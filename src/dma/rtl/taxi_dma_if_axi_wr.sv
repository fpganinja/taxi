// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2021-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI DMA write interface
 */
module taxi_dma_if_axi_wr #
(
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // Operation table size
    parameter OP_TBL_SIZE = 32,
    // Use AXI ID signals
    parameter logic USE_AXI_ID = 1'b1
)
(
    input  wire logic                            clk,
    input  wire logic                            rst,

    /*
     * AXI master interface
     */
    taxi_axi_if.wr_mst                           m_axi_wr,

    /*
     * Write descriptor
     */
    taxi_dma_desc_if.req_snk                     wr_desc_req,
    taxi_dma_desc_if.sts_src                     wr_desc_sts,

    /*
     * RAM interface
     */
    taxi_dma_ram_if.rd_mst                       dma_ram_rd,

    /*
     * Configuration
     */
    input  wire logic                            enable,

    /*
     * Status
     */
    output wire logic                            status_busy,

    /*
     * Statistics
     */
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_wr_op_start_tag,
    output wire logic                            stat_wr_op_start_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_wr_op_finish_tag,
    output wire logic [3:0]                      stat_wr_op_finish_status,
    output wire logic                            stat_wr_op_finish_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_wr_req_start_tag,
    output wire logic [12:0]                     stat_wr_req_start_len,
    output wire logic                            stat_wr_req_start_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_wr_req_finish_tag,
    output wire logic [3:0]                      stat_wr_req_finish_status,
    output wire logic                            stat_wr_req_finish_valid,
    output wire logic                            stat_wr_op_tbl_full,
    output wire logic                            stat_wr_tx_stall
);

// TODO cleanup
// verilator lint_off WIDTHEXPAND

// extract parameters
localparam AXI_DATA_W = m_axi_wr.DATA_W;
localparam AXI_ADDR_W = m_axi_wr.ADDR_W;
localparam AXI_STRB_W = m_axi_wr.STRB_W;
localparam AXI_ID_W = m_axi_wr.ID_W;
localparam AXI_MAX_BURST_LEN_INT = AXI_MAX_BURST_LEN < m_axi_wr.MAX_BURST_LEN ? AXI_MAX_BURST_LEN : m_axi_wr.MAX_BURST_LEN;

localparam IMM_EN = wr_desc_req.IMM_EN;
localparam IMM_W = wr_desc_req.IMM_W;
localparam LEN_W = wr_desc_req.LEN_W;
localparam TAG_W = wr_desc_req.TAG_W;

localparam RAM_SEGS = dma_ram_rd.SEGS;
localparam RAM_SEG_ADDR_W = dma_ram_rd.SEG_ADDR_W;
localparam RAM_SEG_DATA_W = dma_ram_rd.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_rd.SEG_BE_W;
localparam RAM_SEL_W = dma_ram_rd.SEL_W;

localparam RAM_ADDR_W = RAM_SEG_ADDR_W+$clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam RAM_DATA_W = RAM_SEGS*RAM_SEG_DATA_W;
localparam RAM_WORD_W = RAM_SEG_BE_W;
localparam RAM_WORD_SIZE = RAM_SEG_DATA_W/RAM_WORD_W;

localparam AXI_WORD_W = AXI_STRB_W;
localparam AXI_WORD_SIZE = AXI_DATA_W/AXI_WORD_W;
localparam AXI_BURST_SIZE = $clog2(AXI_STRB_W);
localparam AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

