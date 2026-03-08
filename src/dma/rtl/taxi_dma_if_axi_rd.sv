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
 * AXI DMA read interface
 */
module taxi_dma_if_axi_rd #
(
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 256,
    // Operation table size
    parameter OP_TBL_SIZE = 32,
    // Use AXI ID signals
    parameter logic USE_AXI_ID = 1'b0
)
(
    input  wire logic                            clk,
    input  wire logic                            rst,

    /*
     * AXI master interface
     */
    taxi_axi_if.rd_mst                           m_axi_rd,

    /*
     * Read descriptor
     */
    taxi_dma_desc_if.req_snk                     rd_desc_req,
    taxi_dma_desc_if.sts_src                     rd_desc_sts,

    /*
     * RAM interface
     */
    taxi_dma_ram_if.wr_mst                       dma_ram_wr,

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
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_rd_op_start_tag,
    output wire logic                            stat_rd_op_start_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_rd_op_finish_tag,
    output wire logic [3:0]                      stat_rd_op_finish_status,
    output wire logic                            stat_rd_op_finish_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_rd_req_start_tag,
    output wire logic [12:0]                     stat_rd_req_start_len,
    output wire logic                            stat_rd_req_start_valid,
    output wire logic [$clog2(OP_TBL_SIZE)-1:0]  stat_rd_req_finish_tag,
    output wire logic [3:0]                      stat_rd_req_finish_status,
    output wire logic                            stat_rd_req_finish_valid,
    output wire logic                            stat_rd_op_tbl_full,
    output wire logic                            stat_rd_tx_stall
);

// TODO cleanup
// verilator lint_off WIDTHEXPAND

// extract parameters
localparam AXI_DATA_W = m_axi_rd.DATA_W;
localparam AXI_ADDR_W = m_axi_rd.ADDR_W;
localparam AXI_STRB_W = m_axi_rd.STRB_W;
localparam AXI_ID_W = m_axi_rd.ID_W;
localparam AXI_MAX_BURST_LEN_INT = AXI_MAX_BURST_LEN < m_axi_rd.MAX_BURST_LEN ? AXI_MAX_BURST_LEN : m_axi_rd.MAX_BURST_LEN;

localparam LEN_W = rd_desc_req.LEN_W;
localparam TAG_W = rd_desc_req.TAG_W;

localparam RAM_SEGS = dma_ram_wr.SEGS;
localparam RAM_SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;
localparam RAM_SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_wr.SEG_BE_W;
localparam RAM_SEL_W = dma_ram_wr.SEL_W;

localparam RAM_ADDR_W = RAM_SEG_ADDR_W+$clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam RAM_DATA_W = RAM_SEGS*RAM_SEG_DATA_W;
localparam RAM_BYTE_LANES = RAM_SEG_BE_W;
localparam RAM_BYTE_SIZE = RAM_SEG_DATA_W/RAM_BYTE_LANES;

localparam AXI_BYTE_LANES = AXI_STRB_W;
localparam AXI_BYTE_SIZE = AXI_DATA_W/AXI_BYTE_LANES;
localparam AXI_BURST_SIZE = $clog2(AXI_STRB_W);
localparam AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

