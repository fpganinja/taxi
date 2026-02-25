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
 * FPGA top-level module
 */
module fpga #
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
     * Clock: 125MHz LVDS
     * Reset: Push button, active low
     */
    input  wire logic        clk_125mhz_p,
    input  wire logic        clk_125mhz_n,
    input  wire logic        reset,

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
     * Ethernet: SFP+
     */
    input  wire logic        sfp_rx_p[2],
    input  wire logic        sfp_rx_n[2],
    output wire logic        sfp_tx_p[2],
    output wire logic        sfp_tx_n[2],
    input  wire logic        sfp_mgt_refclk_0_p,
    input  wire logic        sfp_mgt_refclk_0_n,
    output wire logic [1:0]  sfp_tx_disable_b,

    /*
     * PCIe
     */
    input  wire logic [3:0]  pcie_rx_p,
    input  wire logic [3:0]  pcie_rx_n,
    output wire logic [3:0]  pcie_tx_p,
    output wire logic [3:0]  pcie_tx_n,
    input  wire logic        pcie_refclk_p,
    input  wire logic        pcie_refclk_n,
    input  wire logic        pcie_reset_n
);

// Clock and reset
wire pcie_user_clk;
wire pcie_user_rst;

wire clk_125mhz_ibufg;

// Internal 125 MHz clock
wire clk_125mhz_mmcm_out;
wire clk_125mhz_int;
wire rst_125mhz_int;

wire mmcm_rst = reset;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFGDS #(
   .DIFF_TERM("FALSE"),
   .IBUF_LOW_PWR("FALSE")
)
clk_125mhz_ibufg_inst (
   .O   (clk_125mhz_ibufg),
   .I   (clk_125mhz_p),
   .IB  (clk_125mhz_n)
);

// MMCM instance
MMCME4_BASE #(
    // 125 MHz input
    .CLKIN1_PERIOD(8.0),
    .REF_JITTER1(0.010),
    // 125 MHz input / 1 = 125 MHz PFD (range 10 MHz to 500 MHz)
    .DIVCLK_DIVIDE(1),
    // 125 MHz PFD * 10 = 1250 MHz VCO (range 800 MHz to 1600 MHz)
    .CLKFBOUT_MULT_F(10),
    .CLKFBOUT_PHASE(0),
    // 1250 MHz / 10 = 125 MHz, 0 degrees
    .CLKOUT0_DIVIDE_F(10),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    // Not used
    .CLKOUT1_DIVIDE(1),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0),
    // Not used
    .CLKOUT2_DIVIDE(1),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    // Not used
    .CLKOUT3_DIVIDE(1),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0),
    // Not used
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0),
    .CLKOUT4_CASCADE("FALSE"),
    // Not used
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0),
    // Not used
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT6_PHASE(0),

    // optimized bandwidth
    .BANDWIDTH("OPTIMIZED"),
    // don't wait for lock during startup
    .STARTUP_WAIT("FALSE")
)
clk_mmcm_inst (
    // 125 MHz input
    .CLKIN1(clk_125mhz_ibufg),
    // direct clkfb feeback
    .CLKFBIN(mmcm_clkfb),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    // 125 MHz, 0 degrees
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    // Not used
    .CLKOUT1(),
    .CLKOUT1B(),
    // Not used
    .CLKOUT2(),
    .CLKOUT2B(),
    // Not used
    .CLKOUT3(),
    .CLKOUT3B(),
    // Not used
    .CLKOUT4(),
    // Not used
    .CLKOUT5(),
    // Not used
    .CLKOUT6(),
    // reset input
    .RST(mmcm_rst),
    // don't power down
    .PWRDWN(1'b0),
    // locked output
    .LOCKED(mmcm_locked)
);

BUFG
clk_125mhz_bufg_inst (
    .I(clk_125mhz_mmcm_out),
    .O(clk_125mhz_int)
);

taxi_sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

// GPIO
wire btnu_int;
wire btnl_int;
wire btnd_int;
wire btnr_int;
wire btnc_int;
wire [7:0] sw_int;

taxi_debounce_switch #(
    .WIDTH(5+8),
    .N(4),
    .RATE(125000)
)
debounce_switch_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),
    .in({btnu,
        btnl,
        btnd,
        btnr,
        btnc,
        sw}),
    .out({btnu_int,
        btnl_int,
        btnd_int,
        btnr_int,
        btnc_int,
        sw_int})
);

