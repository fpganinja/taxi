// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2018-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 crossbar
 */
module taxi_axi_crossbar_1s_rd #
(
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Address width in bits for address decoding
    parameter ADDR_W = 32,
    // TODO fix parametrization once verilator issue 5890 is fixed
    // Number of concurrent unique IDs
    parameter S_THREADS = 2,
    // Number of concurrent operations for each slave interface
    // 1 concatenated fields of 32 bits
    parameter S_ACCEPT = 16,
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_W bits
    // set to zero for default addressing based on M_ADDR_W
    parameter M_BASE_ADDR = '0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_W = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Number of concurrent operations for each master interface
    // M_COUNT concatenated fields of 32 bits
    parameter M_ISSUE = {M_COUNT{32'd4}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}},
    // Slave interface AR channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_AR_REG_TYPE = 2'd0,
    // Slave interface R channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter S_R_REG_TYPE = 2'd2,
    // Master interface AR channel register type (output)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_AR_REG_TYPE = {M_COUNT{2'd1}},
    // Master interface R channel register type (input)
    // 0 to bypass, 1 for simple buffer, 2 for skid buffer
    parameter M_R_REG_TYPE = {M_COUNT{2'd0}}
)
(
    input  wire logic   clk,
    input  wire logic   rst,

    /*
     * AXI4 slave interface
     */
    taxi_axi_if.rd_slv  s_axi_rd,

    /*
     * AXI4 master interfaces
     */
    taxi_axi_if.rd_mst  m_axi_rd[M_COUNT]
);

taxi_axi_if #(
    .DATA_W(s_axi_rd.DATA_W),
    .ADDR_W(s_axi_rd.ADDR_W),
    .STRB_W(s_axi_rd.STRB_W),
    .ID_W(s_axi_rd.ID_W),
    .AWUSER_EN(s_axi_rd.AWUSER_EN),
    .AWUSER_W(s_axi_rd.AWUSER_W),
    .WUSER_EN(s_axi_rd.WUSER_EN),
    .WUSER_W(s_axi_rd.WUSER_W),
    .BUSER_EN(s_axi_rd.BUSER_EN),
    .BUSER_W(s_axi_rd.BUSER_W),
    .ARUSER_EN(s_axi_rd.ARUSER_EN),
    .ARUSER_W(s_axi_rd.ARUSER_W),
    .RUSER_EN(s_axi_rd.RUSER_EN),
    .RUSER_W(s_axi_rd.RUSER_W),
    .MAX_BURST_LEN(s_axi_rd.MAX_BURST_LEN),
    .NARROW_BURST_EN(s_axi_rd.NARROW_BURST_EN)
)
s_axi_rd_int[1]();

taxi_axi_tie_rd
tie_inst (
    .s_axi_rd(s_axi_rd),
    .m_axi_rd(s_axi_rd_int[0])
);

taxi_axi_crossbar_rd #(
    .S_COUNT(1),
    .M_COUNT(M_COUNT),
    .ADDR_W(ADDR_W),
    .S_THREADS(S_THREADS),
    .S_ACCEPT(S_ACCEPT),
    .M_REGIONS(M_REGIONS),
    .M_BASE_ADDR(M_BASE_ADDR),
    .M_ADDR_W(M_ADDR_W),
    .M_ISSUE(M_ISSUE),
    .M_SECURE(M_SECURE),
    .S_AR_REG_TYPE(S_AR_REG_TYPE),
    .S_R_REG_TYPE(S_R_REG_TYPE)
)
rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI slave interface
     */
    .s_axi_rd(s_axi_rd_int),

    /*
     * AXI master interfaces
     */
    .m_axi_rd(m_axi_rd)
);

endmodule

`resetall
