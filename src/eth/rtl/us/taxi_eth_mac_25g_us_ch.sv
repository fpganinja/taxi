// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Transceiver and MAC/PHY wrapper for UltraScale/UltraScale+
 */
module taxi_eth_mac_25g_us_ch #
(
    parameter logic SIM = 1'b0,
    parameter string VENDOR = "XILINX",
    parameter string FAMILY = "virtexuplus",

    parameter logic HAS_COMMON = 1'b1,

    // GT config
    parameter logic CFG_LOW_LATENCY = 0,

    // GT type
    parameter string GT_TYPE = "GTY",

    // PLL parameters
    parameter logic QPLL0_PD = 1'b0,
    parameter logic QPLL1_PD = 1'b1,
    parameter logic QPLL0_EXT_CTRL = 1'b0,
    parameter logic QPLL1_EXT_CTRL = 1'b0,

    // GT parameters
    parameter logic GT_TX_PD = 1'b0,
    parameter logic GT_TX_QPLL_SEL = 1'b0,
    parameter logic GT_TX_POLARITY = 1'b0,
    parameter logic GT_TX_ELECIDLE = 1'b0,
    parameter logic GT_TX_INHIBIT = 1'b0,
    parameter logic [4:0] GT_TX_DIFFCTRL = 5'd16,
    parameter logic [6:0] GT_TX_MAINCURSOR = 7'd64,
    parameter logic [4:0] GT_TX_POSTCURSOR = 5'd0,
    parameter logic [4:0] GT_TX_PRECURSOR = 5'd0,
    parameter logic GT_RX_PD = 1'b0,
    parameter logic GT_RX_QPLL_SEL = 1'b0,
    parameter logic GT_RX_LPM_EN = 1'b0,
    parameter logic GT_RX_POLARITY = 1'b0,

    // MAC/PHY parameters
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter DATA_W = 64,
    parameter logic USXGMII_EN = 1'b0,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TD_EN = PTP_TS_EN,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter PTP_TD_SDI_PIPELINE = 2,
    parameter logic PRBS31_EN = 1'b0,
    parameter TX_SERDES_PIPELINE = 1,
    parameter RX_SERDES_PIPELINE = 1,
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
    input  wire logic                 xcvr_ctrl_clk,
    input  wire logic                 xcvr_ctrl_rst,

    /*
     * Transceiver control
     */
    taxi_apb_if.slv                   s_apb_ctrl,

    /*
     * Common
     */
    output wire logic                 xcvr_gtpowergood_out,

    /*
     * PLL out
     */
    input  wire logic                 xcvr_gtrefclk00_in = 1'b0,
    input  wire logic                 xcvr_qpll0pd_in = 1'b0,
    input  wire logic                 xcvr_qpll0reset_in = 1'b0,
    input  wire logic [2:0]           xcvr_qpll0pcierate_in = 3'd0,
    output wire logic                 xcvr_qpll0lock_out,
    output wire logic                 xcvr_qpll0clk_out,
    output wire logic                 xcvr_qpll0refclk_out,
    input  wire logic                 xcvr_gtrefclk01_in = 1'b0,
    input  wire logic                 xcvr_qpll1pd_in = 1'b0,
    input  wire logic                 xcvr_qpll1reset_in = 1'b0,
    input  wire logic [2:0]           xcvr_qpll1pcierate_in = 3'd0,
    output wire logic                 xcvr_qpll1lock_out,
    output wire logic                 xcvr_qpll1clk_out,
    output wire logic                 xcvr_qpll1refclk_out,

    /*
     * PLL in
     */
    input  wire logic                 xcvr_qpll0lock_in = 1'b0,
    input  wire logic                 xcvr_qpll0clk_in = 1'b0,
    input  wire logic                 xcvr_qpll0refclk_in = 1'b0,
    input  wire logic                 xcvr_qpll1lock_in = 1'b0,
    input  wire logic                 xcvr_qpll1clk_in = 1'b0,
    input  wire logic                 xcvr_qpll1refclk_in = 1'b0,

    /*
     * Serial data
     */
    output wire logic                 xcvr_txp,
    output wire logic                 xcvr_txn,
    input  wire logic                 xcvr_rxp,
    input  wire logic                 xcvr_rxn,

    /*
     * MAC clocks
     */
    output wire logic                 rx_clk,
    input  wire logic                 rx_rst_in = 1'b0,
    output wire logic                 rx_rst_out,
    output wire logic                 tx_clk,
    input  wire logic                 tx_rst_in = 1'b0,
    output wire logic                 tx_rst_out,

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
     * USXGMII autonegotiation
     */
    input  wire logic                 an_en = 1'b1,
    input  wire logic                 an_restart = 1'b0,
    input  wire logic                 an_speedup = 1'b0,
    input  wire logic                 an_timeout_en = 1'b1,
    input  wire logic                 an_usxgmii_en = 1'b0,
    input  wire logic                 an_usxgmii_auto = 1'b1,
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
     * PTP clock
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

localparam GT_7 = FAMILY == "virtex7" || FAMILY == "kintex7";
localparam GBX_EN = CFG_LOW_LATENCY || GT_7;

localparam HDR_W = 2;

wire rx_reset_req;

wire [DATA_W-1:0]  serdes_tx_data;
wire               serdes_tx_data_valid;
wire [HDR_W-1:0]   serdes_tx_hdr;
wire               serdes_tx_hdr_valid;
wire               serdes_tx_gbx_req_sync;
wire               serdes_tx_gbx_req_stall;
wire               serdes_tx_gbx_sync;
wire [DATA_W-1:0]  serdes_rx_data;
wire               serdes_rx_data_valid;
wire [HDR_W-1:0]   serdes_rx_hdr;
wire               serdes_rx_hdr_valid;
wire               serdes_rx_bitslip;

if (GT_7) begin : gt

    taxi_eth_phy_10g_7_gt #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .HAS_COMMON(HAS_COMMON),

        // GT type
        .GT_TYPE(GT_TYPE),

        // PLL parameters
        .QPLL_PD(QPLL0_PD),
        .QPLL_EXT_CTRL(QPLL0_EXT_CTRL),

        // GT parameters
        .GT_TX_PD(GT_TX_PD),
        .GT_TX_POLARITY(GT_TX_POLARITY),
        .GT_TX_ELECIDLE(GT_TX_ELECIDLE),
        .GT_TX_INHIBIT(GT_TX_INHIBIT),
        .GT_TX_DIFFCTRL(4'(GT_TX_DIFFCTRL)),
        .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR),
        .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR),
        .GT_TX_PRECURSOR(GT_TX_PRECURSOR),
        .GT_RX_PD(GT_RX_PD),
        .GT_RX_LPM_EN(GT_RX_LPM_EN),
        .GT_RX_POLARITY(GT_RX_POLARITY),

        // MAC/PHY parameters
        .DATA_W(DATA_W),
        .HDR_W(HDR_W)
    )
    gt_inst (
        .xcvr_ctrl_clk(xcvr_ctrl_clk),
        .xcvr_ctrl_rst(xcvr_ctrl_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(s_apb_ctrl),

        /*
         * PLL out
         */
        .xcvr_gtrefclk0_in(xcvr_gtrefclk00_in),
        .xcvr_qpllpd_in(xcvr_qpll0pd_in),
        .xcvr_qpllreset_in(xcvr_qpll0reset_in),
        .xcvr_qpllpcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qplllock_out(xcvr_qpll0lock_out),
        .xcvr_qpllclk_out(xcvr_qpll0clk_out),
        .xcvr_qpllrefclk_out(xcvr_qpll0refclk_out),

        /*
         * PLL in
         */
        .xcvr_qplllock_in(xcvr_qpll0lock_in),
        .xcvr_qpllclk_in(xcvr_qpll0clk_in),
        .xcvr_qpllrefclk_in(xcvr_qpll0refclk_in),

        /*
         * Serial data
         */
        .xcvr_txp(xcvr_txp),
        .xcvr_txn(xcvr_txn),
        .xcvr_rxp(xcvr_rxp),
        .xcvr_rxn(xcvr_rxn),

        /*
         * GT user clocks
         */
        .rx_clk(rx_clk),
        .rx_rst_in(rx_rst_in || rx_reset_req),
        .rx_rst_out(rx_rst_out),
        .tx_clk(tx_clk),
        .tx_rst_in(tx_rst_in),
        .tx_rst_out(tx_rst_out),

        /*
         * Serdes interface
         */
        .serdes_tx_data(serdes_tx_data),
        .serdes_tx_data_valid(serdes_tx_data_valid),
        .serdes_tx_hdr(serdes_tx_hdr),
        .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
        .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
        .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
        .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip)
    );

    assign xcvr_gtpowergood_out = 1'b1;

    assign xcvr_qpll1lock_out = 1'b0;
    assign xcvr_qpll1clk_out = 1'b0;
    assign xcvr_qpll1refclk_out = 1'b0;

