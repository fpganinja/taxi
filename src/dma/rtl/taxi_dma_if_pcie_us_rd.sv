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
 * UltraScale PCIe DMA read interface
 */
module taxi_dma_if_pcie_us_rd #
(
    // RQ sequence number width
    parameter RQ_SEQ_NUM_W = 6,
    // RQ sequence number tracking enable
    parameter logic RQ_SEQ_NUM_EN = 1'b0,
    // PCIe tag count
    parameter PCIE_TAG_CNT = 64,
    // Operation table size
    parameter OP_TBL_SIZE = PCIE_TAG_CNT,
    // In-flight transmit limit
    parameter TX_LIMIT = 2**(RQ_SEQ_NUM_W-1),
    // Transmit flow control
    parameter logic TX_FC_EN = 1'b0,
    // Completion header flow control credit limit
    parameter CPLH_FC_LIMIT = 0,
    // Completion data flow control credit limit
    parameter CPLD_FC_LIMIT = CPLH_FC_LIMIT*4
)
(
    input  wire logic                             clk,
    input  wire logic                             rst,

    /*
     * UltraScale PCIe interface
     */
    taxi_axis_if.src                              m_axis_rq,
    taxi_axis_if.snk                              s_axis_rc,

    /*
     * Transmit sequence number input
     */
    input  wire logic [RQ_SEQ_NUM_W-1:0]          s_axis_rq_seq_num_0,
    input  wire logic                             s_axis_rq_seq_num_valid_0,
    input  wire logic [RQ_SEQ_NUM_W-1:0]          s_axis_rq_seq_num_1,
    input  wire logic                             s_axis_rq_seq_num_valid_1,

    /*
     * Transmit flow control
     */
    input  wire logic [7:0]                       pcie_tx_fc_nph_av,

    /*
     * Read descriptor
     */
    taxi_dma_desc_if.req_snk                      rd_desc_req,
    taxi_dma_desc_if.sts_src                      rd_desc_sts,

    /*
     * RAM interface
     */
    taxi_dma_ram_if.wr_mst                        dma_ram_wr,

    /*
     * Configuration
     */
    input  wire logic                             enable,
    input  wire logic                             ext_tag_en,
    input  wire logic                             rcb_128b,
    input  wire logic [15:0]                      requester_id,
    input  wire logic                             requester_id_en,
    input  wire logic [2:0]                       max_rd_req_size,

    /*
     * Status
     */
    output wire logic                             stat_busy,
    output wire logic                             stat_err_cor,
    output wire logic                             stat_err_uncor,

    /*
     * Statistics
     */
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]   stat_rd_op_start_tag,
    output wire logic                             stat_rd_op_start_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]   stat_rd_op_finish_tag,
    output wire logic [3:0]                       stat_rd_op_finish_status,
    output wire logic                             stat_rd_op_finish_valid,
    output wire logic [$clog2(PCIE_TAG_CNT)-1:0]  stat_rd_req_start_tag,
    output wire logic [12:0]                      stat_rd_req_start_len,
    output wire logic                             stat_rd_req_start_valid,
    output wire logic [$clog2(PCIE_TAG_CNT)-1:0]  stat_rd_req_finish_tag,
    output wire logic [3:0]                       stat_rd_req_finish_status,
    output wire logic                             stat_rd_req_finish_valid,
    output wire logic                             stat_rd_req_timeout,
    output wire logic                             stat_rd_op_tbl_full,
    output wire logic                             stat_rd_no_tags,
    output wire logic                             stat_rd_tx_limit,
    output wire logic                             stat_rd_tx_stall
);

// TODO cleanup
// verilator lint_off WIDTHEXPAND

// extract parameters
localparam AXIS_PCIE_DATA_W = m_axis_rq.DATA_W;
localparam AXIS_PCIE_KEEP_W = m_axis_rq.KEEP_W;
localparam AXIS_PCIE_RQ_USER_W = m_axis_rq.USER_W;
localparam AXIS_PCIE_RC_USER_W = s_axis_rc.USER_W;

localparam LEN_W = rd_desc_req.LEN_W;
localparam TAG_W = rd_desc_req.TAG_W;

localparam RAM_SEL_W = dma_ram_wr.SEL_W;
localparam RAM_SEGS = dma_ram_wr.SEGS;
localparam RAM_SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_wr.SEG_BE_W;
localparam RAM_SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;

localparam RAM_ADDR_W = RAM_SEG_ADDR_W+$clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam RAM_DATA_W = RAM_SEGS*RAM_SEG_DATA_W;
localparam RAM_BYTE_LANES = RAM_SEG_BE_W;
localparam RAM_BYTE_SIZE = RAM_SEG_DATA_W/RAM_BYTE_LANES;

localparam AXIS_PCIE_WORD_W = AXIS_PCIE_KEEP_W;
localparam AXIS_PCIE_WORD_SIZE = AXIS_PCIE_DATA_W/AXIS_PCIE_WORD_W;

localparam OFFSET_W = $clog2(AXIS_PCIE_DATA_W/8);
localparam RAM_OFFSET_W = $clog2(RAM_SEGS*RAM_SEG_DATA_W/8);

localparam SEQ_NUM_MASK = {RQ_SEQ_NUM_W-1{1'b1}};
localparam SEQ_NUM_FLAG = {1'b1, {RQ_SEQ_NUM_W-1{1'b0}}};

localparam PCIE_TAG_W = $clog2(PCIE_TAG_CNT);
localparam PCIE_TAG_CNT_1 = 2**PCIE_TAG_W > 32 ? 32 : 2**PCIE_TAG_W;
localparam PCIE_TAG_W_1 = $clog2(PCIE_TAG_CNT_1);
localparam PCIE_TAG_CNT_2 = 2**PCIE_TAG_W > 32 ? 2**PCIE_TAG_W-32 : 0;
localparam PCIE_TAG_W_2 = $clog2(PCIE_TAG_CNT_2);

localparam OP_TAG_W = $clog2(OP_TBL_SIZE);
localparam OP_TBL_RD_COUNT_W = PCIE_TAG_W+1;

localparam CL_CPLH_FC_LIMIT = $clog2(CPLH_FC_LIMIT);
localparam CL_CPLD_FC_LIMIT = $clog2(CPLD_FC_LIMIT);

localparam STATUS_FIFO_AW = 5;
localparam OUTPUT_FIFO_AW = 5;

localparam INIT_COUNT_W = PCIE_TAG_W > OP_TAG_W ? PCIE_TAG_W : OP_TAG_W;

localparam PCIE_ADDR_W = 64;

// check configuration
if (AXIS_PCIE_DATA_W != 64 && AXIS_PCIE_DATA_W != 128 && AXIS_PCIE_DATA_W != 256 && AXIS_PCIE_DATA_W != 512)
    $fatal(0, "Error: PCIe interface width must be 64, 128, or 256 (instance %m)");

if (AXIS_PCIE_KEEP_W * 32 != AXIS_PCIE_DATA_W)
    $fatal(0, "Error: PCIe interface requires DWORD (32-bit) granularity (instance %m)");

if (AXIS_PCIE_DATA_W == 512) begin
    if (AXIS_PCIE_RC_USER_W != 161)
        $fatal(0, "Error: PCIe RC tuser width must be 161 (instance %m)");

    if (AXIS_PCIE_RQ_USER_W != 137)
        $fatal(0, "Error: PCIe RQ tuser width must be 137 (instance %m)");
end else begin
    if (AXIS_PCIE_RC_USER_W != 75)
        $fatal(0, "Error: PCIe RC tuser width must be 75 (instance %m)");

    if (AXIS_PCIE_RQ_USER_W != 60 && AXIS_PCIE_RQ_USER_W != 62)
        $fatal(0, "Error: PCIe RQ tuser width must be 60 or 62 (instance %m)");
end

if (AXIS_PCIE_RQ_USER_W == 60) begin
    if (RQ_SEQ_NUM_EN && RQ_SEQ_NUM_W != 4)
        $fatal(0, "Error: RQ sequence number width must be 4 (instance %m)");

    if (PCIE_TAG_CNT > 64)
        $fatal(0, "Error: PCIe tag count must be no larger than 64 (instance %m)");
end else begin
    if (RQ_SEQ_NUM_EN && RQ_SEQ_NUM_W != 6)
        $fatal(0, "Error: RQ sequence number width must be 6 (instance %m)");

    if (PCIE_TAG_CNT > 256)
        $fatal(0, "Error: PCIe tag count must be no larger than 256 (instance %m)");
end

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

if (PCIE_TAG_CNT < 1 || PCIE_TAG_CNT > 256)
    $fatal(0, "Error: PCIe tag count must be between 1 and 256 (instance %m)");

if (rd_desc_req.SRC_ADDR_W < PCIE_ADDR_W || rd_desc_req.DST_ADDR_W < RAM_ADDR_W)
    $fatal(0, "Error: Descriptor address width is not sufficient (instance %m)");

localparam logic [3:0]
    REQ_MEM_READ = 4'b0000,
    REQ_MEM_WRITE = 4'b0001,
    REQ_IO_READ = 4'b0010,
    REQ_IO_WRITE = 4'b0011,
    REQ_MEM_FETCH_ADD = 4'b0100,
    REQ_MEM_SWAP = 4'b0101,
    REQ_MEM_CAS = 4'b0110,
    REQ_MEM_RD_LOCKED = 4'b0111,
    REQ_CFG_RD_0 = 4'b1000,
    REQ_CFG_RD_1 = 4'b1001,
    REQ_CFG_WRITE_0 = 4'b1010,
    REQ_CFG_WRITE_1 = 4'b1011,
    REQ_MSG = 4'b1100,
    REQ_MSG_VENDOR = 4'b1101,
    REQ_MSG_ATS = 4'b1110;

localparam logic [2:0]
    CPL_STATUS_SC  = 3'b000, // successful completion
    CPL_STATUS_UR  = 3'b001, // unsupported request
    CPL_STATUS_CRS = 3'b010, // configuration request retry status
    CPL_STATUS_CA  = 3'b100; // completer abort

localparam logic [3:0]
    RC_ERR_NORMAL_TERM = 4'b0000,
    RC_ERR_POISONED = 4'b0001,
    RC_ERR_BAD_STATUS = 4'b0010,
    RC_ERR_INVALID_LEN = 4'b0011,
    RC_ERR_MISMATCH = 4'b0100,
    RC_ERR_INVALID_ADDR = 4'b0101,
    RC_ERR_INVALID_TAG = 4'b0110,
    RC_ERR_TIMEOUT = 4'b1001,
    RC_ERR_FLR = 4'b1000;

localparam logic [3:0]
    DMA_ERR_NONE = 4'd0,
    DMA_ERR_TIMEOUT = 4'd1,
    DMA_ERR_PARITY = 4'd2,
    DMA_ERR_AXI_RD_SLVERR = 4'd4,
    DMA_ERR_AXI_RD_DECERR = 4'd5,
    DMA_ERR_AXI_WR_SLVERR = 4'd6,
    DMA_ERR_AXI_WR_DECERR = 4'd7,
    DMA_ERR_PCIE_FLR = 4'd8,
    DMA_ERR_PCIE_CPL_POISONED = 4'd9,
    DMA_ERR_PCIE_CPL_STATUS_UR = 4'd10,
    DMA_ERR_PCIE_CPL_STATUS_CA = 4'd11;

localparam logic [1:0]
    REQ_STATE_IDLE = 2'd0,
    REQ_STATE_START = 2'd1,
    REQ_STATE_HEADER = 2'd2;

logic [1:0] req_state_reg = REQ_STATE_IDLE, req_state_next;

localparam logic [1:0]
    TLP_STATE_IDLE = 2'd0,
    TLP_STATE_HEADER = 2'd1,
    TLP_STATE_WRITE = 2'd2,
    TLP_STATE_WAIT_END = 2'd3;

logic [1:0] tlp_state_reg = TLP_STATE_IDLE, tlp_state_next;

// datapath control signals
logic last_cycle;

logic [3:0] req_first_be;
logic [3:0] req_last_be;
logic [12:0] req_tlp_count;
logic [10:0] req_dword_count;
logic [6:0] req_cplh_fc_count;
logic [8:0] req_cpld_fc_count;
logic req_last_tlp;
logic [PCIE_ADDR_W-1:0] req_pcie_addr;

