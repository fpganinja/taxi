// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * UltraScale PCIe DMA write interface
 */
module taxi_dma_if_pcie_us_wr #
(
    // RQ sequence number width
    parameter RQ_SEQ_NUM_W = 6,
    // RQ sequence number tracking enable
    parameter logic RQ_SEQ_NUM_EN = 1'b0,
    // Operation table size
    parameter OP_TBL_SIZE = 2**(RQ_SEQ_NUM_W-1),
    // In-flight transmit limit
    parameter TX_LIMIT = 2**(RQ_SEQ_NUM_W-1),
    // Transmit flow control
    parameter logic TX_FC_EN = 1'b0
)
(
    input  wire logic                            clk,
    input  wire logic                            rst,

    /*
     * UltraScale PCIe interface
     */
    taxi_axis_if.snk                             s_axis_rq,
    taxi_axis_if.src                             m_axis_rq,

    /*
     * Transmit sequence number input
     */
    input  wire logic [RQ_SEQ_NUM_W-1:0]         s_axis_rq_seq_num_0,
    input  wire logic                            s_axis_rq_seq_num_valid_0,
    input  wire logic [RQ_SEQ_NUM_W-1:0]         s_axis_rq_seq_num_1,
    input  wire logic                            s_axis_rq_seq_num_valid_1,

    /*
     * Transmit flow control
     */
    input  wire logic [7:0]                      pcie_tx_fc_ph_av,
    input  wire logic [11:0]                     pcie_tx_fc_pd_av,

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
    input  wire logic [15:0]                     requester_id,
    input  wire logic                            requester_id_en,
    input  wire logic [2:0]                      max_payload_size,

    /*
     * Status
     */
    output wire logic                            stat_busy,

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
    output wire logic                            stat_wr_tx_limit,
    output wire logic                            stat_wr_tx_stall
);

// TODO cleanup
// verilator lint_off WIDTHEXPAND

// extract parameters
localparam AXIS_PCIE_DATA_W = m_axis_rq.DATA_W;
localparam AXIS_PCIE_KEEP_W = m_axis_rq.KEEP_W;
localparam AXIS_PCIE_RQ_USER_W = m_axis_rq.USER_W;

localparam IMM_EN = wr_desc_req.IMM_EN;
localparam IMM_W = wr_desc_req.IMM_W;
localparam LEN_W = wr_desc_req.LEN_W;
localparam TAG_W = wr_desc_req.TAG_W;

localparam RAM_SEL_W = dma_ram_rd.SEL_W;
localparam RAM_SEGS = dma_ram_rd.SEGS;
localparam RAM_SEG_DATA_W = dma_ram_rd.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_rd.SEG_BE_W;
localparam RAM_SEG_ADDR_W = dma_ram_rd.SEG_ADDR_W;

localparam RAM_ADDR_W = RAM_SEG_ADDR_W+$clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam RAM_DATA_W = RAM_SEGS*RAM_SEG_DATA_W;
localparam RAM_BYTE_LANES = RAM_SEG_BE_W;
localparam RAM_BYTE_SIZE = RAM_SEG_DATA_W/RAM_BYTE_LANES;

localparam AXIS_PCIE_WORD_W = AXIS_PCIE_KEEP_W;
localparam AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_W/AXIS_PCIE_WORD_W;

localparam OFFSET_W = $clog2(AXIS_PCIE_DATA_W/8);
localparam RAM_OFFSET_W = $clog2(RAM_SEGS*RAM_SEG_DATA_W/8);
localparam WORD_LEN_W = LEN_W - $clog2(AXIS_PCIE_KEEP_W);
localparam CYCLE_COUNT_W = 13-$clog2(AXIS_PCIE_KEEP_W*4);

localparam SEQ_NUM_MASK = {RQ_SEQ_NUM_W-1{1'b1}};
localparam SEQ_NUM_FLAG = {1'b1, {RQ_SEQ_NUM_W-1{1'b0}}};

localparam MASK_FIFO_AW = $clog2(OP_TBL_SIZE)+1;

localparam OP_TAG_W = $clog2(OP_TBL_SIZE);

localparam OUTPUT_FIFO_AW = 5;

localparam PCIE_ADDR_W = 64;

// check configuration
if (AXIS_PCIE_DATA_W != 64 && AXIS_PCIE_DATA_W != 128 && AXIS_PCIE_DATA_W != 256 && AXIS_PCIE_DATA_W != 512)
    $fatal(0, "Error: PCIe interface width must be 64, 128, or 256 (instance %m)");

if (AXIS_PCIE_KEEP_W * 32 != AXIS_PCIE_DATA_W)
    $fatal(0, "Error: PCIe interface requires DWORD (32-bit) granularity (instance %m)");

if (AXIS_PCIE_DATA_W == 512) begin
    if (AXIS_PCIE_RQ_USER_W != 137)
        $fatal(0, "Error: PCIe RQ tuser width must be 137 (instance %m)");
end else begin
    if (AXIS_PCIE_RQ_USER_W != 60 && AXIS_PCIE_RQ_USER_W != 62)
        $fatal(0, "Error: PCIe RQ tuser width must be 60 or 62 (instance %m)");
end

if (AXIS_PCIE_RQ_USER_W == 60) begin
    if (RQ_SEQ_NUM_W != 4)
        $fatal(0, "Error: RQ sequence number width must be 4 (instance %m)");
end else begin
    if (RQ_SEQ_NUM_W != 6)
        $fatal(0, "Error: RQ sequence number width must be 6 (instance %m)");
end

if (RQ_SEQ_NUM_EN && OP_TBL_SIZE > 2**(RQ_SEQ_NUM_W-1))
    $fatal(0, "Error: Operation table size of range (instance %m)");

if (RQ_SEQ_NUM_EN && TX_LIMIT > 2**(RQ_SEQ_NUM_W-1))
    $fatal(0, "Error: TX limit out of range (instance %m)");

if (RAM_SEGS < 2)
    $fatal(0, "Error: RAM interface requires at least 2 segments (instance %m)");

if (RAM_SEGS*RAM_SEG_DATA_W != AXIS_PCIE_DATA_W*2)
    $fatal(0, "Error: RAM interface width must be double the PCIe interface width (instance %m)");

if (RAM_SEG_BE_W * 8 != RAM_SEG_DATA_W)
    $fatal(0, "Error: RAM interface requires byte (8-bit) granularity (instance %m)");

if (2**$clog2(RAM_BYTE_LANES) != RAM_BYTE_LANES)
    $fatal(0, "Error: RAM word width must be even power of two (instance %m)");

if (wr_desc_req.SRC_ADDR_W < RAM_ADDR_W || wr_desc_req.DST_ADDR_W < PCIE_ADDR_W)
    $fatal(0, "Error: Descriptor address width is not sufficient (instance %m)");

typedef enum logic [3:0] {
    REQ_MEM_READ = 4'b0000,
    REQ_MEM_WRITE = 4'b0001,
    REQ_IO_READ = 4'b0010,
    REQ_IO_WRITE = 4'b0011,
    REQ_MEM_FETCH_ADD = 4'b0100,
    REQ_MEM_SWAP = 4'b0101,
    REQ_MEM_CAS = 4'b0110,
    REQ_MEM_READ_LOCKED = 4'b0111,
    REQ_CFG_READ_0 = 4'b1000,
    REQ_CFG_READ_1 = 4'b1001,
    REQ_CFG_WRITE_0 = 4'b1010,
    REQ_CFG_WRITE_1 = 4'b1011,
    REQ_MSG = 4'b1100,
    REQ_MSG_VENDOR = 4'b1101,
    REQ_MSG_ATS = 4'b1110
} req_type_t;

