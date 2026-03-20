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
 * APB interconnect testbench
 */
module test_taxi_apb_interconnect_1s #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter M_CNT = 4,
    parameter DATA_W = 32,
    parameter ADDR_W = 32,
    parameter STRB_W = (DATA_W/8),
    parameter logic PAUSER_EN = 1'b0,
    parameter PAUSER_W = 1,
    parameter logic PWUSER_EN = 1'b0,
    parameter PWUSER_W = 1,
    parameter logic PRUSER_EN = 1'b0,
    parameter PRUSER_W = 1,
    parameter logic PBUSER_EN = 1'b0,
    parameter PBUSER_W = 1,
    parameter M_REGIONS = 1,
    parameter M_BASE_ADDR = '0,
    parameter M_ADDR_W = {M_CNT{{M_REGIONS{32'd24}}}},
    parameter M_SECURE = {M_CNT{1'b0}}
    /* verilator lint_on WIDTHTRUNC */
)
();

logic clk;
logic rst;

taxi_apb_if #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .PAUSER_EN(PAUSER_EN),
    .PAUSER_W(PAUSER_W),
    .PWUSER_EN(PWUSER_EN),
    .PWUSER_W(PWUSER_W),
    .PRUSER_EN(PRUSER_EN),
    .PRUSER_W(PRUSER_W),
    .PBUSER_EN(PBUSER_EN),
    .PBUSER_W(PBUSER_W)
) s_apb(), m_apb[M_CNT]();

taxi_apb_interconnect_1s #(
    .M_CNT(M_CNT),
    .ADDR_W(ADDR_W),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_W(M_ADDR_W),
    .M_SECURE(M_SECURE)
)
uut (
    .clk(clk),
    .rst(rst),

    /*
     * APB slave interface
     */
    .s_apb(s_apb),

    /*
     * APB master interface
     */
    .m_apb(m_apb)
);

endmodule

`resetall
