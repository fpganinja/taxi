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
 * Corundum-micro descriptor read module
 */
module cndm_micro_desc_rd #(
    parameter WQN_W = 5,
    parameter CQN_W = 5
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Control register interface
     */
    taxi_axil_if.wr_slv       s_axil_ctrl_wr,
    taxi_axil_if.rd_slv       s_axil_ctrl_rd,

    /*
     * Datapath control register interface
     */
    taxi_apb_if.slv           s_apb_dp_ctrl,

    /*
     * DMA
     */
    taxi_dma_desc_if.req_src  dma_rd_desc_req,
    taxi_dma_desc_if.sts_snk  dma_rd_desc_sts,
    taxi_dma_ram_if.wr_slv    dma_ram_wr,

    taxi_axis_if.snk          s_axis_desc_req,
    taxi_axis_if.src          m_axis_desc
);

localparam DMA_ADDR_W = dma_rd_desc_req.SRC_ADDR_W;
localparam DMA_TAG_W = dma_rd_desc_req.TAG_W;

localparam RAM_ADDR_W = 16;

localparam SLOT_CNT = 2;
localparam SLOT_AW = $clog2(SLOT_CNT);

localparam SLOT_SZ = dma_ram_wr.SEG_DATA_W * dma_ram_wr.SEG_DATA_W / 8;
localparam CL_SLOT_SZ = $clog2(SLOT_SZ);

localparam ID_W = s_axis_desc_req.ID_W;
localparam TAG_W = SLOT_AW;

logic [SLOT_AW+1-1:0] slot_start_ptr_reg = '0;
logic [SLOT_AW+1-1:0] slot_rd_ptr_reg = '0;
logic [SLOT_AW+1-1:0] slot_finish_ptr_reg = '0;
logic slot_valid_reg[2**SLOT_AW] = '{default: '0};
logic slot_error_reg[2**SLOT_AW] = '{default: '0};
logic [TAG_W-1:0] slot_id_reg[2**SLOT_AW] = '{default: '0};
logic [CQN_W-1:0] slot_cqn_reg[2**SLOT_AW] = '{default: '0};

typedef enum logic [2:0] {
    QTYPE_EQ,
    QTYPE_CQ,
    QTYPE_SQ,
    QTYPE_RQ
} qtype_t;

logic [WQN_W-1:0]       wq_req_wqn_reg = '0;
logic [2:0]             wq_req_qtype_reg = '0;
logic [TAG_W-1:0]       wq_req_tag_reg = '0;
logic                   wq_req_valid_reg = 1'b0;
logic                   wq_req_ready;
logic [CQN_W-1:0]       wq_rsp_cqn;
logic [DMA_ADDR_W-1:0]  wq_rsp_addr;
logic                   wq_rsp_error;
logic [TAG_W-1:0]       wq_rsp_tag;
logic                   wq_rsp_valid;
logic                   wq_rsp_ready_reg = 1'b0;

taxi_axis_if axis_irq_stub();
taxi_axis_if axis_event_stub();