end else if (DATA_W == 64 && CFG_LOW_LATENCY) begin : gt

    taxi_eth_phy_25g_us_gt_ll #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .HAS_COMMON(HAS_COMMON),

        // GT type
        .GT_TYPE(GT_TYPE),

        // PLL parameters
        .QPLL0_PD(QPLL0_PD),
        .QPLL1_PD(QPLL1_PD),
        .QPLL0_EXT_CTRL(QPLL0_EXT_CTRL),
        .QPLL1_EXT_CTRL(QPLL1_EXT_CTRL),

        // GT parameters
        .GT_TX_PD(GT_TX_PD),
        .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL),
        .GT_TX_POLARITY(GT_TX_POLARITY),
        .GT_TX_ELECIDLE(GT_TX_ELECIDLE),
        .GT_TX_INHIBIT(GT_TX_INHIBIT),
        .GT_TX_DIFFCTRL(GT_TX_DIFFCTRL),
        .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR),
        .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR),
        .GT_TX_PRECURSOR(GT_TX_PRECURSOR),
        .GT_RX_PD(GT_RX_PD),
        .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL),
        .GT_RX_LPM_EN(GT_RX_LPM_EN),
        .GT_RX_POLARITY(GT_RX_POLARITY),

        // MAC/PHY parameters
        .DATA_W(DATA_W),
        .HDR_W(HDR_W)
    )
    gt_inst (
        .xcvr_ctrl_clk(xcvr_ctrl_clk),
        .xcvr_ctrl_rst(xcvr_ctrl_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(s_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(xcvr_gtpowergood_out),

        /*
         * PLL out
         */
        .xcvr_gtrefclk00_in(xcvr_gtrefclk00_in),
        .xcvr_qpll0pd_in(xcvr_qpll0pd_in),
        .xcvr_qpll0reset_in(xcvr_qpll0reset_in),
        .xcvr_qpll0pcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qpll0lock_out(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_out(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_out(xcvr_qpll0refclk_out),
        .xcvr_gtrefclk01_in(xcvr_gtrefclk01_in),
        .xcvr_qpll1pd_in(xcvr_qpll1pd_in),
        .xcvr_qpll1reset_in(xcvr_qpll1reset_in),
        .xcvr_qpll1pcierate_in(xcvr_qpll1pcierate_in),
        .xcvr_qpll1lock_out(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_out(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_out(xcvr_qpll1refclk_out),

        /*
         * PLL in
         */
        .xcvr_qpll0lock_in(xcvr_qpll0lock_in),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_in),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_in),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_in),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_in),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_in),

        /*
         * Serial data
         */
        .xcvr_txp(xcvr_txp),
        .xcvr_txn(xcvr_txn),
        .xcvr_rxp(xcvr_rxp),
        .xcvr_rxn(xcvr_rxn),

        /*
         * GT user clocks
         */
        .rx_clk(rx_clk),
        .rx_rst_in(rx_rst_in || rx_reset_req),
        .rx_rst_out(rx_rst_out),
        .tx_clk(tx_clk),
        .tx_rst_in(tx_rst_in),
        .tx_rst_out(tx_rst_out),

        /*
         * Serdes interface
         */
        .serdes_tx_data(serdes_tx_data),
        .serdes_tx_data_valid(serdes_tx_data_valid),
        .serdes_tx_hdr(serdes_tx_hdr),
        .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
        .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
        .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
        .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip)
    );

