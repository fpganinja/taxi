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
 * Generic source synchronous DDR input
 */
module taxi_ssio_ddr_in #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA", "LATTICE")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtex7",
    // Width of register in bits
    parameter WIDTH = 1
)
(
    input  wire logic              input_clk,

    input  wire logic [WIDTH-1:0]  input_d,

    output wire logic              output_clk,

    output wire logic [WIDTH-1:0]  output_q1,
    output wire logic [WIDTH-1:0]  output_q2
);

wire clk_int;
wire clk_io;

if (!SIM && VENDOR == "XILINX") begin
    // Xilinx/AMD device support

    // use Xilinx clocking primitives

    if (FAMILY == "virtex6" || FAMILY == "virtex7" || FAMILY == "kintex7" || FAMILY == "artix7") begin
        // BUFIO + BUFR
        // virtex6, virtex7, kintex7, artix7, zynq

        assign clk_int = input_clk;

        // pass through RX clock to input buffers
        BUFIO
        clk_bufio (
            .I(clk_int),
            .O(clk_io)
        );

        // pass through RX clock to logic
        BUFR #(
            .BUFR_DIVIDE("BYPASS")
        )
        clk_bufr (
            .I(clk_int),
            .O(output_clk),
            .CE(1'b1),
            .CLR(1'b0)
        );

    end else begin
        // BUFG only
        // spartan6, virtexu, kintexu, virtexuplus, virtexuplusHBM, virtexuplus58g, kintexuplus, zynquplus, zynquplusRFSOC

        // buffer RX clock
        BUFG
        clk_bufg (
            .I(input_clk),
            .O(clk_int)
        );

        // pass through RX clock to logic and input buffers
        assign clk_io = clk_int;
        assign output_clk = clk_int;

    end

end else begin
    // generic/simulation implementation (no vendor primitives)
    // also used for LATTICE (ecp5): no I/O clock buffer primitive is needed

    // pass through RX clock to input buffers
    assign clk_io = input_clk;

    // pass through RX clock to logic
    assign clk_int = input_clk;
    assign output_clk = clk_int;

end

taxi_iddr #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(WIDTH)
)
data_iddr_inst (
    .clk(clk_io),
    .d(input_d),
    .q1(output_q1),
    .q2(output_q2)
);

endmodule

`resetall
