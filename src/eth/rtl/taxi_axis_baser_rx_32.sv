// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream 10GBASE-R frame receiver (10GBASE-R in, AXI out)
 */
module taxi_axis_baser_rx_32 #
(
    parameter DATA_W = 32,
    parameter HDR_W = 2,
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic PTP_TS_EN = 1'b0,
    parameter PTP_TS_W = 96
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * 10GBASE-R encoded input
     */
    input  wire logic [DATA_W-1:0]    encoded_rx_data,
    input  wire logic                 encoded_rx_data_valid,
    input  wire logic [HDR_W-1:0]     encoded_rx_hdr,
    input  wire logic                 encoded_rx_hdr_valid,

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_rx_max_pkt_len = 16'd1518,
    input  wire logic                 cfg_rx_enable,

    /*
     * Status
     */
    output wire logic                 rx_start_packet,
    output wire logic [2:0]           stat_rx_byte,
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
if (DATA_W != 32)
    $fatal(0, "Error: Interface width must be 32 (instance %m)");

if (KEEP_W*8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2 (instance %m)");

if (m_axis_rx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axis_rx.USER_W != USER_W)
    $fatal(0, "Error: Interface USER_W parameter mismatch (instance %m)");

typedef enum logic [7:0] {
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5
} eth_pre_t;

typedef enum logic [6:0] {
    CTRL_IDLE  = 7'h00,
    CTRL_LPI   = 7'h06,
    CTRL_ERROR = 7'h1e,
    CTRL_RES_0 = 7'h2d,
    CTRL_RES_1 = 7'h33,
    CTRL_RES_2 = 7'h4b,
    CTRL_RES_3 = 7'h55,
    CTRL_RES_4 = 7'h66,
    CTRL_RES_5 = 7'h78
} baser_ctrl_t;

typedef enum logic [3:0] {
    O_SEQ_OS = 4'h0,
    O_SIG_OS = 4'hf
} baser_o_t;

typedef enum logic [1:0] {
    SYNC_DATA = 2'b10,
    SYNC_CTRL = 2'b01
} baser_sync_t;

typedef enum logic [7:0] {
    BLOCK_TYPE_CTRL     = 8'h1e, // C7 C6 C5 C4 C3 C2 C1 C0 BT
    BLOCK_TYPE_OS_4     = 8'h2d, // D7 D6 D5 O4 C3 C2 C1 C0 BT
    BLOCK_TYPE_START_4  = 8'h33, // D7 D6 D5    C3 C2 C1 C0 BT
    BLOCK_TYPE_OS_START = 8'h66, // D7 D6 D5    O0 D3 D2 D1 BT
    BLOCK_TYPE_OS_04    = 8'h55, // D7 D6 D5 O4 O0 D3 D2 D1 BT
    BLOCK_TYPE_START_0  = 8'h78, // D7 D6 D5 D4 D3 D2 D1    BT
    BLOCK_TYPE_OS_0     = 8'h4b, // C7 C6 C5 C4 O0 D3 D2 D1 BT
    BLOCK_TYPE_TERM_0   = 8'h87, // C7 C6 C5 C4 C3 C2 C1    BT
    BLOCK_TYPE_TERM_1   = 8'h99, // C7 C6 C5 C4 C3 C2    D0 BT
    BLOCK_TYPE_TERM_2   = 8'haa, // C7 C6 C5 C4 C3    D1 D0 BT
    BLOCK_TYPE_TERM_3   = 8'hb4, // C7 C6 C5 C4    D2 D1 D0 BT
    BLOCK_TYPE_TERM_4   = 8'hcc, // C7 C6 C5    D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_5   = 8'hd2, // C7 C6    D4 D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_6   = 8'he1, // C7    D5 D4 D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_7   = 8'hff  //    D6 D5 D4 D3 D2 D1 D0 BT
} baser_block_type_t;

typedef enum logic [1:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PAYLOAD,
    STATE_LAST
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;

logic term_present_alt_reg = 1'b0;
logic term_present_reg = 1'b0;
logic term_first_cycle_alt_reg = 1'b0;
logic term_first_cycle_reg = 1'b0;
logic [1:0] term_lane_alt_reg = 0;
logic [1:0] term_lane_reg = 0;
logic [1:0] term_lane_d0_reg = 0;
logic framing_error_reg = 1'b0;

logic [DATA_W-1:0] input_data_d0_reg = '0;
logic [DATA_W-1:0] input_data_d1_reg = '0;
logic [DATA_W-1:0] input_data_d2_reg = '0;

logic input_start_alt_reg = 1'b0;
logic input_start_d0_reg = 1'b0;
logic input_start_d1_reg = 1'b0;
logic input_start_d2_reg = 1'b0;

logic [DATA_W-1:0] encoded_rx_data_reg = '0;
logic encoded_rx_data_valid_reg = 1'b0;
logic [HDR_W-1:0] encoded_rx_hdr_reg = '0;
logic encoded_rx_hdr_valid_reg = 1'b0;

logic frame_oversize_reg = 1'b0, frame_oversize_next;
logic pre_ok_reg = 1'b0, pre_ok_next;
logic [2:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [13:0] frame_len_lim_cyc_reg = '0, frame_len_lim_cyc_next;
logic [1:0] frame_len_lim_last_reg = '0, frame_len_lim_last_next;
logic frame_len_lim_check_reg = '0, frame_len_lim_check_next;

logic [DATA_W-1:0] m_axis_rx_tdata_reg = '0, m_axis_rx_tdata_next;
logic [KEEP_W-1:0] m_axis_rx_tkeep_reg = '0, m_axis_rx_tkeep_next;
logic m_axis_rx_tvalid_reg = 1'b0, m_axis_rx_tvalid_next;
logic m_axis_rx_tlast_reg = 1'b0, m_axis_rx_tlast_next;
logic m_axis_rx_tuser_reg = 1'b0, m_axis_rx_tuser_next;

logic start_packet_reg = 1'b0, start_packet_next;
logic frame_reg = 1'b0;

logic [2:0] stat_rx_byte_reg = '0, stat_rx_byte_next;
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

logic [PTP_TS_W-1:0] ptp_ts_out_reg = '0, ptp_ts_out_next;

logic [31:0] crc_state_reg = '1;

wire [31:0] crc_state;

wire [3:0] crc_valid;
logic [3:0] crc_valid_reg = '0;

assign crc_valid[3] = crc_state == ~32'h2144df1c;
assign crc_valid[2] = crc_state == ~32'hc622f71d;
assign crc_valid[1] = crc_state == ~32'hb1c2a1a3;
assign crc_valid[0] = crc_state == ~32'h9d6cdf7e;

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

wire last_cycle = state_reg == STATE_LAST;

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

    start_packet_next = 1'b0;

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
    end else begin
        // counter to measure frame length
        if (&frame_len_reg[15:2] == 0) begin
            if (term_present_reg) begin
                frame_len_next = frame_len_reg + 16'(term_lane_reg);
            end else begin
                frame_len_next = frame_len_reg + 16'(KEEP_W);
            end
        end else begin
            frame_len_next = '1;
        end

        // counter for max frame length enforcement
        if (frame_len_lim_cyc_reg != 0) begin
            frame_len_lim_cyc_next = frame_len_lim_cyc_reg - 1;
        end else begin
            frame_len_lim_cyc_next = '0;
        end

        if (frame_len_lim_cyc_reg == 2) begin
            frame_len_lim_check_next = 1'b1;
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
            3'd1: is_bcast_next = is_bcast_reg && &input_data_d2_reg[15:0];
            3'd3: is_8021q_next = {input_data_d2_reg[7:0], input_data_d2_reg[15:8]} == 16'h8100;
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
                {frame_len_lim_cyc_next, frame_len_lim_last_next} = cfg_rx_max_pkt_len;
                frame_len_lim_check_next = 1'b0;
                hdr_ptr_next = 0;

                pre_ok_next = input_data_d2_reg[31:8] == 24'h555555;

                if (input_start_d2_reg && cfg_rx_enable) begin
                    // start condition
                    if (framing_error_reg) begin
                        // control or error characters in first data word
                        stat_rx_err_framing_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        reset_crc = 1'b0;
                        stat_rx_byte_next = 3'(KEEP_W);
                        state_next = STATE_PREAMBLE;
                    end
                end else begin
                    if (PTP_TS_EN) begin
                        ptp_ts_out_next = ptp_ts;
                    end
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // drop preamble

                hdr_ptr_next = 0;

                pre_ok_next = pre_ok_reg && input_data_d2_reg == 32'hD5555555;

                if (framing_error_reg) begin
                    // control or error characters in packet
                    stat_rx_err_framing_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    start_packet_next = 1'b1;
                    stat_rx_byte_next = 3'(KEEP_W);
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_PAYLOAD: begin
                // read payload
                m_axis_rx_tdata_next = input_data_d2_reg;
                m_axis_rx_tkeep_next = {KEEP_W{1'b1}};
                m_axis_rx_tvalid_next = 1'b1;
                m_axis_rx_tlast_next = 1'b0;
                m_axis_rx_tuser_next = 1'b0;

                if (term_present_reg) begin
                    stat_rx_byte_next = 3'(term_lane_reg);
                    if (frame_len_lim_check_reg) begin
                        if (frame_len_lim_last_reg < term_lane_reg) begin
                            frame_oversize_next = 1'b1;
                        end
                    end
                end else begin
                    stat_rx_byte_next = 3'(KEEP_W);
                    if (frame_len_lim_check_reg) begin
                        // at the limit but this isn't a termination character
                        frame_oversize_next = 1'b1;
                    end
                end

                if (framing_error_reg) begin
                    // control or error characters in packet
                    m_axis_rx_tlast_next = 1'b1;
                    m_axis_rx_tuser_next = 1'b1;
                    stat_rx_pkt_bad_next = 1'b1;
                    stat_rx_pkt_len_next = frame_len_next;
                    stat_rx_pkt_ucast_next = !is_mcast_reg;
                    stat_rx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                    stat_rx_pkt_bcast_next = is_bcast_reg;
                    stat_rx_pkt_vlan_next = is_8021q_reg;
                    stat_rx_err_oversize_next = frame_oversize_next;
                    stat_rx_err_framing_next = 1'b1;
                    stat_rx_err_preamble_next = !pre_ok_reg;
                    stat_rx_pkt_fragment_next = frame_len_next[15:6] == 0;
                    stat_rx_pkt_jabber_next = frame_oversize_next;
                    reset_crc = 1'b1;
                    state_next = STATE_IDLE;
                end else if (term_first_cycle_reg) begin
                    // end this cycle
                    m_axis_rx_tkeep_next = 4'b1111;
                    m_axis_rx_tlast_next = 1'b1;
                    if (crc_valid_reg[3]) begin
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
                end else if (term_present_reg) begin
                    // need extra cycle
                    state_next = STATE_LAST;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_LAST: begin
                // last cycle of packet
                m_axis_rx_tdata_next = input_data_d2_reg;
                m_axis_rx_tkeep_next = {KEEP_W{1'b1}} >> 2'(KEEP_W-term_lane_d0_reg);
                m_axis_rx_tvalid_next = 1'b1;
                m_axis_rx_tlast_next = 1'b1;
                m_axis_rx_tuser_next = 1'b0;

                reset_crc = 1'b1;

                if ((term_lane_d0_reg == 1 && crc_valid_reg[0]) ||
                    (term_lane_d0_reg == 2 && crc_valid_reg[1]) ||
                    (term_lane_d0_reg == 3 && crc_valid_reg[2])) begin
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

    m_axis_rx_tdata_reg <= m_axis_rx_tdata_next;
    m_axis_rx_tkeep_reg <= m_axis_rx_tkeep_next;
    m_axis_rx_tvalid_reg <= m_axis_rx_tvalid_next;
    m_axis_rx_tlast_reg <= m_axis_rx_tlast_next;
    m_axis_rx_tuser_reg <= m_axis_rx_tuser_next;

    ptp_ts_out_reg <= ptp_ts_out_next;

    start_packet_reg <= start_packet_next;

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
        encoded_rx_data_reg <= encoded_rx_data;
        encoded_rx_data_valid_reg <= encoded_rx_data_valid;
        encoded_rx_hdr_reg <= encoded_rx_hdr;
        encoded_rx_hdr_valid_reg <= encoded_rx_hdr_valid;

        term_present_alt_reg <= 1'b0;
        term_present_reg <= term_present_alt_reg;
        term_first_cycle_alt_reg <= 1'b0;
        term_first_cycle_reg <= term_first_cycle_alt_reg;
        term_lane_alt_reg <= 0;
        term_lane_reg <= term_lane_alt_reg;
        term_lane_d0_reg <= term_lane_reg;

        input_data_d0_reg <= encoded_rx_data_reg;
        input_data_d1_reg <= input_data_d0_reg;
        input_data_d2_reg <= input_data_d1_reg;

        input_start_alt_reg <= 1'b0;
        input_start_d0_reg <= input_start_alt_reg;
        input_start_d1_reg <= input_start_d0_reg;
        input_start_d2_reg <= input_start_d1_reg;

        if (encoded_rx_hdr_valid_reg) begin
            // portion with header
            if (encoded_rx_hdr_reg[0] == 0) begin
                // data
                input_data_d0_reg <= encoded_rx_data_reg;
                framing_error_reg <= !frame_reg;
            end else begin
                // control
                case (encoded_rx_data_reg[7:4])
                    BLOCK_TYPE_CTRL[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_OS_4[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_START_4[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        input_start_alt_reg <= 1'b1;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b1;
                    end
                    BLOCK_TYPE_OS_START[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        input_start_alt_reg <= 1'b1;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b1;
                    end
                    BLOCK_TYPE_OS_04[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_START_0[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        input_start_d0_reg <= 1'b1;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b1;
                    end
                    BLOCK_TYPE_OS_0[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_0[7:4]: begin
                        input_data_d0_reg <= encoded_rx_data_reg; // don't care
                        term_present_reg <= 1'b1;
                        term_first_cycle_reg <= 1'b1;
                        term_lane_reg <= 0;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_1[7:4]: begin
                        input_data_d0_reg <= {24'd0, encoded_rx_data_reg[15:8]};
                        term_present_reg <= 1'b1;
                        term_lane_reg <= 1;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_2[7:4]: begin
                        input_data_d0_reg <= {16'd0, encoded_rx_data_reg[23:8]};
                        term_present_reg <= 1'b1;
                        term_lane_reg <= 2;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_3[7:4]: begin
                        input_data_d0_reg <= {8'd0, encoded_rx_data_reg[31:8]};
                        term_present_reg <= 1'b1;
                        term_lane_reg <= 3;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_4[7:4]: begin
                        input_data_d0_reg <= {encoded_rx_data[7:0], encoded_rx_data_reg[31:8]};
                        term_present_alt_reg <= 1'b1;
                        term_first_cycle_alt_reg <= 1'b1;
                        term_lane_alt_reg <= 0;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_5[7:4]: begin
                        input_data_d0_reg <= {encoded_rx_data[7:0], encoded_rx_data_reg[31:8]};
                        term_present_alt_reg <= 1'b1;
                        term_lane_alt_reg <= 1;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_6[7:4]: begin
                        input_data_d0_reg <= {encoded_rx_data[7:0], encoded_rx_data_reg[31:8]};
                        term_present_alt_reg <= 1'b1;
                        term_lane_alt_reg <= 2;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    BLOCK_TYPE_TERM_7[7:4]: begin
                        input_data_d0_reg <= {encoded_rx_data[7:0], encoded_rx_data_reg[31:8]};
                        term_present_alt_reg <= 1'b1;
                        term_lane_alt_reg <= 3;
                        framing_error_reg <= !frame_reg;
                        frame_reg <= 1'b0;
                    end
                    default: begin
                        // invalid block type
                        input_data_d0_reg <= encoded_rx_data_reg;
                        framing_error_reg <= frame_reg;
                        frame_reg <= 1'b0;
                    end
                endcase
            end

            // check all block type bits to detect bad encodings
            if (encoded_rx_hdr_reg == SYNC_DATA) begin
                // data - nothing encoded
            end else if (encoded_rx_hdr_reg == SYNC_CTRL) begin
                // control - check for bad block types
                case (encoded_rx_data_reg[7:0])
                    BLOCK_TYPE_CTRL: begin end
                    BLOCK_TYPE_OS_4: begin end
                    BLOCK_TYPE_START_4: begin end
                    BLOCK_TYPE_OS_START: begin end
                    BLOCK_TYPE_OS_04: begin end
                    BLOCK_TYPE_START_0: begin end
                    BLOCK_TYPE_OS_0: begin end
                    BLOCK_TYPE_TERM_0: begin end
                    BLOCK_TYPE_TERM_1: begin end
                    BLOCK_TYPE_TERM_2: begin end
                    BLOCK_TYPE_TERM_3: begin end
                    BLOCK_TYPE_TERM_4: begin end
                    BLOCK_TYPE_TERM_5: begin end
                    BLOCK_TYPE_TERM_6: begin end
                    BLOCK_TYPE_TERM_7: begin end
                    default: begin
                        // invalid block type
                        stat_rx_err_bad_block_reg <= 1'b1;
                    end
                endcase
            end else begin
                // invalid header
                stat_rx_err_bad_block_reg <= 1'b1;
            end
        end else begin
            input_data_d0_reg <= encoded_rx_data_reg;
            if (term_present_alt_reg) begin
                case (term_lane_alt_reg)
                    1: input_data_d0_reg <= {24'd0, encoded_rx_data_reg[15:8]};
                    2: input_data_d0_reg <= {16'd0, encoded_rx_data_reg[23:8]};
                    3: input_data_d0_reg <= {8'd0, encoded_rx_data_reg[31:8]};
                    default: input_data_d0_reg <= encoded_rx_data_reg;
                endcase
            end
        end

        if (reset_crc) begin
            crc_state_reg <= '1;
        end else begin
            crc_state_reg <= crc_state;
        end

        crc_valid_reg <= crc_valid;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        m_axis_rx_tvalid_reg <= 1'b0;

        start_packet_reg <= 1'b0;
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

        input_start_alt_reg <= 1'b0;
        input_start_d0_reg <= 1'b0;
        input_start_d1_reg <= 1'b0;
        input_start_d2_reg <= 1'b0;
    end
end

endmodule

`resetall
