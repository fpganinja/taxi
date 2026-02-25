// SPDX-License-Identifier: MIT
/*

Copyright (c) 2020-2026 FPGA Ninja, LLC

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

    // FW ID
    parameter FPGA_ID = 32'h4730093,
    parameter FW_ID = 32'h0000C001,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h10ee_906a,
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
    parameter MAC_DATA_W = 32
)
(
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire logic                     clk_125mhz,
    input  wire logic                     rst_125mhz,

    /*
     * GPIO
     */
    input  wire logic                     btnu,
    input  wire logic                     btnl,
    input  wire logic                     btnd,
    input  wire logic                     btnr,
    input  wire logic                     btnc,
    input  wire logic [7:0]               sw,
    output wire logic [7:0]               led,

    /*
     * UART: 115200 bps, 8N1
     */
    input  wire logic                     uart_rxd,
    output wire logic                     uart_txd,
    input  wire logic                     uart_rts,
    output wire logic                     uart_cts,

    /*
     * Ethernet: SFP+
     */
    input  wire logic                     sfp_rx_p[2],
    input  wire logic                     sfp_rx_n[2],
    output wire logic                     sfp_tx_p[2],
    output wire logic                     sfp_tx_n[2],
    input  wire logic                     sfp_mgt_refclk_0_p,
    input  wire logic                     sfp_mgt_refclk_0_n,

    input  wire logic                     sfp0_gmii_clk,
    input  wire logic                     sfp0_gmii_rst,
    input  wire logic                     sfp0_gmii_clk_en,
    input  wire logic [7:0]               sfp0_gmii_rxd,
    input  wire logic                     sfp0_gmii_rx_dv,
    input  wire logic                     sfp0_gmii_rx_er,
    output wire logic [7:0]               sfp0_gmii_txd,
    output wire logic                     sfp0_gmii_tx_en,
    output wire logic                     sfp0_gmii_tx_er,

    input  wire logic                     sfp1_gmii_clk,
    input  wire logic                     sfp1_gmii_rst,
    input  wire logic                     sfp1_gmii_clk_en,
    input  wire logic [7:0]               sfp1_gmii_rxd,
    input  wire logic                     sfp1_gmii_rx_dv,
    input  wire logic                     sfp1_gmii_rx_er,
    output wire logic [7:0]               sfp1_gmii_txd,
    output wire logic                     sfp1_gmii_tx_en,
    output wire logic                     sfp1_gmii_tx_er,

    output wire logic [1:0]               sfp_tx_disable_b,

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

    // input  wire logic                     cfg_ext_read_received,
    // input  wire logic                     cfg_ext_write_received,
    // input  wire logic [9:0]               cfg_ext_register_number,
    // input  wire logic [7:0]               cfg_ext_function_number,
    // input  wire logic [31:0]              cfg_ext_write_data,
    // input  wire logic [3:0]               cfg_ext_write_byte_enable,
    // output wire logic [31:0]              cfg_ext_read_data,
    // output wire logic                     cfg_ext_read_data_valid,

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
    output wire logic [7:0]               cfg_interrupt_msi_function_number
);

localparam logic PTP_TS_FMT_TOD = 1'b0;
localparam PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 48;

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
    .prescale(16'(125000000/2000000))
);

taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_sw_ds[2](), xfcp_sw_us[2]();

taxi_xfcp_switch #(
    .XFCP_ID_STR("ZCU106"),
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

// SFP+
wire sfp_tx_clk[2];
wire sfp_tx_rst[2];
wire sfp_rx_clk[2];
wire sfp_rx_rst[2];

wire sfp_rx_status[2];

wire sfp_gtpowergood;

wire sfp_mgt_refclk_0;
wire sfp_mgt_refclk_0_int;
wire sfp_mgt_refclk_0_bufg;

wire sfp_rst;

taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_sfp_tx[2]();
taxi_axis_if #(.DATA_W(PTP_TS_W), .KEEP_W(1), .ID_W(8)) axis_sfp_tx_cpl[2]();
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1+PTP_TS_W)) axis_sfp_rx[2]();

