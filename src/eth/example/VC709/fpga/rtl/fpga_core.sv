// SPDX-License-Identifier: MIT
/*

Copyright (c) 2014-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic
 */
module fpga_core #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtex7",
    // 10G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 32
)
(
    /*
     * Clock: 125 MHz
     * Synchronous reset
     */
    input  wire logic        clk_125mhz,
    input  wire logic        rst_125mhz,

    /*
     * GPIO
     */
    input  wire logic        btnu,
    input  wire logic        btnl,
    input  wire logic        btnd,
    input  wire logic        btnr,
    input  wire logic        btnc,
    input  wire logic [7:0]  sw,
    output wire logic [7:0]  led,

    /*
     * UART: 115200 bps, 8N1
     */
    input  wire logic        uart_rxd,
    output wire logic        uart_txd,
    input  wire logic        uart_rts,
    output wire logic        uart_cts,

    /*
     * I2C
     */
    input  wire logic        i2c_scl_i,
    output wire logic        i2c_scl_o,
    input  wire logic        i2c_sda_i,
    output wire logic        i2c_sda_o,

    /*
     * Ethernet: SFP+
     */
    input  wire logic        sfp_rx_p[4],
    input  wire logic        sfp_rx_n[4],
    output wire logic        sfp_tx_p[4],
    output wire logic        sfp_tx_n[4],
    input  wire logic        sfp_mgt_refclk_p,
    input  wire logic        sfp_mgt_refclk_n,
    // input  wire logic        sma_mgt_refclk_p,
    // input  wire logic        sma_mgt_refclk_n,
    // input  wire logic        sfp_recclk_p,
    // input  wire logic        sfp_recclk_n,

    input  wire logic        sfp_mod_detect[4],
    output wire logic [1:0]  sfp_rs[4],
    input  wire logic        sfp_los[4],
    output wire logic        sfp_tx_disable[4],
    input  wire logic        sfp_tx_fault[4]
);

assign led = sw;

// XFCP
assign uart_cts = 1'b0;

taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_ds(), xfcp_us();

taxi_xfcp_if_uart #(
    .TX_FIFO_DEPTH(512),
    .RX_FIFO_DEPTH(512)
)
xfcp_if_uart_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * UART interface
     */
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),

    /*
     * XFCP downstream interface
     */
    .xfcp_dsp_ds(xfcp_ds),
    .xfcp_dsp_us(xfcp_us),

    /*
     * Configuration
     */
    .prescale(16'(125000000/921600))
);

taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_sw_ds[3](), xfcp_sw_us[3]();

taxi_xfcp_switch #(
    .XFCP_ID_STR("VC709"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR("Taxi example"),
    .PORTS($size(xfcp_sw_us))
)
xfcp_sw_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_ds),
    .xfcp_usp_us(xfcp_us),

    /*
     * XFCP downstream ports
     */
    .xfcp_dsp_ds(xfcp_sw_ds),
    .xfcp_dsp_us(xfcp_sw_us)
);

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_stat();

taxi_xfcp_mod_stats #(
    .XFCP_ID_STR("Statistics"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR(""),
    .STAT_COUNT_W(64),
    .STAT_PIPELINE(2)
)
xfcp_stats_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_sw_ds[0]),
    .xfcp_usp_us(xfcp_sw_us[0]),

    /*
     * Statistics increment input
     */
    .s_axis_stat(axis_stat)
);

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_eth_stat[1]();

taxi_axis_arb_mux #(
    .S_COUNT($size(axis_eth_stat)),
    .UPDATE_TID(1'b0),
    .ARB_ROUND_ROBIN(1'b1),
    .ARB_LSB_HIGH_PRIO(1'b0)
)
stat_mux_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * AXI4-Stream inputs (sink)
     */
    .s_axis(axis_eth_stat),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(axis_stat)
);

// I2C
taxi_xfcp_mod_i2c_master #(
    .XFCP_EXT_ID_STR("I2C"),
    .DEFAULT_PRESCALE(16'(125000000/200000/4))
)
xfcp_mod_i2c_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_sw_ds[1]),
    .xfcp_usp_us(xfcp_sw_us[1]),

    /*
     * I2C interface
     */
    .i2c_scl_i(i2c_scl_i),
    .i2c_scl_o(i2c_scl_o),
    .i2c_sda_i(i2c_sda_i),
    .i2c_sda_o(i2c_sda_o)
);

// SFP+
assign sfp_tx_disable = '{4{1'b0}};

