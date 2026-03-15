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
 * AXI4 tie (read)
 */
module taxi_axi_tie_rd
(
    /*
     * AXI4 slave interface
     */
    taxi_axi_if.rd_slv  s_axi_rd,

    /*
     * AXI4 master interface
     */
    taxi_axi_if.rd_mst  m_axi_rd
);

// extract parameters
localparam DATA_W = s_axi_rd.DATA_W;
localparam ADDR_W = s_axi_rd.ADDR_W;
localparam STRB_W = s_axi_rd.STRB_W;
localparam ID_W = s_axi_rd.ID_W;
localparam logic ARUSER_EN = s_axi_rd.ARUSER_EN && m_axi_rd.ARUSER_EN;
localparam ARUSER_W = s_axi_rd.ARUSER_W;
localparam logic RUSER_EN = s_axi_rd.RUSER_EN && m_axi_rd.RUSER_EN;
localparam RUSER_W = s_axi_rd.RUSER_W;

// check configuration
if (m_axi_rd.ADDR_W > ADDR_W)
    $fatal(0, "Error: Output ADDR_W is wider than input ADDR_W, cannot access entire address space (instance %m)");

if (m_axi_rd.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axi_rd.STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

assign m_axi_rd.arid = s_axi_rd.arid;
assign m_axi_rd.araddr = m_axi_wr.ADDR_W'(s_axi_rd.araddr);
assign m_axi_rd.arlen = s_axi_rd.arlen;
assign m_axi_rd.arsize = s_axi_rd.arsize;
assign m_axi_rd.arburst = s_axi_rd.arburst;
assign m_axi_rd.arlock = s_axi_rd.arlock;
assign m_axi_rd.arcache = s_axi_rd.arcache;
assign m_axi_rd.arprot = s_axi_rd.arprot;
assign m_axi_rd.arqos = s_axi_rd.arqos;
assign m_axi_rd.arregion = s_axi_rd.arregion;
assign m_axi_rd.aruser = ARUSER_EN ? s_axi_rd.aruser : '0;
assign m_axi_rd.arvalid = s_axi_rd.arvalid;
assign s_axi_rd.arready = m_axi_rd.arready;

assign s_axi_rd.rid = m_axi_rd.rid;
assign s_axi_rd.rdata = m_axi_rd.rdata;
assign s_axi_rd.rresp = m_axi_rd.rresp;
assign s_axi_rd.rlast = m_axi_rd.rlast;
assign s_axi_rd.ruser = RUSER_EN ? m_axi_rd.ruser : '0;
assign s_axi_rd.rvalid = m_axi_rd.rvalid;
assign m_axi_rd.rready = s_axi_rd.rready;

endmodule

`resetall