typedef enum logic [2:0] {
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100  // completer abort
} cpl_status_t;

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

typedef enum logic [1:0] {
    TLP_STATE_IDLE,
    TLP_STATE_HEADER,
    TLP_STATE_TRANSFER
} tlp_state_t;

tlp_state_t tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

typedef enum logic [1:0] {
    TLP_OUTPUT_STATE_IDLE,
    TLP_OUTPUT_STATE_HEADER,
    TLP_OUTPUT_STATE_PAYLOAD,
    TLP_OUTPUT_STATE_PASSTHROUGH
} tlp_output_state_t;

tlp_output_state_t tlp_output_state_reg = TLP_OUTPUT_STATE_IDLE, tlp_output_state_next;

// datapath control signals
logic mask_fifo_we;

logic read_cmd_ready;

logic [PCIE_ADDR_W-1:0] pcie_addr_reg = '0, pcie_addr_next;
logic [RAM_SEL_W-1:0] ram_sel_reg = '0, ram_sel_next;
logic [RAM_ADDR_W-1:0] ram_addr_reg = '0, ram_addr_next;
logic [LEN_W-1:0] op_count_reg = '0, op_count_next;
logic [12:0] tlp_count_reg = '0, tlp_count_next;
logic zero_len_reg = 1'b0, zero_len_next;
logic [TAG_W-1:0] tag_reg = '0, tag_next;

logic [PCIE_ADDR_W-1:0] read_pcie_addr_reg = '0, read_pcie_addr_next;
logic [RAM_SEL_W-1:0] read_ram_sel_reg = '0, read_ram_sel_next;
logic [RAM_ADDR_W-1:0] read_ram_addr_reg = '0, read_ram_addr_next;
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

logic [PCIE_ADDR_W-1:0] tlp_addr_reg = '0, tlp_addr_next;
logic [11:0] tlp_len_reg = '0, tlp_len_next;
logic tlp_zero_len_reg = 1'b0, tlp_zero_len_next;
logic [RAM_OFFSET_W-1:0] offset_reg = '0, offset_next;
logic [10:0] dword_count_reg = '0, dword_count_next;
logic [RAM_SEGS-1:0] ram_mask_reg = '0, ram_mask_next;
logic ram_mask_valid_reg = 1'b0, ram_mask_valid_next;
logic [CYCLE_COUNT_W-1:0] cycle_count_reg = '0, cycle_count_next;
logic last_cycle_reg = 1'b0, last_cycle_next;

logic [PCIE_ADDR_W-1:0] read_cmd_pcie_addr_reg = '0, read_cmd_pcie_addr_next;
logic [RAM_SEL_W-1:0] read_cmd_ram_sel_reg = '0, read_cmd_ram_sel_next;
logic [RAM_ADDR_W-1:0] read_cmd_ram_addr_reg = '0, read_cmd_ram_addr_next;
logic [12:0] read_cmd_len_reg = '0, read_cmd_len_next;
logic [CYCLE_COUNT_W-1:0] read_cmd_cycle_count_reg = '0, read_cmd_cycle_count_next;
logic read_cmd_last_cycle_reg = 1'b0, read_cmd_last_cycle_next;
logic read_cmd_valid_reg = 1'b0, read_cmd_valid_next;

logic [127:0] tlp_header_data;
logic [AXIS_PCIE_RQ_USER_W-1:0] tlp_tuser;
logic [127:0] tlp_header_data_reg = '0, tlp_header_data_next;
logic tlp_header_valid_reg = 1'b0, tlp_header_valid_next;
logic [AXIS_PCIE_DATA_W-1:0] tlp_payload_data_reg = '0, tlp_payload_data_next;
logic [AXIS_PCIE_KEEP_W-1:0] tlp_payload_keep_reg = '0, tlp_payload_keep_next;
logic tlp_payload_valid_reg = 1'b0, tlp_payload_valid_next;
logic tlp_payload_last_reg = 1'b0, tlp_payload_last_next;
logic [3:0] tlp_first_be_reg = '0, tlp_first_be_next;
logic [3:0] tlp_last_be_reg = '0, tlp_last_be_next;
logic [RQ_SEQ_NUM_W-1:0] tlp_seq_num_reg = '0, tlp_seq_num_next;

logic [MASK_FIFO_AW+1-1:0] mask_fifo_wr_ptr_reg = '0;
logic [MASK_FIFO_AW+1-1:0] mask_fifo_rd_ptr_reg = '0, mask_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_SEGS-1:0] mask_fifo_mask[2**MASK_FIFO_AW];
logic [RAM_SEGS-1:0] mask_fifo_wr_mask;

wire mask_fifo_empty = mask_fifo_wr_ptr_reg == mask_fifo_rd_ptr_reg;
wire mask_fifo_full = mask_fifo_wr_ptr_reg == (mask_fifo_rd_ptr_reg ^ (1 << MASK_FIFO_AW));

logic [10:0] max_payload_size_dw_reg = '0;

logic have_credit_reg = 1'b0;

logic [RQ_SEQ_NUM_W-1:0] active_tx_count_reg = '0;
logic active_tx_count_av_reg = 1'b1;
logic inc_active_tx;

logic [OP_TAG_W+1-1:0] active_op_count_reg = '0;
logic inc_active_op;
logic dec_active_op;

logic s_axis_rq_tready_reg = 1'b0, s_axis_rq_tready_next;

logic wr_desc_req_ready_reg = 1'b0, wr_desc_req_ready_next;

logic [TAG_W-1:0] wr_desc_sts_tag_reg = '0, wr_desc_sts_tag_next;
logic wr_desc_sts_valid_reg = 1'b0, wr_desc_sts_valid_next;

logic [RAM_SEGS-1:0][RAM_SEL_W-1:0] ram_rd_cmd_sel_reg = '0, ram_rd_cmd_sel_next;
logic [RAM_SEGS-1:0][RAM_SEG_ADDR_W-1:0] ram_rd_cmd_addr_reg = '0, ram_rd_cmd_addr_next;
logic [RAM_SEGS-1:0] ram_rd_cmd_valid_reg = '0, ram_rd_cmd_valid_next;
logic [RAM_SEGS-1:0] ram_rd_resp_ready_cmb;

logic stat_busy_reg = 1'b0;

logic [OP_TAG_W-1:0] stat_wr_op_start_tag_reg = '0, stat_wr_op_start_tag_next;
logic stat_wr_op_start_valid_reg = 1'b0, stat_wr_op_start_valid_next;
logic [OP_TAG_W-1:0] stat_wr_op_finish_tag_reg = '0, stat_wr_op_finish_tag_next;
logic stat_wr_op_finish_valid_reg = 1'b0, stat_wr_op_finish_valid_next;
logic [OP_TAG_W-1:0] stat_wr_req_start_tag_reg = '0, stat_wr_req_start_tag_next;
logic [12:0] stat_wr_req_start_len_reg = '0, stat_wr_req_start_len_next;
logic stat_wr_req_start_valid_reg = 1'b0, stat_wr_req_start_valid_next;
logic [OP_TAG_W-1:0] stat_wr_req_finish_tag_reg = '0, stat_wr_req_finish_tag_next;
logic stat_wr_req_finish_valid_reg = 1'b0, stat_wr_req_finish_valid_next;
logic stat_wr_op_tbl_full_reg = 1'b0, stat_wr_op_tbl_full_next;
logic stat_wr_tx_limit_reg = 1'b0, stat_wr_tx_limit_next;
logic stat_wr_tx_stall_reg = 1'b0, stat_wr_tx_stall_next;