logic [INIT_COUNT_W-1:0] init_count_reg = 0;
logic init_done_reg = 1'b0;
logic init_pcie_tag_reg = 1'b1;
logic init_op_tag_reg = 1'b1;

logic [PCIE_ADDR_W-1:0] req_pcie_addr_reg = '0, req_pcie_addr_next;
logic [RAM_SEL_W-1:0] req_ram_sel_reg = '0, req_ram_sel_next;
logic [RAM_ADDR_W-1:0] req_ram_addr_reg = '0, req_ram_addr_next;
logic [LEN_W-1:0] req_op_count_reg = '0, req_op_count_next;
logic req_zero_len_reg = 1'b0, req_zero_len_next;
logic [OP_TAG_W-1:0] req_op_tag_reg = '0, req_op_tag_next;
logic req_op_tag_valid_reg = 1'b0, req_op_tag_valid_next;
logic [PCIE_TAG_W-1:0] req_pcie_tag_reg = '0, req_pcie_tag_next;
logic req_pcie_tag_valid_reg = 1'b0, req_pcie_tag_valid_next;

logic [11:0] lower_addr_reg = '0, lower_addr_next;
logic [12:0] byte_count_reg = '0, byte_count_next;
logic [3:0] error_code_reg = '0, error_code_next;
logic [RAM_SEL_W-1:0] ram_sel_reg = '0, ram_sel_next;
logic [RAM_ADDR_W-1:0] addr_reg = '0, addr_next;
logic [RAM_ADDR_W-1:0] addr_delay_reg = '0, addr_delay_next;
logic [10:0] op_dword_count_reg = '0, op_dword_count_next;
logic [12:0] op_count_reg = '0, op_count_next;
logic zero_len_reg = 1'b0, zero_len_next;
logic [RAM_SEGS-1:0] ram_mask_reg = '0, ram_mask_next;
logic [RAM_SEGS-1:0] ram_mask_0_reg = '0, ram_mask_0_next;
logic [RAM_SEGS-1:0] ram_mask_1_reg = '0, ram_mask_1_next;
logic ram_wrap_reg = 1'b0, ram_wrap_next;
logic [OFFSET_W+1-1:0] cycle_byte_count_reg = '0, cycle_byte_count_next;
logic [RAM_OFFSET_W-1:0] start_offset_reg = '0, start_offset_next;
logic [RAM_OFFSET_W-1:0] end_offset_reg = '0, end_offset_next;
logic [2:0] cpl_status_reg = 3'b000, cpl_status_next;
logic [PCIE_TAG_W-1:0] pcie_tag_reg = '0, pcie_tag_next;
logic [OP_TAG_W-1:0] op_tag_reg = '0, op_tag_next;
logic final_cpl_reg = 1'b0, final_cpl_next;
logic finish_tag_reg = 1'b0, finish_tag_next;

logic [OFFSET_W-1:0] offset_reg = '0, offset_next;

logic [AXIS_PCIE_DATA_W-1:0] rc_tdata_int_reg = '0, rc_tdata_int_next;
logic rc_tvalid_int_reg = 1'b0, rc_tvalid_int_next;

logic [127:0] tlp_header_data;
logic [AXIS_PCIE_RQ_USER_W-1:0] tlp_tuser;

logic [10:0] max_rd_req_size_dw_reg = '0;
logic rcb_128b_reg = 1'b0;

logic have_credit_reg = 1'b0;

logic [STATUS_FIFO_AW+1-1:0] status_fifo_wr_ptr_reg = '0;
logic [STATUS_FIFO_AW+1-1:0] status_fifo_rd_ptr_reg = '0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [OP_TAG_W-1:0] status_fifo_op_tag[2**STATUS_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_SEGS-1:0] status_fifo_mask[2**STATUS_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic status_fifo_finish[2**STATUS_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [3:0] status_fifo_error[2**STATUS_FIFO_AW];
logic [OP_TAG_W-1:0] status_fifo_wr_op_tag;
logic [RAM_SEGS-1:0] status_fifo_wr_mask;
logic status_fifo_wr_finish;
logic [3:0] status_fifo_wr_error;
logic status_fifo_wr_en;
logic status_fifo_mask_reg = 1'b0, status_fifo_mask_next;
logic status_fifo_finish_reg = 1'b0, status_fifo_finish_next;
logic [3:0] status_fifo_error_reg = '0, status_fifo_error_next;
logic status_fifo_wr_en_reg = 1'b0, status_fifo_wr_en_next;
logic status_fifo_full_reg = 1'b0;
logic status_fifo_rd_en;
logic [OP_TAG_W-1:0] status_fifo_rd_op_tag_reg = '0;
logic [RAM_SEGS-1:0] status_fifo_rd_mask_reg = '0;
logic status_fifo_rd_finish_reg = 1'b0;
logic [3:0] status_fifo_rd_error_reg = '0;
logic status_fifo_rd_valid_reg = 1'b0, status_fifo_rd_valid_next;

logic [RQ_SEQ_NUM_W-1:0] active_tx_count_reg = '0, active_tx_count_next;
logic active_tx_count_av_reg = 1'b1, active_tx_count_av_next;
logic inc_active_tx;

logic [PCIE_TAG_W+1-1:0] active_tag_count_reg = '0;
logic inc_active_tag;
logic dec_active_tag;

logic [OP_TAG_W+1-1:0] active_op_count_reg = '0;
logic inc_active_op;
logic dec_active_op;

logic [CL_CPLH_FC_LIMIT+1-1:0] active_cplh_fc_count_reg = '0, active_cplh_fc_count_next;
logic active_cplh_fc_av_reg = 1'b1, active_cplh_fc_av_next;
logic [6:0] inc_active_cplh_fc_count;
logic [6:0] dec_active_cplh_fc_count;

logic [CL_CPLD_FC_LIMIT+1-1:0] active_cpld_fc_count_reg = '0, active_cpld_fc_count_next;
logic active_cpld_fc_av_reg = 1'b1, active_cpld_fc_av_next;
logic [8:0] inc_active_cpld_fc_count;
logic [8:0] dec_active_cpld_fc_count;

logic s_axis_rc_tready_reg = 1'b0, s_axis_rc_tready_next;

logic rd_desc_req_ready_reg = 1'b0, rd_desc_req_ready_next;

logic [TAG_W-1:0] rd_desc_sts_tag_reg = '0, rd_desc_sts_tag_next;
logic [3:0] rd_desc_sts_error_reg = DMA_ERR_NONE, rd_desc_sts_error_next;
logic rd_desc_sts_valid_reg = 1'b0, rd_desc_sts_valid_next;

logic stat_busy_reg = 1'b0;
logic stat_err_cor_reg = 1'b0, stat_err_cor_next;
logic stat_err_uncor_reg = 1'b0, stat_err_uncor_next;

logic [OP_TAG_W-1:0] stat_rd_op_start_tag_reg = '0, stat_rd_op_start_tag_next;
logic stat_rd_op_start_valid_reg = 1'b0, stat_rd_op_start_valid_next;
logic [OP_TAG_W-1:0] stat_rd_op_finish_tag_reg = '0, stat_rd_op_finish_tag_next;
logic [3:0] stat_rd_op_finish_status_reg = 4'd0, stat_rd_op_finish_status_next;
logic stat_rd_op_finish_valid_reg = 1'b0, stat_rd_op_finish_valid_next;
logic [PCIE_TAG_W-1:0] stat_rd_req_start_tag_reg = '0, stat_rd_req_start_tag_next;
logic [12:0] stat_rd_req_start_len_reg = 13'd0, stat_rd_req_start_len_next;
logic stat_rd_req_start_valid_reg = 1'b0, stat_rd_req_start_valid_next;
logic [PCIE_TAG_W-1:0] stat_rd_req_finish_tag_reg = '0, stat_rd_req_finish_tag_next;
logic [3:0] stat_rd_req_finish_status_reg = 4'd0, stat_rd_req_finish_status_next;
logic stat_rd_req_finish_valid_reg = 1'b0, stat_rd_req_finish_valid_next;
logic stat_rd_req_timeout_reg = 1'b0, stat_rd_req_timeout_next;
logic stat_rd_op_tbl_full_reg = 1'b0, stat_rd_op_tbl_full_next;
logic stat_rd_no_tags_reg = 1'b0, stat_rd_no_tags_next;
logic stat_rd_tx_limit_reg = 1'b0, stat_rd_tx_limit_next;
logic stat_rd_tx_stall_reg = 1'b0, stat_rd_tx_stall_next;

// internal datapath
logic [AXIS_PCIE_DATA_W-1:0]     m_axis_rq_tdata_int;
logic [AXIS_PCIE_KEEP_W-1:0]     m_axis_rq_tkeep_int;
logic                            m_axis_rq_tvalid_int;
logic                            m_axis_rq_tready_int_reg = 1'b0;
logic                            m_axis_rq_tlast_int;
logic [AXIS_PCIE_RQ_USER_W-1:0]  m_axis_rq_tuser_int;
wire                             m_axis_rq_tready_int_early;

logic [RAM_SEGS-1:0][RAM_SEL_W-1:0]       ram_wr_cmd_sel_int;
logic [RAM_SEGS-1:0][RAM_SEG_BE_W-1:0]    ram_wr_cmd_be_int;
logic [RAM_SEGS-1:0][RAM_SEG_ADDR_W-1:0]  ram_wr_cmd_addr_int;
logic [RAM_SEGS-1:0][RAM_SEG_DATA_W-1:0]  ram_wr_cmd_data_int;
logic [RAM_SEGS-1:0]                      ram_wr_cmd_valid_int;
wire  [RAM_SEGS-1:0]                      ram_wr_cmd_ready_int;

wire [RAM_SEGS-1:0] out_done;
logic [RAM_SEGS-1:0] out_done_ack;

assign s_axis_rc.tready = s_axis_rc_tready_reg;

assign rd_desc_req.req_ready = rd_desc_req_ready_reg;

assign rd_desc_sts.sts_tag = rd_desc_sts_tag_reg;
assign rd_desc_sts.sts_error = rd_desc_sts_error_reg;
assign rd_desc_sts.sts_valid = rd_desc_sts_valid_reg;

assign stat_busy = stat_busy_reg;
assign stat_err_cor = stat_err_cor_reg;
assign stat_err_uncor = stat_err_uncor_reg;

assign stat_rd_op_start_tag = stat_rd_op_start_tag_reg;
assign stat_rd_op_start_valid = stat_rd_op_start_valid_reg;
assign stat_rd_op_finish_tag = stat_rd_op_finish_tag_reg;
assign stat_rd_op_finish_status = stat_rd_op_finish_status_reg;
assign stat_rd_op_finish_valid = stat_rd_op_finish_valid_reg;
assign stat_rd_req_start_tag = stat_rd_req_start_tag_reg;
assign stat_rd_req_start_len = stat_rd_req_start_len_reg;
assign stat_rd_req_start_valid = stat_rd_req_start_valid_reg;
assign stat_rd_req_finish_tag = stat_rd_req_finish_tag_reg;
assign stat_rd_req_finish_status = stat_rd_req_finish_status_reg;
assign stat_rd_req_finish_valid = stat_rd_req_finish_valid_reg;
assign stat_rd_req_timeout = stat_rd_req_timeout_reg;
assign stat_rd_op_tbl_full = stat_rd_op_tbl_full_reg;
assign stat_rd_no_tags = stat_rd_no_tags_reg;
assign stat_rd_tx_limit = stat_rd_tx_limit_reg;
assign stat_rd_tx_stall = stat_rd_tx_stall_reg;

wire [1:0] axis_rq_seq_num_valid_int;
assign axis_rq_seq_num_valid_int[0] = s_axis_rq_seq_num_valid_0 && (s_axis_rq_seq_num_0 & SEQ_NUM_FLAG) == 0;
assign axis_rq_seq_num_valid_int[1] = s_axis_rq_seq_num_valid_1 && (s_axis_rq_seq_num_1 & SEQ_NUM_FLAG) == 0;

