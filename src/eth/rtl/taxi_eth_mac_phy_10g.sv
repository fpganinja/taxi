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
module taxi_eth_mac_phy_10g #
(
    parameter DATA_W = 64,
    parameter HDR_W = (DATA_W/32),
    parameter logic TX_GBX_IF_EN = 1'b0,
    parameter logic RX_GBX_IF_EN = TX_GBX_IF_EN,
    parameter logic USXGMII_EN = 1'b0,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TD_EN = PTP_TS_EN,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter PTP_TD_SDI_PIPELINE = 2,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic SCRAMBLER_DISABLE = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter TX_SERDES_PIPELINE = 0,
    parameter RX_SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 0,
    parameter BITSLIP_LOW_CYCLES = 7,
    parameter COUNT_125US = 125000/6.4,
    parameter logic PFC_EN = 1'b0,
    parameter logic PAUSE_EN = PFC_EN,
    parameter logic STAT_EN = 1'b0,
    parameter STAT_TX_LEVEL = 1,
    parameter STAT_RX_LEVEL = 1,
    parameter STAT_ID_BASE = 0,
    parameter STAT_UPDATE_PERIOD = 1024,
    parameter logic STAT_STR_EN = 1'b0,
    parameter logic [8*8-1:0] STAT_PREFIX_STR = "MAC"
)
(
    input  wire logic                 rx_clk,
    input  wire logic                 rx_rst,
    input  wire logic                 tx_clk,
    input  wire logic                 tx_rst,

    /*
     * Transmit interface (AXI stream)
     */
    taxi_axis_if.snk                  s_axis_tx,
    taxi_axis_if.src                  m_axis_tx_cpl,

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx,

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
    input  wire logic [DATA_W-1:0]    serdes_rx_data,
    input  wire logic                 serdes_rx_data_valid = 1'b1,
    input  wire logic [HDR_W-1:0]     serdes_rx_hdr,
    input  wire logic                 serdes_rx_hdr_valid = 1'b1,
    output wire logic                 serdes_rx_bitslip,
    output wire logic                 serdes_rx_reset_req,

    /*
     * USXGMII autonegotiation
     */
    input  wire logic                 an_en = 1'b1,
    input  wire logic                 an_restart = 1'b0,
    input  wire logic                 an_speedup = 1'b0,
    input  wire logic                 an_timeout_en = 1'b1,
    input  wire logic                 an_usxgmii_en = 1'b0,
    input  wire logic                 an_usxgmii_auto = 1'b1,
    input  wire logic                 an_usxgmii_5g = 1'b0,
    output wire logic                 an_intr,
    output wire logic                 an_running,
    output wire logic                 an_complete,
    output wire logic                 an_timeout,
    output wire logic                 an_usxgmii_mode,
    input  wire logic [15:0]          an_adv_ability_usxgmii = 16'h1601,
    output wire logic [15:0]          an_lp_adv_ability,
    output wire logic                 an_lp_usxgmii_link,
    output wire logic [2:0]           an_lp_usxgmii_speed,
    output wire logic                 an_res_full_duplex,

    /*
     * PTP
     */
    input  wire logic                 ptp_clk = 1'b0,
    input  wire logic                 ptp_rst = 1'b0,
    input  wire logic                 ptp_sample_clk = 1'b0,
    input  wire logic                 ptp_td_sdi = 1'b0,
    input  wire logic [PTP_TS_W-1:0]  tx_ptp_ts_in = '0,
    output wire logic [PTP_TS_W-1:0]  tx_ptp_ts_out,
    output wire logic                 tx_ptp_ts_step_out,
    output wire logic                 tx_ptp_locked,
    input  wire logic [PTP_TS_W-1:0]  rx_ptp_ts_in = '0,
    output wire logic [PTP_TS_W-1:0]  rx_ptp_ts_out,
    output wire logic                 rx_ptp_ts_step_out,
    output wire logic                 rx_ptp_locked,

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    input  wire logic                 tx_lfc_req = 1'b0,
    input  wire logic                 tx_lfc_resend = 1'b0,
    input  wire logic                 rx_lfc_en = 1'b0,
    output wire logic                 rx_lfc_req,
    input  wire logic                 rx_lfc_ack = 1'b0,

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    input  wire logic [7:0]           tx_pfc_req = '0,
    input  wire logic                 tx_pfc_resend = 1'b0,
    input  wire logic [7:0]           rx_pfc_en = '0,
    output wire logic [7:0]           rx_pfc_req,
    input  wire logic [7:0]           rx_pfc_ack = '0,

    /*
     * Pause interface
     */
    input  wire logic                 tx_lfc_pause_en = 1'b0,
    input  wire logic                 tx_pause_req = 1'b0,
    output wire logic                 tx_pause_ack,

    /*
     * Statistics
     */
    input  wire logic                 stat_clk,
    input  wire logic                 stat_rst,
    taxi_axis_if.src                  m_axis_stat,

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
    input  wire logic                 stat_rx_fifo_drop = 1'b0,
    output wire logic                 stat_tx_mcf,
    output wire logic                 stat_rx_mcf,
    output wire logic                 stat_tx_lfc_pkt,
    output wire logic                 stat_tx_lfc_xon,
    output wire logic                 stat_tx_lfc_xoff,
    output wire logic                 stat_tx_lfc_paused,
    output wire logic                 stat_tx_pfc_pkt,
    output wire logic [7:0]           stat_tx_pfc_xon,
    output wire logic [7:0]           stat_tx_pfc_xoff,
    output wire logic [7:0]           stat_tx_pfc_paused,
    output wire logic                 stat_rx_lfc_pkt,
    output wire logic                 stat_rx_lfc_xon,
    output wire logic                 stat_rx_lfc_xoff,
    output wire logic                 stat_rx_lfc_paused,
    output wire logic                 stat_rx_pfc_pkt,
    output wire logic [7:0]           stat_rx_pfc_xon,
    output wire logic [7:0]           stat_rx_pfc_xoff,
    output wire logic [7:0]           stat_rx_pfc_paused,

    /*
     * Configuration
     */
    input  wire logic                 cfg_tx_pad_en = 1'b1,
    input  wire logic [7:0]           cfg_tx_min_pkt_len = 8'd60-1,
    input  wire logic [15:0]          cfg_tx_max_pkt_len = 16'd1518-1,
    input  wire logic [7:0]           cfg_tx_ifg = 8'd12,
    input  wire logic                 cfg_tx_enable = 1'b1,
    input  wire logic [15:0]          cfg_rx_max_pkt_len = 16'd1518-1,
    input  wire logic                 cfg_rx_enable = 1'b1,
    input  wire logic                 cfg_tx_prbs31_enable = 1'b0,
    input  wire logic                 cfg_rx_prbs31_enable = 1'b0,
    input  wire logic [47:0]          cfg_mcf_rx_eth_dst_mcast = 48'h01_80_C2_00_00_01,
    input  wire logic                 cfg_mcf_rx_check_eth_dst_mcast = 1'b1,
    input  wire logic [47:0]          cfg_mcf_rx_eth_dst_ucast = 48'd0,
    input  wire logic                 cfg_mcf_rx_check_eth_dst_ucast = 1'b0,
    input  wire logic [47:0]          cfg_mcf_rx_eth_src = 48'd0,
    input  wire logic                 cfg_mcf_rx_check_eth_src = 1'b0,
    input  wire logic [15:0]          cfg_mcf_rx_eth_type = 16'h8808,
    input  wire logic [15:0]          cfg_mcf_rx_opcode_lfc = 16'h0001,
    input  wire logic                 cfg_mcf_rx_check_opcode_lfc = 1'b1,
    input  wire logic [15:0]          cfg_mcf_rx_opcode_pfc = 16'h0101,
    input  wire logic                 cfg_mcf_rx_check_opcode_pfc = 1'b1,
    input  wire logic                 cfg_mcf_rx_forward = 1'b0,
    input  wire logic                 cfg_mcf_rx_enable = 1'b0,
    input  wire logic [47:0]          cfg_tx_lfc_eth_dst = 48'h01_80_C2_00_00_01,
    input  wire logic [47:0]          cfg_tx_lfc_eth_src = 48'h80_23_31_43_54_4C,
    input  wire logic [15:0]          cfg_tx_lfc_eth_type = 16'h8808,
    input  wire logic [15:0]          cfg_tx_lfc_opcode = 16'h0001,
    input  wire logic                 cfg_tx_lfc_en = 1'b0,
    input  wire logic [15:0]          cfg_tx_lfc_quanta = 16'hffff,
    input  wire logic [15:0]          cfg_tx_lfc_refresh = 16'h7fff,
    input  wire logic [47:0]          cfg_tx_pfc_eth_dst = 48'h01_80_C2_00_00_01,
    input  wire logic [47:0]          cfg_tx_pfc_eth_src = 48'h80_23_31_43_54_4C,
    input  wire logic [15:0]          cfg_tx_pfc_eth_type = 16'h8808,
    input  wire logic [15:0]          cfg_tx_pfc_opcode = 16'h0101,
    input  wire logic                 cfg_tx_pfc_en = 1'b0,
    input  wire logic [15:0]          cfg_tx_pfc_quanta[8] = '{8{16'hffff}},
    input  wire logic [15:0]          cfg_tx_pfc_refresh[8] = '{8{16'h7fff}},
    input  wire logic [15:0]          cfg_rx_lfc_opcode = 16'h0001,
    input  wire logic                 cfg_rx_lfc_en = 1'b0,
    input  wire logic [15:0]          cfg_rx_pfc_opcode = 16'h0101,
    input  wire logic                 cfg_rx_pfc_en = 1'b0
);

