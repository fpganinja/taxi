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
module taxi_axi_dma_rd #
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
        * DMA read descriptor
        */
    taxi_dma_desc_if.req_snk  rd_desc_req,
    taxi_dma_desc_if.sts_src  rd_desc_sts,

    /*
     * AXI stream read data output
     */
    taxi_axis_if.src          m_axis_rd_data,

    /*
     * AXI4 master interface
     */
    taxi_axi_if.rd_mst        m_axi_rd,

    /*
     * Configuration
     */
    input  wire logic         enable
);

// extract parameters
localparam AXI_DATA_W = m_axi_rd.DATA_W;
localparam AXI_ADDR_W = m_axi_rd.ADDR_W;
localparam AXI_STRB_W = m_axi_rd.STRB_W;
localparam AXI_ID_W = m_axi_rd.ID_W;
localparam AXI_MAX_BURST_LEN_INT = AXI_MAX_BURST_LEN < m_axi_rd.MAX_BURST_LEN ? AXI_MAX_BURST_LEN : m_axi_rd.MAX_BURST_LEN;

localparam LEN_W = rd_desc_req.LEN_W;
localparam TAG_W = rd_desc_req.TAG_W;

localparam AXIS_DATA_W = m_axis_rd_data.DATA_W;
localparam AXIS_KEEP_EN = m_axis_rd_data.KEEP_EN;
localparam AXIS_KEEP_W = m_axis_rd_data.KEEP_W;
localparam AXIS_LAST_EN = m_axis_rd_data.LAST_EN;
localparam AXIS_ID_EN = m_axis_rd_data.ID_EN;
localparam AXIS_ID_W = m_axis_rd_data.ID_W;
localparam AXIS_DEST_EN = m_axis_rd_data.DEST_EN;
localparam AXIS_DEST_W = m_axis_rd_data.DEST_W;
localparam AXIS_USER_EN = m_axis_rd_data.USER_EN;
localparam AXIS_USER_W = m_axis_rd_data.USER_W;

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
// Count the entire descriptor, including an extra input beat for an unaligned address.
localparam CYCLE_COUNT_W = LEN_W - AXI_BURST_SIZE + 1;

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

if (rd_desc_req.SRC_ADDR_W < AXI_ADDR_W)
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
    AXI_STATE_IDLE,
    AXI_STATE_START
} axi_state_t;

axi_state_t axi_state_reg = AXI_STATE_IDLE, axi_state_next;

typedef enum logic [0:0] {
    AXIS_STATE_IDLE,
    AXIS_STATE_READ
} axis_state_t;

axis_state_t axis_state_reg = AXIS_STATE_IDLE, axis_state_next;

// datapath control signals
logic transfer_in_save;
logic axis_cmd_ready;

logic [AXI_ADDR_W-1:0] addr_reg = '0, addr_next;
logic [LEN_W-1:0] op_count_reg = '0, op_count_next;
logic [12:0] tr_count_reg = '0, tr_count_next;

logic [OFFSET_W-1:0] axis_cmd_offset_reg = '0, axis_cmd_offset_next;
logic [OFFSET_W-1:0] axis_cmd_last_cycle_offset_reg = '0, axis_cmd_last_cycle_offset_next;
logic [CYCLE_COUNT_W-1:0] axis_cmd_input_cycle_count_reg = '0, axis_cmd_input_cycle_count_next;
logic [CYCLE_COUNT_W-1:0] axis_cmd_output_cycle_count_reg = '0, axis_cmd_output_cycle_count_next;
logic axis_cmd_bubble_cycle_reg = 1'b0, axis_cmd_bubble_cycle_next;
logic [TAG_W-1:0] axis_cmd_tag_reg = '0, axis_cmd_tag_next;
logic [AXIS_ID_W-1:0] axis_cmd_axis_id_reg = '0, axis_cmd_axis_id_next;
logic [AXIS_DEST_W-1:0] axis_cmd_axis_dest_reg = '0, axis_cmd_axis_dest_next;
logic [AXIS_USER_W-1:0] axis_cmd_axis_user_reg = '0, axis_cmd_axis_user_next;
logic axis_cmd_valid_reg = 1'b0, axis_cmd_valid_next;

