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
 * AXI stream source DMA client
 */
module taxi_dma_client_axis_source
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Descriptor
     */
    taxi_dma_desc_if.req_snk  desc_req,
    taxi_dma_desc_if.sts_src  desc_sts,

    /*
     * AXI stream read data output
     */
    taxi_axis_if.src          m_axis_rd_data,

    /*
     * RAM interface
     */
    taxi_dma_ram_if.rd_mst    dma_ram_rd,

    /*
     * Configuration
     */
    input  wire logic         enable
);

// TODO cleanup
// verilator lint_off WIDTHEXPAND
// verilator lint_off WIDTHTRUNC

// extract parameters
localparam RAM_SEGS = dma_ram_rd.SEGS;
localparam RAM_SEG_ADDR_W = dma_ram_rd.SEG_ADDR_W;
localparam RAM_SEG_DATA_W = dma_ram_rd.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_rd.SEG_BE_W;

localparam LEN_W = desc_req.LEN_W;
localparam TAG_W = desc_req.TAG_W;

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

localparam RAM_ADDR_W = RAM_SEG_ADDR_W+$clog2(RAM_SEGS*RAM_SEG_BE_W);
localparam RAM_BYTE_LANES = RAM_SEG_BE_W;
localparam RAM_BYTE_SIZE = RAM_SEG_DATA_W/RAM_BYTE_LANES;

localparam AXIS_KEEP_W_INT = AXIS_KEEP_EN ? AXIS_KEEP_W : 1;
localparam AXIS_BYTE_LANES = AXIS_KEEP_W_INT;
localparam AXIS_BYTE_SIZE = AXIS_DATA_W/AXIS_BYTE_LANES;

localparam PART_COUNT = RAM_SEGS*RAM_SEG_BE_W / AXIS_KEEP_W_INT;
localparam PART_COUNT_W = PART_COUNT > 1 ? $clog2(PART_COUNT) : 1;
localparam PART_OFFSET_W = AXIS_KEEP_W_INT > 1 ? $clog2(AXIS_KEEP_W_INT) : 1;
localparam PARTS_PER_SEG = (RAM_SEG_BE_W + AXIS_KEEP_W_INT - 1) / AXIS_KEEP_W_INT;
localparam SEGS_PER_PART = (AXIS_KEEP_W_INT + RAM_SEG_BE_W - 1) / RAM_SEG_BE_W;