localparam KEEP_W = s_axis_tx.KEEP_W;
localparam TX_USER_W = 1;
localparam RX_USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;
localparam TX_TAG_W = s_axis_tx.ID_W;

localparam MAC_CTRL_EN = PAUSE_EN || PFC_EN;
localparam TX_USER_W_INT = (MAC_CTRL_EN ? 1 : 0) + TX_USER_W;

taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(TX_USER_W_INT), .ID_EN(1), .ID_W(TX_TAG_W)) axis_tx_int();
taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(RX_USER_W)) axis_rx_int();

// PTP timestamping
if (PTP_TS_EN && PTP_TD_EN) begin : ptp

    // TX
    wire [PTP_TS_W-1:0] tx_ptp_ts_rel;
    wire tx_ptp_ts_rel_step;
    wire [PTP_TS_W-1:0] tx_ptp_ts_tod;
    wire tx_ptp_ts_tod_step;

    taxi_ptp_td_leaf #(
        .TS_REL_EN(!PTP_TS_FMT_TOD),
        .TS_TOD_EN(PTP_TS_FMT_TOD),
        .TS_FNS_W(16),
        .TS_REL_NS_W(PTP_TS_FMT_TOD ? 48 : PTP_TS_W-16),
        .TS_TOD_S_W(PTP_TS_FMT_TOD ? PTP_TS_W-32-16 : 48),
        .TS_REL_W(PTP_TS_W),
        .TS_TOD_W(PTP_TS_W),
        .TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE)
    )
    tx_leaf_inst (
        .clk(tx_clk),
        .rst(tx_rst),
        .sample_clk(ptp_sample_clk),

        /*
         * PTP clock interface
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_td_sdi(ptp_td_sdi),

        /*
         * Timestamp output
         */
        .output_ts_rel(tx_ptp_ts_rel),
        .output_ts_rel_step(tx_ptp_ts_rel_step),
        .output_ts_tod(tx_ptp_ts_tod),
        .output_ts_tod_step(tx_ptp_ts_tod_step),

        /*
         * PPS output (ToD format only)
         */
        .output_pps(),
        .output_pps_str(),

        /*
         * Status
         */
        .locked(tx_ptp_locked)
    );

    assign tx_ptp_ts_out = PTP_TS_FMT_TOD ? tx_ptp_ts_tod : tx_ptp_ts_rel;
    assign tx_ptp_ts_step_out = PTP_TS_FMT_TOD ? tx_ptp_ts_tod_step : tx_ptp_ts_rel_step;

    // RX
    wire [PTP_TS_W-1:0] rx_ptp_ts_rel;
    wire rx_ptp_ts_rel_step;
    wire [PTP_TS_W-1:0] rx_ptp_ts_tod;
    wire rx_ptp_ts_tod_step;

    taxi_ptp_td_leaf #(
        .TS_REL_EN(!PTP_TS_FMT_TOD),
        .TS_TOD_EN(PTP_TS_FMT_TOD),
        .TS_FNS_W(16),
        .TS_REL_NS_W(PTP_TS_FMT_TOD ? 48 : PTP_TS_W-16),
        .TS_TOD_S_W(PTP_TS_FMT_TOD ? PTP_TS_W-32-16 : 48),
        .TS_REL_W(PTP_TS_W),
        .TS_TOD_W(PTP_TS_W),
        .TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE)
    )
    rx_leaf_inst (
        .clk(rx_clk),
        .rst(rx_rst),
        .sample_clk(ptp_sample_clk),

        /*
         * PTP clock interface
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_td_sdi(ptp_td_sdi),

        /*
         * Timestamp output
         */
        .output_ts_rel(rx_ptp_ts_rel),
        .output_ts_rel_step(rx_ptp_ts_rel_step),
        .output_ts_tod(rx_ptp_ts_tod),
        .output_ts_tod_step(rx_ptp_ts_tod_step),

        /*
         * PPS output (ToD format only)
         */
        .output_pps(),
        .output_pps_str(),

        /*
         * Status
         */
        .locked(rx_ptp_locked)
    );

    assign rx_ptp_ts_out = PTP_TS_FMT_TOD ? rx_ptp_ts_tod : rx_ptp_ts_rel;
    assign rx_ptp_ts_step_out = PTP_TS_FMT_TOD ? rx_ptp_ts_tod_step : rx_ptp_ts_rel_step;