end else if (DATA_W == 64 && !CFG_LOW_LATENCY) begin : gt

    taxi_eth_phy_25g_us_gt #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .HAS_COMMON(HAS_COMMON),

        // GT type
        .GT_TYPE(GT_TYPE),

        // PLL parameters
        .QPLL0_PD(QPLL0_PD),
        .QPLL1_PD(QPLL1_PD),
        .QPLL0_EXT_CTRL(QPLL0_EXT_CTRL),
        .QPLL1_EXT_CTRL(QPLL1_EXT_CTRL),

        // GT parameters
        .GT_TX_PD(GT_TX_PD),
        .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL),
        .GT_TX_POLARITY(GT_TX_POLARITY),
        .GT_TX_ELECIDLE(GT_TX_ELECIDLE),
        .GT_TX_INHIBIT(GT_TX_INHIBIT),
        .GT_TX_DIFFCTRL(GT_TX_DIFFCTRL),
        .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR),
        .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR),
        .GT_TX_PRECURSOR(GT_TX_PRECURSOR),
        .GT_RX_PD(GT_RX_PD),
        .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL),
        .GT_RX_LPM_EN(GT_RX_LPM_EN),
        .GT_RX_POLARITY(GT_RX_POLARITY),

        // MAC/PHY parameters
        .DATA_W(DATA_W),
        .HDR_W(HDR_W)
    )
    gt_inst (
        .xcvr_ctrl_clk(xcvr_ctrl_clk),
        .xcvr_ctrl_rst(xcvr_ctrl_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(s_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(xcvr_gtpowergood_out),

        /*
         * PLL out
         */
        .xcvr_gtrefclk00_in(xcvr_gtrefclk00_in),
        .xcvr_qpll0pd_in(xcvr_qpll0pd_in),
        .xcvr_qpll0reset_in(xcvr_qpll0reset_in),
        .xcvr_qpll0pcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qpll0lock_out(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_out(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_out(xcvr_qpll0refclk_out),
        .xcvr_gtrefclk01_in(xcvr_gtrefclk01_in),
        .xcvr_qpll1pd_in(xcvr_qpll1pd_in),
        .xcvr_qpll1reset_in(xcvr_qpll1reset_in),
        .xcvr_qpll1pcierate_in(xcvr_qpll1pcierate_in),
        .xcvr_qpll1lock_out(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_out(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_out(xcvr_qpll1refclk_out),

        /*
         * PLL in
         */
        .xcvr_qpll0lock_in(xcvr_qpll0lock_in),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_in),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_in),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_in),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_in),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_in),

        /*
         * Serial data
         */
        .xcvr_txp(xcvr_txp),
        .xcvr_txn(xcvr_txn),
        .xcvr_rxp(xcvr_rxp),
        .xcvr_rxn(xcvr_rxn),

        /*
         * GT user clocks
         */
        .rx_clk(rx_clk),
        .rx_rst_in(rx_rst_in || rx_reset_req),
        .rx_rst_out(rx_rst_out),
        .tx_clk(tx_clk),
        .tx_rst_in(tx_rst_in),
        .tx_rst_out(tx_rst_out),

        /*
         * Serdes interface
         */
        .serdes_tx_data(serdes_tx_data),
        .serdes_tx_data_valid(serdes_tx_data_valid),
        .serdes_tx_hdr(serdes_tx_hdr),
        .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
        .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
        .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
        .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip)
    );

