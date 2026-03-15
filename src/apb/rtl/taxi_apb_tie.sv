// SPDX-License-Identifier: MIT
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * APB tie
 */
module taxi_apb_tie
(
    /*
     * APB slave interface
     */
    taxi_apb_if.slv  s_apb,

    /*
     * APB master interface
     */
    taxi_apb_if.mst  m_apb
);

// extract parameters
localparam DATA_W = s_apb.DATA_W;
localparam ADDR_W = s_apb.ADDR_W;
localparam STRB_W = s_apb.STRB_W;
localparam logic PAUSER_EN = s_apb.PAUSER_EN && m_apb.PAUSER_EN;
localparam PAUSER_W = s_apb.PAUSER_W;
localparam logic PWUSER_EN = s_apb.PWUSER_EN && m_apb.PWUSER_EN;
localparam PWUSER_W = s_apb.PWUSER_W;
localparam logic PRUSER_EN = s_apb.PRUSER_EN && m_apb.PRUSER_EN;
localparam PRUSER_W = s_apb.PRUSER_W;
localparam logic PBUSER_EN = s_apb.PBUSER_EN && m_apb.PBUSER_EN;
localparam PBUSER_W = s_apb.PBUSER_W;

// check configuration
if (m_apb.ADDR_W > ADDR_W)
    $fatal(0, "Error: Output ADDR_W is wider than input ADDR_W, cannot access entire address space (instance %m)");

if (m_apb.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_apb.STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

assign m_apb.paddr = m_apb.ADDR_W'(s_apb.paddr);
assign m_apb.pprot = s_apb.pprot;
assign m_apb.psel = s_apb.psel;
assign m_apb.penable = s_apb.penable;
assign m_apb.pwrite = s_apb.pwrite;
assign m_apb.pwdata = s_apb.pwdata;
assign m_apb.pstrb = s_apb.pstrb;
assign s_apb.pready = m_apb.pready;
assign s_apb.prdata = m_apb.prdata;
assign s_apb.pslverr = m_apb.pslverr;
assign m_apb.pauser = PAUSER_EN ? s_apb.pauser : '0;
assign m_apb.pwuser = PWUSER_EN ? s_apb.pwuser : '0;
assign s_apb.pruser = PRUSER_EN ? m_apb.pruser : '0;
assign s_apb.pbuser = PBUSER_EN ? m_apb.pbuser : '0;

endmodule

`resetall