end else begin

    assign tx_ptp_ts_out = tx_ptp_ts_in;
    assign tx_ptp_ts_step_out = 1'b0;
    assign rx_ptp_ts_out = rx_ptp_ts_in;
    assign rx_ptp_ts_step_out = 1'b0;

    assign tx_ptp_locked = 1'b0;
    assign rx_ptp_locked = 1'b0;

end

// USXGMII autonegotiation
wire [23:0] rx_os;
wire        rx_os_sig;
wire        rx_os_valid;
wire        rx_os_match;
wire        rx_idle_match;

wire [23:0] tx_os;
wire        tx_os_sig;
wire        tx_os_valid;
wire        tx_os_ready;

wire        cfg_rx_usxgmii_en;
wire        cfg_rx_usxgmii_5g;
wire [2:0]  cfg_rx_usxgmii_speed;

wire        cfg_tx_usxgmii_en;
wire        cfg_tx_usxgmii_5g;
wire [2:0]  cfg_tx_usxgmii_speed;

if (USXGMII_EN) begin : an

    // synchronize RX signals to TX
    wire [23:0]  sync_rx_os;
    wire         sync_rx_os_sig;
    wire         sync_rx_os_valid;
    wire         sync_rx_os_match;
    wire         sync_rx_idle_match;
    wire         sync_rx_block_lock;

    taxi_sync_signal #(
        .WIDTH(24+5),
        .N(2)
    )
    rx_sync_inst (
        .clk(tx_clk),

        .in({
            rx_os,
            rx_os_sig,
            rx_os_valid,
            rx_os_match,
            rx_idle_match,
            rx_block_lock
        }),
        .out({
            sync_rx_os,
            sync_rx_os_sig,
            sync_rx_os_valid,
            sync_rx_os_match,
            sync_rx_idle_match,
            sync_rx_block_lock
        })
    );

    taxi_sync_signal #(
        .WIDTH(1+1+3),
        .N(2)
    )
    rx_sync_ctrl_inst (
        .clk(rx_clk),

        .in({
            cfg_tx_usxgmii_en,
            cfg_tx_usxgmii_5g,
            cfg_tx_usxgmii_speed
        }),
        .out({
            cfg_rx_usxgmii_en,
            cfg_rx_usxgmii_5g,
            cfg_rx_usxgmii_speed
        })
    );

    taxi_eth_phy_10g_usxgmii_an #(
        .DATA_W(DATA_W)
    )
    an_inst (
        .clk(tx_clk),
        .rst(tx_rst),

        /*
         * Ordered sets
         */
        .rx_os(sync_rx_os),
        .rx_os_sig(sync_rx_os_sig),
        .rx_os_valid(sync_rx_os_valid),
        .rx_os_match(sync_rx_os_match),
        .rx_idle_match(sync_rx_idle_match),
        .rx_block_lock(sync_rx_block_lock),

        .tx_os(tx_os),
        .tx_os_sig(tx_os_sig),
        .tx_os_valid(tx_os_valid),
        .tx_os_ready(tx_os_ready),

        /*
         * USXGMII Autonegotiation
         */
        .an_en(an_en),
        .an_restart(an_restart),
        .an_speedup(an_speedup),
        .an_timeout_en(an_timeout_en),
        .an_usxgmii_en(an_usxgmii_en),
        .an_usxgmii_auto(an_usxgmii_auto),
        .an_usxgmii_5g(an_usxgmii_5g),
        .an_intr(an_intr),
        .an_running(an_running),
        .an_complete(an_complete),
        .an_timeout(an_timeout),
        .an_usxgmii_mode(an_usxgmii_mode),
        .an_adv_ability_usxgmii(an_adv_ability_usxgmii),
        .an_lp_adv_ability(an_lp_adv_ability),
        .an_lp_usxgmii_link(an_lp_usxgmii_link),
        .an_lp_usxgmii_speed(an_lp_usxgmii_speed),
        .an_res_full_duplex(an_res_full_duplex)
    );

    assign cfg_tx_usxgmii_en = an_usxgmii_mode;
    assign cfg_tx_usxgmii_5g = an_usxgmii_5g;
    assign cfg_tx_usxgmii_speed = an_lp_usxgmii_speed;

