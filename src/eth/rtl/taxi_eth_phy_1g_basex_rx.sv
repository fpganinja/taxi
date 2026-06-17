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
 * 1000BASE-X Ethernet PHY RX
 */
module taxi_eth_phy_1g_basex_rx #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic DEC_8B10B_EN = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * GMII interface
     */
    output wire logic [DATA_W-1:0]  gmii_rxd,
    output wire logic [CTRL_W-1:0]  gmii_rx_dv,
    output wire logic [CTRL_W-1:0]  gmii_rx_er,
    output wire logic               gmii_rx_valid,

    /*
     * SERDES interface
     */
    input  wire logic [DATA_W-1:0]  serdes_rx_data,
    input  wire logic [CTRL_W-1:0]  serdes_rx_data_k,
    input  wire logic               serdes_rx_data_valid = 1'b1,
    output wire logic               serdes_rx_reset_req,

    /*
     * Status
     */
    output wire logic [4:0]         rx_error_count,
    output wire logic               stat_rx_err_bad_block,
    output wire logic               stat_rx_err_framing,
    output wire logic               rx_block_lock,
    output wire logic               rx_high_ber,
    output wire logic               rx_status,

    /*
     * Configuration
     */
    input  wire logic               cfg_rx_prbs31_enable
);

wire [DATA_W-1:0] encoded_rx_data;
wire [CTRL_W-1:0] encoded_rx_data_k;
wire encoded_rx_data_valid;

taxi_eth_phy_1g_basex_rx_if #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(GBX_IF_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .DEC_8B10B_EN(DEC_8B10B_EN),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(SERDES_PIPELINE),
    .COUNT_125US(COUNT_125US)
)
rx_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * 1000BASE-X encoded interface
     */
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_data_k(encoded_rx_data_k),
    .encoded_rx_data_valid(encoded_rx_data_valid),

    /*
     * SERDES interface
     */
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_data_k(serdes_rx_data_k),
    .serdes_rx_data_valid(serdes_rx_data_valid),
    .serdes_rx_reset_req(serdes_rx_reset_req),

    /*
     * Status
     */
    .rx_bad_block(stat_rx_err_bad_block),
    .rx_sequence_error(stat_rx_err_framing),
    .rx_error_count(rx_error_count),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),

    /*
     * Configuration
     */
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

taxi_gmii_basex_dec #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(GBX_IF_EN),
    .AN_EN(1'b0)
)
dec_inst (
    .clk(clk),
    .rst(rst),

    /*
     * 1000BASE-X encoded input
     */
    .encoded_rx_data(encoded_rx_data),
    .encoded_rx_data_k(encoded_rx_data_k),
    .encoded_rx_data_valid(encoded_rx_data_valid),

    /*
     * GMII interface
     */
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .gmii_rx_valid(gmii_rx_valid),

    /*
     * AN config register
     */
    .rx_an_cfg(),
    .rx_an_cfg_valid(),
    .rx_an_ability_match(),
    .rx_an_ack_match(),
    .rx_an_idle_match(),

    /*
     * Status
     */
    .stat_rx_err_bad_block(stat_rx_err_bad_block),
    .stat_rx_err_framing(stat_rx_err_framing)
);

endmodule

`resetall
