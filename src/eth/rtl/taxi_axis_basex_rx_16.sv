// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream 1000BASE-X frame receiver (1000BASE-X in, AXI out)
 */
module taxi_axis_basex_rx_16 #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic SGMII_EN = 1'b1,
    parameter logic AN_EN = SGMII_EN,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = 96
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * 1000BASE-X encoded input
     */
    input  wire logic [DATA_W-1:0]    encoded_rx_data,
    input  wire logic [CTRL_W-1:0]    encoded_rx_data_k,
    input  wire logic                 encoded_rx_data_valid,

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx,

    /*
     * AN config register
     */
    output wire logic [15:0]          rx_an_cfg,
    output wire logic                 rx_an_cfg_valid,
    output wire logic                 rx_an_ability_match,
    output wire logic                 rx_an_ack_match,
    output wire logic                 rx_an_idle_match,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_rx_max_pkt_len = 16'd1518-1,
    input  wire logic                 cfg_rx_enable = 1'b1,
    input  wire logic                 cfg_rx_sgmii_en = 1'b1,
    input  wire logic [1:0]           cfg_rx_sgmii_speed = 2'b10,

    /*
     * Status
     */
    output wire logic [1:0]           rx_start_packet,
    output wire logic [1:0]           stat_rx_byte,
    output wire logic [15:0]          stat_rx_pkt_len,
    output wire logic                 stat_rx_pkt_fragment,
    output wire logic                 stat_rx_pkt_jabber,
    output wire logic                 stat_rx_pkt_ucast,
    output wire logic                 stat_rx_pkt_mcast,
    output wire logic                 stat_rx_pkt_bcast,
    output wire logic                 stat_rx_pkt_vlan,
    output wire logic                 stat_rx_pkt_good,
    output wire logic                 stat_rx_pkt_bad,
    output wire logic                 stat_rx_err_oversize,
    output wire logic                 stat_rx_err_bad_fcs,
    output wire logic                 stat_rx_err_bad_block,
    output wire logic                 stat_rx_err_framing,
    output wire logic                 stat_rx_err_preamble
);

// extract parameters
localparam KEEP_W = DATA_W/8;
localparam USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

// check configuration
if (DATA_W != 16)
    $fatal(0, "Error: Interface width must be 16 (instance %m)");