end else begin : an

    wire [23:0] tx_os = '0;
    wire        tx_os_sig = 1'b0;
    wire        tx_os_valid = 1'b0;

    wire        cfg_rx_usxgmii_en = 1'b0;
    wire        cfg_rx_usxgmii_5g = 1'b0;
    wire [2:0]  cfg_rx_usxgmii_speed = 3'b011;

    wire        cfg_tx_usxgmii_en = 1'b0;
    wire        cfg_tx_usxgmii_5g = 1'b0;
    wire [2:0]  cfg_tx_usxgmii_speed = 3'b011;

end

taxi_eth_mac_phy_10g_rx #(
    .DATA_W(DATA_W),
    .HDR_W(HDR_W),
    .GBX_IF_EN(RX_GBX_IF_EN),
    .USXGMII_EN(USXGMII_EN),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
    .PTP_TS_W(PTP_TS_W),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US)
)
eth_mac_phy_10g_rx_inst (
    .clk(rx_clk),
    .rst(rx_rst),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_rx_int),

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
     * Ordered sets
     */
    .rx_os(rx_os),
    .rx_os_sig(rx_os_sig),
    .rx_os_valid(rx_os_valid),
    .rx_os_match(rx_os_match),
    .rx_idle_match(rx_idle_match),

    /*
     * PTP
     */
    .ptp_ts(rx_ptp_ts_out),

    /*
     * Status
     */
    .rx_start_packet(rx_start_packet),
    .rx_error_count(rx_error_count),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),
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
    .stat_rx_err_preamble(stat_rx_err_preamble),

    /*
     * Configuration
     */
    .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
    .cfg_rx_enable(cfg_rx_enable),
    .cfg_rx_usxgmii_en(cfg_rx_usxgmii_en),
    .cfg_rx_usxgmii_5g(cfg_rx_usxgmii_5g),
    .cfg_rx_usxgmii_speed(cfg_rx_usxgmii_speed),
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

