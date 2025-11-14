// SPDX-License-Identifier: MIT
/*

Copyright (c) 2025 FPGA Ninja, LLC

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
    parameter string FAMILY = "zynquplus",
    // Use 90 degree clock for RGMII transmit
    parameter logic USE_CLK90 = 1'b1,
    // SFP rate selection (0 for 1G, 1 for 10G)
    parameter logic SFP_RATE = 1'b1
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
    output wire logic [1:0]  led,
    output wire logic [1:0]  sfp_led,

    /*
     * Ethernet: 1000BASE-T
     */
    input  wire logic        phy2_rgmii_rx_clk,
    input  wire logic [3:0]  phy2_rgmii_rxd,
    input  wire logic        phy2_rgmii_rx_ctl,
    output wire logic        phy2_rgmii_tx_clk,
    output wire logic [3:0]  phy2_rgmii_txd,
    output wire logic        phy2_rgmii_tx_ctl,
    output wire logic        phy2_reset_n,

    input  wire logic        phy3_rgmii_rx_clk,
    input  wire logic [3:0]  phy3_rgmii_rxd,
    input  wire logic        phy3_rgmii_rx_ctl,
    output wire logic        phy3_rgmii_tx_clk,
    output wire logic [3:0]  phy3_rgmii_txd,
    output wire logic        phy3_rgmii_tx_ctl,
    output wire logic        phy3_reset_n,

    /*
     * Ethernet: SFP+
     */
    input  wire logic        sfp_rx_p,
    input  wire logic        sfp_rx_n,
    output wire logic        sfp_tx_p,
    output wire logic        sfp_tx_n,
    input  wire logic        sfp_mgt_refclk_p,
    input  wire logic        sfp_mgt_refclk_n,

    input  wire logic        sfp_gmii_clk,
    input  wire logic        sfp_gmii_rst,
    input  wire logic        sfp_gmii_clk_en,
    input  wire logic [7:0]  sfp_gmii_rxd,
    input  wire logic        sfp_gmii_rx_dv,
    input  wire logic        sfp_gmii_rx_er,
    output wire logic [7:0]  sfp_gmii_txd,
    output wire logic        sfp_gmii_tx_en,
    output wire logic        sfp_gmii_tx_er,

    output wire logic        sfp_tx_disable,
    input  wire logic        sfp_tx_fault,
    input  wire logic        sfp_rx_los,
    input  wire logic        sfp_mod_abs,

    input  wire logic        sfp_i2c_scl_i,
    output wire logic        sfp_i2c_scl_o,
    output wire logic        sfp_i2c_scl_t,
    input  wire logic        sfp_i2c_sda_i,
    output wire logic        sfp_i2c_sda_o,
    output wire logic        sfp_i2c_sda_t
);

// BASE-T PHY
assign phy2_reset_n = !rst;
assign phy3_reset_n = !rst;

taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_phy2_eth();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_phy2_tx_cpl();
taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_phy2_stat();

taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_phy3_eth();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_phy3_tx_cpl();
taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_phy3_stat();

taxi_eth_mac_1g_rgmii_fifo #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .USE_CLK90(USE_CLK90),
    .PADDING_EN(1),
    .MIN_FRAME_LEN(64),
    .STAT_EN(1'b0),
    .TX_FIFO_DEPTH(16384),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(16384),
    .RX_FRAME_FIFO(1)
)
phy2_eth_mac_inst (
    .gtx_clk(clk),
    .gtx_clk90(clk90),
    .gtx_rst(rst),
    .logic_clk(clk),
    .logic_rst(rst),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_phy2_eth),
    .m_axis_tx_cpl(axis_phy2_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_phy2_eth),

    /*
     * RGMII interface
     */
    .rgmii_rx_clk(phy2_rgmii_rx_clk),
    .rgmii_rxd(phy2_rgmii_rxd),
    .rgmii_rx_ctl(phy2_rgmii_rx_ctl),
    .rgmii_tx_clk(phy2_rgmii_tx_clk),
    .rgmii_txd(phy2_rgmii_txd),
    .rgmii_tx_ctl(phy2_rgmii_tx_ctl),

    /*
     * Statistics
     */
    .stat_clk(clk),
    .stat_rst(rst),
    .m_axis_stat(axis_phy2_stat),

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

taxi_eth_mac_1g_rgmii_fifo #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .USE_CLK90(USE_CLK90),
    .PADDING_EN(1),
    .MIN_FRAME_LEN(64),
    .STAT_EN(1'b0),
    .TX_FIFO_DEPTH(16384),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(16384),
    .RX_FRAME_FIFO(1)
)
phy3_eth_mac_inst (
    .gtx_clk(clk),
    .gtx_clk90(clk90),
    .gtx_rst(rst),
    .logic_clk(clk),
    .logic_rst(rst),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_phy3_eth),
    .m_axis_tx_cpl(axis_phy3_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_phy3_eth),

    /*
     * RGMII interface
     */
    .rgmii_rx_clk(phy3_rgmii_rx_clk),
    .rgmii_rxd(phy3_rgmii_rxd),
    .rgmii_rx_ctl(phy3_rgmii_rx_ctl),
    .rgmii_tx_clk(phy3_rgmii_tx_clk),
    .rgmii_txd(phy3_rgmii_txd),
    .rgmii_tx_ctl(phy3_rgmii_tx_ctl),

    /*
     * Statistics
     */
    .stat_clk(clk),
    .stat_rst(rst),
    .m_axis_stat(axis_phy3_stat),

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