if (KEEP_W*8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (CTRL_W != 2)
    $fatal(0, "Error: CTRL_W must be 2 (instance %m)");

if (m_axis_rx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axis_rx.USER_W != USER_W)
    $fatal(0, "Error: Interface USER_W parameter mismatch (instance %m)");

typedef enum logic [7:0] {
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5
} eth_pre_t;

function [7:0] D(input [4:0] edcba, input [2:0] hgf);
    D = {hgf, edcba};
endfunction

function [7:0] K(input [4:0] edcba, input [2:0] hgf);
    K = {hgf, edcba};
endfunction

localparam logic [15:0] CTRL_C1 = {D(21,5), K(28,5)};
localparam logic [15:0] CTRL_C2 = {D(2,2),  K(28,5)};
localparam logic [15:0] CTRL_I1 = {D(5,6),  K(28,5)};
localparam logic [15:0] CTRL_I2 = {D(16,2), K(28,5)};
localparam logic [7:0] CTRL_R = K(23,7);
localparam logic [7:0] CTRL_S = K(27,7);
localparam logic [7:0] CTRL_T = K(29,7);
localparam logic [7:0] CTRL_V = K(30,7);
localparam logic [15:0] CTRL_L1 = {D(6,5),  K(28,5)};
localparam logic [15:0] CTRL_L2 = {D(26,4), K(28,5)};

typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PIPE,
    STATE_PAYLOAD,
    STATE_LAST
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic [DATA_W-1:0] input_data_d0_reg = '0;
logic [DATA_W-1:0] input_data_d1_reg = '0;
logic [DATA_W-1:0] input_data_d2_reg = '0;

logic input_k28p5_d0_reg = 1'b0;
logic input_i_d0_reg = 1'b0;
logic input_c_d0_reg = 1'b0;
logic input_start_int_reg = 1'b0;
logic input_start_d0_reg = 1'b0;

logic frame_oversize_reg = 1'b0, frame_oversize_next;
logic pre_ok_reg = 1'b0, pre_ok_next;
logic [2:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [14:0] frame_len_lim_cyc_reg = '0, frame_len_lim_cyc_next;
logic frame_len_lim_last_reg = '0, frame_len_lim_last_next;
logic frame_len_lim_check_reg = '0, frame_len_lim_check_next;

logic [5:0] rep_cnt_reg = '0;
logic rep_stall_reg = 1'b0;
logic rep_en_reg = 1'b0;
logic rep_sel_reg = 1'b0;
logic rep_store_reg = 1'b0;

logic [DATA_W-1:0] m_axis_rx_tdata_reg = '0, m_axis_rx_tdata_next;
logic [KEEP_W-1:0] m_axis_rx_tkeep_reg = '0, m_axis_rx_tkeep_next;
logic m_axis_rx_tvalid_reg = 1'b0, m_axis_rx_tvalid_next;
logic m_axis_rx_tlast_reg = 1'b0, m_axis_rx_tlast_next;
logic m_axis_rx_tuser_reg = 1'b0, m_axis_rx_tuser_next;

logic [15:0] rx_an_cfg_reg = '0;
logic rx_an_cfg_valid_reg = 1'b0;
logic [1:0] an_ability_match_reg = '0;
logic [1:0] an_ack_match_reg = '0;
logic [1:0] an_idle_match_reg = '0;

logic start_packet_int_reg = 1'b0;
logic [1:0] start_packet_reg = '0;
logic frame_reg = 1'b0;

logic [1:0] stat_rx_byte_reg = '0, stat_rx_byte_next;
logic [15:0] stat_rx_pkt_len_reg = '0, stat_rx_pkt_len_next;
logic stat_rx_pkt_fragment_reg = 1'b0, stat_rx_pkt_fragment_next;
logic stat_rx_pkt_jabber_reg = 1'b0, stat_rx_pkt_jabber_next;
logic stat_rx_pkt_ucast_reg = 1'b0, stat_rx_pkt_ucast_next;
logic stat_rx_pkt_mcast_reg = 1'b0, stat_rx_pkt_mcast_next;
logic stat_rx_pkt_bcast_reg = 1'b0, stat_rx_pkt_bcast_next;
logic stat_rx_pkt_vlan_reg = 1'b0, stat_rx_pkt_vlan_next;
logic stat_rx_pkt_good_reg = 1'b0, stat_rx_pkt_good_next;
logic stat_rx_pkt_bad_reg = 1'b0, stat_rx_pkt_bad_next;
logic stat_rx_err_oversize_reg = 1'b0, stat_rx_err_oversize_next;
logic stat_rx_err_bad_fcs_reg = 1'b0, stat_rx_err_bad_fcs_next;
logic stat_rx_err_bad_block_reg = 1'b0;
logic stat_rx_err_framing_reg = 1'b0, stat_rx_err_framing_next;
logic stat_rx_err_preamble_reg = 1'b0, stat_rx_err_preamble_next;

logic [PTP_TS_W-1:0] ptp_ts_reg = '0;
logic [PTP_TS_W-1:0] ptp_ts_out_reg = '0, ptp_ts_out_next;
logic [PTP_TS_W-1:0] ptp_ts_adj_reg = '0;
logic ptp_ts_borrow_reg = '0;

logic [31:0] crc_state_reg = '1;

wire [31:0] crc_state;

wire [1:0] crc_valid;
logic [1:0] crc_valid_reg = '0;

assign crc_valid[1] = crc_state == ~32'h2144df1c;
assign crc_valid[0] = crc_state == ~32'hc622f71d;

logic [5+16-1:0] last_ts_reg = '0;
logic [5+16-1:0] ts_inc_reg = '0;

assign m_axis_rx.tdata = m_axis_rx_tdata_reg;
assign m_axis_rx.tkeep = m_axis_rx_tkeep_reg;
assign m_axis_rx.tstrb = m_axis_rx.tkeep;
assign m_axis_rx.tvalid = m_axis_rx_tvalid_reg;
assign m_axis_rx.tlast = m_axis_rx_tlast_reg;
assign m_axis_rx.tid = '0;
assign m_axis_rx.tdest = '0;
assign m_axis_rx.tuser[0] = m_axis_rx_tuser_reg;
if (PTP_TS_EN) begin
    assign m_axis_rx.tuser[1 +: PTP_TS_W] = ptp_ts_out_reg;
end

assign rx_an_cfg = AN_EN ? rx_an_cfg_reg : '0;
assign rx_an_cfg_valid = AN_EN ? rx_an_cfg_valid_reg : 1'b0;
assign rx_an_ability_match = AN_EN ? an_ability_match_reg[1] : 1'b0;
assign rx_an_ack_match = AN_EN ? an_ack_match_reg[1] : 1'b0;
assign rx_an_idle_match = AN_EN ? an_idle_match_reg[1] : 1'b0;

assign rx_start_packet = start_packet_reg;

assign stat_rx_byte = stat_rx_byte_reg;
assign stat_rx_pkt_len = stat_rx_pkt_len_reg;
assign stat_rx_pkt_fragment = stat_rx_pkt_fragment_reg;
assign stat_rx_pkt_jabber = stat_rx_pkt_jabber_reg;
assign stat_rx_pkt_ucast = stat_rx_pkt_ucast_reg;
assign stat_rx_pkt_mcast = stat_rx_pkt_mcast_reg;
assign stat_rx_pkt_bcast = stat_rx_pkt_bcast_reg;
assign stat_rx_pkt_vlan = stat_rx_pkt_vlan_reg;
assign stat_rx_pkt_good = stat_rx_pkt_good_reg;
assign stat_rx_pkt_bad = stat_rx_pkt_bad_reg;
assign stat_rx_err_oversize = stat_rx_err_oversize_reg;
assign stat_rx_err_bad_fcs = stat_rx_err_bad_fcs_reg;
assign stat_rx_err_bad_block = stat_rx_err_bad_block_reg;
assign stat_rx_err_framing = stat_rx_err_framing_reg;
assign stat_rx_err_preamble = stat_rx_err_preamble_reg;

// Lane swapping with truncated preamble
logic in_pre_reg = 1'b0;
logic lanes_swapped_reg = 1'b0;
logic [7:0] swap_data_reg = '0;
logic swap_data_k_reg = '0;

logic [DATA_W-1:0] swap_rx_data;
logic [CTRL_W-1:0] swap_rx_data_k;

always_comb begin
    swap_rx_data = encoded_rx_data;
    swap_rx_data_k = encoded_rx_data_k;

    if (SGMII_EN && rep_en_reg) begin
        if (lanes_swapped_reg) begin
            swap_rx_data   = {encoded_rx_data[15:8], swap_data_reg};
            swap_rx_data_k = {encoded_rx_data_k[1], swap_data_k_reg};
        end else begin
            swap_rx_data   = {encoded_rx_data[7:0], swap_data_reg};
            swap_rx_data_k = {encoded_rx_data_k[0], swap_data_k_reg};
        end
    end else begin
        if (lanes_swapped_reg) begin
            swap_rx_data   = {encoded_rx_data[7:0], swap_data_reg};
            swap_rx_data_k = {encoded_rx_data_k[0], swap_data_k_reg};
        end
    end
end

// Mask input data
wire [DATA_W-1:0] swap_rx_data_masked;
wire [CTRL_W-1:0] swap_rx_data_term;

for (genvar n = 0; n < CTRL_W; n = n + 1) begin
    assign swap_rx_data_masked[n*8 +: 8] = (n > 0 && swap_rx_data_k[n]) ? 8'd0 : swap_rx_data[n*8 +: 8];
    assign swap_rx_data_term[n] = swap_rx_data_k[n] && (swap_rx_data[n*8 +: 8] == CTRL_T);
end

taxi_lfsr #(
    .LFSR_W(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_GALOIS(1),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_W(DATA_W),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b0)
)
eth_crc (
    .data_in(input_data_d0_reg),
    .state_in(crc_state_reg),
    .data_out(),
    .state_out(crc_state)
);

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_oversize_next = frame_oversize_reg;
    pre_ok_next = pre_ok_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_cyc_next = frame_len_lim_cyc_reg;
    frame_len_lim_last_next = frame_len_lim_last_reg;
    frame_len_lim_check_next = frame_len_lim_check_reg;

    m_axis_rx_tdata_next = input_data_d2_reg;
    m_axis_rx_tkeep_next = {KEEP_W{1'b1}};
    m_axis_rx_tvalid_next = 1'b0;
    m_axis_rx_tlast_next = 1'b0;
    m_axis_rx_tuser_next = 1'b0;

    ptp_ts_out_next = ptp_ts_out_reg;

    stat_rx_byte_next = '0;
    stat_rx_pkt_len_next = '0;
    stat_rx_pkt_fragment_next = 1'b0;
    stat_rx_pkt_jabber_next = 1'b0;
    stat_rx_pkt_ucast_next = 1'b0;
    stat_rx_pkt_mcast_next = 1'b0;
    stat_rx_pkt_bcast_next = 1'b0;
    stat_rx_pkt_vlan_next = 1'b0;
    stat_rx_pkt_good_next = 1'b0;
    stat_rx_pkt_bad_next = 1'b0;
    stat_rx_err_oversize_next = 1'b0;
    stat_rx_err_bad_fcs_next = 1'b0;
    stat_rx_err_framing_next = 1'b0;
    stat_rx_err_preamble_next = 1'b0;

    if (GBX_IF_EN && !encoded_rx_data_valid) begin
        // data from gearbox not valid - hold state
        state_next = state_reg;
    end else if (SGMII_EN && rep_stall_reg) begin
        // SGMII stall - hold state
        state_next = state_reg;
    end else begin
        // counter to measure frame length
        if (&frame_len_reg[15:1] == 0) begin
            casez (swap_rx_data_k)
                2'b00:   frame_len_next = frame_len_reg + 16'(KEEP_W);
                2'b10:   frame_len_next = frame_len_reg + 1;
                default: frame_len_next = frame_len_reg + 0;
            endcase
        end else begin
            frame_len_next = '1;
        end

        // counter for max frame length enforcement
        if (frame_len_lim_cyc_reg != 0) begin
            frame_len_lim_cyc_next = frame_len_lim_cyc_reg - 1;
        end else begin
            frame_len_lim_cyc_next = '0;
        end

        if (frame_len_lim_last_reg == 0) begin
            if (frame_len_lim_cyc_reg == 1) begin
                frame_len_lim_check_next = 1'b1;
            end
        end else begin
            if (frame_len_lim_cyc_reg == 2) begin
                frame_len_lim_check_next = 1'b1;
            end
        end

        // address and ethertype checks
        if (&hdr_ptr_reg == 0) begin
            hdr_ptr_next = hdr_ptr_reg + 1;
        end

        case (hdr_ptr_reg)
            3'd0: begin
                is_mcast_next = input_data_d2_reg[0];
                is_bcast_next = &input_data_d2_reg;
            end
            3'd1: is_bcast_next = is_bcast_reg && &input_data_d2_reg;
            3'd2: is_bcast_next = is_bcast_reg && &input_data_d2_reg;
            3'd6: is_8021q_next = {input_data_d2_reg[7:0], input_data_d2_reg[15:8]} == 16'h8100;
            default: begin
                // do nothing
            end
        endcase

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;

                frame_oversize_next = 1'b0;
                frame_len_next = 16'(KEEP_W);
                frame_len_lim_cyc_next = cfg_rx_max_pkt_len[15:1];
                frame_len_lim_last_next = cfg_rx_max_pkt_len[0] + 1;
                frame_len_lim_check_next = 1'b0;
                hdr_ptr_next = 0;

                pre_ok_next = 1'b1;

                if (input_start_d0_reg && encoded_rx_data_k == 0) begin
                    state_next = STATE_PREAMBLE;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // drop preamble
                reset_crc = 1'b1;

                frame_oversize_next = 1'b0;
                frame_len_next = 16'(KEEP_W);
                frame_len_lim_cyc_next = cfg_rx_max_pkt_len[15:1];
                frame_len_lim_last_next = cfg_rx_max_pkt_len[0] + 1;
                frame_len_lim_check_next = 1'b0;
                hdr_ptr_next = 0;

                if (swap_rx_data_k != 0) begin
                    // control character
                    stat_rx_err_framing_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    // data
                    if (input_data_d0_reg == {2{ETH_PRE}}) begin
                        // normal preamble
                        state_next = STATE_PREAMBLE;
                    end else if (input_data_d0_reg == {ETH_SFD, ETH_PRE}) begin
                        // start
                        if (cfg_rx_enable) begin
                            stat_rx_byte_next = 2'd2;
                            state_next = STATE_PIPE;
                        end else begin
                            state_next = STATE_IDLE;
                        end
                    end else begin
                        // abnormal preamble
                        pre_ok_next = 1'b0;
                        state_next = STATE_PREAMBLE;
                    end
                end
            end
            STATE_PIPE: begin
                // wait for pipeline to fill
                update_crc = 1'b1;

                hdr_ptr_next = 0;

                if (swap_rx_data_k != 0) begin
                    // control or error characters in packet
                    stat_rx_err_framing_next = 1'b1;
                    state_next = STATE_IDLE;
                end else if (input_data_d2_reg == 16'h5555) begin
                    // preamble continues
                    stat_rx_byte_next = 2'(KEEP_W);
                    state_next = STATE_PIPE;
                end else if (input_data_d2_reg == 16'hD555) begin
                    // start
                    stat_rx_byte_next = 2'(KEEP_W);
                    state_next = STATE_PAYLOAD;
                end else begin
                    // invalid preamble
                    stat_rx_err_framing_next = 1'b1;
                    state_next = STATE_IDLE;
                end
            end
            STATE_PAYLOAD: begin
                // read payload
                update_crc = 1'b1;

                m_axis_rx_tdata_next = input_data_d2_reg;
                m_axis_rx_tkeep_next = {KEEP_W{1'b1}};
                m_axis_rx_tvalid_next = 1'b1;
                m_axis_rx_tlast_next = 1'b0;
                m_axis_rx_tuser_next = 1'b0;

                if (swap_rx_data_k[0]) begin
                    stat_rx_byte_next = 2'd0;
                end else if (swap_rx_data_k[1]) begin
                    stat_rx_byte_next = 2'd1;
                    if (frame_len_lim_check_reg) begin
                        if (frame_len_lim_last_reg < 1) begin
                            frame_oversize_next = 1'b1;
                        end
                    end
                end else begin
                    stat_rx_byte_next = 2'(KEEP_W);
                    if (frame_len_lim_check_reg) begin
                        // at the limit but this isn't a termination character
                        frame_oversize_next = 1'b1;
                    end
                end

                if (PTP_TS_EN) begin
                    ptp_ts_out_next = (!PTP_TS_FMT_TOD || ptp_ts_borrow_reg) ? ptp_ts_reg : ptp_ts_adj_reg;
                end

                // if (encoded_rx_data_k && encoded_rx_data != CTRL_T) begin
                //     frame_error_next = 1'b1;
                //     stat_rx_err_framing_next = 1'b1;
                // end

                // if (framing_error_reg) begin
                //     // control or error characters in packet
                //     m_axis_rx_tlast_next = 1'b1;
                //     m_axis_rx_tuser_next = 1'b1;
                //     stat_rx_pkt_bad_next = 1'b1;
                //     stat_rx_pkt_len_next = frame_len_next;
                //     stat_rx_pkt_ucast_next = !is_mcast_reg;
                //     stat_rx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                //     stat_rx_pkt_bcast_next = is_bcast_reg;
                //     stat_rx_pkt_vlan_next = is_8021q_reg;
                //     stat_rx_err_oversize_next = frame_oversize_next;
                //     stat_rx_err_framing_next = 1'b1;
                //     stat_rx_err_preamble_next = !pre_ok_reg;
                //     stat_rx_pkt_fragment_next = frame_len_next[15:6] == 0;
                //     stat_rx_pkt_jabber_next = frame_oversize_next;
                //     reset_crc = 1'b1;
                //     state_next = STATE_IDLE;
                // end else if (term_first_cycle_reg) begin
                if (swap_rx_data_k[0]) begin
                    // end this cycle
                    m_axis_rx_tkeep_next = 2'b11;
                    m_axis_rx_tlast_next = 1'b1;
                    if (swap_rx_data[0 +: 8] != CTRL_T) begin
                        // not a termination character
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_err_framing_next = 1'b1;
                        stat_rx_pkt_fragment_next = frame_len_next[15:6] == 0;
                        stat_rx_pkt_jabber_next = frame_oversize_next;
                        stat_rx_pkt_bad_next = 1'b1;
                    end else if (crc_valid[1]) begin
                        // CRC valid
                        if (frame_oversize_next) begin
                            // too long
                            m_axis_rx_tuser_next = 1'b1;
                            stat_rx_pkt_bad_next = 1'b1;
                        end else begin
                            // length OK
                            m_axis_rx_tuser_next = 1'b0;
                            stat_rx_pkt_good_next = 1'b1;
                        end
                    end else begin
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_pkt_fragment_next = frame_len_next[15:6] == 0;
                        stat_rx_pkt_jabber_next = frame_oversize_next;
                        stat_rx_pkt_bad_next = 1'b1;
                        stat_rx_err_bad_fcs_next = 1'b1;
                    end
                    stat_rx_pkt_len_next = frame_len_next;
                    stat_rx_pkt_ucast_next = !is_mcast_reg;
                    stat_rx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                    stat_rx_pkt_bcast_next = is_bcast_reg;
                    stat_rx_pkt_vlan_next = is_8021q_reg;
                    stat_rx_err_oversize_next = frame_oversize_next;
                    stat_rx_err_preamble_next = !pre_ok_reg;
                    reset_crc = 1'b1;
                    state_next = STATE_IDLE;
                end else if (swap_rx_data_k[1]) begin
                    // need extra cycle
                    // TODO check term char
                    state_next = STATE_LAST;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_LAST: begin
                // last cycle of packet
                m_axis_rx_tdata_next = input_data_d2_reg;
                m_axis_rx_tkeep_next = 2'b01;
                m_axis_rx_tvalid_next = 1'b1;
                m_axis_rx_tlast_next = 1'b1;
                m_axis_rx_tuser_next = 1'b0;

                reset_crc = 1'b1;

                if (crc_valid[0]) begin
                    // CRC valid
                    if (frame_oversize_reg) begin
                        // too long
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_pkt_bad_next = 1'b1;
                    end else begin
                        // length OK
                        m_axis_rx_tuser_next = 1'b0;
                        stat_rx_pkt_good_next = 1'b1;
                    end
                end else begin
                    m_axis_rx_tuser_next = 1'b1;
                    stat_rx_pkt_fragment_next = frame_len_reg[15:6] == 0;
                    stat_rx_pkt_jabber_next = frame_oversize_reg;
                    stat_rx_pkt_bad_next = 1'b1;
                    stat_rx_err_bad_fcs_next = 1'b1;
                end

                stat_rx_pkt_len_next = frame_len_reg;
                stat_rx_pkt_ucast_next = !is_mcast_reg;
                stat_rx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                stat_rx_pkt_bcast_next = is_bcast_reg;
                stat_rx_pkt_vlan_next = is_8021q_reg;
                stat_rx_err_oversize_next = frame_oversize_reg;
                stat_rx_err_preamble_next = !pre_ok_reg;

                state_next = STATE_IDLE;
            end
            default: begin
                // invalid state, return to idle
                state_next = STATE_IDLE;
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    frame_oversize_reg <= frame_oversize_next;
    pre_ok_reg <= pre_ok_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_cyc_reg <= frame_len_lim_cyc_next;
    frame_len_lim_last_reg <= frame_len_lim_last_next;
    frame_len_lim_check_reg <= frame_len_lim_check_next;

    start_packet_reg <= '0;

    m_axis_rx_tdata_reg <= m_axis_rx_tdata_next;
    m_axis_rx_tkeep_reg <= m_axis_rx_tkeep_next;
    m_axis_rx_tvalid_reg <= m_axis_rx_tvalid_next;
    m_axis_rx_tlast_reg <= m_axis_rx_tlast_next;
    m_axis_rx_tuser_reg <= m_axis_rx_tuser_next;

    rx_an_cfg_valid_reg <= 1'b0;

    ptp_ts_out_reg <= ptp_ts_out_next;

    stat_rx_byte_reg <= stat_rx_byte_next;
    stat_rx_pkt_len_reg <= stat_rx_pkt_len_next;
    stat_rx_pkt_fragment_reg <= stat_rx_pkt_fragment_next;
    stat_rx_pkt_jabber_reg <= stat_rx_pkt_jabber_next;
    stat_rx_pkt_ucast_reg <= stat_rx_pkt_ucast_next;
    stat_rx_pkt_mcast_reg <= stat_rx_pkt_mcast_next;
    stat_rx_pkt_bcast_reg <= stat_rx_pkt_bcast_next;
    stat_rx_pkt_vlan_reg <= stat_rx_pkt_vlan_next;
    stat_rx_pkt_good_reg <= stat_rx_pkt_good_next;
    stat_rx_pkt_bad_reg <= stat_rx_pkt_bad_next;
    stat_rx_err_oversize_reg <= stat_rx_err_oversize_next;
    stat_rx_err_bad_fcs_reg <= stat_rx_err_bad_fcs_next;
    stat_rx_err_bad_block_reg <= 1'b0;
    stat_rx_err_framing_reg <= stat_rx_err_framing_next;
    stat_rx_err_preamble_reg <= stat_rx_err_preamble_next;

    if (!GBX_IF_EN || encoded_rx_data_valid) begin

        if (!SGMII_EN || !rep_en_reg) begin
            swap_data_reg <= encoded_rx_data[15:8];
            swap_data_k_reg <= encoded_rx_data_k[1];

            input_data_d0_reg <= swap_rx_data_masked;
            input_data_d1_reg <= input_data_d0_reg;
            input_data_d2_reg <= input_data_d1_reg;
        end else begin
            if (rep_store_reg || encoded_rx_data_k != 0) begin
                if (!encoded_rx_data_k[0]) begin
                    swap_data_reg <= encoded_rx_data[15:8];
                    swap_data_k_reg <= encoded_rx_data_k[1];
                end else begin
                    swap_data_reg <= encoded_rx_data[7:0];
                    swap_data_k_reg <= encoded_rx_data_k[0];
                end
            end

            if (!rep_stall_reg) begin
                input_data_d0_reg <= swap_rx_data_masked;
                input_data_d1_reg <= input_data_d0_reg;
                input_data_d2_reg <= input_data_d1_reg;
            end
        end

        input_k28p5_d0_reg <= 1'b0;
        input_i_d0_reg <= 1'b0;
        input_c_d0_reg <= 1'b0;
        if (!SGMII_EN || !rep_stall_reg) begin
            input_start_int_reg <= 1'b0;
            input_start_d0_reg <= input_start_int_reg;
        end

        if (PTP_TS_EN && PTP_TS_FMT_TOD) begin
            // ns field rollover
            // workaround for verilator lint bug: unreachable by parameter value
            /* verilator lint_off SELRANGE */
            ptp_ts_adj_reg[15:0] <= ptp_ts_reg[15:0];
            {ptp_ts_borrow_reg, ptp_ts_adj_reg[45:16]} <= $signed({1'b0, ptp_ts_reg[45:16]}) - $signed(31'd1000000000);
            ptp_ts_adj_reg[47:46] <= 0;
            ptp_ts_adj_reg[95:48] <= ptp_ts_reg[95:48] + 1;
            /* verilator lint_on SELRANGE */
        end

        // /K28.5/ control character detection
        if (encoded_rx_data_k[0] && encoded_rx_data[7:0] == K(28, 5)) begin
            input_k28p5_d0_reg <= 1'b1;
        end

        // idle symbol detection
        if (encoded_rx_data_k == 2'b01 && (encoded_rx_data == CTRL_I1 || encoded_rx_data == CTRL_I2)) begin
            input_i_d0_reg <= 1'b1;
        end

        if (AN_EN && input_i_d0_reg) begin
            an_ability_match_reg <= '0;
            an_ack_match_reg <= '0;
            an_idle_match_reg <= {an_idle_match_reg[0], 1'b1};
        end

        // config symbol detection
        if (encoded_rx_data_k == 2'b01 && (encoded_rx_data == CTRL_C1 || encoded_rx_data == CTRL_C2)) begin
            input_c_d0_reg <= 1'b1;
        end

        if (AN_EN && input_c_d0_reg) begin
            rx_an_cfg_reg <= encoded_rx_data;
            rx_an_cfg_valid_reg <= encoded_rx_data_k == 2'b00;
            if (((rx_an_cfg_reg ^ encoded_rx_data) & ~16'h4000) == 0) begin
                an_ability_match_reg <= {an_ability_match_reg[0], 1'b1};
            end else begin
                an_ability_match_reg <= '0;
            end
            if (rx_an_cfg_reg[14] && rx_an_cfg_reg == encoded_rx_data) begin
                an_ack_match_reg <= {an_ack_match_reg[0], 1'b1};
            end else begin
                an_ack_match_reg <= '0;
            end
            an_idle_match_reg <= '0;
        end

        // start control character detection
        if (encoded_rx_data_k[0] && encoded_rx_data[7:0] == CTRL_S) begin
            if (rep_en_reg) begin
                input_start_int_reg <= 1'b1;
            end else begin
                input_start_d0_reg <= 1'b1;
            end
            in_pre_reg <= 1'b1;
            lanes_swapped_reg <= 1'b0;
        end

        if (AN_EN && input_start_d0_reg) begin
            an_ability_match_reg <= '0;
            an_ack_match_reg <= '0;
            an_idle_match_reg <= '0;
        end

        // SFD detection
        if (in_pre_reg) begin
            lanes_swapped_reg <= 1'b0;
            if (SGMII_EN && rep_en_reg) begin
                // SGMII repeated symbols
                if (encoded_rx_data[7]) begin
                    // normal
                    in_pre_reg <= 1'b0;
                    start_packet_int_reg <= 1'b1;
                end else if (encoded_rx_data[15]) begin
                    // truncated start
                    in_pre_reg <= 1'b0;
                    lanes_swapped_reg <= 1'b1;
                    start_packet_int_reg <= 1'b1;
                end
            end else begin
                // full rate
                if (encoded_rx_data[7]) begin
                    // truncated preamble
                    in_pre_reg <= 1'b0;
                    lanes_swapped_reg <= 1'b1;
                    input_data_d0_reg <= {ETH_SFD, ETH_PRE};
                    start_packet_reg <= 2'b10;
                    if (PTP_TS_FMT_TOD) begin
                        // workaround for verilator lint bug: unreachable by parameter value
                        /* verilator lint_off SELRANGE */
                        ptp_ts_reg[45:0] <= ptp_ts[45:0] + 46'(ts_inc_reg >> 1);
                        ptp_ts_reg[95:48] <= ptp_ts[95:48];
                        /* verilator lint_on SELRANGE */
                    end else begin
                        ptp_ts_reg <= ptp_ts + PTP_TS_W'(ts_inc_reg >> 1);
                    end
                end else if (encoded_rx_data[15]) begin
                    // normal preamble
                    in_pre_reg <= 1'b0;
                    start_packet_int_reg <= 1'b1;
                end
            end
        end

        if (start_packet_int_reg) begin
            if (SGMII_EN && rep_en_reg) begin
                if (lanes_swapped_reg) begin
                    if (rep_store_reg) begin
                        start_packet_int_reg <= 1'b0;
                        start_packet_reg <= 2'b10;
                    end
                    if (PTP_TS_FMT_TOD) begin
                        // workaround for verilator lint bug: unreachable by parameter value
                        /* verilator lint_off SELRANGE */
                        ptp_ts_reg[45:0] <= ptp_ts[45:0] + 46'(ts_inc_reg >> 1);
                        ptp_ts_reg[95:48] <= ptp_ts[95:48];
                        /* verilator lint_on SELRANGE */
                    end else begin
                        ptp_ts_reg <= ptp_ts + PTP_TS_W'(ts_inc_reg >> 1);
                    end
                end else begin
                    if (rep_store_reg) begin
                        start_packet_int_reg <= 1'b0;
                        start_packet_reg <= 2'b01;
                    end
                    ptp_ts_reg <= ptp_ts;
                end
            end else begin
                start_packet_int_reg <= 1'b0;
                start_packet_reg <= 2'b01;
                ptp_ts_reg <= ptp_ts;
            end
        end

        if (reset_crc) begin
            crc_state_reg <= '1;
        end else if (update_crc) begin
            crc_state_reg <= crc_state;
        end

        crc_valid_reg <= crc_valid;

        if (SGMII_EN && cfg_rx_sgmii_en) begin
            if (in_pre_reg && encoded_rx_data[15] && !encoded_rx_data[7]) begin
                // truncated repetition
                rep_stall_reg <= 1'b0;
                rep_en_reg <= 1'b1;
                rep_sel_reg <= 1'b1;
                rep_store_reg <= 1'b0;
                case (cfg_rx_sgmii_speed)
                    2'b00: rep_cnt_reg <= 48; // 10 Mbps
                    2'b01: rep_cnt_reg <= 3; // 100 Mbps
                    default: begin
                        rep_cnt_reg <= 0; // 1 Gbps
                        rep_stall_reg <= 1'b0;
                        rep_en_reg <= 1'b0;
                        rep_sel_reg <= 1'b0;
                    end
                endcase
            end else if (encoded_rx_data_k != 0) begin
                // align to start (control character)
                rep_stall_reg <= 1'b1;
                rep_en_reg <= 1'b1;
                rep_sel_reg <= 1'b0;
                rep_store_reg <= 1'b0;
                case (cfg_rx_sgmii_speed)
                    2'b00: rep_cnt_reg <= 48; // 10 Mbps
                    2'b01: rep_cnt_reg <= 3; // 100 Mbps
                    default: begin
                        rep_cnt_reg <= 0; // 1 Gbps
                        rep_stall_reg <= 1'b0;
                        rep_en_reg <= 1'b0;
                        rep_sel_reg <= 1'b0;
                    end
                endcase
                if (encoded_rx_data_k != 0 && !(encoded_rx_data_k[0] && encoded_rx_data[7:0] == CTRL_S)) begin
                    // have stored control character that isn't start, skip stall
                    rep_stall_reg <= 1'b0;
                end
            end else if (rep_cnt_reg == 0) begin
                rep_stall_reg <= rep_sel_reg;
                rep_en_reg <= 1'b1;
                rep_sel_reg <= !rep_sel_reg;
                rep_store_reg <= rep_sel_reg;
                case (cfg_rx_sgmii_speed)
                    2'b00: rep_cnt_reg <= 49; // 10 Mbps
                    2'b01: rep_cnt_reg <= 4; // 100 Mbps
                    default: begin
                        rep_cnt_reg <= 0; // 1 Gbps
                        rep_stall_reg <= 1'b0;
                        rep_en_reg <= 1'b0;
                        rep_sel_reg <= 1'b0;
                    end
                endcase
            end else begin
                rep_cnt_reg <= rep_cnt_reg-1;
                rep_stall_reg <= 1'b1;
                rep_en_reg <= 1'b1;
                rep_store_reg <= 1'b0;
            end
        end else begin
            rep_cnt_reg <= '0;
            rep_stall_reg <= 1'b0;
            rep_en_reg <= 1'b0;
            rep_sel_reg <= 1'b0;
            rep_store_reg <= 1'b0;
        end
    end

    last_ts_reg <= (5+16)'(ptp_ts);
    ts_inc_reg <= (5+16)'(ptp_ts) - last_ts_reg;

    if (rst) begin
        state_reg <= STATE_IDLE;

        m_axis_rx_tvalid_reg <= 1'b0;

        rx_an_cfg_valid_reg <= 1'b0;
        an_ability_match_reg <= '0;
        an_ack_match_reg <= '0;
        an_idle_match_reg <= '0;

        rep_cnt_reg <= '0;
        rep_stall_reg <= 1'b0;
        rep_en_reg <= 1'b0;
        rep_sel_reg <= 1'b0;
        rep_store_reg <= 1'b0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= '0;
        frame_reg <= 1'b0;

        stat_rx_byte_reg <= '0;
        stat_rx_pkt_len_reg <= '0;
        stat_rx_pkt_fragment_reg <= 1'b0;
        stat_rx_pkt_jabber_reg <= 1'b0;
        stat_rx_pkt_ucast_reg <= 1'b0;
        stat_rx_pkt_mcast_reg <= 1'b0;
        stat_rx_pkt_bcast_reg <= 1'b0;
        stat_rx_pkt_vlan_reg <= 1'b0;
        stat_rx_pkt_good_reg <= 1'b0;
        stat_rx_pkt_bad_reg <= 1'b0;
        stat_rx_err_oversize_reg <= 1'b0;
        stat_rx_err_bad_fcs_reg <= 1'b0;
        stat_rx_err_bad_block_reg <= 1'b0;
        stat_rx_err_framing_reg <= 1'b0;
        stat_rx_err_preamble_reg <= 1'b0;

        input_k28p5_d0_reg <= 1'b0;
        input_i_d0_reg <= 1'b0;
        input_c_d0_reg <= 1'b0;
        input_start_d0_reg <= 1'b0;
    end
end

endmodule

`resetall