wire sfp_tx_clk[4];
wire sfp_tx_rst[4];
wire sfp_rx_clk[4];
wire sfp_rx_rst[4];

wire sfp_rx_status[4];

wire sfp_gtpowergood;

wire sfp_mgt_refclk;
wire sfp_mgt_refclk_bufg;

wire sfp_rst;

taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_tx[4]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl[4]();
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_rx[4]();

if (SIM) begin

    assign sfp_mgt_refclk = sfp_mgt_refclk_p;
    assign sfp_mgt_refclk_bufg = sfp_mgt_refclk_p;

end else begin

    IBUFDS_GTE2 ibufds_gte2_sfp_mgt_refclk_inst (
        .I     (sfp_mgt_refclk_p),
        .IB    (sfp_mgt_refclk_n),
        .CEB   (1'b0),
        .O     (sfp_mgt_refclk),
        .ODIV2 ()
    );

    BUFG bufg_sfp_mgt_refclk_inst (
        .I (sfp_mgt_refclk),
        .O (sfp_mgt_refclk_bufg)
    );

end

taxi_sync_reset #(
    .N(4)
)
sfp_sync_reset_inst (
    .clk(sfp_mgt_refclk_bufg),
    .rst(rst_125mhz),
    .out(sfp_rst)
);

taxi_apb_if #(
    .ADDR_W(18),
    .DATA_W(16)
)
gt_apb_ctrl();

taxi_xfcp_mod_apb #(
    .XFCP_EXT_ID_STR("GTH CTRL")
)
xfcp_mod_apb_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_sw_ds[2]),
    .xfcp_usp_us(xfcp_sw_us[2]),

    /*
     * APB master interface
     */
    .m_apb(gt_apb_ctrl)
);

