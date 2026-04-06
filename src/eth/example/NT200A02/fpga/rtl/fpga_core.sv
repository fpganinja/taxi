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
    parameter string FAMILY = "virtexuplus",
    // Board configuration
    parameter PORT_CNT = 2,
    parameter GTY_QUAD_CNT = PORT_CNT,
    parameter GTY_CNT = GTY_QUAD_CNT*4,
    parameter GTY_CLK_CNT = GTY_QUAD_CNT,
    // 10G/25G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64

)
(
    /*
     * Clock: 125 MHz
     * Synchronous reset
     */
    input  wire logic                 clk_125mhz,
    input  wire logic                 rst_125mhz,

    /*
     * GPIO
     */
    output wire logic [3:0]           led,
    output wire logic [3:0]           qsfp_led[PORT_CNT],
    output wire logic                 led_red,
    output wire logic                 led_green,
    output wire logic [1:0]           led_sync,
    output wire logic                 eth_led_yellow,
    output wire logic                 eth_led_green,

    /*
     * Ethernet: QSFP28
     */
    output wire logic                 eth_gty_tx_p[GTY_CNT],
    output wire logic                 eth_gty_tx_n[GTY_CNT],
    input  wire logic                 eth_gty_rx_p[GTY_CNT],
    input  wire logic                 eth_gty_rx_n[GTY_CNT],
    input  wire logic                 eth_gty_mgt_refclk_p[GTY_CLK_CNT],
    input  wire logic                 eth_gty_mgt_refclk_n[GTY_CLK_CNT],
    output wire logic                 eth_gty_mgt_refclk_out[GTY_CLK_CNT],

    output wire logic [PORT_CNT-1:0]  eth_port_resetl,
    input  wire logic [PORT_CNT-1:0]  eth_port_modprsl,
    input  wire logic [PORT_CNT-1:0]  eth_port_intl,
    output wire logic [PORT_CNT-1:0]  eth_port_lpmode,

    input  wire logic [PORT_CNT-1:0]  eth_port_i2c_scl_i,
    output wire logic [PORT_CNT-1:0]  eth_port_i2c_scl_o,
    input  wire logic [PORT_CNT-1:0]  eth_port_i2c_sda_i,
    output wire logic [PORT_CNT-1:0]  eth_port_i2c_sda_o
);

assign eth_port_i2c_scl_o = '1;
assign eth_port_i2c_sda_o = '1;

// QSFP28
assign eth_port_resetl = '1;
assign eth_port_lpmode = '0;

wire eth_gty_tx_clk[GTY_CNT];
wire eth_gty_tx_rst[GTY_CNT];
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) eth_gty_axis_tx[GTY_CNT]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) eth_gty_axis_tx_cpl[GTY_CNT]();

wire eth_gty_rx_clk[GTY_CNT];
wire eth_gty_rx_rst[GTY_CNT];
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) eth_gty_axis_rx[GTY_CNT]();

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_eth_stat[GTY_QUAD_CNT]();

wire eth_gty_rx_status[GTY_CNT];

assign qsfp_led[0][0] = eth_gty_rx_status[0];
assign qsfp_led[0][1] = eth_gty_rx_status[1];
assign qsfp_led[0][2] = eth_gty_rx_status[2];
assign qsfp_led[0][3] = eth_gty_rx_status[3];
assign qsfp_led[1][0] = eth_gty_rx_status[4];
assign qsfp_led[1][1] = eth_gty_rx_status[5];
assign qsfp_led[1][2] = eth_gty_rx_status[6];
assign qsfp_led[1][3] = eth_gty_rx_status[7];

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

        if (FAMILY == "virtexuplus") begin

            IBUFDS_GTE4 ibufds_gte4_eth_gty_mgt_refclk_inst (
                .I     (eth_gty_mgt_refclk_p[n]),
                .IB    (eth_gty_mgt_refclk_n[n]),
                .CEB   (1'b0),
                .O     (eth_gty_mgt_refclk[n]),
                .ODIV2 (eth_gty_mgt_refclk_int)
            );

        end else begin

            IBUFDS_GTE3 ibufds_gte4_eth_gty_mgt_refclk_inst (
                .I     (eth_gty_mgt_refclk_p[n]),
                .IB    (eth_gty_mgt_refclk_n[n]),
                .CEB   (1'b0),
                .O     (eth_gty_mgt_refclk[n]),
                .ODIV2 (eth_gty_mgt_refclk_int)
            );

        end

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

    taxi_sync_reset #(
        .N(4)
    )
    qsfp_sync_reset_inst (
        .clk(eth_gty_mgt_refclk_bufg[n]),
        .rst(rst_125mhz),
        .out(eth_gty_rst[n])
    );

end

localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP0[4] = '{"QSFP0.1", "QSFP0.2", "QSFP0.3",  "QSFP0.4"};
localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP1[4] = '{"QSFP1.1", "QSFP1.2", "QSFP1.3",  "QSFP1.4"};

for (genvar n = 0; n < GTY_QUAD_CNT; n = n + 1) begin : gt_quad

    localparam CNT = 4;

    taxi_apb_if #(
        .ADDR_W(18),
        .DATA_W(16)
    )
    gt_apb_ctrl();

    taxi_eth_mac_25g_us #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .CNT(4),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE("GTY"),

        // GT parameters
        .GT_TX_POLARITY(n == 0 ? 4'b0101 : 4'b0001),
        .GT_RX_POLARITY(n == 0 ? 4'b1011 : 4'b0011),

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
        .STAT_EN(0),
        .STAT_TX_LEVEL(1),
        .STAT_RX_LEVEL(1),
        .STAT_ID_BASE(n*CNT*(16+16)),
        .STAT_UPDATE_PERIOD(1024),
        .STAT_STR_EN(0),
        .STAT_PREFIX_STR(n == 0 ? STAT_PREFIX_STR_QSFP0 : STAT_PREFIX_STR_QSFP1)
    )
    mac_inst (
        .xcvr_ctrl_clk(clk_125mhz),
        .xcvr_ctrl_rst(eth_gty_rst[n]),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(gt_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(eth_gty_gtpowergood[n]),
        .xcvr_gtrefclk00_in(eth_gty_mgt_refclk[n]),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'd0),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(eth_gty_mgt_refclk[n]),
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

for (genvar n = 0; n < GTY_CNT; n = n + 1) begin : qsfp_ch

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

endmodule

`resetall
