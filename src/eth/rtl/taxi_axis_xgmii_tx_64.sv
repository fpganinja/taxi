// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2015-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream XGMII frame transmitter (AXI in, XGMII out)
 */
module taxi_axis_xgmii_tx_64 #
(
    parameter DATA_W = 64,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
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
     * XGMII output
     */
    output wire logic [DATA_W-1:0]    xgmii_txd,
    output wire logic [CTRL_W-1:0]    xgmii_txc,
    output wire logic                 xgmii_tx_valid,
    input  wire logic [GBX_CNT-1:0]   tx_gbx_req_sync = '0,
    input  wire logic                 tx_gbx_req_stall = '0,
    output wire logic [GBX_CNT-1:0]   tx_gbx_sync,

    /*
     * Ordered sets
     */
    input  wire logic [23:0]          tx_os = '0,
    input  wire logic                 tx_os_sig = 1'b0,
    input  wire logic                 tx_os_valid = 1'b0,
    output wire logic                 tx_os_ready,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_tx_max_pkt_len = 16'd1518-1,
    input  wire logic [7:0]           cfg_tx_ifg = 8'd12,
    input  wire logic                 cfg_tx_enable,

    /*
     * Status
     */
    output wire logic [1:0]           tx_start_packet,
    output wire logic [3:0]           stat_tx_byte,
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

// check configuration
if (DATA_W != 64)
    $fatal(0, "Error: Interface width must be 64 (instance %m)");

if (KEEP_W*8 != DATA_W || CTRL_W*8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (s_axis_tx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (s_axis_tx.USER_W != USER_W)
    $fatal(0, "Error: Interface USER_W parameter mismatch (instance %m)");

typedef enum logic [7:0] {
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5
} eth_pre_t;

typedef enum logic [7:0] {
    XGMII_IDLE   = 8'h07,
    XGMII_LPI    = 8'h06,
    XGMII_START  = 8'hfb,
    XGMII_TERM   = 8'hfd,
    XGMII_ERROR  = 8'hfe,
    XGMII_SEQ_OS = 8'h9c,
    XGMII_RES_0  = 8'h1c,
    XGMII_RES_1  = 8'h3c,
    XGMII_RES_2  = 8'h7c,
    XGMII_RES_3  = 8'hbc,
    XGMII_RES_4  = 8'hdc,
    XGMII_RES_5  = 8'hf7,
    XGMII_SIG_OS = 8'h5c
} xgmii_ctrl_t;

typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_PAYLOAD,
    STATE_FCS_1,
    STATE_FCS_2,
    STATE_ERR,
    STATE_IFG
} state_t;

state_t state_reg = STATE_IDLE, state_next;

logic swap_lanes_reg = 1'b0, swap_lanes_next;
logic [31:0] swap_txd_reg = 32'd0;
logic [3:0] swap_txc_reg = 4'd0;

logic [DATA_W-1:0] s_tdata_reg = '0, s_tdata_next;
logic [EMPTY_W-1:0] s_empty_reg = '0, s_empty_next;

logic [DATA_W-1:0] fcs_output_txd_0;
logic [DATA_W-1:0] fcs_output_txd_1;
logic [CTRL_W-1:0] fcs_output_txc_0;
logic [CTRL_W-1:0] fcs_output_txc_1;

logic [7:0] ifg_offset;
logic extra_cycle;

logic frame_start_reg = 1'b0, frame_start_next;
logic frame_reg = 1'b0, frame_next;
logic frame_error_reg = 1'b0, frame_error_next;
logic frame_oversize_reg = 1'b0, frame_oversize_next;
logic [1:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [12:0] frame_len_lim_cyc_reg = '0, frame_len_lim_cyc_next;
logic [2:0] frame_len_lim_last_reg = '0, frame_len_lim_last_next;
logic frame_len_lim_check_reg = '0, frame_len_lim_check_next;
logic [7:0] ifg_cnt_reg = '0, ifg_cnt_next;
logic [1:0] deficit_idle_cnt_reg = 2'd0, deficit_idle_cnt_next;

logic s_axis_tx_tready_reg = 1'b0, s_axis_tx_tready_next;

logic [PTP_TS_W-1:0] m_axis_tx_cpl_ts_reg = '0;
logic [PTP_TS_W-1:0] m_axis_tx_cpl_ts_adj_reg = '0;
logic [TX_TAG_W-1:0] m_axis_tx_cpl_tag_reg = '0, m_axis_tx_cpl_tag_next;
logic m_axis_tx_cpl_valid_reg = 1'b0;
logic m_axis_tx_cpl_valid_int_reg = 1'b0;
logic m_axis_tx_cpl_ts_borrow_reg = 1'b0;

logic tx_os_ready_reg = 1'b0, tx_os_ready_next;

logic [4+16-1:0] last_ts_reg = '0;
logic [4+16-1:0] ts_inc_reg = '0;

logic [DATA_W-1:0] xgmii_txd_reg = {CTRL_W{XGMII_IDLE}}, xgmii_txd_next;
logic [CTRL_W-1:0] xgmii_txc_reg = {CTRL_W{1'b1}}, xgmii_txc_next;
logic xgmii_tx_valid_reg = 1'b0;
logic [GBX_CNT-1:0] tx_gbx_sync_reg = '0;

logic [1:0] start_packet_reg = 2'b00;

logic [3:0] stat_tx_byte_reg = '0, stat_tx_byte_next;
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

assign xgmii_txd = xgmii_txd_reg;
assign xgmii_txc = xgmii_txc_reg;
assign xgmii_tx_valid = GBX_IF_EN ? xgmii_tx_valid_reg : 1'b1;
assign tx_gbx_sync = GBX_IF_EN ? tx_gbx_sync_reg : '0;

assign m_axis_tx_cpl.tdata = PTP_TS_EN ? ((!PTP_TS_FMT_TOD || m_axis_tx_cpl_ts_borrow_reg) ? m_axis_tx_cpl_ts_reg : m_axis_tx_cpl_ts_adj_reg) : '0;
assign m_axis_tx_cpl.tkeep = 1'b1;
assign m_axis_tx_cpl.tstrb = m_axis_tx_cpl.tkeep;
assign m_axis_tx_cpl.tvalid = m_axis_tx_cpl_valid_reg;
assign m_axis_tx_cpl.tlast = 1'b1;
assign m_axis_tx_cpl.tid = m_axis_tx_cpl_tag_reg;
assign m_axis_tx_cpl.tdest = '0;
assign m_axis_tx_cpl.tuser = '0;

assign tx_os_ready = tx_os_ready_reg;

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

logic [DATA_W+24-1:0] crc_data_reg, crc_data_next;
reg [31:0] crc_state_reg = '0;
wire [31:0] crc_state;

taxi_lfsr #(
    .LFSR_W(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_GALOIS(1),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_W(DATA_W+24),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b0),
    .STATE_SHIFT_PRE(0),
    .STATE_SHIFT_POST(-24)
)
eth_crc (
    .data_in(crc_data_reg),
    .state_in('0),
    .data_out(),
    .state_out(crc_state)
);

function [2:0] keep2empty(input [7:0] k);
    casez (k)
        8'bzzzzzzz0: keep2empty = 3'd7;
        8'bzzzzzz01: keep2empty = 3'd7;
        8'bzzzzz011: keep2empty = 3'd6;
        8'bzzzz0111: keep2empty = 3'd5;
        8'bzzz01111: keep2empty = 3'd4;
        8'bzz011111: keep2empty = 3'd3;
        8'bz0111111: keep2empty = 3'd2;
        8'b01111111: keep2empty = 3'd1;
        8'b11111111: keep2empty = 3'd0;
    endcase
endfunction

// FCS cycle calculation
always_comb begin
    casez (s_empty_reg)
        3'd7: begin
            fcs_output_txd_0 = {{2{XGMII_IDLE}}, XGMII_TERM, ~crc_state[31:0], s_tdata_reg[7:0]};
            fcs_output_txd_1 = {8{XGMII_IDLE}};
            fcs_output_txc_0 = 8'b11100000;
            fcs_output_txc_1 = 8'b11111111;
            ifg_offset = 8'd3;
            extra_cycle = 1'b0;
        end
        3'd6: begin
            fcs_output_txd_0 = {XGMII_IDLE, XGMII_TERM, ~crc_state[31:0], s_tdata_reg[15:0]};
            fcs_output_txd_1 = {8{XGMII_IDLE}};
            fcs_output_txc_0 = 8'b11000000;
            fcs_output_txc_1 = 8'b11111111;
            ifg_offset = 8'd2;
            extra_cycle = 1'b0;
        end
        3'd5: begin
            fcs_output_txd_0 = {XGMII_TERM, ~crc_state[31:0], s_tdata_reg[23:0]};
            fcs_output_txd_1 = {8{XGMII_IDLE}};
            fcs_output_txc_0 = 8'b10000000;
            fcs_output_txc_1 = 8'b11111111;
            ifg_offset = 8'd1;
            extra_cycle = 1'b0;
        end
        3'd4: begin
            fcs_output_txd_0 = {~crc_state[31:0], s_tdata_reg[31:0]};
            fcs_output_txd_1 = {{7{XGMII_IDLE}}, XGMII_TERM};
            fcs_output_txc_0 = 8'b00000000;
            fcs_output_txc_1 = 8'b11111111;
            ifg_offset = 8'd8;
            extra_cycle = 1'b1;
        end
        3'd3: begin
            fcs_output_txd_0 = {~crc_state[23:0], s_tdata_reg[39:0]};
            fcs_output_txd_1 = {{6{XGMII_IDLE}}, XGMII_TERM, ~crc_state_reg[31:24]};
            fcs_output_txc_0 = 8'b00000000;
            fcs_output_txc_1 = 8'b11111110;
            ifg_offset = 8'd7;
            extra_cycle = 1'b1;
        end
        3'd2: begin
            fcs_output_txd_0 = {~crc_state[15:0], s_tdata_reg[47:0]};
            fcs_output_txd_1 = {{5{XGMII_IDLE}}, XGMII_TERM, ~crc_state_reg[31:16]};
            fcs_output_txc_0 = 8'b00000000;
            fcs_output_txc_1 = 8'b11111100;
            ifg_offset = 8'd6;
            extra_cycle = 1'b1;
        end
        3'd1: begin
            fcs_output_txd_0 = {~crc_state[7:0], s_tdata_reg[55:0]};
            fcs_output_txd_1 = {{4{XGMII_IDLE}}, XGMII_TERM, ~crc_state_reg[31:8]};
            fcs_output_txc_0 = 8'b00000000;
            fcs_output_txc_1 = 8'b11111000;
            ifg_offset = 8'd5;
            extra_cycle = 1'b1;
        end
        3'd0: begin
            fcs_output_txd_0 = s_tdata_reg;
            fcs_output_txd_1 = {{3{XGMII_IDLE}}, XGMII_TERM, ~crc_state_reg[31:0]};
            fcs_output_txc_0 = 8'b00000000;
            fcs_output_txc_1 = 8'b11110000;
            ifg_offset = 8'd4;
            extra_cycle = 1'b1;
        end
    endcase
end

always_comb begin
    state_next = STATE_IDLE;

    swap_lanes_next = swap_lanes_reg;

    frame_start_next = 1'b0;
    frame_next = frame_reg;
    frame_error_next = frame_error_reg;
    frame_oversize_next = frame_oversize_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_cyc_next = frame_len_lim_cyc_reg;
    frame_len_lim_last_next = frame_len_lim_last_reg;
    frame_len_lim_check_next = frame_len_lim_check_reg;
    ifg_cnt_next = ifg_cnt_reg;
    deficit_idle_cnt_next = deficit_idle_cnt_reg;

    s_axis_tx_tready_next = 1'b0;

    s_tdata_next = s_tdata_reg;
    s_empty_next = s_empty_reg;

    crc_data_next = crc_data_reg;

    m_axis_tx_cpl_tag_next = m_axis_tx_cpl_tag_reg;

    tx_os_ready_next = 1'b0;

    if (tx_os_valid) begin
        // Ordered sets
        xgmii_txd_next[7:0] = tx_os_sig ? XGMII_SIG_OS : XGMII_SEQ_OS;
        xgmii_txd_next[15:8] = tx_os[23:16];
        xgmii_txd_next[23:16] = tx_os[15:8];
        xgmii_txd_next[31:24] = tx_os[7:0];
        xgmii_txd_next[39:32] = tx_os_sig ? XGMII_SIG_OS : XGMII_SEQ_OS;
        xgmii_txd_next[47:40] = tx_os[23:16];
        xgmii_txd_next[55:48] = tx_os[15:8];
        xgmii_txd_next[63:56] = tx_os[7:0];
        xgmii_txc_next = 8'b00010001;
        tx_os_ready_next = 1'b1;
    end else begin
        // XGMII idle
        xgmii_txd_next = {CTRL_W{XGMII_IDLE}};
        xgmii_txc_next = {CTRL_W{1'b1}};
    end

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
        frame_start_next = frame_start_reg;
        s_axis_tx_tready_next = s_axis_tx_tready_reg;
    end else begin
        // counter to measure frame length
        if (&frame_len_reg[15:3] == 0) begin
            frame_len_next = frame_len_reg + 16'(CTRL_W);
        end else begin
            frame_len_next = '1;
        end

        // counter for max frame length enforcement
        if (frame_len_lim_cyc_reg != 0) begin
            frame_len_lim_cyc_next = frame_len_lim_cyc_reg - 1;
        end else begin
            frame_len_lim_cyc_next = '0;
        end

        if (frame_len_lim_last_reg[2]) begin
            if (frame_len_lim_cyc_reg == 3) begin
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
            2'd0: begin
                is_mcast_next = s_tdata_reg[0];
                is_bcast_next = &s_tdata_reg[47:0];
            end
            2'd1: is_8021q_next = {s_tdata_reg[39:32], s_tdata_reg[47:40]} == 16'h8100;
            default: begin
                // do nothing
            end
        endcase

        if (ifg_cnt_reg[7:3] != 0) begin
            ifg_cnt_next = ifg_cnt_reg - 8'(CTRL_W);
        end else begin
            ifg_cnt_next = '0;
        end

        // FCS
        casez (s_axis_tx.tkeep)
            8'b11111111: crc_data_next = {24'd0, s_axis_tx.tdata}              ^ {56'd0, crc_state};
            8'b01111111: crc_data_next = {24'd0, s_axis_tx.tdata[55:0], 8'd0}  ^ {48'd0, crc_state, 8'd0};
            8'bz0111111: crc_data_next = {24'd0, s_axis_tx.tdata[47:0], 16'd0} ^ {40'd0, crc_state, 16'd0};
            8'bz0011111: crc_data_next = {24'd0, s_axis_tx.tdata[39:0], 24'd0} ^ {32'd0, crc_state, 24'd0};
            8'bzzz01111: crc_data_next = {24'd0, s_axis_tx.tdata[31:0], 32'd0} ^ {24'd0, crc_state, 32'd0};
            8'bzzzz0111: crc_data_next = {24'd0, s_axis_tx.tdata[23:0], 40'd0} ^ {16'd0, crc_state, 40'd0};
            8'bzzzzz011: crc_data_next = {24'd0, s_axis_tx.tdata[15:0], 48'd0} ^ {8'd0, crc_state, 48'd0};
            default:     crc_data_next = {24'd0, s_axis_tx.tdata[7:0],  56'd0} ^ {crc_state, 56'd0};
        endcase

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for data
                frame_error_next = 1'b0;
                frame_oversize_next = 1'b0;
                hdr_ptr_next = 0;
                frame_len_next = 0;
                {frame_len_lim_cyc_next, frame_len_lim_last_next} = cfg_tx_max_pkt_len ^ 4;
                frame_len_lim_check_next = 1'b0;
                s_axis_tx_tready_next = cfg_tx_enable;

                // XGMII idle or ordered set

                s_tdata_next = s_axis_tx.tdata;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                crc_data_next = {24'd0, s_axis_tx.tdata} ^ {56'd0, 32'hffffffff};

                m_axis_tx_cpl_tag_next = s_axis_tx.tid;

                if (s_axis_tx.tvalid && s_axis_tx.tready) begin
                    // XGMII start, preamble, and SFD
                    xgmii_txd_next = {ETH_SFD, {6{ETH_PRE}}, XGMII_START};
                    xgmii_txc_next = 8'b00000001;
                    frame_start_next = 1'b1;
                    s_axis_tx_tready_next = 1'b1;
                    state_next = STATE_PAYLOAD;
                end else begin
                    swap_lanes_next = 1'b0;
                    ifg_cnt_next = 8'd0;
                    deficit_idle_cnt_next = 2'd0;
                    state_next = STATE_IDLE;
                end
            end
            STATE_PAYLOAD: begin
                // transfer payload
                s_axis_tx_tready_next = 1'b1;

                xgmii_txd_next = s_tdata_reg;
                xgmii_txc_next = {CTRL_W{1'b0}};

                s_tdata_next = s_axis_tx.tdata;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                stat_tx_byte_next = 4'(CTRL_W);

                if (s_axis_tx.tvalid && s_axis_tx.tlast) begin
                    if (frame_len_lim_check_reg) begin
                        if (frame_len_lim_last_reg < 3'(7-keep2empty(s_axis_tx.tkeep))) begin
                            frame_oversize_next = 1'b1;
                        end
                    end
                end else begin
                    if (frame_len_lim_check_reg) begin
                        // at the limit but the frame doesn't end in this cycle
                        frame_oversize_next = 1'b1;
                    end
                end

                if (!s_axis_tx.tvalid || s_axis_tx.tlast || frame_oversize_next) begin
                    s_axis_tx_tready_next = frame_next; // drop frame
                    frame_error_next = !s_axis_tx.tvalid || s_axis_tx.tuser[0] || frame_oversize_next;
                    stat_tx_err_user_next = s_axis_tx.tuser[0];
                    stat_tx_err_underflow_next = !s_axis_tx.tvalid;

                    if (frame_error_next) begin
                        state_next = STATE_ERR;
                    end else begin
                        state_next = STATE_FCS_1;
                    end
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_FCS_1: begin
                // last cycle
                s_axis_tx_tready_next = frame_next; // drop frame

                xgmii_txd_next = fcs_output_txd_0;
                xgmii_txc_next = fcs_output_txc_0;

                ifg_cnt_next = (cfg_tx_ifg > 8'd12 ? cfg_tx_ifg : 8'd12) - ifg_offset + (swap_lanes_reg ? 8'd4 : 8'd0) + 8'(deficit_idle_cnt_reg);

                if (extra_cycle) begin
                    stat_tx_byte_next = 4'(CTRL_W);
                    state_next = STATE_FCS_2;
                end else begin
                    stat_tx_byte_next = 12-s_empty_reg;
                    frame_len_next = frame_len_reg + 16'(12-s_empty_reg);
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
            STATE_FCS_2: begin
                // last cycle
                s_axis_tx_tready_next = frame_next; // drop frame

                xgmii_txd_next = fcs_output_txd_1;
                xgmii_txc_next = fcs_output_txc_1;

                stat_tx_byte_next = 4-s_empty_reg;
                frame_len_next = frame_len_reg + 16'(4-s_empty_reg);

                stat_tx_pkt_len_next = frame_len_next;
                stat_tx_pkt_good_next = !frame_error_reg;
                stat_tx_pkt_bad_next = frame_error_reg;
                stat_tx_pkt_ucast_next = !is_mcast_reg;
                stat_tx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                stat_tx_pkt_bcast_next = is_bcast_reg;
                stat_tx_pkt_vlan_next = is_8021q_reg;
                stat_tx_err_oversize_next = frame_oversize_reg;

                crc_data_next = {24'd0, s_axis_tx.tdata} ^ {56'd0, 32'hffffffff};

                ifg_cnt_next = (cfg_tx_ifg > 8'd12 ? cfg_tx_ifg : 8'd12) - ifg_offset + (swap_lanes_reg ? 8'd4 : 8'd0) + 8'(deficit_idle_cnt_reg);

                if (DIC_EN) begin
                    if (ifg_cnt_next > 8'd7) begin
                        state_next = STATE_IFG;
                    end else begin
                        if (ifg_cnt_next >= 8'd4) begin
                            deficit_idle_cnt_next = 2'(ifg_cnt_next - 8'd4);
                            swap_lanes_next = 1'b1;
                        end else begin
                            deficit_idle_cnt_next = 2'(ifg_cnt_next);
                            ifg_cnt_next = 8'd0;
                            swap_lanes_next = 1'b0;
                        end
                        s_axis_tx_tready_next = cfg_tx_enable;
                        state_next = STATE_IDLE;
                    end
                end else begin
                    if (ifg_cnt_next > 8'd4) begin
                        state_next = STATE_IFG;
                    end else begin
                        s_axis_tx_tready_next = cfg_tx_enable;
                        swap_lanes_next = ifg_cnt_next != 0;
                        state_next = STATE_IDLE;
                    end
                end
            end
            STATE_ERR: begin
                // terminate packet with error
                s_axis_tx_tready_next = frame_next; // drop frame

                // XGMII error
                xgmii_txd_next = {XGMII_TERM, {7{XGMII_ERROR}}};
                xgmii_txc_next = {CTRL_W{1'b1}};

                ifg_cnt_next = cfg_tx_ifg > 8'd12 ? cfg_tx_ifg : 8'd12;

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

                // XGMII idle or ordered set

                crc_data_next = {24'd0, s_axis_tx.tdata} ^ {56'd0, 32'hffffffff};

                if (DIC_EN) begin
                    if (ifg_cnt_next > 8'd7 || frame_reg) begin
                        state_next = STATE_IFG;
                    end else begin
                        if (ifg_cnt_next >= 8'd4) begin
                            deficit_idle_cnt_next = 2'(ifg_cnt_next - 8'd4);
                            swap_lanes_next = 1'b1;
                        end else begin
                            deficit_idle_cnt_next = 2'(ifg_cnt_next);
                            ifg_cnt_next = 8'd0;
                            swap_lanes_next = 1'b0;
                        end
                        s_axis_tx_tready_next = cfg_tx_enable;
                        state_next = STATE_IDLE;
                    end
                end else begin
                    if (ifg_cnt_next > 8'd4 || frame_reg) begin
                        state_next = STATE_IFG;
                    end else begin
                        s_axis_tx_tready_next = cfg_tx_enable;
                        swap_lanes_next = ifg_cnt_next != 0;
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

    swap_lanes_reg <= swap_lanes_next;

    frame_start_reg <= frame_start_next;
    frame_reg <= frame_next;
    frame_error_reg <= frame_error_next;
    frame_oversize_reg <= frame_oversize_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_cyc_reg <= frame_len_lim_cyc_next;
    frame_len_lim_last_reg <= frame_len_lim_last_next;
    frame_len_lim_check_reg <= frame_len_lim_check_next;
    ifg_cnt_reg <= ifg_cnt_next;
    deficit_idle_cnt_reg <= deficit_idle_cnt_next;

    s_tdata_reg <= s_tdata_next;
    s_empty_reg <= s_empty_next;

    crc_data_reg <= crc_data_next;

    s_axis_tx_tready_reg <= s_axis_tx_tready_next;

    m_axis_tx_cpl_tag_reg <= m_axis_tx_cpl_tag_next;
    m_axis_tx_cpl_valid_reg <= 1'b0;
    m_axis_tx_cpl_valid_int_reg <= 1'b0;

    tx_os_ready_reg <= tx_os_ready_next;

    start_packet_reg <= 2'b00;

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

    if (PTP_TS_EN && PTP_TS_FMT_TOD) begin
        m_axis_tx_cpl_valid_reg <= m_axis_tx_cpl_valid_int_reg;
        m_axis_tx_cpl_ts_adj_reg[15:0] <= m_axis_tx_cpl_ts_reg[15:0];
        {m_axis_tx_cpl_ts_borrow_reg, m_axis_tx_cpl_ts_adj_reg[45:16]} <= $signed({1'b0, m_axis_tx_cpl_ts_reg[45:16]}) - $signed(31'd1000000000);
        m_axis_tx_cpl_ts_adj_reg[47:46] <= 0;
        m_axis_tx_cpl_ts_adj_reg[95:48] <= m_axis_tx_cpl_ts_reg[95:48] + 1;
    end

    if (GBX_IF_EN && tx_gbx_req_stall) begin
        // gearbox stall
        xgmii_tx_valid_reg <= 1'b0;
    end else begin
        if (frame_start_reg) begin
            if (swap_lanes_reg) begin
                if (PTP_TS_EN) begin
                    if (PTP_TS_FMT_TOD) begin
                        m_axis_tx_cpl_ts_reg[45:0] <= ptp_ts[45:0] + 46'(ts_inc_reg >> 1);
                        m_axis_tx_cpl_ts_reg[95:48] <= ptp_ts[95:48];
                    end else begin
                        m_axis_tx_cpl_ts_reg <= ptp_ts + PTP_TS_W'(ts_inc_reg >> 1);
                    end
                end
                start_packet_reg <= 2'b10;
            end else begin
                if (PTP_TS_EN) begin
                    m_axis_tx_cpl_ts_reg <= ptp_ts;
                end
                start_packet_reg <= 2'b01;
            end
            if (TX_CPL_CTRL_IN_TUSER) begin
                if (PTP_TS_FMT_TOD) begin
                    m_axis_tx_cpl_valid_int_reg <= (s_axis_tx.tuser >> 1) == 0;
                end else begin
                    m_axis_tx_cpl_valid_reg <= (s_axis_tx.tuser >> 1) == 0;
                end
            end else begin
                if (PTP_TS_FMT_TOD) begin
                    m_axis_tx_cpl_valid_int_reg <= 1'b1;
                end else begin
                    m_axis_tx_cpl_valid_reg <= 1'b1;
                end
            end
        end

        crc_state_reg <= crc_state;

        swap_txd_reg <= xgmii_txd_next[63:32];
        swap_txc_reg <= xgmii_txc_next[7:4];

        if (swap_lanes_reg) begin
            xgmii_txd_reg <= {xgmii_txd_next[31:0], swap_txd_reg};
            xgmii_txc_reg <= {xgmii_txc_next[3:0], swap_txc_reg};
        end else begin
            xgmii_txd_reg <= xgmii_txd_next;
            xgmii_txc_reg <= xgmii_txc_next;
        end

        xgmii_tx_valid_reg <= 1'b1;
    end

    tx_gbx_sync_reg <= tx_gbx_req_sync;

    last_ts_reg <= (4+16)'(ptp_ts);
    ts_inc_reg <= (4+16)'(ptp_ts) - last_ts_reg;

    if (rst) begin
        state_reg <= STATE_IDLE;

        swap_lanes_reg <= 1'b0;

        frame_start_reg <= 1'b0;
        frame_reg <= 1'b0;
        deficit_idle_cnt_reg <= 2'd0;

        s_axis_tx_tready_reg <= 1'b0;

        m_axis_tx_cpl_valid_reg <= 1'b0;
        m_axis_tx_cpl_valid_int_reg <= 1'b0;

        tx_os_ready_reg <= 1'b0;

        xgmii_txd_reg <= {CTRL_W{XGMII_IDLE}};
        xgmii_txc_reg <= {CTRL_W{1'b1}};
        xgmii_tx_valid_reg <= 1'b0;
        tx_gbx_sync_reg <= '0;

        start_packet_reg <= 2'b00;

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