end else if (DATA_W == 32 && CFG_LOW_LATENCY) begin : gt

    taxi_eth_phy_10g_us_gt_ll #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .HAS_COMMON(HAS_COMMON),

        // GT type
        .GT_TYPE(GT_TYPE),

        // PLL parameters
        .QPLL0_PD(QPLL0_PD),
        .QPLL1_PD(QPLL1_PD),
        .QPLL0_EXT_CTRL(QPLL0_EXT_CTRL),
        .QPLL1_EXT_CTRL(QPLL1_EXT_CTRL),

        // GT parameters
        .GT_TX_PD(GT_TX_PD),
        .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL),
        .GT_TX_POLARITY(GT_TX_POLARITY),
        .GT_TX_ELECIDLE(GT_TX_ELECIDLE),
        .GT_TX_INHIBIT(GT_TX_INHIBIT),
        .GT_TX_DIFFCTRL(GT_TX_DIFFCTRL),
        .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR),
        .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR),
        .GT_TX_PRECURSOR(GT_TX_PRECURSOR),
        .GT_RX_PD(GT_RX_PD),
        .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL),
        .GT_RX_LPM_EN(GT_RX_LPM_EN),
        .GT_RX_POLARITY(GT_RX_POLARITY),

        // MAC/PHY parameters
        .DATA_W(DATA_W),
        .HDR_W(HDR_W)
    )
    gt_inst (
        .xcvr_ctrl_clk(xcvr_ctrl_clk),
        .xcvr_ctrl_rst(xcvr_ctrl_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(s_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(xcvr_gtpowergood_out),

        /*
         * PLL out
         */
        .xcvr_gtrefclk00_in(xcvr_gtrefclk00_in),
        .xcvr_qpll0pd_in(xcvr_qpll0pd_in),
        .xcvr_qpll0reset_in(xcvr_qpll0reset_in),
        .xcvr_qpll0pcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qpll0lock_out(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_out(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_out(xcvr_qpll0refclk_out),
        .xcvr_gtrefclk01_in(xcvr_gtrefclk01_in),
        .xcvr_qpll1pd_in(xcvr_qpll1pd_in),
        .xcvr_qpll1reset_in(xcvr_qpll1reset_in),
        .xcvr_qpll1pcierate_in(xcvr_qpll1pcierate_in),
        .xcvr_qpll1lock_out(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_out(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_out(xcvr_qpll1refclk_out),

        /*
         * PLL in
         */
        .xcvr_qpll0lock_in(xcvr_qpll0lock_in),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_in),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_in),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_in),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_in),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_in),

        /*
         * Serial data
         */
        .xcvr_txp(xcvr_txp),
        .xcvr_txn(xcvr_txn),
        .xcvr_rxp(xcvr_rxp),
        .xcvr_rxn(xcvr_rxn),

        /*
         * GT user clocks
         */
        .rx_clk(rx_clk),
        .rx_rst_in(rx_rst_in || rx_reset_req),
        .rx_rst_out(rx_rst_out),
        .tx_clk(tx_clk),
        .tx_rst_in(tx_rst_in),
        .tx_rst_out(tx_rst_out),

        /*
         * Serdes interface
         */
        .serdes_tx_data(serdes_tx_data),
        .serdes_tx_data_valid(serdes_tx_data_valid),
        .serdes_tx_hdr(serdes_tx_hdr),
        .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
        .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
        .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
        .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip)
    );