// internal datapath
logic  [AXIS_PCIE_DATA_W-1:0]    m_axis_rq_tdata_int;
logic  [AXIS_PCIE_KEEP_W-1:0]    m_axis_rq_tkeep_int;
logic                            m_axis_rq_tvalid_int;
wire                             m_axis_rq_tready_int;
logic                            m_axis_rq_tlast_int;
logic  [AXIS_PCIE_RQ_USER_W-1:0] m_axis_rq_tuser_int;

assign s_axis_rq.tready = s_axis_rq_tready_reg;

assign wr_desc_req.req_ready = wr_desc_req_ready_reg;

assign wr_desc_sts.sts_tag = wr_desc_sts_tag_reg;
assign wr_desc_sts.sts_error = '0;
assign wr_desc_sts.sts_valid = wr_desc_sts_valid_reg;

assign dma_ram_rd.rd_cmd_sel = ram_rd_cmd_sel_reg;
assign dma_ram_rd.rd_cmd_addr = ram_rd_cmd_addr_reg;
assign dma_ram_rd.rd_cmd_valid = ram_rd_cmd_valid_reg;
assign dma_ram_rd.rd_resp_ready = ram_rd_resp_ready_cmb;

assign stat_busy = stat_busy_reg;

assign stat_wr_op_start_tag = stat_wr_op_start_tag_reg;
assign stat_wr_op_start_valid = stat_wr_op_start_valid_reg;
assign stat_wr_op_finish_tag = stat_wr_op_finish_tag_reg;
assign stat_wr_op_finish_status = 4'd0;
assign stat_wr_op_finish_valid = stat_wr_op_finish_valid_reg;
assign stat_wr_req_start_tag = stat_wr_req_start_tag_reg;
assign stat_wr_req_start_len = stat_wr_req_start_len_reg;
assign stat_wr_req_start_valid = stat_wr_req_start_valid_reg;
assign stat_wr_req_finish_tag = stat_wr_req_finish_tag_reg;
assign stat_wr_req_finish_status = 4'd00;
assign stat_wr_req_finish_valid = stat_wr_req_finish_valid_reg;
assign stat_wr_op_tbl_full = stat_wr_op_tbl_full_reg;
assign stat_wr_tx_limit = stat_wr_tx_limit_reg;
assign stat_wr_tx_stall = stat_wr_tx_stall_reg;

wire axis_rq_seq_num_valid_0_int = s_axis_rq_seq_num_valid_0 && (s_axis_rq_seq_num_0 & SEQ_NUM_FLAG) != 0;
wire axis_rq_seq_num_valid_1_int = s_axis_rq_seq_num_valid_1 && (s_axis_rq_seq_num_1 & SEQ_NUM_FLAG) != 0;

// operation tag management
logic [OP_TAG_W+1-1:0] op_tbl_start_ptr_reg = '0;
logic [PCIE_ADDR_W-1:0] op_tbl_start_pcie_addr;
logic [11:0] op_tbl_start_len;
logic op_tbl_start_zero_len;
logic [10:0] op_tbl_start_dword_len;
logic [CYCLE_COUNT_W-1:0] op_tbl_start_cycle_count;
logic [RAM_OFFSET_W-1:0] op_tbl_start_offset;
logic [TAG_W-1:0] op_tbl_start_tag;
logic op_tbl_start_last;
logic op_tbl_start_en;
logic [OP_TAG_W+1-1:0] op_tbl_tx_start_ptr_reg = '0;
logic op_tbl_tx_start_en;
logic [OP_TAG_W+1-1:0] op_tbl_tx_finish_ptr_reg = '0;
logic op_tbl_tx_finish_en;
logic [OP_TAG_W+1-1:0] op_tbl_finish_ptr_reg = '0;
logic op_tbl_finish_en;