// SFP+
assign sfp_tx_disable = 1'b0;

if (SFP_RATE == 0) begin : sfp_mac

    taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_eth();
    taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl();
    taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_sfp_stat();

    taxi_eth_mac_1g_fifo #(
        .PADDING_EN(1),
        .MIN_FRAME_LEN(64),
        .STAT_EN(1'b0),
        .TX_FIFO_DEPTH(16384),
        .TX_FRAME_FIFO(1),
        .RX_FIFO_DEPTH(16384),
        .RX_FRAME_FIFO(1)
    )
    sfp_eth_mac_inst (
        .rx_clk(sfp_gmii_clk),
        .rx_rst(sfp_gmii_rst),
        .tx_clk(sfp_gmii_clk),
        .tx_rst(sfp_gmii_rst),
        .logic_clk(clk),
        .logic_rst(rst),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_sfp_eth),
        .m_axis_tx_cpl(axis_sfp_tx_cpl),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_sfp_eth),

        /*
         * GMII interface
         */
        .gmii_rxd(sfp_gmii_rxd),
        .gmii_rx_dv(sfp_gmii_rx_dv),
        .gmii_rx_er(sfp_gmii_rx_er),
        .gmii_txd(sfp_gmii_txd),
        .gmii_tx_en(sfp_gmii_tx_en),
        .gmii_tx_er(sfp_gmii_tx_er),

        /*
         * Control
         */
        .rx_clk_enable(sfp_gmii_clk_en),
        .tx_clk_enable(sfp_gmii_clk_en),
        .rx_mii_select(1'b0),
        .tx_mii_select(1'b0),

        /*
         * Statistics
         */
        .stat_clk(clk),
        .stat_rst(rst),
        .m_axis_stat(axis_sfp_stat),

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

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len(16'd9218),
        .cfg_tx_ifg(8'd12),
        .cfg_tx_enable(1'b1),
        .cfg_rx_max_pkt_len(16'd9218),
        .cfg_rx_enable(1'b1)
    );

end else begin : sfp_mac

    wire sfp_tx_clk[1];
    wire sfp_tx_rst[1];
    wire sfp_rx_clk[1];
    wire sfp_rx_rst[1];

    wire sfp_rx_status[1];

    wire sfp_gtpowergood;

    wire sfp_mgt_refclk;
    wire sfp_mgt_refclk_int;
    wire sfp_mgt_refclk_bufg;

    wire sfp_rst;

    taxi_axis_if #(.DATA_W(32), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_tx[1]();
    taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl[1]();
    taxi_axis_if #(.DATA_W(32), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_rx[1]();
    taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_sfp_stat();

    if (SIM) begin

        assign sfp_mgt_refclk = sfp_mgt_refclk_p;
        assign sfp_mgt_refclk_int = sfp_mgt_refclk_p;
        assign sfp_mgt_refclk_bufg = sfp_mgt_refclk_int;

    end else begin

        IBUFDS_GTE4 ibufds_gte3_sfp_mgt_refclk_inst (
            .I     (sfp_mgt_refclk_p),
            .IB    (sfp_mgt_refclk_n),
            .CEB   (1'b0),
            .O     (sfp_mgt_refclk),
            .ODIV2 (sfp_mgt_refclk_int)
        );

        BUFG_GT bufg_gt_sfp_mgt_refclk_inst (
            .CE      (sfp_gtpowergood),
            .CEMASK  (1'b1),
            .CLR     (1'b0),
            .CLRMASK (1'b1),
            .DIV     (3'd0),
            .I       (sfp_mgt_refclk_int),
            .O       (sfp_mgt_refclk_bufg)
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

    taxi_apb_if #(
        .ADDR_W(18),
        .DATA_W(16)
    )
    gt_apb_ctrl();

    taxi_eth_mac_25g_us #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .CNT(1),

        // GT config
        .CFG_LOW_LATENCY(1),

        // GT type
        .GT_TYPE("GTH"),

        // PHY parameters
        .DATA_W(axis_sfp_tx[0].DATA_W),
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
        .STAT_EN(1'b0)
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
        .m_axis_stat(axis_sfp_stat),

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
    sfp_mac_fifo (
        /*
         * AXI4-Stream input (sink)
         */
        .s_clk(sfp_rx_clk[0]),
        .s_rst(sfp_rx_rst[0]),
        .s_axis(axis_sfp_rx[0]),

        /*
         * AXI4-Stream output (source)
         */
        .m_clk(sfp_tx_clk[0]),
        .m_rst(sfp_tx_rst[0]),
        .m_axis(axis_sfp_tx[0]),

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