localparam OFFSET_W = AXI_STRB_W > 1 ? $clog2(AXI_STRB_W) : 1;
localparam OFFSET_MASK = AXI_STRB_W > 1 ? {OFFSET_W{1'b1}} : 0;
localparam RAM_OFFSET_W = $clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam ADDR_MASK = {AXI_ADDR_W{1'b1}} << $clog2(AXI_STRB_W);
localparam CYCLE_COUNT_W = LEN_W - AXI_BURST_SIZE + 1;

localparam OP_TAG_W = $clog2(OP_TBL_SIZE);
localparam OP_TBL_READ_COUNT_W = AXI_ID_W+1;
localparam OP_TBL_WRITE_COUNT_W = LEN_W;

localparam STATUS_FIFO_AW = 5;
localparam OUTPUT_FIFO_AW = 5;

// check configuration
if (AXI_BYTE_SIZE * AXI_STRB_W != AXI_DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (AXI_BYTE_SIZE != RAM_BYTE_SIZE)
    $fatal(0, "Error: byte size mismatch (instance %m)");

if (2**$clog2(AXI_BYTE_LANES) != AXI_BYTE_LANES)
    $fatal(0, "Error: AXI byte lane count must be even power of two (instance %m)");

if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256)
    $fatal(0, "Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");

if (RAM_SEGS < 2)
    $fatal(0, "Error: RAM interface requires at least 2 segments (instance %m)");

if (RAM_DATA_W != AXI_DATA_W*2)
    $fatal(0, "Error: RAM interface width must be double the AXI interface width (instance %m)");

if (2**$clog2(RAM_BYTE_LANES) != RAM_BYTE_LANES)
    $fatal(0, "Error: RAM byte lane count must be even power of two (instance %m)");

if (OP_TBL_SIZE > 2**AXI_ID_W)
    $fatal(0, "Error: AXI_ID_W insufficient for requested OP_TBL_SIZE (instance %m)");

if (rd_desc_req.SRC_ADDR_W < AXI_ADDR_W || rd_desc_req.DST_ADDR_W < RAM_ADDR_W)
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
    AXI_STATE_IDLE,
    AXI_STATE_WRITE
} axi_state_t;

axi_state_t axi_state_reg = AXI_STATE_IDLE, axi_state_next;

logic [AXI_ADDR_W-1:0] req_axi_addr_reg = '0, req_axi_addr_next;
logic [RAM_SEL_W-1:0] req_ram_sel_reg = '0, req_ram_sel_next;
logic [RAM_ADDR_W-1:0] req_ram_addr_reg = '0, req_ram_addr_next;
logic [LEN_W-1:0] req_op_count_reg = '0, req_op_count_next;
logic [12:0] req_tr_count_reg = '0, req_tr_count_next;
logic req_zero_len_reg = 1'b0, req_zero_len_next;
logic [TAG_W-1:0] req_tag_reg = '0, req_tag_next;

logic [RAM_SEL_W-1:0] ram_sel_reg = '0, ram_sel_next;
logic [RAM_ADDR_W-1:0] addr_reg = '0, addr_next;
logic [RAM_ADDR_W-1:0] addr_delay_reg = '0, addr_delay_next;
logic [12:0] op_count_reg = '0, op_count_next;
logic zero_len_reg = 1'b0, zero_len_next;
logic [RAM_SEGS-1:0] ram_mask_reg = '0, ram_mask_next;
logic [RAM_SEGS-1:0] ram_mask_0_reg = '0, ram_mask_0_next;
logic [RAM_SEGS-1:0] ram_mask_1_reg = '0, ram_mask_1_next;
logic ram_wrap_reg = 1'b0, ram_wrap_next;
logic [OFFSET_W+1-1:0] cycle_byte_count_reg = '0, cycle_byte_count_next;
logic [RAM_OFFSET_W-1:0] start_offset_reg = '0, start_offset_next;
logic [RAM_OFFSET_W-1:0] end_offset_reg = '0, end_offset_next;
logic [OFFSET_W-1:0] offset_reg = '0, offset_next;
logic [OP_TAG_W-1:0] op_tag_reg = '0, op_tag_next;

logic [STATUS_FIFO_AW+1-1:0] status_fifo_wr_ptr_reg = '0;
logic [STATUS_FIFO_AW+1-1:0] status_fifo_rd_ptr_reg = '0, status_fifo_rd_ptr_next;
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
logic status_fifo_we;
logic status_fifo_mask_reg = 1'b0, status_fifo_mask_next;
logic status_fifo_finish_reg = 1'b0, status_fifo_finish_next;
logic [3:0] status_fifo_error_reg = 4'd0, status_fifo_error_next;
logic status_fifo_we_reg = 1'b0, status_fifo_we_next;
logic status_fifo_half_full_reg = 1'b0;
logic [OP_TAG_W-1:0] status_fifo_rd_op_tag_reg = '0, status_fifo_rd_op_tag_next;
logic [RAM_SEGS-1:0] status_fifo_rd_mask_reg = '0, status_fifo_rd_mask_next;
logic status_fifo_rd_finish_reg = 1'b0, status_fifo_rd_finish_next;
logic [3:0] status_fifo_rd_error_reg = 4'd0, status_fifo_rd_error_next;
logic status_fifo_rd_valid_reg = 1'b0, status_fifo_rd_valid_next;

logic [OP_TAG_W+1-1:0] active_op_count_reg = '0;
logic inc_active_op;
logic dec_active_op;

logic [AXI_DATA_W-1:0] m_axi_rdata_int_reg = '0, m_axi_rdata_int_next;
logic m_axi_rvalid_int_reg = 1'b0, m_axi_rvalid_int_next;

logic [AXI_ID_W-1:0] m_axi_arid_reg = '0, m_axi_arid_next;
logic [AXI_ADDR_W-1:0] m_axi_araddr_reg = '0, m_axi_araddr_next;
logic [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
logic m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
logic m_axi_rready_reg = 1'b0, m_axi_rready_next;

logic rd_desc_req_ready_reg = 1'b0, rd_desc_req_ready_next;

logic [TAG_W-1:0] rd_desc_sts_tag_reg = '0, rd_desc_sts_tag_next;
logic [3:0] rd_desc_sts_error_reg = 4'd0, rd_desc_sts_error_next;
logic rd_desc_sts_valid_reg = 1'b0, rd_desc_sts_valid_next;

logic status_busy_reg = 1'b0;

logic [OP_TAG_W-1:0] stat_rd_op_start_tag_reg = '0, stat_rd_op_start_tag_next;
logic stat_rd_op_start_valid_reg = 1'b0, stat_rd_op_start_valid_next;
logic [OP_TAG_W-1:0] stat_rd_op_finish_tag_reg = '0, stat_rd_op_finish_tag_next;
logic [3:0] stat_rd_op_finish_status_reg = 4'd0, stat_rd_op_finish_status_next;
logic stat_rd_op_finish_valid_reg = 1'b0, stat_rd_op_finish_valid_next;
logic [OP_TAG_W-1:0] stat_rd_req_start_tag_reg = '0, stat_rd_req_start_tag_next;
logic [12:0] stat_rd_req_start_len_reg = 13'd0, stat_rd_req_start_len_next;
logic stat_rd_req_start_valid_reg = 1'b0, stat_rd_req_start_valid_next;
logic [OP_TAG_W-1:0] stat_rd_req_finish_tag_reg = '0, stat_rd_req_finish_tag_next;
logic [3:0] stat_rd_req_finish_status_reg = 4'd0, stat_rd_req_finish_status_next;
logic stat_rd_req_finish_valid_reg = 1'b0, stat_rd_req_finish_valid_next;
logic stat_rd_op_tbl_full_reg = 1'b0, stat_rd_op_tbl_full_next;
logic stat_rd_tx_stall_reg = 1'b0, stat_rd_tx_stall_next;

// internal datapath
logic [RAM_SEGS-1:0][RAM_SEL_W-1:0]      ram_wr_cmd_sel_int;
logic [RAM_SEGS-1:0][RAM_SEG_BE_W-1:0]   ram_wr_cmd_be_int;
logic [RAM_SEGS-1:0][RAM_SEG_ADDR_W-1:0] ram_wr_cmd_addr_int;
logic [RAM_SEGS-1:0][RAM_SEG_DATA_W-1:0] ram_wr_cmd_data_int;
logic [RAM_SEGS-1:0]                     ram_wr_cmd_valid_int;
wire  [RAM_SEGS-1:0]                     ram_wr_cmd_ready_int;

wire [RAM_SEGS-1:0] out_done;
logic [RAM_SEGS-1:0] out_done_ack;

assign m_axi_rd.arid = USE_AXI_ID ? m_axi_arid_reg : '0;
assign m_axi_rd.araddr = m_axi_araddr_reg;
assign m_axi_rd.arlen = m_axi_arlen_reg;
assign m_axi_rd.arsize = 3'(AXI_BURST_SIZE);
assign m_axi_rd.arburst = 2'b01;
assign m_axi_rd.arlock = 1'b0;
assign m_axi_rd.arcache = 4'b0011;
assign m_axi_rd.arprot = 3'b010;
assign m_axi_rd.arvalid = m_axi_arvalid_reg;
assign m_axi_rd.rready = m_axi_rready_reg;

assign rd_desc_req.req_ready = rd_desc_req_ready_reg;

assign rd_desc_sts.sts_tag = rd_desc_sts_tag_reg;
assign rd_desc_sts.sts_error = rd_desc_sts_error_reg;
assign rd_desc_sts.sts_valid = rd_desc_sts_valid_reg;

assign status_busy = status_busy_reg;

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
assign stat_rd_op_tbl_full = stat_rd_op_tbl_full_reg;
assign stat_rd_tx_stall = stat_rd_tx_stall_reg;

// operation tag management
logic [OP_TAG_W+1-1:0] op_tbl_start_ptr_reg = '0;
logic [AXI_ADDR_W-1:0] op_tbl_start_axi_addr;
logic [RAM_SEL_W-1:0] op_tbl_start_ram_sel;
logic [RAM_ADDR_W-1:0] op_tbl_start_ram_addr;
logic [12:0] op_tbl_start_len;
logic op_tbl_start_zero_len;
logic [CYCLE_COUNT_W-1:0] op_tbl_start_cycle_count;
logic [TAG_W-1:0] op_tbl_start_tag;
logic op_tbl_start_last;
logic op_tbl_start_en;
logic [OP_TAG_W+1-1:0] op_tbl_read_complete_ptr_reg = '0;
logic op_tbl_read_complete_en;
logic [OP_TAG_W-1:0] op_tbl_update_status_ptr;
logic [3:0] op_tbl_update_status_error;
logic op_tbl_update_status_en;
logic [OP_TAG_W-1:0] op_tbl_write_complete_ptr;
logic op_tbl_write_complete_en;
logic [OP_TAG_W+1-1:0] op_tbl_finish_ptr_reg = '0;
logic op_tbl_finish_en;

logic [2**OP_TAG_W-1:0] op_tbl_active = '0;
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXI_ADDR_W-1:0] op_tbl_axi_addr[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_SEL_W-1:0] op_tbl_ram_sel[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [RAM_ADDR_W-1:0] op_tbl_ram_addr[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [12:0] op_tbl_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_zero_len[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [CYCLE_COUNT_W-1:0] op_tbl_cycle_count[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [TAG_W-1:0] op_tbl_tag[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_last[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_write_complete[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_error_a[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic op_tbl_error_b[2**OP_TAG_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [3:0] op_tbl_error_code[2**OP_TAG_W] = '{default: '0};

always_comb begin
    req_state_next = REQ_STATE_IDLE;

    rd_desc_req_ready_next = 1'b0;

    stat_rd_op_start_tag_next = stat_rd_op_start_tag_reg;
    stat_rd_op_start_valid_next = 1'b0;
    stat_rd_req_start_tag_next = stat_rd_req_start_tag_reg;
    stat_rd_req_start_len_next = stat_rd_req_start_len_reg;
    stat_rd_req_start_valid_next = 1'b0;
    stat_rd_op_tbl_full_next = !(!op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W));
    stat_rd_tx_stall_next = m_axi_arvalid_reg && !m_axi_rd.arready;

    req_axi_addr_next = req_axi_addr_reg;
    req_ram_sel_next = req_ram_sel_reg;
    req_ram_addr_next = req_ram_addr_reg;
    req_op_count_next = req_op_count_reg;
    req_tr_count_next = req_tr_count_reg;
    req_zero_len_next = req_zero_len_reg;
    req_tag_next = req_tag_reg;

    m_axi_arid_next = m_axi_arid_reg;
    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_rd.arready;

    op_tbl_start_axi_addr = req_axi_addr_reg;
    op_tbl_start_ram_sel = req_ram_sel_reg;
    op_tbl_start_ram_addr = req_ram_addr_reg;
    op_tbl_start_len = '0;
    op_tbl_start_zero_len = req_zero_len_reg;
    op_tbl_start_tag = req_tag_reg;
    op_tbl_start_cycle_count = '0;
    op_tbl_start_last = '0;
    op_tbl_start_en = 1'b0;

    inc_active_op = 1'b0;

    // segmentation and request generation
    case (req_state_reg)
        REQ_STATE_IDLE: begin
            rd_desc_req_ready_next = !op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && enable;

            req_axi_addr_next = rd_desc_req.req_src_addr;
            req_ram_sel_next = rd_desc_req.req_dst_sel;
            req_ram_addr_next = rd_desc_req.req_dst_addr;
            if (rd_desc_req.req_len == 0) begin
                // zero-length operation
                req_op_count_next = 1;
                req_zero_len_next = 1'b1;
            end else begin
                req_op_count_next = rd_desc_req.req_len;
                req_zero_len_next = 1'b0;
            end
            req_tag_next = rd_desc_req.req_tag;

            if (req_op_count_next <= LEN_W'(AXI_MAX_BURST_SIZE) - LEN_W'(req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                // packet smaller than max burst size
                if ((12'(req_axi_addr_next & 12'hfff) + 12'(req_op_count_next & 12'hfff)) >> 12 != 0 || req_op_count_next >> 12 != 0) begin
                    // crosses 4k boundary
                    req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    req_tr_count_next = 13'(req_op_count_next);
                end
            end else begin
                // packet larger than max burst size
                if ((12'(req_axi_addr_next & 12'hfff) + 12'(AXI_MAX_BURST_SIZE)) >> 12 != 0) begin
                    // crosses 4k boundary
                    req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                end else begin
                    // does not cross 4k boundary
                    req_tr_count_next = 13'(AXI_MAX_BURST_SIZE) - 13'(req_axi_addr_next & OFFSET_MASK);
                end
            end

            if (rd_desc_req.req_ready && rd_desc_req.req_valid) begin
                rd_desc_req_ready_next = 1'b0;

                stat_rd_op_start_tag_next = stat_rd_op_start_tag_reg+1;
                stat_rd_op_start_valid_next = 1'b1;

                req_state_next = REQ_STATE_START;
            end else begin
                req_state_next = REQ_STATE_IDLE;
            end
        end
        REQ_STATE_START: begin
            if (!op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && (!m_axi_rd.arvalid || m_axi_rd.arready)) begin
                req_axi_addr_next = req_axi_addr_reg + AXI_ADDR_W'(req_tr_count_reg);
                req_ram_addr_next = req_ram_addr_reg + RAM_ADDR_W'(req_tr_count_reg);
                req_op_count_next = req_op_count_reg - LEN_W'(req_tr_count_reg);

                op_tbl_start_axi_addr = req_axi_addr_reg;
                op_tbl_start_ram_sel = req_ram_sel_reg;
                op_tbl_start_ram_addr = req_ram_addr_reg;
                op_tbl_start_len = req_tr_count_next;
                op_tbl_start_zero_len = req_zero_len_reg;
                op_tbl_start_tag = req_tag_reg;
                op_tbl_start_cycle_count = CYCLE_COUNT_W'((req_tr_count_next + 13'(req_axi_addr_reg & OFFSET_MASK) - 13'd1) >> AXI_BURST_SIZE);
                op_tbl_start_last = req_op_count_reg == LEN_W'(req_tr_count_next);
                op_tbl_start_en = 1'b1;
                inc_active_op = 1'b1;

                stat_rd_req_start_tag_next = op_tbl_start_ptr_reg[OP_TAG_W-1:0];
                stat_rd_req_start_len_next = req_zero_len_reg ? '0 : req_tr_count_reg;
                stat_rd_req_start_valid_next = 1'b1;

                m_axi_arid_next = op_tbl_start_ptr_reg[OP_TAG_W-1:0];
                m_axi_araddr_next = req_axi_addr_reg;
                m_axi_arlen_next = 8'(op_tbl_start_cycle_count);
                m_axi_arvalid_next = 1'b1;

                if (req_op_count_next <= LEN_W'(AXI_MAX_BURST_SIZE) - LEN_W'(req_axi_addr_next & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                    // packet smaller than max burst size
                    if ((12'(req_axi_addr_next & 12'hfff) + 12'(req_op_count_next & 12'hfff)) >> 12 != 0 || req_op_count_next >> 12 != 0) begin
                        // crosses 4k boundary
                        req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        req_tr_count_next = 13'(req_op_count_next);
                    end
                end else begin
                    // packet larger than max burst size
                    if ((12'(req_axi_addr_next & 12'hfff) + 12'(AXI_MAX_BURST_SIZE)) >> 12 != 0) begin
                        // crosses 4k boundary
                        req_tr_count_next = 13'h1000 - req_axi_addr_next[11:0];
                    end else begin
                        // does not cross 4k boundary
                        req_tr_count_next = 13'(AXI_MAX_BURST_SIZE) - 13'(req_axi_addr_next & OFFSET_MASK);
                    end
                end

                if (!op_tbl_start_last) begin
                    req_state_next = REQ_STATE_START;
                end else begin
                    rd_desc_req_ready_next = !op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] && ($unsigned(op_tbl_start_ptr_reg - op_tbl_finish_ptr_reg) < 2**OP_TAG_W) && enable;
                    req_state_next = REQ_STATE_IDLE;
                end
            end else begin
                req_state_next = REQ_STATE_START;
            end
        end
    endcase
end

always_comb begin
    axi_state_next = AXI_STATE_IDLE;

    m_axi_rready_next = 1'b0;

    stat_rd_op_finish_tag_next = stat_rd_op_finish_tag_reg;
    stat_rd_op_finish_status_next = stat_rd_op_finish_status_reg;
    stat_rd_op_finish_valid_next = 1'b0;
    stat_rd_req_finish_tag_next = stat_rd_req_finish_tag_reg;
    stat_rd_req_finish_status_next = stat_rd_req_finish_status_reg;
    stat_rd_req_finish_valid_next = 1'b0;

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
    offset_next = offset_reg;
    op_tag_next = op_tag_reg;

    op_tbl_read_complete_en = 1'b0;

    m_axi_rdata_int_next = m_axi_rdata_int_reg;
    m_axi_rvalid_int_next = 1'b0;

    status_fifo_mask_next = 1'b1;
    status_fifo_finish_next = 1'b0;
    status_fifo_error_next = DMA_ERROR_NONE;
    status_fifo_we_next = 1'b0;

    out_done_ack = '0;

    // Write generation
    ram_wr_cmd_sel_int = '{RAM_SEGS{ram_sel_reg}};
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
    ram_wr_cmd_data_int = RAM_DATA_W'({3{m_axi_rdata_int_reg}} >> (AXI_DATA_W - offset_reg*AXI_BYTE_SIZE));
    ram_wr_cmd_valid_int = '0;

    if (m_axi_rvalid_int_reg) begin
        ram_wr_cmd_valid_int = ram_mask_reg;
    end

    // AXI read response handling
    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state, wait for read data
            m_axi_rready_next = &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            if (USE_AXI_ID) begin
                op_tag_next = OP_TAG_W'(m_axi_rd.rid);
            end else begin
                op_tag_next = OP_TAG_W'(op_tbl_read_complete_ptr_reg);
            end
            ram_sel_next = op_tbl_ram_sel[op_tag_next];
            addr_next = op_tbl_ram_addr[op_tag_next];
            op_count_next = op_tbl_len[op_tag_next];
            zero_len_next = op_tbl_zero_len[op_tag_next];
            offset_next = OFFSET_W'(op_tbl_ram_addr[op_tag_next][RAM_OFFSET_W-1:0]-RAM_OFFSET_W'(op_tbl_axi_addr[op_tag_next] & OFFSET_MASK));

            if (m_axi_rd.rready && m_axi_rd.rvalid) begin
                if (op_count_next > 13'(AXI_BYTE_LANES)-13'(op_tbl_axi_addr[op_tag_next] & OFFSET_MASK)) begin
                    cycle_byte_count_next = (OFFSET_W+1)'(AXI_BYTE_LANES)-(OFFSET_W+1)'(op_tbl_axi_addr[op_tag_next] & OFFSET_MASK);
                end else begin
                    cycle_byte_count_next = (OFFSET_W+1)'(op_count_next);
                end
                start_offset_next = RAM_OFFSET_W'(addr_next);
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                if (!ram_wrap_next) begin
                    ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_1_next = '0;
                end else begin
                    ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                end

                addr_delay_next = addr_next;
                addr_next = addr_next + AXI_ADDR_W'(cycle_byte_count_next);
                op_count_next = op_count_next - 13'(cycle_byte_count_next);

                m_axi_rdata_int_next = m_axi_rd.rdata;
                m_axi_rvalid_int_next = 1'b1;

                status_fifo_mask_next = 1'b1;
                status_fifo_finish_next = 1'b0;
                status_fifo_error_next = DMA_ERROR_NONE;
                status_fifo_we_next = 1'b1;

                if (zero_len_next) begin
                    m_axi_rvalid_int_next = 1'b0;
                    status_fifo_mask_next = 1'b0;
                end

                if (m_axi_rd.rresp == AXI_RESP_SLVERR) begin
                    m_axi_rvalid_int_next = 1'b0;
                    status_fifo_mask_next = 1'b0;
                    status_fifo_error_next = DMA_ERROR_AXI_RD_SLVERR;
                end else if (m_axi_rd.rresp == AXI_RESP_DECERR) begin
                    m_axi_rvalid_int_next = 1'b0;
                    status_fifo_mask_next = 1'b0;
                    status_fifo_error_next = DMA_ERROR_AXI_RD_DECERR;
                end

                stat_rd_req_finish_tag_next = op_tag_next;
                stat_rd_req_finish_status_next = status_fifo_error_next;
                stat_rd_req_finish_valid_next = 1'b0;

                if (!USE_AXI_ID) begin
                    op_tbl_read_complete_en = 1'b1;
                end

                if (m_axi_rd.rlast) begin
                    status_fifo_finish_next = 1'b1;
                    stat_rd_req_finish_valid_next = 1'b1;
                    axi_state_next = AXI_STATE_IDLE;
                end else begin
                    axi_state_next = AXI_STATE_WRITE;
                end
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_WRITE: begin
            // write state - generate write operations
            m_axi_rready_next = &ram_wr_cmd_ready_int && !status_fifo_half_full_reg;

            if (m_axi_rd.rready && m_axi_rd.rvalid) begin

                if (op_count_next > 13'(AXI_BYTE_LANES)) begin
                    cycle_byte_count_next = (OFFSET_W+1)'(AXI_BYTE_LANES);
                end else begin
                    cycle_byte_count_next = (OFFSET_W+1)'(op_count_next);
                end
                start_offset_next = RAM_OFFSET_W'(addr_next);
                {ram_wrap_next, end_offset_next} = start_offset_next+cycle_byte_count_next-1;

                ram_mask_0_next = {RAM_SEGS{1'b1}} << (start_offset_next >> $clog2(RAM_SEG_BE_W));
                ram_mask_1_next = {RAM_SEGS{1'b1}} >> (RAM_SEGS-1-(end_offset_next >> $clog2(RAM_SEG_BE_W)));

                if (!ram_wrap_next) begin
                    ram_mask_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_0_next = ram_mask_0_next & ram_mask_1_next;
                    ram_mask_1_next = '0;
                end else begin
                    ram_mask_next = ram_mask_0_next | ram_mask_1_next;
                end

                addr_delay_next = addr_next;
                addr_next = addr_next + AXI_ADDR_W'(cycle_byte_count_next);
                op_count_next = op_count_next - 13'(cycle_byte_count_next);

                m_axi_rdata_int_next = m_axi_rd.rdata;
                m_axi_rvalid_int_next = 1'b1;

                status_fifo_mask_next = 1'b1;
                status_fifo_finish_next = 1'b0;
                status_fifo_error_next = DMA_ERROR_NONE;
                status_fifo_we_next = 1'b1;

                if (m_axi_rd.rresp == AXI_RESP_SLVERR) begin
                    m_axi_rvalid_int_next = 1'b0;
                    status_fifo_mask_next = 1'b0;
                    status_fifo_error_next = DMA_ERROR_AXI_RD_SLVERR;
                end else if (m_axi_rd.rresp == AXI_RESP_DECERR) begin
                    m_axi_rvalid_int_next = 1'b0;
                    status_fifo_mask_next = 1'b0;
                    status_fifo_error_next = DMA_ERROR_AXI_RD_DECERR;
                end

                stat_rd_req_finish_tag_next = op_tag_next;
                stat_rd_req_finish_status_next = status_fifo_error_next;
                stat_rd_req_finish_valid_next = 1'b0;

                if (m_axi_rd.rlast) begin
                    status_fifo_finish_next = 1'b1;
                    stat_rd_req_finish_valid_next = 1'b1;
                    axi_state_next = AXI_STATE_IDLE;
                end else begin
                    axi_state_next = AXI_STATE_WRITE;
                end
            end else begin
                axi_state_next = AXI_STATE_WRITE;
            end
        end
    endcase

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    status_fifo_wr_op_tag = op_tag_reg;
    status_fifo_wr_mask = status_fifo_mask_reg ? ram_mask_reg : 0;
    status_fifo_wr_finish = status_fifo_finish_reg;
    status_fifo_wr_error = status_fifo_error_reg;
    status_fifo_we = 1'b0;

    if (status_fifo_we_reg) begin
        status_fifo_wr_op_tag = op_tag_reg;
        status_fifo_wr_mask = status_fifo_mask_reg ? ram_mask_reg : 0;
        status_fifo_wr_finish = status_fifo_finish_reg;
        status_fifo_wr_error = status_fifo_error_reg;
        status_fifo_we = 1'b1;
    end

    status_fifo_rd_op_tag_next = status_fifo_rd_op_tag_reg;
    status_fifo_rd_mask_next = status_fifo_rd_mask_reg;
    status_fifo_rd_finish_next = status_fifo_rd_finish_reg;
    status_fifo_rd_valid_next = status_fifo_rd_valid_reg;
    status_fifo_rd_error_next = status_fifo_rd_error_reg;

    op_tbl_update_status_ptr = status_fifo_rd_op_tag_reg;
    op_tbl_update_status_error = status_fifo_rd_error_reg;
    op_tbl_update_status_en = 1'b0;

    op_tbl_write_complete_ptr = status_fifo_rd_op_tag_reg;
    op_tbl_write_complete_en = 1'b0;

    if (status_fifo_rd_valid_reg && (status_fifo_rd_mask_reg & ~out_done) == 0) begin
        // got write completion, pop and return status
        status_fifo_rd_valid_next = 1'b0;
        op_tbl_update_status_en = 1'b1;

        out_done_ack = status_fifo_rd_mask_reg;

        if (status_fifo_rd_finish_reg) begin
            // mark done
            op_tbl_write_complete_ptr = status_fifo_rd_op_tag_reg;
            op_tbl_write_complete_en = 1'b1;
        end
    end

    if (!status_fifo_rd_valid_next && status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        status_fifo_rd_op_tag_next = status_fifo_op_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_mask_next = status_fifo_mask[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_finish_next = status_fifo_finish[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_error_next = status_fifo_error[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
        status_fifo_rd_valid_next = 1'b1;
        status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;
    end

    // commit operations in-order
    op_tbl_finish_en = 1'b0;
    dec_active_op = 1'b0;

    if (rd_desc_sts_valid_reg) begin
        rd_desc_sts_error_next = DMA_ERROR_NONE;
    end else begin
        rd_desc_sts_error_next = rd_desc_sts_error_reg;
    end

    rd_desc_sts_tag_next = op_tbl_tag[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
    rd_desc_sts_valid_next = 1'b0;

    stat_rd_op_finish_tag_next = stat_rd_op_finish_tag_reg;
    stat_rd_op_finish_status_next = rd_desc_sts_error_next;
    stat_rd_op_finish_valid_next = 1'b0;

    if (op_tbl_active[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] && op_tbl_write_complete[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] && op_tbl_finish_ptr_reg != op_tbl_start_ptr_reg) begin
        op_tbl_finish_en = 1'b1;
        dec_active_op = 1'b1;

        if (op_tbl_error_a[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] != op_tbl_error_b[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]]) begin
            rd_desc_sts_error_next = op_tbl_error_code[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
        end

        stat_rd_op_finish_status_next = rd_desc_sts_error_next;

        if (op_tbl_last[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]]) begin
            rd_desc_sts_tag_next = op_tbl_tag[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]];
            rd_desc_sts_valid_next = 1'b1;
            stat_rd_op_finish_tag_next = stat_rd_op_finish_tag_reg + 1;
            stat_rd_op_finish_valid_next = 1'b1;
        end
    end
end

always_ff @(posedge clk) begin
    req_state_reg <= req_state_next;
    axi_state_reg <= axi_state_next;

    req_axi_addr_reg <= req_axi_addr_next;
    req_ram_sel_reg <= req_ram_sel_next;
    req_ram_addr_reg <= req_ram_addr_next;
    req_op_count_reg <= req_op_count_next;
    req_tr_count_reg <= req_tr_count_next;
    req_zero_len_reg <= req_zero_len_next;
    req_tag_reg <= req_tag_next;

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
    offset_reg <= offset_next;
    op_tag_reg <= op_tag_next;

    m_axi_rdata_int_reg <= m_axi_rdata_int_next;
    m_axi_rvalid_int_reg <= m_axi_rvalid_int_next;

    m_axi_arid_reg <= m_axi_arid_next;
    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

    rd_desc_req_ready_reg <= rd_desc_req_ready_next;

    rd_desc_sts_tag_reg <= rd_desc_sts_tag_next;
    rd_desc_sts_error_reg <= rd_desc_sts_error_next;
    rd_desc_sts_valid_reg <= rd_desc_sts_valid_next;

    status_busy_reg <= active_op_count_reg != 0;

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
    stat_rd_op_tbl_full_reg <= stat_rd_op_tbl_full_next;
    stat_rd_tx_stall_reg <= stat_rd_tx_stall_next;

    if (status_fifo_we) begin
        status_fifo_op_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_op_tag;
        status_fifo_mask[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_mask;
        status_fifo_finish[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_finish;
        status_fifo_error[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_error;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    status_fifo_mask_reg <= status_fifo_mask_next;
    status_fifo_finish_reg <= status_fifo_finish_next;
    status_fifo_error_reg <= status_fifo_error_next;
    status_fifo_we_reg <= status_fifo_we_next;

    status_fifo_rd_op_tag_reg <= status_fifo_rd_op_tag_next;
    status_fifo_rd_mask_reg <= status_fifo_rd_mask_next;
    status_fifo_rd_finish_reg <= status_fifo_rd_finish_next;
    status_fifo_rd_error_reg <= status_fifo_rd_error_next;
    status_fifo_rd_valid_reg <= status_fifo_rd_valid_next;

    status_fifo_half_full_reg <= $unsigned(status_fifo_wr_ptr_reg - status_fifo_rd_ptr_reg) >= 2**(STATUS_FIFO_AW-1);

    active_op_count_reg <= active_op_count_reg + OP_TAG_W'(inc_active_op) - OP_TAG_W'(dec_active_op);

    if (op_tbl_start_en) begin
        op_tbl_start_ptr_reg <= op_tbl_start_ptr_reg + 1;
        op_tbl_active[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= 1'b1;
        op_tbl_axi_addr[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_axi_addr;
        op_tbl_ram_sel[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_ram_sel;
        op_tbl_ram_addr[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_ram_addr;
        op_tbl_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_len;
        op_tbl_zero_len[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_zero_len;
        op_tbl_cycle_count[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_cycle_count;
        op_tbl_tag[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_tag;
        op_tbl_last[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_start_last;
        op_tbl_write_complete[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= 1'b0;
        op_tbl_error_a[op_tbl_start_ptr_reg[OP_TAG_W-1:0]] <= op_tbl_error_b[op_tbl_start_ptr_reg[OP_TAG_W-1:0]];
    end

    if (!USE_AXI_ID && op_tbl_read_complete_en) begin
        op_tbl_read_complete_ptr_reg <= op_tbl_read_complete_ptr_reg + 1;
    end

    if (op_tbl_update_status_en) begin
        if (op_tbl_update_status_error != 0) begin
            op_tbl_error_code[op_tbl_update_status_ptr] <= op_tbl_update_status_error;
            op_tbl_error_b[op_tbl_update_status_ptr] <= !op_tbl_error_a[op_tbl_update_status_ptr];
        end
    end

    if (op_tbl_write_complete_en) begin
        op_tbl_write_complete[op_tbl_write_complete_ptr] <= 1'b1;
    end

    if (op_tbl_finish_en) begin
        op_tbl_finish_ptr_reg <= op_tbl_finish_ptr_reg + 1;
        op_tbl_active[op_tbl_finish_ptr_reg[OP_TAG_W-1:0]] <= 1'b0;
    end

    if (rst) begin
        req_state_reg <= REQ_STATE_IDLE;
        axi_state_reg <= AXI_STATE_IDLE;

        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        rd_desc_req_ready_reg <= 1'b0;
        rd_desc_sts_error_reg <= 4'd0;
        rd_desc_sts_valid_reg <= 1'b0;

        status_busy_reg <= 1'b0;

        stat_rd_op_start_tag_reg <= '0;
        stat_rd_op_start_valid_reg <= 1'b0;
        stat_rd_op_finish_tag_reg <= '0;
        stat_rd_op_finish_valid_reg <= 1'b0;
        stat_rd_req_start_valid_reg <= 1'b0;
        stat_rd_req_finish_valid_reg <= 1'b0;
        stat_rd_op_tbl_full_reg <= 1'b0;
        stat_rd_tx_stall_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= '0;
        status_fifo_rd_ptr_reg <= '0;
        status_fifo_we_reg <= 1'b0;
        status_fifo_rd_valid_reg <= 1'b0;

        active_op_count_reg <= '0;

        op_tbl_start_ptr_reg <= '0;
        op_tbl_read_complete_ptr_reg <= '0;
        op_tbl_finish_ptr_reg <= '0;
        op_tbl_active <= '0;
    end
end

// output datapath logic (write data)
for (genvar n = 0; n < RAM_SEGS; n = n + 1) begin

    logic [RAM_SEL_W-1:0]      ram_wr_cmd_sel_reg = '0;
    logic [RAM_SEG_BE_W-1:0]   ram_wr_cmd_be_reg = '0;
    logic [RAM_SEG_ADDR_W-1:0] ram_wr_cmd_addr_reg = '0;
    logic [RAM_SEG_DATA_W-1:0] ram_wr_cmd_data_reg = '0;
    logic                      ram_wr_cmd_valid_reg = 1'b0;

    logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_wr_ptr_reg = '0;
    logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_rd_ptr_reg = '0;
    logic out_fifo_half_full_reg = 1'b0;

    wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_AW{1'b0}}});
    wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    logic [RAM_SEL_W-1:0]  out_fifo_wr_cmd_sel[2**OUTPUT_FIFO_AW];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    logic [RAM_SEG_BE_W-1:0]   out_fifo_wr_cmd_be[2**OUTPUT_FIFO_AW];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    logic [RAM_SEG_ADDR_W-1:0] out_fifo_wr_cmd_addr[2**OUTPUT_FIFO_AW];
    (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
    logic [RAM_SEG_DATA_W-1:0] out_fifo_wr_cmd_data[2**OUTPUT_FIFO_AW];

    logic [OUTPUT_FIFO_AW+1-1:0] done_count_reg = '0;
    logic done_reg = 1'b0;

    assign ram_wr_cmd_ready_int[n] = !out_fifo_half_full_reg;

    assign dma_ram_wr.wr_cmd_sel[n] = ram_wr_cmd_sel_reg;
    assign dma_ram_wr.wr_cmd_be[n] = ram_wr_cmd_be_reg;
    assign dma_ram_wr.wr_cmd_addr[n] = ram_wr_cmd_addr_reg;
    assign dma_ram_wr.wr_cmd_data[n] = ram_wr_cmd_data_reg;
    assign dma_ram_wr.wr_cmd_valid[n] = ram_wr_cmd_valid_reg;

    assign out_done[n] = done_reg;

    always_ff @(posedge clk) begin
        ram_wr_cmd_valid_reg <= ram_wr_cmd_valid_reg && !dma_ram_wr.wr_cmd_ready[n];

        out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_AW-1);

        if (!out_fifo_full && ram_wr_cmd_valid_int[n]) begin
            out_fifo_wr_cmd_sel[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_sel_int[n];
            out_fifo_wr_cmd_be[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_be_int[n];
            out_fifo_wr_cmd_addr[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_addr_int[n];
            out_fifo_wr_cmd_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= ram_wr_cmd_data_int[n];
            out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
        end

        if (!out_fifo_empty && (!ram_wr_cmd_valid_reg || dma_ram_wr.wr_cmd_ready[n])) begin
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
