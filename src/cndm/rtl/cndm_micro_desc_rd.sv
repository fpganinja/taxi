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

    input  wire logic [1:0]   desc_req,
    taxi_axis_if.src          m_axis_desc
);

localparam DMA_ADDR_W = dma_rd_desc_req.SRC_ADDR_W;

localparam RAM_ADDR_W = 16;

logic [WQN_W-1:0]       wq_req_wqn_reg = '0;
logic                   wq_req_valid_reg = 1'b0;
logic                   wq_req_ready;
logic [CQN_W-1:0]       wq_rsp_cqn;
logic [DMA_ADDR_W-1:0]  wq_rsp_addr;
logic                   wq_rsp_error;
logic                   wq_rsp_valid;
logic                   wq_rsp_ready_reg = 1'b0;

cndm_micro_queue_state #(
    .QN_W(WQN_W),
    .DQN_W(CQN_W),
    .IS_CQ(0),
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
    .req_valid(wq_req_valid_reg),
    .req_ready(wq_req_ready),
    .rsp_qn(),
    .rsp_dqn(wq_rsp_cqn),
    .rsp_addr(wq_rsp_addr),
    .rsp_phase_tag(),
    .rsp_error(wq_rsp_error),
    .rsp_valid(wq_rsp_valid),
    .rsp_ready(wq_rsp_ready_reg)
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
    .TAG_W(1),
    .ID_EN(m_axis_desc.ID_EN),
    .ID_W(m_axis_desc.ID_W),
    .DEST_EN(m_axis_desc.DEST_EN),
    .DEST_W(m_axis_desc.DEST_W),
    .USER_EN(m_axis_desc.USER_EN),
    .USER_W(m_axis_desc.USER_W)
) dma_desc();

typedef enum logic [1:0] {
    STATE_IDLE,
    STATE_QUERY_WQ,
    STATE_READ_DESC,
    STATE_TX_DESC
} state_t;

state_t state_reg = STATE_IDLE;

logic [1:0] desc_req_reg = '0;

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

    desc_req_reg <= desc_req_reg | desc_req;

    case (state_reg)
        STATE_IDLE: begin
            wq_req_wqn_reg <= 0;

            if (desc_req_reg[1]) begin
                desc_req_reg[1] <= 1'b0;
                wq_req_wqn_reg <= 1;
                wq_req_valid_reg <= 1'b1;
                dma_desc.req_id <= 1'b1;
                state_reg <= STATE_QUERY_WQ;
            end else if (desc_req_reg[0]) begin
                desc_req_reg[0] <= 1'b0;
                wq_req_wqn_reg <= 0;
                wq_req_valid_reg <= 1'b1;
                dma_desc.req_id <= 1'b0;
                state_reg <= STATE_QUERY_WQ;
            end else begin
                state_reg <= STATE_IDLE;
            end
        end
        STATE_QUERY_WQ: begin
            wq_rsp_ready_reg <= 1'b1;

            if (wq_rsp_valid && wq_rsp_ready_reg) begin
                wq_rsp_ready_reg <= 1'b0;

                dma_rd_desc_req.req_src_addr <= wq_rsp_addr;

                dma_desc.req_dest <= wq_rsp_cqn;

                if (wq_rsp_error) begin
                    // report error
                    dma_desc.req_user <= 1'b1;
                    dma_desc.req_valid <= 1'b1;
                    state_reg <= STATE_TX_DESC;
                end else begin
                    // read desc
                    dma_desc.req_user <= 1'b0;
                    dma_rd_desc_req.req_valid <= 1'b1;
                    state_reg <= STATE_READ_DESC;
                end
            end
        end
        STATE_READ_DESC: begin
            if (dma_rd_desc_sts.sts_valid) begin
                dma_desc.req_valid <= 1'b1;
                state_reg <= STATE_TX_DESC;
            end
        end
        STATE_TX_DESC: begin
            if (dma_desc.sts_valid) begin
                state_reg <= STATE_IDLE;
            end
        end
        default: begin
            state_reg <= STATE_IDLE;
        end
    endcase

    if (rst) begin
        state_reg <= STATE_IDLE;
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