localparam OFFSET_W = AXI_STRB_W > 1 ? $clog2(AXI_STRB_W) : 1;
localparam OFFSET_MASK = AXI_STRB_W > 1 ? {OFFSET_W{1'b1}} : 0;
localparam RAM_OFFSET_W = $clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam ADDR_MASK = {AXI_ADDR_W{1'b1}} << $clog2(AXI_STRB_W);
localparam CYCLE_COUNT_W = LEN_W - AXI_BURST_SIZE + 1;

localparam MASK_FIFO_AW = $clog2(OP_TBL_SIZE)+1;

localparam OP_TAG_W = $clog2(OP_TBL_SIZE);

localparam OUTPUT_FIFO_AW = 5;

// check configuration
if (AXI_WORD_SIZE * AXI_STRB_W != AXI_DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (AXI_WORD_SIZE != RAM_WORD_SIZE)
    $fatal(0, "Error: word size mismatch (instance %m)");

if (2**$clog2(AXI_WORD_W) != AXI_WORD_W)
    $fatal(0, "Error: AXI word width must be even power of two (instance %m)");

if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256)
    $fatal(0, "Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");

if (RAM_SEGS < 2)
    $fatal(0, "Error: RAM interface requires at least 2 segments (instance %m)");

if (RAM_DATA_W != AXI_DATA_W*2)
    $fatal(0, "Error: RAM interface width must be double the AXI interface width (instance %m)");

if (2**$clog2(RAM_WORD_W) != RAM_WORD_W)
    $fatal(0, "Error: RAM word width must be even power of two (instance %m)");

if (OP_TBL_SIZE > 2**AXI_ID_W)
    $fatal(0, "Error: AXI_ID_W insufficient for requested OP_TBL_SIZE (instance %m)");

if (IMM_EN && IMM_W > AXI_DATA_W)
    $fatal(0, "Error: IMM_W must not be larger than the AXI interface width (instance %m)");

if (wr_desc_req.SRC_ADDR_W < RAM_ADDR_W || wr_desc_req.DST_ADDR_W < AXI_ADDR_W)
    $fatal(0, "Error: Descriptor address width is not sufficient (instance %m)");

typedef enum logic [1:0] {
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
} axi_resp_t;

typedef enum logic [3:0] {
    DMA_ERROR_NONE = 4'd0,
    DMA_ERROR_TIMEOUT = 4'd1,
    DMA_ERROR_PARITY = 4'd2,
    DMA_ERROR_AXI_RD_SLVERR = 4'd4,
    DMA_ERROR_AXI_RD_DECERR = 4'd5,
    DMA_ERROR_AXI_WR_SLVERR = 4'd6,
    DMA_ERROR_AXI_WR_DECERR = 4'd7,
    DMA_ERROR_PCIE_FLR = 4'd8,
    DMA_ERROR_PCIE_CPL_POISONED = 4'd9,
    DMA_ERROR_PCIE_CPL_STATUS_UR = 4'd10,
    DMA_ERROR_PCIE_CPL_STATUS_CA = 4'd11
} dma_error_t;

typedef enum logic [0:0] {
    REQ_STATE_IDLE,
    REQ_STATE_START
} req_state_t;

req_state_t req_state_reg = REQ_STATE_IDLE, req_state_next;

typedef enum logic [0:0] {
    READ_STATE_IDLE,
    READ_STATE_READ
} read_state_t;

read_state_t read_state_reg = READ_STATE_IDLE, read_state_next;

typedef enum logic [0:0] {
    AXI_STATE_IDLE,
    AXI_STATE_TRANSFER
} axi_state_t;

axi_state_t axi_state_reg = AXI_STATE_IDLE, axi_state_next;

// datapath control signals
logic mask_fifo_we;

logic read_cmd_ready;

logic [AXI_ADDR_W-1:0] req_axi_addr_reg = '0, req_axi_addr_next;
logic [RAM_SEL_W-1:0] ram_sel_reg = '0, ram_sel_next;
logic [RAM_ADDR_W-1:0] ram_addr_reg = '0, ram_addr_next;
logic [IMM_W-1:0] imm_reg = '0, imm_next;
logic imm_en_reg = 1'b0, imm_en_next;
logic [LEN_W-1:0] op_count_reg = '0, op_count_next;
logic zero_len_reg = 1'b0, zero_len_next;
logic [LEN_W-1:0] tr_count_reg = '0, tr_count_next;
logic [12:0] tr_word_count_reg = '0, tr_word_count_next;
logic [TAG_W-1:0] tag_reg = '0, tag_next;

logic [AXI_ADDR_W-1:0] read_axi_addr_reg = '0, read_axi_addr_next;
logic [RAM_SEL_W-1:0] read_ram_sel_reg = '0, read_ram_sel_next;
logic [RAM_ADDR_W-1:0] read_ram_addr_reg = '0, read_ram_addr_next;
logic read_imm_en_reg = 1'b0, read_imm_en_next;
logic [12:0] read_len_reg = '0, read_len_next;
logic [RAM_SEGS-1:0] read_ram_mask_reg = '0, read_ram_mask_next;
logic [RAM_SEGS-1:0] read_ram_mask_0_reg = '0, read_ram_mask_0_next;
logic [RAM_SEGS-1:0] read_ram_mask_1_reg = '0, read_ram_mask_1_next;
logic ram_wrap_reg = 1'b0, ram_wrap_next;
logic [CYCLE_COUNT_W-1:0] read_cycle_count_reg = '0, read_cycle_count_next;
logic read_last_cycle_reg = 1'b0, read_last_cycle_next;
logic [OFFSET_W+1-1:0] cycle_byte_count_reg = '0, cycle_byte_count_next;
logic [RAM_OFFSET_W-1:0] start_offset_reg = '0, start_offset_next;
logic [RAM_OFFSET_W-1:0] end_offset_reg = '0, end_offset_next;

logic [AXI_ADDR_W-1:0] axi_addr_reg = '0, axi_addr_next;
logic [IMM_W-1:0] axi_imm_reg = '0, axi_imm_next;
logic axi_imm_en_reg = 1'b0, axi_imm_en_next;
logic [12:0] axi_len_reg = '0, axi_len_next;
logic axi_zero_len_reg = 1'b0, axi_zero_len_next;
logic [RAM_OFFSET_W-1:0] offset_reg = '0, offset_next;
logic [AXI_STRB_W-1:0] strb_offset_mask_reg = '1, strb_offset_mask_next;
logic [OFFSET_W-1:0] last_cycle_offset_reg = '0, last_cycle_offset_next;
logic [RAM_SEGS-1:0] ram_mask_reg = '0, ram_mask_next;
logic ram_mask_valid_reg = 1'b0, ram_mask_valid_next;
logic [CYCLE_COUNT_W-1:0] cycle_count_reg = '0, cycle_count_next;
logic last_cycle_reg = 1'b0, last_cycle_next;

logic [AXI_ADDR_W-1:0] read_cmd_axi_addr_reg = '0, read_cmd_axi_addr_next;
logic [RAM_SEL_W-1:0] read_cmd_ram_sel_reg = '0, read_cmd_ram_sel_next;
logic [RAM_ADDR_W-1:0] read_cmd_ram_addr_reg = '0, read_cmd_ram_addr_next;
logic read_cmd_imm_en_reg = 1'b0, read_cmd_imm_en_next;
logic [12:0] read_cmd_len_reg = '0, read_cmd_len_next;
logic [CYCLE_COUNT_W-1:0] read_cmd_cycle_count_reg = '0, read_cmd_cycle_count_next;
logic read_cmd_last_cycle_reg = 1'b0, read_cmd_last_cycle_next;
logic read_cmd_valid_reg = 1'b0, read_cmd_valid_next;

logic [MASK_FIFO_AW+1-1:0] mask_fifo_wr_ptr_reg = '0;
logic [MASK_FIFO_AW+1-1:0] mask_fifo_rd_ptr_reg = '0, mask_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_SEGS-1:0] mask_fifo_mask[2**MASK_FIFO_AW];
logic [RAM_SEGS-1:0] mask_fifo_wr_mask;

wire mask_fifo_empty = mask_fifo_wr_ptr_reg == mask_fifo_rd_ptr_reg;
wire mask_fifo_full = mask_fifo_wr_ptr_reg == (mask_fifo_rd_ptr_reg ^ (1 << MASK_FIFO_AW));

logic [OP_TAG_W+1-1:0] active_op_count_reg = '0;
logic inc_active_op;
logic dec_active_op;

logic [AXI_ID_W-1:0] m_axi_awid_reg = '0, m_axi_awid_next;
logic [AXI_ADDR_W-1:0] m_axi_awaddr_reg = '0, m_axi_awaddr_next;
logic [7:0] m_axi_awlen_reg = '0, m_axi_awlen_next;
logic m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;
logic m_axi_bready_reg = 1'b0, m_axi_bready_next;

logic wr_desc_req_ready_reg = 1'b0, wr_desc_req_ready_next;

logic [TAG_W-1:0] wr_desc_sts_tag_reg = '0, wr_desc_sts_tag_next;
logic [3:0] wr_desc_sts_error_reg = 4'd0, wr_desc_sts_error_next;
logic wr_desc_sts_valid_reg = 1'b0, wr_desc_sts_valid_next;

logic [RAM_SEGS-1:0][RAM_SEL_W-1:0]      ram_rd_cmd_sel_reg = '0, ram_rd_cmd_sel_next;
logic [RAM_SEGS-1:0][RAM_SEG_ADDR_W-1:0] ram_rd_cmd_addr_reg = '0, ram_rd_cmd_addr_next;
logic [RAM_SEGS-1:0]                     ram_rd_cmd_valid_reg = '0, ram_rd_cmd_valid_next;
logic [RAM_SEGS-1:0]                     ram_rd_resp_ready_cmb;

logic status_busy_reg = 1'b0;

logic [OP_TAG_W-1:0] stat_wr_op_start_tag_reg = '0, stat_wr_op_start_tag_next;
logic stat_wr_op_start_valid_reg = 1'b0, stat_wr_op_start_valid_next;
logic [OP_TAG_W-1:0] stat_wr_op_finish_tag_reg = '0, stat_wr_op_finish_tag_next;
logic [3:0] stat_wr_op_finish_status_reg = '0, stat_wr_op_finish_status_next;
logic stat_wr_op_finish_valid_reg = 1'b0, stat_wr_op_finish_valid_next;
logic [OP_TAG_W-1:0] stat_wr_req_start_tag_reg = '0, stat_wr_req_start_tag_next;
logic [12:0] stat_wr_req_start_len_reg = '0, stat_wr_req_start_len_next;
logic stat_wr_req_start_valid_reg = 1'b0, stat_wr_req_start_valid_next;
logic [OP_TAG_W-1:0] stat_wr_req_finish_tag_reg = '0, stat_wr_req_finish_tag_next;
logic [3:0] stat_wr_req_finish_status_reg = '0, stat_wr_req_finish_status_next;
logic stat_wr_req_finish_valid_reg = 1'b0, stat_wr_req_finish_valid_next;
logic stat_wr_op_tbl_full_reg = 1'b0, stat_wr_op_tbl_full_next;
logic stat_wr_tx_stall_reg = 1'b0, stat_wr_tx_stall_next;

// internal datapath
logic  [AXI_DATA_W-1:0] m_axi_wdata_int;
logic  [AXI_STRB_W-1:0] m_axi_wstrb_int;
logic                   m_axi_wlast_int;
logic                   m_axi_wvalid_int;
wire                    m_axi_wready_int;

assign m_axi_wr.awid = USE_AXI_ID ? m_axi_awid_reg : '0;
assign m_axi_wr.awaddr = m_axi_awaddr_reg;
assign m_axi_wr.awlen = m_axi_awlen_reg;
assign m_axi_wr.awsize = 3'(AXI_BURST_SIZE);
assign m_axi_wr.awburst = 2'b01;
assign m_axi_wr.awlock = 1'b0;
assign m_axi_wr.awcache = 4'b0011;
assign m_axi_wr.awprot = 3'b010;
assign m_axi_wr.awvalid = m_axi_awvalid_reg;
assign m_axi_wr.bready = m_axi_bready_reg;

assign wr_desc_req.req_ready = wr_desc_req_ready_reg;

assign wr_desc_sts.sts_tag = wr_desc_sts_tag_reg;
assign wr_desc_sts.sts_error = wr_desc_sts_error_reg;
assign wr_desc_sts.sts_valid = wr_desc_sts_valid_reg;

assign dma_ram_rd.rd_cmd_sel = ram_rd_cmd_sel_reg;
assign dma_ram_rd.rd_cmd_addr = ram_rd_cmd_addr_reg;
assign dma_ram_rd.rd_cmd_valid = ram_rd_cmd_valid_reg;
assign dma_ram_rd.rd_resp_ready = ram_rd_resp_ready_cmb;

assign status_busy = status_busy_reg;

assign stat_wr_op_start_tag = stat_wr_op_start_tag_reg;
assign stat_wr_op_start_valid = stat_wr_op_start_valid_reg;
assign stat_wr_op_finish_tag = stat_wr_op_finish_tag_reg;
assign stat_wr_op_finish_status = stat_wr_op_finish_status_reg;
assign stat_wr_op_finish_valid = stat_wr_op_finish_valid_reg;
assign stat_wr_req_start_tag = stat_wr_req_start_tag_reg;
assign stat_wr_req_start_len = stat_wr_req_start_len_reg;
assign stat_wr_req_start_valid = stat_wr_req_start_valid_reg;
assign stat_wr_req_finish_tag = stat_wr_req_finish_tag_reg;
assign stat_wr_req_finish_status = stat_wr_req_finish_status_reg;
assign stat_wr_req_finish_valid = stat_wr_req_finish_valid_reg;
assign stat_wr_op_tbl_full = stat_wr_op_tbl_full_reg;
assign stat_wr_tx_stall = stat_wr_tx_stall_reg;

// operation tag management
logic [OP_TAG_W+1-1:0] op_tbl_start_ptr_reg = '0;
logic [AXI_ADDR_W-1:0] op_tbl_start_axi_addr;
logic [IMM_W-1:0] op_tbl_start_imm;
logic op_tbl_start_imm_en;
logic [12:0] op_tbl_start_len;
logic op_tbl_start_zero_len;
logic [CYCLE_COUNT_W-1:0] op_tbl_start_cycle_count;
logic [RAM_OFFSET_W-1:0] op_tbl_start_offset;
logic [TAG_W-1:0] op_tbl_start_tag;
logic op_tbl_start_last;
logic op_tbl_start_en;
logic [OP_TAG_W+1-1:0] op_tbl_tx_start_ptr_reg = '0;
logic op_tbl_tx_start_en;
logic [OP_TAG_W+1-1:0] op_tbl_tx_finish_ptr_reg = '0;
logic op_tbl_tx_finish_en;
logic [OP_TAG_W-1:0] op_tbl_write_complete_ptr;
logic [3:0] op_tbl_write_complete_error;
logic op_tbl_write_complete_en;
logic [OP_TAG_W+1-1:0] op_tbl_finish_ptr_reg = '0;
logic op_tbl_finish_en;

logic [2**OP_TAG_W-1:0] op_tbl_active = '0;
logic [2**OP_TAG_W-1:0] op_tbl_write_complete = '0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXI_ADDR_W-1:0] op_tbl_axi_addr[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [IMM_W-1:0] op_tbl_imm[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_imm_en[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [12:0] op_tbl_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_zero_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [CYCLE_COUNT_W-1:0] op_tbl_cycle_count[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_OFFSET_W-1:0] op_tbl_offset[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [TAG_W-1:0] op_tbl_tag[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_last[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [3:0] op_tbl_error_code[2**OP_TAG_W] = '{default: '0};

always_comb begin
    req_state_next = REQ_STATE_IDLE;

    wr_desc_req_ready_next = 1'b0;

    stat_wr_op_start_tag_next = stat_wr_op_start_tag_reg;
    stat_wr_op_start_valid_next = 1'b0;
    stat_wr_req_start_tag_next = stat_wr_req_start_tag_reg;
    stat_wr_req_start_len_next = stat_wr_req_start_len_reg;
    stat_wr_req_start_valid_next = 1'b0;
    stat_wr_op_tbl_full_next = !(!op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W));
    stat_wr_tx_stall_next = (m_axi.awvalid && !m_axi.awready) || (m_axi.wvalid && !m_axi.wready);

    tag_next = tag_reg;
    req_axi_addr_next = req_axi_addr_reg;
    ram_sel_next = ram_sel_reg;
    ram_addr_next = ram_addr_reg;
    imm_next = imm_reg;
    imm_en_next = imm_en_reg;
    op_count_next = op_count_reg;
    zero_len_next = zero_len_reg;
    tr_count_next = tr_count_reg;
    tr_word_count_next = tr_word_count_reg;

    read_cmd_axi_addr_next = read_cmd_axi_addr_reg;
    read_cmd_ram_sel_next = read_cmd_ram_sel_reg;
    read_cmd_ram_addr_next = read_cmd_ram_addr_reg;
    read_cmd_imm_en_next = read_cmd_imm_en_reg;
    read_cmd_len_next = read_cmd_len_reg;
    read_cmd_cycle_count_next = read_cmd_cycle_count_reg;
    read_cmd_last_cycle_next = read_cmd_last_cycle_reg;
    read_cmd_valid_next = read_cmd_valid_reg && !read_cmd_ready;

    op_tbl_start_axi_addr = req_axi_addr_reg;
    op_tbl_start_imm = imm_reg;
    op_tbl_start_imm_en = imm_en_reg;
    op_tbl_start_len = '0;
    op_tbl_start_zero_len = zero_len_reg;
    op_tbl_start_cycle_count = '0;
    op_tbl_start_offset = RAM_OFFSET_W'(req_axi_addr_reg & OFFSET_MASK) - RAM_OFFSET_W'(ram_addr_reg);
    op_tbl_start_tag = tag_reg;
    op_tbl_start_last = '0;
    op_tbl_start_en = 1'b0;

    inc_active_op = 1'b0;

    // TLP segmentation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            // idle state, wait for incoming descriptor
            wr_desc_req_ready_next = !op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && enable;

            req_axi_addr_next = wr_desc_req.req_dst_addr;
            if (IMM_EN && wr_desc_req.req_imm_en) begin
                ram_sel_next = '0;
                ram_addr_next = '0;
            end else begin
                ram_sel_next = wr_desc_req.req_src_sel;
                ram_addr_next = wr_desc_req.req_src_addr;
            end
            imm_next = wr_desc_req.req_imm;
            imm_en_next = IMM_EN && wr_desc_req.req_imm_en;
            if (wr_desc_req.req_len == 0) begin
                // zero-length operation
                op_count_next = 1;
                zero_len_next = 1'b1;
            end else begin
                op_count_next = wr_desc_req.req_len;
                zero_len_next = 1'b0;
            end
            tag_next = wr_desc_req.req_tag;

            if (op_count_next <= LEN_W'(AXI_MAX_BURST_SIZE) - LEN_W'(req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                // packet smaller than max burst size
                if ((12'(req_axi_addr_next & 12'hfff) + 12'(op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    tr_word_count_next = 13'(op_count_next);
                end
            end else begin
                // packet larger than max burst size
                if ((12'(req_axi_addr_next & 12'hfff) + 12'(AXI_MAX_BURST_SIZE)) >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    tr_word_count_next = 13'(AXI_MAX_BURST_SIZE) - 13'(req_axi_addr_next & OFFSET_MASK);
                end
            end

            if (wr_desc_req.req_ready & wr_desc_req.req_valid) begin
                wr_desc_req_ready_next = 1'b0;

                stat_wr_op_start_tag_next = stat_wr_op_start_tag_reg+1;
                stat_wr_op_start_valid_next = 1'b1;

                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            // start state, compute length
            if (!op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && (!read_cmd_valid_reg || read_cmd_ready)) begin
                read_cmd_axi_addr_next = req_axi_addr_reg;
                read_cmd_ram_sel_next = ram_sel_reg;
                read_cmd_ram_addr_next = ram_addr_reg;
                read_cmd_imm_en_next = imm_en_reg;
                read_cmd_len_next = tr_word_count_next;
                read_cmd_cycle_count_next = CYCLE_COUNT_W'(tr_word_count_next + 13'(req_axi_addr_reg & OFFSET_MASK) - 13'd1) >> AXI_BURST_SIZE;
                op_tbl_start_cycle_count = read_cmd_cycle_count_next;
                read_cmd_last_cycle_next = read_cmd_cycle_count_next == 0;
                read_cmd_valid_next = 1'b1;

                req_axi_addr_next = req_axi_addr_reg + AXI_ADDR_W'(tr_word_count_next);
                ram_addr_next = ram_addr_reg + RAM_ADDR_W'(tr_word_count_next);
                op_count_next = op_count_reg - LEN_W'(tr_word_count_next);

                op_tbl_start_axi_addr = req_axi_addr_reg;
                op_tbl_start_imm = imm_reg;
                op_tbl_start_imm_en = imm_en_reg;
                op_tbl_start_len = tr_word_count_next;
                op_tbl_start_zero_len = zero_len_reg;
                op_tbl_start_offset = RAM_OFFSET_W'(req_axi_addr_reg & OFFSET_MASK)-ram_addr_reg[RAM_OFFSET_W-1:0];
                op_tbl_start_tag = tag_reg;
                op_tbl_start_last = op_count_reg == LEN_W'(tr_word_count_next);
                op_tbl_start_en = 1'b1;
                inc_active_op = 1'b1;

                stat_wr_req_start_tag_next = op_tbl_start_ptr_reg[OP_TAG_W-1:0];
                stat_wr_req_start_len_next = zero_len_reg ? '0 : tr_word_count_next;
                stat_wr_req_start_valid_next = 1'b1;

                if (op_count_next <= LEN_W'(AXI_MAX_BURST_SIZE) - LEN_W'(req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                    // packet smaller than max burst size
                    if ((12'(req_axi_addr_next & 12'hfff) + 12'(op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                        // crosses 4k boundary
                        tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        tr_word_count_next = 13'(op_count_next);
                    end
                end else begin
                    // packet larger than max burst size
                    if ((12'(req_axi_addr_next & 12'hfff) + 12'(AXI_MAX_BURST_SIZE)) >> 12 != 0) begin
                        // crosses 4k boundary
                        tr_word_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        tr_word_count_next = 13'(AXI_MAX_BURST_SIZE) - 13'(req_axi_addr_next & OFFSET_MASK);
                    end
                end

                if (!op_tbl_start_last) begin
                    req_state_next = REQ_STATE_START;
                end else begin
                    wr_desc_req_ready_next = !op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && enable;
                    req_state_next = REQ_STATE_IDLE;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
    endcase
end

always_comb begin
    read_state_next = READ_STATE_IDLE;

    read_cmd_ready = 1'b0;

    ram_rd_cmd_sel_next = ram_rd_cmd_sel_reg;
    ram_rd_cmd_addr_next = ram_rd_cmd_addr_reg;
    ram_rd_cmd_valid_next = ram_rd_cmd_valid_reg & ~dma_ram_rd.rd_cmd_ready;

    read_axi_addr_next = read_axi_addr_reg;
    read_ram_sel_next = read_ram_sel_reg;
    read_ram_addr_next = read_ram_addr_reg;
    read_imm_en_next = read_imm_en_reg;
    read_len_next = read_len_reg;
    read_ram_mask_next = read_ram_mask_reg;
    read_ram_mask_0_next = read_ram_mask_0_reg;
    read_ram_mask_1_next = read_ram_mask_1_reg;
    ram_wrap_next = ram_wrap_reg;
    read_cycle_count_next = read_cycle_count_reg;
    read_last_cycle_next = read_last_cycle_reg;
    cycle_byte_count_next = cycle_byte_count_reg;
    start_offset_next = start_offset_reg;
    end_offset_next = end_offset_reg;

    mask_fifo_wr_mask = read_ram_mask_reg;
    mask_fifo_we = 1'b0;

    // Read request generation
    case (read_state_reg)
        READ_STATE_IDLE: begin
            // idle state, wait for read command

            read_axi_addr_next = read_cmd_axi_addr_reg;
            read_ram_sel_next = read_cmd_ram_sel_reg;
            read_ram_addr_next = read_cmd_ram_addr_reg;
            read_imm_en_next = read_cmd_imm_en_reg;
            read_len_next = read_cmd_len_reg;
            read_cycle_count_next = read_cmd_cycle_count_reg;
            read_last_cycle_next = read_cmd_last_cycle_reg;

            if (read_len_next > 13'(AXI_STRB_W)-13'(read_axi_addr_next & OFFSET_MASK)) begin
                cycle_byte_count_next = (OFFSET_W+1)'(AXI_STRB_W)-(OFFSET_W+1)'(read_axi_addr_next & OFFSET_MASK);
            end else begin
                cycle_byte_count_next = (OFFSET_W+1)'(read_len_next);
            end
            start_offset_next = RAM_OFFSET_W'(read_ram_addr_next);
            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

            read_ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
            read_ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

            if (!ram_wrap_next) begin
                read_ram_mask_next = read_ram_mask_0_next & read_ram_mask_1_next;
                read_ram_mask_0_next = read_ram_mask_0_next & read_ram_mask_1_next;
                read_ram_mask_1_next = '0;
            end else begin
                read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
            end

            if (read_cmd_valid_reg) begin
                read_cmd_ready = 1'b1;
                read_state_next = READ_STATE_READ;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_READ: begin
            // read state - start new read operations

            if ((dma_ram_rd.rd_cmd_valid & ~dma_ram_rd.rd_cmd_ready & read_ram_mask_reg) == 0 && !mask_fifo_full) begin

                // update counters
                read_ram_addr_next = read_ram_addr_reg + RAM_ADDR_W'(cycle_byte_count_reg);
                read_len_next = read_len_reg - 13'(cycle_byte_count_reg);
                read_cycle_count_next = read_cycle_count_reg - 1;
                read_last_cycle_next = read_cycle_count_next == 0;

                for (integer i = 0; i < RAM_SEGS; i = i + 1) begin
                    if (read_ram_mask_reg[i]) begin
                        ram_rd_cmd_sel_next[i] = read_ram_sel_reg;
                        ram_rd_cmd_addr_next[i] = read_ram_addr_reg[RAM_ADDR_W-1:RAM_ADDR_W-RAM_SEG_ADDR_W];
                        ram_rd_cmd_valid_next[i] = !(IMM_EN && read_imm_en_reg);
                    end
                    if (read_ram_mask_1_reg[i]) begin
                        ram_rd_cmd_addr_next[i] = read_ram_addr_reg[RAM_ADDR_W-1:RAM_ADDR_W-RAM_SEG_ADDR_W]+1;
                    end
                end

                mask_fifo_wr_mask = (IMM_EN && read_imm_en_reg) ? 0 : read_ram_mask_reg;
                mask_fifo_we = 1'b1;

                if (read_len_next > 13'(AXI_STRB_W)) begin
                    cycle_byte_count_next = (OFFSET_W+1)'(AXI_STRB_W);
                end else begin
                    cycle_byte_count_next = (OFFSET_W+1)'(read_len_next);
                end
                start_offset_next = RAM_OFFSET_W'(read_ram_addr_next);
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                read_ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                read_ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                if (!ram_wrap_next) begin
                    read_ram_mask_next = read_ram_mask_0_next & read_ram_mask_1_next;
                    read_ram_mask_0_next = read_ram_mask_0_next & read_ram_mask_1_next;
                    read_ram_mask_1_next = '0;
                end else begin
                    read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
                end

                if (!read_last_cycle_reg) begin
                    read_state_next = READ_STATE_READ;
                end else if (read_cmd_valid_reg) begin

                    read_axi_addr_next = read_cmd_axi_addr_reg;
                    read_ram_sel_next = read_cmd_ram_sel_reg;
                    read_ram_addr_next = read_cmd_ram_addr_reg;
                    read_imm_en_next = read_cmd_imm_en_reg;
                    read_len_next = read_cmd_len_reg;
                    read_cycle_count_next = read_cmd_cycle_count_reg;
                    read_last_cycle_next = read_cmd_last_cycle_reg;

                    if (read_len_next > 13'(AXI_STRB_W)-13'(read_axi_addr_next & OFFSET_MASK)) begin
                        cycle_byte_count_next = (OFFSET_W+1)'(AXI_STRB_W)-(OFFSET_W+1)'(read_axi_addr_next & OFFSET_MASK);
                    end else begin
                        cycle_byte_count_next = (OFFSET_W+1)'(read_len_next);
                    end
                    start_offset_next = RAM_OFFSET_W'(read_ram_addr_next);
                    {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                    read_ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                    read_ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                    if (!ram_wrap_next) begin
                        read_ram_mask_next = read_ram_mask_0_next & read_ram_mask_1_next;
                        read_ram_mask_0_next = read_ram_mask_0_next & read_ram_mask_1_next;
                        read_ram_mask_1_next = '0;
                    end else begin
                        read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
                    end

                    read_cmd_ready = 1'b1;

                    read_state_next = READ_STATE_READ;
                end else begin
                    read_state_next = READ_STATE_IDLE;
                end
            end else begin
                read_state_next = READ_STATE_READ;
            end
        end
    endcase
end

always_comb begin
    axi_state_next = AXI_STATE_IDLE;

    ram_rd_resp_ready_cmb = '0;

    stat_wr_op_finish_tag_next = stat_wr_op_finish_tag_reg;
    stat_wr_op_finish_status_next = stat_wr_op_finish_status_reg;
    stat_wr_op_finish_valid_next = 1'b0;
    stat_wr_req_finish_tag_next = stat_wr_req_finish_tag_reg;
    stat_wr_req_finish_status_next = stat_wr_req_finish_status_reg;
    stat_wr_req_finish_valid_next = 1'b0;

    axi_addr_next = axi_addr_reg;
    axi_imm_next = axi_imm_reg;
    axi_imm_en_next = axi_imm_en_reg;
    axi_len_next = axi_len_reg;
    axi_zero_len_next = axi_zero_len_reg;
    offset_next = offset_reg;
    strb_offset_mask_next = strb_offset_mask_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_valid_next = ram_mask_valid_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg;

    op_tbl_tx_start_en = 1'b0;
    op_tbl_tx_finish_en = 1'b0;

    m_axi_awid_next = m_axi_awid_reg;
    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_wr.awready;
    m_axi_bready_next = 1'b0;

    m_axi_wdata_int = AXI_DATA_W'(((IMM_EN && axi_imm_en_reg) ? {2{RAM_DATA_W'(axi_imm_reg)}} : {2{dma_ram_rd.rd_resp_data}}) >> (RAM_DATA_W-offset_reg*AXI_WORD_SIZE));
    m_axi_wstrb_int = strb_offset_mask_reg;
    m_axi_wlast_int = 1'b0;
    m_axi_wvalid_int = 1'b0;

    // read response processing and AXI write generation
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for command
            ram_rd_resp_ready_cmb = '0;

            axi_addr_next = op_tbl_axi_addr[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            axi_imm_next = op_tbl_imm[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            axi_imm_en_next = op_tbl_imm_en[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            axi_len_next = op_tbl_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            axi_zero_len_next = op_tbl_zero_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            offset_next = op_tbl_offset[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            strb_offset_mask_next = axi_zero_len_next ? '0 : ({AXI_STRB_W{1'b1}} << (axi_addr_next & OFFSET_MASK));
            last_cycle_offset_next = OFFSET_W'(axi_addr_next) + OFFSET_W'(axi_len_next & OFFSET_MASK);
            cycle_count_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            last_cycle_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] == 0;

            if (op_tbl_active[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] && op_tbl_tx_start_ptr_reg != op_tbl_start_ptr_reg && (!m_axi_awvalid_reg || m_axi_wr.awready)) begin
                m_axi_awid_next = op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0];
                m_axi_awaddr_next = axi_addr_next;
                m_axi_awlen_next = 8'(cycle_count_next);
                m_axi_awvalid_next = 1'b1;
                op_tbl_tx_start_en = 1'b1;
                axi_state_next = AXI_STATE_TRANSFER;
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_TRANSFER: begin
            // transfer state, transfer data
            ram_rd_resp_ready_cmb = '0;

            if ((ram_mask_reg & ~dma_ram_rd.rd_resp_valid) == 0 && ram_mask_valid_reg && m_axi_wready_int) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;
                ram_mask_valid_next = 1'b0;

                // update counters
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                offset_next = offset_reg + RAM_OFFSET_W'(AXI_STRB_W);
                strb_offset_mask_next = '1;

                m_axi_wdata_int = AXI_DATA_W'(((IMM_EN && axi_imm_en_reg) ? {2{RAM_DATA_W'(axi_imm_reg)}} : {2{dma_ram_rd.rd_resp_data}}) >> (RAM_DATA_W-offset_reg*AXI_WORD_SIZE));
                m_axi_wstrb_int = strb_offset_mask_reg;
                m_axi_wlast_int = 1'b0;
                m_axi_wvalid_int = 1'b1;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    m_axi_wlast_int = 1'b1;
                    op_tbl_tx_finish_en = 1'b1;

                    if (last_cycle_offset_reg != 0) begin
                        m_axi_wstrb_int = strb_offset_mask_reg & {AXI_STRB_W{1'b1}} >> ((OFFSET_W+1)'(AXI_STRB_W) - last_cycle_offset_reg);
                    end

                    // skip idle state if possible
                    axi_addr_next = op_tbl_axi_addr[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    axi_imm_next = op_tbl_imm[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    axi_imm_en_next = op_tbl_imm_en[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    axi_len_next = op_tbl_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    axi_zero_len_next = op_tbl_zero_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    offset_next = op_tbl_offset[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    strb_offset_mask_next = axi_zero_len_next ? '0 : ({AXI_STRB_W{1'b1}} << (axi_addr_next & OFFSET_MASK));
                    last_cycle_offset_next = OFFSET_W'(axi_addr_next) + OFFSET_W'(axi_len_next & OFFSET_MASK);
                    cycle_count_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    last_cycle_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] == 0;

                    if (op_tbl_active[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] && op_tbl_tx_start_ptr_reg != op_tbl_start_ptr_reg && (!m_axi_awvalid_reg || m_axi_wr.awready)) begin
                        m_axi_awid_next = op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0];
                        m_axi_awaddr_next = axi_addr_next;
                        m_axi_awlen_next = 8'(cycle_count_next);
                        m_axi_awvalid_next = 1'b1;
                        op_tbl_tx_start_en = 1'b1;
                        axi_state_next = AXI_STATE_TRANSFER;
                    end else begin
                        axi_state_next = AXI_STATE_IDLE;
                    end
                end else begin
                    axi_state_next = AXI_STATE_TRANSFER;
                end
            end else begin
                axi_state_next = AXI_STATE_TRANSFER;
            end
        end
    endcase

    if (!ram_mask_valid_next && !mask_fifo_empty) begin
        ram_mask_next = mask_fifo_mask[mask_fifo_rd_ptr_reg[MASK_FIFO_AW-1:0]];
        ram_mask_valid_next = 1'b1;
        mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg+1;
    end

    op_tbl_write_complete_ptr = m_axi_wr.bid;
    if (m_axi_wr.bresp == AXI_RESP_SLVERR) begin
        op_tbl_write_complete_error = DMA_ERROR_AXI_WR_SLVERR;
    end else if (m_axi_wr.bresp == AXI_RESP_DECERR) begin
        op_tbl_write_complete_error = DMA_ERROR_AXI_WR_DECERR;
    end else begin
        op_tbl_write_complete_error = DMA_ERROR_NONE;
    end
    op_tbl_write_complete_en = 1'b0;

    wr_desc_sts_tag_next = op_tbl_tag[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
    if (wr_desc_sts_valid_reg) begin
        wr_desc_sts_error_next = DMA_ERROR_NONE;
    end else begin
        wr_desc_sts_error_next = wr_desc_sts_error_reg;
    end
    wr_desc_sts_valid_next = 1'b0;

    stat_wr_req_finish_status_next = op_tbl_write_complete_error;
    stat_wr_req_finish_valid_next = 1'b0;

    stat_wr_op_finish_tag_next = stat_wr_op_finish_tag_reg;
    stat_wr_op_finish_status_next = wr_desc_sts_error_next;
    stat_wr_op_finish_valid_next = 1'b0;

    if (USE_AXI_ID) begin
        // accept write completions
        stat_wr_req_finish_tag_next = m_axi_wr.bid;

        m_axi_bready_next = 1'b1;
        if (m_axi_wr.bready && m_axi_wr.bvalid) begin
            op_tbl_write_complete_ptr = m_axi_wr.bid;
            op_tbl_write_complete_en = 1'b1;
            stat_wr_req_finish_valid_next = 1'b1;
        end

        // commit operations in-order
        op_tbl_finish_en = 1'b0;
        dec_active_op = 1'b0;

        if (op_tbl_active[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] && op_tbl_write_complete[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] && op_tbl_finish_ptr_reg != op_tbl_tx_finish_ptr_reg) begin
            op_tbl_finish_en = 1'b1;
            dec_active_op = 1'b1;

            if (op_tbl_error_code[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] != DMA_ERROR_NONE) begin
                wr_desc_sts_error_next = op_tbl_error_code[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
            end

            stat_wr_op_finish_status_next = wr_desc_sts_error_next;

            if (op_tbl_last[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]]) begin
                wr_desc_sts_tag_next = op_tbl_tag[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
                wr_desc_sts_valid_next = 1'b1;
                stat_wr_op_finish_tag_next = stat_wr_op_finish_tag_reg + 1;
                stat_wr_op_finish_valid_next = 1'b1;
            end
        end
    end else begin
        // accept write completions
        op_tbl_finish_en = 1'b0;
        dec_active_op = 1'b0;

        stat_wr_req_finish_tag_next = op_tbl_finish_ptr_reg[OP_TAG_W-1:0];

        m_axi_bready_next = 1'b1;
        if (m_axi_wr.bready && m_axi_wr.bvalid) begin
            op_tbl_finish_en = 1'b1;
            dec_active_op = 1'b1;
            stat_wr_req_finish_valid_next = 1'b1;

            if (m_axi_wr.bresp == AXI_RESP_SLVERR) begin
                wr_desc_sts_error_next = DMA_ERROR_AXI_WR_SLVERR;
            end else if (m_axi_wr.bresp == AXI_RESP_DECERR) begin
                wr_desc_sts_error_next = DMA_ERROR_AXI_WR_DECERR;
            end

            stat_wr_op_finish_status_next = wr_desc_sts_error_next;

            if (op_tbl_last[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]]) begin
                wr_desc_sts_tag_next = op_tbl_tag[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
                wr_desc_sts_valid_next = 1'b1;
                stat_wr_op_finish_tag_next = stat_wr_op_finish_tag_reg + 1;
                stat_wr_op_finish_valid_next = 1'b1;
            end
        end
    end
end

always_ff @(posedge clk) begin
    req_state_reg <= req_state_next;
    read_state_reg <= read_state_next;
    axi_state_reg <= axi_state_next;

    req_axi_addr_reg <= req_axi_addr_next;
    ram_sel_reg <= ram_sel_next;
    ram_addr_reg <= ram_addr_next;
    imm_reg <= imm_next;
    imm_en_reg <= imm_en_next;
    op_count_reg <= op_count_next;
    zero_len_reg <= zero_len_next;
    tr_count_reg <= tr_count_next;
    tr_word_count_reg <= tr_word_count_next;
    tag_reg <= tag_next;

    read_axi_addr_reg <= read_axi_addr_next;
    read_ram_sel_reg <= read_ram_sel_next;
    read_ram_addr_reg <= read_ram_addr_next;
    read_imm_en_reg <= read_imm_en_next;
    read_len_reg <= read_len_next;
    read_ram_mask_reg <= read_ram_mask_next;
    read_ram_mask_0_reg <= read_ram_mask_0_next;
    read_ram_mask_1_reg <= read_ram_mask_1_next;
    ram_wrap_reg <= ram_wrap_next;
    read_cycle_count_reg <= read_cycle_count_next;
    read_last_cycle_reg <= read_last_cycle_next;
    cycle_byte_count_reg <= cycle_byte_count_next;
    start_offset_reg <= start_offset_next;
    end_offset_reg <= end_offset_next;

    axi_addr_reg <= axi_addr_next;
    axi_imm_reg <= axi_imm_next;
    axi_imm_en_reg <= axi_imm_en_next;
    axi_len_reg <= axi_len_next;
    axi_zero_len_reg <= axi_zero_len_next;
    offset_reg <= offset_next;
    strb_offset_mask_reg <= strb_offset_mask_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_valid_reg <= ram_mask_valid_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    read_cmd_axi_addr_reg <= read_cmd_axi_addr_next;
    read_cmd_ram_sel_reg <= read_cmd_ram_sel_next;
    read_cmd_ram_addr_reg <= read_cmd_ram_addr_next;
    read_cmd_imm_en_reg <= read_cmd_imm_en_next;
    read_cmd_len_reg <= read_cmd_len_next;
    read_cmd_cycle_count_reg <= read_cmd_cycle_count_next;
    read_cmd_last_cycle_reg <= read_cmd_last_cycle_next;
    read_cmd_valid_reg <= read_cmd_valid_next;

    m_axi_awid_reg <= m_axi_awid_next;
    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;
    m_axi_bready_reg <= m_axi_bready_next;

    wr_desc_req_ready_reg <= wr_desc_req_ready_next;

    wr_desc_sts_tag_reg <= wr_desc_sts_tag_next;
    wr_desc_sts_error_reg <= wr_desc_sts_error_next;
    wr_desc_sts_valid_reg <= wr_desc_sts_valid_next;

    status_busy_reg <= active_op_count_reg != 0;

    stat_wr_op_start_tag_reg <= stat_wr_op_start_tag_next;
    stat_wr_op_start_valid_reg <= stat_wr_op_start_valid_next;
    stat_wr_op_finish_tag_reg <= stat_wr_op_finish_tag_next;
    stat_wr_op_finish_status_reg <= stat_wr_op_finish_status_next;
    stat_wr_op_finish_valid_reg <= stat_wr_op_finish_valid_next;
    stat_wr_req_start_tag_reg <= stat_wr_req_start_tag_next;
    stat_wr_req_start_len_reg <= stat_wr_req_start_len_next;
    stat_wr_req_start_valid_reg <= stat_wr_req_start_valid_next;
    stat_wr_req_finish_tag_reg <= stat_wr_req_finish_tag_next;
    stat_wr_req_finish_status_reg <= stat_wr_req_finish_status_next;
    stat_wr_req_finish_valid_reg <= stat_wr_req_finish_valid_next;
    stat_wr_op_tbl_full_reg <= stat_wr_op_tbl_full_next;
    stat_wr_tx_stall_reg <= stat_wr_tx_stall_next;

    ram_rd_cmd_sel_reg <= ram_rd_cmd_sel_next;
    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    active_op_count_reg <= active_op_count_reg + OP_TAG_W'(inc_active_op) - OP_TAG_W'(dec_active_op);

    if (mask_fifo_we) begin
        mask_fifo_mask[mask_fifo_wr_ptr_reg[MASK_FIFO_AW-1:0]] <= mask_fifo_wr_mask;
        mask_fifo_wr_ptr_reg <= mask_fifo_wr_ptr_reg + 1;
    end
    mask_fifo_rd_ptr_reg <= mask_fifo_rd_ptr_next;

    if (op_tbl_start_en) begin
        op_tbl_start_ptr_reg <= op_tbl_start_ptr_reg + 1;
        op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= 1'b1;
        op_tbl_write_complete[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= 1'b0;
        op_tbl_axi_addr[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_axi_addr;
        op_tbl_imm[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_imm;
        op_tbl_imm_en[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_imm_en;
        op_tbl_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_len;
        op_tbl_zero_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_zero_len;
        op_tbl_cycle_count[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_cycle_count;
        op_tbl_offset[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_offset;
        op_tbl_tag[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_tag;
        op_tbl_last[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_last;
    end

    if (op_tbl_tx_start_en) begin
        op_tbl_tx_start_ptr_reg <= op_tbl_tx_start_ptr_reg + 1;
    end

    if (op_tbl_tx_finish_en) begin
        op_tbl_tx_finish_ptr_reg <= op_tbl_tx_finish_ptr_reg + 1;
    end

    if (USE_AXI_ID && op_tbl_write_complete_en) begin
        op_tbl_write_complete[op_tbl_write_complete_ptr] <= 1'b1;
        op_tbl_error_code[op_tbl_write_complete_ptr] <= op_tbl_write_complete_error;
    end

    if (op_tbl_finish_en) begin
        op_tbl_finish_ptr_reg <= op_tbl_finish_ptr_reg + 1;
        op_tbl_active[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] <= 1'b0;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        read_state_reg <= READ_STATE_IDLE;
        axi_state_reg <= AXI_STATE_IDLE;

        read_cmd_valid_reg <= 1'b0;

        ram_mask_valid_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;

        wr_desc_req_ready_reg <= 1'b0;
        wr_desc_sts_error_reg <= 4'd0;
        wr_desc_sts_valid_reg <= 1'b0;

        status_busy_reg <= 1'b0;

        stat_wr_op_start_tag_reg <= '0;
        stat_wr_op_start_valid_reg <= 1'b0;
        stat_wr_op_finish_tag_reg <= '0;
        stat_wr_op_finish_valid_reg <= 1'b0;
        stat_wr_req_start_valid_reg <= 1'b0;
        stat_wr_req_finish_valid_reg <= 1'b0;
        stat_wr_op_tbl_full_reg <= 1'b0;
        stat_wr_tx_stall_reg <= 1'b0;

        ram_rd_cmd_valid_reg <= '0;

        active_op_count_reg <= '0;

        mask_fifo_wr_ptr_reg <= '0;
        mask_fifo_rd_ptr_reg <= '0;

        op_tbl_start_ptr_reg <= '0;
        op_tbl_tx_start_ptr_reg <= '0;
        op_tbl_tx_finish_ptr_reg <= '0;
        op_tbl_finish_ptr_reg <= '0;
        op_tbl_active <= '0;
    end
end

// output datapath logic
logic [AXI_DATA_W-1:0] m_axi_wdata_reg  = '0;
logic [AXI_STRB_W-1:0] m_axi_wstrb_reg  = '0;
logic                  m_axi_wlast_reg  = 1'b0;
logic                  m_axi_wvalid_reg = 1'b0;

logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_wr_ptr_reg = '0;
logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_rd_ptr_reg = '0;
logic out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_AW{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXI_DATA_W-1:0] out_fifo_wdata[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXI_STRB_W-1:0] out_fifo_wstrb[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic                  out_fifo_wlast[2**OUTPUT_FIFO_AW];

assign m_axi_wready_int = !out_fifo_half_full_reg;

assign m_axi_wr.wdata  = m_axi_wdata_reg;
assign m_axi_wr.wstrb  = m_axi_wstrb_reg;
assign m_axi_wr.wvalid = m_axi_wvalid_reg;
assign m_axi_wr.wlast  = m_axi_wlast_reg;

always_ff @(posedge clk) begin
    m_axi_wvalid_reg <= m_axi_wvalid_reg && !m_axi_wr.wready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_AW-1);

    if (!out_fifo_full && m_axi_wvalid_int) begin
        out_fifo_wdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axi_wdata_int;
        out_fifo_wstrb[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axi_wstrb_int;
        out_fifo_wlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axi_wlast_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axi_wvalid_reg || m_axi_wr.wready)) begin
        m_axi_wdata_reg <= out_fifo_wdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axi_wstrb_reg <= out_fifo_wstrb[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axi_wlast_reg <= out_fifo_wlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axi_wvalid_reg <= 1'b1;
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= '0;
        out_fifo_rd_ptr_reg <= '0;
        m_axi_wvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
