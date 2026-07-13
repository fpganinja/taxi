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
 * Transceiver and MAC/PHY quad wrapper for UltraScale/UltraScale+
 */
module taxi_eth_mac_25g_us #
(
    parameter logic SIM = 1'b0,
    parameter string VENDOR = "XILINX",
    parameter string FAMILY = "virtexuplus",

    parameter CNT = 4,

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
    // TODO switch to packed arrays; blocked on Verilator bug
    parameter logic [CNT-1:0] GT_TX_PD = '0,
    parameter logic [CNT-1:0] GT_TX_QPLL_SEL = '0,
    parameter logic [CNT-1:0] GT_TX_POLARITY = '0,
    parameter logic [CNT-1:0] GT_TX_ELECIDLE = '0,
    parameter logic [CNT-1:0] GT_TX_INHIBIT = '0,
    parameter logic [CNT-1:0][4:0] GT_TX_DIFFCTRL = '{CNT{5'd16}},
    parameter logic [CNT-1:0][6:0] GT_TX_MAINCURSOR = '{CNT{7'd64}},
    parameter logic [CNT-1:0][4:0] GT_TX_POSTCURSOR = '{CNT{5'd0}},
    parameter logic [CNT-1:0][4:0] GT_TX_PRECURSOR = '{CNT{5'd0}},
    parameter logic [CNT-1:0] GT_RX_PD = '0,
    parameter logic [CNT-1:0] GT_RX_QPLL_SEL = '0,
    parameter logic [CNT-1:0] GT_RX_LPM_EN = '0,
    parameter logic [CNT-1:0] GT_RX_POLARITY = '0,

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
    parameter logic [8*8-1:0] STAT_PREFIX_STR[CNT] = '{CNT{"MAC"}}
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
     * Serial data
     */
    output wire logic                 xcvr_txp[CNT],
    output wire logic                 xcvr_txn[CNT],
    input  wire logic                 xcvr_rxp[CNT],
    input  wire logic                 xcvr_rxn[CNT],

    /*
     * MAC clocks
     */
    output wire logic                 rx_clk[CNT],
    input  wire logic                 rx_rst_in[CNT] = '{CNT{1'b0}},
    output wire logic                 rx_rst_out[CNT],
    output wire logic                 tx_clk[CNT],
    input  wire logic                 tx_rst_in[CNT] = '{CNT{1'b0}},
    output wire logic                 tx_rst_out[CNT],

    /*
     * Transmit interface (AXI stream)
     */
    taxi_axis_if.snk                  s_axis_tx[CNT],
    taxi_axis_if.src                  m_axis_tx_cpl[CNT],

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx[CNT],

    /*
     * USXGMII autonegotiation
     */
    input  wire logic                 an_en[CNT] = '{CNT{1'b1}},
    input  wire logic                 an_restart[CNT] = '{CNT{1'b0}},
    input  wire logic                 an_speedup[CNT] = '{CNT{1'b0}},
    input  wire logic                 an_timeout_en[CNT] = '{CNT{1'b1}},
    input  wire logic                 an_usxgmii_en[CNT] = '{CNT{1'b0}},
    input  wire logic                 an_usxgmii_auto[CNT] = '{CNT{1'b1}},
    output wire logic                 an_intr[CNT],
    output wire logic                 an_running[CNT],
    output wire logic                 an_complete[CNT],
    output wire logic                 an_timeout[CNT],
    output wire logic                 an_usxgmii_mode[CNT],
    input  wire logic [15:0]          an_adv_ability_usxgmii[CNT] = '{CNT{16'h1601}},
    output wire logic [15:0]          an_lp_adv_ability[CNT],
    output wire logic                 an_lp_usxgmii_link[CNT],
    output wire logic [2:0]           an_lp_usxgmii_speed[CNT],
    output wire logic                 an_res_full_duplex[CNT],

    /*
     * PTP clock
     */
    input  wire logic                 ptp_clk = 1'b0,
    input  wire logic                 ptp_rst = 1'b0,
    input  wire logic                 ptp_sample_clk = 1'b0,
    input  wire logic                 ptp_td_sdi = 1'b0,
    input  wire logic [PTP_TS_W-1:0]  tx_ptp_ts_in[CNT] = '{CNT{'0}},
    output wire logic [PTP_TS_W-1:0]  tx_ptp_ts_out[CNT],
    output wire logic                 tx_ptp_ts_step_out[CNT],
    output wire logic                 tx_ptp_locked[CNT],
    input  wire logic [PTP_TS_W-1:0]  rx_ptp_ts_in[CNT] = '{CNT{'0}},
    output wire logic [PTP_TS_W-1:0]  rx_ptp_ts_out[CNT],
    output wire logic                 rx_ptp_ts_step_out[CNT],
    output wire logic                 rx_ptp_locked[CNT],

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    input  wire logic                 tx_lfc_req[CNT] = '{CNT{1'b0}},
    input  wire logic                 tx_lfc_resend[CNT] = '{CNT{1'b0}},
    input  wire logic                 rx_lfc_en[CNT] = '{CNT{1'b0}},
    output wire logic                 rx_lfc_req[CNT],
    input  wire logic                 rx_lfc_ack[CNT] = '{CNT{1'b0}},

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    input  wire logic [7:0]           tx_pfc_req[CNT] = '{CNT{'0}},
    input  wire logic                 tx_pfc_resend[CNT] = '{CNT{1'b0}},
    input  wire logic [7:0]           rx_pfc_en[CNT] = '{CNT{'0}},
    output wire logic [7:0]           rx_pfc_req[CNT],
    input  wire logic [7:0]           rx_pfc_ack[CNT] = '{CNT{'0}},

    /*
     * Pause interface
     */
    input  wire logic                 tx_lfc_pause_en[CNT] = '{CNT{1'b0}},
    input  wire logic                 tx_pause_req[CNT] = '{CNT{1'b0}},
    output wire logic                 tx_pause_ack[CNT],

    /*
     * Statistics
     */
    input  wire logic                 stat_clk,
    input  wire logic                 stat_rst,
    taxi_axis_if.src                  m_axis_stat,

    /*
     * Status
     */
    output wire logic [1:0]           tx_start_packet[CNT],
    output wire logic [3:0]           stat_tx_byte[CNT],
    output wire logic [15:0]          stat_tx_pkt_len[CNT],
    output wire logic                 stat_tx_pkt_ucast[CNT],
    output wire logic                 stat_tx_pkt_mcast[CNT],
    output wire logic                 stat_tx_pkt_bcast[CNT],
    output wire logic                 stat_tx_pkt_vlan[CNT],
    output wire logic                 stat_tx_pkt_good[CNT],
    output wire logic                 stat_tx_pkt_bad[CNT],
    output wire logic                 stat_tx_pad_frame[CNT],
    output wire logic                 stat_tx_err_oversize[CNT],
    output wire logic                 stat_tx_err_user[CNT],
    output wire logic                 stat_tx_err_underflow[CNT],
    output wire logic [1:0]           rx_start_packet[CNT],
    output wire logic [6:0]           rx_error_count[CNT],
    output wire logic                 rx_block_lock[CNT],
    output wire logic                 rx_high_ber[CNT],
    output wire logic                 rx_status[CNT],
    output wire logic [3:0]           stat_rx_byte[CNT],
    output wire logic [15:0]          stat_rx_pkt_len[CNT],
    output wire logic                 stat_rx_pkt_fragment[CNT],
    output wire logic                 stat_rx_pkt_jabber[CNT],
    output wire logic                 stat_rx_pkt_ucast[CNT],
    output wire logic                 stat_rx_pkt_mcast[CNT],
    output wire logic                 stat_rx_pkt_bcast[CNT],
    output wire logic                 stat_rx_pkt_vlan[CNT],
    output wire logic                 stat_rx_pkt_good[CNT],
    output wire logic                 stat_rx_pkt_bad[CNT],
    output wire logic                 stat_rx_err_oversize[CNT],
    output wire logic                 stat_rx_err_bad_fcs[CNT],
    output wire logic                 stat_rx_err_bad_block[CNT],
    output wire logic                 stat_rx_err_framing[CNT],
    output wire logic                 stat_rx_err_preamble[CNT],
    input  wire logic                 stat_rx_fifo_drop[CNT] = '{CNT{1'b0}},
    output wire logic                 stat_tx_mcf[CNT],
    output wire logic                 stat_rx_mcf[CNT],
    output wire logic                 stat_tx_lfc_pkt[CNT],
    output wire logic                 stat_tx_lfc_xon[CNT],
    output wire logic                 stat_tx_lfc_xoff[CNT],
    output wire logic                 stat_tx_lfc_paused[CNT],
    output wire logic                 stat_tx_pfc_pkt[CNT],
    output wire logic [7:0]           stat_tx_pfc_xon[CNT],
    output wire logic [7:0]           stat_tx_pfc_xoff[CNT],
    output wire logic [7:0]           stat_tx_pfc_paused[CNT],
    output wire logic                 stat_rx_lfc_pkt[CNT],
    output wire logic                 stat_rx_lfc_xon[CNT],
    output wire logic                 stat_rx_lfc_xoff[CNT],
    output wire logic                 stat_rx_lfc_paused[CNT],
    output wire logic                 stat_rx_pfc_pkt[CNT],
    output wire logic [7:0]           stat_rx_pfc_xon[CNT],
    output wire logic [7:0]           stat_rx_pfc_xoff[CNT],
    output wire logic [7:0]           stat_rx_pfc_paused[CNT],

    /*
     * Configuration
     */
    input  wire logic                 cfg_tx_pad_en[CNT] = '{CNT{1'b1}},
    input  wire logic [7:0]           cfg_tx_min_pkt_len[CNT] = '{CNT{8'd60-1}},
    input  wire logic [15:0]          cfg_tx_max_pkt_len[CNT] = '{CNT{16'd1518-1}},
    input  wire logic [7:0]           cfg_tx_ifg[CNT] = '{CNT{8'd12}},
    input  wire logic                 cfg_tx_enable[CNT] = '{CNT{1'b1}},
    input  wire logic [15:0]          cfg_rx_max_pkt_len[CNT] = '{CNT{16'd1518-1}},
    input  wire logic                 cfg_rx_enable[CNT] = '{CNT{1'b1}},
    input  wire logic [7:0]           cfg_ifg[CNT] = '{CNT{8'd12}},
    input  wire logic                 cfg_tx_prbs31_enable[CNT] = '{CNT{1'b0}},
    input  wire logic                 cfg_rx_prbs31_enable[CNT] = '{CNT{1'b0}},
    input  wire logic [47:0]          cfg_mcf_rx_eth_dst_mcast[CNT] = '{CNT{48'h01_80_C2_00_00_01}},
    input  wire logic                 cfg_mcf_rx_check_eth_dst_mcast[CNT] = '{CNT{1'b1}},
    input  wire logic [47:0]          cfg_mcf_rx_eth_dst_ucast[CNT] = '{CNT{48'd0}},
    input  wire logic                 cfg_mcf_rx_check_eth_dst_ucast[CNT] = '{CNT{1'b0}},
    input  wire logic [47:0]          cfg_mcf_rx_eth_src[CNT] = '{CNT{48'd0}},
    input  wire logic                 cfg_mcf_rx_check_eth_src[CNT] = '{CNT{1'b0}},
    input  wire logic [15:0]          cfg_mcf_rx_eth_type[CNT] = '{CNT{16'h8808}},
    input  wire logic [15:0]          cfg_mcf_rx_opcode_lfc[CNT] = '{CNT{16'h0001}},
    input  wire logic                 cfg_mcf_rx_check_opcode_lfc[CNT] = '{CNT{1'b1}},
    input  wire logic [15:0]          cfg_mcf_rx_opcode_pfc[CNT] = '{CNT{16'h0101}},
    input  wire logic                 cfg_mcf_rx_check_opcode_pfc[CNT] = '{CNT{1'b1}},
    input  wire logic                 cfg_mcf_rx_forward[CNT] = '{CNT{1'b0}},
    input  wire logic                 cfg_mcf_rx_enable[CNT] = '{CNT{1'b0}},
    input  wire logic [47:0]          cfg_tx_lfc_eth_dst[CNT] = '{CNT{48'h01_80_C2_00_00_01}},
    input  wire logic [47:0]          cfg_tx_lfc_eth_src[CNT] = '{CNT{48'h80_23_31_43_54_4C}},
    input  wire logic [15:0]          cfg_tx_lfc_eth_type[CNT] = '{CNT{16'h8808}},
    input  wire logic [15:0]          cfg_tx_lfc_opcode[CNT] = '{CNT{16'h0001}},
    input  wire logic                 cfg_tx_lfc_en[CNT] = '{CNT{1'b0}},
    input  wire logic [15:0]          cfg_tx_lfc_quanta[CNT] = '{CNT{16'hffff}},
    input  wire logic [15:0]          cfg_tx_lfc_refresh[CNT] = '{CNT{16'h7fff}},
    input  wire logic [47:0]          cfg_tx_pfc_eth_dst[CNT] = '{CNT{48'h01_80_C2_00_00_01}},
    input  wire logic [47:0]          cfg_tx_pfc_eth_src[CNT] = '{CNT{48'h80_23_31_43_54_4C}},
    input  wire logic [15:0]          cfg_tx_pfc_eth_type[CNT] = '{CNT{16'h8808}},
    input  wire logic [15:0]          cfg_tx_pfc_opcode[CNT] = '{CNT{16'h0101}},
    input  wire logic                 cfg_tx_pfc_en[CNT] = '{CNT{1'b0}},
    input  wire logic [15:0]          cfg_tx_pfc_quanta[CNT][8] = '{CNT{'{8{16'hffff}}}},
    input  wire logic [15:0]          cfg_tx_pfc_refresh[CNT][8] = '{CNT{'{8{16'h7fff}}}},
    input  wire logic [15:0]          cfg_rx_lfc_opcode[CNT] = '{CNT{16'h0001}},
    input  wire logic                 cfg_rx_lfc_en[CNT] = '{CNT{1'b0}},
    input  wire logic [15:0]          cfg_rx_pfc_opcode[CNT] = '{CNT{16'h0101}},
    input  wire logic                 cfg_rx_pfc_en[CNT] = '{CNT{1'b0}}
);