wire uart_rxd_int;
wire uart_rts_int;

taxi_sync_signal #(
    .WIDTH(2),
    .N(2)
)
sync_signal_inst (
    .clk(clk_125mhz_int),
    .in({uart_rxd, uart_rts}),
    .out({uart_rxd_int, uart_rts_int})
);

// PCIe
localparam AXIS_PCIE_DATA_W = 128;
localparam AXIS_PCIE_KEEP_W = (AXIS_PCIE_DATA_W/32);
localparam AXIS_PCIE_RC_USER_W = AXIS_PCIE_DATA_W < 512 ? 75 : 161;
localparam AXIS_PCIE_RQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 62 : 137;
localparam AXIS_PCIE_CQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 85 : 183;
localparam AXIS_PCIE_CC_USER_W = AXIS_PCIE_DATA_W < 512 ? 33 : 81;
localparam RC_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 256;
localparam RQ_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 512;
localparam CQ_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 512;
localparam CC_STRADDLE = 0; // AXIS_PCIE_DATA_W >= 512;

localparam RQ_SEQ_NUM_W = AXIS_PCIE_RQ_USER_W == 60 ? 4 : 6;
localparam RQ_SEQ_NUM_EN = 1;

localparam PCIE_TAG_CNT = AXIS_PCIE_RQ_USER_W == 60 ? 64 : 256;
localparam BAR0_APERTURE = 24;

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_CQ_USER_W)
) axis_pcie_cq();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_CC_USER_W)
) axis_pcie_cc();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_RQ_USER_W)
) axis_pcie_rq();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_RC_USER_W)
) axis_pcie_rc();