logic [OFFSET_W-1:0] offset_reg = '0, offset_next;
logic [OFFSET_W-1:0] last_cycle_offset_reg = '0, last_cycle_offset_next;
logic [CYCLE_COUNT_W-1:0] input_cycle_count_reg = '0, input_cycle_count_next;
logic [CYCLE_COUNT_W-1:0] output_cycle_count_reg = '0, output_cycle_count_next;
logic input_active_reg = 1'b0, input_active_next;
logic output_active_reg = 1'b0, output_active_next;
logic bubble_cycle_reg = 1'b0, bubble_cycle_next;
logic first_cycle_reg = 1'b0, first_cycle_next;
logic output_last_cycle_reg = 1'b0, output_last_cycle_next;
logic [1:0] rresp_reg = AXI_RESP_OKAY, rresp_next;

logic [TAG_W-1:0] tag_reg = '0, tag_next;
logic [AXIS_ID_W-1:0] axis_id_reg = '0, axis_id_next;
logic [AXIS_DEST_W-1:0] axis_dest_reg = '0, axis_dest_next;
logic [AXIS_USER_W-1:0] axis_user_reg = '0, axis_user_next;

logic rd_desc_req_ready_reg = 1'b0, rd_desc_req_ready_next;

logic [TAG_W-1:0] rd_desc_sts_tag_reg = '0, rd_desc_sts_tag_next;
logic [3:0] rd_desc_sts_error_reg = 4'd0, rd_desc_sts_error_next;
logic rd_desc_sts_valid_reg = 1'b0, rd_desc_sts_valid_next;

logic [AXI_ADDR_W-1:0] m_axi_araddr_reg = '0, m_axi_araddr_next;
logic [7:0] m_axi_arlen_reg = 8'd0, m_axi_arlen_next;
logic m_axi_arvalid_reg = 1'b0, m_axi_arvalid_next;
logic m_axi_rready_reg = 1'b0, m_axi_rready_next;

logic [AXI_DATA_W-1:0] save_axi_rdata_reg = '0;