wire xcvr_ctrl_rst_sync;

taxi_sync_reset #(
    .N(4)
)
reset_sync_inst (
    .clk(xcvr_ctrl_clk),
    .rst(xcvr_ctrl_rst),
    .out(xcvr_ctrl_rst_sync)
);

// transceiver control
taxi_apb_if #(
    .ADDR_W(16),
    .DATA_W(16)
)
ch_apb_ctrl[CNT]();

taxi_apb_interconnect_1s #(
    .M_CNT(CNT),
    .ADDR_W(s_apb_ctrl.ADDR_W),
    .M_REGIONS(1),
    .M_BASE_ADDR('0),
    .M_ADDR_W({CNT{{1{32'd16}}}})
)
ctrl_intercon_inst (
    .clk(xcvr_ctrl_clk),
    .rst(xcvr_ctrl_rst_sync),

    /*
     * APB slave interface
     */
    .s_apb(s_apb_ctrl),

    /*
     * APB master interface
     */
    .m_apb(ch_apb_ctrl)
);

// statistics
localparam STAT_TX_CNT = STAT_TX_LEVEL == 0 ? 8 : (STAT_TX_LEVEL == 1 ? 16: 32);
localparam STAT_RX_CNT = STAT_RX_LEVEL == 0 ? 8 : (STAT_RX_LEVEL == 1 ? 16: 32);

taxi_axis_if #(
    .DATA_W(m_axis_stat.DATA_W),
    .KEEP_EN(m_axis_stat.KEEP_EN),
    .KEEP_W(m_axis_stat.KEEP_W),
    .LAST_EN(m_axis_stat.LAST_EN),
    .ID_EN(m_axis_stat.ID_EN),
    .ID_W(m_axis_stat.ID_W),
    .USER_EN(m_axis_stat.USER_EN),
    .USER_W(m_axis_stat.USER_W)
)
axis_stat_int[CNT]();

if (STAT_EN) begin : stats

    taxi_axis_arb_mux #(
        .S_COUNT(CNT),
        .UPDATE_TID(1'b0),
        .ARB_ROUND_ROBIN(1'b1),
        .ARB_LSB_HIGH_PRIO(1'b0)
    )
    stat_mux_inst (
        .clk(stat_clk),
        .rst(stat_rst),

        /*
         * AXI4-Stream inputs (sink)
         */
        .s_axis(axis_stat_int),

        /*
         * AXI4-Stream output (source)
         */
        .m_axis(m_axis_stat)
    );

end

for (genvar n = 0; n < CNT; n = n + 1) begin : ch

    localparam HAS_COMMON = n == 0;

    wire ch_gtpowergood_out;

    wire ch_qpll0lock_out;
    wire ch_qpll0clk_out;
    wire ch_qpll0refclk_out;
    wire ch_qpll1lock_out;
    wire ch_qpll1clk_out;
    wire ch_qpll1refclk_out;

    if (HAS_COMMON) begin
        // drive outputs from common
        assign xcvr_gtpowergood_out = ch_gtpowergood_out;

        assign xcvr_qpll0lock_out = ch_qpll0lock_out;
        assign xcvr_qpll0clk_out = ch_qpll0clk_out;
        assign xcvr_qpll0refclk_out = ch_qpll0refclk_out;
        assign xcvr_qpll1lock_out = ch_qpll1lock_out;
        assign xcvr_qpll1clk_out = ch_qpll1clk_out;
        assign xcvr_qpll1refclk_out = ch_qpll1refclk_out;
    end

    taxi_eth_mac_25g_us_ch #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .HAS_COMMON(HAS_COMMON),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE(GT_TYPE),

        // PLL parameters
        .QPLL0_PD(QPLL0_PD),
        .QPLL1_PD(QPLL1_PD),
        .QPLL0_EXT_CTRL(QPLL0_EXT_CTRL),
        .QPLL1_EXT_CTRL(QPLL1_EXT_CTRL),

        // GT parameters
        .GT_TX_PD(GT_TX_PD[n]),
        .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL[n]),
        .GT_TX_POLARITY(GT_TX_POLARITY[n]),
        .GT_TX_ELECIDLE(GT_TX_ELECIDLE[n]),
        .GT_TX_INHIBIT(GT_TX_INHIBIT[n]),
        .GT_TX_DIFFCTRL(GT_TX_DIFFCTRL[n]),
        .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR[n]),
        .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR[n]),
        .GT_TX_PRECURSOR(GT_TX_PRECURSOR[n]),
        .GT_RX_PD(GT_RX_PD[n]),
        .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL[n]),
        .GT_RX_LPM_EN(GT_RX_LPM_EN[n]),
        .GT_RX_POLARITY(GT_RX_POLARITY[n]),

        // MAC/PHY parameters
        .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
        .DATA_W(DATA_W),
        .USXGMII_EN(USXGMII_EN),
        .DIC_EN(DIC_EN),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TD_EN(PTP_TD_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W),
        .PTP_TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE),
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
        .STAT_ID_BASE(STAT_ID_BASE + n*(STAT_TX_CNT+STAT_RX_CNT)),
        .STAT_UPDATE_PERIOD(STAT_UPDATE_PERIOD),
        .STAT_STR_EN(STAT_STR_EN),
        .STAT_PREFIX_STR(STAT_PREFIX_STR[n])
    )
    ch_inst (
        .xcvr_ctrl_clk(xcvr_ctrl_clk),
        .xcvr_ctrl_rst(xcvr_ctrl_rst_sync),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(ch_apb_ctrl[n]),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(ch_gtpowergood_out),

        /*
         * PLL out
         */
        .xcvr_gtrefclk00_in(xcvr_gtrefclk00_in),
        .xcvr_qpll0pd_in(xcvr_qpll0pd_in),
        .xcvr_qpll0reset_in(xcvr_qpll0reset_in),
        .xcvr_qpll0pcierate_in(xcvr_qpll0pcierate_in),
        .xcvr_qpll0lock_out(ch_qpll0lock_out),
        .xcvr_qpll0clk_out(ch_qpll0clk_out),
        .xcvr_qpll0refclk_out(ch_qpll0refclk_out),
        .xcvr_gtrefclk01_in(xcvr_gtrefclk01_in),
        .xcvr_qpll1pd_in(xcvr_qpll1pd_in),
        .xcvr_qpll1reset_in(xcvr_qpll1reset_in),
        .xcvr_qpll1pcierate_in(xcvr_qpll1pcierate_in),
        .xcvr_qpll1lock_out(ch_qpll1lock_out),
        .xcvr_qpll1clk_out(ch_qpll1clk_out),
        .xcvr_qpll1refclk_out(ch_qpll1refclk_out),

        /*
         * PLL in
         */
        .xcvr_qpll0lock_in(xcvr_qpll0lock_out),
        .xcvr_qpll0clk_in(xcvr_qpll0clk_out),
        .xcvr_qpll0refclk_in(xcvr_qpll0refclk_out),
        .xcvr_qpll1lock_in(xcvr_qpll1lock_out),
        .xcvr_qpll1clk_in(xcvr_qpll1clk_out),
        .xcvr_qpll1refclk_in(xcvr_qpll1refclk_out),

        /*
         * Serial data
         */
        .xcvr_txp(xcvr_txp[n]),
        .xcvr_txn(xcvr_txn[n]),
        .xcvr_rxp(xcvr_rxp[n]),
        .xcvr_rxn(xcvr_rxn[n]),

        /*
         * MAC clocks
         */
        .rx_clk(rx_clk[n]),
        .rx_rst_in(rx_rst_in[n]),
        .rx_rst_out(rx_rst_out[n]),
        .tx_clk(tx_clk[n]),
        .tx_rst_in(tx_rst_in[n]),
        .tx_rst_out(tx_rst_out[n]),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(s_axis_tx[n]),
        .m_axis_tx_cpl(m_axis_tx_cpl[n]),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(m_axis_rx[n]),

        /*
         * USXGMII autonegotiation
         */
        .an_en(an_en[n]),
        .an_restart(an_restart[n]),
        .an_speedup(an_speedup[n]),
        .an_timeout_en(an_timeout_en[n]),
        .an_usxgmii_en(an_usxgmii_en[n]),
        .an_usxgmii_auto(an_usxgmii_auto[n]),
        .an_intr(an_intr[n]),
        .an_running(an_running[n]),
        .an_complete(an_complete[n]),
        .an_timeout(an_timeout[n]),
        .an_usxgmii_mode(an_usxgmii_mode[n]),
        .an_adv_ability_usxgmii(an_adv_ability_usxgmii[n]),
        .an_lp_adv_ability(an_lp_adv_ability[n]),
        .an_lp_usxgmii_link(an_lp_usxgmii_link[n]),
        .an_lp_usxgmii_speed(an_lp_usxgmii_speed[n]),
        .an_res_full_duplex(an_res_full_duplex[n]),

        /*
         * PTP clock
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sdi(ptp_td_sdi),
        .tx_ptp_ts_in(tx_ptp_ts_in[n]),
        .tx_ptp_ts_out(tx_ptp_ts_out[n]),
        .tx_ptp_ts_step_out(tx_ptp_ts_step_out[n]),
        .tx_ptp_locked(tx_ptp_locked[n]),
        .rx_ptp_ts_in(rx_ptp_ts_in[n]),
        .rx_ptp_ts_out(rx_ptp_ts_out[n]),
        .rx_ptp_ts_step_out(rx_ptp_ts_step_out[n]),
        .rx_ptp_locked(rx_ptp_locked[n]),

        /*
         * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
         */
        .tx_lfc_req(tx_lfc_req[n]),
        .tx_lfc_resend(tx_lfc_resend[n]),
        .rx_lfc_en(rx_lfc_en[n]),
        .rx_lfc_req(rx_lfc_req[n]),
        .rx_lfc_ack(rx_lfc_ack[n]),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
         */
        .tx_pfc_req(tx_pfc_req[n]),
        .tx_pfc_resend(tx_pfc_resend[n]),
        .rx_pfc_en(rx_pfc_en[n]),
        .rx_pfc_req(rx_pfc_req[n]),
        .rx_pfc_ack(rx_pfc_ack[n]),

        /*
         * Pause interface
         */
        .tx_lfc_pause_en(tx_lfc_pause_en[n]),
        .tx_pause_req(tx_pause_req[n]),
        .tx_pause_ack(tx_pause_ack[n]),

        /*
         * Statistics
         */
        .stat_clk(stat_clk),
        .stat_rst(stat_rst),
        .m_axis_stat(axis_stat_int[n]),

        /*
         * Status
         */
        .tx_start_packet(tx_start_packet[n]),
        .stat_tx_byte(stat_tx_byte[n]),
        .stat_tx_pkt_len(stat_tx_pkt_len[n]),
        .stat_tx_pkt_ucast(stat_tx_pkt_ucast[n]),
        .stat_tx_pkt_mcast(stat_tx_pkt_mcast[n]),
        .stat_tx_pkt_bcast(stat_tx_pkt_bcast[n]),
        .stat_tx_pkt_vlan(stat_tx_pkt_vlan[n]),
        .stat_tx_pkt_good(stat_tx_pkt_good[n]),
        .stat_tx_pkt_bad(stat_tx_pkt_bad[n]),
        .stat_tx_pad_frame(stat_tx_pad_frame[n]),
        .stat_tx_err_oversize(stat_tx_err_oversize[n]),
        .stat_tx_err_user(stat_tx_err_user[n]),
        .stat_tx_err_underflow(stat_tx_err_underflow[n]),
        .rx_start_packet(rx_start_packet[n]),
        .rx_error_count(rx_error_count[n]),
        .rx_block_lock(rx_block_lock[n]),
        .rx_high_ber(rx_high_ber[n]),
        .rx_status(rx_status[n]),
        .stat_rx_byte(stat_rx_byte[n]),
        .stat_rx_pkt_len(stat_rx_pkt_len[n]),
        .stat_rx_pkt_fragment(stat_rx_pkt_fragment[n]),
        .stat_rx_pkt_jabber(stat_rx_pkt_jabber[n]),
        .stat_rx_pkt_ucast(stat_rx_pkt_ucast[n]),
        .stat_rx_pkt_mcast(stat_rx_pkt_mcast[n]),
        .stat_rx_pkt_bcast(stat_rx_pkt_bcast[n]),
        .stat_rx_pkt_vlan(stat_rx_pkt_vlan[n]),
        .stat_rx_pkt_good(stat_rx_pkt_good[n]),
        .stat_rx_pkt_bad(stat_rx_pkt_bad[n]),
        .stat_rx_err_oversize(stat_rx_err_oversize[n]),
        .stat_rx_err_bad_fcs(stat_rx_err_bad_fcs[n]),
        .stat_rx_err_bad_block(stat_rx_err_bad_block[n]),
        .stat_rx_err_framing(stat_rx_err_framing[n]),
        .stat_rx_err_preamble(stat_rx_err_preamble[n]),
        .stat_rx_fifo_drop(stat_rx_fifo_drop[n]),
        .stat_tx_mcf(stat_tx_mcf[n]),
        .stat_rx_mcf(stat_rx_mcf[n]),
        .stat_tx_lfc_pkt(stat_tx_lfc_pkt[n]),
        .stat_tx_lfc_xon(stat_tx_lfc_xon[n]),
        .stat_tx_lfc_xoff(stat_tx_lfc_xoff[n]),
        .stat_tx_lfc_paused(stat_tx_lfc_paused[n]),
        .stat_tx_pfc_pkt(stat_tx_pfc_pkt[n]),
        .stat_tx_pfc_xon(stat_tx_pfc_xon[n]),
        .stat_tx_pfc_xoff(stat_tx_pfc_xoff[n]),
        .stat_tx_pfc_paused(stat_tx_pfc_paused[n]),
        .stat_rx_lfc_pkt(stat_rx_lfc_pkt[n]),
        .stat_rx_lfc_xon(stat_rx_lfc_xon[n]),
        .stat_rx_lfc_xoff(stat_rx_lfc_xoff[n]),
        .stat_rx_lfc_paused(stat_rx_lfc_paused[n]),
        .stat_rx_pfc_pkt(stat_rx_pfc_pkt[n]),
        .stat_rx_pfc_xon(stat_rx_pfc_xon[n]),
        .stat_rx_pfc_xoff(stat_rx_pfc_xoff[n]),
        .stat_rx_pfc_paused(stat_rx_pfc_paused[n]),

        /*
         * Configuration
         */
        .cfg_tx_pad_en(cfg_tx_pad_en[n]),
        .cfg_tx_min_pkt_len(cfg_tx_min_pkt_len[n]),
        .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len[n]),
        .cfg_tx_ifg(cfg_tx_ifg[n]),
        .cfg_tx_enable(cfg_tx_enable[n]),
        .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len[n]),
        .cfg_rx_enable(cfg_rx_enable[n]),
        .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable[n]),
        .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable[n]),
        .cfg_mcf_rx_eth_dst_mcast(cfg_mcf_rx_eth_dst_mcast[n]),
        .cfg_mcf_rx_check_eth_dst_mcast(cfg_mcf_rx_check_eth_dst_mcast[n]),
        .cfg_mcf_rx_eth_dst_ucast(cfg_mcf_rx_eth_dst_ucast[n]),
        .cfg_mcf_rx_check_eth_dst_ucast(cfg_mcf_rx_check_eth_dst_ucast[n]),
        .cfg_mcf_rx_eth_src(cfg_mcf_rx_eth_src[n]),
        .cfg_mcf_rx_check_eth_src(cfg_mcf_rx_check_eth_src[n]),
        .cfg_mcf_rx_eth_type(cfg_mcf_rx_eth_type[n]),
        .cfg_mcf_rx_opcode_lfc(cfg_mcf_rx_opcode_lfc[n]),
        .cfg_mcf_rx_check_opcode_lfc(cfg_mcf_rx_check_opcode_lfc[n]),
        .cfg_mcf_rx_opcode_pfc(cfg_mcf_rx_opcode_pfc[n]),
        .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc[n]),
        .cfg_mcf_rx_forward(cfg_mcf_rx_forward[n]),
        .cfg_mcf_rx_enable(cfg_mcf_rx_enable[n]),
        .cfg_tx_lfc_eth_dst(cfg_tx_lfc_eth_dst[n]),
        .cfg_tx_lfc_eth_src(cfg_tx_lfc_eth_src[n]),
        .cfg_tx_lfc_eth_type(cfg_tx_lfc_eth_type[n]),
        .cfg_tx_lfc_opcode(cfg_tx_lfc_opcode[n]),
        .cfg_tx_lfc_en(cfg_tx_lfc_en[n]),
        .cfg_tx_lfc_quanta(cfg_tx_lfc_quanta[n]),
        .cfg_tx_lfc_refresh(cfg_tx_lfc_refresh[n]),
        .cfg_tx_pfc_eth_dst(cfg_tx_pfc_eth_dst[n]),
        .cfg_tx_pfc_eth_src(cfg_tx_pfc_eth_src[n]),
        .cfg_tx_pfc_eth_type(cfg_tx_pfc_eth_type[n]),
        .cfg_tx_pfc_opcode(cfg_tx_pfc_opcode[n]),
        .cfg_tx_pfc_en(cfg_tx_pfc_en[n]),
        .cfg_tx_pfc_quanta(cfg_tx_pfc_quanta[n]),
        .cfg_tx_pfc_refresh(cfg_tx_pfc_refresh[n]),
        .cfg_rx_lfc_opcode(cfg_rx_lfc_opcode[n]),
        .cfg_rx_lfc_en(cfg_rx_lfc_en[n]),
        .cfg_rx_pfc_opcode(cfg_rx_pfc_opcode[n]),
        .cfg_rx_pfc_en(cfg_rx_pfc_en[n])
    );

end

endmodule

`resetall
