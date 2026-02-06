// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2018-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 DMA
 */
module taxi_axi_dma_wr #
(
    // Maximum AXI burst length to generate
    parameter AXI_MAX_BURST_LEN = 16,
    // Enable support for unaligned transfers
    parameter logic UNALIGNED_EN = 1'b1
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
        * DMA write descriptor
        */
    taxi_dma_desc_if.req_snk  wr_desc_req,
    taxi_dma_desc_if.sts_src  wr_desc_sts,

    /*
     * AXI stream write data input
     */
    taxi_axis_if.snk          s_axis_wr_data,

    /*
     * AXI4 master interface
     */
    taxi_axi_if.wr_mst        m_axi_wr,

    /*
     * Configuration
     */
    input  wire logic         enable,
    input  wire logic         abort
);

// extract parameters
localparam AXI_DATA_W = m_axi_wr.DATA_W;
localparam AXI_ADDR_W = m_axi_wr.ADDR_W;
localparam AXI_STRB_W = m_axi_wr.STRB_W;
localparam AXI_ID_W = m_axi_wr.ID_W;
localparam AXI_MAX_BURST_LEN_INT = AXI_MAX_BURST_LEN < m_axi_wr.MAX_BURST_LEN ? AXI_MAX_BURST_LEN : m_axi_wr.MAX_BURST_LEN;

localparam LEN_W = wr_desc_req.LEN_W;
localparam TAG_W = wr_desc_req.TAG_W;

localparam AXIS_DATA_W = s_axis_wr_data.DATA_W;
localparam AXIS_KEEP_EN = s_axis_wr_data.KEEP_EN;
localparam AXIS_KEEP_W = s_axis_wr_data.KEEP_W;
localparam AXIS_LAST_EN = s_axis_wr_data.LAST_EN;
localparam AXIS_ID_EN = s_axis_wr_data.ID_EN;
localparam AXIS_ID_W = s_axis_wr_data.ID_W;
localparam AXIS_DEST_EN = s_axis_wr_data.DEST_EN;
localparam AXIS_DEST_W = s_axis_wr_data.DEST_W;
localparam AXIS_USER_EN = s_axis_wr_data.USER_EN;
localparam AXIS_USER_W = s_axis_wr_data.USER_W;

localparam AXI_BYTE_LANES = AXI_STRB_W;
localparam AXI_BYTE_SIZE = AXI_DATA_W/AXI_BYTE_LANES;
localparam AXI_BURST_SIZE = $clog2(AXI_STRB_W);
localparam AXI_MAX_BURST_SIZE = AXI_MAX_BURST_LEN << AXI_BURST_SIZE;

localparam AXIS_KEEP_W_INT = AXIS_KEEP_EN ? AXIS_KEEP_W : 1;
localparam AXIS_BYTE_LANES = AXIS_KEEP_W_INT;
localparam AXIS_BYTE_SIZE = AXIS_DATA_W/AXIS_BYTE_LANES;