taxi_eth_mac_phy_10g_tx #(
    .DATA_W(DATA_W),
    .HDR_W(HDR_W),
    .GBX_IF_EN(TX_GBX_IF_EN),
    .USXGMII_EN(USXGMII_EN),
    .DIC_EN(DIC_EN),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
    .PTP_TS_W(PTP_TS_W),
    .TX_CPL_CTRL_IN_TUSER(MAC_CTRL_EN),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_EN(PRBS31_EN),
    .SERDES_PIPELINE(TX_SERDES_PIPELINE)
)
eth_mac_phy_10g_tx_inst (
    .clk(tx_clk),
    .rst(tx_rst),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_tx_int),
    .m_axis_tx_cpl(m_axis_tx_cpl),

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
     * Ordered sets
     */
    .tx_os(tx_os),
    .tx_os_sig(tx_os_sig),
    .tx_os_valid(tx_os_valid),
    .tx_os_ready(tx_os_ready),

    /*
     * PTP
     */
    .ptp_ts(tx_ptp_ts_out),

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
    .stat_tx_pad_frame(stat_tx_pad_frame),
    .stat_tx_err_oversize(stat_tx_err_oversize),
    .stat_tx_err_user(stat_tx_err_user),
    .stat_tx_err_underflow(stat_tx_err_underflow),

    /*
     * Configuration
     */
    .cfg_tx_pad_en(cfg_tx_pad_en),
    .cfg_tx_min_pkt_len(cfg_tx_min_pkt_len),
    .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
    .cfg_tx_ifg(cfg_tx_ifg),
    .cfg_tx_enable(cfg_tx_enable),
    .cfg_tx_usxgmii_en(cfg_tx_usxgmii_en),
    .cfg_tx_usxgmii_5g(cfg_tx_usxgmii_5g),
    .cfg_tx_usxgmii_speed(cfg_tx_usxgmii_speed),
    .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable)
);

