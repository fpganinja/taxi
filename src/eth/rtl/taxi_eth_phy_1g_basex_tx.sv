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
 * 1000BASE-X Ethernet PHY TX
 */
module taxi_eth_phy_1g_basex_tx #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic ENC_8B10B_EN = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * GMII interface
     */
    input  wire logic [DATA_W-1:0]  gmii_txd,
    input  wire logic [CTRL_W-1:0]  gmii_tx_en,
    input  wire logic [CTRL_W-1:0]  gmii_tx_er,
    input  wire logic               gmii_tx_valid = 1'b1,
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

    /*
     * Configuration
     */
    input  wire logic               cfg_tx_prbs31_enable
);

wire [DATA_W-1:0] encoded_tx_data;
wire [CTRL_W-1:0] encoded_tx_data_k;
wire [CTRL_W-1:0] encoded_tx_data_dm;
wire [CTRL_W-1:0] encoded_tx_data_dv;
wire              encoded_tx_data_valid;

wire tx_gbx_sync_int;

taxi_gmii_basex_enc #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(GBX_IF_EN),
    .GBX_CNT(1)
)
enc_inst (
    .clk(clk),
    .rst(rst),

    /*
     * GMII interface
     */
    .gmii_txd(gmii_txd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .gmii_tx_valid(gmii_tx_valid),
    .tx_gbx_sync_in(tx_gbx_sync),

    /*
     * 1000BASE-X encoded interface
     */
    .encoded_tx_data(encoded_tx_data),
    .encoded_tx_data_k(encoded_tx_data_k),
    .encoded_tx_data_dm(encoded_tx_data_dm),
    .encoded_tx_data_dv(encoded_tx_data_dv),
    .encoded_tx_data_valid(encoded_tx_data_valid),
    .tx_gbx_sync_out(tx_gbx_sync_int)
);

taxi_eth_phy_1g_basex_tx_if #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(GBX_IF_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .ENC_8B10B_EN(ENC_8B10B_EN),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(SERDES_PIPELINE)
)
tx_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * 1000BASE-X encoded interface
     */
    .encoded_tx_data(encoded_tx_data),
    .encoded_tx_data_k(encoded_tx_data_k),
    .encoded_tx_data_dm(encoded_tx_data_dm),
    .encoded_tx_data_dv(encoded_tx_data_dv),
    .encoded_tx_data_valid(encoded_tx_data_valid),
    .tx_gbx_req_sync(tx_gbx_req_sync),
    .tx_gbx_req_stall(tx_gbx_req_stall),
    .tx_gbx_sync(tx_gbx_sync_int),

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
