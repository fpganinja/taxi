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
 * AXI4-Stream XGMII frame receiver testbench
 */
module test_taxi_axis_xgmii_rx_32 #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter DATA_W = 32,
    parameter logic PTP_TS_EN = 1'b0,
    parameter PTP_TS_W = 96
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam CTRL_W = DATA_W/8;
localparam USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

logic clk;
logic rst;

logic [DATA_W-1:0] xgmii_rxd;
logic [CTRL_W-1:0] xgmii_rxc;

taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(USER_W)) m_axis_rx();

logic [PTP_TS_W-1:0] ptp_ts;

logic cfg_rx_enable;

logic start_packet;
logic error_bad_frame;
logic error_bad_fcs;

taxi_axis_xgmii_rx_32 #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_W(PTP_TS_W)
)
uut (
    .clk(clk),
    .rst(rst),

    /*
     * XGMII input
     */
    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis_rx(m_axis_rx),

    /*
     * PTP
     */
    .ptp_ts(ptp_ts),

    /*
     * Configuration
     */
    .cfg_rx_enable(cfg_rx_enable),

    /*
     * Status
     */
    .start_packet(start_packet),
    .error_bad_frame(error_bad_frame),
    .error_bad_fcs(error_bad_fcs)
);

endmodule

`resetall
