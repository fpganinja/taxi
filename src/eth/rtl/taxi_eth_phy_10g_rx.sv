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
 * 10G Ethernet PHY RX
 */
module taxi_eth_phy_10g_rx #
(
    parameter DATA_W = 64,
    parameter CTRL_W = (DATA_W/8),
    parameter HDR_W = 2,
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic SCRAMBLER_DISABLE = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 1,
    parameter BITSLIP_LOW_CYCLES = 7,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * XGMII interface
     */
    output wire logic [DATA_W-1:0]  xgmii_rxd,
    output wire logic [CTRL_W-1:0]  xgmii_rxc,
    output wire logic               xgmii_rx_valid,

    /*
     * SERDES interface
     */
    input  wire logic [DATA_W-1:0]  serdes_rx_data,
    input  wire logic               serdes_rx_data_valid = 1'b1,
    input  wire logic [HDR_W-1:0]   serdes_rx_hdr,
    input  wire logic               serdes_rx_hdr_valid = 1'b1,
    output wire logic               serdes_rx_bitslip,
    output wire logic               serdes_rx_reset_req,

    /*
     * Status
     */
    output wire logic [6:0]         rx_error_count,
    output wire logic               rx_bad_block,
    output wire logic               rx_sequence_error,
    output wire logic               rx_block_lock,
    output wire logic               rx_high_ber,
    output wire logic               rx_status,

    /*
     * Configuration
     */
    input  wire logic               cfg_rx_prbs31_enable
);

wire [DATA_W-1:0] encoded_rx_data;
wire encoded_rx_data_valid;
wire [HDR_W-1:0] encoded_rx_hdr;
wire encoded_rx_hdr_valid;

taxi_eth_phy_10g_rx_if #(
    .DATA_W(DATA_W),
    .HDR_W(HDR_W),
    .GBX_IF_EN(GBX_IF_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * 10GBASE-R encoded interface
     */
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_data_valid(encoded_rx_data_valid),
    .encoded_rx_hdr(encoded_rx_hdr),
    .encoded_rx_hdr_valid(encoded_rx_hdr_valid),

    /*
     * SERDES interface
     */
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_data_valid(serdes_rx_data_valid),
    .serdes_rx_hdr(serdes_rx_hdr),
    .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
    .serdes_rx_bitslip(serdes_rx_bitslip),
    .serdes_rx_reset_req(serdes_rx_reset_req),

    /*
     * Status
     */
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_error_count(rx_error_count),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),

    /*
     * Configuration
     */
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

taxi_xgmii_baser_dec #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .HDR_W(HDR_W),
    .GBX_IF_EN(GBX_IF_EN)
)
xgmii_baser_dec_inst (
    .clk(clk),
    .rst(rst),

    /*
     * 10GBASE-R encoded input
     */
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_data_valid(encoded_rx_data_valid),
    .encoded_rx_hdr(encoded_rx_hdr),
    .encoded_rx_hdr_valid(encoded_rx_hdr_valid),

    /*
     * XGMII interface
     */
    .xgmii_rxd(xgmii_rxd),
    .xgmii_rxc(xgmii_rxc),
    .xgmii_rx_valid(xgmii_rx_valid),

    /*
     * Ordered sets
     */
    .rx_os(),
    .rx_os_sig(),
    .rx_os_valid(),
    .rx_os_match(),
    .rx_idle_match(),

    /*
     * Status
     */
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error)
);

endmodule

`resetall
