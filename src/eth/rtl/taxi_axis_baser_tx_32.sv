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
 * AXI4-Stream 10GBASE-R frame transmitter (AXI in, 10GBASE-R out)
 */
module taxi_axis_baser_tx_32 #
(
    parameter DATA_W = 32,
    parameter HDR_W = 2,
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1,
    parameter logic PADDING_EN = 1'b1,
    parameter logic DIC_EN = 1'b1,
    parameter MIN_FRAME_LEN = 64,
    parameter logic PTP_TS_EN = 1'b0,
    parameter PTP_TS_W = 96,
    parameter logic TX_CPL_CTRL_IN_TUSER = 1'b1
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * Transmit interface (AXI stream)
     */
    taxi_axis_if.snk                  s_axis_tx,
    taxi_axis_if.src                  m_axis_tx_cpl,

    /*
     * 10GBASE-R encoded interface
     */
    output wire logic [DATA_W-1:0]    encoded_tx_data,
    output wire logic                 encoded_tx_data_valid,
    output wire logic [HDR_W-1:0]     encoded_tx_hdr,
    output wire logic                 encoded_tx_hdr_valid,
    input  wire logic [GBX_CNT-1:0]   tx_gbx_req_sync = '0,
    input  wire logic                 tx_gbx_req_stall = '0,
    output wire logic [GBX_CNT-1:0]   tx_gbx_sync,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_tx_max_pkt_len = 16'd1518,
    input  wire logic [7:0]           cfg_tx_ifg = 8'd12,
    input  wire logic                 cfg_tx_enable,

    /*
     * Status
     */
    output wire logic                 tx_start_packet,
    output wire logic [2:0]           stat_tx_byte,
    output wire logic [15:0]          stat_tx_pkt_len,
    output wire logic                 stat_tx_pkt_ucast,
    output wire logic                 stat_tx_pkt_mcast,
    output wire logic                 stat_tx_pkt_bcast,
    output wire logic                 stat_tx_pkt_vlan,
    output wire logic                 stat_tx_pkt_good,
    output wire logic                 stat_tx_pkt_bad,
    output wire logic                 stat_tx_err_oversize,
    output wire logic                 stat_tx_err_user,
    output wire logic                 stat_tx_err_underflow
);

// extract parameters
localparam KEEP_W = DATA_W/8;
localparam USER_W = TX_CPL_CTRL_IN_TUSER ? 2 : 1;
localparam TX_TAG_W = s_axis_tx.ID_W;

localparam EMPTY_W = $clog2(KEEP_W);
localparam MIN_LEN_W = $clog2(MIN_FRAME_LEN-4-KEEP_W+1);

// check configuration
if (DATA_W != 32)
    $fatal(0, "Error: Interface width must be 32 (instance %m)");

