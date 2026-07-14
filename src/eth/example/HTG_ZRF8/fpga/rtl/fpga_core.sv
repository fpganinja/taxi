// SPDX-License-Identifier: MIT
/*

Copyright (c) 2021-2025 FPGA Ninja, LLC

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
    parameter string FAMILY = "zynquplusRFSOC",
    // Board configuration
    parameter PORT_CNT = 2,
    parameter GTY_QUAD_CNT = PORT_CNT,
    parameter GTY_CNT = GTY_QUAD_CNT*4,
    parameter GTY_CLK_CNT = GTY_QUAD_CNT,
    parameter ADC_CNT = 8,
    parameter DAC_CNT = ADC_CNT,
    // 10G/25G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
)
(
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire logic                    clk_125mhz,
    input  wire logic                    rst_125mhz,
    input  wire logic                    fpga_refclk,
    input  wire logic                    fpga_sysref,

    /*
     * GPIO
     */
    input  wire logic [3:0]              sw,
    output wire logic [3:0]              led,
    output wire logic [7:0]              gpio,

    /*
     * I2C for board management
     */
    input  wire logic                    i2c_scl_i,
    output wire logic                    i2c_scl_o,
    input  wire logic                    i2c_sda_i,
    output wire logic                    i2c_sda_o,

    /*
     * UART: 921600 bps, 8N1
     */
    output wire logic                    uart_rxd,
    input  wire logic                    uart_txd,
    input  wire logic                    uart_rts,
    output wire logic                    uart_cts,
    output wire logic                    uart_rst_n,
    input  wire logic                    uart_suspend_n,

    /*
     * Ethernet: QSFP28
     */
    output wire logic                    eth_gty_tx_p[GTY_CNT],
    output wire logic                    eth_gty_tx_n[GTY_CNT],
    input  wire logic                    eth_gty_rx_p[GTY_CNT],
    input  wire logic                    eth_gty_rx_n[GTY_CNT],
    input  wire logic                    eth_gty_mgt_refclk_p[GTY_CLK_CNT],
    input  wire logic                    eth_gty_mgt_refclk_n[GTY_CLK_CNT],
    output wire logic                    eth_gty_mgt_refclk_out[GTY_CLK_CNT],

    output wire logic [PORT_CNT-1:0]     eth_port_resetl,
    input  wire logic [PORT_CNT-1:0]     eth_port_modprsl,
    input  wire logic [PORT_CNT-1:0]     eth_port_intl,

    /*
     * RFDC
     */
    input  wire logic                    axil_rfdc_clk,
    input  wire logic                    axil_rfdc_rst,
    taxi_axil_if.wr_mst                  m_axil_rfdc_wr,
    taxi_axil_if.rd_mst                  m_axil_rfdc_rd,

    input  wire logic                    axis_rfdc_clk,
    input  wire logic                    axis_rfdc_rst,
    taxi_axis_if.snk                     s_axis_adc[ADC_CNT],
    taxi_axis_if.src                     m_axis_dac[DAC_CNT]
);

// XFCP
taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_ds(), xfcp_us();

assign uart_cts = 1'b1;
assign uart_rst_n = 1'b1;

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
    .uart_rxd(uart_txd),
    .uart_txd(uart_rxd),

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

localparam XFCP_PORTS = 3+GTY_QUAD_CNT;

taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_sw_ds[XFCP_PORTS](), xfcp_sw_us[XFCP_PORTS]();

taxi_xfcp_switch #(
    .XFCP_ID_STR("HTG-ZRF8"),
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

// Statistics
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

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(axis_stat.ID_W)) axis_eth_stat[GTY_QUAD_CNT]();

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
    .DEFAULT_PRESCALE(16'(125000000/400000/4))
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

// RFDC control
taxi_xfcp_mod_axil #(
    .XFCP_ID_STR("RFDC"),
    .COUNT_SIZE(16)
)
xfcp_mod_axil_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_sw_ds[2]),
    .xfcp_usp_us(xfcp_sw_us[2]),

    /*
     * AXI lite master interface
     */
    .m_axil_wr(m_axil_rfdc_wr),
    .m_axil_rd(m_axil_rfdc_rd)
);

