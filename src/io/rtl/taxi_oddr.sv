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
 * Generic ODDR module
 */
module taxi_oddr #
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

    input  wire logic [WIDTH-1:0]  d1,
    input  wire logic [WIDTH-1:0]  d2,

    output wire logic [WIDTH-1:0]  q
);

/*

Provides a consistent output DDR flip flop across multiple FPGA families
              _____       _____       _____       _____
    clk  ____/     \_____/     \_____/     \_____/     \_____
         _ ___________ ___________ ___________ ___________ __
    d1   _X____D0_____X____D2_____X____D4_____X____D6_____X__
         _ ___________ ___________ ___________ ___________ __
    d2   _X____D1_____X____D3_____X____D5_____X____D7_____X__
         _____ _____ _____ _____ _____ _____ _____ _____ ____
    d    _____X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7_

*/

if (!SIM && VENDOR == "XILINX") begin
    // Xilinx/AMD device support

    if (FAMILY == "spartan6") begin
        // spartan6 uses IODDR2

        for (genvar n = 0; n < WIDTH; n = n + 1) begin : oddr
            ODDR2 #(
                .DDR_ALIGNMENT("C0"),
                .SRTYPE("ASYNC")
            )
            oddr_inst (
                .Q(q[n]),
                .C0(clk),
                .C1(~clk),
                .CE(1'b1),
                .D0(d1[n]),
                .D1(d2[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    end else begin
        // virtex4, virtex5, virtex6, virtex7, kintex7, artix7, virtexu, kintexu, virtexuplus, kintexuplus

        for (genvar n = 0; n < WIDTH; n = n + 1) begin : oddr
            ODDR #(
                .DDR_CLK_EDGE("SAME_EDGE"),
                .SRTYPE("ASYNC")
            )
            oddr_inst (
                .Q(q[n]),
                .C(clk),
                .CE(1'b1),
                .D1(d1[n]),
                .D2(d2[n]),
                .R(1'b0),
                .S(1'b0)
            );
        end
    end

end else if (!SIM && VENDOR == "ALTERA") begin
    // Altera/Intel/Altera device support

    altddio_out #(
        .WIDTH(WIDTH),
        .POWER_UP_HIGH("OFF"),
        .OE_REG("UNUSED")
    )
    altddio_out_inst (
        .aset(1'b0),
        .datain_h(d1),
        .datain_l(d2),
        .outclocken(1'b1),
        .outclock(clk),
        .aclr(1'b0),
        .dataout(q)
    );

end else if (!SIM && VENDOR == "LATTICE") begin
    // Lattice device support
    // ecp5: ODDRX1F in the I/O logic; D0 is driven while SCLK is high, D1 while low

    for (genvar n = 0; n < WIDTH; n = n + 1) begin : oddr
        ODDRX1F
        oddr_inst (
            .D0(d1[n]),
            .D1(d2[n]),
            .SCLK(clk),
            .RST(1'b0),
            .Q(q[n])
        );
    end

end else begin
    // generic/simulation implementation (no vendor primitives)

    logic [WIDTH-1:0] d1_reg = '0;
    logic [WIDTH-1:0] d2_reg = '0;

    always_ff @(posedge clk) begin
        d1_reg <= d1;
        d2_reg <= d2;
    end

    assign q = clk ? d1_reg : d2_reg;

end

endmodule

`resetall