if (KEEP_W*8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2 (instance %m)");

if (s_axis_tx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (s_axis_tx.USER_W != USER_W)
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

typedef enum logic [2:0] {
    OUTPUT_TYPE_IDLE = 3'd0,
    OUTPUT_TYPE_ERROR = 3'd1,
    OUTPUT_TYPE_START = 3'd2,
    OUTPUT_TYPE_DATA = 3'd3,
    OUTPUT_TYPE_TERM_0 = 3'd4,
    OUTPUT_TYPE_TERM_1 = 3'd5,
    OUTPUT_TYPE_TERM_2 = 3'd6,
    OUTPUT_TYPE_TERM_3 = 3'd7
} out_type_t;

typedef enum logic [3:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PAYLOAD,
    STATE_PAD,
    STATE_FCS_1,
    STATE_FCS_2,
    STATE_FCS_3,
    STATE_ERR,
    STATE_IFG
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic [DATA_W-1:0] s_tdata_reg = '0, s_tdata_next;
logic [EMPTY_W-1:0] s_empty_reg = '0, s_empty_next;

logic [DATA_W-1:0] fcs_output_data_0;
logic [DATA_W-1:0] fcs_output_data_1;
out_type_t fcs_output_type_0;
out_type_t fcs_output_type_1;

logic [7:0] ifg_offset;

logic extra_cycle;

logic frame_reg = 1'b0, frame_next;
logic frame_error_reg = 1'b0, frame_error_next;
logic frame_oversize_reg = 1'b0, frame_oversize_next;
logic [MIN_LEN_W-1:0] frame_min_count_reg = '0, frame_min_count_next;
logic [2:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [13:0] frame_len_lim_cyc_reg = '0, frame_len_lim_cyc_next;
logic [1:0] frame_len_lim_last_reg = '0, frame_len_lim_last_next;
logic frame_len_lim_check_reg = '0, frame_len_lim_check_next;
logic [7:0] ifg_cnt_reg = '0, ifg_cnt_next;

logic [7:0] ifg_count_reg = 8'd0, ifg_count_next;
logic [1:0] deficit_idle_count_reg = 2'd0, deficit_idle_count_next;

logic s_axis_tx_tready_reg = 1'b0, s_axis_tx_tready_next;

logic [PTP_TS_W-1:0] m_axis_tx_cpl_ts_reg = '0, m_axis_tx_cpl_ts_next;
logic [TX_TAG_W-1:0] m_axis_tx_cpl_tag_reg = '0, m_axis_tx_cpl_tag_next;
logic m_axis_tx_cpl_valid_reg = 1'b0, m_axis_tx_cpl_valid_next;

logic [31:0] crc_state_reg[4];
wire [31:0] crc_state[4];

logic [DATA_W-1:0] encoded_tx_data_reg = {24'd0, BLOCK_TYPE_CTRL};
logic encoded_tx_data_valid_reg = 1'b0;
logic [HDR_W-1:0] encoded_tx_hdr_reg = SYNC_CTRL;
logic encoded_tx_hdr_valid_reg = 1'b0;
logic phase_reg = 1'b0;
logic [GBX_CNT-1:0] tx_gbx_sync_reg = '0;

logic [DATA_W-1:0] output_data_reg = '0, output_data_next;
logic [DATA_W-1:0] output_data_d1_reg = '0;
out_type_t output_type_reg = OUTPUT_TYPE_IDLE, output_type_next;

logic start_packet_reg = 1'b0, start_packet_next;

logic [2:0] stat_tx_byte_reg = '0, stat_tx_byte_next;
logic [15:0] stat_tx_pkt_len_reg = '0, stat_tx_pkt_len_next;
logic stat_tx_pkt_ucast_reg = 1'b0, stat_tx_pkt_ucast_next;
logic stat_tx_pkt_mcast_reg = 1'b0, stat_tx_pkt_mcast_next;
logic stat_tx_pkt_bcast_reg = 1'b0, stat_tx_pkt_bcast_next;
logic stat_tx_pkt_vlan_reg = 1'b0, stat_tx_pkt_vlan_next;
logic stat_tx_pkt_good_reg = 1'b0, stat_tx_pkt_good_next;
logic stat_tx_pkt_bad_reg = 1'b0, stat_tx_pkt_bad_next;
logic stat_tx_err_oversize_reg = 1'b0, stat_tx_err_oversize_next;
logic stat_tx_err_user_reg = 1'b0, stat_tx_err_user_next;
logic stat_tx_err_underflow_reg = 1'b0, stat_tx_err_underflow_next;

assign s_axis_tx.tready = s_axis_tx_tready_reg && (!GBX_IF_EN || !tx_gbx_req_stall);

assign encoded_tx_data = encoded_tx_data_reg;
assign encoded_tx_data_valid = GBX_IF_EN ? encoded_tx_data_valid_reg : 1'b1;
assign encoded_tx_hdr = encoded_tx_hdr_reg;
assign encoded_tx_hdr_valid = encoded_tx_hdr_valid_reg;
assign tx_gbx_sync = GBX_IF_EN ? tx_gbx_sync_reg : '0;

assign m_axis_tx_cpl.tdata = PTP_TS_EN ? m_axis_tx_cpl_ts_reg : '0;
assign m_axis_tx_cpl.tkeep = 1'b1;
assign m_axis_tx_cpl.tstrb = m_axis_tx_cpl.tkeep;
assign m_axis_tx_cpl.tvalid = m_axis_tx_cpl_valid_reg;
assign m_axis_tx_cpl.tlast = 1'b1;
assign m_axis_tx_cpl.tid = m_axis_tx_cpl_tag_reg;
assign m_axis_tx_cpl.tdest = '0;
assign m_axis_tx_cpl.tuser = '0;

assign tx_start_packet = start_packet_reg;

assign stat_tx_byte = stat_tx_byte_reg;
assign stat_tx_pkt_len = stat_tx_pkt_len_reg;
assign stat_tx_pkt_ucast = stat_tx_pkt_ucast_reg;
assign stat_tx_pkt_mcast = stat_tx_pkt_mcast_reg;
assign stat_tx_pkt_bcast = stat_tx_pkt_bcast_reg;
assign stat_tx_pkt_vlan = stat_tx_pkt_vlan_reg;
assign stat_tx_pkt_good = stat_tx_pkt_good_reg;
assign stat_tx_pkt_bad = stat_tx_pkt_bad_reg;
assign stat_tx_err_oversize = stat_tx_err_oversize_reg;
assign stat_tx_err_user = stat_tx_err_user_reg;
assign stat_tx_err_underflow = stat_tx_err_underflow_reg;

for (genvar n = 0; n < 4; n = n + 1) begin : crc

    taxi_lfsr #(
        .LFSR_W(32),
        .LFSR_POLY(32'h4c11db7),
        .LFSR_GALOIS(1),
        .LFSR_FEED_FORWARD(0),
        .REVERSE(1),
        .DATA_W(8*(n+1)),
        .DATA_IN_EN(1'b1),
        .DATA_OUT_EN(1'b0)
    )
    eth_crc (
        .data_in(s_tdata_reg[0 +: 8*(n+1)]),
        .state_in(crc_state_reg[3]),
        .data_out(),
        .state_out(crc_state[n])
    );

end

function [1:0] keep2empty(input [3:0] k);
    casez (k)
        4'bzzz0: keep2empty = 2'd3;
        4'bzz01: keep2empty = 2'd3;
        4'bz011: keep2empty = 2'd2;
        4'b0111: keep2empty = 2'd1;
        4'b1111: keep2empty = 2'd0;
    endcase
endfunction

// Mask input data
wire [DATA_W-1:0] s_axis_tx_tdata_masked;

for (genvar n = 0; n < KEEP_W; n = n + 1) begin
    assign s_axis_tx_tdata_masked[n*8 +: 8] = (n == 0 || s_axis_tx.tkeep[n]) ? s_axis_tx.tdata[n*8 +: 8] : 8'd0;
end

// FCS cycle calculation
always_comb begin
    casez (s_empty_reg)
        2'd3: begin
            fcs_output_data_0 = {~crc_state[0][23:0], s_tdata_reg[7:0]};
            fcs_output_data_1 = {24'd0, ~crc_state_reg[0][31:24]};
            fcs_output_type_0 = OUTPUT_TYPE_DATA;
            fcs_output_type_1 = OUTPUT_TYPE_TERM_1;
            ifg_offset = 8'd3;
            extra_cycle = 1'b0;
        end
        2'd2: begin
            fcs_output_data_0 = {~crc_state[1][15:0], s_tdata_reg[15:0]};
            fcs_output_data_1 = {16'd0, ~crc_state_reg[1][31:16]};
            fcs_output_type_0 = OUTPUT_TYPE_DATA;
            fcs_output_type_1 = OUTPUT_TYPE_TERM_2;
            ifg_offset = 8'd2;
            extra_cycle = 1'b0;
        end
        2'd1: begin
            fcs_output_data_0 = {~crc_state[2][7:0], s_tdata_reg[23:0]};
            fcs_output_data_1 = {8'd0, ~crc_state_reg[2][31:8]};
            fcs_output_type_0 = OUTPUT_TYPE_DATA;
            fcs_output_type_1 = OUTPUT_TYPE_TERM_3;
            ifg_offset = 8'd1;
            extra_cycle = 1'b0;
        end
        2'd0: begin
            fcs_output_data_0 = s_tdata_reg;
            fcs_output_data_1 = ~crc_state_reg[3];
            fcs_output_type_0 = OUTPUT_TYPE_DATA;
            fcs_output_type_1 = OUTPUT_TYPE_DATA;
            ifg_offset = 8'd4;
            extra_cycle = 1'b1;
        end
    endcase
end

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_next = frame_reg;
    frame_error_next = frame_error_reg;
    frame_oversize_next = frame_oversize_reg;
    frame_min_count_next = frame_min_count_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_cyc_next = frame_len_lim_cyc_reg;
    frame_len_lim_last_next = frame_len_lim_last_reg;
    frame_len_lim_check_next = frame_len_lim_check_reg;
    ifg_cnt_next = ifg_cnt_reg;

    ifg_count_next = ifg_count_reg;
    deficit_idle_count_next = deficit_idle_count_reg;

    s_axis_tx_tready_next = 1'b0;

    s_tdata_next = s_tdata_reg;
    s_empty_next = s_empty_reg;

    m_axis_tx_cpl_ts_next = m_axis_tx_cpl_ts_reg;
    m_axis_tx_cpl_tag_next = m_axis_tx_cpl_tag_reg;
    m_axis_tx_cpl_valid_next = 1'b0;

    if (start_packet_reg) begin
        if (PTP_TS_EN) begin
            m_axis_tx_cpl_ts_next = ptp_ts;
        end
        if (TX_CPL_CTRL_IN_TUSER) begin
            m_axis_tx_cpl_valid_next = (s_axis_tx.tuser >> 1) == 0;
        end else begin
            m_axis_tx_cpl_valid_next = 1'b1;
        end
    end

    output_data_next = s_tdata_reg;
    output_type_next = OUTPUT_TYPE_IDLE;

    start_packet_next = 1'b0;

    stat_tx_byte_next = '0;
    stat_tx_pkt_len_next = '0;
    stat_tx_pkt_ucast_next = 1'b0;
    stat_tx_pkt_mcast_next = 1'b0;
    stat_tx_pkt_bcast_next = 1'b0;
    stat_tx_pkt_vlan_next = 1'b0;
    stat_tx_pkt_good_next = 1'b0;
    stat_tx_pkt_bad_next = 1'b0;
    stat_tx_err_oversize_next = 1'b0;
    stat_tx_err_user_next = 1'b0;
    stat_tx_err_underflow_next = 1'b0;

    if (s_axis_tx.tvalid && s_axis_tx.tready) begin
        frame_next = !s_axis_tx.tlast;
    end

    if (GBX_IF_EN && tx_gbx_req_stall) begin
        // gearbox stall - hold state
        state_next = state_reg;
        s_axis_tx_tready_next = s_axis_tx_tready_reg;
    end else begin
        // counter for min frame length enforcement
        if (frame_min_count_reg > MIN_LEN_W'(KEEP_W)) begin
            frame_min_count_next = MIN_LEN_W'(frame_min_count_reg - KEEP_W);
        end else begin
            frame_min_count_next = 0;
        end

        // counter to measure frame length
        if (&frame_len_reg[15:2] == 0) begin
            frame_len_next = frame_len_reg + 16'(KEEP_W);
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
                is_mcast_next = s_tdata_reg[0];
                is_bcast_next = &s_tdata_reg;
            end
            3'd1: is_bcast_next = is_bcast_reg && &s_tdata_reg[15:0];
            3'd3: is_8021q_next = {s_tdata_reg[7:0], s_tdata_reg[15:8]} == 16'h8100;
            default: begin
                // do nothing
            end
        endcase

        if (ifg_cnt_reg[7:2] != 0) begin
            ifg_cnt_next = ifg_cnt_reg - 8'(KEEP_W);
        end else begin
            ifg_cnt_next = '0;
        end

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for data
                frame_error_next = 1'b0;
                frame_oversize_next = 1'b0;
                frame_min_count_next = MIN_LEN_W'(MIN_FRAME_LEN-4);
                hdr_ptr_next = 0;
                frame_len_next = 0;
                {frame_len_lim_cyc_next, frame_len_lim_last_next} = cfg_tx_max_pkt_len-1;
                frame_len_lim_check_next = 1'b0;
                reset_crc = 1'b1;

                output_data_next = s_tdata_reg;
                output_type_next = OUTPUT_TYPE_IDLE;

                s_tdata_next = s_axis_tx_tdata_masked;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                m_axis_tx_cpl_tag_next = s_axis_tx.tid;

                if (s_axis_tx.tvalid && cfg_tx_enable) begin
                    // Preamble and SFD
                    output_data_next = {4{ETH_PRE}};
                    output_type_next = OUTPUT_TYPE_START;
                    s_axis_tx_tready_next = 1'b1;
                    state_next = STATE_PREAMBLE;
                end else begin
                    ifg_count_next = 8'd0;
                    deficit_idle_count_next = 2'd0;
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // send preamble
                reset_crc = 1'b1;

                hdr_ptr_next = 0;
                frame_len_next = 0;

                s_tdata_next = s_axis_tx_tdata_masked;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                output_data_next = {ETH_SFD, {3{ETH_PRE}}};
                output_type_next = OUTPUT_TYPE_DATA;

                s_axis_tx_tready_next = 1'b1;
                start_packet_next = 1'b1;
                state_next = STATE_PAYLOAD;
            end
            STATE_PAYLOAD: begin
                // transfer payload
                update_crc = 1'b1;
                s_axis_tx_tready_next = 1'b1;

                output_data_next = s_tdata_reg;
                output_type_next = OUTPUT_TYPE_DATA;

                s_tdata_next = s_axis_tx_tdata_masked;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                stat_tx_byte_next = 3'(KEEP_W);

                if (s_axis_tx.tvalid && s_axis_tx.tlast) begin
                    if (frame_len_lim_check_reg) begin
                        if (frame_len_lim_last_reg < 2'(3-keep2empty(s_axis_tx.tkeep))) begin
                            frame_oversize_next = 1'b1;
                        end
                    end
                end else begin
                    if (frame_len_lim_check_reg) begin
                        // at the limit but the frame doesn't end in this cycle
                        frame_oversize_next = 1'b1;
                    end
                end

                if (PADDING_EN && frame_min_count_reg != 0) begin
                    if (frame_min_count_reg > MIN_LEN_W'(KEEP_W)) begin
                        s_empty_next = 0;
                    end else if (keep2empty(s_axis_tx.tkeep) > 2'(KEEP_W-frame_min_count_reg)) begin
                        s_empty_next = 2'(KEEP_W-frame_min_count_reg);
                    end
                end

                if (!s_axis_tx.tvalid || s_axis_tx.tlast || frame_oversize_next) begin
                    s_axis_tx_tready_next = frame_next; // drop frame
                    frame_error_next = !s_axis_tx.tvalid || s_axis_tx.tuser[0] || frame_oversize_next;
                    stat_tx_err_user_next = s_axis_tx.tuser[0];
                    stat_tx_err_underflow_next = !s_axis_tx.tvalid;

                    if (PADDING_EN && frame_min_count_reg != 0 && frame_min_count_reg > MIN_LEN_W'(KEEP_W)) begin
                        state_next = STATE_PAD;
                    end else begin
                        state_next = STATE_FCS_1;
                    end
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_PAD: begin
                // pad frame to MIN_FRAME_LEN
                s_axis_tx_tready_next = frame_next; // drop frame

                output_data_next = s_tdata_reg;
                output_type_next = OUTPUT_TYPE_DATA;

                s_tdata_next = 32'd0;
                s_empty_next = 0;

                stat_tx_byte_next = 3'(KEEP_W);

                update_crc = 1'b1;

                if (frame_min_count_reg > MIN_LEN_W'(KEEP_W)) begin
                    state_next = STATE_PAD;
                end else begin
                    s_empty_next = 2'(KEEP_W-frame_min_count_reg);
                    state_next = STATE_FCS_1;
                end
            end
            STATE_FCS_1: begin
                // last cycle
                s_axis_tx_tready_next = frame_next; // drop frame

                output_data_next = fcs_output_data_0;
                output_type_next = fcs_output_type_0;

                stat_tx_byte_next = 3'(KEEP_W);

                update_crc = 1'b1;

                ifg_count_next = (cfg_tx_ifg > 8'd12 ? cfg_tx_ifg : 8'd12) - ifg_offset + 8'(deficit_idle_count_reg);
                if (frame_error_reg) begin
                    state_next = STATE_ERR;
                end else begin
                    state_next = STATE_FCS_2;
                end
            end
            STATE_FCS_2: begin
                // last cycle
                s_axis_tx_tready_next = frame_next; // drop frame

                output_data_next = fcs_output_data_1;
                output_type_next = fcs_output_type_1;

                stat_tx_byte_next = 4-s_empty_reg;
                frame_len_next = frame_len_reg + 16'(4-s_empty_reg);

                if (extra_cycle) begin
                    state_next = STATE_FCS_3;
                end else begin
                    stat_tx_pkt_len_next = frame_len_next;
                    stat_tx_pkt_good_next = !frame_error_reg;
                    stat_tx_pkt_bad_next = frame_error_reg;
                    stat_tx_pkt_ucast_next = !is_mcast_reg;
                    stat_tx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                    stat_tx_pkt_bcast_next = is_bcast_reg;
                    stat_tx_pkt_vlan_next = is_8021q_reg;
                    stat_tx_err_oversize_next = frame_oversize_reg;
                    state_next = STATE_IFG;
                end
            end
            STATE_FCS_3: begin
                // last cycle
                s_axis_tx_tready_next = frame_next; // drop frame

                output_data_next = s_tdata_reg;
                output_type_next = OUTPUT_TYPE_TERM_0;

                stat_tx_pkt_len_next = frame_len_reg;
                stat_tx_pkt_good_next = !frame_error_reg;
                stat_tx_pkt_bad_next = frame_error_reg;
                stat_tx_pkt_ucast_next = !is_mcast_reg;
                stat_tx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                stat_tx_pkt_bcast_next = is_bcast_reg;
                stat_tx_pkt_vlan_next = is_8021q_reg;
                stat_tx_err_oversize_next = frame_oversize_reg;

                if (DIC_EN) begin
                    if (ifg_count_next > 8'd3) begin
                        state_next = STATE_IFG;
                    end else begin
                        deficit_idle_count_next = 2'(ifg_count_next);
                        ifg_count_next = 8'd0;
                        s_axis_tx_tready_next = 1'b1;
                        state_next = STATE_IDLE;
                    end
                end else begin
                    if (ifg_count_next > 8'd0) begin
                        state_next = STATE_IFG;
                    end else begin
                        state_next = STATE_IDLE;
                    end
                end
            end
            STATE_ERR: begin
                // terminate packet with error
                s_axis_tx_tready_next = frame_next; // drop frame

                output_data_next = s_tdata_reg;
                output_type_next = OUTPUT_TYPE_ERROR;

                ifg_count_next = cfg_tx_ifg > 8'd12 ? cfg_tx_ifg : 8'd12;

                stat_tx_pkt_len_next = frame_len_reg;
                stat_tx_pkt_good_next = !frame_error_reg;
                stat_tx_pkt_bad_next = frame_error_reg;
                stat_tx_pkt_ucast_next = !is_mcast_reg;
                stat_tx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                stat_tx_pkt_bcast_next = is_bcast_reg;
                stat_tx_pkt_vlan_next = is_8021q_reg;
                stat_tx_err_oversize_next = frame_oversize_reg;

                state_next = STATE_IFG;
            end
            STATE_IFG: begin
                // send IFG
                s_axis_tx_tready_next = frame_next; // drop frame

                output_data_next = s_tdata_reg;
                output_type_next = OUTPUT_TYPE_IDLE;

                if (ifg_count_reg > 8'd4) begin
                    ifg_count_next = ifg_count_reg - 8'd4;
                end else begin
                    ifg_count_next = 8'd0;
                end

                if (DIC_EN) begin
                    if (ifg_count_next > 8'd3 || frame_reg) begin
                        state_next = STATE_IFG;
                    end else begin
                        deficit_idle_count_next = 2'(ifg_count_next);
                        ifg_count_next = 8'd0;
                        state_next = STATE_IDLE;
                    end
                end else begin
                    if (ifg_count_next > 8'd0 || frame_reg) begin
                        state_next = STATE_IFG;
                    end else begin
                        state_next = STATE_IDLE;
                    end
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

    frame_reg <= frame_next;
    frame_error_reg <= frame_error_next;
    frame_oversize_reg <= frame_oversize_next;
    frame_min_count_reg <= frame_min_count_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_cyc_reg <= frame_len_lim_cyc_next;
    frame_len_lim_last_reg <= frame_len_lim_last_next;
    frame_len_lim_check_reg <= frame_len_lim_check_next;
    ifg_cnt_reg <= ifg_cnt_next;

    ifg_count_reg <= ifg_count_next;
    deficit_idle_count_reg <= deficit_idle_count_next;

    s_tdata_reg <= s_tdata_next;
    s_empty_reg <= s_empty_next;

    s_axis_tx_tready_reg <= s_axis_tx_tready_next;

    m_axis_tx_cpl_ts_reg <= m_axis_tx_cpl_ts_next;
    m_axis_tx_cpl_tag_reg <= m_axis_tx_cpl_tag_next;
    m_axis_tx_cpl_valid_reg <= m_axis_tx_cpl_valid_next;

    start_packet_reg <= start_packet_next;

    stat_tx_byte_reg <= stat_tx_byte_next;
    stat_tx_pkt_len_reg <= stat_tx_pkt_len_next;
    stat_tx_pkt_ucast_reg <= stat_tx_pkt_ucast_next;
    stat_tx_pkt_mcast_reg <= stat_tx_pkt_mcast_next;
    stat_tx_pkt_bcast_reg <= stat_tx_pkt_bcast_next;
    stat_tx_pkt_vlan_reg <= stat_tx_pkt_vlan_next;
    stat_tx_pkt_good_reg <= stat_tx_pkt_good_next;
    stat_tx_pkt_bad_reg <= stat_tx_pkt_bad_next;
    stat_tx_err_oversize_reg <= stat_tx_err_oversize_next;
    stat_tx_err_user_reg <= stat_tx_err_user_next;
    stat_tx_err_underflow_reg <= stat_tx_err_underflow_next;

    if (GBX_IF_EN && tx_gbx_req_stall) begin
        // gearbox stall
        encoded_tx_data_valid_reg <= 1'b0;
        encoded_tx_hdr_valid_reg <= 1'b0;
    end else begin
        output_data_reg <= output_data_next;
        output_type_reg <= output_type_next;
        output_data_d1_reg <= output_data_reg;

        if (phase_reg == 0) begin
            case ({output_type_reg, output_type_next})
                {OUTPUT_TYPE_IDLE, OUTPUT_TYPE_IDLE}: begin
                    encoded_tx_data_reg <= {24'd0, BLOCK_TYPE_CTRL};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_ERROR, OUTPUT_TYPE_ERROR}: begin
                    encoded_tx_data_reg <= {24'hc78f1e, BLOCK_TYPE_CTRL};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_START, OUTPUT_TYPE_DATA}: begin
                    encoded_tx_data_reg <= {output_data_reg[31:8], BLOCK_TYPE_START_0};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_IDLE, OUTPUT_TYPE_START}: begin
                    encoded_tx_data_reg <= {24'd0, BLOCK_TYPE_START_4};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_DATA, OUTPUT_TYPE_DATA}: begin
                    encoded_tx_data_reg <= output_data_reg;
                    encoded_tx_hdr_reg <= SYNC_DATA;
                end
                {OUTPUT_TYPE_TERM_0, OUTPUT_TYPE_IDLE}: begin
                    encoded_tx_data_reg <= {24'd0, BLOCK_TYPE_TERM_0};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_TERM_1, OUTPUT_TYPE_IDLE}: begin
                    encoded_tx_data_reg <= {16'd0, output_data_reg[7:0], BLOCK_TYPE_TERM_1};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_TERM_2, OUTPUT_TYPE_IDLE}: begin
                    encoded_tx_data_reg <= {8'd0, output_data_reg[15:0], BLOCK_TYPE_TERM_2};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_TERM_3, OUTPUT_TYPE_IDLE}: begin
                    encoded_tx_data_reg <= {output_data_reg[23:0], BLOCK_TYPE_TERM_3};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_DATA, OUTPUT_TYPE_TERM_0}: begin
                    encoded_tx_data_reg <= {output_data_reg[23:0], BLOCK_TYPE_TERM_4};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_DATA, OUTPUT_TYPE_TERM_1}: begin
                    encoded_tx_data_reg <= {output_data_reg[23:0], BLOCK_TYPE_TERM_5};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_DATA, OUTPUT_TYPE_TERM_2}: begin
                    encoded_tx_data_reg <= {output_data_reg[23:0], BLOCK_TYPE_TERM_6};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                {OUTPUT_TYPE_DATA, OUTPUT_TYPE_TERM_3}: begin
                    encoded_tx_data_reg <= {output_data_reg[23:0], BLOCK_TYPE_TERM_7};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
                default: begin
                    encoded_tx_data_reg <= {24'hc78f1e, BLOCK_TYPE_CTRL};
                    encoded_tx_hdr_reg <= SYNC_CTRL;
                end
            endcase
        end else begin
            case (output_type_reg)
                OUTPUT_TYPE_IDLE: begin
                    encoded_tx_data_reg <= 32'd0;
                end
                OUTPUT_TYPE_ERROR: begin
                    encoded_tx_data_reg <= 32'h3c78f1e3; // CTRL_ERROR
                end
                OUTPUT_TYPE_START: begin
                    encoded_tx_data_reg <= {output_data_reg[31:8], 8'd0};
                end
                OUTPUT_TYPE_DATA: begin
                    encoded_tx_data_reg <= output_data_reg;
                end
                OUTPUT_TYPE_TERM_0: begin
                    encoded_tx_data_reg <= {24'd0, output_data_d1_reg[31:24]};
                end
                OUTPUT_TYPE_TERM_1: begin
                    encoded_tx_data_reg <= {16'd0, output_data_reg[7:0], output_data_d1_reg[31:24]};
                end
                OUTPUT_TYPE_TERM_2: begin
                    encoded_tx_data_reg <= {8'd0, output_data_reg[15:0], output_data_d1_reg[31:24]};
                end
                OUTPUT_TYPE_TERM_3: begin
                    encoded_tx_data_reg <= {output_data_reg[23:0], output_data_d1_reg[31:24]};
                end
                default: begin
                    encoded_tx_data_reg <= 32'h3c78f1e3; // CTRL_ERROR
                end
            endcase
        end

        encoded_tx_data_valid_reg <= 1'b1;
        encoded_tx_hdr_valid_reg <= phase_reg == 0;
        phase_reg <= !phase_reg;

        if (GBX_IF_EN && tx_gbx_req_sync[0]) begin
            phase_reg <= 1'b1;
        end

        for (integer i = 0; i < 3; i = i + 1) begin
            crc_state_reg[i] <= crc_state[i];
        end

        if (update_crc) begin
            crc_state_reg[3] <= crc_state[3];
        end

        if (reset_crc) begin
            crc_state_reg[3] <= '1;
        end
    end

    tx_gbx_sync_reg <= tx_gbx_req_sync;

    if (rst) begin
        state_reg <= STATE_IDLE;

        frame_reg <= 1'b0;

        ifg_count_reg <= 8'd0;
        deficit_idle_count_reg <= 2'd0;

        s_axis_tx_tready_reg <= 1'b0;

        m_axis_tx_cpl_valid_reg <= 1'b0;

        encoded_tx_data_reg <= {24'd0, BLOCK_TYPE_CTRL};
        encoded_tx_data_valid_reg <= 1'b0;
        encoded_tx_hdr_reg <= SYNC_CTRL;
        encoded_tx_hdr_valid_reg <= 1'b0;
        phase_reg <= 1'b0;
        tx_gbx_sync_reg <= '0;

        output_type_reg <= OUTPUT_TYPE_IDLE;

        start_packet_reg <= 1'b0;

        stat_tx_byte_reg <= '0;
        stat_tx_pkt_len_reg <= '0;
        stat_tx_pkt_ucast_reg <= 1'b0;
        stat_tx_pkt_mcast_reg <= 1'b0;
        stat_tx_pkt_bcast_reg <= 1'b0;
        stat_tx_pkt_vlan_reg <= 1'b0;
        stat_tx_pkt_good_reg <= 1'b0;
        stat_tx_pkt_bad_reg <= 1'b0;
        stat_tx_err_oversize_reg <= 1'b0;
        stat_tx_err_user_reg <= 1'b0;
        stat_tx_err_underflow_reg <= 1'b0;
    end
end

endmodule

`resetall