taxi_eth_mac_25g_us #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),

    .CNT(4),

    // GT config
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

    // GT type
    .GT_TYPE("GTH"),

    // GT parameters
    .GT_TX_DIFFCTRL('{4{5'd8}}),

    // MAC/PHY config
    .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
    .DATA_W(MAC_DATA_W),
    .USXGMII_EN(1'b1),
    .DIC_EN(1'b1),
    .PTP_TS_EN(1'b0),
    .PTP_TD_EN(1'b0),
    .PTP_TS_FMT_TOD(1'b1),
    .PTP_TS_W(96),
    .PTP_TD_SDI_PIPELINE(2),
    .PRBS31_EN(1'b0),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/6.4),
    .STAT_EN(1),
    .STAT_TX_LEVEL(1),
    .STAT_RX_LEVEL(1),
    .STAT_ID_BASE(0),
    .STAT_UPDATE_PERIOD(1024),
    .STAT_STR_EN(1),
    .STAT_PREFIX_STR('{"SFP0", "SFP1", "SFP2", "SFP3"})
)
sfp_mac_inst (
    .xcvr_ctrl_clk(clk_125mhz),
    .xcvr_ctrl_rst(sfp_rst),

    /*
     * Transceiver control
     */
    .s_apb_ctrl(gt_apb_ctrl),

    /*
     * Common
     */
    .xcvr_gtpowergood_out(sfp_gtpowergood),
    .xcvr_gtrefclk00_in(sfp_mgt_refclk),
    .xcvr_qpll0pd_in(1'b0),
    .xcvr_qpll0reset_in(1'b0),
    .xcvr_qpll0pcierate_in(3'd0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(sfp_mgt_refclk),
    .xcvr_qpll1pd_in(1'b0),
    .xcvr_qpll1reset_in(1'b0),
    .xcvr_qpll1pcierate_in(3'd0),
    .xcvr_qpll1lock_out(),
    .xcvr_qpll1clk_out(),
    .xcvr_qpll1refclk_out(),

    /*
     * Serial data
     */
    .xcvr_txp(sfp_tx_p),
    .xcvr_txn(sfp_tx_n),
    .xcvr_rxp(sfp_rx_p),
    .xcvr_rxn(sfp_rx_n),

    /*
     * MAC clocks
     */
    .rx_clk(sfp_rx_clk),
    .rx_rst_in('{4{1'b0}}),
    .rx_rst_out(sfp_rx_rst),
    .tx_clk(sfp_tx_clk),
    .tx_rst_in('{4{1'b0}}),
    .tx_rst_out(sfp_tx_rst),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_sfp_tx),
    .m_axis_tx_cpl(axis_sfp_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_sfp_rx),

    /*
     * USXGMII autonegotiation
     */
    .an_en('{4{1'b1}}),
    .an_restart('{4{1'b0}}),
    .an_speedup('{4{1'b0}}),
    .an_timeout_en('{4{1'b1}}),
    .an_usxgmii_en('{4{1'b0}}),
    .an_usxgmii_auto('{4{1'b1}}),
    .an_intr(),
    .an_running(),
    .an_complete(),
    .an_timeout(),
    .an_usxgmii_mode(),
    .an_adv_ability_usxgmii('{4{16'h1601}}),
    .an_lp_adv_ability(),
    .an_lp_usxgmii_link(),
    .an_lp_usxgmii_speed(),
    .an_res_full_duplex(),

    /*
     * PTP clock
     */
    .ptp_clk(1'b0),
    .ptp_rst(1'b0),
    .ptp_sample_clk(1'b0),
    .ptp_td_sdi(1'b0),
    .tx_ptp_ts_in('{4{'0}}),
    .tx_ptp_ts_out(),
    .tx_ptp_ts_step_out(),
    .tx_ptp_locked(),
    .rx_ptp_ts_in('{4{'0}}),
    .rx_ptp_ts_out(),
    .rx_ptp_ts_step_out(),
    .rx_ptp_locked(),

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    .tx_lfc_req('{4{1'b0}}),
    .tx_lfc_resend('{4{1'b0}}),
    .rx_lfc_en('{4{1'b0}}),
    .rx_lfc_req(),
    .rx_lfc_ack('{4{1'b0}}),

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    .tx_pfc_req('{4{'0}}),
    .tx_pfc_resend('{4{1'b0}}),
    .rx_pfc_en('{4{'0}}),
    .rx_pfc_req(),
    .rx_pfc_ack('{4{'0}}),

    /*
     * Pause interface
     */
    .tx_lfc_pause_en('{4{1'b0}}),
    .tx_pause_req('{4{1'b0}}),
    .tx_pause_ack(),

    /*
     * Statistics
     */
    .stat_clk(clk_125mhz),
    .stat_rst(rst_125mhz),
    .m_axis_stat(axis_eth_stat[0]),

    /*
     * Status
     */
    .tx_start_packet(),
    .stat_tx_byte(),
    .stat_tx_pkt_len(),
    .stat_tx_pkt_ucast(),
    .stat_tx_pkt_mcast(),
    .stat_tx_pkt_bcast(),
    .stat_tx_pkt_vlan(),
    .stat_tx_pkt_good(),
    .stat_tx_pkt_bad(),
    .stat_tx_pad_frame(),
    .stat_tx_err_oversize(),
    .stat_tx_err_user(),
    .stat_tx_err_underflow(),
    .rx_start_packet(),
    .rx_error_count(),
    .rx_block_lock(),
    .rx_high_ber(),
    .rx_status(sfp_rx_status),
    .stat_rx_byte(),
    .stat_rx_pkt_len(),
    .stat_rx_pkt_fragment(),
    .stat_rx_pkt_jabber(),
    .stat_rx_pkt_ucast(),
    .stat_rx_pkt_mcast(),
    .stat_rx_pkt_bcast(),
    .stat_rx_pkt_vlan(),
    .stat_rx_pkt_good(),
    .stat_rx_pkt_bad(),
    .stat_rx_err_oversize(),
    .stat_rx_err_bad_fcs(),
    .stat_rx_err_bad_block(),
    .stat_rx_err_framing(),
    .stat_rx_err_preamble(),
    .stat_rx_fifo_drop('{4{1'b0}}),
    .stat_tx_mcf(),
    .stat_rx_mcf(),
    .stat_tx_lfc_pkt(),
    .stat_tx_lfc_xon(),
    .stat_tx_lfc_xoff(),
    .stat_tx_lfc_paused(),
    .stat_tx_pfc_pkt(),
    .stat_tx_pfc_xon(),
    .stat_tx_pfc_xoff(),
    .stat_tx_pfc_paused(),
    .stat_rx_lfc_pkt(),
    .stat_rx_lfc_xon(),
    .stat_rx_lfc_xoff(),
    .stat_rx_lfc_paused(),
    .stat_rx_pfc_pkt(),
    .stat_rx_pfc_xon(),
    .stat_rx_pfc_xoff(),
    .stat_rx_pfc_paused(),

    /*
     * Configuration
     */
    .cfg_tx_pad_en('{4{1'b1}}),
    .cfg_tx_min_pkt_len('{4{8'd60-1}}),
    .cfg_tx_max_pkt_len('{4{16'd9218-1}}),
    .cfg_tx_ifg('{4{8'd12}}),
    .cfg_tx_enable('{4{1'b1}}),
    .cfg_rx_max_pkt_len('{4{16'd9218-1}}),
    .cfg_rx_enable('{4{1'b1}}),
    .cfg_tx_prbs31_enable('{4{1'b0}}),
    .cfg_rx_prbs31_enable('{4{1'b0}}),
    .cfg_mcf_rx_eth_dst_mcast('{4{48'h01_80_C2_00_00_01}}),
    .cfg_mcf_rx_check_eth_dst_mcast('{4{1'b1}}),
    .cfg_mcf_rx_eth_dst_ucast('{4{48'd0}}),
    .cfg_mcf_rx_check_eth_dst_ucast('{4{1'b0}}),
    .cfg_mcf_rx_eth_src('{4{48'd0}}),
    .cfg_mcf_rx_check_eth_src('{4{1'b0}}),
    .cfg_mcf_rx_eth_type('{4{16'h8808}}),
    .cfg_mcf_rx_opcode_lfc('{4{16'h0001}}),
    .cfg_mcf_rx_check_opcode_lfc('{4{1'b1}}),
    .cfg_mcf_rx_opcode_pfc('{4{16'h0101}}),
    .cfg_mcf_rx_check_opcode_pfc('{4{1'b1}}),
    .cfg_mcf_rx_forward('{4{1'b0}}),
    .cfg_mcf_rx_enable('{4{1'b0}}),
    .cfg_tx_lfc_eth_dst('{4{48'h01_80_C2_00_00_01}}),
    .cfg_tx_lfc_eth_src('{4{48'h80_23_31_43_54_4C}}),
    .cfg_tx_lfc_eth_type('{4{16'h8808}}),
    .cfg_tx_lfc_opcode('{4{16'h0001}}),
    .cfg_tx_lfc_en('{4{1'b0}}),
    .cfg_tx_lfc_quanta('{4{16'hffff}}),
    .cfg_tx_lfc_refresh('{4{16'h7fff}}),
    .cfg_tx_pfc_eth_dst('{4{48'h01_80_C2_00_00_01}}),
    .cfg_tx_pfc_eth_src('{4{48'h80_23_31_43_54_4C}}),
    .cfg_tx_pfc_eth_type('{4{16'h8808}}),
    .cfg_tx_pfc_opcode('{4{16'h0101}}),
    .cfg_tx_pfc_en('{4{1'b0}}),
    .cfg_tx_pfc_quanta('{4{'{8{16'hffff}}}}),
    .cfg_tx_pfc_refresh('{4{'{8{16'h7fff}}}}),
    .cfg_rx_lfc_opcode('{4{16'h0001}}),
    .cfg_rx_lfc_en('{4{1'b0}}),
    .cfg_rx_pfc_opcode('{4{16'h0101}}),
    .cfg_rx_pfc_en('{4{1'b0}})
);

