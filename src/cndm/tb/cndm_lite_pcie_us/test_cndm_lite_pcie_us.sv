// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic testbench
 */
module test_cndm_lite_pcie_us #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter logic SIM = 1'b0,
    parameter string VENDOR = "XILINX",
    parameter string FAMILY = "virtexuplus",

    // FW ID
    parameter FPGA_ID = 32'hDEADBEEF,
    parameter FW_ID = 32'h0000C002,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h1234_0000,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // Structural configuration
    parameter PORTS = 2,
    parameter logic BRD_CTRL_EN = 1'b0,
    parameter SYS_CLK_PER_NS_NUM = 4,
    parameter SYS_CLK_PER_NS_DEN = 1,

    // Queue configuration
    parameter WQN_W = 5,
    parameter CQN_W = WQN_W,

    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,
    parameter logic PTP_TS_FMT_TOD = 1'b0,
    parameter PTP_CLK_PER_NS_NUM = 512,
    parameter PTP_CLK_PER_NS_DEN = 165,

    // PCIe interface configuration
    parameter AXIS_PCIE_DATA_W = 512,
    parameter AXIS_PCIE_RC_USER_W = AXIS_PCIE_DATA_W < 512 ? 75 : 161,
    parameter AXIS_PCIE_RQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 62 : 137,
    parameter AXIS_PCIE_CQ_USER_W = AXIS_PCIE_DATA_W < 512 ? 85 : 183,
    parameter AXIS_PCIE_CC_USER_W = AXIS_PCIE_DATA_W < 512 ? 33 : 81,

    // AXI lite interface configuration (control)
    parameter AXIL_CTRL_DATA_W = 32,
    parameter AXIL_CTRL_ADDR_W = 24,

    // MAC configuration
    parameter MAC_DATA_W = 512
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 48;

localparam AXIS_PCIE_KEEP_W = (AXIS_PCIE_DATA_W/32);
localparam RQ_SEQ_NUM_W = AXIS_PCIE_RQ_USER_W == 60 ? 4 : 6;

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

taxi_axis_if #(
    .DATA_W(32),
    .KEEP_EN(1),
    .ID_EN(1),
    .ID_W(4),
    .USER_EN(1),
    .USER_W(1)
) m_axis_brd_ctrl_cmd(), s_axis_brd_ctrl_rsp();

logic        ptp_rst;
logic        ptp_clk;
logic        ptp_sample_clk;
logic        ptp_td_sdo;
logic        ptp_pps;
logic        ptp_pps_str;
logic        ptp_sync_locked;
logic [63:0] ptp_sync_ts_rel;
logic        ptp_sync_ts_rel_step;
logic [95:0] ptp_sync_ts_tod;
logic        ptp_sync_ts_tod_step;
logic        ptp_sync_pps;
logic        ptp_sync_pps_str;

logic mac_tx_clk[PORTS];
logic mac_tx_rst[PORTS];

taxi_axis_if #(
    .DATA_W(MAC_DATA_W),
    .ID_W(8),
    .USER_EN(1),
    .USER_W(1)
) mac_axis_tx[PORTS]();

logic mac_rx_clk[PORTS];
logic mac_rx_rst[PORTS];

taxi_axis_if #(
    .DATA_W(PTP_TS_W),
    .KEEP_W(1),
    .ID_W(8)
) mac_axis_tx_cpl[PORTS]();

taxi_axis_if #(
    .DATA_W(MAC_DATA_W),
    .ID_W(8),
    .USER_EN(1),
    .USER_W(PTP_TS_W+1)
) mac_axis_rx[PORTS]();

// PTP leaf clocks for MAC timestamping
logic [PTP_TS_W-1:0] tx_ptp_time[PORTS];
logic tx_ptp_step[PORTS];
logic [PTP_TS_W-1:0] rx_ptp_time[PORTS];
logic rx_ptp_step[PORTS];