wire [AXI_DATA_W*2-1:0] axi_rdata_full = {m_axi_rd.rdata, save_axi_rdata_reg};
wire [AXI_DATA_W-1:0] shift_axi_rdata = axi_rdata_full[(OFFSET_W+1)'(AXI_STRB_W-offset_reg)*AXI_BYTE_SIZE +: AXI_DATA_W];

// internal datapath
logic  [AXIS_DATA_W-1:0] m_axis_rd_data_tdata_int;
logic  [AXIS_KEEP_W-1:0] m_axis_rd_data_tkeep_int;
logic                    m_axis_rd_data_tvalid_int;
wire                     m_axis_rd_data_tready_int;
logic                    m_axis_rd_data_tlast_int;
logic  [AXIS_ID_W-1:0]   m_axis_rd_data_tid_int;
logic  [AXIS_DEST_W-1:0] m_axis_rd_data_tdest_int;
logic  [AXIS_USER_W-1:0] m_axis_rd_data_tuser_int;

assign rd_desc_req.req_ready = rd_desc_req_ready_reg;

assign rd_desc_sts.sts_len = '0;
assign rd_desc_sts.sts_tag = rd_desc_sts_tag_reg;
assign rd_desc_sts.sts_id = '0;
assign rd_desc_sts.sts_dest = '0;
assign rd_desc_sts.sts_user = '0;
assign rd_desc_sts.sts_error = rd_desc_sts_error_reg;
assign rd_desc_sts.sts_valid = rd_desc_sts_valid_reg;

assign m_axi_rd.arid = '0;
assign m_axi_rd.araddr = m_axi_araddr_reg;
assign m_axi_rd.arlen = m_axi_arlen_reg;
assign m_axi_rd.arsize = 3'(AXI_BURST_SIZE);
assign m_axi_rd.arburst = 2'b01;
assign m_axi_rd.arlock = 1'b0;
assign m_axi_rd.arcache = 4'b0011;
assign m_axi_rd.arprot = 3'b010;
assign m_axi_rd.arvalid = m_axi_arvalid_reg;
assign m_axi_rd.rready = m_axi_rready_reg;

always_comb begin
    axi_state_next = AXI_STATE_IDLE;

    rd_desc_req_ready_next = 1'b0;

    m_axi_araddr_next = m_axi_araddr_reg;
    m_axi_arlen_next = m_axi_arlen_reg;
    m_axi_arvalid_next = m_axi_arvalid_reg && !m_axi_rd.arready;

    addr_next = addr_reg;
    op_count_next = op_count_reg;
    tr_count_next = tr_count_reg;

    axis_cmd_offset_next = axis_cmd_offset_reg;
    axis_cmd_last_cycle_offset_next = axis_cmd_last_cycle_offset_reg;
    axis_cmd_input_cycle_count_next = axis_cmd_input_cycle_count_reg;
    axis_cmd_output_cycle_count_next = axis_cmd_output_cycle_count_reg;
    axis_cmd_bubble_cycle_next = axis_cmd_bubble_cycle_reg;
    axis_cmd_tag_next = axis_cmd_tag_reg;
    axis_cmd_axis_id_next = axis_cmd_axis_id_reg;
    axis_cmd_axis_dest_next = axis_cmd_axis_dest_reg;
    axis_cmd_axis_user_next = axis_cmd_axis_user_reg;
    axis_cmd_valid_next = axis_cmd_valid_reg && !axis_cmd_ready;

    case (axi_state_reg)
        AXI_STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            rd_desc_req_ready_next = !axis_cmd_valid_reg && enable;

            if (rd_desc_req.req_ready && rd_desc_req.req_valid) begin
                if (UNALIGNED_EN) begin
                    addr_next = rd_desc_req.req_src_addr;
                    axis_cmd_offset_next = AXI_STRB_W > 1 ? OFFSET_W'(AXI_STRB_W) - OFFSET_W'(rd_desc_req.req_src_addr & OFFSET_MASK) : '0;
                    axis_cmd_bubble_cycle_next = axis_cmd_offset_next > 0;
                    axis_cmd_last_cycle_offset_next = OFFSET_W'(rd_desc_req.req_len & OFFSET_MASK);
                end else begin
                    addr_next = rd_desc_req.req_src_addr & ADDR_MASK;
                    axis_cmd_offset_next = '0;
                    axis_cmd_bubble_cycle_next = 1'b0;
                    axis_cmd_last_cycle_offset_next = OFFSET_W'(rd_desc_req.req_len & OFFSET_MASK);
                end
                axis_cmd_tag_next = rd_desc_req.req_tag;
                op_count_next = rd_desc_req.req_len;

                axis_cmd_axis_id_next = rd_desc_req.req_id;
                axis_cmd_axis_dest_next = rd_desc_req.req_dest;
                axis_cmd_axis_user_next = rd_desc_req.req_user;

                if (UNALIGNED_EN) begin
                    axis_cmd_input_cycle_count_next = CYCLE_COUNT_W'(((LEN_W+1)'(op_count_next) + (LEN_W+1)'(rd_desc_req.req_src_addr & OFFSET_MASK) - (LEN_W+1)'(1)) >> AXI_BURST_SIZE);
                end else begin
                    axis_cmd_input_cycle_count_next = CYCLE_COUNT_W'((op_count_next - LEN_W'(1)) >> AXI_BURST_SIZE);
                end
                axis_cmd_output_cycle_count_next = CYCLE_COUNT_W'((op_count_next - LEN_W'(1)) >> AXI_BURST_SIZE);

                axis_cmd_valid_next = 1'b1;

                rd_desc_req_ready_next = 1'b0;
                axi_state_next = AXI_STATE_START;
            end else begin
                axi_state_next = AXI_STATE_IDLE;
            end
        end
        AXI_STATE_START: begin
            // start state - initiate new AXI transfer
            if (!m_axi_rd.arvalid) begin
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

                m_axi_araddr_next = addr_reg;
                if (UNALIGNED_EN) begin
                    m_axi_arlen_next = 8'((tr_count_next + 13'(addr_reg & OFFSET_MASK) - 13'd1) >> AXI_BURST_SIZE);
                end else begin
                    m_axi_arlen_next = 8'((tr_count_next - 13'd1) >> AXI_BURST_SIZE);
                end
                m_axi_arvalid_next = 1'b1;

                addr_next = addr_reg + AXI_ADDR_W'(tr_count_next);
                op_count_next = op_count_reg - LEN_W'(tr_count_next);

                if (op_count_next > 0) begin
                    axi_state_next = AXI_STATE_START;
                end else begin
                    rd_desc_req_ready_next = !axis_cmd_valid_reg && enable;
                    axi_state_next = AXI_STATE_IDLE;
                end
            end else begin
                axi_state_next = AXI_STATE_START;
            end
        end
    endcase