end else if (DATA_W == 32 && !CFG_LOW_LATENCY) begin : gt

    taxi_eth_phy_10g_us_gt #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .HAS_COMMON(HAS_COMMON),

        // GT type
        .GT_TYPE(GT_TYPE),

        // PLL parameters
        .QPLL0_PD(QPLL0_PD),
        .QPLL1_PD(QPLL1_PD),
        .QPLL0_EXT_CTRL(QPLL0_EXT_CTRL),
        .QPLL1_EXT_CTRL(QPLL1_EXT_CTRL),

        // GT parameters
        .GT_TX_PD(GT_TX_PD),
        .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL),
        .GT_TX_POLARITY(GT_TX_POLARITY),
        .GT_TX_ELECIDLE(GT_TX_ELECIDLE),
        .GT_TX_INHIBIT(GT_TX_INHIBIT),
        .GT_TX_DIFFCTRL(GT_TX_DIFFCTRL),
        .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR),
        .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR),
        .GT_TX_PRECURSOR(GT_TX_PRECURSOR),
        .GT_RX_PD(GT_RX_PD),
        .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL),
        .GT_RX_LPM_EN(GT_RX_LPM_EN),
        .GT_RX_POLARITY(GT_RX_POLARITY),

        // MAC/PHY parameters
        .DATA_W(DATA_W),
        .HDR_W(HDR_W)
    )
    gt_inst (
        .xcvr_ctrl_clk(xcvr_ctrl_clk),
        .xcvr_ctrl_rst(xcvr_ctrl_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(s_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(xcvr_gtpowergood_out),

        /*
         * PLL out
         */
        .xcvr_gtrefclk00_in(xcvr_gtrefclk00_in),
        .xcvr_qpll0pd_in(xcvr_qpll0pd_in),
        .xcvr_qpll0reset_in(xcvr_qpll0reset_in),
        .xcvr_qpll0pcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qpll0lock_out(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_out(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_out(xcvr_qpll0refclk_out),
        .xcvr_gtrefclk01_in(xcvr_gtrefclk01_in),
        .xcvr_qpll1pd_in(xcvr_qpll1pd_in),
        .xcvr_qpll1reset_in(xcvr_qpll1reset_in),
        .xcvr_qpll1pcierate_in(xcvr_qpll1pcierate_in),
        .xcvr_qpll1lock_out(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_out(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_out(xcvr_qpll1refclk_out),

        /*
         * PLL in
         */
        .xcvr_qpll0lock_in(xcvr_qpll0lock_in),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_in),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_in),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_in),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_in),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_in),

        /*
         * Serial data
         */
        .xcvr_txp(xcvr_txp),
        .xcvr_txn(xcvr_txn),
        .xcvr_rxp(xcvr_rxp),
        .xcvr_rxn(xcvr_rxn),

        /*
         * GT user clocks
         */
        .rx_clk(rx_clk),
        .rx_rst_in(rx_rst_in || rx_reset_req),
        .rx_rst_out(rx_rst_out),
        .tx_clk(tx_clk),
        .tx_rst_in(tx_rst_in),
        .tx_rst_out(tx_rst_out),

        /*
         * Serdes interface
         */
        .serdes_tx_data(serdes_tx_data),
        .serdes_tx_data_valid(serdes_tx_data_valid),
        .serdes_tx_hdr(serdes_tx_hdr),
        .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
        .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
        .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
        .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip)
    );

