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
 * FPGA core logic testbench
 */
module test_fpga_core #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter logic SIM = 1'b0,
    parameter string VENDOR = "XILINX",
    parameter string FAMILY = "kintexuplus",
    parameter AXIS_PCIE_DATA_W = 256,
    parameter AXIS_PCIE_RC_USER_W = AXIS_PCIE_DATA_W < 512 ? 75 : 161,
    parameter AXIS_PCIE_RQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 62 : 137,
    parameter AXIS_PCIE_CQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 85 : 183,
    parameter AXIS_PCIE_CC_USER_W = AXIS_PCIE_DATA_W < 512 ? 33 : 81,
    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,
    // 10G/25G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam AXIS_PCIE_KEEP_W = (AXIS_PCIE_DATA_W/32);
localparam RQ_SEQ_NUM_W = AXIS_PCIE_RQ_USER_W == 60 ? 4 : 6;

logic        clk_125mhz;
logic        rst_125mhz;

logic        sfp_led[2];
logic [3:0]  led;
logic        led_r;
logic        led_g;
logic        led_hb;

logic sfp_mgt_refclk_p;
logic sfp_mgt_refclk_n;
logic sfp_mgt_refclk_out;

logic [1:0] sfp_npres;
logic [1:0] sfp_tx_fault;
logic [1:0] sfp_los;

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

logic [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num0;
logic pcie_rq_seq_num_vld0;
logic [RQ_SEQ_NUM_W-1:0] pcie_rq_seq_num1;
logic pcie_rq_seq_num_vld1;

logic [2:0] cfg_max_payload;
logic [2:0] cfg_max_read_req;
logic [3:0] cfg_rcb_status;

logic [9:0]  cfg_mgmt_addr;
logic [7:0]  cfg_mgmt_function_number;
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

logic [3:0]   cfg_interrupt_msi_enable;
logic [11:0]  cfg_interrupt_msi_mmenable;
logic         cfg_interrupt_msi_mask_update;
logic [31:0]  cfg_interrupt_msi_data;
logic [1:0]   cfg_interrupt_msi_select;
logic [31:0]  cfg_interrupt_msi_int;
logic [31:0]  cfg_interrupt_msi_pending_status;
logic         cfg_interrupt_msi_pending_status_data_enable;
logic [1:0]   cfg_interrupt_msi_pending_status_function_num;
logic         cfg_interrupt_msi_sent;
logic         cfg_interrupt_msi_fail;
logic [2:0]   cfg_interrupt_msi_attr;
logic         cfg_interrupt_msi_tph_present;
logic [1:0]   cfg_interrupt_msi_tph_type;
logic [7:0]   cfg_interrupt_msi_tph_st_tag;
logic [7:0]   cfg_interrupt_msi_function_number;

fpga_core #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),
    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),
    // 10G/25G MAC configuration
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
    .sfp_led(sfp_led),
    .led(led),
    .led_r(led_r),
    .led_g(led_g),
    .led_hb(led_hb),

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
     * Ethernet: SFP+
     */
    .sfp_rx_p(),
    .sfp_rx_n(),
    .sfp_tx_p('{2{1'b0}}),
    .sfp_tx_n('{2{1'b0}}),
    .sfp_mgt_refclk_p(sfp_mgt_refclk_p),
    .sfp_mgt_refclk_n(sfp_mgt_refclk_n),
    .sfp_mgt_refclk_out(sfp_mgt_refclk_out),
    .sfp_npres(sfp_npres),
    .sfp_tx_fault(sfp_tx_fault),
    .sfp_los(sfp_los)
);

endmodule

`resetall