for (genvar n = 0; n < 4; n = n + 1) begin : sfp_ch

    taxi_axis_async_fifo #(
        .DEPTH(16384),
        .RAM_PIPELINE(2),
        .FRAME_FIFO(1),
        .USER_BAD_FRAME_VALUE(1'b1),
        .USER_BAD_FRAME_MASK(1'b1),
        .DROP_OVERSIZE_FRAME(1),
        .DROP_BAD_FRAME(1),
        .DROP_WHEN_FULL(1)
    )
    ch_fifo (
        /*
         * AXI4-Stream input (sink)
         */
        .s_clk(sfp_rx_clk[n]),
        .s_rst(sfp_rx_rst[n]),
        .s_axis(axis_sfp_rx[n]),

        /*
         * AXI4-Stream output (source)
         */
        .m_clk(sfp_tx_clk[n]),
        .m_rst(sfp_tx_rst[n]),
        .m_axis(axis_sfp_tx[n]),

        /*
         * Pause
         */
        .s_pause_req(1'b0),
        .s_pause_ack(),
        .m_pause_req(1'b0),
        .m_pause_ack(),

        /*
         * Status
         */
        .s_status_depth(),
        .s_status_depth_commit(),
        .s_status_overflow(),
        .s_status_bad_frame(),
        .s_status_good_frame(),
        .m_status_depth(),
        .m_status_depth_commit(),
        .m_status_overflow(),
        .m_status_bad_frame(),
        .m_status_good_frame()
    );

end

endmodule

`resetall
