// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DMA RAM demux
 */
module taxi_dma_ram_demux #
(
    // Number of ports
    parameter PORTS = 2
)
(
    input  wire logic       clk,
    input  wire logic       rst,

    /*
     * RAM interface (from DMA client/interface)
     */
    taxi_dma_ram_if.wr_slv  dma_ram_wr,
    taxi_dma_ram_if.rd_slv  dma_ram_rd,

    /*
     * RAM interface (towards RAM)
     */
    taxi_dma_ram_if.wr_mst  ram_wr[PORTS],
    taxi_dma_ram_if.rd_mst  ram_rd[PORTS]
);

taxi_dma_ram_demux_wr #(
    .PORTS(PORTS)
)
wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * RAM interface (from DMA client/interface)
     */
    .dma_ram_wr(dma_ram_wr),

    /*
     * RAM interface (towards RAM)
     */
    .ram_wr(ram_wr)
);

taxi_dma_ram_demux_rd #(
    .PORTS(PORTS)
)
rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * RAM interface (from DMA client/interface)
     */
    .dma_ram_rd(dma_ram_rd),

    /*
     * RAM interface (towards RAM)
     */
    .ram_rd(ram_rd)
);

endmodule

`resetall