cndm_micro_queue_state #(
    .QN_W(WQN_W),
    .DQN_W(CQN_W),
    .TAG_W(TAG_W),
    .IS_CQ(0),
    .IS_EQ(0),
    .CQ_IRQ(0),
    .QTYPE_EN(1),
    .QE_SIZE(16),
    .DMA_ADDR_W(DMA_ADDR_W)
)
wq_mgr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Control register interface
     */
    .s_axil_ctrl_wr(s_axil_ctrl_wr),
    .s_axil_ctrl_rd(s_axil_ctrl_rd),

    /*
     * Datapath control register interface
     */
    .s_apb_dp_ctrl(s_apb_dp_ctrl),

    /*
     * Queue management interface
     */
    .req_qn(wq_req_wqn_reg),
    .req_qtype(wq_req_qtype_reg),
    .req_tag(wq_req_tag_reg),
    .req_valid(wq_req_valid_reg),
    .req_ready(wq_req_ready),
    .rsp_qn(),
    .rsp_dqn(wq_rsp_cqn),
    .rsp_addr(wq_rsp_addr),
    .rsp_phase_tag(),
    .rsp_error(wq_rsp_error),
    .rsp_tag(wq_rsp_tag),
    .rsp_valid(wq_rsp_valid),
    .rsp_ready(wq_rsp_ready_reg),

    /*
     * Notification interface
     */
    .notify_req_qn('0),
    .notify_req_valid(1'b0),
    .notify_req_ready(),

    /*
     * Interrupts
     */
    .m_axis_irq(axis_irq_stub),

    /*
     * Event output
     */
    .m_axis_event(axis_event_stub)
);

taxi_dma_desc_if #(
    .SRC_ADDR_W(RAM_ADDR_W),
    .SRC_SEL_EN(1'b0),
    .SRC_ASID_EN(1'b0),
    .DST_ADDR_W(RAM_ADDR_W),
    .DST_SEL_EN(1'b0),
    .DST_ASID_EN(1'b0),
    .IMM_EN(1'b0),
    .LEN_W(5),
    .TAG_W(SLOT_AW+1),
    .ID_EN(m_axis_desc.ID_EN),
    .ID_W(m_axis_desc.ID_W),
    .DEST_EN(m_axis_desc.DEST_EN),
    .DEST_W(m_axis_desc.DEST_W),
    .USER_EN(m_axis_desc.USER_EN),
    .USER_W(m_axis_desc.USER_W)
) dma_desc();

logic s_axis_desc_req_tready_reg = 1'b0;

assign s_axis_desc_req.tready = s_axis_desc_req_tready_reg;

always_ff @(posedge clk) begin
    dma_rd_desc_req.req_src_sel <= '0;
    dma_rd_desc_req.req_src_asid <= '0;
    dma_rd_desc_req.req_dst_sel <= '0;
    dma_rd_desc_req.req_dst_asid <= '0;
    dma_rd_desc_req.req_imm <= '0;
    dma_rd_desc_req.req_imm_en <= '0;
    dma_rd_desc_req.req_len <= 16;
    dma_rd_desc_req.req_tag <= '0;
    dma_rd_desc_req.req_id <= '0;
    dma_rd_desc_req.req_dest <= '0;
    dma_rd_desc_req.req_user <= '0;
    dma_rd_desc_req.req_valid <= dma_rd_desc_req.req_valid && !dma_rd_desc_req.req_ready;

    dma_desc.req_src_sel <= '0;
    dma_desc.req_src_asid <= '0;
    dma_desc.req_dst_addr <= '0;
    dma_desc.req_dst_sel <= '0;
    dma_desc.req_dst_asid <= '0;
    dma_desc.req_imm <= '0;
    dma_desc.req_imm_en <= '0;
    dma_desc.req_len <= 16;
    dma_desc.req_tag <= '0;
    dma_desc.req_user <= '0;
    dma_desc.req_valid <= dma_desc.req_valid && !dma_desc.req_ready;

    wq_req_valid_reg <= wq_req_valid_reg && !wq_req_ready;
    wq_rsp_ready_reg <= 1'b0;

    s_axis_desc_req_tready_reg <= 1'b0;

    // queue state query
    s_axis_desc_req_tready_reg <= ((slot_start_ptr_reg ^ slot_finish_ptr_reg) != {1'b1, {SLOT_AW{1'b0}}}) && (!wq_req_valid_reg || wq_req_ready);

    if (s_axis_desc_req.tvalid && s_axis_desc_req.tready) begin
        s_axis_desc_req_tready_reg <= 1'b0;
        wq_req_wqn_reg <= s_axis_desc_req.tdest;
        wq_req_qtype_reg <= s_axis_desc_req.tuser;
        wq_req_tag_reg <= slot_start_ptr_reg[SLOT_AW-1:0];
        wq_req_valid_reg <= 1'b1;

        slot_id_reg[slot_start_ptr_reg[SLOT_AW-1:0]] <= s_axis_desc_req.tid;
        slot_valid_reg[slot_start_ptr_reg[SLOT_AW-1:0]] <= 1'b0;
        slot_error_reg[slot_start_ptr_reg[SLOT_AW-1:0]] <= 1'b0;

        slot_start_ptr_reg <= slot_start_ptr_reg + 1;
    end

    // start host DMA read
    wq_rsp_ready_reg <= 1'b1;

    if (wq_rsp_valid && wq_rsp_ready_reg) begin
        wq_rsp_ready_reg <= 1'b0;

        dma_rd_desc_req.req_src_addr <= wq_rsp_addr;
        dma_rd_desc_req.req_dst_addr <= RAM_ADDR_W'(wq_rsp_tag*SLOT_SZ);
        dma_rd_desc_req.req_tag <= DMA_TAG_W'(wq_rsp_tag);

        slot_cqn_reg[wq_rsp_tag] <= wq_rsp_cqn;
        slot_error_reg[wq_rsp_tag] <= wq_rsp_error;

        if (!wq_rsp_error) begin
            // read desc
            dma_rd_desc_req.req_valid <= 1'b1;
        end
    end

    // store host DMA read status
    if (dma_rd_desc_sts.sts_valid) begin
        slot_valid_reg[dma_rd_desc_sts.sts_tag[SLOT_AW-1:0]] <= 1'b1;
    end

    // start internal DMA
    if ((slot_valid_reg[slot_rd_ptr_reg[SLOT_AW-1:0]] || slot_error_reg[slot_rd_ptr_reg[SLOT_AW-1:0]]) && slot_rd_ptr_reg != slot_start_ptr_reg) begin
        dma_desc.req_src_addr <= RAM_ADDR_W'(slot_rd_ptr_reg[SLOT_AW-1:0]*SLOT_SZ);
        dma_desc.req_dest <= slot_cqn_reg[slot_rd_ptr_reg[SLOT_AW-1:0]];
        dma_desc.req_id <= slot_id_reg[slot_rd_ptr_reg[SLOT_AW-1:0]];
        dma_desc.req_user <= slot_error_reg[slot_rd_ptr_reg[SLOT_AW-1:0]];
        dma_desc.req_tag <= slot_rd_ptr_reg;
        dma_desc.req_valid <= 1'b1;

        slot_rd_ptr_reg <= slot_rd_ptr_reg + 1;
    end

    // handle internal DMA status
    if (dma_desc.sts_valid) begin
        slot_finish_ptr_reg <= dma_desc.sts_tag;
    end

    if (rst) begin
        slot_start_ptr_reg <= '0;
        slot_rd_ptr_reg <= '0;
        slot_finish_ptr_reg <= '0;
    end
end

taxi_dma_ram_if #(
    .SEGS(dma_ram_wr.SEGS),
    .SEG_ADDR_W(dma_ram_wr.SEG_ADDR_W),
    .SEG_DATA_W(dma_ram_wr.SEG_DATA_W),
    .SEG_BE_W(dma_ram_wr.SEG_BE_W)
) dma_ram_rd();

taxi_dma_psdpram #(
    .SIZE(1024),
    .PIPELINE(2)
)
ram_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .dma_ram_wr(dma_ram_wr),

    /*
     * Read port
     */
    .dma_ram_rd(dma_ram_rd)
);

taxi_dma_client_axis_source
dma_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA descriptor
     */
    .desc_req(dma_desc),
    .desc_sts(dma_desc),

    /*
     * AXI stream read data output
     */
    .m_axis_rd_data(m_axis_desc),

    /*
     * RAM interface
     */
    .dma_ram_rd(dma_ram_rd),

    /*
     * Configuration
     */
    .enable(1'b1)
);

endmodule

`resetall
