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
 * AXI4-Stream 1000BASE-X frame receiver testbench
 */
module test_taxi_axis_basex_rx_16 #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter DATA_W = 16,
    parameter CTRL_W = DATA_W / 8,
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic SGMII_EN = 1'b1,
    parameter logic AN_EN = SGMII_EN,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

logic clk;
logic rst;

logic [DATA_W-1:0] encoded_rx_data;
logic [CTRL_W-1:0] encoded_rx_data_k;
logic encoded_rx_data_valid;

taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(USER_W)) m_axis_rx();

logic [15:0] rx_an_cfg;
logic rx_an_cfg_valid;
logic rx_an_ability_match;
logic rx_an_ack_match;
logic rx_an_idle_match;

logic [PTP_TS_W-1:0] ptp_ts;

logic [15:0] cfg_rx_max_pkt_len;
logic cfg_rx_enable;
logic cfg_rx_sgmii_en;
logic [1:0] cfg_rx_sgmii_speed;

logic [1:0] rx_start_packet;
logic [1:0] stat_rx_byte;
logic [15:0] stat_rx_pkt_len;
logic stat_rx_pkt_fragment;
logic stat_rx_pkt_jabber;
logic stat_rx_pkt_ucast;
logic stat_rx_pkt_mcast;
logic stat_rx_pkt_bcast;
logic stat_rx_pkt_vlan;
logic stat_rx_pkt_good;
logic stat_rx_pkt_bad;
logic stat_rx_err_oversize;
logic stat_rx_err_bad_fcs;
logic stat_rx_err_bad_block;
logic stat_rx_err_framing;
logic stat_rx_err_preamble;

taxi_axis_basex_rx_16 #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(GBX_IF_EN),
    .SGMII_EN(SGMII_EN),
    .AN_EN(AN_EN),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_W(PTP_TS_W)
)
uut (
    .clk(clk),
    .rst(rst),

    /*
     * 1000BASE-X encoded input
     */
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_data_k(encoded_rx_data_k),
    .encoded_rx_data_valid(encoded_rx_data_valid),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis_rx(m_axis_rx),

    /*
     * AN config register
     */
    .rx_an_cfg(rx_an_cfg),
    .rx_an_cfg_valid(rx_an_cfg_valid),
    .rx_an_ability_match(rx_an_ability_match),
    .rx_an_ack_match(rx_an_ack_match),
    .rx_an_idle_match(rx_an_idle_match),

    /*
     * PTP
     */
    .ptp_ts(ptp_ts),

    /*
     * Configuration
     */
    .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
    .cfg_rx_enable(cfg_rx_enable),
    .cfg_rx_sgmii_en(cfg_rx_sgmii_en),
    .cfg_rx_sgmii_speed(cfg_rx_sgmii_speed),

    /*
     * Status
     */
    .rx_start_packet(rx_start_packet),
    .stat_rx_byte(stat_rx_byte),
    .stat_rx_pkt_len(stat_rx_pkt_len),
    .stat_rx_pkt_fragment(stat_rx_pkt_fragment),
    .stat_rx_pkt_jabber(stat_rx_pkt_jabber),
    .stat_rx_pkt_ucast(stat_rx_pkt_ucast),
    .stat_rx_pkt_mcast(stat_rx_pkt_mcast),
    .stat_rx_pkt_bcast(stat_rx_pkt_bcast),
    .stat_rx_pkt_vlan(stat_rx_pkt_vlan),
    .stat_rx_pkt_good(stat_rx_pkt_good),
    .stat_rx_pkt_bad(stat_rx_pkt_bad),
    .stat_rx_err_oversize(stat_rx_err_oversize),
    .stat_rx_err_bad_fcs(stat_rx_err_bad_fcs),
    .stat_rx_err_bad_block(stat_rx_err_bad_block),
    .stat_rx_err_framing(stat_rx_err_framing),
    .stat_rx_err_preamble(stat_rx_err_preamble)
);

endmodule

`resetall
