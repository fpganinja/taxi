// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2016-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Generic source synchronous DDR output
 */
module taxi_ssio_ddr_out #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA", "LATTICE")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtex7",
    // Use 90 degree clock for transmit
    parameter logic USE_CLK90 = 1'b1,
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire logic              clk,
    input  wire logic              clk90,

    input  wire logic [WIDTH-1:0]  input_d1,
    input  wire logic [WIDTH-1:0]  input_d2,

    output wire logic              output_clk,
    output wire logic [WIDTH-1:0]  output_q
);

wire ref_clk = USE_CLK90 ? clk90 : clk;

taxi_oddr #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(1)
)
clk_oddr_inst (
    .clk(ref_clk),
    .d1(1'b1),
    .d2(1'b0),
    .q(output_clk)
);

taxi_oddr #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(WIDTH)
)
data_oddr_inst (
    .clk(clk),
    .d1(input_d1),
    .d2(input_d2),
    .q(output_q)
);

endmodule

`resetall