wire [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num0;
wire pcie_rq_seq_num_vld0;
wire [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num1;
wire pcie_rq_seq_num_vld1;

wire [2:0] cfg_max_payload;
wire [2:0] cfg_max_read_req;
wire [3:0] cfg_rcb_status;

wire [9:0]  cfg_mgmt_addr;
wire [7:0]  cfg_mgmt_function_number;
wire        cfg_mgmt_write;
wire [31:0] cfg_mgmt_write_data;
wire [3:0]  cfg_mgmt_byte_enable;
wire        cfg_mgmt_read;
wire [31:0] cfg_mgmt_read_data;
wire        cfg_mgmt_read_write_done;

wire [7:0]  cfg_fc_ph;
wire [11:0] cfg_fc_pd;
wire [7:0]  cfg_fc_nph;
wire [11:0] cfg_fc_npd;
wire [7:0]  cfg_fc_cplh;
wire [11:0] cfg_fc_cpld;
wire [2:0]  cfg_fc_sel;

// wire         cfg_ext_read_received;
// wire         cfg_ext_write_received;
// wire [9:0]   cfg_ext_register_number;
// wire [7:0]   cfg_ext_function_number;
// wire [31:0]  cfg_ext_write_data;
// wire [3:0]   cfg_ext_write_byte_enable;
// wire [31:0]  cfg_ext_read_data;
// wire         cfg_ext_read_data_valid;

// wire [3:0]   cfg_interrupt_msix_enable;
// wire [3:0]   cfg_interrupt_msix_mask;
// wire [251:0] cfg_interrupt_msix_vf_enable;
// wire [251:0] cfg_interrupt_msix_vf_mask;
// wire [63:0]  cfg_interrupt_msix_address;
// wire [31:0]  cfg_interrupt_msix_data;
// wire         cfg_interrupt_msix_int;
// wire [1:0]   cfg_interrupt_msix_vec_pending;
// wire         cfg_interrupt_msix_vec_pending_status;
// wire         cfg_interrupt_msix_sent;
// wire         cfg_interrupt_msix_fail;
// wire [7:0]   cfg_interrupt_msi_function_number;

wire [3:0]   cfg_interrupt_msi_enable;
wire [11:0]  cfg_interrupt_msi_mmenable;
wire         cfg_interrupt_msi_mask_update;
wire [31:0]  cfg_interrupt_msi_data;
wire [1:0]   cfg_interrupt_msi_select;
wire [31:0]  cfg_interrupt_msi_int;
wire [31:0]  cfg_interrupt_msi_pending_status;
wire         cfg_interrupt_msi_pending_status_data_enable;
wire [1:0]   cfg_interrupt_msi_pending_status_function_num;
wire         cfg_interrupt_msi_sent;
wire         cfg_interrupt_msi_fail;
wire [2:0]   cfg_interrupt_msi_attr;
wire         cfg_interrupt_msi_tph_present;
wire [1:0]   cfg_interrupt_msi_tph_type;
wire [7:0]   cfg_interrupt_msi_tph_st_tag;
wire [7:0]   cfg_interrupt_msi_function_number;

wire stat_err_cor;
wire stat_err_uncor;

wire pcie_sys_clk;
wire pcie_sys_clk_gt;

IBUFDS_GTE4 #(
    .REFCLK_HROW_CK_SEL(2'b00)
)
ibufds_gte4_pcie_refclk_inst (
    .I             (pcie_refclk_p),
    .IB            (pcie_refclk_n),
    .CEB           (1'b0),
    .O             (pcie_sys_clk_gt),
    .ODIV2         (pcie_sys_clk)
);

pcie4_uscale_plus_0
pcie4_uscale_plus_inst (
    .pci_exp_txn(pcie_tx_n),
    .pci_exp_txp(pcie_tx_p),
    .pci_exp_rxn(pcie_rx_n),
    .pci_exp_rxp(pcie_rx_p),
    .user_clk(pcie_user_clk),
    .user_reset(pcie_user_rst),
    .user_lnk_up(),

    .s_axis_rq_tdata(axis_pcie_rq.tdata),
    .s_axis_rq_tkeep(axis_pcie_rq.tkeep),
    .s_axis_rq_tlast(axis_pcie_rq.tlast),
    .s_axis_rq_tready(axis_pcie_rq.tready),
    .s_axis_rq_tuser(axis_pcie_rq.tuser),
    .s_axis_rq_tvalid(axis_pcie_rq.tvalid),

    .m_axis_rc_tdata(axis_pcie_rc.tdata),
    .m_axis_rc_tkeep(axis_pcie_rc.tkeep),
    .m_axis_rc_tlast(axis_pcie_rc.tlast),
    .m_axis_rc_tready(axis_pcie_rc.tready),
    .m_axis_rc_tuser(axis_pcie_rc.tuser),
    .m_axis_rc_tvalid(axis_pcie_rc.tvalid),

    .m_axis_cq_tdata(axis_pcie_cq.tdata),
    .m_axis_cq_tkeep(axis_pcie_cq.tkeep),
    .m_axis_cq_tlast(axis_pcie_cq.tlast),
    .m_axis_cq_tready(axis_pcie_cq.tready),
    .m_axis_cq_tuser(axis_pcie_cq.tuser),
    .m_axis_cq_tvalid(axis_pcie_cq.tvalid),

    .s_axis_cc_tdata(axis_pcie_cc.tdata),
    .s_axis_cc_tkeep(axis_pcie_cc.tkeep),
    .s_axis_cc_tlast(axis_pcie_cc.tlast),
    .s_axis_cc_tready(axis_pcie_cc.tready),
    .s_axis_cc_tuser(axis_pcie_cc.tuser),
    .s_axis_cc_tvalid(axis_pcie_cc.tvalid),

    .pcie_rq_seq_num0(pcie_rq_seq_num0),
    .pcie_rq_seq_num_vld0(pcie_rq_seq_num_vld0),
    .pcie_rq_seq_num1(pcie_rq_seq_num1),
    .pcie_rq_seq_num_vld1(pcie_rq_seq_num_vld1),
    .pcie_rq_tag0(),
    .pcie_rq_tag1(),
    .pcie_rq_tag_av(),
    .pcie_rq_tag_vld0(),
    .pcie_rq_tag_vld1(),

    .pcie_tfc_nph_av(),
    .pcie_tfc_npd_av(),

    .pcie_cq_np_req(1'b1),
    .pcie_cq_np_req_count(),

    .cfg_phy_link_down(),
    .cfg_phy_link_status(),
    .cfg_negotiated_width(),
    .cfg_current_speed(),
    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_function_status(),
    .cfg_function_power_state(),
    .cfg_vf_status(),
    .cfg_vf_power_state(),
    .cfg_link_power_state(),

    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),
    .cfg_mgmt_debug_access(1'b0),

    .cfg_err_cor_out(),
    .cfg_err_nonfatal_out(),
    .cfg_err_fatal_out(),
    .cfg_local_error_valid(),
    .cfg_local_error_out(),
    .cfg_ltssm_state(),
    .cfg_rx_pm_state(),
    .cfg_tx_pm_state(),
    .cfg_rcb_status(cfg_rcb_status),
    .cfg_obff_enable(),
    .cfg_pl_status_change(),
    .cfg_tph_requester_enable(),
    .cfg_tph_st_mode(),
    .cfg_vf_tph_requester_enable(),
    .cfg_vf_tph_st_mode(),

    .cfg_msg_received(),
    .cfg_msg_received_data(),
    .cfg_msg_received_type(),
    .cfg_msg_transmit(1'b0),
    .cfg_msg_transmit_type(3'd0),
    .cfg_msg_transmit_data(32'd0),
    .cfg_msg_transmit_done(),

    .cfg_fc_ph(cfg_fc_ph),
    .cfg_fc_pd(cfg_fc_pd),
    .cfg_fc_nph(cfg_fc_nph),
    .cfg_fc_npd(cfg_fc_npd),
    .cfg_fc_cplh(cfg_fc_cplh),
    .cfg_fc_cpld(cfg_fc_cpld),
    .cfg_fc_sel(cfg_fc_sel),

    .cfg_dsn(64'd0),

    .cfg_bus_number(),

    .cfg_power_state_change_ack(1'b1),
    .cfg_power_state_change_interrupt(),

    .cfg_err_cor_in(stat_err_cor),
    .cfg_err_uncor_in(stat_err_uncor),
    .cfg_flr_in_process(),
    .cfg_flr_done(4'd0),
    .cfg_vf_flr_in_process(),
    .cfg_vf_flr_func_num(8'd0),
    .cfg_vf_flr_done(8'd0),

    .cfg_link_training_enable(1'b1),

    // .cfg_ext_read_received(cfg_ext_read_received),
    // .cfg_ext_write_received(cfg_ext_write_received),
    // .cfg_ext_register_number(cfg_ext_register_number),
    // .cfg_ext_function_number(cfg_ext_function_number),
    // .cfg_ext_write_data(cfg_ext_write_data),
    // .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    // .cfg_ext_read_data(cfg_ext_read_data),
    // .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

    .cfg_interrupt_int(4'd0),
    .cfg_interrupt_pending(4'd0),
    .cfg_interrupt_sent(),
    // .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    // .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    // .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    // .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    // .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    // .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    // .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    // .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    // .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    // .cfg_interrupt_msi_sent(cfg_interrupt_msix_sent),
    // .cfg_interrupt_msi_fail(cfg_interrupt_msix_fail),
    // .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),
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

    .cfg_pm_aspm_l1_entry_reject(1'b0),
    .cfg_pm_aspm_tx_l0s_entry_disable(1'b0),

    .cfg_hot_reset_out(),

    .cfg_config_space_enable(1'b1),
    .cfg_req_pm_transition_l23_ready(1'b0),
    .cfg_hot_reset_in(1'b0),

    .cfg_ds_port_number(8'd0),
    .cfg_ds_bus_number(8'd0),
    .cfg_ds_device_number(5'd0),

    .sys_clk(pcie_sys_clk),
    .sys_clk_gt(pcie_sys_clk_gt),
    .sys_reset(pcie_reset_n),

    .phy_rdy_out()
);

fpga_core #(
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

    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),

    // PCIe interface configuration
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_W(AXIL_CTRL_DATA_W),
    .AXIL_CTRL_ADDR_W(AXIL_CTRL_ADDR_W),

    // MAC configuration
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),
    .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
    .MAC_DATA_W(MAC_DATA_W)
)
core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk_125mhz(clk_125mhz_int),
    .rst_125mhz(rst_125mhz_int),

    /*
     * GPIO
     */
    .btnu(btnu_int),
    .btnl(btnl_int),
    .btnd(btnd_int),
    .btnr(btnr_int),
    .btnc(btnc_int),
    .sw(sw_int),
    .led(led),

    /*
     * UART: 115200 bps, 8N1
     */
    .uart_rxd(uart_rxd_int),
    .uart_txd(uart_txd),
    .uart_rts(uart_rts_int),
    .uart_cts(uart_cts),

    /*
     * Ethernet: SFP+
     */
    .sfp_rx_p(sfp_rx_p),
    .sfp_rx_n(sfp_rx_n),
    .sfp_tx_p(sfp_tx_p),
    .sfp_tx_n(sfp_tx_n),
    .sfp_mgt_refclk_0_p(sfp_mgt_refclk_0_p),
    .sfp_mgt_refclk_0_n(sfp_mgt_refclk_0_n),

    .sfp_tx_disable_b(sfp_tx_disable_b),

    /*
     * PCIe
     */
    .pcie_clk(pcie_user_clk),
    .pcie_rst(pcie_user_rst),
    .s_axis_pcie_cq(axis_pcie_cq),
    .m_axis_pcie_cc(axis_pcie_cc),
    .m_axis_pcie_rq(axis_pcie_rq),
    .s_axis_pcie_rc(axis_pcie_rc),

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

    // .cfg_ext_read_received(cfg_ext_read_received),
    // .cfg_ext_write_received(cfg_ext_write_received),
    // .cfg_ext_register_number(cfg_ext_register_number),
    // .cfg_ext_function_number(cfg_ext_function_number),
    // .cfg_ext_write_data(cfg_ext_write_data),
    // .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    // .cfg_ext_read_data(cfg_ext_read_data),
    // .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

    // .cfg_interrupt_msix_enable(cfg_interrupt_msix_enable),
    // .cfg_interrupt_msix_mask(cfg_interrupt_msix_mask),
    // .cfg_interrupt_msix_vf_enable(cfg_interrupt_msix_vf_enable),
    // .cfg_interrupt_msix_vf_mask(cfg_interrupt_msix_vf_mask),
    // .cfg_interrupt_msix_address(cfg_interrupt_msix_address),
    // .cfg_interrupt_msix_data(cfg_interrupt_msix_data),
    // .cfg_interrupt_msix_int(cfg_interrupt_msix_int),
    // .cfg_interrupt_msix_vec_pending(cfg_interrupt_msix_vec_pending),
    // .cfg_interrupt_msix_vec_pending_status(cfg_interrupt_msix_vec_pending_status),
    // .cfg_interrupt_msix_sent(cfg_interrupt_msix_sent),
    // .cfg_interrupt_msix_fail(cfg_interrupt_msix_fail),
    // .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number),

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
    .cfg_interrupt_msi_function_number(cfg_interrupt_msi_function_number)
);

endmodule

`resetall
