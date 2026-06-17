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
 * AXI4-Stream 10000BASE-X frame transmitter testbench
 */
module test_taxi_axis_basex_tx_8 #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter DATA_W = 8,
    parameter CTRL_W = DATA_W / 8,
    parameter logic PADDING_EN = 1'b1,
    parameter MIN_FRAME_LEN = 64,
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1,
    parameter logic AN_EN = 1'b1,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter TX_TAG_W = 8,
    parameter logic TX_CPL_CTRL_IN_TUSER = 1'b0
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam USER_W = TX_CPL_CTRL_IN_TUSER ? 2 : 1;

logic clk;
logic rst;

taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(USER_W), .ID_EN(1), .ID_W(TX_TAG_W)) s_axis_tx();
taxi_axis_if #(.DATA_W(PTP_TS_W), .KEEP_W(1), .ID_EN(1), .ID_W(TX_TAG_W)) m_axis_tx_cpl();

logic [DATA_W-1:0] encoded_tx_data;
logic [CTRL_W-1:0] encoded_tx_data_k;
logic [CTRL_W-1:0] encoded_tx_data_dm;
logic [CTRL_W-1:0] encoded_tx_data_dv;
logic encoded_tx_data_valid;
logic [GBX_CNT-1:0] tx_gbx_req_sync;
logic tx_gbx_req_stall;
logic [GBX_CNT-1:0] tx_gbx_sync;

logic [15:0] tx_an_cfg;
logic tx_an_cfg_valid;
logic tx_an_cfg_ready;

logic [PTP_TS_W-1:0] ptp_ts;

logic [15:0] cfg_tx_max_pkt_len;
logic [7:0] cfg_tx_ifg;
logic cfg_tx_enable;

logic tx_start_packet;
logic stat_tx_byte;
logic [15:0] stat_tx_pkt_len;
logic stat_tx_pkt_ucast;
logic stat_tx_pkt_mcast;
logic stat_tx_pkt_bcast;
logic stat_tx_pkt_vlan;
logic stat_tx_pkt_good;
logic stat_tx_pkt_bad;
logic stat_tx_err_oversize;
logic stat_tx_err_user;
logic stat_tx_err_underflow;

taxi_axis_basex_tx_8 #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .PADDING_EN(PADDING_EN),
    .MIN_FRAME_LEN(MIN_FRAME_LEN),
    .GBX_IF_EN(GBX_IF_EN),
    .GBX_CNT(GBX_CNT),
    .AN_EN(AN_EN),
    .DIC_EN(DIC_EN),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_W(PTP_TS_W),
    .TX_CPL_CTRL_IN_TUSER(TX_CPL_CTRL_IN_TUSER)
)
uut (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Stream input (sink)
     */
    .s_axis_tx(s_axis_tx),
    .m_axis_tx_cpl(m_axis_tx_cpl),

    /*
     * 10000BASE-X encoded interface
     */
    .encoded_tx_data(encoded_tx_data),
    .encoded_tx_data_k(encoded_tx_data_k),
    .encoded_tx_data_dm(encoded_tx_data_dm),
    .encoded_tx_data_dv(encoded_tx_data_dv),
    .encoded_tx_data_valid(encoded_tx_data_valid),
    .tx_gbx_req_sync(tx_gbx_req_sync),
    .tx_gbx_req_stall(tx_gbx_req_stall),
    .tx_gbx_sync(tx_gbx_sync),

    /*
     * AN config register
     */
    .tx_an_cfg(tx_an_cfg),
    .tx_an_cfg_valid(tx_an_cfg_valid),
    .tx_an_cfg_ready(tx_an_cfg_ready),

    /*
     * PTP
     */
    .ptp_ts(ptp_ts),

    /*
     * Configuration
     */
    .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
    .cfg_tx_ifg(cfg_tx_ifg),
    .cfg_tx_enable(cfg_tx_enable),

    /*
     * Status
     */
    .tx_start_packet(tx_start_packet),
    .stat_tx_byte(stat_tx_byte),
    .stat_tx_pkt_len(stat_tx_pkt_len),
    .stat_tx_pkt_ucast(stat_tx_pkt_ucast),
    .stat_tx_pkt_mcast(stat_tx_pkt_mcast),
    .stat_tx_pkt_bcast(stat_tx_pkt_bcast),
    .stat_tx_pkt_vlan(stat_tx_pkt_vlan),
    .stat_tx_pkt_good(stat_tx_pkt_good),
    .stat_tx_pkt_bad(stat_tx_pkt_bad),
    .stat_tx_err_oversize(stat_tx_err_oversize),
    .stat_tx_err_user(stat_tx_err_user),
    .stat_tx_err_underflow(stat_tx_err_underflow)
);

endmodule

`resetall
