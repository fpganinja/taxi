// SPDX-License-Identifier: MIT
/*

Copyright (c) 2014-2026 FPGA Ninja, LLC

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
    parameter string FAMILY = "artixuplus"
)
(
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire logic        clk_125mhz,
    input  wire logic        rst_125mhz,

    /*
     * GPIO
     */
    output wire logic [5:0]  led,

    /*
     * Ethernet: SFP+
     */
    input  wire logic        sfp_rx_p[2],
    input  wire logic        sfp_rx_n[2],
    output wire logic        sfp_tx_p[2],
    output wire logic        sfp_tx_n[2],
    // input  wire logic        sfp_mgt_refclk_0_p,
    // input  wire logic        sfp_mgt_refclk_0_n,
    // input  wire logic        sfp_mgt_refclk_1_p,
    // input  wire logic        sfp_mgt_refclk_1_n,
    input  wire logic        sfp_mgt_refclk_2_p,
    input  wire logic        sfp_mgt_refclk_2_n,

    output wire logic        sfp_tx_disable[2],
    input  wire logic        sfp_tx_fault[2],
    input  wire logic        sfp_npres[2],
    input  wire logic        sfp_los[2],
    output wire logic [1:0]  sfp_rs[2]
);

// SFP+
assign sfp_tx_disable = '{2{1'b0}};
assign sfp_rs = '{2{2'b11}};

wire sfp_tx_clk[2];
wire sfp_tx_rst[2];
wire sfp_rx_clk[2];
wire sfp_rx_rst[2];

wire sfp_rx_status[2];

assign led[0] = sfp_rx_status[0];
assign led[1] = sfp_rx_status[1];
assign led[2] = 1'b0;
assign led[3] = 1'b0;
assign led[4] = 1'b0;
assign led[5] = 1'b0;

wire sfp_gtpowergood;

wire sfp_mgt_refclk_2;
wire sfp_mgt_refclk_2_int;
wire sfp_mgt_refclk_2_bufg;

wire sfp_rst;

taxi_axis_if #(.DATA_W(32), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_tx[2]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl[2]();
taxi_axis_if #(.DATA_W(32), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_rx[2]();
taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_sfp_stat();

if (SIM) begin

    assign sfp_mgt_refclk_2 = sfp_mgt_refclk_2_p;
    assign sfp_mgt_refclk_2_int = sfp_mgt_refclk_2_p;
    assign sfp_mgt_refclk_2_bufg = sfp_mgt_refclk_2_int;

