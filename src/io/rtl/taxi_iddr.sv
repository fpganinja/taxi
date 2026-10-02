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
 * Generic IDDR module
 */
module taxi_iddr #
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
    input  wire logic              clk,

    input  wire logic [WIDTH-1:0]  d,

    output wire logic [WIDTH-1:0]  q1,
    output wire logic [WIDTH-1:0]  q2
);

/*

Provides a consistent input DDR flip flop across multiple FPGA families
              _____       _____       _____       _____       ____
    clk  ____/     \_____/     \_____/     \_____/     \_____/
         _ _____ _____ _____ _____ _____ _____ _____ _____ _____ _
    d    _X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7__X_D8__X_
         _______ ___________ ___________ ___________ ___________ _
    q1   _______X___________X____D0_____X____D2_____X____D4_____X_
         _______ ___________ ___________ ___________ ___________ _
    q2   _______X___________X____D1_____X____D3_____X____D5_____X_

*/

if (!SIM && VENDOR == "XILINX") begin
    // Xilinx/AMD device support

    if (FAMILY == "spartan6") begin
        // spartan6 uses IODDR2

        for (genvar n = 0; n < WIDTH; n = n + 1) begin : iddr
            wire q1_int;
            logic q1_delay = 1'b0;

            IDDR2 #(
                .DDR_ALIGNMENT("C0")
            )
            iddr_inst (
                .Q0(q1_int),
                .Q1(q2[n]),
                .C0(clk),
                .C1(~clk),
                .CE(1'b1),
                .D(d[n]),
                .R(1'b0),
                .S(1'b0)
            );

            always_ff @(posedge clk) begin
                q1_delay <= q1_int;
            end

            assign q1[n] = q1_delay;
        end
    end else begin
        // virtex4, virtex5, virtex6, virtex7, kintex7, artix7, virtexu, kintexu, virtexuplus, kintexuplus

        for (genvar n = 0; n < WIDTH; n = n + 1) begin : iddr
            IDDR #(
                .DDR_CLK_EDGE("SAME_EDGE_PIPELINED"),
                .SRTYPE("ASYNC")
            )
            iddr_inst (
                .Q1(q1[n]),
                .Q2(q2[n]),
                .C(clk),
                .CE(1'b1),
                .D(d[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    end

end else if (!SIM && VENDOR == "ALTERA") begin
    // Altera/Intel/Altera device support

    wire [WIDTH-1:0] q1_int;
    logic [WIDTH-1:0] q1_delay = '0;

    altddio_in #(
        .WIDTH(WIDTH),
        .POWER_UP_HIGH("OFF")
    )
    altddio_in_inst (
        .aset(1'b0),
        .datain(d),
        .inclocken(1'b1),
        .inclock(clk),
        .aclr(1'b0),
        .dataout_h(q1_int),
        .dataout_l(q2)
    );

    always_ff @(posedge clk) begin
        q1_delay <= q1_int;
    end

    assign q1 = q1_delay;

end else if (!SIM && VENDOR == "LATTICE") begin
    // Lattice device support
    // ecp5: IDDRX1F in the I/O logic; Q0 = data captured on the rising edge,
    // Q1 = data captured on the following falling edge, both on SCLK rising

    for (genvar n = 0; n < WIDTH; n = n + 1) begin : iddr
        IDDRX1F
        iddr_inst (
            .D(d[n]),
            .SCLK(clk),
            .RST(1'b0),
            .Q0(q1[n]),
            .Q1(q2[n])
        );
    end

end else begin
    // generic/simulation implementation (no vendor primitives)

    logic [WIDTH-1:0] d_reg_1 = '0;
    logic [WIDTH-1:0] d_reg_2 = '0;

    logic [WIDTH-1:0] q_reg_1 = '0;
    logic [WIDTH-1:0] q_reg_2 = '0;

    always_ff @(posedge clk) begin
        d_reg_1 <= d;
    end

    always_ff @(negedge clk) begin
        d_reg_2 <= d;
    end

    always_ff @(posedge clk) begin
        q_reg_1 <= d_reg_1;
        q_reg_2 <= d_reg_2;
    end

    assign q1 = q_reg_1;
    assign q2 = q_reg_2;

end

endmodule

`resetall
