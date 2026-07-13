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
module taxi_eth_mac_phy_10g_tx #
(
    parameter DATA_W = 64,
    parameter HDR_W = (DATA_W/32),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic USXGMII_EN = 1'b0,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter logic TX_CPL_CTRL_IN_TUSER = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic SCRAMBLER_DISABLE = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * Transmit interface (AXI stream)
     */
    taxi_axis_if.snk                  s_axis_tx,
    taxi_axis_if.src                  m_axis_tx_cpl,

    /*
     * SERDES interface
     */
    output wire logic [DATA_W-1:0]    serdes_tx_data,
    output wire logic                 serdes_tx_data_valid,
    output wire logic [HDR_W-1:0]     serdes_tx_hdr,
    output wire logic                 serdes_tx_hdr_valid,
    input  wire logic                 serdes_tx_gbx_req_sync = 1'b0,
    input  wire logic                 serdes_tx_gbx_req_stall = 1'b0,
    output wire logic                 serdes_tx_gbx_sync,

    /*
     * Ordered sets
     */
    input  wire logic [23:0]          tx_os = '0,
    input  wire logic                 tx_os_sig = 1'b0,
    input  wire logic                 tx_os_valid = 1'b0,
    output wire logic                 tx_os_ready,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Status
     */
    output wire logic [1:0]           tx_start_packet,
    output wire logic [3:0]           stat_tx_byte,
    output wire logic [15:0]          stat_tx_pkt_len,
    output wire logic                 stat_tx_pkt_ucast,
    output wire logic                 stat_tx_pkt_mcast,
    output wire logic                 stat_tx_pkt_bcast,
    output wire logic                 stat_tx_pkt_vlan,
    output wire logic                 stat_tx_pkt_good,
    output wire logic                 stat_tx_pkt_bad,
    output wire logic                 stat_tx_pad_frame,
    output wire logic                 stat_tx_err_oversize,
    output wire logic                 stat_tx_err_user,
    output wire logic                 stat_tx_err_underflow,

    /*
     * Configuration
     */
    input  wire logic                 cfg_tx_pad_en = 1'b1,
    input  wire logic [7:0]           cfg_tx_min_pkt_len = 8'd60-1,
    input  wire logic [15:0]          cfg_tx_max_pkt_len = 16'd1518-1,
    input  wire logic [7:0]           cfg_tx_ifg = 8'd12,
    input  wire logic                 cfg_tx_enable,
    input  wire logic                 cfg_tx_usxgmii_en = 1'b1,
    input  wire logic                 cfg_tx_usxgmii_5g = 1'b0,
    input  wire logic [2:0]           cfg_tx_usxgmii_speed = 3'b011,
    input  wire logic                 cfg_tx_prbs31_enable
);

localparam TX_USER_W = s_axis_tx.USER_W;
localparam TX_TAG_W = s_axis_tx.ID_W;

wire [DATA_W-1:0] encoded_tx_data;
wire              encoded_tx_data_valid;
wire [HDR_W-1:0]  encoded_tx_hdr;
wire              encoded_tx_hdr_valid;

wire tx_gbx_req_sync;
wire tx_gbx_req_stall;
wire tx_gbx_sync;

taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(TX_USER_W), .ID_EN(1), .ID_W(TX_TAG_W)) axis_tx_pad();

taxi_axis_pad #(
    .ID_PAD_REG_EN(1'b0),
    .DEST_PAD_REG_EN(1'b0),
    .USER_PAD_REG_EN(1'b1),
    .MIN_LEN_W(8),
    .UNDERFLOW_DROP_EN(1'b1)
)
tx_pad_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Stream input (sink)
     */
    .s_axis(s_axis_tx),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(axis_tx_pad),

    /*
     * Configuration
     */
    .cfg_pad_en(cfg_tx_pad_en),
    .cfg_min_pkt_len(cfg_tx_min_pkt_len),

    /*
     * Status
     */
    .stat_pad_frame(stat_tx_pad_frame),
    .stat_err_user(),
    .stat_err_underflow(stat_tx_err_underflow)
);

if (DATA_W == 64) begin

    if (USXGMII_EN)
        $fatal(0, "Error: USXGMII is not currently supported in 64-bit mode (instance %m)");

    taxi_axis_baser_tx_64 #(
        .DATA_W(DATA_W),
        .HDR_W(HDR_W),
        .GBX_IF_EN(GBX_IF_EN),
        .GBX_CNT(1),
        .DIC_EN(DIC_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W),
        .TX_CPL_CTRL_IN_TUSER(TX_CPL_CTRL_IN_TUSER)
    )
    axis_baser_tx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_tx_pad),
        .m_axis_tx_cpl(m_axis_tx_cpl),

        /*
         * 10GBASE-R encoded interface
         */
        .encoded_tx_data(encoded_tx_data),
        .encoded_tx_data_valid(encoded_tx_data_valid),
        .encoded_tx_hdr(encoded_tx_hdr),
        .encoded_tx_hdr_valid(encoded_tx_hdr_valid),
        .tx_gbx_req_sync(tx_gbx_req_sync),
        .tx_gbx_req_stall(tx_gbx_req_stall),
        .tx_gbx_sync(tx_gbx_sync),

        /*
         * Ordered sets
         */
        .tx_os(tx_os),
        .tx_os_sig(tx_os_sig),
        .tx_os_valid(tx_os_valid),
        .tx_os_ready(tx_os_ready),

        /*
         * PTP
         */
        .ptp_ts(ptp_ts),

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
        .cfg_tx_ifg(cfg_tx_ifg),
        .cfg_tx_enable(cfg_tx_enable),

        /*
         * Status
         */
        .tx_start_packet(tx_start_packet),
        .stat_tx_byte(stat_tx_byte),
        .stat_tx_pkt_len(stat_tx_pkt_len),
        .stat_tx_pkt_ucast(stat_tx_pkt_ucast),
        .stat_tx_pkt_mcast(stat_tx_pkt_mcast),
        .stat_tx_pkt_bcast(stat_tx_pkt_bcast),
        .stat_tx_pkt_vlan(stat_tx_pkt_vlan),
        .stat_tx_pkt_good(stat_tx_pkt_good),
        .stat_tx_pkt_bad(stat_tx_pkt_bad),
        .stat_tx_err_oversize(stat_tx_err_oversize),
        .stat_tx_err_user(stat_tx_err_user),
        .stat_tx_err_underflow()
    );