// Ethernet
wire eth_reset = SIM ? 1'b0 : rst_125mhz;
assign eth_port_resetl = {PORT_CNT{~eth_reset}};

wire eth_gty_tx_clk[GTY_CNT];
wire eth_gty_tx_rst[GTY_CNT];
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) eth_gty_axis_tx[GTY_CNT]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) eth_gty_axis_tx_cpl[GTY_CNT]();

wire eth_gty_rx_clk[GTY_CNT];
wire eth_gty_rx_rst[GTY_CNT];
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) eth_gty_axis_rx[GTY_CNT]();

wire eth_gty_rx_status[GTY_CNT];

wire [GTY_QUAD_CNT-1:0] eth_gty_gtpowergood;

wire eth_gty_mgt_refclk[GTY_CLK_CNT];
wire eth_gty_mgt_refclk_bufg[GTY_CLK_CNT];

wire eth_gty_rst[GTY_CLK_CNT];

for (genvar n = 0; n < GTY_CLK_CNT; n = n + 1) begin : gty_clk

    wire eth_gty_mgt_refclk_int;

    if (SIM) begin

        assign eth_gty_mgt_refclk[n] = eth_gty_mgt_refclk_p[n];
        assign eth_gty_mgt_refclk_int = eth_gty_mgt_refclk_p[n];
        assign eth_gty_mgt_refclk_bufg[n] = eth_gty_mgt_refclk_int;

    end else begin

        IBUFDS_GTE4 ibufds_gte4_eth_gty_mgt_refclk_inst (
            .I     (eth_gty_mgt_refclk_p[n]),
            .IB    (eth_gty_mgt_refclk_n[n]),
            .CEB   (1'b0),
            .O     (eth_gty_mgt_refclk[n]),
            .ODIV2 (eth_gty_mgt_refclk_int)
        );

        BUFG_GT bufg_gt_eth_gty_mgt_refclk_inst (
            .CE      (&eth_gty_gtpowergood),
            .CEMASK  (1'b1),
            .CLR     (1'b0),
            .CLRMASK (1'b1),
            .DIV     (3'd0),
            .I       (eth_gty_mgt_refclk_int),
            .O       (eth_gty_mgt_refclk_bufg[n])
        );

    end

    assign eth_gty_mgt_refclk_out[n] = eth_gty_mgt_refclk_bufg[n];

    taxi_sync_reset #(
        .N(4)
    )
    qsfp_sync_reset_inst (
        .clk(eth_gty_mgt_refclk_bufg[n]),
        .rst(rst_125mhz || eth_reset),
        .out(eth_gty_rst[n])
    );

end

localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP1[4] = '{"QSFP1.1", "QSFP1.2", "QSFP1.3",  "QSFP1.4"};
localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP2[4] = '{"QSFP2.1", "QSFP2.2", "QSFP2.3",  "QSFP2.4"};

for (genvar n = 0; n < GTY_QUAD_CNT; n = n + 1) begin : gty_quad

    localparam CLK = n;
    localparam CNT = 4;

    taxi_apb_if #(
        .ADDR_W(18),
        .DATA_W(16)
    )
    gt_apb_ctrl();

    taxi_xfcp_mod_apb #(
        .XFCP_EXT_ID_STR("GTY CTRL")
    )
    xfcp_mod_apb_inst (
        .clk(clk_125mhz),
        .rst(rst_125mhz),

        /*
         * XFCP upstream port
         */
        .xfcp_usp_ds(xfcp_sw_ds[n+3]),
        .xfcp_usp_us(xfcp_sw_us[n+3]),

        /*
         * APB master interface
         */
        .m_apb(gt_apb_ctrl)
    );

    taxi_eth_mac_25g_us #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .CNT(CNT),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE("GTY"),

        // MAC/PHY config
        .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
        .DATA_W(eth_gty_axis_tx[0].DATA_W),
        .USXGMII_EN(COMBINED_MAC_PCS && eth_gty_axis_tx[0].DATA_W == 32),
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
        .STAT_ID_BASE(n*CNT*(16+16)),
        .STAT_UPDATE_PERIOD(1024),
        .STAT_STR_EN(1),
        .STAT_PREFIX_STR(
            n == 0 ? STAT_PREFIX_STR_QSFP1 :
            STAT_PREFIX_STR_QSFP2
        )
    )
    mac_inst (
        .xcvr_ctrl_clk(clk_125mhz),
        .xcvr_ctrl_rst(eth_gty_rst[CLK]),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(gt_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(eth_gty_gtpowergood[n]),
        .xcvr_gtrefclk00_in(eth_gty_mgt_refclk[CLK]),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'd0),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(eth_gty_mgt_refclk[CLK]),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'd0),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        /*
         * Serial data
         */
        .xcvr_txp(eth_gty_tx_p[n*CNT +: CNT]),
        .xcvr_txn(eth_gty_tx_n[n*CNT +: CNT]),
        .xcvr_rxp(eth_gty_rx_p[n*CNT +: CNT]),
        .xcvr_rxn(eth_gty_rx_n[n*CNT +: CNT]),

        /*
         * MAC clocks
         */
        .rx_clk(eth_gty_rx_clk[n*CNT +: CNT]),
        .rx_rst_in('{CNT{1'b0}}),
        .rx_rst_out(eth_gty_rx_rst[n*CNT +: CNT]),
        .tx_clk(eth_gty_tx_clk[n*CNT +: CNT]),
        .tx_rst_in('{CNT{1'b0}}),
        .tx_rst_out(eth_gty_tx_rst[n*CNT +: CNT]),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(eth_gty_axis_tx[n*CNT +: CNT]),
        .m_axis_tx_cpl(eth_gty_axis_tx_cpl[n*CNT +: CNT]),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(eth_gty_axis_rx[n*CNT +: CNT]),

        /*
         * USXGMII autonegotiation
         */
        .an_en('{CNT{1'b1}}),
        .an_restart('{CNT{1'b0}}),
        .an_speedup('{CNT{1'b0}}),
        .an_timeout_en('{CNT{1'b1}}),
        .an_usxgmii_en('{CNT{1'b0}}),
        .an_usxgmii_auto('{CNT{1'b1}}),
        .an_intr(),
        .an_running(),
        .an_complete(),
        .an_timeout(),
        .an_usxgmii_mode(),
        .an_adv_ability_usxgmii('{CNT{16'h1601}}),
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
        .tx_ptp_ts_in('{CNT{'0}}),
        .tx_ptp_ts_out(),
        .tx_ptp_ts_step_out(),
        .tx_ptp_locked(),
        .rx_ptp_ts_in('{CNT{'0}}),
        .rx_ptp_ts_out(),
        .rx_ptp_ts_step_out(),
        .rx_ptp_locked(),

        /*
         * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
         */
        .tx_lfc_req('{CNT{1'b0}}),
        .tx_lfc_resend('{CNT{1'b0}}),
        .rx_lfc_en('{CNT{1'b0}}),
        .rx_lfc_req(),
        .rx_lfc_ack('{CNT{1'b0}}),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
         */
        .tx_pfc_req('{CNT{'0}}),
        .tx_pfc_resend('{CNT{1'b0}}),
        .rx_pfc_en('{CNT{'0}}),
        .rx_pfc_req(),
        .rx_pfc_ack('{CNT{'0}}),

        /*
         * Pause interface
         */
        .tx_lfc_pause_en('{CNT{1'b0}}),
        .tx_pause_req('{CNT{1'b0}}),
        .tx_pause_ack(),

        /*
         * Statistics
         */
        .stat_clk(clk_125mhz),
        .stat_rst(rst_125mhz),
        .m_axis_stat(axis_eth_stat[n]),

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
        .rx_status(eth_gty_rx_status[n*CNT +: CNT]),
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
        .stat_rx_fifo_drop('{CNT{1'b0}}),
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
        .cfg_tx_pad_en('{CNT{1'b1}}),
        .cfg_tx_min_pkt_len('{CNT{8'd60-1}}),
        .cfg_tx_max_pkt_len('{CNT{16'd9218-1}}),
        .cfg_tx_ifg('{CNT{8'd12}}),
        .cfg_tx_enable('{CNT{1'b1}}),
        .cfg_rx_max_pkt_len('{CNT{16'd9218-1}}),
        .cfg_rx_enable('{CNT{1'b1}}),
        .cfg_tx_prbs31_enable('{CNT{1'b0}}),
        .cfg_rx_prbs31_enable('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_dst_mcast('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_mcf_rx_check_eth_dst_mcast('{CNT{1'b1}}),
        .cfg_mcf_rx_eth_dst_ucast('{CNT{48'd0}}),
        .cfg_mcf_rx_check_eth_dst_ucast('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_src('{CNT{48'd0}}),
        .cfg_mcf_rx_check_eth_src('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_type('{CNT{16'h8808}}),
        .cfg_mcf_rx_opcode_lfc('{CNT{16'h0001}}),
        .cfg_mcf_rx_check_opcode_lfc('{CNT{1'b1}}),
        .cfg_mcf_rx_opcode_pfc('{CNT{16'h0101}}),
        .cfg_mcf_rx_check_opcode_pfc('{CNT{1'b1}}),
        .cfg_mcf_rx_forward('{CNT{1'b0}}),
        .cfg_mcf_rx_enable('{CNT{1'b0}}),
        .cfg_tx_lfc_eth_dst('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_tx_lfc_eth_src('{CNT{48'h80_23_31_43_54_4C}}),
        .cfg_tx_lfc_eth_type('{CNT{16'h8808}}),
        .cfg_tx_lfc_opcode('{CNT{16'h0001}}),
        .cfg_tx_lfc_en('{CNT{1'b0}}),
        .cfg_tx_lfc_quanta('{CNT{16'hffff}}),
        .cfg_tx_lfc_refresh('{CNT{16'h7fff}}),
        .cfg_tx_pfc_eth_dst('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_tx_pfc_eth_src('{CNT{48'h80_23_31_43_54_4C}}),
        .cfg_tx_pfc_eth_type('{CNT{16'h8808}}),
        .cfg_tx_pfc_opcode('{CNT{16'h0101}}),
        .cfg_tx_pfc_en('{CNT{1'b0}}),
        .cfg_tx_pfc_quanta('{CNT{'{8{16'hffff}}}}),
        .cfg_tx_pfc_refresh('{CNT{'{8{16'h7fff}}}}),
        .cfg_rx_lfc_opcode('{CNT{16'h0001}}),
        .cfg_rx_lfc_en('{CNT{1'b0}}),
        .cfg_rx_pfc_opcode('{CNT{16'h0101}}),
        .cfg_rx_pfc_en('{CNT{1'b0}})
    );

end

for (genvar n = 0; n < GTY_CNT; n = n + 1) begin : gty_ch

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
        .s_clk(eth_gty_rx_clk[n]),
        .s_rst(eth_gty_rx_rst[n]),
        .s_axis(eth_gty_axis_rx[n]),

        /*
         * AXI4-Stream output (source)
         */
        .m_clk(eth_gty_tx_clk[n]),
        .m_rst(eth_gty_tx_rst[n]),
        .m_axis(eth_gty_axis_tx[n]),

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

for (genvar n = 0; n < ADC_CNT; n = n + 1) begin : rfdc_lpbk

    assign m_axis_dac[n].tdata = s_axis_adc[n].tdata;
    assign m_axis_dac[n].tvalid = s_axis_adc[n].tvalid;
    assign s_axis_adc[n].tready = m_axis_dac[n].tready;

end

endmodule

`resetall