localparam OFFSET_W = AXI_STRB_W > 1 ? $clog2(AXI_STRB_W) : 1;
localparam OFFSET_MASK = AXI_STRB_W > 1 ? {OFFSET_W{1'b1}} : 0;
localparam ADDR_MASK = {AXI_ADDR_W{1'b1}} << $clog2(AXI_STRB_W);
localparam CYCLE_COUNT_W = 13 - AXI_BURST_SIZE;

localparam STATUS_FIFO_AW = 5;
localparam OUTPUT_FIFO_AW = 5;

// check configuration
if (AXI_BYTE_SIZE * AXI_STRB_W != AXI_DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (AXIS_BYTE_SIZE * AXIS_KEEP_W_INT != AXIS_DATA_W)
    $fatal(0, "Error: AXI stream data width not evenly divisible (instance %m)");

if (AXI_BYTE_SIZE != AXIS_BYTE_SIZE)
    $fatal(0, "Error: word size mismatch (instance %m)");

if (2**$clog2(AXI_BYTE_LANES) != AXI_BYTE_LANES)
    $fatal(0, "Error: AXI word width must be even power of two (instance %m)");

if (AXI_DATA_W != AXIS_DATA_W)
    $fatal(0, "Error: AXI interface width must match AXI stream interface width (instance %m)");

if (AXI_MAX_BURST_LEN < 1 || AXI_MAX_BURST_LEN > 256)
    $fatal(0, "Error: AXI_MAX_BURST_LEN must be between 1 and 256 (instance %m)");

if (wr_desc_req.DST_ADDR_W < AXI_ADDR_W)
    $fatal(0, "Error: Descriptor address width is not sufficient (instance %m)");

localparam logic [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

localparam logic [3:0]
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
    DMA_ERROR_PCIE_CPL_STATUS_CA = 4'd11;

localparam logic [2:0]
    STATE_IDLE = 3'd0,
    STATE_START = 3'd1,
    STATE_WRITE = 3'd2,
    STATE_FINISH_BURST = 3'd3,
    STATE_DROP_DATA = 3'd4;

logic [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
logic transfer_in_save;
logic flush_save;
logic status_fifo_we;

logic [OFFSET_W:0] cycle_size;

logic [AXI_ADDR_W-1:0] addr_reg = '0, addr_next;
logic [LEN_W-1:0] op_count_reg = '0, op_count_next;
logic [12:0] tr_count_reg = '0, tr_count_next;

logic [OFFSET_W-1:0] offset_reg = '0, offset_next;
logic [AXI_STRB_W-1:0] strb_offset_mask_reg = '1, strb_offset_mask_next;
logic zero_offset_reg = 1'b1, zero_offset_next;
logic [OFFSET_W-1:0] last_cycle_offset_reg = '0, last_cycle_offset_next;
logic [LEN_W-1:0] length_reg = '0, length_next;
logic [CYCLE_COUNT_W-1:0] input_cycle_count_reg = '0, input_cycle_count_next;
logic [CYCLE_COUNT_W-1:0] output_cycle_count_reg = '0, output_cycle_count_next;
logic input_active_reg = 1'b0, input_active_next;
logic first_cycle_reg = 1'b0, first_cycle_next;
logic input_last_cycle_reg = 1'b0, input_last_cycle_next;
logic output_last_cycle_reg = 1'b0, output_last_cycle_next;
logic last_transfer_reg = 1'b0, last_transfer_next;
logic [1:0] bresp_reg = AXI_RESP_OKAY, bresp_next;

logic [TAG_W-1:0] tag_reg = '0, tag_next;
logic [AXIS_ID_W-1:0] axis_id_reg = '0, axis_id_next;
logic [AXIS_DEST_W-1:0] axis_dest_reg = '0, axis_dest_next;
logic [AXIS_USER_W-1:0] axis_user_reg = '0, axis_user_next;

logic [STATUS_FIFO_AW+1-1:0] status_fifo_wr_ptr_reg = '0;
logic [STATUS_FIFO_AW+1-1:0] status_fifo_rd_ptr_reg = '0, status_fifo_rd_ptr_next;
logic [LEN_W-1:0] status_fifo_len[2**STATUS_FIFO_AW];
logic [TAG_W-1:0] status_fifo_tag[2**STATUS_FIFO_AW];
logic [AXIS_ID_W-1:0] status_fifo_id[2**STATUS_FIFO_AW];
logic [AXIS_DEST_W-1:0] status_fifo_dest[2**STATUS_FIFO_AW];
logic [AXIS_USER_W-1:0] status_fifo_user[2**STATUS_FIFO_AW];
logic status_fifo_last[2**STATUS_FIFO_AW];
logic [LEN_W-1:0] status_fifo_wr_len;
logic [TAG_W-1:0] status_fifo_wr_tag;
logic [AXIS_ID_W-1:0] status_fifo_wr_id;
logic [AXIS_DEST_W-1:0] status_fifo_wr_dest;
logic [AXIS_USER_W-1:0] status_fifo_wr_user;
logic status_fifo_wr_last;

logic [STATUS_FIFO_AW+1-1:0] active_count_reg = 0;
logic active_count_av_reg = 1'b1;
logic inc_active;
logic dec_active;

logic wr_desc_req_ready_reg = 1'b0, wr_desc_req_ready_next;

logic [LEN_W-1:0] wr_desc_sts_len_reg = '0, wr_desc_sts_len_next;
logic [TAG_W-1:0] wr_desc_sts_tag_reg = '0, wr_desc_sts_tag_next;
logic [AXIS_ID_W-1:0] wr_desc_sts_id_reg = '0, wr_desc_sts_id_next;
logic [AXIS_DEST_W-1:0] wr_desc_sts_dest_reg = '0, wr_desc_sts_dest_next;
logic [AXIS_USER_W-1:0] wr_desc_sts_user_reg = '0, wr_desc_sts_user_next;
logic [3:0] wr_desc_sts_error_reg = 4'd0, wr_desc_sts_error_next;
logic wr_desc_sts_valid_reg = 1'b0, wr_desc_sts_valid_next;

logic [AXI_ADDR_W-1:0] m_axi_awaddr_reg = '0, m_axi_awaddr_next;
logic [7:0] m_axi_awlen_reg = 8'd0, m_axi_awlen_next;
logic m_axi_awvalid_reg = 1'b0, m_axi_awvalid_next;
logic m_axi_bready_reg = 1'b0, m_axi_bready_next;

logic s_axis_wr_data_tready_reg = 1'b0, s_axis_wr_data_tready_next;

logic [AXIS_DATA_W-1:0] save_axis_tdata_reg = '0;
logic [AXIS_KEEP_W_INT-1:0] save_axis_tkeep_reg = '0;
logic save_axis_tlast_reg = 1'b0;

logic [AXIS_DATA_W-1:0] shift_axis_tdata;
logic [AXIS_KEEP_W_INT-1:0] shift_axis_tkeep;
logic shift_axis_tvalid;
logic shift_axis_tlast;
logic shift_axis_input_tready;
logic shift_axis_extra_cycle_reg = 1'b0;

// internal datapath
logic  [AXI_DATA_W-1:0] m_axi_wdata_int;
logic  [AXI_STRB_W-1:0] m_axi_wstrb_int;
logic                   m_axi_wlast_int;
logic                   m_axi_wvalid_int;
wire                    m_axi_wready_int;

assign wr_desc_req.req_ready = wr_desc_req_ready_reg;

assign wr_desc_sts.sts_len = wr_desc_sts_len_reg;
assign wr_desc_sts.sts_tag = wr_desc_sts_tag_reg;
assign wr_desc_sts.sts_id = wr_desc_sts_id_reg;
assign wr_desc_sts.sts_dest = wr_desc_sts_dest_reg;
assign wr_desc_sts.sts_user = wr_desc_sts_user_reg;
assign wr_desc_sts.sts_error = wr_desc_sts_error_reg;
assign wr_desc_sts.sts_valid = wr_desc_sts_valid_reg;

assign s_axis_wr_data.tready = s_axis_wr_data_tready_reg;

assign m_axi_wr.awid = '0;
assign m_axi_wr.awaddr = m_axi_awaddr_reg;
assign m_axi_wr.awlen = m_axi_awlen_reg;
assign m_axi_wr.awsize = 3'(AXI_BURST_SIZE);
assign m_axi_wr.awburst = 2'b01;
assign m_axi_wr.awlock = 1'b0;
assign m_axi_wr.awcache = 4'b0011;
assign m_axi_wr.awprot = 3'b010;
assign m_axi_wr.awvalid = m_axi_awvalid_reg;
assign m_axi_wr.bready = m_axi_bready_reg;

if (!UNALIGNED_EN || AXI_STRB_W == 1) begin : shift
    always_comb begin
        shift_axis_tdata = s_axis_wr_data.tdata;
        shift_axis_tkeep = s_axis_wr_data.tkeep;
        shift_axis_tvalid = s_axis_wr_data.tvalid;
        shift_axis_tlast = AXIS_LAST_EN && s_axis_wr_data.tlast;
        shift_axis_input_tready = 1'b1;
    end
end else begin : shift
    wire [AXIS_DATA_W*2-1:0] tdata_full = {s_axis_wr_data.tdata, save_axis_tdata_reg};
    wire [AXIS_KEEP_W*2-1:0] tkeep_full = {s_axis_wr_data.tkeep, save_axis_tkeep_reg};
    wire [AXIS_KEEP_W*2-1:0] tkeep_mask = {{AXIS_KEEP_W_INT{1'b0}}, save_axis_tkeep_reg};

    always_comb begin
        if (zero_offset_reg) begin
            // passthrough if no overlap
            shift_axis_tdata = s_axis_wr_data.tdata;
            shift_axis_tkeep = s_axis_wr_data.tkeep;
            shift_axis_tvalid = s_axis_wr_data.tvalid;
            shift_axis_tlast = AXIS_LAST_EN && s_axis_wr_data.tlast;
            shift_axis_input_tready = 1'b1;
        end else if (!AXIS_LAST_EN) begin
            shift_axis_tdata = tdata_full[(OFFSET_W+1)'(AXIS_KEEP_W_INT-offset_reg)*AXIS_BYTE_SIZE +: AXIS_DATA_W];
            shift_axis_tkeep = tkeep_full[(OFFSET_W+1)'(AXIS_KEEP_W_INT-offset_reg) +: AXIS_KEEP_W];
            shift_axis_tvalid = s_axis_wr_data.tvalid;
            shift_axis_tlast = 1'b0;
            shift_axis_input_tready = 1'b1;
        end else if (shift_axis_extra_cycle_reg) begin
            shift_axis_tdata = tdata_full[(OFFSET_W+1)'(AXIS_KEEP_W_INT-offset_reg)*AXIS_BYTE_SIZE +: AXIS_DATA_W];
            shift_axis_tkeep = tkeep_mask[(OFFSET_W+1)'(AXIS_KEEP_W_INT-offset_reg) +: AXIS_KEEP_W];
            shift_axis_tvalid = 1'b1;
            shift_axis_tlast = save_axis_tlast_reg;
            shift_axis_input_tready = flush_save;
        end else begin
            shift_axis_tdata = tdata_full[(OFFSET_W+1)'(AXIS_KEEP_W_INT-offset_reg)*AXIS_BYTE_SIZE +: AXIS_DATA_W];
            shift_axis_tkeep = tkeep_full[(OFFSET_W+1)'(AXIS_KEEP_W_INT-offset_reg) +: AXIS_KEEP_W];
            shift_axis_tvalid = s_axis_wr_data.tvalid;
            shift_axis_tlast = (s_axis_wr_data.tlast && ((s_axis_wr_data.tkeep & ({AXIS_KEEP_W_INT{1'b1}} << ((OFFSET_W+1)'(AXIS_KEEP_W_INT)-offset_reg))) == 0));
            shift_axis_input_tready = !(s_axis_wr_data.tlast && s_axis_wr_data.tready && s_axis_wr_data.tvalid);
        end
    end
end

always_comb begin
    state_next = STATE_IDLE;

    wr_desc_req_ready_next = 1'b0;

    wr_desc_sts_len_next = wr_desc_sts_len_reg;
    wr_desc_sts_tag_next = wr_desc_sts_tag_reg;
    wr_desc_sts_id_next = wr_desc_sts_id_reg;
    wr_desc_sts_dest_next = wr_desc_sts_dest_reg;
    wr_desc_sts_user_next = wr_desc_sts_user_reg;
    wr_desc_sts_error_next = wr_desc_sts_error_reg;
    wr_desc_sts_valid_next = 1'b0;

    s_axis_wr_data_tready_next = 1'b0;

    m_axi_awaddr_next = m_axi_awaddr_reg;
    m_axi_awlen_next = m_axi_awlen_reg;
    m_axi_awvalid_next = m_axi_awvalid_reg && !m_axi_wr.awready;
    m_axi_wdata_int = shift_axis_tdata;
    m_axi_wstrb_int = shift_axis_tkeep;
    m_axi_wlast_int = 1'b0;
    m_axi_wvalid_int = 1'b0;
    m_axi_bready_next = 1'b0;

    transfer_in_save = 1'b0;
    flush_save = 1'b0;
    status_fifo_we = 1'b0;

    cycle_size = (OFFSET_W+1)'(AXIS_KEEP_W_INT);

    addr_next = addr_reg;
    offset_next = offset_reg;
    strb_offset_mask_next = strb_offset_mask_reg;
    zero_offset_next = zero_offset_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    length_next = length_reg;
    op_count_next = op_count_reg;
    tr_count_next = tr_count_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    first_cycle_next = first_cycle_reg;
    input_last_cycle_next = input_last_cycle_reg;
    output_last_cycle_next = output_last_cycle_reg;
    last_transfer_next = last_transfer_reg;

    status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg;

    inc_active = 1'b0;
    dec_active = 1'b0;

    tag_next = tag_reg;
    axis_id_next = axis_id_reg;
    axis_dest_next = axis_dest_reg;
    axis_user_next = axis_user_reg;

    status_fifo_wr_len = length_reg;
    status_fifo_wr_tag = tag_reg;
    status_fifo_wr_id = axis_id_reg;
    status_fifo_wr_dest = axis_dest_reg;
    status_fifo_wr_user = axis_user_reg;
    status_fifo_wr_last = 1'b0;

    if (m_axi_wr.bready && m_axi_wr.bvalid && (m_axi_wr.bresp == AXI_RESP_SLVERR || m_axi_wr.bresp == AXI_RESP_DECERR)) begin
        bresp_next = m_axi_wr.bresp;
    end else begin
        bresp_next = bresp_reg;
    end

    case (state_reg)
        STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            flush_save = 1'b1;
            wr_desc_req_ready_next = enable && active_count_av_reg;

            if (UNALIGNED_EN) begin
                addr_next = wr_desc_req.req_dst_addr;
                offset_next = OFFSET_W'(wr_desc_req.req_dst_addr & OFFSET_MASK);
                strb_offset_mask_next = {AXI_STRB_W{1'b1}} << OFFSET_W'(wr_desc_req.req_dst_addr & OFFSET_MASK);
                zero_offset_next = OFFSET_W'(wr_desc_req.req_dst_addr & OFFSET_MASK) == 0;
                last_cycle_offset_next = offset_next + OFFSET_W'(wr_desc_req.req_len & OFFSET_MASK);
            end else begin
                addr_next = wr_desc_req.req_dst_addr & ADDR_MASK;
                offset_next = '0;
                strb_offset_mask_next = '1;
                zero_offset_next = 1'b1;
                last_cycle_offset_next = offset_next + OFFSET_W'(wr_desc_req.req_len & OFFSET_MASK);
            end
            tag_next = wr_desc_req.req_tag;
            op_count_next = wr_desc_req.req_len;
            first_cycle_next = 1'b1;
            length_next = 0;

            if (wr_desc_req.req_ready && wr_desc_req.req_valid) begin
                wr_desc_req_ready_next = 1'b0;
                state_next = STATE_START;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_START: begin
            // start state - initiate new AXI transfer
            if (op_count_reg <= LEN_W'(AXI_MAX_BURST_SIZE) - LEN_W'(addr_reg & OFFSET_MASK) || AXI_MAX_BURST_SIZE >= 4096) begin
                // packet smaller than max burst size
                if ((12'(addr_reg & 12'hfff) + 12'(op_count_reg & 12'hfff)) >> 12 != 0 || op_count_reg >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_count_next = 13'h1000 - 12'(addr_reg & 12'hfff);
                end else begin
                    // does not cross 4k boundary
                    tr_count_next = 13'(op_count_reg);
                end
            end else begin
                // packet larger than max burst size
                if ((12'(addr_reg & 12'hfff) + 12'(AXI_MAX_BURST_SIZE)) >> 12 != 0) begin
                    // crosses 4k boundary
                    tr_count_next = 13'h1000 - 12'(addr_reg & 12'hfff);
                end else begin
                    // does not cross 4k boundary
                    tr_count_next = 13'(AXI_MAX_BURST_SIZE) - 13'(addr_reg & OFFSET_MASK);
                end
            end

            input_cycle_count_next = CYCLE_COUNT_W'((tr_count_next - 13'd1) >> $clog2(AXIS_KEEP_W_INT));
            input_last_cycle_next = input_cycle_count_next == 0;
            if (UNALIGNED_EN) begin
                output_cycle_count_next = CYCLE_COUNT_W'((tr_count_next + 13'(addr_reg & OFFSET_MASK) - 13'd1) >> AXI_BURST_SIZE);
            end else begin
                output_cycle_count_next = CYCLE_COUNT_W'((tr_count_next - 13'd1) >> AXI_BURST_SIZE);
            end
            output_last_cycle_next = output_cycle_count_next == 0;
            last_transfer_next = LEN_W'(tr_count_next) == op_count_reg;
            input_active_next = 1'b1;

            if (UNALIGNED_EN) begin
                if (!first_cycle_reg && last_transfer_next) begin
                    if (offset_reg >= last_cycle_offset_reg && last_cycle_offset_reg > 0) begin
                        // last cycle will be served by stored partial cycle
                        input_active_next = input_cycle_count_next > 0;
                        input_cycle_count_next = input_cycle_count_next - 1;
                    end
                end
            end

            if (!m_axi_awvalid_reg && active_count_av_reg) begin
                m_axi_awaddr_next = addr_reg;
                m_axi_awlen_next = 8'(output_cycle_count_next);
                m_axi_awvalid_next = s_axis_wr_data.tvalid || !first_cycle_reg;

                if (m_axi_awvalid_next) begin
                    addr_next = addr_reg + AXI_ADDR_W'(tr_count_next);
                    op_count_next = op_count_reg - LEN_W'(tr_count_next);

                    s_axis_wr_data_tready_next = m_axi_wready_int && input_active_next;

                    inc_active = 1'b1;

                    state_next = STATE_WRITE;
                end else begin
                    state_next = STATE_START;
                end
            end else begin
                state_next = STATE_START;
            end
        end
        STATE_WRITE: begin
            s_axis_wr_data_tready_next = m_axi_wready_int && (last_transfer_reg || input_active_reg) && shift_axis_input_tready;

            if ((s_axis_wr_data.tready && shift_axis_tvalid) || (!input_active_reg && !last_transfer_reg) || !shift_axis_input_tready) begin
                if (s_axis_wr_data.tready && s_axis_wr_data.tvalid) begin
                    transfer_in_save = 1'b1;

                    axis_id_next = s_axis_wr_data.tid;
                    axis_dest_next = s_axis_wr_data.tdest;
                    axis_user_next = s_axis_wr_data.tuser;
                end

                // update counters
                if (first_cycle_reg) begin
                    length_next = length_reg + LEN_W'(AXIS_KEEP_W_INT - offset_reg);
                end else begin
                    length_next = length_reg + LEN_W'(AXIS_KEEP_W_INT);
                end
                if (input_active_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
                end
                input_last_cycle_next = input_cycle_count_next == 0;
                output_cycle_count_next = output_cycle_count_reg - 1;
                output_last_cycle_next = output_cycle_count_next == 0;
                first_cycle_next = 1'b0;
                strb_offset_mask_next = '1;

                m_axi_wdata_int = shift_axis_tdata;
                m_axi_wstrb_int = strb_offset_mask_reg;
                m_axi_wvalid_int = 1'b1;

                if (AXIS_LAST_EN && s_axis_wr_data.tlast) begin
                    // end of input frame
                    input_active_next = 1'b0;
                    s_axis_wr_data_tready_next = 1'b0;
                end

                if (AXIS_LAST_EN && shift_axis_tlast) begin
                    // end of data packet

                    cycle_size = (OFFSET_W+1)'(AXIS_KEEP_W_INT);
                    if (AXIS_KEEP_EN) begin
                        for (integer i = AXIS_KEEP_W_INT-1; i >= 0; i = i - 1) begin
                            if ((~shift_axis_tkeep & strb_offset_mask_reg & (1 << i)) != 0) begin
                                cycle_size = (OFFSET_W+1)'(i);
                            end
                        end
                    end

                    if (output_last_cycle_reg) begin
                        m_axi_wlast_int = 1'b1;

                        // no more data to transfer, finish operation
                        if (last_transfer_reg && last_cycle_offset_reg > 0) begin
                            if (AXIS_KEEP_EN && (shift_axis_tkeep & ~({AXI_STRB_W{1'b1}} >> ((OFFSET_W+1)'(AXI_STRB_W) - last_cycle_offset_reg))) == 0) begin
                                m_axi_wstrb_int = strb_offset_mask_reg & shift_axis_tkeep;
                                if (first_cycle_reg) begin
                                    length_next = length_reg + LEN_W'(cycle_size - offset_reg);
                                end else begin
                                    length_next = length_reg + LEN_W'(cycle_size);
                                end
                            end else begin
                                m_axi_wstrb_int = strb_offset_mask_reg & {AXI_STRB_W{1'b1}} >> ((OFFSET_W+1)'(AXI_STRB_W) - last_cycle_offset_reg);
                                if (first_cycle_reg) begin
                                    length_next = length_reg + LEN_W'(last_cycle_offset_reg - offset_reg);
                                end else begin
                                    length_next = length_reg + LEN_W'(last_cycle_offset_reg);
                                end
                            end
                        end else begin
                            if (AXIS_KEEP_EN) begin
                                m_axi_wstrb_int = strb_offset_mask_reg & shift_axis_tkeep;
                                if (first_cycle_reg) begin
                                    length_next = length_reg + LEN_W'(cycle_size - offset_reg);
                                end else begin
                                    length_next = length_reg + LEN_W'(cycle_size);
                                end
                            end
                        end

                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b1;

                        s_axis_wr_data_tready_next = 1'b0;
                        wr_desc_req_ready_next = enable && active_count_av_reg;
                        state_next = STATE_IDLE;
                    end else begin
                        // more cycles left in burst, finish burst
                        if (AXIS_KEEP_EN) begin
                            m_axi_wstrb_int = strb_offset_mask_reg & shift_axis_tkeep;
                            if (first_cycle_reg) begin
                                length_next = length_reg + LEN_W'(cycle_size - offset_reg);
                            end else begin
                                length_next = length_reg + LEN_W'(cycle_size);
                            end
                        end

                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b1;

                        s_axis_wr_data_tready_next = 1'b0;
                        state_next = STATE_FINISH_BURST;
                    end

                end else if (output_last_cycle_reg) begin
                    m_axi_wlast_int = 1'b1;

                    if (op_count_reg > 0) begin
                        // current AXI transfer complete, but there is more data to transfer
                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b0;

                        s_axis_wr_data_tready_next = 1'b0;
                        state_next = STATE_START;
                    end else begin
                        // no more data to transfer, finish operation
                        if (last_cycle_offset_reg > 0) begin
                            m_axi_wstrb_int = strb_offset_mask_reg & {AXI_STRB_W{1'b1}} >> ((OFFSET_W+1)'(AXI_STRB_W) - last_cycle_offset_reg);
                            if (first_cycle_reg) begin
                                length_next = length_reg + LEN_W'(last_cycle_offset_reg - offset_reg);
                            end else begin
                                length_next = length_reg + LEN_W'(last_cycle_offset_reg);
                            end
                        end

                        // enqueue status FIFO entry for write completion
                        status_fifo_we = 1'b1;
                        status_fifo_wr_len = length_next;
                        status_fifo_wr_tag = tag_reg;
                        status_fifo_wr_id = axis_id_next;
                        status_fifo_wr_dest = axis_dest_next;
                        status_fifo_wr_user = axis_user_next;
                        status_fifo_wr_last = 1'b1;

                        if (AXIS_LAST_EN) begin
                            // not at the end of packet; drop remainder
                            s_axis_wr_data_tready_next = shift_axis_input_tready;
                            state_next = STATE_DROP_DATA;
                        end else begin
                            // no framing; return to idle
                            s_axis_wr_data_tready_next = 1'b0;
                            wr_desc_req_ready_next = enable && active_count_av_reg;
                            state_next = STATE_IDLE;
                        end
                    end
                end else begin
                    s_axis_wr_data_tready_next = m_axi_wready_int && (last_transfer_reg || input_active_next) && shift_axis_input_tready;
                    state_next = STATE_WRITE;
                end
            end else begin
                state_next = STATE_WRITE;
            end
        end
        STATE_FINISH_BURST: begin
            // finish current AXI burst

            if (m_axi_wready_int) begin
                // update counters
                if (input_active_reg) begin
                    input_cycle_count_next = input_cycle_count_reg - 1;
                    input_active_next = input_cycle_count_reg > 0;
                end
                input_last_cycle_next = input_cycle_count_next == 0;
                output_cycle_count_next = output_cycle_count_reg - 1;
                output_last_cycle_next = output_cycle_count_next == 0;

                m_axi_wdata_int = '0;
                m_axi_wstrb_int = '0;
                m_axi_wvalid_int = 1'b1;

                if (output_last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    m_axi_wlast_int = 1'b1;

                    s_axis_wr_data_tready_next = 1'b0;
                    wr_desc_req_ready_next = enable && active_count_av_reg;
                    state_next = STATE_IDLE;
                end else begin
                    // more cycles in AXI transfer
                    state_next = STATE_FINISH_BURST;
                end
            end else begin
                state_next = STATE_FINISH_BURST;
            end
        end
        STATE_DROP_DATA: begin
            // drop excess AXI stream data
            s_axis_wr_data_tready_next = shift_axis_input_tready;

            if (shift_axis_tvalid) begin
                if (s_axis_wr_data.tready && s_axis_wr_data.tvalid) begin
                    transfer_in_save = 1'b1;
                end

                if (shift_axis_tlast) begin
                    s_axis_wr_data_tready_next = 1'b0;
                    wr_desc_req_ready_next = enable && active_count_av_reg;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DROP_DATA;
                end
            end else begin
                state_next = STATE_DROP_DATA;
            end
        end
        default: begin
            // invalid state
            state_next = STATE_IDLE;
        end
    endcase

    if (status_fifo_rd_ptr_reg != status_fifo_wr_ptr_reg) begin
        // status FIFO not empty
        if (m_axi_wr.bready && m_axi_wr.bvalid) begin
            // got write completion, pop and return status
            wr_desc_sts_len_next = status_fifo_len[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
            wr_desc_sts_tag_next = status_fifo_tag[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
            wr_desc_sts_id_next = status_fifo_id[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
            wr_desc_sts_dest_next = status_fifo_dest[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
            wr_desc_sts_user_next = status_fifo_user[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
            if (bresp_next == AXI_RESP_SLVERR) begin
                wr_desc_sts_error_next = DMA_ERROR_AXI_WR_SLVERR;
            end else if (bresp_next == AXI_RESP_DECERR) begin
                wr_desc_sts_error_next = DMA_ERROR_AXI_WR_DECERR;
            end else begin
                wr_desc_sts_error_next = DMA_ERROR_NONE;
            end
            wr_desc_sts_valid_next = status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]];
            status_fifo_rd_ptr_next = status_fifo_rd_ptr_reg + 1;
            m_axi_bready_next = 1'b0;

            if (status_fifo_last[status_fifo_rd_ptr_reg[STATUS_FIFO_AW-1:0]]) begin
                bresp_next = AXI_RESP_OKAY;
            end

            dec_active = 1'b1;
        end else begin
            // wait for write completion
            m_axi_bready_next = 1'b1;
        end
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    wr_desc_req_ready_reg <= wr_desc_req_ready_next;

    wr_desc_sts_len_reg <= wr_desc_sts_len_next;
    wr_desc_sts_tag_reg <= wr_desc_sts_tag_next;
    wr_desc_sts_id_reg <= wr_desc_sts_id_next;
    wr_desc_sts_dest_reg <= wr_desc_sts_dest_next;
    wr_desc_sts_user_reg <= wr_desc_sts_user_next;
    wr_desc_sts_error_reg <= wr_desc_sts_error_next;
    wr_desc_sts_valid_reg <= wr_desc_sts_valid_next;

    s_axis_wr_data_tready_reg <= s_axis_wr_data_tready_next;

    m_axi_awaddr_reg <= m_axi_awaddr_next;
    m_axi_awlen_reg <= m_axi_awlen_next;
    m_axi_awvalid_reg <= m_axi_awvalid_next;
    m_axi_bready_reg <= m_axi_bready_next;

    addr_reg <= addr_next;
    offset_reg <= offset_next;
    strb_offset_mask_reg <= strb_offset_mask_next;
    zero_offset_reg <= zero_offset_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    length_reg <= length_next;
    op_count_reg <= op_count_next;
    tr_count_reg <= tr_count_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    first_cycle_reg <= first_cycle_next;
    input_last_cycle_reg <= input_last_cycle_next;
    output_last_cycle_reg <= output_last_cycle_next;
    last_transfer_reg <= last_transfer_next;
    bresp_reg <= bresp_next;

    tag_reg <= tag_next;
    axis_id_reg <= axis_id_next;
    axis_dest_reg <= axis_dest_next;
    axis_user_reg <= axis_user_next;

    // datapath
    if (flush_save) begin
        save_axis_tkeep_reg <= '0;
        save_axis_tlast_reg <= 1'b0;
        shift_axis_extra_cycle_reg <= 1'b0;
    end else if (transfer_in_save) begin
        save_axis_tdata_reg <= s_axis_wr_data.tdata;
        save_axis_tkeep_reg <= AXIS_KEEP_EN ? s_axis_wr_data.tkeep : '1;
        save_axis_tlast_reg <= s_axis_wr_data.tlast;
        shift_axis_extra_cycle_reg <= s_axis_wr_data.tlast & ((s_axis_wr_data.tkeep >> ((OFFSET_W+1)'(AXIS_KEEP_W_INT) - offset_reg)) != 0);
    end

    if (status_fifo_we) begin
        status_fifo_len[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_len;
        status_fifo_tag[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_tag;
        status_fifo_id[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_id;
        status_fifo_dest[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_dest;
        status_fifo_user[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_user;
        status_fifo_last[status_fifo_wr_ptr_reg[STATUS_FIFO_AW-1:0]] <= status_fifo_wr_last;
        status_fifo_wr_ptr_reg <= status_fifo_wr_ptr_reg + 1;
    end
    status_fifo_rd_ptr_reg <= status_fifo_rd_ptr_next;

    if (active_count_reg < 2**STATUS_FIFO_AW && inc_active && !dec_active) begin
        active_count_reg <= active_count_reg + 1;
        active_count_av_reg <= active_count_reg < (2**STATUS_FIFO_AW-1);
    end else if (active_count_reg > 0 && !inc_active && dec_active) begin
        active_count_reg <= active_count_reg - 1;
        active_count_av_reg <= 1'b1;
    end else begin
        active_count_av_reg <= active_count_reg < 2**STATUS_FIFO_AW;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        wr_desc_req_ready_reg <= 1'b0;
        wr_desc_sts_valid_reg <= 1'b0;

        s_axis_wr_data_tready_reg <= 1'b0;

        m_axi_awvalid_reg <= 1'b0;
        m_axi_bready_reg <= 1'b0;

        bresp_reg <= AXI_RESP_OKAY;

        save_axis_tlast_reg <= 1'b0;
        shift_axis_extra_cycle_reg <= 1'b0;

        status_fifo_wr_ptr_reg <= 0;
        status_fifo_rd_ptr_reg <= 0;

        active_count_reg <= 0;
        active_count_av_reg <= 1'b1;
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