end else begin

    taxi_axis_baser_tx_32 #(
        .DATA_W(DATA_W),
        .HDR_W(HDR_W),
        .GBX_IF_EN(GBX_IF_EN),
        .GBX_CNT(1),
        .USXGMII_EN(USXGMII_EN),
        .DIC_EN(DIC_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_W(PTP_TS_W),
        .TX_CPL_CTRL_IN_TUSER(TX_CPL_CTRL_IN_TUSER)
    )
    axis_baser_tx_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_tx_pad),
        .m_axis_tx_cpl(m_axis_tx_cpl),

        /*
         * 10GBASE-R encoded interface
         */
        .encoded_tx_data(encoded_tx_data),
        .encoded_tx_data_valid(encoded_tx_data_valid),
        .encoded_tx_hdr(encoded_tx_hdr),
        .encoded_tx_hdr_valid(encoded_tx_hdr_valid),
        .tx_gbx_req_sync(tx_gbx_req_sync),
        .tx_gbx_req_stall(tx_gbx_req_stall),
        .tx_gbx_sync(tx_gbx_sync),

        /*
         * Ordered sets
         */
        .tx_os(tx_os),
        .tx_os_sig(tx_os_sig),
        .tx_os_valid(tx_os_valid),
        .tx_os_ready(tx_os_ready),

        /*
         * PTP
         */
        .ptp_ts(ptp_ts),

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
        .cfg_tx_ifg(cfg_tx_ifg),
        .cfg_tx_enable(cfg_tx_enable),
        .cfg_tx_usxgmii_en(cfg_tx_usxgmii_en),
        .cfg_tx_usxgmii_5g(cfg_tx_usxgmii_5g),
        .cfg_tx_usxgmii_speed(cfg_tx_usxgmii_speed),

        /*
         * Status
         */
        .tx_start_packet(tx_start_packet[0]),
        .stat_tx_byte(stat_tx_byte[2:0]),
        .stat_tx_pkt_len(stat_tx_pkt_len),
        .stat_tx_pkt_ucast(stat_tx_pkt_ucast),
        .stat_tx_pkt_mcast(stat_tx_pkt_mcast),
        .stat_tx_pkt_bcast(stat_tx_pkt_bcast),
        .stat_tx_pkt_vlan(stat_tx_pkt_vlan),
        .stat_tx_pkt_good(stat_tx_pkt_good),
        .stat_tx_pkt_bad(stat_tx_pkt_bad),
        .stat_tx_err_oversize(stat_tx_err_oversize),
        .stat_tx_err_user(stat_tx_err_user),
        .stat_tx_err_underflow()
    );

    assign tx_start_packet[1] = 1'b0;
    assign stat_tx_byte[3] = 1'b0;

end

taxi_eth_phy_10g_tx_if #(
    .DATA_W(DATA_W),
    .HDR_W(HDR_W),
    .GBX_IF_EN(GBX_IF_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(SERDES_PIPELINE)
)
eth_phy_10g_tx_if_inst (
    .clk(clk),
    .rst(rst),

    /*
     * 10GBASE-R encoded interface
     */
    .encoded_tx_data(encoded_tx_data),
    .encoded_tx_data_valid(encoded_tx_data_valid),
    .encoded_tx_hdr(encoded_tx_hdr),
    .encoded_tx_hdr_valid(encoded_tx_hdr_valid),
    .tx_gbx_req_sync(tx_gbx_req_sync),
    .tx_gbx_req_stall(tx_gbx_req_stall),
    .tx_gbx_sync(tx_gbx_sync),

    /*
     * SERDES interface
     */
    .serdes_tx_data(serdes_tx_data),
    .serdes_tx_data_valid(serdes_tx_data_valid),
    .serdes_tx_hdr(serdes_tx_hdr),
    .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
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
