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
 * AXI4 tie (write)
 */
module taxi_axi_tie_wr
(
    /*
     * AXI4 slave interface
     */
    taxi_axi_if.wr_slv  s_axi_wr,

    /*
     * AXI4 master interface
     */
    taxi_axi_if.wr_mst  m_axi_wr
);

// extract parameters
localparam DATA_W = s_axi_wr.DATA_W;
localparam ADDR_W = s_axi_wr.ADDR_W;
localparam STRB_W = s_axi_wr.STRB_W;
localparam ID_W = s_axi_wr.ID_W;
localparam logic AWUSER_EN = s_axi_wr.AWUSER_EN && m_axi_wr.AWUSER_EN;
localparam AWUSER_W = s_axi_wr.AWUSER_W;
localparam logic WUSER_EN = s_axi_wr.WUSER_EN && m_axi_wr.WUSER_EN;
localparam WUSER_W = s_axi_wr.WUSER_W;
localparam logic BUSER_EN = s_axi_wr.BUSER_EN && m_axi_wr.BUSER_EN;
localparam BUSER_W = s_axi_wr.BUSER_W;

// check configuration
if (m_axi_wr.ADDR_W > ADDR_W)
    $fatal(0, "Error: Output ADDR_W is wider than input ADDR_W, cannot access entire address space (instance %m)");

if (m_axi_wr.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axi_wr.STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

// bypass AW channel
assign m_axi_wr.awid = s_axi_wr.awid;
assign m_axi_wr.awaddr = m_axi_wr.ADDR_W'(s_axi_wr.awaddr);
assign m_axi_wr.awlen = s_axi_wr.awlen;
assign m_axi_wr.awsize = s_axi_wr.awsize;
assign m_axi_wr.awburst = s_axi_wr.awburst;
assign m_axi_wr.awlock = s_axi_wr.awlock;
assign m_axi_wr.awcache = s_axi_wr.awcache;
assign m_axi_wr.awprot = s_axi_wr.awprot;
assign m_axi_wr.awqos = s_axi_wr.awqos;
assign m_axi_wr.awregion = s_axi_wr.awregion;
assign m_axi_wr.awuser = AWUSER_EN ? s_axi_wr.awuser : '0;
assign m_axi_wr.awvalid = s_axi_wr.awvalid;
assign s_axi_wr.awready = m_axi_wr.awready;

assign m_axi_wr.wdata = s_axi_wr.wdata;
assign m_axi_wr.wstrb = s_axi_wr.wstrb;
assign m_axi_wr.wlast = s_axi_wr.wlast;
assign m_axi_wr.wuser = WUSER_EN ? s_axi_wr.wuser : '0;
assign m_axi_wr.wvalid = s_axi_wr.wvalid;
assign s_axi_wr.wready = m_axi_wr.wready;

assign s_axi_wr.bid = m_axi_wr.bid;
assign s_axi_wr.bresp = m_axi_wr.bresp;
assign s_axi_wr.buser = BUSER_EN ? m_axi_wr.buser : '0;
assign s_axi_wr.bvalid = m_axi_wr.bvalid;
assign m_axi_wr.bready = s_axi_wr.bready;

endmodule

`resetall
