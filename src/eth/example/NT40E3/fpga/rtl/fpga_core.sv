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
    output wire logic [3:0]  sfp_led,
    output wire logic [3:0]  led,
    output wire logic        led_red,
    output wire logic        led_green,
    output wire logic [1:0]  led_sync,

    /*
     * Ethernet: SFP+
     */
    input  wire logic        sfp_rx_p[4],
    input  wire logic        sfp_rx_n[4],
    output wire logic        sfp_tx_p[4],
    output wire logic        sfp_tx_n[4],
    input  wire logic        sfp_mgt_refclk_p[2],
    input  wire logic        sfp_mgt_refclk_n[2],

    input  wire logic        sfp_mod_abs[4],
    output wire logic [1:0]  sfp_rs[4],
    input  wire logic        sfp_los[4],
    output wire logic        sfp_tx_disable[4],
    input  wire logic        sfp_tx_fault[4]
);

// SFP+
assign sfp_tx_disable = '{4{1'b0}};

wire sfp_tx_clk[4];
wire sfp_tx_rst[4];
wire sfp_rx_clk[4];
wire sfp_rx_rst[4];

wire sfp_rx_status[4];

assign sfp_led[0] = sfp_rx_status[0];
assign sfp_led[1] = sfp_rx_status[1];
assign sfp_led[2] = sfp_rx_status[2];
assign sfp_led[3] = sfp_rx_status[3];

wire [1:0] sfp_gtpowergood;

taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_tx[4]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl[4]();
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_rx[4]();
taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_sfp_stat[2]();

wire sfp_mgt_refclk[2];
wire sfp_mgt_refclk_bufg[2];

wire sfp_rst[2];

for (genvar n = 0; n < 2; n = n + 1) begin : gty_clk

    wire sfp_mgt_refclk_int;

    if (SIM) begin

        assign sfp_mgt_refclk[n] = sfp_mgt_refclk_p[n];
        assign sfp_mgt_refclk_int = sfp_mgt_refclk_p[n];
        assign sfp_mgt_refclk_bufg[n] = sfp_mgt_refclk_int;

    end else begin

        IBUFDS_GTE2 ibufds_gte2_sfp_mgt_refclk_inst (
            .I     (sfp_mgt_refclk_p[n]),
            .IB    (sfp_mgt_refclk_n[n]),
            .CEB   (1'b0),
            .O     (sfp_mgt_refclk[n]),
            .ODIV2 (sfp_mgt_refclk_int)
        );

        BUFG bufg_sfp_mgt_refclk_inst (
            .I (sfp_mgt_refclk_int),
            .O (sfp_mgt_refclk_bufg[n])
        );

    end

    taxi_sync_reset #(
        .N(4)
    )
    sfp_sync_reset_inst (
        .clk(sfp_mgt_refclk_bufg[n]),
        .rst(rst_125mhz),
        .out(sfp_rst[n])
    );

end

for (genvar n = 0; n < 2; n = n + 1) begin : gt_quad

    localparam CLK = n;
    localparam CNT = 2;

    taxi_apb_if #(
        .ADDR_W(18),
        .DATA_W(16)
    )
    gt_apb_ctrl();

    taxi_eth_mac_25g_us #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .CNT(CNT),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE("GTH"),

        // GT parameters
        .GT_TX_POLARITY(n == 0 ? 2'b01 : 2'b00),
        .GT_RX_POLARITY('0),

        // MAC/PHY config
        .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
        .DATA_W(MAC_DATA_W),
        .PADDING_EN(1'b1),
        .DIC_EN(1'b1),
        .MIN_FRAME_LEN(64),
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
    mac_inst (
        .xcvr_ctrl_clk(clk_125mhz),
        .xcvr_ctrl_rst(sfp_rst[CLK]),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(gt_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(sfp_gtpowergood[n]),
        .xcvr_gtrefclk00_in(sfp_mgt_refclk[CLK]),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'd0),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(sfp_mgt_refclk[CLK]),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'd0),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        /*
         * Serial data
         */
        .xcvr_txp(sfp_tx_p[n*CNT +: CNT]),
        .xcvr_txn(sfp_tx_n[n*CNT +: CNT]),
        .xcvr_rxp(sfp_rx_p[n*CNT +: CNT]),
        .xcvr_rxn(sfp_rx_n[n*CNT +: CNT]),

        /*
         * MAC clocks
         */
        .rx_clk(sfp_rx_clk[n*CNT +: CNT]),
        .rx_rst_in('{CNT{1'b0}}),
        .rx_rst_out(sfp_rx_rst[n*CNT +: CNT]),
        .tx_clk(sfp_tx_clk[n*CNT +: CNT]),
        .tx_rst_in('{CNT{1'b0}}),
        .tx_rst_out(sfp_tx_rst[n*CNT +: CNT]),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_sfp_tx[n*CNT +: CNT]),
        .m_axis_tx_cpl(axis_sfp_tx_cpl[n*CNT +: CNT]),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_sfp_rx[n*CNT +: CNT]),

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
        .m_axis_stat(axis_sfp_stat[n]),

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
        .rx_status(sfp_rx_status[n*CNT +: CNT]),
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
        .cfg_tx_max_pkt_len('{CNT{16'd9218}}),
        .cfg_tx_ifg('{CNT{8'd12}}),
        .cfg_tx_enable('{CNT{1'b1}}),
        .cfg_rx_max_pkt_len('{CNT{16'd9218}}),
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
