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
 * 10G Ethernet MAC/PHY combination
 */
module taxi_eth_mac_phy_10g_rx #
(
    parameter DATA_W = 64,
    parameter HDR_W = (DATA_W/32),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic SCRAMBLER_DISABLE = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 0,
    parameter BITSLIP_LOW_CYCLES = 7,
    parameter COUNT_125US = 125000/6.4
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
    input  wire logic                 serdes_rx_data_valid = 1'b1,
    input  wire logic [HDR_W-1:0]     serdes_rx_hdr,
    input  wire logic                 serdes_rx_hdr_valid = 1'b1,
    output wire logic                 serdes_rx_bitslip,
    output wire logic                 serdes_rx_reset_req,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Status
     */
    output wire logic [1:0]           rx_start_packet,
    output wire logic [6:0]           rx_error_count,
    output wire logic                 rx_block_lock,
    output wire logic                 rx_high_ber,
    output wire logic                 rx_status,
    output wire logic [3:0]           stat_rx_byte,
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
    input  wire logic                 cfg_rx_prbs31_enable
);

wire [DATA_W-1:0] encoded_rx_data;
wire encoded_rx_data_valid;
wire [HDR_W-1:0]  encoded_rx_hdr;
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

if (DATA_W == 64) begin

    taxi_axis_baser_rx_64 #(
        .DATA_W(DATA_W),
        .HDR_W(HDR_W),
        .GBX_IF_EN(GBX_IF_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W)
    )
    axis_baser_rx_inst (
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
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx),

        /*
         * Ordered sets
         */
        .rx_os(),
        .rx_os_sig(),
        .rx_os_valid(),
        .rx_os_match(),
        .rx_idle_match(),

        /*
         * PTP
         */
        .ptp_ts(ptp_ts),

        /*
         * Configuration
         */
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
        .cfg_rx_enable(cfg_rx_enable),

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

    taxi_axis_baser_rx_32 #(
        .DATA_W(DATA_W),
        .HDR_W(HDR_W),
        .GBX_IF_EN(GBX_IF_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_W(PTP_TS_W)
    )
    axis_baser_rx_inst (
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
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx),

        /*
         * Ordered sets
         */
        .rx_os(),
        .rx_os_sig(),
        .rx_os_valid(),
        .rx_os_match(),
        .rx_idle_match(),

        /*
         * PTP
         */
        .ptp_ts(ptp_ts),

        /*
         * Configuration
         */
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
        .cfg_rx_enable(cfg_rx_enable),

        /*
         * Status
         */
        .rx_start_packet(rx_start_packet[0]),
        .stat_rx_byte(stat_rx_byte[2:0]),
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
    assign stat_rx_byte[3] = 1'b0;

end

endmodule

`resetall
