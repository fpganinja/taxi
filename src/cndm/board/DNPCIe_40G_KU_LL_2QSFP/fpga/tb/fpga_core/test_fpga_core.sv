// SPDX-License-Identifier: MIT
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic testbench
 */
module test_fpga_core #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter logic SIM = 1'b0,
    parameter string VENDOR = "XILINX",
    parameter string FAMILY = "kintexu",

    // FW ID
    parameter FPGA_ID = 32'h3822093,
    parameter FW_ID = 32'h0000C001,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h17df_1a00,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,

    // PCIe interface configuration
    parameter AXIS_PCIE_DATA_W = 256,
    parameter AXIS_PCIE_RC_USER_W = 75,
    parameter AXIS_PCIE_RQ_USER_W = 60,
    parameter AXIS_PCIE_CQ_USER_W = 85,
    parameter AXIS_PCIE_CC_USER_W = 33,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_W = 32,
    parameter AXIL_CTRL_ADDR_W = 24,

    // MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 32
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam AXIS_PCIE_KEEP_W = (AXIS_PCIE_DATA_W/32);
localparam RQ_SEQ_NUM_W = AXIS_PCIE_RQ_USER_W == 60 ? 4 : 6;

logic clk_125mhz;
logic rst_125mhz;

logic [7:0] user_led;
logic qsfp0_led_green;
logic qsfp0_led_red;
logic qsfp1_led_green;
logic qsfp1_led_red;

logic uart_rxd;
logic uart_txd;

logic qsfp0_mgt_refclk_p;
logic qsfp0_mgt_refclk_n;
logic [1:0] qsfp0_fs;
logic qsfp0_modsell;
logic qsfp0_resetl;
logic qsfp0_modprsl;
logic qsfp0_intl;
logic qsfp0_lpmode;

// logic qsfp1_mgt_refclk_p;
// logic qsfp1_mgt_refclk_n;
logic [1:0] qsfp1_fs;
logic qsfp1_modsell;
logic qsfp1_resetl;
logic qsfp1_modprsl;
logic qsfp1_intl;
logic qsfp1_lpmode;

logic pcie_clk;
logic pcie_rst;

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_CQ_USER_W)
) s_axis_pcie_cq();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_CC_USER_W)
) m_axis_pcie_cc();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_RQ_USER_W)
) m_axis_pcie_rq();

taxi_axis_if #(
    .DATA_W(AXIS_PCIE_DATA_W),
    .KEEP_EN(1),
    .KEEP_W(AXIS_PCIE_KEEP_W),
    .USER_EN(1),
    .USER_W(AXIS_PCIE_RC_USER_W)
) s_axis_pcie_rc();