logic [2**OP_TAG_W-1:0] op_tbl_active = '0;
logic [2**OP_TAG_W-1:0] op_tbl_tx_done = '0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [PCIE_ADDR_W-1:0] op_tbl_pcie_addr[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [11:0] op_tbl_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_zero_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [10:0] op_tbl_dword_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [CYCLE_COUNT_W-1:0] op_tbl_cycle_count[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_OFFSET_W-1:0] op_tbl_offset[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [TAG_W-1:0] op_tbl_tag[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_last[2**OP_TAG_W] = '{default: '0};

always_comb begin
    req_state_next = REQ_STATE_IDLE;

    wr_desc_req_ready_next = 1'b0;

    stat_wr_op_start_tag_next = stat_wr_op_start_tag_reg;
    stat_wr_op_start_valid_next = 1'b0;
    stat_wr_req_start_tag_next = stat_wr_req_start_tag_reg;
    stat_wr_req_start_len_next = stat_wr_req_start_len_reg;
    stat_wr_req_start_valid_next = 1'b0;
    stat_wr_op_tbl_full_next = !(!op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W));
    stat_wr_tx_limit_next = (RQ_SEQ_NUM_EN && !active_tx_count_av_reg);
    stat_wr_tx_stall_next = m_axis_rq.tvalid && !m_axis_rq.tready;

    pcie_addr_next = pcie_addr_reg;
    ram_sel_next = ram_sel_reg;
    ram_addr_next = ram_addr_reg;
    op_count_next = op_count_reg;
    tlp_count_next = tlp_count_reg;
    zero_len_next = zero_len_reg;
    tag_next = tag_reg;

    read_cmd_pcie_addr_next = read_cmd_pcie_addr_reg;
    read_cmd_ram_sel_next = read_cmd_ram_sel_reg;
    read_cmd_ram_addr_next = read_cmd_ram_addr_reg;
    read_cmd_len_next = read_cmd_len_reg;
    read_cmd_cycle_count_next = read_cmd_cycle_count_reg;
    read_cmd_last_cycle_next = read_cmd_last_cycle_reg;
    read_cmd_valid_next = read_cmd_valid_reg && !read_cmd_ready;

    op_tbl_start_pcie_addr = pcie_addr_reg;
    op_tbl_start_len = 12'(tlp_count_reg);
    op_tbl_start_zero_len = zero_len_reg;
    op_tbl_start_dword_len = 11'((tlp_count_reg + 13'(pcie_addr_reg[1:0]) + 13'd3) >> 2);
    op_tbl_start_cycle_count = '0;
    if (AXIS_PCIE_DATA_W >= 256) begin
        op_tbl_start_offset = RAM_OFFSET_W'(16)+RAM_OFFSET_W'(pcie_addr_reg[1:0])-ram_addr_reg[RAM_OFFSET_W-1:0];
    end else begin
        op_tbl_start_offset = RAM_OFFSET_W'(pcie_addr_reg[1:0])-ram_addr_reg[RAM_OFFSET_W-1:0];
    end
    op_tbl_start_tag = tag_reg;
    op_tbl_start_last = op_count_reg == LEN_W'(tlp_count_reg);
    op_tbl_start_en = 1'b0;

    inc_active_op = 1'b0;

    // TLP segmentation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            // idle state, wait for incoming descriptor
            wr_desc_req_ready_next = !op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && enable;

            pcie_addr_next = wr_desc_req.req_dst_addr;
            ram_sel_next = wr_desc_req.req_src_sel;
            ram_addr_next = wr_desc_req.req_src_addr;
            if (wr_desc_req.req_len == 0) begin
                // zero-length operation
                op_count_next = 1;
                zero_len_next = 1'b1;
            end else begin
                op_count_next = wr_desc_req.req_len;
                zero_len_next = 1'b0;
            end
            tag_next = wr_desc_req.req_tag;

            // TLP size computation
            if (op_count_next <= LEN_W'({max_payload_size_dw_reg, 2'b00})-LEN_W'(pcie_addr_next[1:0])) begin
                // packet smaller than max payload size
                if ((12'(pcie_addr_next & 12'hfff) + 12'(op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                    // crosses 4k boundary
                    tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary, send one TLP
                    tlp_count_next = 13'(op_count_next);
                end
            end else begin
                // packet larger than max payload size
                if ((12'(pcie_addr_next & 12'hfff) + {max_payload_size_dw_reg, 2'b00}) >> 12 != 0) begin
                    // crosses 4k boundary
                    tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary, send one TLP
                    tlp_count_next = {max_payload_size_dw_reg, 2'b00}-13'(pcie_addr_next[1:0]);
                end
            end

            if (wr_desc_req.req_ready & wr_desc_req.req_valid) begin
                wr_desc_req_ready_next = 1'b0;
                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            // start state, compute TLP length
            if (!op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && (!read_cmd_valid_reg || read_cmd_ready)) begin
                read_cmd_pcie_addr_next = pcie_addr_reg;
                read_cmd_ram_sel_next = ram_sel_reg;
                read_cmd_ram_addr_next = ram_addr_reg;
                read_cmd_len_next = tlp_count_reg;
                if (AXIS_PCIE_DATA_W >= 256) begin
                    read_cmd_cycle_count_next = CYCLE_COUNT_W'((tlp_count_reg + 16+pcie_addr_reg[1:0] - 1) >> $clog2(AXIS_PCIE_DATA_W/8));
                    end else begin
                    read_cmd_cycle_count_next = CYCLE_COUNT_W'((tlp_count_reg + pcie_addr_reg[1:0] - 1) >> $clog2(AXIS_PCIE_DATA_W/8));
                end
                op_tbl_start_cycle_count = read_cmd_cycle_count_next;
                read_cmd_last_cycle_next = read_cmd_cycle_count_next == 0;
                read_cmd_valid_next = 1'b1;

                pcie_addr_next = pcie_addr_reg + PCIE_ADDR_W'(tlp_count_reg);
                ram_addr_next = ram_addr_reg + RAM_ADDR_W'(tlp_count_reg);
                op_count_next = op_count_reg - LEN_W'(tlp_count_reg);

                op_tbl_start_pcie_addr = pcie_addr_reg;
                op_tbl_start_len = 12'(tlp_count_reg);
                op_tbl_start_zero_len = zero_len_reg;
                op_tbl_start_dword_len = 11'((tlp_count_reg + 13'(pcie_addr_reg[1:0]) + 13'd3) >> 2);
                if (AXIS_PCIE_DATA_W >= 256) begin
                    op_tbl_start_offset = RAM_OFFSET_W'(16)+RAM_OFFSET_W'(pcie_addr_reg[1:0])-ram_addr_reg[RAM_OFFSET_W-1:0];
                end else begin
                    op_tbl_start_offset = RAM_OFFSET_W'(pcie_addr_reg[1:0])-ram_addr_reg[RAM_OFFSET_W-1:0];
                end
                op_tbl_start_last = op_count_reg == LEN_W'(tlp_count_reg);

                op_tbl_start_tag = tag_reg;
                op_tbl_start_en = 1'b1;
                inc_active_op = 1'b1;

                // TLP size computation
                if (op_count_next <= LEN_W'({max_payload_size_dw_reg, 2'b00})-LEN_W'(pcie_addr_next[1:0])) begin
                    // packet smaller than max payload size
                    if ((12'(pcie_addr_next & 12'hfff) + 12'(op_count_next & 12'hfff)) >> 12 != 0 || op_count_next >> 12 != 0) begin
                        // crosses 4k boundary
                        tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary, send one TLP
                        tlp_count_next = 13'(op_count_next);
                    end
                end else begin
                    // packet larger than max payload size
                    if ((12'(pcie_addr_next & 12'hfff) + {max_payload_size_dw_reg, 2'b00}) >> 12 != 0) begin
                        // crosses 4k boundary
                        tlp_count_next = 13'h1000 - pcie_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary, send one TLP
                        tlp_count_next = {max_payload_size_dw_reg, 2'b00}-13'(pcie_addr_next[1:0]);
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

    read_pcie_addr_next = read_pcie_addr_reg;
    read_ram_sel_next = read_ram_sel_reg;
    read_ram_addr_next = read_ram_addr_reg;
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

            read_pcie_addr_next = read_cmd_pcie_addr_reg;
            read_ram_sel_next = read_cmd_ram_sel_reg;
            read_ram_addr_next = read_cmd_ram_addr_reg;
            read_len_next = read_cmd_len_reg;
            read_cycle_count_next = read_cmd_cycle_count_reg;
            read_last_cycle_next = read_cmd_last_cycle_reg;

            if (AXIS_PCIE_DATA_W >= 256 && read_len_next > 13'(AXIS_PCIE_DATA_W/8-16)-13'(read_pcie_addr_next[1:0])) begin
                cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8-16)-(OFFSET_W+1)'(read_pcie_addr_next[1:0]);
            end else if (AXIS_PCIE_DATA_W <= 128 && read_len_next > 13'(AXIS_PCIE_DATA_W/8)-13'(read_pcie_addr_next[1:0])) begin
                cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8)-(OFFSET_W+1)'(read_pcie_addr_next[1:0]);
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
                read_ram_mask_1_next = 0;
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
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                    if (read_ram_mask_1_reg[i]) begin
                        ram_rd_cmd_addr_next[i] = read_ram_addr_reg[RAM_ADDR_W-1:RAM_ADDR_W-RAM_SEG_ADDR_W]+1;
                    end
                end

                mask_fifo_wr_mask = read_ram_mask_reg;
                mask_fifo_we = 1'b1;

                if (read_len_next > 13'(AXIS_PCIE_DATA_W/8)) begin
                    cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8);
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
                    read_ram_mask_1_next = 0;
                end else begin
                    read_ram_mask_next = read_ram_mask_0_next | read_ram_mask_1_next;
                end

                if (!read_last_cycle_reg) begin
                    read_state_next = READ_STATE_READ;
                end else begin
                    // skip idle state

                    read_pcie_addr_next = read_cmd_pcie_addr_reg;
                    read_ram_sel_next = read_cmd_ram_sel_reg;
                    read_ram_addr_next = read_cmd_ram_addr_reg;
                    read_len_next = read_cmd_len_reg;
                    read_cycle_count_next = read_cmd_cycle_count_reg;
                    read_last_cycle_next = read_cmd_last_cycle_reg;

                    if (AXIS_PCIE_DATA_W >= 256 && read_len_next > 13'(AXIS_PCIE_DATA_W/8-16)-13'(read_pcie_addr_next[1:0])) begin
                        cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8-16)-(OFFSET_W+1)'(read_pcie_addr_next[1:0]);
                    end else if (AXIS_PCIE_DATA_W <= 128 && read_len_next > 13'(AXIS_PCIE_DATA_W/8)-13'(read_pcie_addr_next[1:0])) begin
                        cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8)-(OFFSET_W+1)'(read_pcie_addr_next[1:0]);
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
                        read_ram_mask_1_next = 0;
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
            end else begin
                read_state_next = READ_STATE_READ;
            end
        end
    endcase
