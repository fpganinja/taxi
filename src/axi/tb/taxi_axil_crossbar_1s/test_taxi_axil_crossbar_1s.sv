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
 * AXI4-lite crossbar testbench
 */
module test_taxi_axil_crossbar_1s #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter M_COUNT = 4,
    parameter DATA_W = 32,
    parameter ADDR_W = 32,
    parameter STRB_W = (DATA_W/8),
    parameter logic AWUSER_EN = 1'b0,
    parameter AWUSER_W = 1,
    parameter logic WUSER_EN = 1'b0,
    parameter WUSER_W = 1,
    parameter logic BUSER_EN = 1'b0,
    parameter BUSER_W = 1,
    parameter logic ARUSER_EN = 1'b0,
    parameter ARUSER_W = 1,
    parameter logic RUSER_EN = 1'b0,
    parameter RUSER_W = 1,
    parameter S_ACCEPT = 16,
    parameter M_REGIONS = 1,
    parameter M_BASE_ADDR = '0,
    parameter M_ADDR_W = {M_COUNT{{M_REGIONS{32'd24}}}},
    parameter M_ISSUE = {M_COUNT{32'd4}},
    parameter M_SECURE = {M_COUNT{1'b0}},
    parameter S_AW_REG_TYPE = 2'd0,
    parameter S_W_REG_TYPE = 2'd0,
    parameter S_B_REG_TYPE = 2'd1,
    parameter S_AR_REG_TYPE = 2'd0,
    parameter S_R_REG_TYPE = 2'd2,
    parameter M_AW_REG_TYPE = {M_COUNT{2'd1}},
    parameter M_W_REG_TYPE = {M_COUNT{2'd2}},
    parameter M_B_REG_TYPE = {M_COUNT{2'd0}},
    parameter M_AR_REG_TYPE = {M_COUNT{2'd1}},
    parameter M_R_REG_TYPE = {M_COUNT{2'd0}}
    /* verilator lint_on WIDTHTRUNC */
)
();

logic clk;
logic rst;

taxi_axil_if #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .AWUSER_EN(AWUSER_EN),
    .AWUSER_W(AWUSER_W),
    .WUSER_EN(WUSER_EN),
    .WUSER_W(WUSER_W),
    .BUSER_EN(BUSER_EN),
    .BUSER_W(BUSER_W),
    .ARUSER_EN(ARUSER_EN),
    .ARUSER_W(ARUSER_W),
    .RUSER_EN(RUSER_EN),
    .RUSER_W(RUSER_W)
) s_axil();

taxi_axil_if #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .AWUSER_EN(AWUSER_EN),
    .AWUSER_W(AWUSER_W),
    .WUSER_EN(WUSER_EN),
    .WUSER_W(WUSER_W),
    .BUSER_EN(BUSER_EN),
    .BUSER_W(BUSER_W),
    .ARUSER_EN(ARUSER_EN),
    .ARUSER_W(ARUSER_W),
    .RUSER_EN(RUSER_EN),
    .RUSER_W(RUSER_W)
) m_axil[M_COUNT]();

taxi_axil_crossbar_1s #(
    .M_COUNT(M_COUNT),
    .ADDR_W(ADDR_W),
    .S_ACCEPT(S_ACCEPT),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_W(M_ADDR_W),
    .M_ISSUE(M_ISSUE),
    .M_SECURE(M_SECURE),
    .S_AW_REG_TYPE(S_AW_REG_TYPE),
    .S_W_REG_TYPE(S_W_REG_TYPE),
    .S_B_REG_TYPE(S_B_REG_TYPE),
    .S_AR_REG_TYPE(S_AR_REG_TYPE),
    .S_R_REG_TYPE(S_R_REG_TYPE),
    .M_AW_REG_TYPE(M_AW_REG_TYPE),
    .M_W_REG_TYPE(M_W_REG_TYPE),
    .M_B_REG_TYPE(M_B_REG_TYPE),
    .M_AR_REG_TYPE(M_AR_REG_TYPE),
    .M_R_REG_TYPE(M_R_REG_TYPE)
)
uut (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-lite slave interface
     */
    .s_axil_wr(s_axil),
    .s_axil_rd(s_axil),

    /*
     * AXI4-lite master interface
     */
    .m_axil_wr(m_axil),
    .m_axil_rd(m_axil)
);

endmodule

`resetall
