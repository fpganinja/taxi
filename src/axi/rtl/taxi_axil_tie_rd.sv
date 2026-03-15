// SPDX-License-Identifier: MIT
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 lite tie (read)
 */
module taxi_axil_tie_rd
(
    /*
     * AXI4 lite slave interface
     */
    taxi_axil_if.rd_slv  s_axil_rd,

    /*
     * AXI4 lite master interface
     */
    taxi_axil_if.rd_mst  m_axil_rd
);

// extract parameters
localparam DATA_W = s_axil_rd.DATA_W;
localparam ADDR_W = s_axil_rd.ADDR_W;
localparam STRB_W = s_axil_rd.STRB_W;
localparam logic ARUSER_EN = s_axil_rd.ARUSER_EN && m_axil_rd.ARUSER_EN;
localparam ARUSER_W = s_axil_rd.ARUSER_W;
localparam logic RUSER_EN = s_axil_rd.RUSER_EN && m_axil_rd.RUSER_EN;
localparam RUSER_W = s_axil_rd.RUSER_W;

// check configuration
if (m_axil_rd.ADDR_W > ADDR_W)
    $fatal(0, "Error: Output ADDR_W is wider than input ADDR_W, cannot access entire address space (instance %m)");

if (m_axil_rd.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axil_rd.STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

assign m_axil_rd.araddr = m_axil_rd.ADDR_W'(s_axil_rd.araddr);
assign m_axil_rd.arprot = s_axil_rd.arprot;
assign m_axil_rd.aruser = ARUSER_EN ? s_axil_rd.aruser : '0;
assign m_axil_rd.arvalid = s_axil_rd.arvalid;
assign s_axil_rd.arready = m_axil_rd.arready;

assign s_axil_rd.rdata = m_axil_rd.rdata;
assign s_axil_rd.rresp = m_axil_rd.rresp;
assign s_axil_rd.ruser = RUSER_EN ? m_axil_rd.ruser : '0;
assign s_axil_rd.rvalid = m_axil_rd.rvalid;
assign m_axil_rd.rready = s_axil_rd.rready;

endmodule

`resetall
