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
 * 1000BASE-X Ethernet MAC/PHY combination
 */
module taxi_eth_mac_phy_1g_basex_rx #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic SGMII_EN = 1'b1,
    parameter logic AN_EN = SGMII_EN,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic DEC_8B10B_EN = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx,

    /*
     * SERDES interface
     */
    input  wire logic [DATA_W-1:0]    serdes_rx_data,
    input  wire logic [CTRL_W-1:0]    serdes_rx_data_k,
    input  wire logic                 serdes_rx_data_valid = 1'b1,
    output wire logic                 serdes_rx_reset_req,

    /*
     * AN config register
     */
    output wire logic [15:0]          rx_an_cfg,
    output wire logic                 rx_an_cfg_valid,
    output wire logic                 rx_an_ability_match,
    output wire logic                 rx_an_ack_match,
    output wire logic                 rx_an_idle_match,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Status
     */
    output wire logic [1:0]           rx_start_packet,
    output wire logic [4:0]           rx_error_count,
    output wire logic                 rx_block_lock,
    output wire logic                 rx_high_ber,
    output wire logic                 rx_status,
    output wire logic [1:0]           stat_rx_byte,
    output wire logic [15:0]          stat_rx_pkt_len,
    output wire logic                 stat_rx_pkt_fragment,
    output wire logic                 stat_rx_pkt_jabber,
    output wire logic                 stat_rx_pkt_ucast,
    output wire logic                 stat_rx_pkt_mcast,
    output wire logic                 stat_rx_pkt_bcast,
    output wire logic                 stat_rx_pkt_vlan,
    output wire logic                 stat_rx_pkt_good,
    output wire logic                 stat_rx_pkt_bad,
    output wire logic                 stat_rx_err_oversize,
    output wire logic                 stat_rx_err_bad_fcs,
    output wire logic                 stat_rx_err_bad_block,
    output wire logic                 stat_rx_err_framing,
    output wire logic                 stat_rx_err_preamble,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_rx_max_pkt_len = 16'd1518-1,
    input  wire logic                 cfg_rx_enable,
    input  wire logic                 cfg_rx_sgmii_en = 1'b1,
    input  wire logic [1:0]           cfg_rx_sgmii_speed = 2'b10,
    input  wire logic                 cfg_rx_prbs31_enable
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
    .SERDES_PIPELINE(SERDES_PIPELINE)
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

if (DATA_W == 16) begin

    taxi_axis_basex_rx_16 #(
        .DATA_W(DATA_W),
        .CTRL_W(CTRL_W),
        .GBX_IF_EN(GBX_IF_EN),
        .SGMII_EN(SGMII_EN),
        .AN_EN(AN_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W)
    )
    rx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * 1000BASE-X encoded input
         */
        .encoded_rx_data(encoded_rx_data),
        .encoded_rx_data_k(encoded_rx_data_k),
        .encoded_rx_data_valid(encoded_rx_data_valid),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx),

        /*
         * AN config register
         */
        .rx_an_cfg(rx_an_cfg),
        .rx_an_cfg_valid(rx_an_cfg_valid),
        .rx_an_ability_match(rx_an_ability_match),
        .rx_an_ack_match(rx_an_ack_match),
        .rx_an_idle_match(rx_an_idle_match),

        /*
         * PTP
         */
        .ptp_ts(ptp_ts),

        /*
         * Configuration
         */
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
        .cfg_rx_enable(cfg_rx_enable),
        .cfg_rx_sgmii_en(cfg_rx_sgmii_en),
        .cfg_rx_sgmii_speed(cfg_rx_sgmii_speed),

        /*
         * Status
         */
        .rx_start_packet(rx_start_packet),
        .stat_rx_byte(stat_rx_byte),
        .stat_rx_pkt_len(stat_rx_pkt_len),
        .stat_rx_pkt_fragment(stat_rx_pkt_fragment),
        .stat_rx_pkt_jabber(stat_rx_pkt_jabber),
        .stat_rx_pkt_ucast(stat_rx_pkt_ucast),
        .stat_rx_pkt_mcast(stat_rx_pkt_mcast),
        .stat_rx_pkt_bcast(stat_rx_pkt_bcast),
        .stat_rx_pkt_vlan(stat_rx_pkt_vlan),
        .stat_rx_pkt_good(stat_rx_pkt_good),
        .stat_rx_pkt_bad(stat_rx_pkt_bad),
        .stat_rx_err_oversize(stat_rx_err_oversize),
        .stat_rx_err_bad_fcs(stat_rx_err_bad_fcs),
        .stat_rx_err_bad_block(stat_rx_err_bad_block),
        .stat_rx_err_framing(stat_rx_err_framing),
        .stat_rx_err_preamble(stat_rx_err_preamble)
    );

end else begin

    taxi_axis_basex_rx_8 #(
        .DATA_W(DATA_W),
        .CTRL_W(CTRL_W),
        .GBX_IF_EN(GBX_IF_EN),
        .SGMII_EN(SGMII_EN),
        .AN_EN(AN_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_W(PTP_TS_W)
    )
    rx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * 1000BASE-X encoded input
         */
        .encoded_rx_data(encoded_rx_data),
        .encoded_rx_data_k(encoded_rx_data_k),
        .encoded_rx_data_valid(encoded_rx_data_valid),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx),

        /*
         * AN config register
         */
        .rx_an_cfg(rx_an_cfg),
        .rx_an_cfg_valid(rx_an_cfg_valid),
        .rx_an_ability_match(rx_an_ability_match),
        .rx_an_ack_match(rx_an_ack_match),
        .rx_an_idle_match(rx_an_idle_match),

        /*
         * PTP
         */
        .ptp_ts(ptp_ts),

        /*
         * Configuration
         */
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
        .cfg_rx_enable(cfg_rx_enable),
        .cfg_rx_sgmii_en(cfg_rx_sgmii_en),
        .cfg_rx_sgmii_speed(cfg_rx_sgmii_speed),

        /*
         * Status
         */
        .rx_start_packet(rx_start_packet[0]),
        .stat_rx_byte(stat_rx_byte[0]),
        .stat_rx_pkt_len(stat_rx_pkt_len),
        .stat_rx_pkt_fragment(stat_rx_pkt_fragment),
        .stat_rx_pkt_jabber(stat_rx_pkt_jabber),
        .stat_rx_pkt_ucast(stat_rx_pkt_ucast),
        .stat_rx_pkt_mcast(stat_rx_pkt_mcast),
        .stat_rx_pkt_bcast(stat_rx_pkt_bcast),
        .stat_rx_pkt_vlan(stat_rx_pkt_vlan),
        .stat_rx_pkt_good(stat_rx_pkt_good),
        .stat_rx_pkt_bad(stat_rx_pkt_bad),
        .stat_rx_err_oversize(stat_rx_err_oversize),
        .stat_rx_err_bad_fcs(stat_rx_err_bad_fcs),
        .stat_rx_err_bad_block(stat_rx_err_bad_block),
        .stat_rx_err_framing(stat_rx_err_framing),
        .stat_rx_err_preamble(stat_rx_err_preamble)
    );

    assign rx_start_packet[1] = 1'b0;
    assign stat_rx_byte[1] = 1'b0;

end

endmodule

`resetall