localparam OFFSET_W = AXIS_KEEP_W_INT > 1 ? $clog2(AXIS_KEEP_W_INT) : 1;
localparam OFFSET_MASK = AXIS_KEEP_W_INT > 1 ? {OFFSET_W{1'b1}} : 0;
localparam ADDR_MASK = {RAM_ADDR_W{1'b1}} << $clog2(AXIS_KEEP_W_INT);
localparam CYCLE_COUNT_W = LEN_W - $clog2(AXIS_KEEP_W_INT) + 1;

localparam OUTPUT_FIFO_AW = 5;

// check configuration
if (RAM_BYTE_SIZE * RAM_SEG_BE_W != RAM_SEG_DATA_W)
    $fatal(0, "Error: RAM data width not evenly divisible (instance %m)");

if (AXIS_BYTE_SIZE * AXIS_KEEP_W_INT != AXIS_DATA_W)
    $fatal(0, "Error: AXI stream data width not evenly divisible (instance %m)");

if (RAM_BYTE_SIZE != AXIS_BYTE_SIZE)
    $fatal(0, "Error: word size mismatch (instance %m)");

if (2**$clog2(RAM_BYTE_LANES) != RAM_BYTE_LANES)
    $fatal(0, "Error: RAM word width must be even power of two (instance %m)");

if (AXIS_DATA_W > RAM_SEGS*RAM_SEG_DATA_W)
    $fatal(0, "Error: AXI stream interface width must not be wider than RAM interface width (instance %m)");

if (AXIS_DATA_W*2**$clog2(PART_COUNT) != RAM_SEGS*RAM_SEG_DATA_W)
    $fatal(0, "Error: AXI stream interface width must be a power of two fraction of RAM interface width (instance %m)");

if (desc_req.SRC_ADDR_W < RAM_ADDR_W)
    $fatal(0, "Error: Descriptor address width is not sufficient (instance %m)");

typedef enum logic [0:0] {
    READ_STATE_IDLE,
    READ_STATE_READ
} read_state_t;

read_state_t read_state_reg = READ_STATE_IDLE, read_state_next;

typedef enum logic [0:0] {
    AXIS_STATE_IDLE,
    AXIS_STATE_READ
} axis_state_t;

axis_state_t axis_state_reg = AXIS_STATE_IDLE, axis_state_next;

// datapath control signals
logic axis_cmd_ready;

logic [RAM_ADDR_W-1:0] read_addr_reg = '0, read_addr_next;
logic [RAM_SEGS-1:0] read_ram_mask_reg = 0, read_ram_mask_next;
logic [CYCLE_COUNT_W-1:0] read_cycle_count_reg = '0, read_cycle_count_next;

logic [RAM_ADDR_W-1:0] axis_cmd_addr_reg = '0, axis_cmd_addr_next;
logic [OFFSET_W-1:0] axis_cmd_last_cycle_offset_reg = '0, axis_cmd_last_cycle_offset_next;
logic [CYCLE_COUNT_W-1:0] axis_cmd_cycle_count_reg = '0, axis_cmd_cycle_count_next;
logic [TAG_W-1:0] axis_cmd_tag_reg = '0, axis_cmd_tag_next;
logic [AXIS_ID_W-1:0] axis_cmd_axis_id_reg = '0, axis_cmd_axis_id_next;
logic [AXIS_DEST_W-1:0] axis_cmd_axis_dest_reg = '0, axis_cmd_axis_dest_next;
logic [AXIS_USER_W-1:0] axis_cmd_axis_user_reg = '0, axis_cmd_axis_user_next;
logic axis_cmd_valid_reg = 1'b0, axis_cmd_valid_next;

logic [RAM_ADDR_W-1:0] addr_reg = '0, addr_next;
logic [RAM_SEGS-1:0] ram_mask_reg = 0, ram_mask_next;
logic [OFFSET_W-1:0] last_cycle_offset_reg = '0, last_cycle_offset_next;
logic [CYCLE_COUNT_W-1:0] cycle_count_reg = '0, cycle_count_next;
logic last_cycle_reg = 1'b0, last_cycle_next;

logic [AXIS_ID_W-1:0] axis_id_reg = '0, axis_id_next;
logic [AXIS_DEST_W-1:0] axis_dest_reg = '0, axis_dest_next;
logic [AXIS_USER_W-1:0] axis_user_reg = '0, axis_user_next;

logic desc_req_ready_reg = 1'b0, desc_req_ready_next;

logic [TAG_W-1:0] desc_sts_tag_reg = '0, desc_sts_tag_next;
logic desc_sts_valid_reg = 1'b0, desc_sts_valid_next;

logic [RAM_SEGS-1:0][RAM_SEG_ADDR_W-1:0] ram_rd_cmd_addr_reg = '0, ram_rd_cmd_addr_next;
logic [RAM_SEGS-1:0] ram_rd_cmd_valid_reg = '0, ram_rd_cmd_valid_next;
logic [RAM_SEGS-1:0] ram_rd_resp_ready_cmb;

// internal datapath
logic  [AXIS_DATA_W-1:0] m_axis_rd_data_tdata_int;
logic  [AXIS_KEEP_W-1:0] m_axis_rd_data_tkeep_int;
logic                    m_axis_rd_data_tvalid_int;
wire                     m_axis_rd_data_tready_int;
logic                    m_axis_rd_data_tlast_int;
logic  [AXIS_ID_W-1:0]   m_axis_rd_data_tid_int;
logic  [AXIS_DEST_W-1:0] m_axis_rd_data_tdest_int;
logic  [AXIS_USER_W-1:0] m_axis_rd_data_tuser_int;

assign desc_req.req_ready = desc_req_ready_reg;

assign desc_sts.sts_len = '0;
assign desc_sts.sts_tag = desc_sts_tag_reg;
assign desc_sts.sts_id = '0;
assign desc_sts.sts_dest = '0;
assign desc_sts.sts_user = '0;
assign desc_sts.sts_error = 4'd0;
assign desc_sts.sts_valid = desc_sts_valid_reg;

assign dma_ram_rd.rd_cmd_addr = ram_rd_cmd_addr_reg;
assign dma_ram_rd.rd_cmd_valid = ram_rd_cmd_valid_reg;
assign dma_ram_rd.rd_resp_ready = ram_rd_resp_ready_cmb;

always_comb begin
    read_state_next = READ_STATE_IDLE;

    desc_req_ready_next = 1'b0;

    ram_rd_cmd_addr_next = ram_rd_cmd_addr_reg;
    ram_rd_cmd_valid_next = ram_rd_cmd_valid_reg & ~dma_ram_rd.rd_cmd_ready;

    read_addr_next = read_addr_reg;
    read_ram_mask_next = read_ram_mask_reg;
    read_cycle_count_next = read_cycle_count_reg;

    axis_cmd_addr_next = axis_cmd_addr_reg;
    axis_cmd_last_cycle_offset_next = axis_cmd_last_cycle_offset_reg;
    axis_cmd_cycle_count_next = axis_cmd_cycle_count_reg;
    axis_cmd_tag_next = axis_cmd_tag_reg;
    axis_cmd_axis_id_next = axis_cmd_axis_id_reg;
    axis_cmd_axis_dest_next = axis_cmd_axis_dest_reg;
    axis_cmd_axis_user_next = axis_cmd_axis_user_reg;
    axis_cmd_valid_next = axis_cmd_valid_reg && !axis_cmd_ready;

    case (read_state_reg)
        READ_STATE_IDLE: begin
            // idle state - load new descriptor to start operation
            desc_req_ready_next = !axis_cmd_valid_reg && enable;

            if (desc_req.req_ready && desc_req.req_valid) begin

                read_addr_next = RAM_ADDR_W'(desc_req.req_src_addr & ADDR_MASK);

                if (PART_COUNT > 1) begin
                    read_ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((read_addr_next >> PART_OFFSET_W) & ({PART_COUNT_W{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    read_ram_mask_next = '1;
                end

                axis_cmd_addr_next = RAM_ADDR_W'(desc_req.req_src_addr & ADDR_MASK);
                axis_cmd_last_cycle_offset_next = OFFSET_W'(desc_req.req_len & OFFSET_MASK);

                axis_cmd_tag_next = desc_req.req_tag;

                axis_cmd_axis_id_next = desc_req.req_id;
                axis_cmd_axis_dest_next = desc_req.req_dest;
                axis_cmd_axis_user_next = desc_req.req_user;

                axis_cmd_cycle_count_next = CYCLE_COUNT_W'(desc_req.req_len - LEN_W'(1) >> $clog2(AXIS_KEEP_W_INT));
                read_cycle_count_next = CYCLE_COUNT_W'(desc_req.req_len - LEN_W'(1) >> $clog2(AXIS_KEEP_W_INT));

                axis_cmd_valid_next = 1'b1;

                desc_req_ready_next = 1'b0;
                read_state_next = READ_STATE_READ;
            end else begin
                read_state_next = READ_STATE_IDLE;
            end
        end
        READ_STATE_READ: begin
            // read state - start new read operations

            if ((dma_ram_rd.rd_cmd_valid & ~dma_ram_rd.rd_cmd_ready & read_ram_mask_reg) == 0) begin

                // update counters
                read_addr_next = read_addr_reg + RAM_ADDR_W'(AXIS_KEEP_W_INT);
                read_cycle_count_next = read_cycle_count_reg - 1;

                if (PART_COUNT > 1) begin
                    read_ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((read_addr_next >> PART_OFFSET_W) & ({PART_COUNT_W{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    read_ram_mask_next = '1;
                end

                for (integer i = 0; i < RAM_SEGS; i = i + 1) begin
                    if (read_ram_mask_reg[i]) begin
                        ram_rd_cmd_addr_next[i] = read_addr_reg[RAM_ADDR_W-1:RAM_ADDR_W-RAM_SEG_ADDR_W];
                        ram_rd_cmd_valid_next[i] = 1'b1;
                    end
                end

                if (read_cycle_count_reg == 0) begin
                    desc_req_ready_next = !axis_cmd_valid_reg && enable;
                    read_state_next = READ_STATE_IDLE;
                end else begin
                    read_state_next = READ_STATE_READ;
                end
            end else begin
                read_state_next = READ_STATE_READ;
            end
        end
    endcase
end

always_comb begin
    axis_state_next = AXIS_STATE_IDLE;

    desc_sts_tag_next = desc_sts_tag_reg;
    desc_sts_valid_next = 1'b0;

    if (PART_COUNT > 1) begin
        m_axis_rd_data_tdata_int = dma_ram_rd.rd_resp_data >> (((addr_reg >> PART_OFFSET_W) & {PART_COUNT_W{1'b1}}) * AXIS_DATA_W);
    end else begin
        m_axis_rd_data_tdata_int = AXIS_DATA_W'(dma_ram_rd.rd_resp_data);
    end
    m_axis_rd_data_tkeep_int = '1;
    m_axis_rd_data_tlast_int = 1'b0;
    m_axis_rd_data_tvalid_int = 1'b0;
    m_axis_rd_data_tid_int = axis_id_reg;
    m_axis_rd_data_tdest_int = axis_dest_reg;
    m_axis_rd_data_tuser_int = axis_user_reg;

    ram_rd_resp_ready_cmb = '0;

    axis_cmd_ready = 1'b0;

    addr_next = addr_reg;
    ram_mask_next = ram_mask_reg;
    last_cycle_offset_next = last_cycle_offset_reg;
    cycle_count_next = cycle_count_reg;
    last_cycle_next = last_cycle_reg;

    axis_id_next = axis_id_reg;
    axis_dest_next = axis_dest_reg;
    axis_user_next = axis_user_reg;

    case (axis_state_reg)
        AXIS_STATE_IDLE: begin
            // idle state - load new descriptor to start operation

            // store transfer parameters
            addr_next = axis_cmd_addr_reg;
            last_cycle_offset_next = axis_cmd_last_cycle_offset_reg;
            cycle_count_next = axis_cmd_cycle_count_reg;
            last_cycle_next = axis_cmd_cycle_count_reg == 0;

            if (PART_COUNT > 1) begin
                ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((addr_next >> PART_OFFSET_W) & ({PART_COUNT_W{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
            end else begin
                ram_mask_next = '1;
            end

            desc_sts_tag_next = axis_cmd_tag_reg;
            axis_id_next = axis_cmd_axis_id_reg;
            axis_dest_next = axis_cmd_axis_dest_reg;
            axis_user_next = axis_cmd_axis_user_reg;

            if (axis_cmd_valid_reg) begin
                axis_cmd_ready = 1'b1;
                axis_state_next = AXIS_STATE_READ;
            end
        end
        AXIS_STATE_READ: begin
            // handle read data
            ram_rd_resp_ready_cmb = '0;

            if ((ram_mask_reg & ~dma_ram_rd.rd_resp_valid) == 0 && m_axis_rd_data_tready_int) begin
                // transfer in read data
                ram_rd_resp_ready_cmb = ram_mask_reg;

                // update counters
                addr_next = addr_reg + RAM_ADDR_W'(AXIS_KEEP_W_INT);
                cycle_count_next = cycle_count_reg - 1;
                last_cycle_next = cycle_count_next == 0;

                if (PART_COUNT > 1) begin
                    ram_mask_next = {SEGS_PER_PART{1'b1}} << ((((addr_next >> PART_OFFSET_W) & ({PART_COUNT_W{1'b1}})) / PARTS_PER_SEG) * SEGS_PER_PART);
                end else begin
                    ram_mask_next = '1;
                end

                if (PART_COUNT > 1) begin
                    m_axis_rd_data_tdata_int = dma_ram_rd.rd_resp_data >> (((addr_reg >> PART_OFFSET_W) & {PART_COUNT_W{1'b1}}) * AXIS_DATA_W);
                end else begin
                    m_axis_rd_data_tdata_int = AXIS_DATA_W'(dma_ram_rd.rd_resp_data);
                end
                m_axis_rd_data_tkeep_int = '1;
                m_axis_rd_data_tvalid_int = 1'b1;

                if (last_cycle_reg) begin
                    // no more data to transfer, finish operation
                    if (last_cycle_offset_reg > 0) begin
                        m_axis_rd_data_tkeep_int = {AXIS_KEEP_W_INT{1'b1}} >> ((OFFSET_W+1)'(AXIS_KEEP_W_INT) - last_cycle_offset_reg);
                    end
                    m_axis_rd_data_tlast_int = 1'b1;

                    desc_sts_valid_next = 1'b1;

                    axis_state_next = AXIS_STATE_IDLE;
                end else begin
                    // more cycles in AXI transfer
                    axis_state_next = AXIS_STATE_READ;
                end
            end else begin
                axis_state_next = AXIS_STATE_READ;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    read_state_reg <= read_state_next;
    axis_state_reg <= axis_state_next;

    desc_req_ready_reg <= desc_req_ready_next;

    desc_sts_tag_reg <= desc_sts_tag_next;
    desc_sts_valid_reg <= desc_sts_valid_next;

    ram_rd_cmd_addr_reg <= ram_rd_cmd_addr_next;
    ram_rd_cmd_valid_reg <= ram_rd_cmd_valid_next;

    read_addr_reg <= read_addr_next;
    read_ram_mask_reg <= read_ram_mask_next;
    read_cycle_count_reg <= read_cycle_count_next;

    axis_cmd_addr_reg <= axis_cmd_addr_next;
    axis_cmd_last_cycle_offset_reg <= axis_cmd_last_cycle_offset_next;
    axis_cmd_cycle_count_reg <= axis_cmd_cycle_count_next;
    axis_cmd_tag_reg <= axis_cmd_tag_next;
    axis_cmd_axis_id_reg <= axis_cmd_axis_id_next;
    axis_cmd_axis_dest_reg <= axis_cmd_axis_dest_next;
    axis_cmd_axis_user_reg <= axis_cmd_axis_user_next;
    axis_cmd_valid_reg <= axis_cmd_valid_next;

    addr_reg <= addr_next;
    ram_mask_reg <= ram_mask_next;
    last_cycle_offset_reg <= last_cycle_offset_next;
    cycle_count_reg <= cycle_count_next;
    last_cycle_reg <= last_cycle_next;

    axis_id_reg <= axis_id_next;
    axis_dest_reg <= axis_dest_next;
    axis_user_reg <= axis_user_next;

    if (rst) begin
        read_state_reg <= READ_STATE_IDLE;
        axis_state_reg <= AXIS_STATE_IDLE;

        axis_cmd_valid_reg <= 1'b0;

        desc_req_ready_reg <= 1'b0;
        desc_sts_valid_reg <= 1'b0;

        ram_rd_cmd_valid_reg <= '0;
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
