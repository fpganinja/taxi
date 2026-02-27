// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PCIe MSI-X module testbench
 */
module test_taxi_pcie_msix_apb #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter IRQ_INDEX_W = 11,
    parameter TLP_SEG_DATA_W = 64,
    parameter TLP_SEGS = 1,
    parameter APB_DATA_W = 32,
    parameter APB_ADDR_W = IRQ_INDEX_W+5,
    parameter logic TLP_FORCE_64_BIT_ADDR = 1'b0
    /* verilator lint_on WIDTHTRUNC */
)
();

logic clk;
logic rst;

taxi_apb_if #(
    .DATA_W(APB_DATA_W),
    .ADDR_W(APB_ADDR_W),
    .PAUSER_EN(1'b0),
    .PWUSER_EN(1'b0),
    .PBUSER_EN(1'b0),
    .PRUSER_EN(1'b0)
) s_apb();

taxi_axis_if #(
    .DATA_W(IRQ_INDEX_W),
    .KEEP_EN(0),
    .KEEP_W(1)
) s_axis_irq();

taxi_pcie_tlp_if #(
    .SEGS(TLP_SEGS),
    .SEG_DATA_W(TLP_SEG_DATA_W),
    .FUNC_NUM_W(8)
) tx_wr_req_tlp();

logic [7:0] bus_num;
logic [7:0] func_num;
logic msix_enable;
logic msix_mask;

taxi_pcie_msix_apb #(
    .TLP_FORCE_64_BIT_ADDR(TLP_FORCE_64_BIT_ADDR)
)
uut (
    .clk(clk),
    .rst(rst),

    /*
     * APB interface for MSI-X tables
     */
    .s_apb(s_apb),

    /*
     * Interrupt request input
     */
    .s_axis_irq(s_axis_irq),

    /*
     * Memory write TLP output
     */
    .tx_wr_req_tlp(tx_wr_req_tlp),

    /*
     * Configuration
     */
    .bus_num(bus_num),
    .func_num(func_num),
    .msix_enable(msix_enable),
    .msix_mask(msix_mask)
);

endmodule

`resetall