end

wire [3:0] first_be = 4'b1111 << tlp_addr_reg[1:0];
wire [3:0] last_be = 4'b1111 >> (3 - ((tlp_addr_reg[1:0] + tlp_len_reg[1:0] - 1) & 3));

always_comb begin
    tlp_state_next = TLP_STATE_IDLE;
    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;

    ram_rd_resp_ready_cmb = '0;

    tlp_addr_next = tlp_addr_reg;
    tlp_len_next = tlp_len_reg;
    tlp_zero_len_next = tlp_zero_len_reg;
    dword_count_next = dword_count_reg;
    offset_next = offset_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_valid_next = ram_mask_valid_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    tlp_header_data_next = tlp_header_data_reg;
    tlp_header_valid_next = tlp_header_valid_reg;
    tlp_payload_data_next = tlp_payload_data_reg;
    tlp_payload_keep_next = tlp_payload_keep_reg;
    tlp_payload_valid_next = tlp_payload_valid_reg;
    tlp_payload_last_next = tlp_payload_last_reg;
    tlp_first_be_next = tlp_first_be_reg;
    tlp_last_be_next = tlp_last_be_reg;
    tlp_seq_num_next = tlp_seq_num_reg;

    mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg;

    op_tbl_tx_start_en = 1'b0;
    op_tbl_tx_finish_en = 1'b0;

    inc_active_tx = 1'b0;
    dec_active_op = 1'b0;

    s_axis_rq_tready_next = 1'b0;

    // TLP header and sideband data
    tlp_header_data[1:0] = 2'b0; // address type
    tlp_header_data[63:2] = tlp_addr_reg[PCIE_ADDR_W-1:2]; // address
    tlp_header_data[74:64] = dword_count_reg; // DWORD count
    tlp_header_data[78:75] = REQ_MEM_WRITE; // request type - memory write
    tlp_header_data[79] = 1'b0; // poisoned request
    tlp_header_data[95:80] = requester_id;
    tlp_header_data[103:96] = 8'd0; // tag
    tlp_header_data[119:104] = 16'd0; // completer ID
    tlp_header_data[120] = requester_id_en; // requester ID enable
    tlp_header_data[123:121] = 3'b000; // traffic class
    tlp_header_data[126:124] = 3'b000; // attr
    tlp_header_data[127] = 1'b0; // force ECRC

    // broken linter
    // verilator lint_off SELRANGE
    // verilator lint_off WIDTHEXPAND
    // verilator lint_off WIDTHTRUNC
    if (AXIS_PCIE_DATA_W == 512) begin
        tlp_tuser[3:0] = tlp_first_be_reg; // first BE 0
        tlp_tuser[7:4] = 4'd0; // first BE 1
        tlp_tuser[11:8] = tlp_last_be_reg; // last BE 0
        tlp_tuser[15:12] = 4'd0; // last BE 1
        tlp_tuser[19:16] = 3'd0; // addr_offset
        tlp_tuser[21:20] = 2'b01; // is_sop
        tlp_tuser[23:22] = 2'd0; // is_sop0_ptr
        tlp_tuser[25:24] = 2'd0; // is_sop1_ptr
        tlp_tuser[27:26] = 2'b01; // is_eop
        tlp_tuser[31:28]  = 4'd3; // is_eop0_ptr
        tlp_tuser[35:32] = 4'd0; // is_eop1_ptr
        tlp_tuser[36] = 1'b0; // discontinue
        tlp_tuser[38:37] = 2'b00; // tph_present
        tlp_tuser[42:39] = 4'b0000; // tph_type
        tlp_tuser[44:43] = 2'b00; // tph_indirect_tag_en
        tlp_tuser[60:45] = 16'd0; // tph_st_tag
        tlp_tuser[66:61] = (tlp_seq_num_reg | SEQ_NUM_FLAG); // seq_num0
        tlp_tuser[72:67] = 6'd0; // seq_num1
        tlp_tuser[136:73] = 64'd0; // parity
    end else begin
        tlp_tuser[3:0] = tlp_first_be_reg; // first BE
        tlp_tuser[7:4] = tlp_last_be_reg; // last BE
        tlp_tuser[10:8] = 3'd0; // addr_offset
        tlp_tuser[11] = 1'b0; // discontinue
        tlp_tuser[12] = 1'b0; // tph_present
        tlp_tuser[14:13] = 2'b00; // tph_type
        tlp_tuser[15] = 1'b0; // tph_indirect_tag_en
        tlp_tuser[23:16] = 8'd0; // tph_st_tag
        tlp_tuser[27:24] = (tlp_seq_num_reg | SEQ_NUM_FLAG); // seq_num
        tlp_tuser[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_W == 62) begin
            tlp_tuser[61:60] = (tlp_seq_num_reg | SEQ_NUM_FLAG) >> 4; // seq_num
        end
    end
    // verilator lint_on SELRANGE
    // verilator lint_on WIDTHEXPAND
    // verilator lint_on WIDTHTRUNC

    // TLP output
    m_axis_rq_tdata_int = tlp_payload_data_reg;
    m_axis_rq_tkeep_int = tlp_payload_keep_reg;
    m_axis_rq_tvalid_int = 1'b0;
    m_axis_rq_tlast_int = tlp_payload_last_reg;
    m_axis_rq_tuser_int = tlp_tuser;

    // combine header and payload, merge in read request TLPs
    case (tlp_output_state_reg)
        TLP_OUTPUT_STATE_IDLE: begin
            // idle state
            s_axis_rq_tready_next = m_axis_rq_tready_int;

            if (s_axis_rq.tready && s_axis_rq.tvalid) begin
                // transfer read request through

                m_axis_rq_tdata_int = s_axis_rq.tdata;
                m_axis_rq_tkeep_int = s_axis_rq.tkeep;
                m_axis_rq_tvalid_int = s_axis_rq.tready && s_axis_rq.tvalid;
                m_axis_rq_tlast_int = s_axis_rq.tlast;
                m_axis_rq_tuser_int = s_axis_rq.tuser;

                if (s_axis_rq.tready && s_axis_rq.tvalid && s_axis_rq.tlast) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PASSTHROUGH;
                end
            end else if (AXIS_PCIE_DATA_W == 64 && tlp_header_valid_reg) begin
                // 64 bit interface, send first half of header
                // broken linter
                // verilator lint_off WIDTHEXPAND
                // verilator lint_off WIDTHTRUNC
                m_axis_rq_tdata_int = tlp_header_data_reg[63:0];
                m_axis_rq_tkeep_int = 2'b11;
                // verilator lint_on WIDTHEXPAND
                // verilator lint_on WIDTHTRUNC
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser;

                s_axis_rq_tready_next = 1'b0;
                tlp_output_state_next = TLP_OUTPUT_STATE_HEADER;
            end else if (AXIS_PCIE_DATA_W == 128 && tlp_header_valid_reg) begin
                // 128 bit interface, send complete header
                // broken linter
                // verilator lint_off WIDTHEXPAND
                // verilator lint_off WIDTHTRUNC
                m_axis_rq_tdata_int = tlp_header_data_reg;
                m_axis_rq_tkeep_int = 4'b1111;
                // verilator lint_on WIDTHEXPAND
                // verilator lint_on WIDTHTRUNC
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser;
                tlp_header_valid_next = 1'b0;

                s_axis_rq_tready_next = 1'b0;
                tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
            end else if (AXIS_PCIE_DATA_W >= 256 && tlp_header_valid_reg && tlp_payload_valid_reg) begin
                // send header and start of payload
                m_axis_rq_tdata_int = tlp_payload_data_reg;
                // broken linter
                // verilator lint_off SELRANGE
                // verilator lint_off WIDTHEXPAND
                // verilator lint_off WIDTHTRUNC
                m_axis_rq_tdata_int[127:0] = tlp_header_data_reg;
                m_axis_rq_tkeep_int = {tlp_payload_keep_reg, 4'b1111};
                // verilator lint_on SELRANGE
                // verilator lint_on WIDTHEXPAND
                // verilator lint_on WIDTHTRUNC
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = tlp_payload_last_reg;
                m_axis_rq_tuser_int = tlp_tuser;
                tlp_header_valid_next = 1'b0;
                tlp_payload_valid_next = 1'b0;

                if (tlp_payload_last_reg) begin
                    s_axis_rq_tready_next = m_axis_rq_tready_int;
                    tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
                end else begin
                    s_axis_rq_tready_next = 1'b0;
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                end
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end
        end
        TLP_OUTPUT_STATE_HEADER: begin
            // second cycle of header
            if (AXIS_PCIE_DATA_W == 64) begin
                // broken linter
                // verilator lint_off WIDTHEXPAND
                m_axis_rq_tdata_int = tlp_header_data_reg[127:64];
                m_axis_rq_tkeep_int = 2'b11;
                // verilator lint_on WIDTHEXPAND
                m_axis_rq_tvalid_int = tlp_header_valid_reg;
                m_axis_rq_tlast_int = 1'b0;
                m_axis_rq_tuser_int = tlp_tuser;
                tlp_header_valid_next = 1'b0;

                if (tlp_header_valid_reg) begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
                end else begin
                    tlp_output_state_next = TLP_OUTPUT_STATE_HEADER;
                end
            end
        end
        TLP_OUTPUT_STATE_PAYLOAD: begin
            // transfer payload
            m_axis_rq_tdata_int = tlp_payload_data_reg;
            m_axis_rq_tkeep_int = tlp_payload_keep_reg;
            m_axis_rq_tvalid_int = tlp_payload_valid_reg;
            m_axis_rq_tlast_int = tlp_payload_last_reg;
            m_axis_rq_tuser_int = tlp_tuser;
            tlp_payload_valid_next = 1'b0;

            if (tlp_payload_valid_reg && tlp_payload_last_reg) begin
                s_axis_rq_tready_next = m_axis_rq_tready_int;
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_PAYLOAD;
            end
        end
        TLP_OUTPUT_STATE_PASSTHROUGH: begin
            // pass through read request TLP
            s_axis_rq_tready_next = m_axis_rq_tready_int;

            m_axis_rq_tdata_int = s_axis_rq.tdata;
            m_axis_rq_tkeep_int = s_axis_rq.tkeep;
            m_axis_rq_tvalid_int = s_axis_rq.tready && s_axis_rq.tvalid;
            m_axis_rq_tlast_int = s_axis_rq.tlast;
            m_axis_rq_tuser_int = s_axis_rq.tuser;

            if (s_axis_rq.tready && s_axis_rq.tvalid && s_axis_rq.tlast) begin
                tlp_output_state_next = TLP_OUTPUT_STATE_IDLE;
            end else begin
                tlp_output_state_next = TLP_OUTPUT_STATE_PASSTHROUGH;
            end
        end
    endcase

    // read response processing and TLP generation
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for command
            ram_rd_resp_ready_cmb = '0;

            tlp_addr_next = op_tbl_pcie_addr[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            tlp_len_next = op_tbl_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            tlp_zero_len_next = op_tbl_zero_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            dword_count_next = op_tbl_dword_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            offset_next = op_tbl_offset[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            cycle_count_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
            last_cycle_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] == 0;

            if (op_tbl_active[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] && op_tbl_tx_start_ptr_reg != op_tbl_start_ptr_reg && (!TX_FC_EN || have_credit_reg) && (!RQ_SEQ_NUM_EN || active_tx_count_av_reg)) begin
                op_tbl_tx_start_en = 1'b1;
                tlp_state_next = TLP_STATE_HEADER;
            end else begin
                tlp_state_next = TLP_STATE_IDLE;
            end
        end
        TLP_STATE_HEADER: begin
            // header state, send TLP header
            if (!tlp_header_valid_next) begin
                tlp_header_data_next = tlp_header_data;

                if (tlp_zero_len_reg) begin
                    tlp_first_be_next = 4'b0000;
                    tlp_last_be_next = 4'b0000;
                end else begin
                    tlp_first_be_next = dword_count_reg == 1 ? first_be & last_be : first_be;
                    tlp_last_be_next = dword_count_reg == 1 ? 4'b0000 : last_be;
                end
                tlp_seq_num_next = RQ_SEQ_NUM_W'(op_tbl_tx_finish_ptr_reg[OP_TAG_W-1:0] & SEQ_NUM_MASK);
            end

            if (AXIS_PCIE_DATA_W >= 256) begin

                if (!tlp_payload_valid_next) begin
                    tlp_payload_data_next = AXIS_PCIE_DATA_W'({2{dma_ram_rd.rd_resp_data}} >> (RAM_SEGS*RAM_SEG_DATA_W-offset_reg*8));
                    if (dword_count_reg >= 11'(AXIS_PCIE_KEEP_W)) begin
                        tlp_payload_keep_next = {AXIS_PCIE_KEEP_W{1'b1}};
                    end else begin
                        tlp_payload_keep_next = {AXIS_PCIE_KEEP_W{1'b1}} >> (11'(AXIS_PCIE_KEEP_W) - dword_count_reg);
                    end
                    tlp_payload_last_next = 1'b0;
                end

                ram_rd_resp_ready_cmb = '0;

                if ((ram_mask_reg & ~dma_ram_rd.rd_resp_valid) == 0 && ram_mask_valid_reg && m_axis_rq_tready_int && !tlp_header_valid_next && !tlp_payload_valid_next) begin
                    // transfer in read data
                    ram_rd_resp_ready_cmb = ram_mask_reg;
                    ram_mask_valid_next = 1'b0;

                    // update counters
                    dword_count_next = dword_count_reg - 11'(AXIS_PCIE_KEEP_W-4);
                    cycle_count_next = cycle_count_reg - 1;
                    last_cycle_next = cycle_count_next == 0;
                    offset_next = offset_reg + RAM_OFFSET_W'(AXIS_PCIE_DATA_W/8);

                    tlp_header_valid_next = 1'b1;
                    tlp_payload_valid_next = 1'b1;

                    inc_active_tx = 1'b1;

                    if (last_cycle_reg) begin
                        tlp_payload_last_next = 1'b1;
                        op_tbl_tx_finish_en = 1'b1;

                        // skip idle state if possible
                        tlp_addr_next = op_tbl_pcie_addr[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                        tlp_len_next = op_tbl_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                        tlp_zero_len_next = op_tbl_zero_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                        dword_count_next = op_tbl_dword_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                        offset_next = op_tbl_offset[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                        cycle_count_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                        last_cycle_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] == 0;

                        if (op_tbl_active[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] && op_tbl_tx_start_ptr_reg != op_tbl_start_ptr_reg && !s_axis_rq.tvalid && (!TX_FC_EN || have_credit_reg) && (!RQ_SEQ_NUM_EN || active_tx_count_av_reg)) begin
                            op_tbl_tx_start_en = 1'b1;
                            tlp_state_next = TLP_STATE_HEADER;
                        end else begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end
                    end else begin
                        tlp_state_next = TLP_STATE_TRANSFER;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_HEADER;
                end
            end else begin
                if (m_axis_rq_tready_int && !tlp_header_valid_next) begin
                    tlp_header_valid_next = 1'b1;

                    inc_active_tx = 1'b1;

                    tlp_state_next = TLP_STATE_TRANSFER;
                end else begin
                    tlp_state_next = TLP_STATE_HEADER;
                end
            end
        end
        TLP_STATE_TRANSFER: begin
            // transfer state, transfer data

            if (!tlp_payload_valid_next) begin
                tlp_payload_data_next = AXIS_PCIE_DATA_W'({2{dma_ram_rd.rd_resp_data}} >> (RAM_SEGS*RAM_SEG_DATA_W-offset_reg*8));
                if (dword_count_reg >= 11'(AXIS_PCIE_KEEP_W)) begin
                    tlp_payload_keep_next = {AXIS_PCIE_KEEP_W{1'b1}};
                end else begin
                    tlp_payload_keep_next = {AXIS_PCIE_KEEP_W{1'b1}} >> (11'(AXIS_PCIE_KEEP_W) - dword_count_reg);
                end
                tlp_payload_last_next = 1'b0;
            end

            ram_rd_resp_ready_cmb = '0;

            if ((ram_mask_reg & ~dma_ram_rd.rd_resp_valid) == 0 && ram_mask_valid_reg && m_axis_rq_tready_int && !tlp_payload_valid_next) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;
                ram_mask_valid_next = 1'b0;

                // update counters
                dword_count_next = dword_count_reg - 11'(AXIS_PCIE_KEEP_W);
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;
                offset_next = offset_reg + RAM_OFFSET_W'(AXIS_PCIE_DATA_W/8);

                tlp_payload_valid_next = 1'b1;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    tlp_payload_last_next = 1'b1;
                    op_tbl_tx_finish_en = 1'b1;

                    // skip idle state if possible
                    tlp_addr_next = op_tbl_pcie_addr[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    tlp_len_next = op_tbl_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    tlp_zero_len_next = op_tbl_zero_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    dword_count_next = op_tbl_dword_len[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    offset_next = op_tbl_offset[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    cycle_count_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]];
                    last_cycle_next = op_tbl_cycle_count[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] == 0;

                    if (op_tbl_active[op_tbl_tx_start_ptr_reg[OP_TAG_W-1:0]] && op_tbl_tx_start_ptr_reg != op_tbl_start_ptr_reg && !s_axis_rq.tvalid && (!TX_FC_EN || have_credit_reg) && (!RQ_SEQ_NUM_EN || active_tx_count_av_reg)) begin
                        op_tbl_tx_start_en = 1'b1;
                        tlp_state_next = TLP_STATE_HEADER;
                    end else begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end
                end else begin
                    tlp_state_next = TLP_STATE_TRANSFER;
                end
            end else begin
                tlp_state_next = TLP_STATE_TRANSFER;
            end
        end
        default: begin
            // invalid state
            tlp_state_next = TLP_STATE_IDLE;
        end
    endcase

    if (!ram_mask_valid_next && !mask_fifo_empty) begin
        ram_mask_next = mask_fifo_mask[mask_fifo_rd_ptr_reg[MASK_FIFO_AW-1:0]];
        ram_mask_valid_next = 1'b1;
        mask_fifo_rd_ptr_next = mask_fifo_rd_ptr_reg+1;
    end

    wr_desc_sts_tag_next = op_tbl_tag[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
    wr_desc_sts_valid_next = 1'b0;

    op_tbl_finish_en = 1'b0;

    if (op_tbl_active[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] && (!RQ_SEQ_NUM_EN || op_tbl_tx_done[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]]) && op_tbl_finish_ptr_reg != op_tbl_tx_finish_ptr_reg) begin
        op_tbl_finish_en = 1'b1;
        dec_active_op = 1'b1;

        if (op_tbl_last[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]]) begin
            wr_desc_sts_valid_next = 1'b1;
        end
    end
end

always_ff @(posedge clk) begin
    req_state_reg <= req_state_next;
    read_state_reg <= read_state_next;
    tlp_state_reg <= tlp_state_next;
    tlp_output_state_reg <= tlp_output_state_next;

    pcie_addr_reg <= pcie_addr_next;
    ram_sel_reg <= ram_sel_next;
    ram_addr_reg <= ram_addr_next;
    op_count_reg <= op_count_next;
    tlp_count_reg <= tlp_count_next;
    zero_len_reg <= zero_len_next;
    tag_reg <= tag_next;

    read_pcie_addr_reg <= read_pcie_addr_next;
    read_ram_sel_reg <= read_ram_sel_next;
    read_ram_addr_reg <= read_ram_addr_next;
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

    tlp_addr_reg <= tlp_addr_next;
    tlp_len_reg <= tlp_len_next;
    tlp_zero_len_reg <= tlp_zero_len_next;
    dword_count_reg <= dword_count_next;
    offset_reg <= offset_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_valid_reg <= ram_mask_valid_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    read_cmd_pcie_addr_reg <= read_cmd_pcie_addr_next;
    read_cmd_ram_sel_reg <= read_cmd_ram_sel_next;
    read_cmd_ram_addr_reg <= read_cmd_ram_addr_next;
    read_cmd_len_reg <= read_cmd_len_next;
    read_cmd_cycle_count_reg <= read_cmd_cycle_count_next;
    read_cmd_last_cycle_reg <= read_cmd_last_cycle_next;
    read_cmd_valid_reg <= read_cmd_valid_next;

    stat_busy_reg <= active_op_count_reg != 0 || active_tx_count_reg != 0;

    stat_wr_op_start_tag_reg <= stat_wr_op_start_tag_next;
    stat_wr_op_start_valid_reg <= stat_wr_op_start_valid_next;
    stat_wr_op_finish_tag_reg <= stat_wr_op_finish_tag_next;
    stat_wr_op_finish_valid_reg <= stat_wr_op_finish_valid_next;
    stat_wr_req_start_tag_reg <= stat_wr_req_start_tag_next;
    stat_wr_req_start_len_reg <= stat_wr_req_start_len_next;
    stat_wr_req_start_valid_reg <= stat_wr_req_start_valid_next;
    stat_wr_req_finish_tag_reg <= stat_wr_req_finish_tag_next;
    stat_wr_req_finish_valid_reg <= stat_wr_req_finish_valid_next;
    stat_wr_op_tbl_full_reg <= stat_wr_op_tbl_full_next;
    stat_wr_tx_limit_reg <= stat_wr_tx_limit_next;
    stat_wr_tx_stall_reg <= stat_wr_tx_stall_next;

    tlp_header_data_reg <= tlp_header_data_next;
    tlp_header_valid_reg <= tlp_header_valid_next;
    tlp_payload_data_reg <= tlp_payload_data_next;
    tlp_payload_keep_reg <= tlp_payload_keep_next;
    tlp_payload_valid_reg <= tlp_payload_valid_next;
    tlp_payload_last_reg <= tlp_payload_last_next;
    tlp_first_be_reg <= tlp_first_be_next;
    tlp_last_be_reg <= tlp_last_be_next;
    tlp_seq_num_reg <= tlp_seq_num_next;

    s_axis_rq_tready_reg <= s_axis_rq_tready_next;

    wr_desc_req_ready_reg <= wr_desc_req_ready_next;

    wr_desc_sts_valid_reg <= wr_desc_sts_valid_next;
    wr_desc_sts_tag_reg <= wr_desc_sts_tag_next;

    ram_rd_cmd_sel_reg <= ram_rd_cmd_sel_next;
    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    max_payload_size_dw_reg <= 11'd32 << (max_payload_size > 5 ? 5 : max_payload_size);

    // TODO cleanup
    // verilator lint_off WIDTHEXPAND
    have_credit_reg <= (pcie_tx_fc_ph_av > 4) && (pcie_tx_fc_pd_av > (max_payload_size_dw_reg >> 1));

    if (active_tx_count_reg < TX_LIMIT && inc_active_tx && !axis_rq_seq_num_valid_0_int && !axis_rq_seq_num_valid_1_int) begin
        // inc by 1
        active_tx_count_reg <= active_tx_count_reg + 1;
        active_tx_count_av_reg <= active_tx_count_reg < (TX_LIMIT-1);
    end else if (active_tx_count_reg > 0 && ((inc_active_tx && axis_rq_seq_num_valid_0_int && axis_rq_seq_num_valid_1_int) || (!inc_active_tx && (axis_rq_seq_num_valid_0_int ^ axis_rq_seq_num_valid_1_int)))) begin
        // dec by 1
        active_tx_count_reg <= active_tx_count_reg - 1;
        active_tx_count_av_reg <= 1'b1;
    end else if (active_tx_count_reg > 1 && !inc_active_tx && axis_rq_seq_num_valid_0_int && axis_rq_seq_num_valid_1_int) begin
        // dec by 2
        active_tx_count_reg <= active_tx_count_reg - 2;
        active_tx_count_av_reg <= 1'b1;
    end else begin
        active_tx_count_av_reg <= active_tx_count_reg < TX_LIMIT;
    end

    active_op_count_reg <= active_op_count_reg + inc_active_op - dec_active_op;

    if (mask_fifo_we) begin
        mask_fifo_mask[mask_fifo_wr_ptr_reg[MASK_FIFO_AW-1:0]] <= mask_fifo_wr_mask;
        mask_fifo_wr_ptr_reg <= mask_fifo_wr_ptr_reg + 1;
    end
    mask_fifo_rd_ptr_reg <= mask_fifo_rd_ptr_next;

    if (op_tbl_start_en) begin
        op_tbl_start_ptr_reg <= op_tbl_start_ptr_reg + 1;
        op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= 1'b1;
        op_tbl_tx_done[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= 1'b0;
        op_tbl_pcie_addr[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_pcie_addr;
        op_tbl_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_len;
        op_tbl_zero_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_zero_len;
        op_tbl_dword_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_dword_len;
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

    if (axis_rq_seq_num_valid_0_int) begin
        op_tbl_tx_done[s_axis_rq_seq_num_0[OP_TAG_W-1:0]] <= 1'b1;
    end

    if (axis_rq_seq_num_valid_1_int) begin
        op_tbl_tx_done[s_axis_rq_seq_num_1[OP_TAG_W-1:0]] <= 1'b1;
    end

    if (op_tbl_finish_en) begin
        op_tbl_finish_ptr_reg <= op_tbl_finish_ptr_reg + 1;
        op_tbl_active[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] <= 1'b0;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        read_state_reg <= READ_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;
        tlp_output_state_reg <= TLP_OUTPUT_STATE_IDLE;

        read_cmd_valid_reg <= 1'b0;

        tlp_header_valid_reg <= 1'b0;
        tlp_payload_valid_reg <= 1'b0;

        ram_mask_valid_reg <= 1'b0;

        s_axis_rq_tready_reg <= 1'b0;
        wr_desc_req_ready_reg <= 1'b0;
        wr_desc_sts_valid_reg <= 1'b0;
        ram_rd_cmd_valid_reg <= '0;

        stat_wr_op_start_valid_reg <= 1'b0;
        stat_wr_op_finish_valid_reg <= 1'b0;
        stat_wr_req_start_valid_reg <= 1'b0;
        stat_wr_req_finish_valid_reg <= 1'b0;
        stat_wr_op_tbl_full_reg <= 1'b0;
        stat_wr_tx_limit_reg <= 1'b0;
        stat_wr_tx_stall_reg <= 1'b0;

        active_tx_count_reg <= '0;
        active_tx_count_av_reg <= 1'b1;

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

// output datapath logic (PCIe TLP)
logic [AXIS_PCIE_DATA_W-1:0]    m_axis_rq_tdata_reg = '0;
logic [AXIS_PCIE_KEEP_W-1:0]    m_axis_rq_tkeep_reg = '0;
logic                           m_axis_rq_tvalid_reg = 1'b0, m_axis_rq_tvalid_next;
logic                           m_axis_rq_tlast_reg = 1'b0;
logic [AXIS_PCIE_RQ_USER_W-1:0] m_axis_rq_tuser_reg = '0;

logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_wr_ptr_reg = '0;
logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_rd_ptr_reg = '0;
logic out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_AW{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed" *)
logic [AXIS_PCIE_DATA_W-1:0]    out_fifo_tdata[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed" *)
logic [AXIS_PCIE_KEEP_W-1:0]    out_fifo_tkeep[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed" *)
logic                           out_fifo_tlast[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed" *)
logic [AXIS_PCIE_RQ_USER_W-1:0] out_fifo_tuser[2**OUTPUT_FIFO_AW];

assign m_axis_rq_tready_int = !out_fifo_half_full_reg;

assign m_axis_rq.tdata = m_axis_rq_tdata_reg;
assign m_axis_rq.tkeep = m_axis_rq_tkeep_reg;
assign m_axis_rq.tvalid = m_axis_rq_tvalid_reg;
assign m_axis_rq.tlast = m_axis_rq_tlast_reg;
assign m_axis_rq.tuser = m_axis_rq_tuser_reg;

always_ff @(posedge clk) begin
    m_axis_rq_tvalid_reg <= m_axis_rq_tvalid_reg && !m_axis_rq.tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_AW-1);

    if (!out_fifo_full && m_axis_rq_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rq_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rq_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rq_tlast_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rq_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_rq_tvalid_reg || m_axis_rq.tready)) begin
        m_axis_rq_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rq_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rq_tvalid_reg <= 1'b1;
        m_axis_rq_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rq_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= '0;
        out_fifo_rd_ptr_reg <= '0;
        m_axis_rq_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