logic [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num;
logic pcie_rq_seq_num_vld;

logic [2:0] cfg_max_payload;
logic [2:0] cfg_max_read_req;
logic [3:0] cfg_rcb_status;

logic [18:0] cfg_mgmt_addr;
logic        cfg_mgmt_write;
logic [31:0] cfg_mgmt_write_data;
logic [3:0]  cfg_mgmt_byte_enable;
logic        cfg_mgmt_read;
logic [31:0] cfg_mgmt_read_data;
logic        cfg_mgmt_read_write_done;

logic [7:0]  cfg_fc_ph;
logic [11:0] cfg_fc_pd;
logic [7:0]  cfg_fc_nph;
logic [11:0] cfg_fc_npd;
logic [7:0]  cfg_fc_cplh;
logic [11:0] cfg_fc_cpld;
logic [2:0]  cfg_fc_sel;

logic        cfg_ext_read_received;
logic        cfg_ext_write_received;
logic [9:0]  cfg_ext_register_number;
logic [7:0]  cfg_ext_function_number;
logic [31:0] cfg_ext_write_data;
logic [3:0]  cfg_ext_write_byte_enable;
logic [31:0] cfg_ext_read_data;
logic        cfg_ext_read_data_valid;

logic [3:0]   cfg_interrupt_msi_enable;
logic [11:0]  cfg_interrupt_msi_mmenable;
logic         cfg_interrupt_msi_mask_update;
logic [31:0]  cfg_interrupt_msi_data;
logic [3:0]   cfg_interrupt_msi_select;
logic [31:0]  cfg_interrupt_msi_int;
logic [31:0]  cfg_interrupt_msi_pending_status;
logic         cfg_interrupt_msi_pending_status_data_enable;
logic [3:0]   cfg_interrupt_msi_pending_status_function_num;
logic         cfg_interrupt_msi_sent;
logic         cfg_interrupt_msi_fail;
logic [2:0]   cfg_interrupt_msi_attr;
logic         cfg_interrupt_msi_tph_present;
logic [1:0]   cfg_interrupt_msi_tph_type;
logic [8:0]   cfg_interrupt_msi_tph_st_tag;
logic [3:0]   cfg_interrupt_msi_function_number;

logic        fpga_boot;
logic [15:0] flash_dq_i;
logic [15:0] flash_dq_o;
logic        flash_dq_oe;
logic [23:0] flash_addr;
logic [1:0]  flash_region;
logic        flash_region_oe;
logic        flash_ce_n;
logic        flash_oe_n;
logic        flash_we_n;
logic        flash_adv_n;

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
uut (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk_125mhz(clk_125mhz),
    .rst_125mhz(rst_125mhz),

    /*
     * GPIO
     */
    .user_led(user_led),
    .qsfp0_led_green(qsfp0_led_green),
    .qsfp0_led_red(qsfp0_led_red),
    .qsfp1_led_green(qsfp1_led_green),
    .qsfp1_led_red(qsfp1_led_red),

    /*
     * UART: 115200 bps, 8N1
     */
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),

    /*
     * Ethernet: QSFP+
     */
    .qsfp0_rx_p('{4{1'b0}}),
    .qsfp0_rx_n('{4{1'b0}}),
    .qsfp0_tx_p(),
    .qsfp0_tx_n(),
    .qsfp0_mgt_refclk_p(qsfp0_mgt_refclk_p),
    .qsfp0_mgt_refclk_n(qsfp0_mgt_refclk_n),
    .qsfp0_fs(qsfp0_fs),
    .qsfp0_modsell(qsfp0_modsell),
    .qsfp0_resetl(qsfp0_resetl),
    .qsfp0_modprsl(qsfp0_modprsl),
    .qsfp0_intl(qsfp0_intl),
    .qsfp0_lpmode(qsfp0_lpmode),

    .qsfp1_rx_p('{4{1'b0}}),
    .qsfp1_rx_n('{4{1'b0}}),
    .qsfp1_tx_p(),
    .qsfp1_tx_n(),
    // .qsfp1_mgt_refclk_p(qsfp1_mgt_refclk_p),
    // .qsfp1_mgt_refclk_n(qsfp1_mgt_refclk_n),
    .qsfp1_fs(qsfp1_fs),
    .qsfp1_modsell(qsfp1_modsell),
    .qsfp1_resetl(qsfp1_resetl),
    .qsfp1_modprsl(qsfp1_modprsl),
    .qsfp1_intl(qsfp1_intl),
    .qsfp1_lpmode(qsfp1_lpmode),

    /*
     * PCIe
     */
    .pcie_clk(pcie_clk),
    .pcie_rst(pcie_rst),
    .s_axis_pcie_cq(s_axis_pcie_cq),
    .m_axis_pcie_cc(m_axis_pcie_cc),
    .m_axis_pcie_rq(m_axis_pcie_rq),
    .s_axis_pcie_rc(s_axis_pcie_rc),

    .pcie_rq_seq_num(pcie_rq_seq_num),
    .pcie_rq_seq_num_vld(pcie_rq_seq_num_vld),

    .cfg_max_payload(cfg_max_payload),
    .cfg_max_read_req(cfg_max_read_req),
    .cfg_rcb_status(cfg_rcb_status),

    .cfg_mgmt_addr(cfg_mgmt_addr),
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

    .cfg_ext_read_received(cfg_ext_read_received),
    .cfg_ext_write_received(cfg_ext_write_received),
    .cfg_ext_register_number(cfg_ext_register_number),
    .cfg_ext_function_number(cfg_ext_function_number),
    .cfg_ext_write_data(cfg_ext_write_data),
    .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    .cfg_ext_read_data(cfg_ext_read_data),
    .cfg_ext_read_data_valid(cfg_ext_read_data_valid),

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
     * QSPI flash
     */
    .fpga_boot(fpga_boot),
    .flash_dq_i(flash_dq_i),
    .flash_dq_o(flash_dq_o),
    .flash_dq_oe(flash_dq_oe),
    .flash_addr(flash_addr),
    .flash_region(flash_region),
    .flash_region_oe(flash_region_oe),
    .flash_ce_n(flash_ce_n),
    .flash_oe_n(flash_oe_n),
    .flash_we_n(flash_we_n),
    .flash_adv_n(flash_adv_n)
);

endmodule

`resetall