end else begin

    $fatal(0, "Error: invalid configuration (%m)");

end

if (COMBINED_MAC_PCS) begin : mac

    taxi_eth_mac_phy_10g #(
        .DATA_W(DATA_W),
        .HDR_W(HDR_W),
        .TX_GBX_IF_EN(GBX_EN),
        .RX_GBX_IF_EN(GBX_EN),
        .USXGMII_EN(USXGMII_EN),
        .DIC_EN(DIC_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TD_EN(PTP_TD_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W),
        .PTP_TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE),
        .BIT_REVERSE(1'b1),
        .SCRAMBLER_DISABLE(1'b0),
        .PRBS31_EN(PRBS31_EN),
        .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
        .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
        .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
        .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
        .COUNT_125US(COUNT_125US),
        .PFC_EN(PFC_EN),
        .PAUSE_EN(PAUSE_EN),
        .STAT_EN(STAT_EN),
        .STAT_TX_LEVEL(STAT_TX_LEVEL),
        .STAT_RX_LEVEL(STAT_RX_LEVEL),
        .STAT_ID_BASE(STAT_ID_BASE),
        .STAT_UPDATE_PERIOD(STAT_UPDATE_PERIOD),
        .STAT_STR_EN(STAT_STR_EN),
        .STAT_PREFIX_STR(STAT_PREFIX_STR)
    )
    mac_phy_inst (
        .tx_clk(tx_clk),
        .tx_rst(tx_rst_out),
        .rx_clk(rx_clk),
        .rx_rst(rx_rst_out),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(s_axis_tx),
        .m_axis_tx_cpl(m_axis_tx_cpl),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx),

        /*
         * Serdes interface
         */
        .serdes_tx_data(serdes_tx_data),
        .serdes_tx_data_valid(serdes_tx_data_valid),
        .serdes_tx_hdr(serdes_tx_hdr),
        .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
        .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
        .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
        .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip),
        .serdes_rx_reset_req(rx_reset_req),

        /*
         * USXGMII autonegotiation
         */
        .an_en(an_en),
        .an_restart(an_restart),
        .an_speedup(an_speedup),
        .an_timeout_en(an_timeout_en),
        .an_usxgmii_en(an_usxgmii_en),
        .an_usxgmii_auto(an_usxgmii_auto),
        .an_usxgmii_5g(1'b0),
        .an_intr(an_intr),
        .an_running(an_running),
        .an_complete(an_complete),
        .an_timeout(an_timeout),
        .an_usxgmii_mode(an_usxgmii_mode),
        .an_adv_ability_usxgmii(an_adv_ability_usxgmii),
        .an_lp_adv_ability(an_lp_adv_ability),
        .an_lp_usxgmii_link(an_lp_usxgmii_link),
        .an_lp_usxgmii_speed(an_lp_usxgmii_speed),
        .an_res_full_duplex(an_res_full_duplex),

        /*
         * PTP
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sdi(ptp_td_sdi),
        .tx_ptp_ts_in(tx_ptp_ts_in),
        .tx_ptp_ts_out(tx_ptp_ts_out),
        .tx_ptp_ts_step_out(tx_ptp_ts_step_out),
        .tx_ptp_locked(tx_ptp_locked),
        .rx_ptp_ts_in(rx_ptp_ts_in),
        .rx_ptp_ts_out(rx_ptp_ts_out),
        .rx_ptp_ts_step_out(rx_ptp_ts_step_out),
        .rx_ptp_locked(rx_ptp_locked),

        /*
         * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
         */
        .tx_lfc_req(tx_lfc_req),
        .tx_lfc_resend(tx_lfc_resend),
        .rx_lfc_en(rx_lfc_en),
        .rx_lfc_req(rx_lfc_req),
        .rx_lfc_ack(rx_lfc_ack),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
         */
        .tx_pfc_req(tx_pfc_req),
        .tx_pfc_resend(tx_pfc_resend),
        .rx_pfc_en(rx_pfc_en),
        .rx_pfc_req(rx_pfc_req),
        .rx_pfc_ack(rx_pfc_ack),

        /*
         * Pause interface
         */
        .tx_lfc_pause_en(tx_lfc_pause_en),
        .tx_pause_req(tx_pause_req),
        .tx_pause_ack(tx_pause_ack),

        /*
         * Statistics
         */
        .stat_clk(stat_clk),
        .stat_rst(stat_rst),
        .m_axis_stat(m_axis_stat),

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
        .stat_rx_pfc_paused(stat_rx_pfc_paused),

        /*
         * Configuration
         */
        .cfg_tx_pad_en(cfg_tx_pad_en),
        .cfg_tx_min_pkt_len(cfg_tx_min_pkt_len),
        .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
        .cfg_tx_ifg(cfg_tx_ifg),
        .cfg_tx_enable(cfg_tx_enable),
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
        .cfg_rx_enable(cfg_rx_enable),
        .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable),
        .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable),
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
        .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc),
        .cfg_mcf_rx_forward(cfg_mcf_rx_forward),
        .cfg_mcf_rx_enable(cfg_mcf_rx_enable),
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
        .cfg_rx_lfc_opcode(cfg_rx_lfc_opcode),
        .cfg_rx_lfc_en(cfg_rx_lfc_en),
        .cfg_rx_pfc_opcode(cfg_rx_pfc_opcode),
        .cfg_rx_pfc_en(cfg_rx_pfc_en)
    );

