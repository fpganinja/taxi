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
module taxi_axis_basex_rx_8 #
(
    parameter DATA_W = 8,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic AN_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
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
    input  wire logic                 cfg_rx_enable,

    /*
     * Status
     */
    output wire logic                 rx_start_packet,
    output wire logic                 stat_rx_byte,
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

localparam USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

// check configuration
if (DATA_W != 8)
    $fatal(0, "Error: Interface width must be 8 (instance %m)");

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

typedef enum logic [1:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PIPE,
    STATE_PAYLOAD
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic in_frame_reg = 1'b0;

logic [DATA_W-1:0] encoded_rx_data_d0_reg = '0;
logic [DATA_W-1:0] encoded_rx_data_d1_reg = '0;
logic [DATA_W-1:0] encoded_rx_data_d2_reg = '0;
logic [DATA_W-1:0] encoded_rx_data_d3_reg = '0;
logic [DATA_W-1:0] encoded_rx_data_d4_reg = '0;

logic encoded_rx_data_k_d0_reg = 1'b0;

logic input_k28p5_d0_reg = 1'b0;
logic input_i_d0_reg = 1'b0;
logic input_c_d0_reg = 1'b0;
logic input_c_d1_reg = 1'b0;
logic input_start_d0_reg = 1'b0;

logic frame_error_reg = 1'b0, frame_error_next;
logic pre_ok_reg = 1'b0, pre_ok_next;
logic [3:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [15:0] frame_len_lim_reg = '0, frame_len_lim_next;
logic frame_len_lim_check_reg = '0, frame_len_lim_check_next;
logic odd_reg = 1'b0, odd_next;

logic [DATA_W-1:0] m_axis_rx_tdata_reg = '0, m_axis_rx_tdata_next;
logic m_axis_rx_tvalid_reg = 1'b0, m_axis_rx_tvalid_next;
logic m_axis_rx_tlast_reg = 1'b0, m_axis_rx_tlast_next;
logic m_axis_rx_tuser_reg = 1'b0, m_axis_rx_tuser_next;

logic [15:0] rx_an_cfg_reg = '0;
logic rx_an_cfg_valid_reg = 1'b0;
logic an_cfg_match_reg = 1'b0;
logic [1:0] an_ability_match_cnt_reg = '0;
logic [1:0] an_ack_match_cnt_reg = '0;
logic [1:0] an_idle_match_cnt_reg = '0;

logic start_packet_int_reg = 1'b0;
logic start_packet_reg = 1'b0;

logic stat_rx_byte_reg = 1'b0, stat_rx_byte_next;
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
logic stat_rx_err_bad_block_reg = 1'b0, stat_rx_err_bad_block_next;
logic stat_rx_err_framing_reg = 1'b0, stat_rx_err_framing_next;
logic stat_rx_err_preamble_reg = 1'b0, stat_rx_err_preamble_next;

logic [PTP_TS_W-1:0] ptp_ts_out_reg = '0;

logic [31:0] crc_state_reg = '1;
wire [31:0] crc_state;

assign m_axis_rx.tdata = m_axis_rx_tdata_reg;
assign m_axis_rx.tkeep = 1'b1;
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
assign rx_an_ability_match = AN_EN ? &an_ability_match_cnt_reg : 1'b0;
assign rx_an_ack_match = AN_EN ? &an_ack_match_cnt_reg : 1'b0;
assign rx_an_idle_match = AN_EN ? &an_idle_match_cnt_reg : 1'b0;

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
eth_crc_8 (
    .data_in(encoded_rx_data_d0_reg),
    .state_in(crc_state_reg),
    .data_out(),
    .state_out(crc_state)
);

wire crc_valid = crc_state == ~32'h2144df1c;

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_error_next = frame_error_reg;
    pre_ok_next = pre_ok_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_next = frame_len_lim_reg;
    frame_len_lim_check_next = frame_len_lim_check_reg;
    odd_next = odd_reg;

    m_axis_rx_tdata_next = '0;
    m_axis_rx_tvalid_next = 1'b0;
    m_axis_rx_tlast_next = 1'b0;
    m_axis_rx_tuser_next = 1'b0;

    stat_rx_byte_next = 1'b0;
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
    stat_rx_err_bad_block_next = 1'b0;
    stat_rx_err_framing_next = 1'b0;
    stat_rx_err_preamble_next = 1'b0;

    if (GBX_IF_EN && !encoded_rx_data_valid) begin
        // data from gearbox not valid - hold state
        state_next = state_reg;
    end else begin

        odd_next = !odd_reg;

        // counter to measure frame length
        if (&frame_len_reg == 0) begin
            frame_len_next = frame_len_reg + 1;
        end

        // counter for max frame length enforcement
        if (frame_len_lim_reg != 0) begin
            frame_len_lim_next = frame_len_lim_reg - 1;
        end else begin
            frame_len_lim_check_next = 1'b1;
        end

        // address and ethertype checks
        if (&hdr_ptr_reg == 0) begin
            hdr_ptr_next = hdr_ptr_reg + 1;
        end

        case (hdr_ptr_reg)
            4'd0: begin
                is_mcast_next = encoded_rx_data_d4_reg[0];
                is_bcast_next = encoded_rx_data_d4_reg == 8'hff;
            end
            4'd1: is_bcast_next = is_bcast_reg && encoded_rx_data_d4_reg == 8'hff;
            4'd2: is_bcast_next = is_bcast_reg && encoded_rx_data_d4_reg == 8'hff;
            4'd3: is_bcast_next = is_bcast_reg && encoded_rx_data_d4_reg == 8'hff;
            4'd4: is_bcast_next = is_bcast_reg && encoded_rx_data_d4_reg == 8'hff;
            4'd5: is_bcast_next = is_bcast_reg && encoded_rx_data_d4_reg == 8'hff;
            4'd12: is_8021q_next = encoded_rx_data_d4_reg == 8'h81;
            4'd13: is_8021q_next = is_8021q_reg && encoded_rx_data_d4_reg == 8'h00;
            default: begin
                // do nothing
            end
        endcase

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;
                frame_error_next = 1'b0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_rx_max_pkt_len;
                frame_len_lim_check_next = 1'b0;
                hdr_ptr_next = 0;
                is_mcast_next = 1'b0;
                is_bcast_next = 1'b0;
                is_8021q_next = 1'b0;

                pre_ok_next = 1'b1;

                if (encoded_rx_data_k_d0_reg && encoded_rx_data_d0_reg == CTRL_S && !encoded_rx_data_k) begin
                    state_next = STATE_PREAMBLE;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;
                frame_error_next = 1'b0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_rx_max_pkt_len;
                frame_len_lim_check_next = 1'b0;
                hdr_ptr_next = 0;
                is_mcast_next = 1'b0;
                is_bcast_next = 1'b0;
                is_8021q_next = 1'b0;

                if (encoded_rx_data_k) begin
                    // control character
                    stat_rx_err_framing_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    // data
                    if (encoded_rx_data_d0_reg == ETH_PRE) begin
                        // normal preamble
                        state_next = STATE_PREAMBLE;
                    end else if (encoded_rx_data_d0_reg == ETH_SFD) begin
                        // start
                        if (cfg_rx_enable) begin
                            stat_rx_byte_next = 1'b1;
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
                // wait for FCS pipeline to fill
                update_crc = 1'b1;
                hdr_ptr_next = 0;
                is_mcast_next = 1'b0;
                is_bcast_next = 1'b0;
                is_8021q_next = 1'b0;

                stat_rx_byte_next = encoded_rx_data_k == 0;

                if (encoded_rx_data_k) begin
                    // control character
                    frame_error_next = 1'b1;
                    stat_rx_err_framing_next = 1'b1;
                    state_next = STATE_IDLE;
                end else if (encoded_rx_data_d4_reg == ETH_SFD) begin
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_PIPE;
                end
            end
            STATE_PAYLOAD: begin
                // read payload
                update_crc = 1'b1;

                m_axis_rx_tdata_next = encoded_rx_data_d4_reg;
                m_axis_rx_tvalid_next = 1'b1;

                stat_rx_byte_next = encoded_rx_data_k == 0;

                if (encoded_rx_data_k && encoded_rx_data != CTRL_T) begin
                    frame_error_next = 1'b1;
                    stat_rx_err_framing_next = 1'b1;
                end

                if (encoded_rx_data_k) begin
                    // end of packet
                    m_axis_rx_tlast_next = 1'b1;
                    stat_rx_pkt_len_next = frame_len_reg;
                    stat_rx_pkt_ucast_next = !is_mcast_reg;
                    stat_rx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                    stat_rx_pkt_bcast_next = is_bcast_reg;
                    stat_rx_pkt_vlan_next = is_8021q_reg;
                    stat_rx_err_oversize_next = frame_len_lim_check_reg;
                    stat_rx_err_preamble_next = !pre_ok_reg;
                    if (frame_error_next) begin
                        // error
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_pkt_fragment_next = frame_len_reg[15:6] == 0;
                        stat_rx_pkt_jabber_next = frame_len_lim_check_reg;
                        stat_rx_pkt_bad_next = 1'b1;
                    end else if (crc_valid) begin
                        // FCS good
                        if (frame_len_lim_check_reg) begin
                            // too long
                            m_axis_rx_tuser_next = 1'b1;
                            stat_rx_pkt_bad_next = 1'b1;
                        end else begin
                            // length OK
                            m_axis_rx_tuser_next = 1'b0;
                            stat_rx_pkt_good_next = 1'b1;
                        end
                    end else begin
                        // FCS bad
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_pkt_fragment_next = frame_len_reg[15:6] == 0;
                        stat_rx_pkt_jabber_next = frame_len_lim_check_reg;
                        stat_rx_pkt_bad_next = 1'b1;
                        stat_rx_err_bad_fcs_next = 1'b1;
                    end
                    reset_crc = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
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

    frame_error_reg <= frame_error_next;
    pre_ok_reg <= pre_ok_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_reg <= frame_len_lim_next;
    frame_len_lim_check_reg <= frame_len_lim_check_next;
    odd_reg <= odd_next;

    m_axis_rx_tdata_reg <= m_axis_rx_tdata_next;
    m_axis_rx_tvalid_reg <= m_axis_rx_tvalid_next;
    m_axis_rx_tlast_reg <= m_axis_rx_tlast_next;
    m_axis_rx_tuser_reg <= m_axis_rx_tuser_next;

    rx_an_cfg_valid_reg <= 1'b0;

    start_packet_int_reg <= 1'b0;
    start_packet_reg <= 1'b0;

    if (start_packet_int_reg) begin
        ptp_ts_out_reg <= ptp_ts;
        start_packet_reg <= 1'b1;
    end

    if (!GBX_IF_EN || encoded_rx_data_valid) begin
        if (in_frame_reg) begin
            in_frame_reg <= encoded_rx_data_k == 0;
        end else if (encoded_rx_data_k == 0 && encoded_rx_data == ETH_SFD) begin
            in_frame_reg <= 1'b1;
            start_packet_int_reg <= 1'b1;
        end

        encoded_rx_data_d0_reg <= encoded_rx_data;
        encoded_rx_data_d1_reg <= encoded_rx_data_d0_reg;
        encoded_rx_data_d2_reg <= encoded_rx_data_d1_reg;
        encoded_rx_data_d3_reg <= encoded_rx_data_d2_reg;
        encoded_rx_data_d4_reg <= encoded_rx_data_d3_reg;

        encoded_rx_data_k_d0_reg <= encoded_rx_data_k;

        input_k28p5_d0_reg <= 1'b0;
        input_i_d0_reg <= 1'b0;
        input_c_d0_reg <= 1'b0;
        input_c_d1_reg <= input_c_d0_reg;
        input_start_d0_reg <= 1'b0;

        // /K28.5/ control character detection
        if (encoded_rx_data_k && encoded_rx_data == K(28, 5)) begin
            input_k28p5_d0_reg <= 1'b1;
        end

        // idle symbol detection
        if (input_k28p5_d0_reg && (encoded_rx_data == D(5,6) || encoded_rx_data == D(16,2))) begin
            input_i_d0_reg <= 1'b1;
        end

        if (AN_EN && input_i_d0_reg) begin
            an_ability_match_cnt_reg <= '0;
            an_ack_match_cnt_reg <= '0;
            if (!(&an_idle_match_cnt_reg)) begin
                an_idle_match_cnt_reg <= an_idle_match_cnt_reg + 1;
            end
        end

        // config symbol detection
        if (input_k28p5_d0_reg && (encoded_rx_data == D(21,5) || encoded_rx_data == D(2,2))) begin
            input_c_d0_reg <= 1'b1;
        end

        if (AN_EN && input_c_d0_reg) begin
            rx_an_cfg_reg[7:0] <= encoded_rx_data;
            an_cfg_match_reg <= rx_an_cfg_reg[7:0] == encoded_rx_data;
            input_c_d1_reg <= encoded_rx_data_k == 1'b0;
            an_idle_match_cnt_reg <= '0;
        end

        if (AN_EN && input_c_d1_reg) begin
            rx_an_cfg_reg[15:8] <= encoded_rx_data;
            rx_an_cfg_valid_reg <= encoded_rx_data_k == 1'b0;
            if (an_cfg_match_reg && ((rx_an_cfg_reg[15:8] ^ encoded_rx_data) & 8'h40) == 0) begin
                if (!(&an_ability_match_cnt_reg)) begin
                    an_ability_match_cnt_reg <= an_ability_match_cnt_reg + 1;
                end
            end else begin
                an_ability_match_cnt_reg <= '0;
            end
            if (an_cfg_match_reg && rx_an_cfg_reg[14] && rx_an_cfg_reg[15:8] == encoded_rx_data) begin
                if (!(&an_ack_match_cnt_reg)) begin
                    an_ack_match_cnt_reg <= an_ack_match_cnt_reg + 1;
                end
            end else begin
                an_ack_match_cnt_reg <= '0;
            end
            an_idle_match_cnt_reg <= '0;
        end

        // start control character detection
        if (encoded_rx_data_k && encoded_rx_data == CTRL_S) begin
            input_start_d0_reg <= 1'b1;
        end

        if (AN_EN && input_start_d0_reg) begin
            an_ability_match_cnt_reg <= '0;
            an_ack_match_cnt_reg <= '0;
            an_idle_match_cnt_reg <= '0;
        end

        if (reset_crc) begin
            crc_state_reg <= '1;
        end else if (update_crc) begin
            crc_state_reg <= crc_state;
        end
    end

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
    stat_rx_err_bad_block_reg <= stat_rx_err_bad_block_next;
    stat_rx_err_framing_reg <= stat_rx_err_framing_next;
    stat_rx_err_preamble_reg <= stat_rx_err_preamble_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        input_k28p5_d0_reg <= 1'b0;
        input_i_d0_reg <= 1'b0;
        input_c_d0_reg <= 1'b0;
        input_c_d1_reg <= 1'b0;
        input_start_d0_reg <= 1'b0;

        m_axis_rx_tvalid_reg <= 1'b0;

        rx_an_cfg_valid_reg <= 1'b0;
        an_ability_match_cnt_reg <= '0;
        an_ack_match_cnt_reg <= '0;
        an_idle_match_cnt_reg <= '0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= 1'b0;

        stat_rx_byte_reg <= 1'b0;
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

        in_frame_reg <= 1'b0;
    end
end

endmodule

`resetall
