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
 * DMA parallel simple dual port RAM
 */
module taxi_dma_psdpram #
(
    // RAM size
    parameter SIZE = 4096,
    // Read data output pipeline stages
    parameter PIPELINE = 2
)
(
    input  wire             clk,
    input  wire             rst,

    /*
     * Write port
     */
    taxi_dma_ram_if.wr_slv  dma_ram_wr,

    /*
     * Read port
     */
    taxi_dma_ram_if.rd_slv  dma_ram_rd
);

// extract parameters
localparam SEGS = dma_ram_wr.SEGS;
localparam SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;
localparam SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam SEG_BE_W = dma_ram_wr.SEG_BE_W;

localparam INT_ADDR_W = $clog2(SIZE/(SEGS*SEG_BE_W));

// check configuration
if (dma_ram_wr.SEG_ADDR_W < INT_ADDR_W)
    $fatal(0, "Error: dma_ram_wr.SEG_ADDR_W not sufficient for requested size (min %d for size %d) (instance %m)", INT_ADDR_W, SIZE);

if (dma_ram_rd.SEG_ADDR_W < INT_ADDR_W)
    $fatal(0, "Error: dma_ram_wr.SEG_ADDR_W not sufficient for requested size (min %d for size %d) (instance %m)", INT_ADDR_W, SIZE);

if (SEGS != dma_ram_rd.SEGS || SEG_DATA_W != dma_ram_rd.SEG_DATA_W)
    $fatal(0, "Error: Interface segment configuration mismatch (instance %m)");

for (genvar n = 0; n < SEGS; n = n + 1) begin

    (* ramstyle = "no_rw_check" *)
    logic [SEG_DATA_W-1:0] mem_reg[2**INT_ADDR_W] = '{default: '0};

    logic wr_done_reg = 1'b0;

    logic [PIPELINE-1:0] rd_resp_valid_pipe_reg = '0;
    logic [SEG_DATA_W-1:0] rd_resp_data_pipe_reg[PIPELINE] = '{default: '0};

    always_ff @(posedge clk) begin
        wr_done_reg <= 1'b0;

        for (integer i = 0; i < SEG_BE_W; i = i + 1) begin
            if (dma_ram_wr.wr_cmd_valid[n] && dma_ram_wr.wr_cmd_be[n][i]) begin
                mem_reg[dma_ram_wr.wr_cmd_addr[n][INT_ADDR_W-1:0]][i*8 +: 8] <= dma_ram_wr.wr_cmd_data[n][i*8 +: 8];
            end
            wr_done_reg <= dma_ram_wr.wr_cmd_valid[n];
        end

        if (rst) begin
            wr_done_reg <= 1'b0;
        end
    end

    assign dma_ram_wr.wr_cmd_ready[n] = 1'b1;
    assign dma_ram_wr.wr_done[n] = wr_done_reg;

    always_ff @(posedge clk) begin
        if (dma_ram_rd.rd_resp_ready[n]) begin
            rd_resp_valid_pipe_reg[PIPELINE-1] <= 1'b0;
        end

        for (integer j = PIPELINE-1; j > 0; j = j - 1) begin
            if (dma_ram_rd.rd_resp_ready[n] || (PIPELINE'(~rd_resp_valid_pipe_reg) >> j) != 0) begin
                rd_resp_valid_pipe_reg[j] <= rd_resp_valid_pipe_reg[j-1];
                rd_resp_data_pipe_reg[j] <= rd_resp_data_pipe_reg[j-1];
                rd_resp_valid_pipe_reg[j-1] <= 1'b0;
            end
        end

        if (dma_ram_rd.rd_cmd_valid[n] && dma_ram_rd.rd_cmd_ready[n]) begin
            rd_resp_valid_pipe_reg[0] <= 1'b1;
            rd_resp_data_pipe_reg[0] <= mem_reg[dma_ram_rd.rd_cmd_addr[n][INT_ADDR_W-1:0]];
        end

        if (rst) begin
            rd_resp_valid_pipe_reg <= '0;
        end
    end

    assign dma_ram_rd.rd_cmd_ready[n] = dma_ram_rd.rd_resp_ready[n] || &rd_resp_valid_pipe_reg == 0;

    assign dma_ram_rd.rd_resp_valid[n] = rd_resp_valid_pipe_reg[PIPELINE-1];
    assign dma_ram_rd.rd_resp_data[n] = rd_resp_data_pipe_reg[PIPELINE-1];

end

endmodule

`resetall