end else begin : mac

    localparam CTRL_W = DATA_W / 8;

    wire [DATA_W-1:0]  xgmii_txd;
    wire [CTRL_W-1:0]  xgmii_txc;
    wire               xgmii_tx_valid;
    wire [DATA_W-1:0]  xgmii_rxd;
    wire [CTRL_W-1:0]  xgmii_rxc;
    wire               xgmii_rx_valid;
    wire               tx_gbx_req_sync;
    wire               tx_gbx_req_stall;
    wire               tx_gbx_sync;

    taxi_eth_phy_10g #(
        .DATA_W(DATA_W),
        .CTRL_W(CTRL_W),
        .HDR_W(HDR_W),
        .TX_GBX_IF_EN(GBX_EN),
        .RX_GBX_IF_EN(GBX_EN),
        .BIT_REVERSE(1'b1),
        .SCRAMBLER_DISABLE(1'b0),
        .PRBS31_EN(PRBS31_EN),
        .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
        .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
        .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
        .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
        .COUNT_125US(COUNT_125US)
    )
    phy_inst (
        .tx_clk(tx_clk),
        .tx_rst(tx_rst_out),
        .rx_clk(rx_clk),
        .rx_rst(rx_rst_out),

        /*
         * XGMII interface
         */
        .xgmii_txd(xgmii_txd),
        .xgmii_txc(xgmii_txc),
        .xgmii_tx_valid(xgmii_tx_valid),
        .xgmii_rxd(xgmii_rxd),
        .xgmii_rxc(xgmii_rxc),
        .xgmii_rx_valid(xgmii_rx_valid),
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
        .serdes_rx_data(serdes_rx_data),
        .serdes_rx_data_valid(serdes_rx_data_valid),
        .serdes_rx_hdr(serdes_rx_hdr),
        .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
        .serdes_rx_bitslip(serdes_rx_bitslip),
        .serdes_rx_reset_req(rx_reset_req),

        /*
         * Status
         */
        .tx_bad_block(),
        .rx_error_count(rx_error_count),
        .rx_bad_block(),
        .rx_sequence_error(),
        .rx_block_lock(rx_block_lock),
        .rx_high_ber(rx_high_ber),
        .rx_status(rx_status),

        /*
         * Configuration
         */
        .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable),
        .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
    );

    taxi_eth_mac_10g #(
        .DATA_W(DATA_W),
        .CTRL_W(CTRL_W),
        .TX_GBX_IF_EN(GBX_EN),
        .RX_GBX_IF_EN(GBX_EN),
        .DIC_EN(DIC_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TD_EN(PTP_TD_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W),
        .PTP_TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE),
        .PFC_EN(PFC_EN),
        .PAUSE_EN(PAUSE_EN),
        .STAT_EN(STAT_EN),
        .STAT_TX_LEVEL(STAT_TX_LEVEL),
        .STAT_RX_LEVEL(STAT_RX_LEVEL),
        .STAT_ID_BASE(STAT_ID_BASE),
        .STAT_UPDATE_PERIOD(STAT_UPDATE_PERIOD),
        .STAT_STR_EN(STAT_STR_EN),
        .STAT_PREFIX_STR(STAT_PREFIX_STR)
    )
    mac_inst (
        .tx_clk(tx_clk),
        .tx_rst(tx_rst_out),
        .rx_clk(rx_clk),
        .rx_rst(rx_rst_out),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(s_axis_tx),
        .m_axis_tx_cpl(m_axis_tx_cpl),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx),

        /*
         * XGMII interface
         */
        .xgmii_txd(xgmii_txd),
        .xgmii_txc(xgmii_txc),
        .xgmii_tx_valid(xgmii_tx_valid),
        .xgmii_rxd(xgmii_rxd),
        .xgmii_rxc(xgmii_rxc),
        .xgmii_rx_valid(xgmii_rx_valid),
        .tx_gbx_req_sync(tx_gbx_req_sync),
        .tx_gbx_req_stall(tx_gbx_req_stall),
        .tx_gbx_sync(tx_gbx_sync),

        /*
         * PTP
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sdi(ptp_td_sdi),
        .tx_ptp_ts_in(tx_ptp_ts_in),
        .tx_ptp_ts_out(tx_ptp_ts_out),
        .tx_ptp_ts_step_out(tx_ptp_ts_step_out),
        .tx_ptp_locked(tx_ptp_locked),
        .rx_ptp_ts_in(rx_ptp_ts_in),
        .rx_ptp_ts_out(rx_ptp_ts_out),
        .rx_ptp_ts_step_out(rx_ptp_ts_step_out),
        .rx_ptp_locked(rx_ptp_locked),

        /*
         * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
         */
        .tx_lfc_req(tx_lfc_req),
        .tx_lfc_resend(tx_lfc_resend),
        .rx_lfc_en(rx_lfc_en),
        .rx_lfc_req(rx_lfc_req),
        .rx_lfc_ack(rx_lfc_ack),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
         */
        .tx_pfc_req(tx_pfc_req),
        .tx_pfc_resend(tx_pfc_resend),
        .rx_pfc_en(rx_pfc_en),
        .rx_pfc_req(rx_pfc_req),
        .rx_pfc_ack(rx_pfc_ack),

        /*
         * Pause interface
         */
        .tx_lfc_pause_en(tx_lfc_pause_en),
        .tx_pause_req(tx_pause_req),
        .tx_pause_ack(tx_pause_ack),

        /*
         * Statistics
         */
        .stat_clk(stat_clk),
        .stat_rst(stat_rst),
        .m_axis_stat(m_axis_stat),

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
        .stat_rx_pfc_paused(stat_rx_pfc_paused),

        /*
         * Configuration
         */
        .cfg_tx_pad_en(cfg_tx_pad_en),
        .cfg_tx_min_pkt_len(cfg_tx_min_pkt_len),
        .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
        .cfg_tx_ifg(cfg_tx_ifg),
        .cfg_tx_enable(cfg_tx_enable),
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
        .cfg_rx_enable(cfg_rx_enable),
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
        .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc),
        .cfg_mcf_rx_forward(cfg_mcf_rx_forward),
        .cfg_mcf_rx_enable(cfg_mcf_rx_enable),
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
        .cfg_rx_lfc_opcode(cfg_rx_lfc_opcode),
        .cfg_rx_lfc_en(cfg_rx_lfc_en),
        .cfg_rx_pfc_opcode(cfg_rx_pfc_opcode),
        .cfg_rx_pfc_en(cfg_rx_pfc_en)
    );

end

endmodule

`resetall