if (STAT_EN) begin : stats

    taxi_eth_mac_stats #(
        .STAT_TX_LEVEL(STAT_TX_LEVEL),
        .STAT_RX_LEVEL(STAT_RX_LEVEL),
        .STAT_ID_BASE(STAT_ID_BASE),
        .STAT_UPDATE_PERIOD(STAT_UPDATE_PERIOD),
        .STAT_STR_EN(STAT_STR_EN),
        .STAT_PREFIX_STR(STAT_PREFIX_STR),
        .INC_W(4)
    )
    mac_stats_inst (
        .rx_clk(rx_clk),
        .rx_rst(rx_rst),
        .tx_clk(tx_clk),
        .tx_rst(tx_rst),

        /*
         * Statistics
         */
        .stat_clk(stat_clk),
        .stat_rst(stat_rst),
        .m_axis_stat(m_axis_stat),

        /*
         * Status
         */
        .tx_start_packet(|tx_start_packet),
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
        .stat_tx_err_underflow(stat_tx_err_underflow),
        .rx_start_packet(|rx_start_packet),
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
        .stat_rx_err_preamble(stat_rx_err_preamble),
        .stat_rx_fifo_drop(stat_rx_fifo_drop),
        .stat_tx_mcf(stat_tx_mcf),
        .stat_rx_mcf(stat_rx_mcf),
        .stat_tx_lfc_pkt(stat_tx_lfc_pkt),
        .stat_tx_lfc_xon(stat_tx_lfc_xon),
        .stat_tx_lfc_xoff(stat_tx_lfc_xoff),
        .stat_tx_lfc_paused(stat_tx_lfc_paused),
        .stat_tx_pfc_pkt(stat_tx_pfc_pkt),
        .stat_tx_pfc_xon(stat_tx_pfc_xon),
        .stat_tx_pfc_xoff(stat_tx_pfc_xoff),
        .stat_tx_pfc_paused(stat_tx_pfc_paused),
        .stat_rx_lfc_pkt(stat_rx_lfc_pkt),
        .stat_rx_lfc_xon(stat_rx_lfc_xon),
        .stat_rx_lfc_xoff(stat_rx_lfc_xoff),
        .stat_rx_lfc_paused(stat_rx_lfc_paused),
        .stat_rx_pfc_pkt(stat_rx_pfc_pkt),
        .stat_rx_pfc_xon(stat_rx_pfc_xon),
        .stat_rx_pfc_xoff(stat_rx_pfc_xoff),
        .stat_rx_pfc_paused(stat_rx_pfc_paused)
    );

end else begin

    taxi_axis_null_src
    null_src_inst (
        .m_axis(m_axis_stat)
    );

end

