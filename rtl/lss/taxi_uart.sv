// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2014-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream UART
 */
module taxi_uart
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * AXI4-Stream input (sink)
     */
    taxi_axis_if.snk          s_axis_tx,

    /*
     * AXI4-Stream output (source)
     */
    taxi_axis_if.src          m_axis_rx,

    /*
     * UART interface
     */
    input  wire logic         rxd,
    output wire logic         txd,

    /*
     * Status
     */
    output wire logic         tx_busy,
    output wire logic         rx_busy,
    output wire logic         rx_overrun_error,
    output wire logic         rx_frame_error,

    /*
     * Configuration
     */
    input  wire logic [15:0]  prescale

);

taxi_uart_tx
uart_tx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Stream input (sink)
     */
    .s_axis_tx(s_axis_tx),

    /*
     * UART interface
     */
    .txd(txd),

    /*
     * Status
     */
    .busy(tx_busy),

    /*
     * Configuration
     */
    .prescale(prescale)
);

taxi_uart_rx
uart_rx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis_rx(m_axis_rx),

    /*
     * UART interface
     */
    .rxd(rxd),

    /*
     * Status
     */
    .busy(rx_busy),
    .overrun_error(rx_overrun_error),
    .frame_error(rx_frame_error),

    /*
     * Configuration
     */
    .prescale(prescale)
);

endmodule

`resetall