end

always_comb begin
    axis_state_next = AXIS_STATE_IDLE;

    rd_desc_sts_tag_next = rd_desc_sts_tag_reg;
    rd_desc_sts_error_next = rd_desc_sts_error_reg;
    rd_desc_sts_valid_next = 1'b0;

    m_axis_rd_data_tdata_int = shift_axi_rdata;
    m_axis_rd_data_tkeep_int = '1;
    m_axis_rd_data_tlast_int = 1'b0;
    m_axis_rd_data_tvalid_int = 1'b0;
    m_axis_rd_data_tid_int = axis_id_reg;
    m_axis_rd_data_tdest_int = axis_dest_reg;
    m_axis_rd_data_tuser_int = axis_user_reg;

    m_axi_rready_next = 1'b0;

    transfer_in_save = 1'b0;
    axis_cmd_ready = 1'b0;

    offset_next = offset_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    input_cycle_count_next = input_cycle_count_reg;
    output_cycle_count_next = output_cycle_count_reg;
    input_active_next = input_active_reg;
    output_active_next = output_active_reg;
    bubble_cycle_next = bubble_cycle_reg;
    first_cycle_next = first_cycle_reg;
    output_last_cycle_next = output_last_cycle_reg;

    tag_next = tag_reg;
    axis_id_next = axis_id_reg;
    axis_dest_next = axis_dest_reg;
    axis_user_next = axis_user_reg;

    if (m_axi_rd.rready && m_axi_rd.rvalid && (m_axi_rd.rresp == AXI_RESP_SLVERR || m_axi_rd.rresp == AXI_RESP_DECERR)) begin
        rresp_next = m_axi_rd.rresp;
    end else begin
        rresp_next = rresp_reg;
    end

    case (axis_state_reg)
        AXIS_STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            m_axi_rready_next = 1'b0;

            // store transfer parameters
            if (UNALIGNED_EN) begin
                offset_next = axis_cmd_offset_reg;
            end else begin
                offset_next = 0;
            end
            last_cycle_offset_next = axis_cmd_last_cycle_offset_reg;
            input_cycle_count_next = axis_cmd_input_cycle_count_reg;
            output_cycle_count_next = axis_cmd_output_cycle_count_reg;
            bubble_cycle_next = axis_cmd_bubble_cycle_reg;
            tag_next = axis_cmd_tag_reg;
            axis_id_next = axis_cmd_axis_id_reg;
            axis_dest_next = axis_cmd_axis_dest_reg;
            axis_user_next = axis_cmd_axis_user_reg;

            output_last_cycle_next = output_cycle_count_next == 0;
            input_active_next = 1'b1;
            output_active_next = 1'b1;
            first_cycle_next = 1'b1;

            if (axis_cmd_valid_reg) begin
                axis_cmd_ready = 1'b1;
                m_axi_rready_next = m_axis_rd_data_tready_int;
                axis_state_next = AXIS_STATE_READ;
            end
        end
        AXIS_STATE_READ: begin
            // handle AXI read data
            m_axi_rready_next = m_axis_rd_data_tready_int && input_active_reg;

            if ((m_axi_rd.rready && m_axi_rd.rvalid) || !input_active_reg) begin
                // transfer in AXI read data
                transfer_in_save = m_axi_rd.rready && m_axi_rd.rvalid;

                if (UNALIGNED_EN && first_cycle_reg && bubble_cycle_reg) begin
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg > 0;
                    end
                    bubble_cycle_next = 1'b0;
                    first_cycle_next = 1'b0;

                    m_axi_rready_next = m_axis_rd_data_tready_int && input_active_next;
                    axis_state_next = AXIS_STATE_READ;
                end else begin
                    // update counters
                    if (input_active_reg) begin
                        input_cycle_count_next = input_cycle_count_reg - 1;
                        input_active_next = input_cycle_count_reg > 0;
                    end
                    if (output_active_reg) begin
                        output_cycle_count_next = output_cycle_count_reg - 1;
                        output_active_next = output_cycle_count_reg > 0;
                    end
                    output_last_cycle_next = output_cycle_count_next == 0;
                    bubble_cycle_next = 1'b0;
                    first_cycle_next = 1'b0;

                    // pass through read data
                    m_axis_rd_data_tdata_int = shift_axi_rdata;
                    m_axis_rd_data_tkeep_int = '1;
                    m_axis_rd_data_tvalid_int = 1'b1;

                    if (output_last_cycle_reg) begin
                        // no more data to transfer, finish operation
                        if (last_cycle_offset_reg > 0) begin
                            m_axis_rd_data_tkeep_int = {AXIS_KEEP_W_INT{1'b1}} >> ((OFFSET_W+1)'(AXIS_KEEP_W_INT) - last_cycle_offset_reg);
                        end
                        m_axis_rd_data_tlast_int = 1'b1;

                        rd_desc_sts_tag_next = tag_reg;
                        if (rresp_next == AXI_RESP_SLVERR) begin
                            rd_desc_sts_error_next = DMA_ERROR_AXI_RD_SLVERR;
                        end else if (rresp_next == AXI_RESP_DECERR) begin
                            rd_desc_sts_error_next = DMA_ERROR_AXI_RD_DECERR;
                        end else begin
                            rd_desc_sts_error_next = DMA_ERROR_NONE;
                        end
                        rd_desc_sts_valid_next = 1'b1;

                        rresp_next = AXI_RESP_OKAY;

                        m_axi_rready_next = 1'b0;
                        axis_state_next = AXIS_STATE_IDLE;
                    end else begin
                        // more cycles in AXI transfer
                        m_axi_rready_next = m_axis_rd_data_tready_int && input_active_next;
                        axis_state_next = AXIS_STATE_READ;
                    end
                end
            end else begin
                axis_state_next = AXIS_STATE_READ;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    axi_state_reg <= axi_state_next;
    axis_state_reg <= axis_state_next;

    rd_desc_req_ready_reg <= rd_desc_req_ready_next;

    rd_desc_sts_tag_reg <= rd_desc_sts_tag_next;
    rd_desc_sts_error_reg <= rd_desc_sts_error_next;
    rd_desc_sts_valid_reg <= rd_desc_sts_valid_next;

    m_axi_araddr_reg <= m_axi_araddr_next;
    m_axi_arlen_reg <= m_axi_arlen_next;
    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

    addr_reg <= addr_next;
    op_count_reg <= op_count_next;
    tr_count_reg <= tr_count_next;

    axis_cmd_offset_reg <= axis_cmd_offset_next;
    axis_cmd_last_cycle_offset_reg <= axis_cmd_last_cycle_offset_next;
    axis_cmd_input_cycle_count_reg <= axis_cmd_input_cycle_count_next;
    axis_cmd_output_cycle_count_reg <= axis_cmd_output_cycle_count_next;
    axis_cmd_bubble_cycle_reg <= axis_cmd_bubble_cycle_next;
    axis_cmd_tag_reg <= axis_cmd_tag_next;
    axis_cmd_axis_id_reg <= axis_cmd_axis_id_next;
    axis_cmd_axis_dest_reg <= axis_cmd_axis_dest_next;
    axis_cmd_axis_user_reg <= axis_cmd_axis_user_next;
    axis_cmd_valid_reg <= axis_cmd_valid_next;

    offset_reg <= offset_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    input_cycle_count_reg <= input_cycle_count_next;
    output_cycle_count_reg <= output_cycle_count_next;
    input_active_reg <= input_active_next;
    output_active_reg <= output_active_next;
    bubble_cycle_reg <= bubble_cycle_next;
    first_cycle_reg <= first_cycle_next;
    output_last_cycle_reg <= output_last_cycle_next;
    rresp_reg <= rresp_next;

    tag_reg <= tag_next;
    axis_id_reg <= axis_id_next;
    axis_dest_reg <= axis_dest_next;
    axis_user_reg <= axis_user_next;

    if (transfer_in_save) begin
        save_axi_rdata_reg <= m_axi_rd.rdata;
    end

    if (rst) begin
        axi_state_reg <= AXI_STATE_IDLE;
        axis_state_reg <= AXIS_STATE_IDLE;

        axis_cmd_valid_reg <= 1'b0;

        rd_desc_req_ready_reg <= 1'b0;

        rd_desc_sts_valid_reg <= 1'b0;
        m_axi_arvalid_reg <= 1'b0;
        m_axi_rready_reg <= 1'b0;

        rresp_reg <= AXI_RESP_OKAY;
    end
end

// output datapath logic
logic [AXIS_DATA_W-1:0] m_axis_rd_data_tdata_reg  = '0;
logic [AXIS_KEEP_W-1:0] m_axis_rd_data_tkeep_reg  = '0;
logic                   m_axis_rd_data_tvalid_reg = 1'b0;
logic                   m_axis_rd_data_tlast_reg  = 1'b0;
logic [AXIS_ID_W-1:0]   m_axis_rd_data_tid_reg    = '0;
logic [AXIS_DEST_W-1:0] m_axis_rd_data_tdest_reg  = '0;
logic [AXIS_USER_W-1:0] m_axis_rd_data_tuser_reg  = '0;

logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_wr_ptr_reg = '0;
logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_rd_ptr_reg = '0;
logic out_fifo_half_full_reg = 1'b0;

wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_AW{1'b0}}});
wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXIS_DATA_W-1:0] out_fifo_tdata[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXIS_KEEP_W-1:0] out_fifo_tkeep[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic                   out_fifo_tlast[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXIS_ID_W-1:0]   out_fifo_tid[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXIS_DEST_W-1:0] out_fifo_tdest[2**OUTPUT_FIFO_AW];
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [AXIS_USER_W-1:0] out_fifo_tuser[2**OUTPUT_FIFO_AW];

assign m_axis_rd_data_tready_int = !out_fifo_half_full_reg;

assign m_axis_rd_data.tdata  = m_axis_rd_data_tdata_reg;
assign m_axis_rd_data.tkeep  = AXIS_KEEP_EN ? m_axis_rd_data_tkeep_reg : '1;
assign m_axis_rd_data.tstrb  = m_axis_rd_data.tkeep;
assign m_axis_rd_data.tvalid = m_axis_rd_data_tvalid_reg;
assign m_axis_rd_data.tlast  = AXIS_LAST_EN ? m_axis_rd_data_tlast_reg : 1'b1;
assign m_axis_rd_data.tid    = AXIS_ID_EN   ? m_axis_rd_data_tid_reg   : '0;
assign m_axis_rd_data.tdest  = AXIS_DEST_EN ? m_axis_rd_data_tdest_reg : '0;
assign m_axis_rd_data.tuser  = AXIS_USER_EN ? m_axis_rd_data_tuser_reg : '0;

always_ff @(posedge clk) begin
    m_axis_rd_data_tvalid_reg <= m_axis_rd_data_tvalid_reg && !m_axis_rd_data.tready;

    out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_AW-1);

    if (!out_fifo_full && m_axis_rd_data_tvalid_int) begin
        out_fifo_tdata[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rd_data_tdata_int;
        out_fifo_tkeep[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rd_data_tkeep_int;
        out_fifo_tlast[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rd_data_tlast_int;
        out_fifo_tid[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rd_data_tid_int;
        out_fifo_tdest[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rd_data_tdest_int;
        out_fifo_tuser[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= m_axis_rd_data_tuser_int;
        out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
    end

    if (!out_fifo_empty && (!m_axis_rd_data_tvalid_reg || m_axis_rd_data.tready)) begin
        m_axis_rd_data_tdata_reg <= out_fifo_tdata[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rd_data_tkeep_reg <= out_fifo_tkeep[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rd_data_tvalid_reg <= 1'b1;
        m_axis_rd_data_tlast_reg <= out_fifo_tlast[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rd_data_tid_reg <= out_fifo_tid[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rd_data_tdest_reg <= out_fifo_tdest[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        m_axis_rd_data_tuser_reg <= out_fifo_tuser[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
        out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
    end

    if (rst) begin
        out_fifo_wr_ptr_reg <= '0;
        out_fifo_rd_ptr_reg <= '0;
        m_axis_rd_data_tvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
