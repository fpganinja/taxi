// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Corundum-micro core logic for UltraScale PCIe
 */
module cndm_micro_pcie_us #(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtexuplus",
    parameter PORTS = 2,
    parameter RQ_SEQ_NUM_W = 6,
    parameter BAR0_APERTURE = 24
)
(
    /*
     * PCIe
     */
    input  wire logic               pcie_clk,
    input  wire logic               pcie_rst,
    taxi_axis_if.snk                s_axis_pcie_cq,
    taxi_axis_if.src                m_axis_pcie_cc,
    taxi_axis_if.src                m_axis_pcie_rq,
    taxi_axis_if.snk                s_axis_pcie_rc,

    input  wire [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num0,
    input  wire                     pcie_rq_seq_num_vld0,
    input  wire [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num1,
    input  wire                     pcie_rq_seq_num_vld1,

    input  wire [2:0]               cfg_max_payload,
    input  wire [2:0]               cfg_max_read_req,
    input  wire [3:0]               cfg_rcb_status,

    output wire [9:0]               cfg_mgmt_addr,
    output wire [7:0]               cfg_mgmt_function_number,
    output wire                     cfg_mgmt_write,
    output wire [31:0]              cfg_mgmt_write_data,
    output wire [3:0]               cfg_mgmt_byte_enable,
    output wire                     cfg_mgmt_read,
    input  wire [31:0]              cfg_mgmt_read_data,
    input  wire                     cfg_mgmt_read_write_done,

    input  wire [7:0]               cfg_fc_ph,
    input  wire [11:0]              cfg_fc_pd,
    input  wire [7:0]               cfg_fc_nph,
    input  wire [11:0]              cfg_fc_npd,
    input  wire [7:0]               cfg_fc_cplh,
    input  wire [11:0]              cfg_fc_cpld,
    output wire [2:0]               cfg_fc_sel,

    input  wire [3:0]               cfg_interrupt_msi_enable,
    input  wire [11:0]              cfg_interrupt_msi_mmenable,
    input  wire                     cfg_interrupt_msi_mask_update,
    input  wire [31:0]              cfg_interrupt_msi_data,
    output wire [1:0]               cfg_interrupt_msi_select,
    output wire [31:0]              cfg_interrupt_msi_int,
    output wire [31:0]              cfg_interrupt_msi_pending_status,
    output wire                     cfg_interrupt_msi_pending_status_data_enable,
    output wire [1:0]               cfg_interrupt_msi_pending_status_function_num,
    input  wire                     cfg_interrupt_msi_sent,
    input  wire                     cfg_interrupt_msi_fail,
    output wire [2:0]               cfg_interrupt_msi_attr,
    output wire                     cfg_interrupt_msi_tph_present,
    output wire [1:0]               cfg_interrupt_msi_tph_type,
    output wire [7:0]               cfg_interrupt_msi_tph_st_tag,
    output wire [7:0]               cfg_interrupt_msi_function_number,

    /*
     * Ethernet
     */
    input  wire logic               mac_tx_clk[PORTS],
    input  wire logic               mac_tx_rst[PORTS],
    taxi_axis_if.src                mac_axis_tx[PORTS],
    taxi_axis_if.snk                mac_axis_tx_cpl[PORTS],

    input  wire logic               mac_rx_clk[PORTS],
    input  wire logic               mac_rx_rst[PORTS],
    taxi_axis_if.snk                mac_axis_rx[PORTS]
);

localparam CL_PORTS = $clog2(PORTS);

localparam AXIL_DATA_W = 32;
localparam AXIL_ADDR_W = BAR0_APERTURE;

taxi_axil_if #(
    .DATA_W(AXIL_DATA_W),
    .ADDR_W(AXIL_ADDR_W),
    .AWUSER_EN(1'b0),
    .WUSER_EN(1'b0),
    .BUSER_EN(1'b0),
    .ARUSER_EN(1'b0),
    .RUSER_EN(1'b0)
) axil_ctrl_bar();

taxi_pcie_us_axil_master
pcie_axil_master_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * UltraScale PCIe interface
     */
    .s_axis_cq(s_axis_pcie_cq),
    .m_axis_cc(m_axis_pcie_cc),

    /*
     * AXI Lite Master output
     */
    .m_axil_wr(axil_ctrl_bar),
    .m_axil_rd(axil_ctrl_bar),

    /*
     * Configuration
     */
    .completer_id('0),
    .completer_id_en(1'b0),

    /*
     * Status
     */
    .stat_err_cor(),
    .stat_err_uncor()
);

localparam AXIS_PCIE_DATA_W = m_axis_pcie_rq.DATA_W;

localparam PCIE_ADDR_W = 64;

// TODO
localparam logic RQ_SEQ_NUM_EN = 1'b1;
localparam RAM_SEL_W = 2+CL_PORTS;
localparam RAM_ADDR_W = 16;
localparam RAM_SEGS = 2;//AXIS_PCIE_DATA_W > 256 ? AXIS_PCIE_DATA_W / 128 : 2;
localparam PCIE_TAG_CNT = 64;//AXIS_PCIE_RQ_USER_W == 60 ? 64 : 256,
localparam logic IMM_EN = 1'b0;
localparam IMM_W = 32;
localparam LEN_W = 20;
localparam TAG_W = 8;
localparam RD_OP_TBL_SIZE = PCIE_TAG_CNT;
localparam RD_TX_LIMIT = 2**(RQ_SEQ_NUM_W-1);
localparam logic RD_TX_FC_EN = 1'b1;
localparam RD_CPLH_FC_LIMIT = 512;
localparam RD_CPLD_FC_LIMIT = RD_CPLH_FC_LIMIT*4;
localparam WR_OP_TBL_SIZE = 2**(RQ_SEQ_NUM_W-1);
localparam WR_TX_LIMIT = 2**(RQ_SEQ_NUM_W-1);
localparam logic WR_TX_FC_EN = 1'b1;

localparam RAM_DATA_W = AXIS_PCIE_DATA_W*2;
localparam RAM_SEG_DATA_W = RAM_DATA_W / RAM_SEGS;
localparam RAM_SEG_BE_W = RAM_SEG_DATA_W / 8;
localparam RAM_SEG_ADDR_W = RAM_ADDR_W - $clog2(RAM_SEGS*RAM_SEG_BE_W);

logic [RQ_SEQ_NUM_W-1:0] s_axis_rq_seq_num_0;
logic                    s_axis_rq_seq_num_valid_0;
logic [RQ_SEQ_NUM_W-1:0] s_axis_rq_seq_num_1;
logic                    s_axis_rq_seq_num_valid_1;

logic [7:0] pcie_tx_fc_nph_av;
logic [7:0] pcie_tx_fc_ph_av;
logic [11:0] pcie_tx_fc_pd_av;

logic ext_tag_en;

assign cfg_fc_sel = 3'b100;

taxi_dma_desc_if #(
    .SRC_ADDR_W(PCIE_ADDR_W),
    .SRC_SEL_EN(1'b0),
    .SRC_ASID_EN(1'b0),
    .DST_ADDR_W(RAM_ADDR_W),
    .DST_SEL_EN(1'b1),
    .DST_SEL_W(RAM_SEL_W),
    .DST_ASID_EN(1'b0),
    .IMM_EN(1'b0),
    .LEN_W(LEN_W),
    .TAG_W(TAG_W),
    .ID_EN(1'b0),
    .DEST_EN(1'b0),
    .USER_EN(1'b0)
) dma_rd_desc();

taxi_dma_desc_if #(
    .SRC_ADDR_W(RAM_ADDR_W),
    .SRC_SEL_EN(1'b1),
    .SRC_SEL_W(RAM_SEL_W),
    .SRC_ASID_EN(1'b0),
    .DST_ADDR_W(PCIE_ADDR_W),
    .DST_SEL_EN(1'b0),
    .DST_ASID_EN(1'b0),
    .IMM_EN(IMM_EN),
    .IMM_W(IMM_W),
    .LEN_W(LEN_W),
    .TAG_W(TAG_W),
    .ID_EN(1'b0),
    .DEST_EN(1'b0),
    .USER_EN(1'b0)
) dma_wr_desc();

taxi_dma_ram_if #(
    .SEGS(RAM_SEGS),
    .SEG_ADDR_W(RAM_SEG_ADDR_W),
    .SEG_DATA_W(RAM_SEG_DATA_W),
    .SEG_BE_W(RAM_SEG_BE_W),
    .SEL_W(RAM_SEL_W)
) dma_ram();

logic stat_rd_busy;
logic stat_wr_busy;
logic stat_err_cor;
logic stat_err_uncor;

logic [$clog2(RD_OP_TBL_SIZE)-1:0]  stat_rd_op_start_tag;
logic                               stat_rd_op_start_valid;
logic [$clog2(RD_OP_TBL_SIZE)-1:0]  stat_rd_op_finish_tag;
logic [3:0]                         stat_rd_op_finish_status;
logic                               stat_rd_op_finish_valid;
logic [$clog2(PCIE_TAG_CNT)-1:0]    stat_rd_req_start_tag;
logic [12:0]                        stat_rd_req_start_len;
logic                               stat_rd_req_start_valid;
logic [$clog2(PCIE_TAG_CNT)-1:0]    stat_rd_req_finish_tag;
logic [3:0]                         stat_rd_req_finish_status;
logic                               stat_rd_req_finish_valid;
logic                               stat_rd_req_timeout;
logic                               stat_rd_op_tbl_full;
logic                               stat_rd_no_tags;
logic                               stat_rd_tx_limit;
logic                               stat_rd_tx_stall;
logic [$clog2(WR_OP_TBL_SIZE)-1:0]  stat_wr_op_start_tag;
logic                               stat_wr_op_start_valid;
logic [$clog2(WR_OP_TBL_SIZE)-1:0]  stat_wr_op_finish_tag;
logic [3:0]                         stat_wr_op_finish_status;
logic                               stat_wr_op_finish_valid;
logic [$clog2(WR_OP_TBL_SIZE)-1:0]  stat_wr_req_start_tag;
logic [12:0]                        stat_wr_req_start_len;
logic                               stat_wr_req_start_valid;
logic [$clog2(WR_OP_TBL_SIZE)-1:0]  stat_wr_req_finish_tag;
logic [3:0]                         stat_wr_req_finish_status;
logic                               stat_wr_req_finish_valid;
logic                               stat_wr_op_tbl_full;
logic                               stat_wr_tx_limit;
logic                               stat_wr_tx_stall;

// register to break timing path from PCIe HIP 500 MHz clock domain
logic [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num0_reg = '0;
logic                     pcie_rq_seq_num_vld0_reg = 1'b0;
logic [RQ_SEQ_NUM_W-1:0]  pcie_rq_seq_num1_reg = '0;
logic                     pcie_rq_seq_num_vld1_reg = 1'b0;

always_ff @(posedge pcie_clk) begin
    pcie_rq_seq_num0_reg <= pcie_rq_seq_num0;
    pcie_rq_seq_num_vld0_reg <= pcie_rq_seq_num_vld0;
    pcie_rq_seq_num1_reg <= pcie_rq_seq_num1;
    pcie_rq_seq_num_vld1_reg <= pcie_rq_seq_num_vld1;

    if (pcie_rst) begin
        pcie_rq_seq_num_vld0_reg <= 1'b0;
        pcie_rq_seq_num_vld1_reg <= 1'b0;
    end
end

taxi_dma_if_pcie_us #(
    .RQ_SEQ_NUM_W(RQ_SEQ_NUM_W),
    .RQ_SEQ_NUM_EN(RQ_SEQ_NUM_EN),
    .PCIE_TAG_CNT(PCIE_TAG_CNT),
    .RD_OP_TBL_SIZE(RD_OP_TBL_SIZE),
    .RD_TX_LIMIT(RD_TX_LIMIT),
    .RD_TX_FC_EN(RD_TX_FC_EN),
    .RD_CPLH_FC_LIMIT(RD_CPLH_FC_LIMIT),
    .RD_CPLD_FC_LIMIT(RD_CPLD_FC_LIMIT),
    .WR_OP_TBL_SIZE(WR_OP_TBL_SIZE),
    .WR_TX_LIMIT(WR_TX_LIMIT),
    .WR_TX_FC_EN(WR_TX_FC_EN)
)
dma_if_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * UltraScale PCIe interface
     */
    .m_axis_rq(m_axis_pcie_rq),
    .s_axis_rc(s_axis_pcie_rc),

    /*
     * Transmit sequence number input
     */
    .s_axis_rq_seq_num_0(pcie_rq_seq_num0_reg),
    .s_axis_rq_seq_num_valid_0(pcie_rq_seq_num_vld0_reg),
    .s_axis_rq_seq_num_1(pcie_rq_seq_num1_reg),
    .s_axis_rq_seq_num_valid_1(pcie_rq_seq_num_vld1_reg),

    /*
     * Transmit flow control
     */
    .pcie_tx_fc_nph_av(cfg_fc_nph),
    .pcie_tx_fc_ph_av(cfg_fc_ph),
    .pcie_tx_fc_pd_av(cfg_fc_pd),

    /*
     * Read descriptor
     */
    .rd_desc_req(dma_rd_desc),
    .rd_desc_sts(dma_rd_desc),

    /*
     * Write descriptor
     */
    .wr_desc_req(dma_wr_desc),
    .wr_desc_sts(dma_wr_desc),

    /*
     * RAM interface
     */
    .dma_ram_wr(dma_ram),
    .dma_ram_rd(dma_ram),

    /*
     * Configuration
     */
    .read_enable(1'b1),
    .write_enable(1'b1),
    .ext_tag_en(ext_tag_en),
    .rcb_128b(cfg_rcb_status[0]),
    .requester_id('0),
    .requester_id_en(1'b0),
    .max_rd_req_size(cfg_max_read_req),
    .max_payload_size(cfg_max_payload),

    /*
     * Status
     */
    .stat_rd_busy(stat_rd_busy),
    .stat_wr_busy(stat_wr_busy),
    .stat_err_cor(stat_err_cor),
    .stat_err_uncor(stat_err_uncor),

    /*
     * Statistics
     */
    .stat_rd_op_start_tag(stat_rd_op_start_tag),
    .stat_rd_op_start_valid(stat_rd_op_start_valid),
    .stat_rd_op_finish_tag(stat_rd_op_finish_tag),
    .stat_rd_op_finish_status(stat_rd_op_finish_status),
    .stat_rd_op_finish_valid(stat_rd_op_finish_valid),
    .stat_rd_req_start_tag(stat_rd_req_start_tag),
    .stat_rd_req_start_len(stat_rd_req_start_len),
    .stat_rd_req_start_valid(stat_rd_req_start_valid),
    .stat_rd_req_finish_tag(stat_rd_req_finish_tag),
    .stat_rd_req_finish_status(stat_rd_req_finish_status),
    .stat_rd_req_finish_valid(stat_rd_req_finish_valid),
    .stat_rd_req_timeout(stat_rd_req_timeout),
    .stat_rd_op_tbl_full(stat_rd_op_tbl_full),
    .stat_rd_no_tags(stat_rd_no_tags),
    .stat_rd_tx_limit(stat_rd_tx_limit),
    .stat_rd_tx_stall(stat_rd_tx_stall),
    .stat_wr_op_start_tag(stat_wr_op_start_tag),
    .stat_wr_op_start_valid(stat_wr_op_start_valid),
    .stat_wr_op_finish_tag(stat_wr_op_finish_tag),
    .stat_wr_op_finish_status(stat_wr_op_finish_status),
    .stat_wr_op_finish_valid(stat_wr_op_finish_valid),
    .stat_wr_req_start_tag(stat_wr_req_start_tag),
    .stat_wr_req_start_len(stat_wr_req_start_len),
    .stat_wr_req_start_valid(stat_wr_req_start_valid),
    .stat_wr_req_finish_tag(stat_wr_req_finish_tag),
    .stat_wr_req_finish_status(stat_wr_req_finish_status),
    .stat_wr_req_finish_valid(stat_wr_req_finish_valid),
    .stat_wr_op_tbl_full(stat_wr_op_tbl_full),
    .stat_wr_tx_limit(stat_wr_tx_limit),
    .stat_wr_tx_stall(stat_wr_tx_stall)
);

taxi_pcie_us_cfg #(
    .PF_COUNT(1),
    .VF_COUNT(0),
    .VF_OFFSET(m_axis_pcie_rq.USER_W == 60 ? 64 : 4),
    .PCIE_CAP_OFFSET(m_axis_pcie_rq.USER_W == 60 ? 12'h0C0 : 12'h070)
)
cfg_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * Configuration outputs
     */
    .ext_tag_en(ext_tag_en),
    .max_read_req_size(),
    .max_payload_size(),

    /*
     * Interface to Ultrascale PCIe IP core
     */
    .cfg_mgmt_addr(cfg_mgmt_addr),
    .cfg_mgmt_function_number(cfg_mgmt_function_number),
    .cfg_mgmt_write(cfg_mgmt_write),
    .cfg_mgmt_write_data(cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable(cfg_mgmt_byte_enable),
    .cfg_mgmt_read(cfg_mgmt_read),
    .cfg_mgmt_read_data(cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done(cfg_mgmt_read_write_done)
);

wire [PORTS-1:0] irq;
wire [31:0] msi_irq = 32'(irq);

taxi_pcie_us_msi #(
    .MSI_CNT(32)
)
msi_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * Interrupt request inputs
     */
    .msi_irq(msi_irq),

    /*
     * Interface to UltraScale PCIe IP core
     */
    /* verilator lint_off WIDTHEXPAND */
    .cfg_interrupt_msi_enable(cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_vf_enable(),
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
    /* verilator lint_on WIDTHEXPAND */
);

cndm_micro_core #(
    .PORTS(PORTS)
)
core_inst (
    .clk(pcie_clk),
    .rst(pcie_rst),

    /*
     * Control register interface
     */
    .s_axil_wr(axil_ctrl_bar),
    .s_axil_rd(axil_ctrl_bar),

    /*
     * DMA
     */
    .dma_rd_desc_req(dma_rd_desc),
    .dma_rd_desc_sts(dma_rd_desc),
    .dma_wr_desc_req(dma_wr_desc),
    .dma_wr_desc_sts(dma_wr_desc),
    .dma_ram_wr(dma_ram),
    .dma_ram_rd(dma_ram),

    .irq(irq),

    /*
     * Ethernet
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
