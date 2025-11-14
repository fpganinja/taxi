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
    parameter string FAMILY = "kintex7",
    // Use 90 degree clock for RGMII transmit
    parameter logic USE_CLK90 = 1'b1,
    // BASE-T PHY type (GMII or RGMII)
    parameter BASET_PHY_TYPE = "GMII",
    // Invert SFP data pins
    parameter logic SFP_INVERT = 1'b1,
    // 10G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 32
)
(
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire logic        clk,
    input  wire logic        clk90,
    input  wire logic        rst,

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
    input  wire logic        sfp_rx_p,
    input  wire logic        sfp_rx_n,
    output wire logic        sfp_tx_p,
    output wire logic        sfp_tx_n,
    input  wire logic        sfp_mgt_refclk_p,
    input  wire logic        sfp_mgt_refclk_n,

    output wire logic        sfp_tx_disable_b,

    /*
     * Ethernet: 1000BASE-T
     */
    input  wire logic        phy_rgmii_rx_clk,
    input  wire logic [3:0]  phy_rgmii_rxd,
    input  wire logic        phy_rgmii_rx_ctl,
    output wire logic        phy_rgmii_tx_clk,
    output wire logic [3:0]  phy_rgmii_txd,
    output wire logic        phy_rgmii_tx_ctl,

    input  wire logic        phy_gmii_rx_clk,
    input  wire logic [7:0]  phy_gmii_rxd,
    input  wire logic        phy_gmii_rx_dv,
    input  wire logic        phy_gmii_rx_er,
    output wire logic        phy_gmii_gtx_clk,
    input  wire logic        phy_gmii_tx_clk,
    output wire logic [7:0]  phy_gmii_txd,
    output wire logic        phy_gmii_tx_en,
    output wire logic        phy_gmii_tx_er,

    output wire logic        phy_reset_n,
    input  wire logic        phy_int_n
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
    .clk(clk),
    .rst(rst),

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
    .XFCP_ID_STR("KC705"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR("Taxi example"),
    .PORTS($size(xfcp_sw_us))
)
xfcp_sw_inst (
    .clk(clk),
    .rst(rst),

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
    .clk(clk),
    .rst(rst),

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

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_eth_stat[2]();

taxi_axis_arb_mux #(
    .S_COUNT($size(axis_eth_stat)),
    .UPDATE_TID(1'b0),
    .ARB_ROUND_ROBIN(1'b1),
    .ARB_LSB_HIGH_PRIO(1'b0)
)
stat_mux_inst (
    .clk(clk),
    .rst(rst),

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
    .clk(clk),
    .rst(rst),

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

// BASE-T PHY
assign phy_reset_n = !rst;

taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_eth();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_tx_cpl();

if (BASET_PHY_TYPE == "GMII") begin : baset_mac_gmii

    taxi_eth_mac_1g_gmii_fifo #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),
        .PADDING_EN(1),
        .MIN_FRAME_LEN(64),
        .STAT_EN(1),
        .STAT_TX_LEVEL(1),
        .STAT_RX_LEVEL(1),
        .STAT_ID_BASE(0),
        .STAT_UPDATE_PERIOD(1024),
        .STAT_STR_EN(1),
        .STAT_PREFIX_STR("GMII0"),
        .TX_FIFO_DEPTH(16384),
        .TX_FRAME_FIFO(1),
        .RX_FIFO_DEPTH(16384),
        .RX_FRAME_FIFO(1)
    )
    eth_mac_inst (
        .gtx_clk(clk),
        .gtx_rst(rst),
        .logic_clk(clk),
        .logic_rst(rst),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_eth),
        .m_axis_tx_cpl(axis_tx_cpl),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_eth),

        /*
         * GMII interface
         */
        .gmii_rx_clk(phy_gmii_rx_clk),
        .gmii_rxd(phy_gmii_rxd),
        .gmii_rx_dv(phy_gmii_rx_dv),
        .gmii_rx_er(phy_gmii_rx_er),
        .gmii_tx_clk(phy_gmii_gtx_clk),
        .mii_tx_clk(phy_gmii_tx_clk),
        .gmii_txd(phy_gmii_txd),
        .gmii_tx_en(phy_gmii_tx_en),
        .gmii_tx_er(phy_gmii_tx_er),

        /*
         * Statistics
         */
        .stat_clk(clk),
        .stat_rst(rst),
        .m_axis_stat(axis_eth_stat[0]),

        /*
         * Status
         */
        .tx_error_underflow(),
        .tx_fifo_overflow(),
        .tx_fifo_bad_frame(),
        .tx_fifo_good_frame(),
        .rx_error_bad_frame(),
        .rx_error_bad_fcs(),
        .rx_fifo_overflow(),
        .rx_fifo_bad_frame(),
        .rx_fifo_good_frame(),
        .link_speed(),

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len(16'd9218),
        .cfg_tx_ifg(8'd12),
        .cfg_tx_enable(1'b1),
        .cfg_rx_max_pkt_len(16'd9218),
        .cfg_rx_enable(1'b1)
    );

end else if (BASET_PHY_TYPE == "RGMII") begin : baset_mac_rgmii

    taxi_eth_mac_1g_rgmii_fifo #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),
        .USE_CLK90(USE_CLK90),
        .PADDING_EN(1),
        .MIN_FRAME_LEN(64),
        .STAT_EN(1),
        .STAT_TX_LEVEL(1),
        .STAT_RX_LEVEL(1),
        .STAT_ID_BASE(0),
        .STAT_UPDATE_PERIOD(1024),
        .STAT_STR_EN(1),
        .STAT_PREFIX_STR("RGMII0"),
        .TX_FIFO_DEPTH(16384),
        .TX_FRAME_FIFO(1),
        .RX_FIFO_DEPTH(16384),
        .RX_FRAME_FIFO(1)
    )
    eth_mac_inst (
        .gtx_clk(clk),
        .gtx_clk90(clk90),
        .gtx_rst(rst),
        .logic_clk(clk),
        .logic_rst(rst),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_eth),
        .m_axis_tx_cpl(axis_tx_cpl),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_eth),

        /*
         * RGMII interface
         */
        .rgmii_rx_clk(phy_rgmii_rx_clk),
        .rgmii_rxd(phy_rgmii_rxd),
        .rgmii_rx_ctl(phy_rgmii_rx_ctl),
        .rgmii_tx_clk(phy_rgmii_tx_clk),
        .rgmii_txd(phy_rgmii_txd),
        .rgmii_tx_ctl(phy_rgmii_tx_ctl),

        /*
         * Statistics
         */
        .stat_clk(clk),
        .stat_rst(rst),
        .m_axis_stat(axis_eth_stat[0]),

        /*
         * Status
         */
        .tx_error_underflow(),
        .tx_fifo_overflow(),
        .tx_fifo_bad_frame(),
        .tx_fifo_good_frame(),
        .rx_error_bad_frame(),
        .rx_error_bad_fcs(),
        .rx_fifo_overflow(),
        .rx_fifo_bad_frame(),
        .rx_fifo_good_frame(),
        .link_speed(),

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len(16'd9218),
        .cfg_tx_ifg(8'd12),
        .cfg_tx_enable(1'b1),
        .cfg_rx_max_pkt_len(16'd9218),
        .cfg_rx_enable(1'b1)
    );

    assign phy_gmii_gtx_clk = 1'b0;
    assign phy_gmii_txd = '0;
    assign phy_gmii_tx_en = 1'b0;
    assign phy_gmii_tx_er = 1'b0;

end

// SFP+
assign sfp_tx_disable_b = 1'b1;

wire sfp_tx_clk[1];
wire sfp_tx_rst[1];
wire sfp_rx_clk[1];
wire sfp_rx_rst[1];

wire sfp_rx_status[1];

wire sfp_gtpowergood;

wire sfp_mgt_refclk;
wire sfp_mgt_refclk_bufg;

wire sfp_rst;

taxi_axis_if #(.DATA_W(32), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_tx[1]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl[1]();
taxi_axis_if #(.DATA_W(32), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_rx[1]();

if (SIM) begin

    assign sfp_mgt_refclk = sfp_mgt_refclk_p;
    assign sfp_mgt_refclk_bufg = sfp_mgt_refclk;

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
    .rst(rst),
    .out(sfp_rst)
);

// synthesis translate_off
`define SIM
// synthesis translate_on

taxi_apb_if #(
    .ADDR_W(18),
    .DATA_W(16)
)
gt_apb_ctrl();

taxi_xfcp_mod_apb #(
    .XFCP_EXT_ID_STR("GTX CTRL")
)
xfcp_mod_apb_inst (
    .clk(clk),
    .rst(rst),

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

    .CNT(1),

    // GT config
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

    // GT type
    .GT_TYPE("GTX"),

    // GT parameters
    // workaround for verilator bug
    `ifndef SIM
    .GT_TX_DIFFCTRL('{1{5'd8}}),
    .GT_TX_POLARITY('{1{SFP_INVERT}}),
    .GT_RX_POLARITY('{1{SFP_INVERT}}),
    `endif

    // MAC/PHY config
    .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
    .DATA_W(MAC_DATA_W),
    .PADDING_EN(1'b1),
    .DIC_EN(1'b1),
    .MIN_FRAME_LEN(64),
    .PTP_TS_EN(1'b0),
    .PTP_TS_FMT_TOD(1'b1),
    .PTP_TS_W(96),
    .PRBS31_EN(1'b0),
    .TX_SERDES_PIPELINE(1),
    .RX_SERDES_PIPELINE(1),
    .COUNT_125US(125000/6.4),
    .STAT_EN(1),
    .STAT_TX_LEVEL(1),
    .STAT_RX_LEVEL(1),
    .STAT_ID_BASE(16+16),
    .STAT_UPDATE_PERIOD(1024)
    // workaround for verilator bug
    `ifndef SIM
    ,
    .STAT_STR_EN(1),
    .STAT_PREFIX_STR('{"SFP"})
    `endif
)
sfp_mac_inst (
    .xcvr_ctrl_clk(clk),
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
    .xcvr_txp('{sfp_tx_p}),
    .xcvr_txn('{sfp_tx_n}),
    .xcvr_rxp('{sfp_rx_p}),
    .xcvr_rxn('{sfp_rx_n}),

    /*
     * MAC clocks
     */
    .rx_clk(sfp_rx_clk),
    .rx_rst_in('{1{1'b0}}),
    .rx_rst_out(sfp_rx_rst),
    .tx_clk(sfp_tx_clk),
    .tx_rst_in('{1{1'b0}}),
    .tx_rst_out(sfp_tx_rst),
    .ptp_sample_clk('{1{1'b0}}),

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
     * PTP clock
     */
    .tx_ptp_ts('{1{'0}}),
    .tx_ptp_ts_step('{1{1'b0}}),
    .rx_ptp_ts('{1{'0}}),
    .rx_ptp_ts_step('{1{1'b0}}),

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    .tx_lfc_req('{1{1'b0}}),
    .tx_lfc_resend('{1{1'b0}}),
    .rx_lfc_en('{1{1'b0}}),
    .rx_lfc_req(),
    .rx_lfc_ack('{1{1'b0}}),

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    .tx_pfc_req('{1{'0}}),
    .tx_pfc_resend('{1{1'b0}}),
    .rx_pfc_en('{1{'0}}),
    .rx_pfc_req(),
    .rx_pfc_ack('{1{'0}}),

    /*
     * Pause interface
     */
    .tx_lfc_pause_en('{1{1'b0}}),
    .tx_pause_req('{1{1'b0}}),
    .tx_pause_ack(),

    /*
     * Statistics
     */
    .stat_clk(clk),
    .stat_rst(rst),
    .m_axis_stat(axis_eth_stat[1]),

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
    .stat_rx_fifo_drop('{1{1'b0}}),
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
    .cfg_tx_max_pkt_len('{1{16'd9218}}),
    .cfg_tx_ifg('{1{8'd12}}),
    .cfg_tx_enable('{1{1'b1}}),
    .cfg_rx_max_pkt_len('{1{16'd9218}}),
    .cfg_rx_enable('{1{1'b1}}),
    .cfg_tx_prbs31_enable('{1{1'b0}}),
    .cfg_rx_prbs31_enable('{1{1'b0}}),
    .cfg_mcf_rx_eth_dst_mcast('{1{48'h01_80_C2_00_00_01}}),
    .cfg_mcf_rx_check_eth_dst_mcast('{1{1'b1}}),
    .cfg_mcf_rx_eth_dst_ucast('{1{48'd0}}),
    .cfg_mcf_rx_check_eth_dst_ucast('{1{1'b0}}),
    .cfg_mcf_rx_eth_src('{1{48'd0}}),
    .cfg_mcf_rx_check_eth_src('{1{1'b0}}),
    .cfg_mcf_rx_eth_type('{1{16'h8808}}),
    .cfg_mcf_rx_opcode_lfc('{1{16'h0001}}),
    .cfg_mcf_rx_check_opcode_lfc('{1{1'b1}}),
    .cfg_mcf_rx_opcode_pfc('{1{16'h0101}}),
    .cfg_mcf_rx_check_opcode_pfc('{1{1'b1}}),
    .cfg_mcf_rx_forward('{1{1'b0}}),
    .cfg_mcf_rx_enable('{1{1'b0}}),
    .cfg_tx_lfc_eth_dst('{1{48'h01_80_C2_00_00_01}}),
    .cfg_tx_lfc_eth_src('{1{48'h80_23_31_43_54_4C}}),
    .cfg_tx_lfc_eth_type('{1{16'h8808}}),
    .cfg_tx_lfc_opcode('{1{16'h0001}}),
    .cfg_tx_lfc_en('{1{1'b0}}),
    .cfg_tx_lfc_quanta('{1{16'hffff}}),
    .cfg_tx_lfc_refresh('{1{16'h7fff}}),
    .cfg_tx_pfc_eth_dst('{1{48'h01_80_C2_00_00_01}}),
    .cfg_tx_pfc_eth_src('{1{48'h80_23_31_43_54_4C}}),
    .cfg_tx_pfc_eth_type('{1{16'h8808}}),
    .cfg_tx_pfc_opcode('{1{16'h0101}}),
    .cfg_tx_pfc_en('{1{1'b0}}),
    .cfg_tx_pfc_quanta('{1{'{8{16'hffff}}}}),
    .cfg_tx_pfc_refresh('{1{'{8{16'h7fff}}}}),
    .cfg_rx_lfc_opcode('{1{16'h0001}}),
    .cfg_rx_lfc_en('{1{1'b0}}),
    .cfg_rx_pfc_opcode('{1{16'h0101}}),
    .cfg_rx_pfc_en('{1{1'b0}})
);

for (genvar n = 0; n < 1; n = n + 1) begin : sfp_ch

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