if (PTP_TS_EN) begin : ptp

    for (genvar n = 0; n < PORTS; n = n + 1) begin : ch

        // TX
        wire [PTP_TS_W-1:0] tx_ptp_ts_rel;
        wire tx_ptp_ts_rel_step;
        wire [PTP_TS_W-1:0] tx_ptp_ts_tod;
        wire tx_ptp_ts_tod_step;

        taxi_ptp_td_leaf #(
            .TS_REL_EN(!PTP_TS_FMT_TOD),
            .TS_TOD_EN(PTP_TS_FMT_TOD),
            .TS_FNS_W(16),
            .TS_REL_NS_W(PTP_TS_FMT_TOD ? 48 : PTP_TS_W-16),
            .TS_TOD_S_W(PTP_TS_FMT_TOD ? PTP_TS_W-32-16 : 48),
            .TS_REL_W(PTP_TS_W),
            .TS_TOD_W(PTP_TS_W),
            .TD_SDI_PIPELINE(2)
        )
        tx_leaf_inst (
            .clk(mac_tx_clk[n]),
            .rst(mac_tx_rst[n]),
            .sample_clk(ptp_sample_clk),

            /*
             * PTP clock interface
             */
            .ptp_clk(ptp_clk),
            .ptp_rst(ptp_rst),
            .ptp_td_sdi(ptp_td_sdo),

            /*
             * Timestamp output
             */
            .output_ts_rel(tx_ptp_ts_rel),
            .output_ts_rel_step(tx_ptp_ts_rel_step),
            .output_ts_tod(tx_ptp_ts_tod),
            .output_ts_tod_step(tx_ptp_ts_tod_step),

            /*
             * PPS output (ToD format only)
             */
            .output_pps(),
            .output_pps_str(),

            /*
             * Status
             */
            .locked()
        );

        assign tx_ptp_time[n] = PTP_TS_FMT_TOD ? tx_ptp_ts_tod : tx_ptp_ts_rel;
        assign tx_ptp_step[n] = PTP_TS_FMT_TOD ? tx_ptp_ts_tod_step : tx_ptp_ts_rel_step;

        // RX
        wire [PTP_TS_W-1:0] rx_ptp_ts_rel;
        wire rx_ptp_ts_rel_step;
        wire [PTP_TS_W-1:0] rx_ptp_ts_tod;
        wire rx_ptp_ts_tod_step;

        taxi_ptp_td_leaf #(
            .TS_REL_EN(!PTP_TS_FMT_TOD),
            .TS_TOD_EN(PTP_TS_FMT_TOD),
            .TS_FNS_W(16),
            .TS_REL_NS_W(PTP_TS_FMT_TOD ? 48 : PTP_TS_W-16),
            .TS_TOD_S_W(PTP_TS_FMT_TOD ? PTP_TS_W-32-16 : 48),
            .TS_REL_W(PTP_TS_W),
            .TS_TOD_W(PTP_TS_W),
            .TD_SDI_PIPELINE(2)
        )
        rx_leaf_inst (
            .clk(mac_rx_clk[n]),
            .rst(mac_rx_rst[n]),
            .sample_clk(ptp_sample_clk),

            /*
             * PTP clock interface
             */
            .ptp_clk(ptp_clk),
            .ptp_rst(ptp_rst),
            .ptp_td_sdi(ptp_td_sdo),

            /*
             * Timestamp output
             */
            .output_ts_rel(rx_ptp_ts_rel),
            .output_ts_rel_step(rx_ptp_ts_rel_step),
            .output_ts_tod(rx_ptp_ts_tod),
            .output_ts_tod_step(rx_ptp_ts_tod_step),

            /*
             * PPS output (ToD format only)
             */
            .output_pps(),
            .output_pps_str(),

            /*
             * Status
             */
            .locked()
        );

        assign rx_ptp_time[n] = PTP_TS_FMT_TOD ? rx_ptp_ts_tod : rx_ptp_ts_rel;
        assign rx_ptp_step[n] = PTP_TS_FMT_TOD ? rx_ptp_ts_tod_step : rx_ptp_ts_rel_step;

    end

end

cndm_lite_pcie_us #(
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
    .PORTS(PORTS),
    .BRD_CTRL_EN(BRD_CTRL_EN),
    .SYS_CLK_PER_NS_NUM(SYS_CLK_PER_NS_NUM),
    .SYS_CLK_PER_NS_DEN(SYS_CLK_PER_NS_DEN),

    // Queue configuration
    .WQN_W(WQN_W),
    .CQN_W(CQN_W),

    // PTP configuration
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
    .PTP_CLK_PER_NS_NUM(PTP_CLK_PER_NS_NUM),
    .PTP_CLK_PER_NS_DEN(PTP_CLK_PER_NS_DEN),

    // PCIe interface configuration
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),

    // AXI lite interface configuration (control)
    .AXIL_CTRL_DATA_W(AXIL_CTRL_DATA_W),
    .AXIL_CTRL_ADDR_W(AXIL_CTRL_ADDR_W)
)
uut (
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
     * Board control
     */
    .m_axis_brd_ctrl_cmd(m_axis_brd_ctrl_cmd),
    .s_axis_brd_ctrl_rsp(s_axis_brd_ctrl_rsp),

    /*
     * PTP
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sdo(ptp_td_sdo),
    .ptp_pps(ptp_pps),
    .ptp_pps_str(ptp_pps_str),
    .ptp_sync_locked(ptp_sync_locked),
    .ptp_sync_ts_rel(ptp_sync_ts_rel),
    .ptp_sync_ts_rel_step(ptp_sync_ts_rel_step),
    .ptp_sync_ts_tod(ptp_sync_ts_tod),
    .ptp_sync_ts_tod_step(ptp_sync_ts_tod_step),
    .ptp_sync_pps(ptp_sync_pps),
    .ptp_sync_pps_str(ptp_sync_pps_str),

    /*
     * Ethernet: SFP+
     */
    .mac_tx_clk(mac_tx_clk),
    .mac_tx_rst(mac_tx_rst),
    .mac_axis_tx(mac_axis_tx),
    .mac_axis_tx_cpl(mac_axis_tx_cpl),

    .mac_rx_clk(mac_rx_clk),
    .mac_rx_rst(mac_rx_rst),
    .mac_axis_rx(mac_axis_rx)
);

endmodule

`resetall