end else begin

    IBUFDS_GTE4 ibufds_gte4_sfp_mgt_refclk_2_inst (
        .I     (sfp_mgt_refclk_2_p),
        .IB    (sfp_mgt_refclk_2_n),
        .CEB   (1'b0),
        .O     (sfp_mgt_refclk_2),
        .ODIV2 (sfp_mgt_refclk_2_int)
    );

    BUFG_GT bufg_gt_sfp_mgt_refclk_2_inst (
        .CE      (sfp_gtpowergood),
        .CEMASK  (1'b1),
        .CLR     (1'b0),
        .CLRMASK (1'b1),
        .DIV     (3'd0),
        .I       (sfp_mgt_refclk_2_int),
        .O       (sfp_mgt_refclk_2_bufg)
    );

end

taxi_sync_reset #(
    .N(4)
)
sfp_sync_reset_inst (
    .clk(sfp_mgt_refclk_2_bufg),
    .rst(rst_125mhz),
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

    .CNT(2),

    // GT config
    .CFG_LOW_LATENCY(1),

    // GT type
    .GT_TYPE("GTY"),

    // PHY parameters
    .DATA_W(axis_sfp_tx[0].DATA_W),
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
    .STAT_EN(1'b0)
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
    .xcvr_gtrefclk00_in(sfp_mgt_refclk_2),
    .xcvr_qpll0pd_in(1'b0),
    .xcvr_qpll0reset_in(1'b0),
    .xcvr_qpll0pcierate_in(3'd0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(sfp_mgt_refclk_2),
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
    .rx_rst_in('{2{1'b0}}),
    .rx_rst_out(sfp_rx_rst),
    .tx_clk(sfp_tx_clk),
    .tx_rst_in('{2{1'b0}}),
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
    .an_en('{2{1'b1}}),
    .an_restart('{2{1'b0}}),
    .an_speedup('{2{1'b0}}),
    .an_timeout_en('{2{1'b1}}),
    .an_usxgmii_en('{2{1'b0}}),
    .an_usxgmii_auto('{2{1'b1}}),
    .an_intr(),
    .an_running(),
    .an_complete(),
    .an_timeout(),
    .an_usxgmii_mode(),
    .an_adv_ability_usxgmii('{2{16'h1601}}),
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
    .tx_ptp_ts_in('{2{'0}}),
    .tx_ptp_ts_out(),
    .tx_ptp_ts_step_out(),
    .tx_ptp_locked(),
    .rx_ptp_ts_in('{2{'0}}),
    .rx_ptp_ts_out(),
    .rx_ptp_ts_step_out(),
    .rx_ptp_locked(),

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    .tx_lfc_req('{2{1'b0}}),
    .tx_lfc_resend('{2{1'b0}}),
    .rx_lfc_en('{2{1'b0}}),
    .rx_lfc_req(),
    .rx_lfc_ack('{2{1'b0}}),

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    .tx_pfc_req('{2{'0}}),
    .tx_pfc_resend('{2{1'b0}}),
    .rx_pfc_en('{2{'0}}),
    .rx_pfc_req(),
    .rx_pfc_ack('{2{'0}}),

    /*
     * Pause interface
     */
    .tx_lfc_pause_en('{2{1'b0}}),
    .tx_pause_req('{2{1'b0}}),
    .tx_pause_ack(),

    /*
     * Statistics
     */
    .stat_clk(clk_125mhz),
    .stat_rst(rst_125mhz),
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
    .stat_rx_fifo_drop('{2{1'b0}}),
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
    .cfg_tx_pad_en('{2{1'b1}}),
    .cfg_tx_min_pkt_len('{2{8'd60-1}}),
    .cfg_tx_max_pkt_len('{2{16'd9218-1}}),
    .cfg_tx_ifg('{2{8'd12}}),
    .cfg_tx_enable('{2{1'b1}}),
    .cfg_rx_max_pkt_len('{2{16'd9218-1}}),
    .cfg_rx_enable('{2{1'b1}}),
    .cfg_tx_prbs31_enable('{2{1'b0}}),
    .cfg_rx_prbs31_enable('{2{1'b0}}),
    .cfg_mcf_rx_eth_dst_mcast('{2{48'h01_80_C2_00_00_01}}),
    .cfg_mcf_rx_check_eth_dst_mcast('{2{1'b1}}),
    .cfg_mcf_rx_eth_dst_ucast('{2{48'd0}}),
    .cfg_mcf_rx_check_eth_dst_ucast('{2{1'b0}}),
    .cfg_mcf_rx_eth_src('{2{48'd0}}),
    .cfg_mcf_rx_check_eth_src('{2{1'b0}}),
    .cfg_mcf_rx_eth_type('{2{16'h8808}}),
    .cfg_mcf_rx_opcode_lfc('{2{16'h0001}}),
    .cfg_mcf_rx_check_opcode_lfc('{2{1'b1}}),
    .cfg_mcf_rx_opcode_pfc('{2{16'h0101}}),
    .cfg_mcf_rx_check_opcode_pfc('{2{1'b1}}),
    .cfg_mcf_rx_forward('{2{1'b0}}),
    .cfg_mcf_rx_enable('{2{1'b0}}),
    .cfg_tx_lfc_eth_dst('{2{48'h01_80_C2_00_00_01}}),
    .cfg_tx_lfc_eth_src('{2{48'h80_23_31_43_54_4C}}),
    .cfg_tx_lfc_eth_type('{2{16'h8808}}),
    .cfg_tx_lfc_opcode('{2{16'h0001}}),
    .cfg_tx_lfc_en('{2{1'b0}}),
    .cfg_tx_lfc_quanta('{2{16'hffff}}),
    .cfg_tx_lfc_refresh('{2{16'h7fff}}),
    .cfg_tx_pfc_eth_dst('{2{48'h01_80_C2_00_00_01}}),
    .cfg_tx_pfc_eth_src('{2{48'h80_23_31_43_54_4C}}),
    .cfg_tx_pfc_eth_type('{2{16'h8808}}),
    .cfg_tx_pfc_opcode('{2{16'h0101}}),
    .cfg_tx_pfc_en('{2{1'b0}}),
    .cfg_tx_pfc_quanta('{2{'{8{16'hffff}}}}),
    .cfg_tx_pfc_refresh('{2{'{8{16'h7fff}}}}),
    .cfg_rx_lfc_opcode('{2{16'h0001}}),
    .cfg_rx_lfc_en('{2{1'b0}}),
    .cfg_rx_pfc_opcode('{2{16'h0101}}),
    .cfg_rx_pfc_en('{2{1'b0}})
);

for (genvar n = 0; n < 2; n = n + 1) begin : sfp_ch

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
