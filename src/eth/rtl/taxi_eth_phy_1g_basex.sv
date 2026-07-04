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
    parameter logic AN_EN = 1'b1,
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
     * Autonegotiation
     */
    input  wire logic               an_en = 1'b1,
    input  wire logic               an_restart = 1'b0,
    input  wire logic               an_speedup = 1'b0,
    input  wire logic               an_timeout_en = 1'b1,
    output wire logic               an_intr,
    output wire logic               an_running,
    output wire logic               an_complete,
    output wire logic               an_timeout,
    input  wire logic [15:0]        an_adv_ability = 16'h0020,
    output wire logic [15:0]        an_lp_adv_ability,
    output wire logic [1:0]         an_lp_remote_fault,
    output wire logic               an_res_full_duplex,
    output wire logic               an_res_tx_pause,
    output wire logic               an_res_rx_pause,

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

// Autonegotiation
wire logic [15:0]  rx_an_cfg;
wire logic         rx_an_cfg_valid;
wire logic         rx_an_ability_match;
wire logic         rx_an_ack_match;
wire logic         rx_an_idle_match;

wire logic [15:0]  tx_an_cfg;
wire logic         tx_an_cfg_valid;
wire logic         tx_an_cfg_ready;

if (AN_EN) begin : an

    // synchronize RX signals to TX
    wire [15:0]  sync_rx_an_cfg;
    wire         sync_rx_an_cfg_valid;
    wire         sync_rx_an_ability_match;
    wire         sync_rx_an_ack_match;
    wire         sync_rx_an_idle_match;

    taxi_sync_signal #(
        .WIDTH(16+4),
        .N(2)
    )
    sync_inst (
        .clk(tx_clk),

        .in({
            rx_an_cfg,
            rx_an_cfg_valid,
            rx_an_ability_match,
            rx_an_ack_match,
            rx_an_idle_match
        }),
        .out({
            sync_rx_an_cfg,
            sync_rx_an_cfg_valid,
            sync_rx_an_ability_match,
            sync_rx_an_ack_match,
            sync_rx_an_idle_match
        })
    );

    taxi_eth_phy_1g_basex_an #(
        .DATA_W(DATA_W)
    )
    an_inst (
        .clk(tx_clk),
        .rst(tx_rst),

        /*
        * AN config register
        */
        .rx_an_cfg(sync_rx_an_cfg),
        .rx_an_cfg_valid(sync_rx_an_cfg_valid),
        .rx_an_ability_match(sync_rx_an_ability_match),
        .rx_an_ack_match(sync_rx_an_ack_match),
        .rx_an_idle_match(sync_rx_an_idle_match),

        .tx_an_cfg(tx_an_cfg),
        .tx_an_cfg_valid(tx_an_cfg_valid),
        .tx_an_cfg_ready(tx_an_cfg_ready),

        /*
         * Autonegotiation
         */
        .an_en(an_en),
        .an_restart(an_restart),
        .an_speedup(an_speedup),
        .an_timeout_en(an_timeout_en),
        .an_intr(an_intr),
        .an_running(an_running),
        .an_complete(an_complete),
        .an_timeout(an_timeout),
        .an_adv_ability(an_adv_ability),
        .an_lp_adv_ability(an_lp_adv_ability),
        .an_lp_remote_fault(an_lp_remote_fault),
        .an_res_full_duplex(an_res_full_duplex),
        .an_res_tx_pause(an_res_tx_pause),
        .an_res_rx_pause(an_res_rx_pause)
    );

end else begin : an

    assign tx_an_cfg = '0;
    assign tx_an_cfg_valid = 1'b0;

    assign an_intr = 1'b0;
    assign an_complete = 1'b0;
    assign an_lp_adv_ability = '0;

end

taxi_eth_phy_1g_basex_rx #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .GBX_IF_EN(RX_GBX_IF_EN),
    .AN_EN(AN_EN),
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
     * AN config register
     */
    .rx_an_cfg(rx_an_cfg),
    .rx_an_cfg_valid(rx_an_cfg_valid),
    .rx_an_ability_match(rx_an_ability_match),
    .rx_an_ack_match(rx_an_ack_match),
    .rx_an_idle_match(rx_an_idle_match),

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
    .AN_EN(AN_EN),
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
     * AN config register
     */
    .tx_an_cfg(tx_an_cfg),
    .tx_an_cfg_valid(tx_an_cfg_valid),
    .tx_an_cfg_ready(tx_an_cfg_ready),

    /*
     * Configuration
     */
    .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable)
);

endmodule

`resetall
