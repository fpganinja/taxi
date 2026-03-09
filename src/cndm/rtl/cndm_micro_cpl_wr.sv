// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Corundum-micro completion write module
 */
module cndm_micro_cpl_wr #(
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
    taxi_dma_desc_if.req_src  dma_wr_desc_req,
    taxi_dma_desc_if.sts_snk  dma_wr_desc_sts,
    taxi_dma_ram_if.rd_slv    dma_ram_rd,

    /*
     * Interrupts
     */
    taxi_axis_if.src          m_axis_irq,

    taxi_axis_if.snk          s_axis_cpl
);

localparam DMA_ADDR_W = dma_wr_desc_req.DST_ADDR_W;

localparam IRQN_W = m_axis_irq.DATA_W;

logic [CQN_W-1:0]       cq_req_cqn_reg = '0;
logic                   cq_req_valid_reg = 1'b0;
logic                   cq_req_ready;
logic [IRQN_W-1:0]      cq_rsp_irqn;
logic [DMA_ADDR_W-1:0]  cq_rsp_addr;
logic                   cq_rsp_phase_tag;
logic                   cq_rsp_error;
logic                   cq_rsp_valid;
logic                   cq_rsp_ready_reg = 1'b0;

cndm_micro_queue_state #(
    .QN_W(CQN_W),
    .DQN_W(IRQN_W),
    .IS_CQ(1),
    .QTYPE_EN(0),
    .QE_SIZE(16),
    .DMA_ADDR_W(DMA_ADDR_W)
)
cq_mgr_inst (
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
    .req_qn(cq_req_cqn_reg),
    .req_qtype('0),
    .req_valid(cq_req_valid_reg),
    .req_ready(cq_req_ready),
    .rsp_qn(),
    .rsp_dqn(cq_rsp_irqn),
    .rsp_addr(cq_rsp_addr),
    .rsp_phase_tag(cq_rsp_phase_tag),
    .rsp_error(cq_rsp_error),
    .rsp_valid(cq_rsp_valid),
    .rsp_ready(cq_rsp_ready_reg)
);

typedef enum logic [1:0] {
    STATE_IDLE,
    STATE_QUERY_CQ,
    STATE_WRITE_DATA
} state_t;

state_t state_reg = STATE_IDLE;

logic phase_tag_reg = 1'b0;

logic [IRQN_W-1:0] m_axis_irq_irqn_reg = '0;
logic m_axis_irq_tvalid_reg = 1'b0;

assign m_axis_irq.tdata  = m_axis_irq_irqn_reg;
assign m_axis_irq.tkeep  = '1;
assign m_axis_irq.tstrb  = m_axis_irq.tkeep;
assign m_axis_irq.tvalid = m_axis_irq_tvalid_reg;
assign m_axis_irq.tlast  = 1'b1;
assign m_axis_irq.tid    = '0;
assign m_axis_irq.tdest  = '0;
assign m_axis_irq.tuser  = '0;

always_ff @(posedge clk) begin
    s_axis_cpl.tready <= 1'b0;

    dma_wr_desc_req.req_src_sel <= '0;
    dma_wr_desc_req.req_src_asid <= '0;
    dma_wr_desc_req.req_dst_sel <= '0;
    dma_wr_desc_req.req_dst_asid <= '0;
    dma_wr_desc_req.req_imm <= '0;
    dma_wr_desc_req.req_imm_en <= '0;
    dma_wr_desc_req.req_len <= 16;
    dma_wr_desc_req.req_tag <= '0;
    dma_wr_desc_req.req_id <= '0;
    dma_wr_desc_req.req_dest <= '0;
    dma_wr_desc_req.req_user <= '0;
    dma_wr_desc_req.req_valid <= dma_wr_desc_req.req_valid && !dma_wr_desc_req.req_ready;

    cq_req_valid_reg <= cq_req_valid_reg && !cq_req_ready;
    cq_rsp_ready_reg <= 1'b0;

    m_axis_irq_tvalid_reg <= m_axis_irq_tvalid_reg && !m_axis_irq.tready;

    case (state_reg)
        STATE_IDLE: begin
            dma_wr_desc_req.req_src_addr <= '0;

            cq_req_cqn_reg <= s_axis_cpl.tdest;

            if (s_axis_cpl.tvalid && !s_axis_cpl.tready) begin
                cq_req_valid_reg <= 1'b1;
                state_reg <= STATE_QUERY_CQ;
            end else begin
                state_reg <= STATE_IDLE;
            end
        end
        STATE_QUERY_CQ: begin
            dma_wr_desc_req.req_src_addr <= '0;
            cq_rsp_ready_reg <= 1'b1;

            if (cq_rsp_valid && cq_rsp_ready_reg) begin
                cq_rsp_ready_reg <= 1'b0;

                m_axis_irq_irqn_reg <= cq_rsp_irqn;
                dma_wr_desc_req.req_dst_addr <= cq_rsp_addr;
                phase_tag_reg <= cq_rsp_phase_tag;

                if (cq_rsp_error) begin
                    // drop completion
                    s_axis_cpl.tready <= 1'b1;
                    state_reg <= STATE_IDLE;
                end else begin
                    dma_wr_desc_req.req_valid <= 1'b1;
                    state_reg <= STATE_WRITE_DATA;
                end
            end
        end
        STATE_WRITE_DATA: begin
            if (dma_wr_desc_sts.sts_valid) begin
                s_axis_cpl.tready <= 1'b1;
                m_axis_irq_tvalid_reg <= 1'b1;
                state_reg <= STATE_IDLE;
            end
        end
        default: begin
            state_reg <= STATE_IDLE;
        end
    endcase

    if (rst) begin
        state_reg <= STATE_IDLE;
        cq_req_valid_reg <= 1'b0;
        cq_rsp_ready_reg <= 1'b0;
        m_axis_irq_tvalid_reg <= 1'b0;
    end
end

// extract parameters
localparam SEGS = dma_ram_rd.SEGS;
localparam SEG_ADDR_W = dma_ram_rd.SEG_ADDR_W;
localparam SEG_DATA_W = dma_ram_rd.SEG_DATA_W;
localparam SEG_BE_W = dma_ram_rd.SEG_BE_W;

if (SEGS*SEG_DATA_W < 128)
    $fatal(0, "Total segmented interface width must be at least 128 (instance %m)");

wire [SEGS-1:0][SEG_DATA_W-1:0] ram_data = (SEG_DATA_W*SEGS)'({phase_tag_reg, s_axis_cpl.tdata[126:0]});

for (genvar n = 0; n < SEGS; n = n + 1) begin

    logic [0:0] rd_resp_valid_pipe_reg = '0;
    logic [SEG_DATA_W-1:0] rd_resp_data_pipe_reg[1];

    initial begin
        for (integer i = 0; i < 1; i = i + 1) begin
            rd_resp_data_pipe_reg[i] = '0;
        end
    end

    always_ff @(posedge clk) begin
        if (dma_ram_rd.rd_resp_ready[n]) begin
            rd_resp_valid_pipe_reg[0] <= 1'b0;
        end

        for (integer j = 0; j > 0; j = j - 1) begin
            if (dma_ram_rd.rd_resp_ready[n] || (1'(~rd_resp_valid_pipe_reg) >> j) != 0) begin
                rd_resp_valid_pipe_reg[j] <= rd_resp_valid_pipe_reg[j-1];
                rd_resp_data_pipe_reg[j] <= rd_resp_data_pipe_reg[j-1];
                rd_resp_valid_pipe_reg[j-1] <= 1'b0;
            end
        end

        if (dma_ram_rd.rd_cmd_valid[n] && dma_ram_rd.rd_cmd_ready[n]) begin
            rd_resp_valid_pipe_reg[0] <= 1'b1;
            rd_resp_data_pipe_reg[0] <= ram_data[0];
        end

        if (rst) begin
            rd_resp_valid_pipe_reg <= '0;
        end
    end

    assign dma_ram_rd.rd_cmd_ready[n] = dma_ram_rd.rd_resp_ready[n] || &rd_resp_valid_pipe_reg == 0;

    assign dma_ram_rd.rd_resp_valid[n] = rd_resp_valid_pipe_reg[0];
    assign dma_ram_rd.rd_resp_data[n] = rd_resp_data_pipe_reg[0];

end

endmodule

`resetall