if (MAC_CTRL_EN) begin : mac_ctrl

    localparam MCF_PARAMS_SIZE = PFC_EN ? 18 : 2;

    wire                          tx_mcf_valid;
    wire                          tx_mcf_ready;
    wire [47:0]                   tx_mcf_eth_dst;
    wire [47:0]                   tx_mcf_eth_src;
    wire [15:0]                   tx_mcf_eth_type;
    wire [15:0]                   tx_mcf_opcode;
    wire [MCF_PARAMS_SIZE*8-1:0]  tx_mcf_params;

    wire                          rx_mcf_valid;
    wire [47:0]                   rx_mcf_eth_dst;
    wire [47:0]                   rx_mcf_eth_src;
    wire [15:0]                   rx_mcf_eth_type;
    wire [15:0]                   rx_mcf_opcode;
    wire [MCF_PARAMS_SIZE*8-1:0]  rx_mcf_params;

    // terminate LFC pause requests from RX internally on TX side
    wire tx_pause_req_int;
    wire rx_lfc_ack_int;

    wire rx_lfc_req_sync;

    taxi_sync_signal #(
        .WIDTH(1),
        .N(2)
    )
    rx_lfc_req_sync_inst (
        .clk(tx_clk),
        .in(rx_lfc_req),
        .out(rx_lfc_req_sync)
    );

    wire tx_pause_ack_sync;

    taxi_sync_signal #(
        .WIDTH(1),
        .N(2)
    )
    tx_pause_ack_sync_inst (
        .clk(rx_clk),
        .in(tx_lfc_pause_en && tx_pause_ack),
        .out(tx_pause_ack_sync)
    );

    assign tx_pause_req_int = tx_pause_req || (tx_lfc_pause_en && rx_lfc_req_sync);

    assign rx_lfc_ack_int = rx_lfc_ack || tx_pause_ack_sync;

    taxi_mac_ctrl_tx #(
        .ID_W(s_axis_tx.ID_W),
        .DEST_W(s_axis_tx.DEST_W),
        .USER_W(TX_USER_W_INT),
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
    )
    mac_ctrl_tx_inst (
        .clk(tx_clk),
        .rst(tx_rst),

        /*
         * AXI stream input
         */
        .s_axis(s_axis_tx),

        /*
         * AXI stream output
         */
        .m_axis(axis_tx_int),

        /*
         * MAC control frame interface
         */
        .mcf_valid(tx_mcf_valid),
        .mcf_ready(tx_mcf_ready),
        .mcf_eth_dst(tx_mcf_eth_dst),
        .mcf_eth_src(tx_mcf_eth_src),
        .mcf_eth_type(tx_mcf_eth_type),
        .mcf_opcode(tx_mcf_opcode),
        .mcf_params(tx_mcf_params),
        .mcf_id('0),
        .mcf_dest('0),
        .mcf_user(2'b10),

        /*
         * Pause interface
         */
        .tx_pause_req(tx_pause_req_int),
        .tx_pause_ack(tx_pause_ack),

        /*
         * Status
         */
        .stat_tx_mcf(stat_tx_mcf)
    );

    taxi_mac_ctrl_rx #(
        .USER_W(RX_USER_W),
        .USE_READY(0),
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE)
    )
    mac_ctrl_rx_inst (
        .clk(rx_clk),
        .rst(rx_rst),

        /*
         * AXI stream input
         */
        .s_axis(axis_rx_int),

        /*
         * AXI stream output
         */
        .m_axis(m_axis_rx),

        /*
         * MAC control frame interface
         */
        .mcf_valid(rx_mcf_valid),
        .mcf_eth_dst(rx_mcf_eth_dst),
        .mcf_eth_src(rx_mcf_eth_src),
        .mcf_eth_type(rx_mcf_eth_type),
        .mcf_opcode(rx_mcf_opcode),
        .mcf_params(rx_mcf_params),
        .mcf_id(),
        .mcf_dest(),
        .mcf_user(),

        /*
         * Configuration
         */
        .cfg_mcf_rx_eth_dst_mcast(cfg_mcf_rx_eth_dst_mcast),
        .cfg_mcf_rx_check_eth_dst_mcast(cfg_mcf_rx_check_eth_dst_mcast),
        .cfg_mcf_rx_eth_dst_ucast(cfg_mcf_rx_eth_dst_ucast),
        .cfg_mcf_rx_check_eth_dst_ucast(cfg_mcf_rx_check_eth_dst_ucast),
        .cfg_mcf_rx_eth_src(cfg_mcf_rx_eth_src),
        .cfg_mcf_rx_check_eth_src(cfg_mcf_rx_check_eth_src),
        .cfg_mcf_rx_eth_type(cfg_mcf_rx_eth_type),
        .cfg_mcf_rx_opcode_lfc(cfg_mcf_rx_opcode_lfc),
        .cfg_mcf_rx_check_opcode_lfc(cfg_mcf_rx_check_opcode_lfc),
        .cfg_mcf_rx_opcode_pfc(cfg_mcf_rx_opcode_pfc),
        .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc && PFC_EN),
        .cfg_mcf_rx_forward(cfg_mcf_rx_forward),
        .cfg_mcf_rx_enable(cfg_mcf_rx_enable),

        /*
         * Status
         */
        .stat_rx_mcf(stat_rx_mcf)
    );

    taxi_mac_pause_ctrl_tx #(
        .MCF_PARAMS_SIZE(MCF_PARAMS_SIZE),
        .PFC_EN(PFC_EN)
    )
    mac_pause_ctrl_tx_inst (
        .clk(tx_clk),
        .rst(tx_rst),

        /*
         * MAC control frame interface
         */
        .mcf_valid(tx_mcf_valid),
        .mcf_ready(tx_mcf_ready),
        .mcf_eth_dst(tx_mcf_eth_dst),
        .mcf_eth_src(tx_mcf_eth_src),
        .mcf_eth_type(tx_mcf_eth_type),
        .mcf_opcode(tx_mcf_opcode),
        .mcf_params(tx_mcf_params),

        /*
         * Pause (IEEE 802.3 annex 31B)
         */
        .tx_lfc_req(tx_lfc_req),
        .tx_lfc_resend(tx_lfc_resend),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
         */
        .tx_pfc_req(tx_pfc_req),
        .tx_pfc_resend(tx_pfc_resend),

        /*
         * Configuration
         */
        .cfg_tx_lfc_eth_dst(cfg_tx_lfc_eth_dst),
        .cfg_tx_lfc_eth_src(cfg_tx_lfc_eth_src),
        .cfg_tx_lfc_eth_type(cfg_tx_lfc_eth_type),
        .cfg_tx_lfc_opcode(cfg_tx_lfc_opcode),
        .cfg_tx_lfc_en(cfg_tx_lfc_en),
        .cfg_tx_lfc_quanta(cfg_tx_lfc_quanta),
        .cfg_tx_lfc_refresh(cfg_tx_lfc_refresh),
        .cfg_tx_pfc_eth_dst(cfg_tx_pfc_eth_dst),
        .cfg_tx_pfc_eth_src(cfg_tx_pfc_eth_src),
        .cfg_tx_pfc_eth_type(cfg_tx_pfc_eth_type),
        .cfg_tx_pfc_opcode(cfg_tx_pfc_opcode),
        .cfg_tx_pfc_en(cfg_tx_pfc_en),
        .cfg_tx_pfc_quanta(cfg_tx_pfc_quanta),
        .cfg_tx_pfc_refresh(cfg_tx_pfc_refresh),
        .cfg_quanta_step(10'((DATA_W*256)/512)),
        .cfg_quanta_clk_en(!TX_GBX_IF_EN || serdes_tx_data_valid),

        /*
         * Status
         */
        .stat_tx_lfc_pkt(stat_tx_lfc_pkt),
        .stat_tx_lfc_xon(stat_tx_lfc_xon),
        .stat_tx_lfc_xoff(stat_tx_lfc_xoff),
        .stat_tx_lfc_paused(stat_tx_lfc_paused),
        .stat_tx_pfc_pkt(stat_tx_pfc_pkt),
        .stat_tx_pfc_xon(stat_tx_pfc_xon),
        .stat_tx_pfc_xoff(stat_tx_pfc_xoff),
        .stat_tx_pfc_paused(stat_tx_pfc_paused)
    );

    taxi_mac_pause_ctrl_rx #(
        .MCF_PARAMS_SIZE(18),
        .PFC_EN(PFC_EN)
    )
    mac_pause_ctrl_rx_inst (
        .clk(rx_clk),
        .rst(rx_rst),

        /*
         * MAC control frame interface
         */
        .mcf_valid(rx_mcf_valid),
        .mcf_eth_dst(rx_mcf_eth_dst),
        .mcf_eth_src(rx_mcf_eth_src),
        .mcf_eth_type(rx_mcf_eth_type),
        .mcf_opcode(rx_mcf_opcode),
        .mcf_params(rx_mcf_params),

        /*
         * Pause (IEEE 802.3 annex 31B)
         */
        .rx_lfc_en(rx_lfc_en),
        .rx_lfc_req(rx_lfc_req),
        .rx_lfc_ack(rx_lfc_ack_int),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
         */
        .rx_pfc_en(rx_pfc_en),
        .rx_pfc_req(rx_pfc_req),
        .rx_pfc_ack(rx_pfc_ack),

        /*
         * Configuration
         */
        .cfg_rx_lfc_opcode(cfg_rx_lfc_opcode),
        .cfg_rx_lfc_en(cfg_rx_lfc_en),
        .cfg_rx_pfc_opcode(cfg_rx_pfc_opcode),
        .cfg_rx_pfc_en(cfg_rx_pfc_en),
        .cfg_quanta_step(10'((DATA_W*256)/512)),
        .cfg_quanta_clk_en(!RX_GBX_IF_EN || serdes_rx_data_valid),

        /*
         * Status
         */
        .stat_rx_lfc_pkt(stat_rx_lfc_pkt),
        .stat_rx_lfc_xon(stat_rx_lfc_xon),
        .stat_rx_lfc_xoff(stat_rx_lfc_xoff),
        .stat_rx_lfc_paused(stat_rx_lfc_paused),
        .stat_rx_pfc_pkt(stat_rx_pfc_pkt),
        .stat_rx_pfc_xon(stat_rx_pfc_xon),
        .stat_rx_pfc_xoff(stat_rx_pfc_xoff),
        .stat_rx_pfc_paused(stat_rx_pfc_paused)
    );

end else begin

    taxi_axis_tie
    tx_tie_inst (
        .s_axis(s_axis_tx),
        .m_axis(axis_tx_int)
    );

    taxi_axis_tie
    rx_tie_inst (
        .s_axis(axis_rx_int),
        .m_axis(m_axis_rx)
    );

    assign rx_lfc_req = '0;
    assign rx_pfc_req = '0;
    assign tx_pause_ack = '0;

    assign stat_tx_mcf = '0;
    assign stat_rx_mcf = '0;
    assign stat_tx_lfc_pkt = '0;
    assign stat_tx_lfc_xon = '0;
    assign stat_tx_lfc_xoff = '0;
    assign stat_tx_lfc_paused = '0;
    assign stat_tx_pfc_pkt = '0;
    assign stat_tx_pfc_xon = '0;
    assign stat_tx_pfc_xoff = '0;
    assign stat_tx_pfc_paused = '0;
    assign stat_rx_lfc_pkt = '0;
    assign stat_rx_lfc_xon = '0;
    assign stat_rx_lfc_xoff = '0;
    assign stat_rx_lfc_paused = '0;
    assign stat_rx_pfc_pkt = '0;
    assign stat_rx_pfc_xon = '0;
    assign stat_rx_pfc_xoff = '0;
    assign stat_rx_pfc_paused = '0;

end

endmodule

`resetall
