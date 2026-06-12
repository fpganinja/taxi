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
 * 1000BASE-X Ethernet PHY
 */
module taxi_eth_phy_1g_basex #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic TX_GBX_IF_EN = 1'b0,
    parameter logic RX_GBX_IF_EN = TX_GBX_IF_EN,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic ENC_8B10B_EN = 1'b0,
    parameter logic DEC_8B10B_EN = ENC_8B10B_EN,
    parameter logic PRBS31_EN = 1'b0,
    parameter TX_SERDES_PIPELINE = 0,
    parameter RX_SERDES_PIPELINE = 0,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire logic               rx_clk,
    input  wire logic               rx_rst,
    input  wire logic               tx_clk,
    input  wire logic               tx_rst,

    /*
     * GMII interface
     */
    input  wire logic [DATA_W-1:0]  gmii_txd,
    input  wire logic [CTRL_W-1:0]  gmii_tx_en,
    input  wire logic [CTRL_W-1:0]  gmii_tx_er,
    input  wire logic               gmii_tx_valid = 1'b1,
    output wire logic [DATA_W-1:0]  gmii_rxd,
    output wire logic [CTRL_W-1:0]  gmii_rx_dv,
    output wire logic [CTRL_W-1:0]  gmii_rx_er,
    output wire logic               gmii_rx_valid,
    output wire logic               tx_gbx_req_sync,
    output wire logic               tx_gbx_req_stall,
    input  wire logic               tx_gbx_sync = 1'b0,

    /*
     * SERDES interface
     */
    output wire logic [DATA_W-1:0]  serdes_tx_data,
    output wire logic [CTRL_W-1:0]  serdes_tx_data_k,
    output wire logic [CTRL_W-1:0]  serdes_tx_data_dm,
    output wire logic [CTRL_W-1:0]  serdes_tx_data_dv,
    output wire logic               serdes_tx_data_valid,
    input  wire logic               serdes_tx_gbx_req_sync = 1'b0,
    input  wire logic               serdes_tx_gbx_req_stall = 1'b0,
    output wire logic               serdes_tx_gbx_sync,
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
    input  wire logic               cfg_tx_prbs31_enable = 1'b0,
    input  wire logic               cfg_rx_prbs31_enable = 1'b0
);

taxi_eth_phy_1g_basex_rx #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(RX_GBX_IF_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .DEC_8B10B_EN(DEC_8B10B_EN),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .COUNT_125US(COUNT_125US)
)
rx_inst (
    .clk(rx_clk),
    .rst(rx_rst),

    /*
     * GMII interface
     */
    .gmii_rxd(gmii_rxd),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .gmii_rx_valid(gmii_rx_valid),

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
    .rx_error_count(rx_error_count),
    .stat_rx_err_bad_block(stat_rx_err_bad_block),
    .stat_rx_err_framing(stat_rx_err_framing),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),

    /*
     * Configuration
     */
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

taxi_eth_phy_1g_basex_tx #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(TX_GBX_IF_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .ENC_8B10B_EN(ENC_8B10B_EN),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(TX_SERDES_PIPELINE)
)
tx_inst (
    .clk(tx_clk),
    .rst(tx_rst),

    /*
     * GMII interface
     */
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .gmii_tx_valid(gmii_tx_valid),
    .tx_gbx_req_sync(tx_gbx_req_sync),
    .tx_gbx_req_stall(tx_gbx_req_stall),
    .tx_gbx_sync(tx_gbx_sync),

    /*
     * SERDES interface
     */
    .serdes_tx_data(serdes_tx_data),
    .serdes_tx_data_k(serdes_tx_data_k),
    .serdes_tx_data_dm(serdes_tx_data_dm),
    .serdes_tx_data_dv(serdes_tx_data_dv),
    .serdes_tx_data_valid(serdes_tx_data_valid),
    .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
    .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
    .serdes_tx_gbx_sync(serdes_tx_gbx_sync),

    /*
     * Configuration
     */
    .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable)
);

endmodule

`resetall