// PCIe tag management
logic [PCIE_TAG_W-1:0] pcie_tag_table_start_ptr_reg = '0, pcie_tag_table_start_ptr_next;
logic [RAM_SEL_W-1:0] pcie_tag_table_start_ram_sel_reg = '0, pcie_tag_table_start_ram_sel_next;
logic [RAM_ADDR_W-1:0] pcie_tag_table_start_ram_addr_reg = '0, pcie_tag_table_start_ram_addr_next;
logic [OP_TAG_W-1:0] pcie_tag_table_start_op_tag_reg = '0, pcie_tag_table_start_op_tag_next;
logic pcie_tag_table_start_zero_len_reg = 1'b0, pcie_tag_table_start_zero_len_next;
logic pcie_tag_table_start_en_reg = 1'b0, pcie_tag_table_start_en_next;
logic [PCIE_TAG_W-1:0] pcie_tag_table_finish_ptr;
logic pcie_tag_table_finish_en;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_SEL_W-1:0] pcie_tag_table_ram_sel[2**PCIE_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_ADDR_W-1:0] pcie_tag_table_ram_addr[2**PCIE_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [OP_TAG_W-1:0] pcie_tag_table_op_tag[2**PCIE_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic pcie_tag_table_zero_len[2**PCIE_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic pcie_tag_table_active_a[2**PCIE_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic pcie_tag_table_active_b[2**PCIE_TAG_W];

logic [PCIE_TAG_W-1:0] pcie_tag_fifo_wr_tag;

logic [PCIE_TAG_W_1+1-1:0] pcie_tag_fifo_1_wr_ptr_reg = '0;
logic [PCIE_TAG_W_1+1-1:0] pcie_tag_fifo_1_rd_ptr_reg = '0, pcie_tag_fifo_1_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [PCIE_TAG_W_1-1:0] pcie_tag_fifo_1_mem [2**PCIE_TAG_W_1];
logic pcie_tag_fifo_1_we;

logic [PCIE_TAG_W_2+1-1:0] pcie_tag_fifo_2_wr_ptr_reg = '0;
logic [PCIE_TAG_W_2+1-1:0] pcie_tag_fifo_2_rd_ptr_reg = '0, pcie_tag_fifo_2_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [PCIE_TAG_W-1:0] pcie_tag_fifo_2_mem [2**PCIE_TAG_W_2];
logic pcie_tag_fifo_2_we;

// operation tag management
logic [OP_TAG_W-1:0] op_tbl_start_ptr;
logic [TAG_W-1:0] op_tbl_start_tag;
logic op_tbl_start_en;
logic [OP_TAG_W-1:0] op_tbl_rd_start_ptr;
logic op_tbl_rd_start_commit;
logic op_tbl_rd_start_en;
logic [OP_TAG_W-1:0] op_tbl_update_status_ptr;
logic [3:0] op_tbl_update_status_err;
logic op_tbl_update_status_en;
logic [OP_TAG_W-1:0] op_tbl_rd_finish_ptr;
logic op_tbl_rd_finish_en;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [TAG_W-1:0] op_tbl_tag [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_rd_init_a [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_rd_init_b [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_rd_commit [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [OP_TBL_RD_COUNT_W-1:0] op_tbl_rd_count_start [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [OP_TBL_RD_COUNT_W-1:0] op_tbl_rd_count_finish [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_error_a [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_error_b [2**OP_TAG_W];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [3:0] op_tbl_error_code [2**OP_TAG_W];

logic [OP_TAG_W+1-1:0] op_tag_fifo_wr_ptr_reg = '0;
logic [OP_TAG_W+1-1:0] op_tag_fifo_rd_ptr_reg = '0, op_tag_fifo_rd_ptr_next;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [OP_TAG_W-1:0] op_tag_fifo_mem [2**OP_TAG_W];
logic [OP_TAG_W-1:0] op_tag_fifo_wr_tag;
logic op_tag_fifo_we;

initial begin
    for (integer i = 0; i < 2**OP_TAG_W; i = i + 1) begin
        op_tbl_tag[i] = '0;
        op_tbl_rd_init_a[i] = '0;
        op_tbl_rd_init_b[i] = '0;
        op_tbl_rd_commit[i] = '0;
        op_tbl_rd_count_start[i] = '0;
        op_tbl_rd_count_finish[i] = '0;
        op_tbl_error_a[i] = '0;
        op_tbl_error_b[i] = '0;
        op_tbl_error_code[i] = '0;
    end

    for (integer i = 0; i < 2**PCIE_TAG_W; i = i + 1) begin
        pcie_tag_table_ram_sel[i] = '0;
        pcie_tag_table_ram_addr[i] = '0;
        pcie_tag_table_op_tag[i] = '0;
        pcie_tag_table_zero_len[i] = '0;
        pcie_tag_table_active_a[i] = '0;
        pcie_tag_table_active_b[i] = '0;
    end
end

always_comb begin
    req_state_next = REQ_STATE_IDLE;

    rd_desc_req_ready_next = 1'b0;

    stat_rd_op_start_tag_next = stat_rd_op_start_tag_reg;
    stat_rd_op_start_valid_next = 1'b0;
    stat_rd_req_start_tag_next = stat_rd_req_start_tag_reg;
    stat_rd_req_start_len_next = stat_rd_req_start_len_reg;
    stat_rd_req_start_valid_next = 1'b0;
    stat_rd_op_tbl_full_next = op_tag_fifo_rd_ptr_reg == op_tag_fifo_wr_ptr_reg;
    stat_rd_no_tags_next = !req_pcie_tag_valid_reg;
    stat_rd_tx_limit_next = (RQ_SEQ_NUM_EN && !active_tx_count_av_reg) || !active_cplh_fc_av_reg || !active_cpld_fc_av_reg;
    stat_rd_tx_stall_next = m_axis_rq.tvalid && !m_axis_rq.tready;

    req_pcie_addr_next = req_pcie_addr_reg;
    req_ram_sel_next = req_ram_sel_reg;
    req_ram_addr_next = req_ram_addr_reg;
    req_op_count_next = req_op_count_reg;
    req_zero_len_next = req_zero_len_reg;
    req_op_tag_next = req_op_tag_reg;
    req_op_tag_valid_next = req_op_tag_valid_reg;
    req_pcie_tag_next = req_pcie_tag_reg;
    req_pcie_tag_valid_next = req_pcie_tag_valid_reg;

    inc_active_tx = 1'b0;
    inc_active_tag = 1'b0;
    inc_active_op = 1'b0;

    op_tbl_start_ptr = req_op_tag_reg;
    op_tbl_start_tag = rd_desc_req.req_tag;
    op_tbl_start_en = 1'b0;

    op_tbl_rd_start_ptr = req_op_tag_reg;
    op_tbl_rd_start_commit = 1'b0;
    op_tbl_rd_start_en = 1'b0;

    // TLP size computation
    if (req_op_count_reg + LEN_W'(req_pcie_addr_reg[1:0]) <= LEN_W'({max_rd_req_size_dw_reg, 2'b00})) begin
        // packet smaller than max read request size
        if ((12'(req_pcie_addr_reg & 12'hfff) + 12'(req_op_count_reg & 12'hfff)) >> 12 != 0 || req_op_count_reg >> 12 != 0) begin
            // crosses 4k boundary, split on 4K boundary
            req_tlp_count = 13'h1000 - req_pcie_addr_reg[11:0];
            req_dword_count = 11'h400 - req_pcie_addr_reg[11:2];
            req_cpld_fc_count = 9'h100 - req_pcie_addr_reg[11:4];
            if (rcb_128b_reg) begin
                req_cplh_fc_count = 7'h20 - 7'(req_pcie_addr_reg[11:7]);
            end else begin
                req_cplh_fc_count = 7'h40 - 7'(req_pcie_addr_reg[11:6]);
            end
            req_last_tlp = ((12'(req_pcie_addr_reg & 12'hfff) + 12'(req_op_count_reg & 12'hfff)) & 12'hfff) == 0 && req_op_count_reg >> 12 == 0;
            req_pcie_addr[PCIE_ADDR_W-1:12] = req_pcie_addr_reg[PCIE_ADDR_W-1:12]+1;
            req_pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, send one TLP
            req_tlp_count = 13'(req_op_count_reg);
            req_dword_count = 11'((13'(req_op_count_reg) + 13'(req_pcie_addr_reg[1:0]) + 13'd3) >> 2);
            req_cpld_fc_count = 9'((13'(req_op_count_reg) + 13'(req_pcie_addr_reg[1:0]) + 13'd15) >> 4);
            if (rcb_128b_reg) begin
                req_cplh_fc_count = 7'((13'(req_pcie_addr_reg[6:0])+13'(req_op_count_reg)+13'd127) >> 7);
            end else begin
                req_cplh_fc_count = 7'((13'(req_pcie_addr_reg[5:0])+13'(req_op_count_reg)+13'd63) >> 6);
            end
            req_last_tlp = 1'b1;
            // always last TLP, so next address is irrelevant
            req_pcie_addr[PCIE_ADDR_W-1:12] = req_pcie_addr_reg[PCIE_ADDR_W-1:12];
            req_pcie_addr[11:0] = 12'd0;
        end
    end else begin
        // packet larger than max read request size
        if ((12'(req_pcie_addr_reg & 12'hfff) + {max_rd_req_size_dw_reg, 2'b00}) >> 12 != 0) begin
            // crosses 4k boundary, split on 4K boundary
            req_tlp_count = 13'h1000 - req_pcie_addr_reg[11:0];
            req_dword_count = 11'h400 - req_pcie_addr_reg[11:2];
            req_cpld_fc_count = 9'h100 - req_pcie_addr_reg[11:4];
            if (rcb_128b_reg) begin
                req_cplh_fc_count = 7'h20 - 7'(req_pcie_addr_reg[11:7]);
            end else begin
                req_cplh_fc_count = 7'h40 - 7'(req_pcie_addr_reg[11:6]);
            end
            req_last_tlp = 1'b0;
            req_pcie_addr[PCIE_ADDR_W-1:12] = req_pcie_addr_reg[PCIE_ADDR_W-1:12]+1;
            req_pcie_addr[11:0] = 12'd0;
        end else begin
            // does not cross 4k boundary, split on 128-byte read completion boundary
            req_tlp_count = {max_rd_req_size_dw_reg, 2'b00} - 13'(req_pcie_addr_reg[6:0]);
            req_dword_count = max_rd_req_size_dw_reg - 11'(req_pcie_addr_reg[6:2]);
            req_cpld_fc_count = max_rd_req_size_dw_reg[10:2] - 9'(req_pcie_addr_reg[6:4]);
            if (rcb_128b_reg) begin
                req_cplh_fc_count = 7'(max_rd_req_size_dw_reg[10:5]);
            end else begin
                req_cplh_fc_count = 7'(max_rd_req_size_dw_reg[10:4] - 7'(req_pcie_addr_reg[6]));
            end
            req_last_tlp = 1'b0;
            req_pcie_addr[PCIE_ADDR_W-1:12] = req_pcie_addr_reg[PCIE_ADDR_W-1:12];
            req_pcie_addr[11:0] = 12'({{req_pcie_addr_reg[11:7], 5'd0} + max_rd_req_size_dw_reg, 2'b00});
        end
    end

    // un-optimized TLP size computations (for reference)
    // req_dword_count = (req_tlp_count + req_pcie_addr_reg[1:0] + 3) >> 2
    // req_cpld_fc_count = (req_dword_count + 3) >> 2
    // if (rcb_128b_reg) begin
    //     req_cplh_fc_count = (req_pcie_addr_reg[6:0]+req_tlp_count+127) >> 7
    // end lse begin
    //     req_cplh_fc_count = (req_pcie_addr_reg[5:0]+req_tlp_count+63) >> 6
    // end
    // req_pcie_addr = req_pcie_addr_reg + req_tlp_count

    pcie_tag_table_start_ptr_next = req_pcie_tag_reg;
    pcie_tag_table_start_ram_sel_next = req_ram_sel_reg;
    pcie_tag_table_start_ram_addr_next = req_ram_addr_reg + RAM_ADDR_W'(req_tlp_count);
    pcie_tag_table_start_op_tag_next = req_op_tag_reg;
    pcie_tag_table_start_zero_len_next = req_zero_len_reg;
    pcie_tag_table_start_en_next = 1'b0;

    req_first_be = 4'b1111 << req_pcie_addr_reg[1:0];
    req_last_be = 4'b1111 >> (3 - ((req_pcie_addr_reg[1:0] + req_tlp_count[1:0] - 1) & 3));

    // TLP header and sideband data
    tlp_header_data[1:0] = 2'b0; // address type
    tlp_header_data[63:2] = req_pcie_addr_reg[PCIE_ADDR_W-1:2]; // address
    tlp_header_data[74:64] = req_dword_count; // DWORD count
    tlp_header_data[78:75] = REQ_MEM_READ; // request type - memory read
    tlp_header_data[79] = 1'b0; // poisoned request
    tlp_header_data[95:80] = requester_id;
    tlp_header_data[103:96] = req_pcie_tag_reg;
    tlp_header_data[119:104] = 16'd0; // completer ID
    tlp_header_data[120] = requester_id_en;
    tlp_header_data[123:121] = 3'b000; // traffic class
    tlp_header_data[126:124] = 3'b000; // attr
    tlp_header_data[127] = 1'b0; // force ECRC

    // broken linter
    // verilator lint_off SELRANGE
    // verilator lint_off WIDTHEXPAND
    // verilator lint_off WIDTHTRUNC
    if (AXIS_PCIE_DATA_W == 512) begin
        tlp_tuser[3:0] = req_zero_len_reg ? 4'b0000 : (req_dword_count == 1 ? req_first_be & req_last_be : req_first_be); // first BE 0
        tlp_tuser[7:4] = 4'd0; // first BE 1
        tlp_tuser[11:8] = req_zero_len_reg ? 4'b0000 : (req_dword_count == 1 ? 4'b0000 : req_last_be); // last BE 0
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
        tlp_tuser[66:61] = 6'd0; // seq_num0
        tlp_tuser[72:67] = 6'd0; // seq_num1
        tlp_tuser[136:73] = 64'd0; // parity
    end else begin
        tlp_tuser[3:0] = req_zero_len_reg ? 4'b0000 : (req_dword_count == 1 ? req_first_be & req_last_be : req_first_be); // first BE
        tlp_tuser[7:4] = req_zero_len_reg ? 4'b0000 : (req_dword_count == 1 ? 4'b0000 : req_last_be); // last BE
        tlp_tuser[10:8] = 3'd0; // addr_offset
        tlp_tuser[11] = 1'b0; // discontinue
        tlp_tuser[12] = 1'b0; // tph_present
        tlp_tuser[14:13] = 2'b00; // tph_type
        tlp_tuser[15] = 1'b0; // tph_indirect_tag_en
        tlp_tuser[23:16] = 8'd0; // tph_st_tag
        tlp_tuser[27:24] = 4'd0; // seq_num
        tlp_tuser[59:28] = 32'd0; // parity
        if (AXIS_PCIE_RQ_USER_W == 62) begin
            tlp_tuser[61:60] = 2'd0; // seq_num
        end
    end
    // verilator lint_on SELRANGE
    // verilator lint_on WIDTHEXPAND
    // verilator lint_on WIDTHTRUNC

    // broken linter
    // verilator lint_off WIDTHEXPAND
    // verilator lint_off WIDTHTRUNC
    if (AXIS_PCIE_DATA_W == 512) begin
        m_axis_rq_tdata_int = tlp_header_data;
        m_axis_rq_tkeep_int = 16'b0000000000001111;
        m_axis_rq_tlast_int = 1'b1;
    end else if (AXIS_PCIE_DATA_W == 256) begin
        m_axis_rq_tdata_int = tlp_header_data;
        m_axis_rq_tkeep_int = 8'b00001111;
        m_axis_rq_tlast_int = 1'b1;
    end else if (AXIS_PCIE_DATA_W == 128) begin
        m_axis_rq_tdata_int = tlp_header_data;
        m_axis_rq_tkeep_int = 4'b1111;
        m_axis_rq_tlast_int = 1'b1;
    end else if (AXIS_PCIE_DATA_W == 64) begin
        m_axis_rq_tdata_int = tlp_header_data[63:0];
        m_axis_rq_tkeep_int = 2'b11;
        m_axis_rq_tlast_int = 1'b0;
    end
    // verilator lint_on WIDTHEXPAND
    // verilator lint_on WIDTHTRUNC
    m_axis_rq_tvalid_int = 1'b0;
    m_axis_rq_tuser_int = tlp_tuser;

    // TLP segmentation and request generation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            rd_desc_req_ready_next = init_done_reg && enable && req_op_tag_valid_reg;

            if (rd_desc_req.req_ready && rd_desc_req.req_valid) begin
                rd_desc_req_ready_next = 1'b0;
                req_ram_sel_next = rd_desc_req.req_dst_sel;
                req_pcie_addr_next = rd_desc_req.req_src_addr;
                req_ram_addr_next = rd_desc_req.req_dst_addr;
                if (rd_desc_req.req_len == 0) begin
                    // zero-length operation
                    req_op_count_next = 1;
                    req_zero_len_next = 1'b1;
                end else begin
                    req_op_count_next = rd_desc_req.req_len;
                    req_zero_len_next = 1'b0;
                end
                op_tbl_start_ptr = req_op_tag_reg;
                op_tbl_start_tag = rd_desc_req.req_tag;
                op_tbl_start_en = 1'b1;
                inc_active_op = 1'b1;
                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            if (m_axis_rq_tready_int_reg && req_pcie_tag_valid_reg && (!TX_FC_EN || have_credit_reg) && (!RQ_SEQ_NUM_EN || active_tx_count_av_reg) && active_cplh_fc_av_reg && active_cpld_fc_av_reg) begin
                m_axis_rq_tvalid_int = 1'b1;

                inc_active_tx = 1'b1;

                if (AXIS_PCIE_DATA_W > 64) begin
                    req_pcie_addr_next = req_pcie_addr;
                    req_ram_addr_next = req_ram_addr_reg + RAM_ADDR_W'(req_tlp_count);
                    req_op_count_next = req_op_count_reg - LEN_W'(req_tlp_count);

                    pcie_tag_table_start_ptr_next = req_pcie_tag_reg;
                    pcie_tag_table_start_ram_sel_next = req_ram_sel_reg;
                    pcie_tag_table_start_ram_addr_next = req_ram_addr_reg + RAM_ADDR_W'(req_tlp_count);
                    pcie_tag_table_start_op_tag_next = req_op_tag_reg;
                    pcie_tag_table_start_zero_len_next = req_zero_len_reg;
                    pcie_tag_table_start_en_next = 1'b1;
                    inc_active_tag = 1'b1;

                    op_tbl_rd_start_ptr = req_op_tag_reg;
                    op_tbl_rd_start_commit = req_last_tlp;
                    op_tbl_rd_start_en = 1'b1;

                    req_pcie_tag_valid_next = 1'b0;

                    if (!req_last_tlp) begin
                        req_state_next = REQ_STATE_START;
                    end else begin
                        req_op_tag_valid_next = 1'b0;
                        rd_desc_req_ready_next = init_done_reg && enable && (op_tag_fifo_rd_ptr_reg != op_tag_fifo_wr_ptr_reg);
                        req_state_next = REQ_STATE_IDLE;
                    end
                end else begin
                    req_state_next = REQ_STATE_HEADER;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
        REQ_STATE_HEADER: begin
            if (AXIS_PCIE_DATA_W == 64) begin
                // broken linter
                // verilator lint_off WIDTHEXPAND
                m_axis_rq_tdata_int = tlp_header_data[127:64];
                m_axis_rq_tkeep_int = 2'b11;
                // verilator lint_on WIDTHEXPAND
                m_axis_rq_tlast_int = 1'b1;

                if (m_axis_rq_tready_int_reg && req_pcie_tag_valid_reg) begin
                    req_pcie_addr_next = req_pcie_addr;
                    req_ram_addr_next = req_ram_addr_reg + RAM_ADDR_W'(req_tlp_count);
                    req_op_count_next = req_op_count_reg - LEN_W'(req_tlp_count);

                    m_axis_rq_tvalid_int = 1'b1;

                    pcie_tag_table_start_ptr_next = req_pcie_tag_reg;
                    pcie_tag_table_start_ram_sel_next = req_ram_sel_reg;
                    pcie_tag_table_start_ram_addr_next = req_ram_addr_reg + RAM_ADDR_W'(req_tlp_count);
                    pcie_tag_table_start_op_tag_next = req_op_tag_reg;
                    pcie_tag_table_start_zero_len_next = req_zero_len_reg;
                    pcie_tag_table_start_en_next = 1'b1;
                    inc_active_tag = 1'b1;

                    op_tbl_rd_start_ptr = req_op_tag_reg;
                    op_tbl_rd_start_commit = req_last_tlp;
                    op_tbl_rd_start_en = 1'b1;

                    req_pcie_tag_valid_next = 1'b0;

                    if (!req_last_tlp) begin
                        req_state_next = REQ_STATE_START;
                    end else begin
                        req_op_tag_valid_next = 1'b0;
                        rd_desc_req_ready_next = init_done_reg && enable && (op_tag_fifo_rd_ptr_reg != op_tag_fifo_wr_ptr_reg);
                        req_state_next = REQ_STATE_IDLE;
                    end
                end else begin
                    req_state_next = REQ_STATE_HEADER;
                end
            end
        end
        default: begin
            // invalid state
            req_state_next = REQ_STATE_IDLE;
        end
    endcase

    op_tag_fifo_rd_ptr_next = op_tag_fifo_rd_ptr_reg;

    if (!req_op_tag_valid_next) begin
        if (op_tag_fifo_rd_ptr_reg != op_tag_fifo_wr_ptr_reg) begin
            req_op_tag_next = op_tag_fifo_mem[op_tag_fifo_rd_ptr_reg[OP_TAG_W-1:0]];
            req_op_tag_valid_next = 1'b1;
            op_tag_fifo_rd_ptr_next = op_tag_fifo_rd_ptr_reg + 1;
        end
    end

    pcie_tag_fifo_1_rd_ptr_next = pcie_tag_fifo_1_rd_ptr_reg;
    pcie_tag_fifo_2_rd_ptr_next = pcie_tag_fifo_2_rd_ptr_reg;

    if (!req_pcie_tag_valid_next) begin
        if (pcie_tag_fifo_1_rd_ptr_reg != pcie_tag_fifo_1_wr_ptr_reg) begin
            req_pcie_tag_next = PCIE_TAG_W'(pcie_tag_fifo_1_mem[pcie_tag_fifo_1_rd_ptr_reg[PCIE_TAG_W_1-1:0]]);
            req_pcie_tag_valid_next = 1'b1;
            pcie_tag_fifo_1_rd_ptr_next = pcie_tag_fifo_1_rd_ptr_reg + 1;
        end else if (PCIE_TAG_CNT_2 > 0 && ext_tag_en && pcie_tag_fifo_2_rd_ptr_reg != pcie_tag_fifo_2_wr_ptr_reg) begin
            req_pcie_tag_next = pcie_tag_fifo_2_mem[pcie_tag_fifo_2_rd_ptr_reg[PCIE_TAG_W_2-1:0]];
            req_pcie_tag_valid_next = 1'b1;
            pcie_tag_fifo_2_rd_ptr_next = pcie_tag_fifo_2_rd_ptr_reg + 1;
        end
    end
end

always_comb begin
    tlp_state_next = TLP_STATE_IDLE;

    last_cycle = 1'b0;

    s_axis_rc_tready_next = 1'b0;

    lower_addr_next = lower_addr_reg;
    byte_count_next = byte_count_reg;
    error_code_next = error_code_reg;
    ram_sel_next = ram_sel_reg;
    addr_next = addr_reg;
    addr_delay_next = addr_delay_reg;
    op_count_next = op_count_reg;
    zero_len_next = zero_len_reg;
    ram_mask_next = ram_mask_reg;
    ram_mask_0_next = ram_mask_0_reg;
    ram_mask_1_next = ram_mask_1_reg;
    ram_wrap_next = ram_wrap_reg;
    cycle_byte_count_next = cycle_byte_count_reg;
    start_offset_next = start_offset_reg;
    end_offset_next = end_offset_reg;
    op_dword_count_next = op_dword_count_reg;
    cpl_status_next = cpl_status_reg;
    pcie_tag_next = pcie_tag_reg;
    op_tag_next = op_tag_reg;
    final_cpl_next = final_cpl_reg;
    finish_tag_next = 1'b0;
    offset_next = offset_reg;

    rc_tdata_int_next = s_axis_rc.tdata;
    rc_tvalid_int_next = 1'b0;

    status_fifo_mask_next = 1'b1;
    status_fifo_finish_next = 1'b0;
    status_fifo_error_next = DMA_ERR_NONE;
    status_fifo_wr_en_next = 1'b0;

    out_done_ack = '0;

    dec_active_tag = 1'b0;
    dec_active_op = 1'b0;

    // TODO cleanup
    // verilator lint_off WIDTHEXPAND

    // Write generation
    ram_wr_cmd_sel_int = {RAM_SEGS{ram_sel_reg}};
    if (!ram_wrap_reg) begin
        ram_wr_cmd_be_int = ({RAM_SEGS*RAM_SEG_BE_W{1'b1}} << start_offset_reg) & ({RAM_SEGS*RAM_SEG_BE_W{1'b1}} >> (RAM_SEGS*RAM_SEG_BE_W-1-end_offset_reg));
    end else begin
        ram_wr_cmd_be_int = ({RAM_SEGS*RAM_SEG_BE_W{1'b1}} << start_offset_reg) | ({RAM_SEGS*RAM_SEG_BE_W{1'b1}} >> (RAM_SEGS*RAM_SEG_BE_W-1-end_offset_reg));
    end
    for (integer i = 0; i < RAM_SEGS; i = i + 1) begin
        ram_wr_cmd_addr_int[i] = addr_delay_reg[RAM_ADDR_W-1:RAM_ADDR_W-RAM_SEG_ADDR_W];
        if (ram_mask_1_reg[i]) begin
            ram_wr_cmd_addr_int[i] = addr_delay_reg[RAM_ADDR_W-1:RAM_ADDR_W-RAM_SEG_ADDR_W]+1;
        end
    end
    ram_wr_cmd_data_int = RAM_DATA_W'({3{rc_tdata_int_reg}} >> (AXIS_PCIE_DATA_W - offset_reg*8));
    ram_wr_cmd_valid_int = '0;

    if (rc_tvalid_int_reg) begin
        ram_wr_cmd_valid_int = ram_mask_reg;
    end

    stat_err_cor_next = 1'b0;
    stat_err_uncor_next = 1'b0;

    // TLP response handling
    case (tlp_state_reg)
        TLP_STATE_IDLE: begin
            // idle state, wait for completion
            if (AXIS_PCIE_DATA_W > 64) begin
                s_axis_rc_tready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_full_reg;

                if (s_axis_rc.tready && s_axis_rc.tvalid) begin
                    // header fields

                    // broken linter
                    // verilator lint_off SELRANGE
                    lower_addr_next = s_axis_rc.tdata[11:0]; // lower address
                    error_code_next = s_axis_rc.tdata[15:12]; // error code
                    byte_count_next = s_axis_rc.tdata[28:16]; // byte count
                    //s_axis_rc.tdata[29]; // locked read
                    //s_axis_rc.tdata[30]; // request completed
                    op_dword_count_next = s_axis_rc.tdata[42:32]; // DWORD count
                    cpl_status_next = s_axis_rc.tdata[45:43]; // completion status
                    //s_axis_rc.tdata[46]; // poisoned completion
                    //s_axis_rc.tdata[63:48]; // requester ID
                    pcie_tag_next = PCIE_TAG_W'(s_axis_rc.tdata[71:64]); // tag
                    //s_axis_rc.tdata[87:72]; // completer ID
                    //s_axis_rc.tdata[91:89]; // tc
                    //s_axis_rc.tdata[94:92]; // attr

                    // tuser fields
                    //s_axis_rc.tuser[31:0]; // byte enables
                    //s_axis_rc.tuser[32]; // is_sof_0
                    //s_axis_rc.tuser[33]; // is_sof_1
                    //s_axis_rc.tuser[37:34]; // is_eof_0
                    //s_axis_rc.tuser[41:38]; // is_eof_1
                    //s_axis_rc.tuser[42]; // discontinue
                    //s_axis_rc.tuser[74:43]; // parity
                    // verilator lint_on SELRANGE

                    ram_sel_next = pcie_tag_table_ram_sel[pcie_tag_next];
                    addr_next = pcie_tag_table_ram_addr[pcie_tag_next] - RAM_ADDR_W'(byte_count_next);
                    zero_len_next = pcie_tag_table_zero_len[pcie_tag_next];

                    offset_next = addr_next[OFFSET_W-1:0] - (OFFSET_W'(12)+OFFSET_W'(lower_addr_next[1:0]));

                    if (byte_count_next > {op_dword_count_next, 2'b00} - 13'(lower_addr_next[1:0])) begin
                        // more completions to follow
                        op_count_next = {op_dword_count_next, 2'b00} - 13'(lower_addr_next[1:0]);
                        final_cpl_next = 1'b0;

                        // broken linter
                        // verilator lint_off CMPCONST
                        if (op_dword_count_next > 11'(AXIS_PCIE_DATA_W/32-3)) begin
                        // verilator lint_on CMPCONST
                            // more than one cycle
                            cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8-12)-(OFFSET_W+1)'(lower_addr_next[1:0]);
                            last_cycle = 1'b0;

                            start_offset_next = RAM_OFFSET_W'(addr_next);
                            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                        end else begin
                            // one cycle
                            cycle_byte_count_next = (OFFSET_W+1)'(op_count_next);
                            last_cycle = 1'b1;

                            start_offset_next = RAM_OFFSET_W'(addr_next);
                            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                        end
                    end else begin
                        // last completion
                        op_count_next = byte_count_next;
                        final_cpl_next = 1'b1;

                        if (op_count_next > 13'(AXIS_PCIE_DATA_W/8-12)-13'(lower_addr_next[1:0])) begin
                            // more than one cycle
                            cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8-12)-(OFFSET_W+1)'(lower_addr_next[1:0]);
                            last_cycle = 1'b0;

                            start_offset_next = RAM_OFFSET_W'(addr_next);
                            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                        end else begin
                            // one cycle
                            cycle_byte_count_next = (OFFSET_W+1)'(op_count_next);
                            last_cycle = 1'b1;

                            start_offset_next = RAM_OFFSET_W'(addr_next);
                            {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;
                        end
                    end

                    ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                    ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                    if (!ram_wrap_next) begin
                        ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                        ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                        ram_mask_1_next = 0;
                    end else begin
                        ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                    end

                    addr_delay_next = addr_next;
                    addr_next = addr_next + RAM_ADDR_W'(cycle_byte_count_next);
                    op_count_next = op_count_next - 13'(cycle_byte_count_next);

                    op_tag_next = pcie_tag_table_op_tag[pcie_tag_next];

                    if (pcie_tag_table_active_b[pcie_tag_next] == pcie_tag_table_active_a[pcie_tag_next]) begin
                        // tag not active, handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)

                        // drop TLP and report correctable error
                        stat_err_cor_next = 1'b1;
                        if (s_axis_rc.tlast) begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            s_axis_rc_tready_next = init_done_reg;
                            tlp_state_next = TLP_STATE_WAIT_END;
                        end
                    end else if (error_code_next == RC_ERR_MISMATCH) begin
                        // format/status mismatch, handle as malformed TLP (2.3.2)
                        // ATTR or TC mismatch, handle as malformed TLP (2.3.2)

                        // drop TLP and report uncorrectable error
                        stat_err_uncor_next = 1'b1;
                        if (s_axis_rc.tlast) begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            s_axis_rc_tready_next = init_done_reg;
                            tlp_state_next = TLP_STATE_WAIT_END;
                        end
                    end else if (error_code_next == RC_ERR_POISONED || error_code_next == RC_ERR_BAD_STATUS ||
                            error_code_next == RC_ERR_TIMEOUT || error_code_next == RC_ERR_FLR) begin
                        // transfer-terminating error

                        if (error_code_next == RC_ERR_POISONED) begin
                            // poisoned TLP, handle as advisory non-fatal (6.2.3.2.4.3)
                            // drop TLP and report correctable error
                            stat_err_cor_next = 1'b1;
                            status_fifo_error_next = DMA_ERR_PCIE_CPL_POISONED;
                        end else if (error_code_next == RC_ERR_BAD_STATUS) begin
                            // bad status, handle as advisory non-fatal (6.2.3.2.4.1)
                            // drop TLP and report correctable error
                            stat_err_cor_next = 1'b1;
                            if (cpl_status_next == CPL_STATUS_CA) begin
                                status_fifo_error_next = DMA_ERR_PCIE_CPL_STATUS_CA;
                            end else begin
                                status_fifo_error_next = DMA_ERR_PCIE_CPL_STATUS_UR;
                            end
                        end else if (error_code_next == RC_ERR_TIMEOUT) begin
                            // timeout, handle as uncorrectable (6.2.3.2.4.4)
                            // drop TLP and report uncorrectable error
                            stat_err_uncor_next = 1'b1;
                            status_fifo_error_next = DMA_ERR_TIMEOUT;
                        end else if (error_code_next == RC_ERR_FLR) begin
                            // FLR; not an actual completion so no error to report
                            // drop TLP
                            status_fifo_error_next = DMA_ERR_PCIE_FLR;
                        end

                        finish_tag_next = 1'b1;

                        status_fifo_mask_next = 1'b0;
                        status_fifo_finish_next = 1'b1;
                        status_fifo_wr_en_next = 1'b1;

                        if (s_axis_rc.tlast) begin
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            s_axis_rc_tready_next = init_done_reg;
                            tlp_state_next = TLP_STATE_WAIT_END;
                        end
                    end else begin
                        // no error

                        rc_tdata_int_next = s_axis_rc.tdata;
                        rc_tvalid_int_next = 1'b1;

                        status_fifo_mask_next = 1'b1;
                        status_fifo_finish_next = 1'b0;
                        status_fifo_error_next = DMA_ERR_NONE;
                        status_fifo_wr_en_next = 1'b1;

                        if (zero_len_next) begin
                            rc_tvalid_int_next = 1'b0;
                            status_fifo_mask_next = 1'b0;
                        end

                        if (last_cycle) begin
                            if (final_cpl_next) begin
                                // last completion in current read request (PCIe tag)

                                // release tag
                                finish_tag_next = 1'b1;
                                status_fifo_finish_next = 1'b1;
                            end
                            tlp_state_next = TLP_STATE_IDLE;
                        end else begin
                            tlp_state_next = TLP_STATE_WRITE;
                        end
                    end
                end else begin
                    tlp_state_next = TLP_STATE_IDLE;
                end
            end else begin
                s_axis_rc_tready_next = init_done_reg;

                if (s_axis_rc.tready && s_axis_rc.tvalid) begin
                    // header fields
                    lower_addr_next = s_axis_rc.tdata[11:0]; // lower address
                    error_code_next = s_axis_rc.tdata[15:12]; // error code
                    byte_count_next = s_axis_rc.tdata[28:16]; // byte count
                    //s_axis_rc.tdata[29]; // locked read
                    //s_axis_rc.tdata[30]; // request completed
                    op_dword_count_next = s_axis_rc.tdata[42:32]; // DWORD count
                    cpl_status_next = s_axis_rc.tdata[45:43]; // completion status
                    //s_axis_rc.tdata[46]; // poisoned completion
                    //s_axis_rc.tdata[63:48]; // requester ID

                    // tuser fields
                    //s_axis_rc.tuser[31:0]; // byte enables
                    //s_axis_rc.tuser[32]; // is_sof_0
                    //s_axis_rc.tuser[33]; // is_sof_1
                    //s_axis_rc.tuser[37:34]; // is_eof_0
                    //s_axis_rc.tuser[41:38]; // is_eof_1
                    //s_axis_rc.tuser[42]; // discontinue
                    //s_axis_rc.tuser[74:43]; // parity

                    if (byte_count_next > {op_dword_count_next, 2'b00} - 13'(lower_addr_next[1:0])) begin
                        // more completions to follow
                        op_count_next = {op_dword_count_next, 2'b00} - 13'(lower_addr_next[1:0]);
                        final_cpl_next = 1'b0;
                    end else begin
                        // last completion
                        op_count_next = byte_count_next;
                        final_cpl_next = 1'b1;
                    end

                    if (s_axis_rc.tlast) begin
                        s_axis_rc_tready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        s_axis_rc_tready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_full_reg;
                        tlp_state_next = TLP_STATE_HEADER;
                    end
                end else begin
                    s_axis_rc_tready_next = init_done_reg;
                    tlp_state_next = TLP_STATE_IDLE;
                end
            end
        end
        TLP_STATE_HEADER: begin
            // header state; process header (64 bit interface only)
            s_axis_rc_tready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_full_reg;

            if (s_axis_rc.tready && s_axis_rc.tvalid) begin
                pcie_tag_next = PCIE_TAG_W'(s_axis_rc.tdata[7:0]); // tag
                //s_axis_rc.tdata[23:8]; // completer ID
                //s_axis_rc.tdata[27:25]; // attr
                //s_axis_rc.tdata[30:28]; // tc

                ram_sel_next = pcie_tag_table_ram_sel[pcie_tag_next];
                addr_next = pcie_tag_table_ram_addr[pcie_tag_next] - RAM_ADDR_W'(byte_count_reg);
                zero_len_next = pcie_tag_table_zero_len[pcie_tag_next];

                offset_next = addr_next[OFFSET_W-1:0] - (4+lower_addr_reg[1:0]);

                if (op_count_next > 13'd4-13'(lower_addr_reg[1:0])) begin
                    // more than one cycle
                    cycle_byte_count_next = (OFFSET_W+1)'(4)-(OFFSET_W+1)'(lower_addr_reg[1:0]);
                    last_cycle = 1'b0;
                end else begin
                    // one cycle
                    cycle_byte_count_next = (OFFSET_W+1)'(op_count_next);
                    last_cycle = 1'b1;
                end
                start_offset_next = RAM_OFFSET_W'(addr_next);
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                if (!ram_wrap_next) begin
                    ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_1_next = 0;
                end else begin
                    ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                end

                addr_delay_next = addr_next;
                addr_next = addr_next + RAM_ADDR_W'(cycle_byte_count_next);
                op_count_next = op_count_next - 13'(cycle_byte_count_next);

                op_tag_next = pcie_tag_table_op_tag[pcie_tag_next];

                if (pcie_tag_table_active_b[pcie_tag_next] == pcie_tag_table_active_a[pcie_tag_next]) begin
                    // tag not active, handle as unexpected completion (2.3.2), advisory non-fatal (6.2.3.2.4.5)

                    // drop TLP and report correctable error
                    stat_err_cor_next = 1'b1;
                    if (s_axis_rc.tlast) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        s_axis_rc_tready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else if (error_code_next == RC_ERR_MISMATCH) begin
                    // format/status mismatch, handle as malformed TLP (2.3.2)
                    // ATTR or TC mismatch, handle as malformed TLP (2.3.2)

                    // drop TLP and report uncorrectable error
                    stat_err_uncor_next = 1'b1;
                    if (s_axis_rc.tlast) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        s_axis_rc_tready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else if (error_code_next == RC_ERR_POISONED || error_code_next == RC_ERR_BAD_STATUS ||
                        error_code_next == RC_ERR_TIMEOUT || error_code_next == RC_ERR_FLR) begin
                    // transfer-terminating error

                    if (error_code_next == RC_ERR_POISONED) begin
                        // poisoned TLP, handle as advisory non-fatal (6.2.3.2.4.3)
                        // drop TLP and report correctable error
                        stat_err_cor_next = 1'b1;
                        status_fifo_error_next = DMA_ERR_PCIE_CPL_POISONED;
                    end else if (error_code_next == RC_ERR_BAD_STATUS) begin
                        // bad status, handle as advisory non-fatal (6.2.3.2.4.1)
                        // drop TLP and report correctable error
                        stat_err_cor_next = 1'b1;
                        if (cpl_status_reg == CPL_STATUS_CA) begin
                            status_fifo_error_next = DMA_ERR_PCIE_CPL_STATUS_CA;
                        end else begin
                            status_fifo_error_next = DMA_ERR_PCIE_CPL_STATUS_UR;
                        end
                    end else if (error_code_next == RC_ERR_TIMEOUT) begin
                        // timeout, handle as uncorrectable (6.2.3.2.4.4)
                        // drop TLP and report uncorrectable error
                        stat_err_uncor_next = 1'b1;
                        status_fifo_error_next = DMA_ERR_TIMEOUT;
                    end else if (error_code_next == RC_ERR_FLR) begin
                        // FLR; not an actual completion so no error to report
                        // drop TLP
                        status_fifo_error_next = DMA_ERR_PCIE_FLR;
                    end

                    finish_tag_next = 1'b1;

                    status_fifo_mask_next = 1'b0;
                    status_fifo_finish_next = 1'b1;
                    status_fifo_wr_en_next = 1'b1;

                    if (s_axis_rc.tlast) begin
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        s_axis_rc_tready_next = init_done_reg;
                        tlp_state_next = TLP_STATE_WAIT_END;
                    end
                end else begin
                    // no error

                    if (zero_len_next) begin
                        status_fifo_mask_next = 1'b0;
                    end else begin
                        rc_tdata_int_next = s_axis_rc.tdata;
                        rc_tvalid_int_next = 1'b1;

                        status_fifo_mask_next = 1'b1;
                    end

                    status_fifo_finish_next = 1'b0;
                    status_fifo_error_next = DMA_ERR_NONE;
                    status_fifo_wr_en_next = 1'b1;

                    if (last_cycle) begin
                        if (final_cpl_next) begin
                            // last completion in current read request (PCIe tag)

                            // release tag
                            finish_tag_next = 1'b1;
                            status_fifo_finish_next = 1'b1;
                        end
                        tlp_state_next = TLP_STATE_IDLE;
                    end else begin
                        tlp_state_next = TLP_STATE_WRITE;
                    end
                end
            end else begin
                tlp_state_next = TLP_STATE_HEADER;
            end
        end
        TLP_STATE_WRITE: begin
            // write state - generate write operations
            s_axis_rc_tready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_full_reg;

            if (s_axis_rc.tready && s_axis_rc.tvalid) begin
                rc_tdata_int_next = s_axis_rc.tdata;
                rc_tvalid_int_next = 1'b1;

                if (op_count_next > 13'(AXIS_PCIE_DATA_W/8)) begin
                    // more cycles after this one
                    cycle_byte_count_next = (OFFSET_W+1)'(AXIS_PCIE_DATA_W/8);
                    last_cycle = 1'b0;
                end else begin
                    // last cycle
                    cycle_byte_count_next = (OFFSET_W+1)'(op_count_next);
                    last_cycle = 1'b1;
                end
                start_offset_next = RAM_OFFSET_W'(addr_next);
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                if (!ram_wrap_next) begin
                    ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_1_next = 0;
                end else begin
                    ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                end

                addr_delay_next = addr_reg;
                addr_next = addr_reg + RAM_ADDR_W'(cycle_byte_count_next);
                op_count_next = op_count_reg - 13'(cycle_byte_count_next);

                status_fifo_mask_next = 1'b1;
                status_fifo_finish_next = 1'b0;
                status_fifo_error_next = DMA_ERR_NONE;
                status_fifo_wr_en_next = 1'b1;

                if (last_cycle) begin
                    if (final_cpl_reg) begin
                        // last completion in current read request (PCIe tag)

                        // release tag
                        finish_tag_next = 1'b1;
                        status_fifo_finish_next = 1'b1;
                    end

                    if (AXIS_PCIE_DATA_W == 64) begin
                        s_axis_rc_tready_next = init_done_reg;
                    end
                    tlp_state_next = TLP_STATE_IDLE;
                end else begin
                    tlp_state_next = TLP_STATE_WRITE;
                end
            end else begin
                tlp_state_next = TLP_STATE_WRITE;
            end
        end
        TLP_STATE_WAIT_END: begin
            // wait end state, wait for end of TLP
            s_axis_rc_tready_next = init_done_reg;

            if (s_axis_rc.tready & s_axis_rc.tvalid) begin
                if (s_axis_rc.tlast) begin
                    if (AXIS_PCIE_DATA_W > 64) begin
                        s_axis_rc_tready_next = init_done_reg && &ram_wr_cmd_ready_int && !status_fifo_full_reg;
                    end else begin
                        s_axis_rc_tready_next = init_done_reg;
                    end
                    tlp_state_next = TLP_STATE_IDLE;
                end else begin
                    tlp_state_next = TLP_STATE_WAIT_END;
                end
            end else begin
                tlp_state_next = TLP_STATE_WAIT_END;
            end
        end
    endcase

    pcie_tag_table_finish_ptr = pcie_tag_reg;
    pcie_tag_table_finish_en = 1'b0;

    pcie_tag_fifo_wr_tag = pcie_tag_reg;
    pcie_tag_fifo_1_we = 1'b0;
    pcie_tag_fifo_2_we = 1'b0;

    if (init_pcie_tag_reg) begin
        // initialize FIFO
        pcie_tag_fifo_wr_tag = init_count_reg;
        if (pcie_tag_fifo_wr_tag < PCIE_TAG_CNT_1 || PCIE_TAG_CNT_2 == 0) begin
            pcie_tag_fifo_1_we = 1'b1;
        end else if (pcie_tag_fifo_wr_tag != 0) begin
            pcie_tag_fifo_2_we = 1'b1;
        end
    end else if (finish_tag_reg) begin
        pcie_tag_table_finish_ptr = pcie_tag_reg;
        pcie_tag_table_finish_en = 1'b1;
        dec_active_tag = 1'b1;

        pcie_tag_fifo_wr_tag = pcie_tag_reg;
        if (pcie_tag_fifo_wr_tag < PCIE_TAG_CNT_1 || PCIE_TAG_CNT_2 == 0) begin
            pcie_tag_fifo_1_we = 1'b1;
        end else begin
            pcie_tag_fifo_2_we = 1'b1;
        end
    end

    status_fifo_wr_op_tag = op_tag_reg;
    status_fifo_wr_mask = status_fifo_mask_reg ? ram_mask_reg : 0;
    status_fifo_wr_finish = status_fifo_finish_reg;
    status_fifo_wr_error = status_fifo_error_reg;
    status_fifo_wr_en = status_fifo_wr_en_reg;

    status_fifo_rd_valid_next = status_fifo_rd_valid_reg;
    status_fifo_rd_en = 1'b0;

    rd_desc_sts_tag_next = op_tbl_tag[status_fifo_rd_op_tag_reg];
    if (status_fifo_rd_error_reg != DMA_ERR_NONE) begin
        rd_desc_sts_error_next = status_fifo_rd_error_reg;
    end else if (op_tbl_error_a[status_fifo_rd_op_tag_reg] != op_tbl_error_b[status_fifo_rd_op_tag_reg]) begin
        rd_desc_sts_error_next = op_tbl_error_code[status_fifo_rd_op_tag_reg];
    end else begin
        rd_desc_sts_error_next = DMA_ERR_NONE;
    end
    rd_desc_sts_valid_next = 1'b0;

    op_tbl_update_status_ptr = status_fifo_rd_op_tag_reg;
    if (status_fifo_rd_error_reg != DMA_ERR_NONE) begin
        op_tbl_update_status_err = status_fifo_rd_error_reg;
    end else begin
        op_tbl_update_status_err = DMA_ERR_NONE;
    end
    op_tbl_update_status_en = 1'b0;

    op_tbl_rd_finish_ptr = status_fifo_rd_op_tag_reg;
    op_tbl_rd_finish_en = 1'b0;

    op_tag_fifo_wr_tag = status_fifo_rd_op_tag_reg;
    op_tag_fifo_we = 1'b0;

    if (init_op_tag_reg) begin
        // initialize FIFO
        op_tag_fifo_wr_tag = init_count_reg;
        op_tag_fifo_we = 1'b1;
    end else if (status_fifo_rd_valid_reg && (status_fifo_rd_mask_reg & ~out_done) == 0) begin
        // got write completion, pop and return status
        status_fifo_rd_valid_next = 1'b0;
        op_tbl_update_status_en = 1'b1;

        out_done_ack = status_fifo_rd_mask_reg;

        if (status_fifo_rd_finish_reg) begin
            // mark done
            op_tbl_rd_finish_en = 1'b1;

            if (op_tbl_rd_commit[op_tbl_rd_finish_ptr] && (op_tbl_rd_count_start[op_tbl_rd_finish_ptr] == op_tbl_rd_count_finish[op_tbl_rd_finish_ptr])) begin
                op_tag_fifo_we = 1'b1;
                dec_active_op = 1'b1;
                rd_desc_sts_valid_next = 1'b1;
            end
        end
    end

    if (!status_fifo_rd_valid_next && status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        status_fifo_rd_en = 1'b1;
        status_fifo_rd_valid_next = 1'b1;
    end
end

logic [1:0] active_tx_count_ovf;

always_comb begin
    {active_tx_count_ovf, active_tx_count_next} = $signed({1'b0, active_tx_count_reg}) + $signed({1'b0, inc_active_tx});

    for (integer i = 0; i < 2; i = i + 1) begin
        {active_tx_count_ovf, active_tx_count_next} = $signed({active_tx_count_ovf, active_tx_count_next}) - $signed({1'b0, axis_rq_seq_num_valid_int[i]});
    end

    // saturate
    if (active_tx_count_ovf[1]) begin
        // sign bit set indicating underflow across zero; saturate to zero
        active_tx_count_next = '0;
    end else if (active_tx_count_ovf[0]) begin
        // sign bit clear but carry bit set indicating overflow; saturate to all 1
        active_tx_count_next = '1;
    end

    active_tx_count_av_next = active_tx_count_next < TX_LIMIT;

    active_cplh_fc_count_next = active_cplh_fc_count_reg + inc_active_cplh_fc_count - dec_active_cplh_fc_count;
    active_cplh_fc_av_next = CPLH_FC_LIMIT == 0 || active_cplh_fc_count_next < CPLH_FC_LIMIT;

    active_cpld_fc_count_next = active_cpld_fc_count_reg + inc_active_cpld_fc_count - dec_active_cpld_fc_count;
    active_cpld_fc_av_next = CPLD_FC_LIMIT == 0 || active_cpld_fc_count_next < CPLD_FC_LIMIT;
end

always_ff @(posedge clk) begin
    req_state_reg <= req_state_next;
    tlp_state_reg <= tlp_state_next;

    if (!init_done_reg) begin
        {init_done_reg, init_count_reg} <= init_count_reg + 1;
        init_pcie_tag_reg <= init_count_reg + 1 < 2**PCIE_TAG_W;
        init_op_tag_reg <= init_count_reg + 1 < 2**OP_TAG_W;
    end

    req_pcie_addr_reg <= req_pcie_addr_next;
    req_ram_sel_reg <= req_ram_sel_next;
    req_ram_addr_reg <= req_ram_addr_next;
    req_op_count_reg <= req_op_count_next;
    req_zero_len_reg <= req_zero_len_next;
    req_op_tag_reg <= req_op_tag_next;
    req_op_tag_valid_reg <= req_op_tag_valid_next;
    req_pcie_tag_reg <= req_pcie_tag_next;
    req_pcie_tag_valid_reg <= req_pcie_tag_valid_next;

    lower_addr_reg <= lower_addr_next;
    byte_count_reg <= byte_count_next;
    error_code_reg <= error_code_next;
    ram_sel_reg <= ram_sel_next;
    addr_reg <= addr_next;
    addr_delay_reg <= addr_delay_next;
    op_count_reg <= op_count_next;
    zero_len_reg <= zero_len_next;
    ram_mask_reg <= ram_mask_next;
    ram_mask_0_reg <= ram_mask_0_next;
    ram_mask_1_reg <= ram_mask_1_next;
    ram_wrap_reg <= ram_wrap_next;
    cycle_byte_count_reg <= cycle_byte_count_next;
    start_offset_reg <= start_offset_next;
    end_offset_reg <= end_offset_next;
    op_dword_count_reg <= op_dword_count_next;
    cpl_status_reg <= cpl_status_next;
    pcie_tag_reg <= pcie_tag_next;
    op_tag_reg <= op_tag_next;
    final_cpl_reg <= final_cpl_next;
    finish_tag_reg <= finish_tag_next;

    offset_reg <= offset_next;

    rc_tdata_int_reg <= rc_tdata_int_next;
    rc_tvalid_int_reg <= rc_tvalid_int_next;

    s_axis_rc_tready_reg <= s_axis_rc_tready_next;
    rd_desc_req_ready_reg <= rd_desc_req_ready_next;

    rd_desc_sts_tag_reg <= rd_desc_sts_tag_next;
    rd_desc_sts_error_reg <= rd_desc_sts_error_next;
    rd_desc_sts_valid_reg <= rd_desc_sts_valid_next;

    stat_busy_reg <= active_op_count_reg != 0 || active_tx_count_reg != 0;
    stat_err_cor_reg <= stat_err_cor_next;
    stat_err_uncor_reg <= stat_err_uncor_next;

    stat_rd_op_start_tag_reg <= stat_rd_op_start_tag_next;
    stat_rd_op_start_valid_reg <= stat_rd_op_start_valid_next;
    stat_rd_op_finish_tag_reg <= stat_rd_op_finish_tag_next;
    stat_rd_op_finish_status_reg <= stat_rd_op_finish_status_next;
    stat_rd_op_finish_valid_reg <= stat_rd_op_finish_valid_next;
    stat_rd_req_start_tag_reg <= stat_rd_req_start_tag_next;
    stat_rd_req_start_len_reg <= stat_rd_req_start_len_next;
    stat_rd_req_start_valid_reg <= stat_rd_req_start_valid_next;
    stat_rd_req_finish_tag_reg <= stat_rd_req_finish_tag_next;
    stat_rd_req_finish_status_reg <= stat_rd_req_finish_status_next;
    stat_rd_req_finish_valid_reg <= stat_rd_req_finish_valid_next;
    stat_rd_req_timeout_reg <= stat_rd_req_timeout_next;
    stat_rd_op_tbl_full_reg <= stat_rd_op_tbl_full_next;
    stat_rd_no_tags_reg <= stat_rd_no_tags_next;
    stat_rd_tx_limit_reg <= stat_rd_tx_limit_next;
    stat_rd_tx_stall_reg <= stat_rd_tx_stall_next;

    max_rd_req_size_dw_reg <= 11'd32 << (max_rd_req_size > 5 ? 5 : max_rd_req_size);
    rcb_128b_reg <= rcb_128b;

    have_credit_reg <= pcie_tx_fc_nph_av > 4;

    if (status_fifo_wr_en) begin
        status_fifo_op_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_op_tag;
        status_fifo_mask[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_mask;
        status_fifo_finish[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_finish;
        status_fifo_error[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_error;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end

    if (status_fifo_rd_en) begin
        status_fifo_rd_op_tag_reg <= status_fifo_op_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_mask_reg <= status_fifo_mask[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_finish_reg <= status_fifo_finish[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_error_reg <= status_fifo_error[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_reg + 1;
    end

    status_fifo_mask_reg <= status_fifo_mask_next;
    status_fifo_finish_reg <= status_fifo_finish_next;
    status_fifo_error_reg <= status_fifo_error_next;
    status_fifo_wr_en_reg <= status_fifo_wr_en_next;

    status_fifo_rd_valid_reg <= status_fifo_rd_valid_next;

    status_fifo_full_reg <= $unsigned(status_fifo_wr_ptr_reg - status_fifo_rd_ptr_reg) >= 2**STATUS_FIFO_AW-4;

    active_tx_count_reg <= active_tx_count_next;
    active_tx_count_av_reg <= active_tx_count_av_next;

    active_tag_count_reg <= active_tag_count_reg + PCIE_TAG_W'(inc_active_tag) - PCIE_TAG_W'(dec_active_tag);
    active_op_count_reg <= active_op_count_reg + OP_TAG_W'(inc_active_op) - OP_TAG_W'(dec_active_op);

    active_cplh_fc_count_reg <= active_cplh_fc_count_next;
    active_cplh_fc_av_reg <= active_cplh_fc_av_next;

    active_cpld_fc_count_reg <= active_cpld_fc_count_next;
    active_cpld_fc_av_reg <= active_cpld_fc_av_next;

    pcie_tag_table_start_ptr_reg <= pcie_tag_table_start_ptr_next;
    pcie_tag_table_start_ram_sel_reg <= pcie_tag_table_start_ram_sel_next;
    pcie_tag_table_start_ram_addr_reg <= pcie_tag_table_start_ram_addr_next;
    pcie_tag_table_start_op_tag_reg <= pcie_tag_table_start_op_tag_next;
    pcie_tag_table_start_zero_len_reg <= pcie_tag_table_start_zero_len_next;
    pcie_tag_table_start_en_reg <= pcie_tag_table_start_en_next;

    if (init_pcie_tag_reg) begin
        pcie_tag_table_active_a[init_count_reg] <= 1'b0;
    end else if (pcie_tag_table_start_en_reg) begin
        pcie_tag_table_ram_sel[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_ram_sel_reg;
        pcie_tag_table_ram_addr[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_ram_addr_reg;
        pcie_tag_table_op_tag[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_op_tag_reg;
        pcie_tag_table_zero_len[pcie_tag_table_start_ptr_reg] <= pcie_tag_table_start_zero_len_reg;
        pcie_tag_table_active_a[pcie_tag_table_start_ptr_reg] <= !pcie_tag_table_active_b[pcie_tag_table_start_ptr_reg];
    end

    if (init_pcie_tag_reg) begin
        pcie_tag_table_active_b[init_count_reg] <= 1'b0;
    end else if (pcie_tag_table_finish_en) begin
        pcie_tag_table_active_b[pcie_tag_table_finish_ptr] <= pcie_tag_table_active_a[pcie_tag_table_finish_ptr];
    end

    if (pcie_tag_fifo_1_we) begin
        pcie_tag_fifo_1_mem[pcie_tag_fifo_1_wr_ptr_reg[PCIE_TAG_W_1-1:0]] <= PCIE_TAG_W_1'(pcie_tag_fifo_wr_tag);
        pcie_tag_fifo_1_wr_ptr_reg <= pcie_tag_fifo_1_wr_ptr_reg + 1;
    end
    pcie_tag_fifo_1_rd_ptr_reg <= pcie_tag_fifo_1_rd_ptr_next;
    if (PCIE_TAG_CNT_2 != 0) begin
        if (pcie_tag_fifo_2_we) begin
            pcie_tag_fifo_2_mem[pcie_tag_fifo_2_wr_ptr_reg[PCIE_TAG_W_2-1:0]] <= pcie_tag_fifo_wr_tag;
            pcie_tag_fifo_2_wr_ptr_reg <= pcie_tag_fifo_2_wr_ptr_reg + 1;
        end
        pcie_tag_fifo_2_rd_ptr_reg <= pcie_tag_fifo_2_rd_ptr_next;
    end

    if (init_op_tag_reg) begin
        op_tbl_rd_init_a[init_count_reg] <= 1'b0;
        op_tbl_error_a[init_count_reg] <= 1'b0;
    end else if (op_tbl_start_en) begin
        op_tbl_tag[op_tbl_start_ptr] <= op_tbl_start_tag;
        op_tbl_rd_init_a[op_tbl_start_ptr] <= !op_tbl_rd_init_b[op_tbl_start_ptr];
        op_tbl_error_a[op_tbl_start_ptr] <= op_tbl_error_b[op_tbl_start_ptr];
    end

    if (init_op_tag_reg) begin
        op_tbl_rd_init_b[init_count_reg] <= 1'b0;
        op_tbl_rd_count_start[init_count_reg] <= 0;
    end else if (op_tbl_rd_start_en) begin
        op_tbl_rd_init_b[op_tbl_rd_start_ptr] <= op_tbl_rd_init_a[op_tbl_rd_start_ptr];
        op_tbl_rd_commit[op_tbl_rd_start_ptr] <= op_tbl_rd_start_commit;
        if (op_tbl_rd_init_b[op_tbl_rd_start_ptr] != op_tbl_rd_init_a[op_tbl_rd_start_ptr]) begin
            op_tbl_rd_count_start[op_tbl_rd_start_ptr] <= op_tbl_rd_count_finish[op_tbl_rd_start_ptr];
        end else begin
            op_tbl_rd_count_start[op_tbl_rd_start_ptr] <= op_tbl_rd_count_start[op_tbl_rd_start_ptr] + 1;
        end
    end

    if (init_op_tag_reg) begin
        op_tbl_error_b[init_count_reg] <= 1'b0;
    end else if (op_tbl_update_status_en) begin
        if (op_tbl_update_status_err != 0) begin
            op_tbl_error_code[op_tbl_update_status_ptr] <= op_tbl_update_status_err;
            op_tbl_error_b[op_tbl_update_status_ptr] <= !op_tbl_error_a[op_tbl_update_status_ptr];
        end
    end

    if (init_op_tag_reg) begin
        op_tbl_rd_count_finish[init_count_reg] <= 0;
    end else if (op_tbl_rd_finish_en) begin
        op_tbl_rd_count_finish[op_tbl_rd_finish_ptr] <= op_tbl_rd_count_finish[op_tbl_rd_finish_ptr] + 1;
    end

    if (op_tag_fifo_we) begin
        op_tag_fifo_mem[op_tag_fifo_wr_ptr_reg[OP_TAG_W-1:0]] <= op_tag_fifo_wr_tag;
        op_tag_fifo_wr_ptr_reg <= op_tag_fifo_wr_ptr_reg + 1;
    end
    op_tag_fifo_rd_ptr_reg <= op_tag_fifo_rd_ptr_next;

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        tlp_state_reg <= TLP_STATE_IDLE;

        init_count_reg <= '0;
        init_done_reg <= 1'b0;
        init_pcie_tag_reg <= 1'b1;
        init_op_tag_reg <= 1'b1;

        req_op_tag_valid_reg <= 1'b0;
        req_pcie_tag_valid_reg <= 1'b0;

        finish_tag_reg <= 1'b0;

        rc_tvalid_int_reg <= 1'b0;

        s_axis_rc_tready_reg <= 1'b0;

        rd_desc_req_ready_reg <= 1'b0;
        rd_desc_sts_valid_reg <= 1'b0;

        stat_busy_reg <= 1'b0;
        stat_err_cor_reg <= 1'b0;
        stat_err_uncor_reg <= 1'b0;

        stat_rd_op_start_valid_reg <= 1'b0;
        stat_rd_op_finish_valid_reg <= 1'b0;
        stat_rd_req_start_valid_reg <= 1'b0;
        stat_rd_req_finish_valid_reg <= 1'b0;
        stat_rd_req_timeout_reg <= 1'b0;
        stat_rd_op_tbl_full_reg <= 1'b0;
        stat_rd_no_tags_reg <= 1'b0;
        stat_rd_tx_limit_reg <= 1'b0;
        stat_rd_tx_stall_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= '0;
        status_fifo_rd_ptr_reg <= '0;
        status_fifo_wr_en_reg <= 1'b0;
        status_fifo_rd_valid_reg <= 1'b0;

        active_tx_count_reg <= '0;
        active_tx_count_av_reg <= 1'b1;

        active_tag_count_reg <= '0;
        active_op_count_reg <= '0;

        active_cplh_fc_count_reg <= '0;
        active_cplh_fc_av_reg <= 1'b1;

        active_cpld_fc_count_reg <= '0;
        active_cpld_fc_av_reg <= 1'b1;

        pcie_tag_table_start_en_reg <= 1'b0;

        pcie_tag_fifo_1_wr_ptr_reg <= '0;
        pcie_tag_fifo_1_rd_ptr_reg <= '0;
        pcie_tag_fifo_2_wr_ptr_reg <= '0;
        pcie_tag_fifo_2_rd_ptr_reg <= '0;

        op_tag_fifo_wr_ptr_reg <= '0;
        op_tag_fifo_rd_ptr_reg <= '0;
    end
end

// output datapath logic (PCIe TLP)
logic [AXIS_PCIE_DATA_W-1:0]    m_axis_rq_tdata_reg = '0;
logic [AXIS_PCIE_KEEP_W-1:0]    m_axis_rq_tkeep_reg = '0;
logic                           m_axis_rq_tvalid_reg = 1'b0, m_axis_rq_tvalid_next;
logic                           m_axis_rq_tlast_reg = 1'b0;
logic [AXIS_PCIE_RQ_USER_W-1:0] m_axis_rq_tuser_reg = '0;

logic [AXIS_PCIE_DATA_W-1:0]    temp_m_axis_rq_tdata_reg = '0;
logic [AXIS_PCIE_KEEP_W-1:0]    temp_m_axis_rq_tkeep_reg = '0;
logic                           temp_m_axis_rq_tvalid_reg = 1'b0, temp_m_axis_rq_tvalid_next;
logic                           temp_m_axis_rq_tlast_reg = 1'b0;
logic [AXIS_PCIE_RQ_USER_W-1:0] temp_m_axis_rq_tuser_reg = '0;

// datapath control
logic store_axis_rq_int_to_output;
logic store_axis_rq_int_to_temp;
logic store_axis_rq_temp_to_output;

assign m_axis_rq.tdata = m_axis_rq_tdata_reg;
assign m_axis_rq.tkeep = m_axis_rq_tkeep_reg;
assign m_axis_rq.tvalid = m_axis_rq_tvalid_reg;
assign m_axis_rq.tlast = m_axis_rq_tlast_reg;
assign m_axis_rq.tuser = m_axis_rq_tuser_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_rq_tready_int_early = m_axis_rq.tready || (!temp_m_axis_rq_tvalid_reg && (!m_axis_rq_tvalid_reg || !m_axis_rq_tvalid_int));

always_comb begin
    // transfer sink ready state to source
    m_axis_rq_tvalid_next = m_axis_rq_tvalid_reg;
    temp_m_axis_rq_tvalid_next = temp_m_axis_rq_tvalid_reg;

    store_axis_rq_int_to_output = 1'b0;
    store_axis_rq_int_to_temp = 1'b0;
    store_axis_rq_temp_to_output = 1'b0;

    if (m_axis_rq_tready_int_reg) begin
        // input is ready
        if (m_axis_rq.tready || !m_axis_rq_tvalid_reg) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_rq_tvalid_next = m_axis_rq_tvalid_int;
            store_axis_rq_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_rq_tvalid_next = m_axis_rq_tvalid_int;
            store_axis_rq_int_to_temp = 1'b1;
        end
    end else if (m_axis_rq.tready) begin
        // input is not ready, but output is ready
        m_axis_rq_tvalid_next = temp_m_axis_rq_tvalid_reg;
        temp_m_axis_rq_tvalid_next = 1'b0;
        store_axis_rq_temp_to_output = 1'b1;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        m_axis_rq_tvalid_reg <= 1'b0;
        m_axis_rq_tready_int_reg <= 1'b0;
        temp_m_axis_rq_tvalid_reg <= 1'b0;
    end else begin
        m_axis_rq_tvalid_reg <= m_axis_rq_tvalid_next;
        m_axis_rq_tready_int_reg <= m_axis_rq_tready_int_early;
        temp_m_axis_rq_tvalid_reg <= temp_m_axis_rq_tvalid_next;
    end

    // datapath
    if (store_axis_rq_int_to_output) begin
        m_axis_rq_tdata_reg <= m_axis_rq_tdata_int;
        m_axis_rq_tkeep_reg <= m_axis_rq_tkeep_int;
        m_axis_rq_tlast_reg <= m_axis_rq_tlast_int;
        m_axis_rq_tuser_reg <= m_axis_rq_tuser_int;
    end else if (store_axis_rq_temp_to_output) begin
        m_axis_rq_tdata_reg <= temp_m_axis_rq_tdata_reg;
        m_axis_rq_tkeep_reg <= temp_m_axis_rq_tkeep_reg;
        m_axis_rq_tlast_reg <= temp_m_axis_rq_tlast_reg;
        m_axis_rq_tuser_reg <= temp_m_axis_rq_tuser_reg;
    end

    if (store_axis_rq_int_to_temp) begin
        temp_m_axis_rq_tdata_reg <= m_axis_rq_tdata_int;
        temp_m_axis_rq_tkeep_reg <= m_axis_rq_tkeep_int;
        temp_m_axis_rq_tlast_reg <= m_axis_rq_tlast_int;
        temp_m_axis_rq_tuser_reg <= m_axis_rq_tuser_int;
    end
end

// output datapath logic (write data)
for (genvar n = 0; n < RAM_SEGS; n = n + 1) begin

    logic [RAM_SEL_W-1:0]  ram_wr_cmd_sel_reg = '0;
    logic [RAM_SEG_BE_W-1:0]   ram_wr_cmd_be_reg = '0;
    logic [RAM_SEG_ADDR_W-1:0] ram_wr_cmd_addr_reg = '0;
    logic [RAM_SEG_DATA_W-1:0] ram_wr_cmd_data_reg = '0;
    logic                  ram_wr_cmd_valid_reg = 1'b0;

    logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_wr_ptr_reg = '0;
    logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_rd_ptr_reg = '0;
    logic out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_AW{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed" *)
    logic [RAM_SEL_W-1:0]  out_fifo_wr_cmd_sel[2**OUTPUT_FIFO_AW];
    (* ram_style = "distributed" *)
    logic [RAM_SEG_BE_W-1:0]   out_fifo_wr_cmd_be[2**OUTPUT_FIFO_AW];
    (* ram_style = "distributed" *)
    logic [RAM_SEG_ADDR_W-1:0] out_fifo_wr_cmd_addr[2**OUTPUT_FIFO_AW];
    (* ram_style = "distributed" *)
    logic [RAM_SEG_DATA_W-1:0] out_fifo_wr_cmd_data[2**OUTPUT_FIFO_AW];

    logic [OUTPUT_FIFO_AW+1-1:0] done_count_reg = '0;
    logic done_reg = 1'b0;

    assign ram_wr_cmd_ready_int[n +: 1] = !out_fifo_half_full_reg;

    assign dma_ram_wr.wr_cmd_sel[n] = ram_wr_cmd_sel_reg;
    assign dma_ram_wr.wr_cmd_be[n] = ram_wr_cmd_be_reg;
    assign dma_ram_wr.wr_cmd_addr[n] = ram_wr_cmd_addr_reg;
    assign dma_ram_wr.wr_cmd_data[n] = ram_wr_cmd_data_reg;
    assign dma_ram_wr.wr_cmd_valid[n] = ram_wr_cmd_valid_reg;

    assign out_done[n] = done_reg;

    always_ff @(posedge clk) begin
        ram_wr_cmd_valid_reg <= ram_wr_cmd_valid_reg && !dma_ram_wr.wr_cmd_ready[n +: 1];

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_AW-1);

        if (!out_fifo_full && ram_wr_cmd_valid_int[n +: 1]) begin
            out_fifo_wr_cmd_sel[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_sel_int[n];
            out_fifo_wr_cmd_be[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_be_int[n];
            out_fifo_wr_cmd_addr[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_addr_int[n];
            out_fifo_wr_cmd_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_data_int[n];
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!ram_wr_cmd_valid_reg || dma_ram_wr.wr_cmd_ready[n +: 1])) begin
            ram_wr_cmd_sel_reg <= out_fifo_wr_cmd_sel[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
            ram_wr_cmd_be_reg <= out_fifo_wr_cmd_be[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
            ram_wr_cmd_addr_reg <= out_fifo_wr_cmd_addr[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
            ram_wr_cmd_data_reg <= out_fifo_wr_cmd_data[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
            ram_wr_cmd_valid_reg <= 1'b1;
            out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
        end

        if (done_count_reg < 2**OUTPUT_FIFO_AW && dma_ram_wr.wr_done[n] && !out_done_ack[n]) begin
            done_count_reg <= done_count_reg + 1;
            done_reg <= 1;
        end else if (done_count_reg > 0 && !dma_ram_wr.wr_done[n] && out_done_ack[n]) begin
            done_count_reg <= done_count_reg - 1;
            done_reg <= done_count_reg > 1;
        end

        if (rst) begin
            out_fifo_wr_ptr_reg <= '0;
            out_fifo_rd_ptr_reg <= '0;
            ram_wr_cmd_valid_reg <= 1'b0;
            done_count_reg <= '0;
            done_reg <= 1'b0;
        end
    end

end

endmodule

`resetall
