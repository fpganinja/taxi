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
 * AXI4 lite tie (write)
 */
module taxi_axil_tie_wr
(
    /*
     * AXI4 lite slave interface
     */
    taxi_axil_if.wr_slv  s_axil_wr,

    /*
     * AXI4 lite master interface
     */
    taxi_axil_if.wr_mst  m_axil_wr
);

// extract parameters
localparam DATA_W = s_axil_wr.DATA_W;
localparam ADDR_W = s_axil_wr.ADDR_W;
localparam STRB_W = s_axil_wr.STRB_W;
localparam logic AWUSER_EN = s_axil_wr.AWUSER_EN && m_axil_wr.AWUSER_EN;
localparam AWUSER_W = s_axil_wr.AWUSER_W;
localparam logic WUSER_EN = s_axil_wr.WUSER_EN && m_axil_wr.WUSER_EN;
localparam WUSER_W = s_axil_wr.WUSER_W;
localparam logic BUSER_EN = s_axil_wr.BUSER_EN && m_axil_wr.BUSER_EN;
localparam BUSER_W = s_axil_wr.BUSER_W;

// check configuration
if (m_axil_wr.ADDR_W > ADDR_W)
    $fatal(0, "Error: Output ADDR_W is wider than input ADDR_W, cannot access entire address space (instance %m)");

if (m_axil_wr.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axil_wr.STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

// bypass AW channel
assign m_axil_wr.awaddr = m_axil_wr.ADDR_W'(s_axil_wr.awaddr);
assign m_axil_wr.awprot = s_axil_wr.awprot;
assign m_axil_wr.awuser = AWUSER_EN ? s_axil_wr.awuser : '0;
assign m_axil_wr.awvalid = s_axil_wr.awvalid;
assign s_axil_wr.awready = m_axil_wr.awready;

assign m_axil_wr.wdata = s_axil_wr.wdata;
assign m_axil_wr.wstrb = s_axil_wr.wstrb;
assign m_axil_wr.wuser = WUSER_EN ? s_axil_wr.wuser : '0;
assign m_axil_wr.wvalid = s_axil_wr.wvalid;
assign s_axil_wr.wready = m_axil_wr.wready;

assign s_axil_wr.bresp = m_axil_wr.bresp;
assign s_axil_wr.buser = BUSER_EN ? m_axil_wr.buser : '0;
assign s_axil_wr.bvalid = m_axil_wr.bvalid;
assign m_axil_wr.bready = s_axil_wr.bready;

endmodule

`resetall
