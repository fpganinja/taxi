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

    // FW ID
    parameter FPGA_ID = 32'h4B39093,
    parameter FW_ID = 32'h0000C001,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h4144_9003,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,

    // PCIe interface configuration
    parameter RQ_SEQ_NUM_W = 6,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_W = 32,
    parameter AXIL_CTRL_ADDR_W = 24,

    // MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
)
(
    /*
     * Clock: 125 MHz
     * Synchronous reset
     */
    input  wire logic                     clk_125mhz,
    input  wire logic                     rst_125mhz,

    /*
     * GPIO
     */
    output wire logic [1:0]               user_led_g,
    output wire logic                     user_led_r,
    output wire logic [1:0]               front_led,
    input  wire logic [1:0]               user_sw,

    /*
     * Ethernet: QSFP28
     */
    output wire logic                     qsfp_0_tx_p[4],
    output wire logic                     qsfp_0_tx_n[4],
    input  wire logic                     qsfp_0_rx_p[4],
    input  wire logic                     qsfp_0_rx_n[4],
    input  wire logic                     qsfp_0_mgt_refclk_p,
    input  wire logic                     qsfp_0_mgt_refclk_n,
    input  wire logic                     qsfp_0_modprs_l,
    output wire logic                     qsfp_0_sel_l,

    output wire logic                     qsfp_1_tx_p[4],
    output wire logic                     qsfp_1_tx_n[4],
    input  wire logic                     qsfp_1_rx_p[4],
    input  wire logic                     qsfp_1_rx_n[4],
    // input  wire logic                     qsfp_1_mgt_refclk_p,
    // input  wire logic                     qsfp_1_mgt_refclk_n,
    input  wire logic                     qsfp_1_modprs_l,
    output wire logic                     qsfp_1_sel_l,

    output wire logic                     qsfp_reset_l,
    input  wire logic                     qsfp_int_l,

    /*
     * PCIe
     */
    input  wire logic                     pcie_clk,
    input  wire logic                     pcie_rst,
    taxi_axis_if.snk                      s_axis_pcie_cq,
    taxi_axis_if.src                      m_axis_pcie_cc,
    taxi_axis_if.src                      m_axis_pcie_rq,
    taxi_axis_if.snk                      s_axis_pcie_rc,

    input  wire logic [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num0,
    input  wire logic                     pcie_rq_seq_num_vld0,
    input  wire logic [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num1,
    input  wire logic                     pcie_rq_seq_num_vld1,

    input  wire logic [2:0]               cfg_max_payload,
    input  wire logic [2:0]               cfg_max_read_req,
    input  wire logic [3:0]               cfg_rcb_status,

    output wire logic [9:0]               cfg_mgmt_addr,
    output wire logic [7:0]               cfg_mgmt_function_number,
    output wire logic                     cfg_mgmt_write,
    output wire logic [31:0]              cfg_mgmt_write_data,
    output wire logic [3:0]               cfg_mgmt_byte_enable,
    output wire logic                     cfg_mgmt_read,
    output wire logic [31:0]              cfg_mgmt_read_data,
    input  wire logic                     cfg_mgmt_read_write_done,

    input  wire logic [7:0]               cfg_fc_ph,
    input  wire logic [11:0]              cfg_fc_pd,
    input  wire logic [7:0]               cfg_fc_nph,
    input  wire logic [11:0]              cfg_fc_npd,
    input  wire logic [7:0]               cfg_fc_cplh,
    input  wire logic [11:0]              cfg_fc_cpld,
    output wire logic [2:0]               cfg_fc_sel,

    input  wire logic                     cfg_ext_read_received,
    input  wire logic                     cfg_ext_write_received,
    input  wire logic [9:0]               cfg_ext_register_number,
    input  wire logic [7:0]               cfg_ext_function_number,
    input  wire logic [31:0]              cfg_ext_write_data,
    input  wire logic [3:0]               cfg_ext_write_byte_enable,
    output wire logic [31:0]              cfg_ext_read_data,
    output wire logic                     cfg_ext_read_data_valid,

    input  wire logic [3:0]               cfg_interrupt_msi_enable,
    input  wire logic [11:0]              cfg_interrupt_msi_mmenable,
    input  wire logic                     cfg_interrupt_msi_mask_update,
    input  wire logic [31:0]              cfg_interrupt_msi_data,
    output wire logic [1:0]               cfg_interrupt_msi_select,
    output wire logic [31:0]              cfg_interrupt_msi_int,
    output wire logic [31:0]              cfg_interrupt_msi_pending_status,
    output wire logic                     cfg_interrupt_msi_pending_status_data_enable,
    output wire logic [1:0]               cfg_interrupt_msi_pending_status_function_num,
    input  wire logic                     cfg_interrupt_msi_sent,
    input  wire logic                     cfg_interrupt_msi_fail,
    output wire logic [2:0]               cfg_interrupt_msi_attr,
    output wire logic                     cfg_interrupt_msi_tph_present,
    output wire logic [1:0]               cfg_interrupt_msi_tph_type,
    output wire logic [7:0]               cfg_interrupt_msi_tph_st_tag,
    output wire logic [7:0]               cfg_interrupt_msi_function_number,

    /*
     * QSPI flash
     */
    output wire logic                     fpga_boot,
    output wire logic                     qspi_clk,
    input  wire logic [3:0]               qspi_0_dq_i,
    output wire logic [3:0]               qspi_0_dq_o,
    output wire logic [3:0]               qspi_0_dq_oe,
    output wire logic                     qspi_0_cs,
    input  wire logic [3:0]               qspi_1_dq_i,
    output wire logic [3:0]               qspi_1_dq_o,
    output wire logic [3:0]               qspi_1_dq_oe,
    output wire logic                     qspi_1_cs
);

localparam logic PTP_TS_FMT_TOD = 1'b0;
localparam PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 48;

// flashing via PCIe VPD
pyrite_pcie_us_vpd_qspi #(
    .VPD_CAP_ID(8'h03),
    .VPD_CAP_OFFSET(8'hB0),
    .VPD_CAP_NEXT(8'h00),

    // FW ID
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

    // Flash
    .FLASH_SEG_COUNT(2),
    .FLASH_SEG_DEFAULT(1),
    .FLASH_SEG_FALLBACK(0),
    .FLASH_SEG0_SIZE(32'h00000000),
    .FLASH_DATA_W(4),
    .FLASH_DUAL_QSPI(1'b1)
)
pyrite_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * PCIe
     */
    .cfg_ext_read_received(cfg_ext_read_received),
    .cfg_ext_write_received(cfg_ext_write_received),
    .cfg_ext_register_number(cfg_ext_register_number),
    .cfg_ext_function_number(cfg_ext_function_number),
    .cfg_ext_write_data(cfg_ext_write_data),
    .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    .cfg_ext_read_data(cfg_ext_read_data),
    .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

    /*
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .qspi_clk(qspi_clk),
    .qspi_0_dq_i(qspi_0_dq_i),
    .qspi_0_dq_o(qspi_0_dq_o),
    .qspi_0_dq_oe(qspi_0_dq_oe),
    .qspi_0_cs(qspi_0_cs),
    .qspi_1_dq_i(qspi_1_dq_i),
    .qspi_1_dq_o(qspi_1_dq_o),
    .qspi_1_dq_oe(qspi_1_dq_oe),
    .qspi_1_cs(qspi_1_cs)
);

// QSFP28
assign qsfp_0_sel_l = 1'b1;
assign qsfp_1_sel_l = 1'b1;
assign qsfp_reset_l = 1'b1;

wire qsfp_tx_clk[8];
wire qsfp_tx_rst[8];
wire qsfp_rx_clk[8];
wire qsfp_rx_rst[8];

wire qsfp_rx_status[8];

wire [1:0] qsfp_gtpowergood;

wire qsfp_0_mgt_refclk;
wire qsfp_0_mgt_refclk_int;
wire qsfp_0_mgt_refclk_bufg;

wire qsfp_rst;

taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_qsfp_tx[8]();
taxi_axis_if #(.DATA_W(PTP_TS_W), .KEEP_W(1), .ID_W(8)) axis_qsfp_tx_cpl[8]();
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1+PTP_TS_W)) axis_qsfp_rx[8]();
taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) axis_qsfp_stat[2]();

if (SIM) begin

    assign qsfp_0_mgt_refclk = qsfp_0_mgt_refclk_p;
    assign qsfp_0_mgt_refclk_int = qsfp_0_mgt_refclk_p;
    assign qsfp_0_mgt_refclk_bufg = qsfp_0_mgt_refclk_int;

end else begin

    IBUFDS_GTE4 ibufds_gte4_qsfp_0_mgt_refclk_inst (
        .I     (qsfp_0_mgt_refclk_p),
        .IB    (qsfp_0_mgt_refclk_n),
        .CEB   (1'b0),
        .O     (qsfp_0_mgt_refclk),
        .ODIV2 (qsfp_0_mgt_refclk_int)
    );

    BUFG_GT bufg_gt_qsfp_0_mgt_refclk_inst (
        .CE      (&qsfp_gtpowergood),
        .CEMASK  (1'b1),
        .CLR     (1'b0),
        .CLRMASK (1'b1),
        .DIV     (3'd0),
        .I       (qsfp_0_mgt_refclk_int),
        .O       (qsfp_0_mgt_refclk_bufg)
    );

end

taxi_sync_reset #(
    .N(4)
)
qsfp_sync_reset_inst (
    .clk(qsfp_0_mgt_refclk_bufg),
    .rst(rst_125mhz),
    .out(qsfp_rst)
);

wire ptp_clk = qsfp_0_mgt_refclk_bufg;
wire ptp_rst = qsfp_rst;
wire ptp_sample_clk = clk_125mhz;
wire ptp_td_sd;
wire ptp_pps;
wire ptp_pps_str;

assign user_led_g[0] = ptp_pps_str;
assign user_led_g[1] = 1'b0;
assign user_led_r = 1'b0;

wire qsfp_tx_p[8];
wire qsfp_tx_n[8];
wire qsfp_rx_p[8];
wire qsfp_rx_n[8];

assign qsfp_0_tx_p = qsfp_tx_p[4*0 +: 4];
assign qsfp_0_tx_n = qsfp_tx_n[4*0 +: 4];
assign qsfp_1_tx_p = qsfp_tx_p[4*1 +: 4];
assign qsfp_1_tx_n = qsfp_tx_n[4*1 +: 4];

assign qsfp_rx_p[4*0 +: 4] = qsfp_0_rx_p;
assign qsfp_rx_n[4*0 +: 4] = qsfp_0_rx_n;
assign qsfp_rx_p[4*1 +: 4] = qsfp_1_rx_p;
assign qsfp_rx_n[4*1 +: 4] = qsfp_1_rx_n;

for (genvar n = 0; n < 2; n = n + 1) begin : gty_quad

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

        .CNT(CNT),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE("GTY"),

        // PHY parameters
        .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
        .DATA_W(MAC_DATA_W),
        .PADDING_EN(1'b1),
        .DIC_EN(1'b1),
        .MIN_FRAME_LEN(64),
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TD_EN(PTP_TS_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
        .PTP_TS_W(PTP_TS_W),
        .PTP_TD_SDI_PIPELINE(2),
        .PRBS31_EN(1'b0),
        .TX_SERDES_PIPELINE(1),
        .RX_SERDES_PIPELINE(1),
        .COUNT_125US(125000/6.4),
        .STAT_EN(1'b0)
    )
    mac_inst (
        .xcvr_ctrl_clk(clk_125mhz),
        .xcvr_ctrl_rst(qsfp_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(gt_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(qsfp_gtpowergood[n]),
        .xcvr_gtrefclk00_in(qsfp_0_mgt_refclk),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'd0),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(qsfp_0_mgt_refclk),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'd0),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        /*
         * Serial data
         */
        .xcvr_txp(qsfp_tx_p[n*CNT +: CNT]),
        .xcvr_txn(qsfp_tx_n[n*CNT +: CNT]),
        .xcvr_rxp(qsfp_rx_p[n*CNT +: CNT]),
        .xcvr_rxn(qsfp_rx_n[n*CNT +: CNT]),

        /*
         * MAC clocks
         */
        .rx_clk(qsfp_rx_clk[n*CNT +: CNT]),
        .rx_rst_in('{CNT{1'b0}}),
        .rx_rst_out(qsfp_rx_rst[n*CNT +: CNT]),
        .tx_clk(qsfp_tx_clk[n*CNT +: CNT]),
        .tx_rst_in('{CNT{1'b0}}),
        .tx_rst_out(qsfp_tx_rst[n*CNT +: CNT]),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_qsfp_tx[n*CNT +: CNT]),
        .m_axis_tx_cpl(axis_qsfp_tx_cpl[n*CNT +: CNT]),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_qsfp_rx[n*CNT +: CNT]),

        /*
         * PTP clock
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sdi(ptp_td_sd),
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
        .m_axis_stat(axis_qsfp_stat[n]),

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
        .rx_status(qsfp_rx_status[n*CNT +: CNT]),
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

cndm_micro_pcie_us #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),

    // FW ID
    .FPGA_ID(FPGA_ID),
    .FW_ID(FW_ID),
    .FW_VER(FW_VER),
    .BOARD_ID(BOARD_ID),
    .BOARD_VER(BOARD_VER),
    .BUILD_DATE(BUILD_DATE),
    .GIT_HASH(GIT_HASH),
    .RELEASE_INFO(RELEASE_INFO),

    // Structural configuration
    .PORTS(8),

    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(1'b0),
    .PTP_CLK_PER_NS_NUM(1024),
    .PTP_CLK_PER_NS_DENOM(165),

    // PCIe interface configuration
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_W(AXIL_CTRL_DATA_W),
    .AXIL_CTRL_ADDR_W(AXIL_CTRL_ADDR_W)
)
cndm_inst (
    /*
     * PCIe
     */
    .pcie_clk(pcie_clk),
    .pcie_rst(pcie_rst),
    .s_axis_pcie_cq(s_axis_pcie_cq),
    .m_axis_pcie_cc(m_axis_pcie_cc),
    .m_axis_pcie_rq(m_axis_pcie_rq),
    .s_axis_pcie_rc(s_axis_pcie_rc),

    .pcie_rq_seq_num0(pcie_rq_seq_num0),
    .pcie_rq_seq_num_vld0(pcie_rq_seq_num_vld0),
    .pcie_rq_seq_num1(pcie_rq_seq_num1),
    .pcie_rq_seq_num_vld1(pcie_rq_seq_num_vld1),

    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_rcb_status(cfg_rcb_status),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_mmenable(cfg_interrupt_msi_mmenable),
    .cfg_interrupt_msi_mask_update(cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_data(cfg_interrupt_msi_data),
    .cfg_interrupt_msi_select(cfg_interrupt_msi_select),
    .cfg_interrupt_msi_int(cfg_interrupt_msi_int),
    .cfg_interrupt_msi_pending_status(cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_pending_status_data_enable(cfg_interrupt_msi_pending_status_data_enable),
    .cfg_interrupt_msi_pending_status_function_num(cfg_interrupt_msi_pending_status_function_num),
    .cfg_interrupt_msi_sent(cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail(cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_attr(cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_tph_present(cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_type(cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_tph_st_tag(cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

    /*
     * PTP
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sdo(ptp_td_sd),
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_sync_locked(),
    .ptp_sync_ts_rel(),
    .ptp_sync_ts_rel_step(),
    .ptp_sync_ts_tod(),
    .ptp_sync_ts_tod_step(),
    .ptp_sync_pps(),
    .ptp_sync_pps_str(),

    /*
     * Ethernet
     */
    .mac_tx_clk(qsfp_tx_clk),
    .mac_tx_rst(qsfp_tx_rst),
    .mac_axis_tx(axis_qsfp_tx),
    .mac_axis_tx_cpl(axis_qsfp_tx_cpl),

    .mac_rx_clk(qsfp_rx_clk),
    .mac_rx_rst(qsfp_rx_rst),
    .mac_axis_rx(axis_qsfp_rx)
);

endmodule

`resetall