if (SIM) begin

    assign sfp_mgt_refclk_0 = sfp_mgt_refclk_0_p;
    assign sfp_mgt_refclk_0_int = sfp_mgt_refclk_0_p;
    assign sfp_mgt_refclk_0_bufg = sfp_mgt_refclk_0_int;

end else begin

    IBUFDS_GTE4 ibufds_gte4_sfp_mgt_refclk_0_inst (
        .I     (sfp_mgt_refclk_0_p),
        .IB    (sfp_mgt_refclk_0_n),
        .CEB   (1'b0),
        .O     (sfp_mgt_refclk_0),
        .ODIV2 (sfp_mgt_refclk_0_int)
    );

    BUFG_GT bufg_gt_sfp_mgt_refclk_0_inst (
        .CE      (sfp_gtpowergood),
        .CEMASK  (1'b1),
        .CLR     (1'b0),
        .CLRMASK (1'b1),
        .DIV     (3'd0),
        .I       (sfp_mgt_refclk_0_int),
        .O       (sfp_mgt_refclk_0_bufg)
    );

end

taxi_sync_reset #(
    .N(4)
)
sfp_sync_reset_inst (
    .clk(sfp_mgt_refclk_0_bufg),
    .rst(rst_125mhz),
    .out(sfp_rst)
);

wire ptp_clk = sfp_mgt_refclk_0_bufg;
wire ptp_rst = sfp_rst;
wire ptp_sample_clk = clk_125mhz;
wire ptp_td_sd;
wire ptp_pps;
wire ptp_pps_str;

assign led[0] = sfp_rx_status[0];
assign led[1] = sfp_rx_status[1];
assign led[2] = 1'b0;
assign led[3] = 1'b0;
assign led[4] = 1'b0;
assign led[5] = 1'b0;
assign led[6] = 1'b0;
assign led[7] = ptp_pps_str;

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
    .xfcp_usp_ds(xfcp_sw_ds[1]),
    .xfcp_usp_us(xfcp_sw_us[1]),

    /*
     * APB master interface
     */
    .m_apb(gt_apb_ctrl)
);

taxi_eth_mac_25g_us #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),

    .CNT(2),

    // GT config
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

    // GT type
    .GT_TYPE("GTH"),

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
    .STAT_EN(1),
    .STAT_TX_LEVEL(1),
    .STAT_RX_LEVEL(1),
    .STAT_ID_BASE(0),
    .STAT_UPDATE_PERIOD(1024)//,
    // disabled due to verilator bug
    // .STAT_STR_EN(1),
    // .STAT_PREFIX_STR('{"SFP0", "SFP1"})
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
    .xcvr_gtrefclk00_in(sfp_mgt_refclk_0),
    .xcvr_qpll0pd_in(1'b0),
    .xcvr_qpll0reset_in(1'b0),
    .xcvr_qpll0pcierate_in(3'd0),
    .xcvr_qpll0lock_out(),
    .xcvr_qpll0clk_out(),
    .xcvr_qpll0refclk_out(),
    .xcvr_gtrefclk01_in(sfp_mgt_refclk_0),
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
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sdi(ptp_td_sd),
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
    .m_axis_stat(axis_stat),

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
    .cfg_tx_max_pkt_len('{2{16'd9218}}),
    .cfg_tx_ifg('{2{8'd12}}),
    .cfg_tx_enable('{2{1'b1}}),
    .cfg_rx_max_pkt_len('{2{16'd9218}}),
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
    .PORTS(2),

    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(1'b0),
    .PTP_CLK_PER_NS_NUM(32),
    .PTP_CLK_PER_NS_DENOM(5),

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
    .mac_tx_clk(sfp_tx_clk),
    .mac_tx_rst(sfp_tx_rst),
    .mac_axis_tx(axis_sfp_tx),
    .mac_axis_tx_cpl(axis_sfp_tx_cpl),

    .mac_rx_clk(sfp_rx_clk),
    .mac_rx_rst(sfp_rx_rst),
    .mac_axis_rx(axis_sfp_rx)
);

endmodule

`resetall
