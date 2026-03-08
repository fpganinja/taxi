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
 * DMA RAM demux (write)
 */
module taxi_dma_ram_demux_wr #
(
    // Number of ports
    parameter PORTS = 2
)
(
    input  wire logic       clk,
    input  wire logic       rst,

    /*
     * RAM interface (from DMA interface)
     */
    taxi_dma_ram_if.wr_slv  dma_ram_wr,

    /*
     * RAM interface (towards RAM)
     */
    taxi_dma_ram_if.wr_mst  ram_wr[PORTS]
);

localparam SEGS = dma_ram_wr.SEGS;
localparam SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;
localparam SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam SEG_BE_W = dma_ram_wr.SEG_BE_W;
localparam DMA_SEL_W = dma_ram_wr.SEL_W;
localparam RAM_SEL_W = ram_wr[0].SEL_W;

localparam CL_PORTS = $clog2(PORTS);

localparam RAM_SEL_W_INT = RAM_SEL_W > 0 ? RAM_SEL_W : 1;

localparam FIFO_AW = 5;

// check configuration
if (ram_wr[0].SEGS != SEGS || ram_wr[0].SEG_ADDR_W > SEG_ADDR_W ||
    ram_wr[0].SEG_DATA_W != SEG_DATA_W || ram_wr[0].SEG_BE_W != SEG_BE_W)
    $error("Error: interface configuration mismatch (instance %m)");

if (DMA_SEL_W < RAM_SEL_W+$clog2(PORTS))
    $error("Error: dma_ram_wr.SEL_W must be at least $clog2(PORTS) larger than ram_wr.SEL_W (instance %m)");

for (genvar n = 0; n < SEGS; n = n + 1) begin

    if (PORTS == 1) begin
        // degenerate case

        assign ram_wr[0].wr_cmd_sel = dma_ram_wr.wr_cmd_sel;
        assign ram_wr[0].wr_cmd_addr = dma_ram_wr.wr_cmd_addr;
        assign ram_wr[0].wr_cmd_data = dma_ram_wr.wr_cmd_data;
        assign ram_wr[0].wr_cmd_be = dma_ram_wr.wr_cmd_be;
        assign ram_wr[0].wr_cmd_valid = dma_ram_wr.wr_cmd_valid;

        assign dma_ram_wr.wr_cmd_ready = ram_wr[0].wr_cmd_ready;
        assign dma_ram_wr.wr_done = ram_wr[0].wr_done;

    end else begin

        // FIFO to maintain response ordering
        logic [FIFO_AW+1-1:0] fifo_wr_ptr_reg = '0;
        logic [FIFO_AW+1-1:0] fifo_rd_ptr_reg = '0;
        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        logic [CL_PORTS-1:0] fifo_sel[2**FIFO_AW] = '{default: '0};

        wire fifo_empty = fifo_wr_ptr_reg == fifo_rd_ptr_reg;
        wire fifo_full = fifo_wr_ptr_reg == (fifo_rd_ptr_reg ^ (1 << FIFO_AW));

        // RAM write command demux

        wire [DMA_SEL_W-1:0]   seg_ctrl_wr_cmd_sel   = dma_ram_wr.wr_cmd_sel[n];
        wire [SEG_BE_W-1:0]    seg_ctrl_wr_cmd_be    = dma_ram_wr.wr_cmd_be[n];
        wire [SEG_ADDR_W-1:0]  seg_ctrl_wr_cmd_addr  = dma_ram_wr.wr_cmd_addr[n];
        wire [SEG_DATA_W-1:0]  seg_ctrl_wr_cmd_data  = dma_ram_wr.wr_cmd_data[n];
        wire                   seg_ctrl_wr_cmd_valid = dma_ram_wr.wr_cmd_valid[n];
        wire                   seg_ctrl_wr_cmd_ready;

        assign dma_ram_wr.wr_cmd_ready[n] = seg_ctrl_wr_cmd_ready;

        // internal datapath
        logic  [RAM_SEL_W-1:0]   seg_ram_wr_cmd_sel_int;
        logic  [SEG_BE_W-1:0]    seg_ram_wr_cmd_be_int;
        logic  [SEG_ADDR_W-1:0]  seg_ram_wr_cmd_addr_int;
        logic  [SEG_DATA_W-1:0]  seg_ram_wr_cmd_data_int;
        logic  [PORTS-1:0]       seg_ram_wr_cmd_valid_int;
        logic                    seg_ram_wr_cmd_ready_int_reg = 1'b0;
        wire                     seg_ram_wr_cmd_ready_int_early;

        assign seg_ctrl_wr_cmd_ready = seg_ram_wr_cmd_ready_int_reg && !fifo_full;

        wire [CL_PORTS-1:0] select_cmd = CL_PORTS'(PORTS > 1 ? (seg_ctrl_wr_cmd_sel >> (DMA_SEL_W - CL_PORTS)) : '0);

        always_comb begin
            seg_ram_wr_cmd_sel_int   = RAM_SEL_W'(seg_ctrl_wr_cmd_sel);
            seg_ram_wr_cmd_be_int    = seg_ctrl_wr_cmd_be;
            seg_ram_wr_cmd_addr_int  = seg_ctrl_wr_cmd_addr;
            seg_ram_wr_cmd_data_int  = seg_ctrl_wr_cmd_data;
            seg_ram_wr_cmd_valid_int = '0;
            seg_ram_wr_cmd_valid_int[select_cmd] = seg_ctrl_wr_cmd_valid && seg_ctrl_wr_cmd_ready;
        end

        always_ff @(posedge clk) begin
            if (seg_ctrl_wr_cmd_valid && seg_ctrl_wr_cmd_ready) begin
                fifo_sel[fifo_wr_ptr_reg[FIFO_AW-1:0]] <= select_cmd;
                fifo_wr_ptr_reg <= fifo_wr_ptr_reg + 1;
            end

            if (rst) begin
                fifo_wr_ptr_reg <= '0;
            end
        end

        // output datapath logic
        logic [RAM_SEL_W-1:0]   seg_ram_wr_cmd_sel_reg   = '0;
        logic [SEG_BE_W-1:0]    seg_ram_wr_cmd_be_reg    = '0;
        logic [SEG_ADDR_W-1:0]  seg_ram_wr_cmd_addr_reg  = '0;
        logic [SEG_DATA_W-1:0]  seg_ram_wr_cmd_data_reg  = '0;
        logic [PORTS-1:0]       seg_ram_wr_cmd_valid_reg = '0, seg_ram_wr_cmd_valid_next;

        logic [RAM_SEL_W-1:0]   temp_seg_ram_wr_cmd_sel_reg   = '0;
        logic [SEG_BE_W-1:0]    temp_seg_ram_wr_cmd_be_reg    = '0;
        logic [SEG_ADDR_W-1:0]  temp_seg_ram_wr_cmd_addr_reg  = '0;
        logic [SEG_DATA_W-1:0]  temp_seg_ram_wr_cmd_data_reg  = '0;
        logic [PORTS-1:0]       temp_seg_ram_wr_cmd_valid_reg = '0, temp_seg_ram_wr_cmd_valid_next;

        // datapath control
        logic store_axis_resp_int_to_output;
        logic store_axis_resp_int_to_temp;
        logic store_axis_resp_temp_to_output;

        wire [PORTS-1:0]  seg_ram_wr_cmd_ready;

        for (genvar p = 0; p < PORTS; p = p + 1) begin
            assign ram_wr[p].wr_cmd_sel[n] = seg_ram_wr_cmd_sel_reg;
            assign ram_wr[p].wr_cmd_be[n] = seg_ram_wr_cmd_be_reg;
            assign ram_wr[p].wr_cmd_addr[n] = seg_ram_wr_cmd_addr_reg;
            assign ram_wr[p].wr_cmd_data[n] = seg_ram_wr_cmd_data_reg;
            assign ram_wr[p].wr_cmd_valid[n] = seg_ram_wr_cmd_valid_reg[p];
            assign seg_ram_wr_cmd_ready[p] = ram_wr[p].wr_cmd_ready[n];
        end

        // enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
        assign seg_ram_wr_cmd_ready_int_early = (seg_ram_wr_cmd_ready & seg_ram_wr_cmd_valid_reg) != 0 || (temp_seg_ram_wr_cmd_valid_reg == 0 && (seg_ram_wr_cmd_valid_reg == 0 || seg_ram_wr_cmd_valid_int == 0));

        always_comb begin
            // transfer sink ready state to source
            seg_ram_wr_cmd_valid_next = seg_ram_wr_cmd_valid_reg;
            temp_seg_ram_wr_cmd_valid_next = temp_seg_ram_wr_cmd_valid_reg;

            store_axis_resp_int_to_output = 1'b0;
            store_axis_resp_int_to_temp = 1'b0;
            store_axis_resp_temp_to_output = 1'b0;

            if (seg_ram_wr_cmd_ready_int_reg) begin
                // input is ready
                if ((seg_ram_wr_cmd_ready & seg_ram_wr_cmd_valid_reg) != 0 || seg_ram_wr_cmd_valid_reg == 0) begin
                    // output is ready or currently not valid, transfer data to output
                    seg_ram_wr_cmd_valid_next = seg_ram_wr_cmd_valid_int;
                    store_axis_resp_int_to_output = 1'b1;
                end else begin
                    // output is not ready, store input in temp
                    temp_seg_ram_wr_cmd_valid_next = seg_ram_wr_cmd_valid_int;
                    store_axis_resp_int_to_temp = 1'b1;
                end
            end else if ((seg_ram_wr_cmd_ready & seg_ram_wr_cmd_valid_reg) != 0) begin
                // input is not ready, but output is ready
                seg_ram_wr_cmd_valid_next = temp_seg_ram_wr_cmd_valid_reg;
                temp_seg_ram_wr_cmd_valid_next = '0;
                store_axis_resp_temp_to_output = 1'b1;
            end
        end

        always_ff @(posedge clk) begin
            seg_ram_wr_cmd_valid_reg <= seg_ram_wr_cmd_valid_next;
            seg_ram_wr_cmd_ready_int_reg <= seg_ram_wr_cmd_ready_int_early;
            temp_seg_ram_wr_cmd_valid_reg <= temp_seg_ram_wr_cmd_valid_next;

            // datapath
            if (store_axis_resp_int_to_output) begin
                seg_ram_wr_cmd_sel_reg <= seg_ram_wr_cmd_sel_int;
                seg_ram_wr_cmd_be_reg <= seg_ram_wr_cmd_be_int;
                seg_ram_wr_cmd_addr_reg <= seg_ram_wr_cmd_addr_int;
                seg_ram_wr_cmd_data_reg <= seg_ram_wr_cmd_data_int;
            end else if (store_axis_resp_temp_to_output) begin
                seg_ram_wr_cmd_sel_reg <= temp_seg_ram_wr_cmd_sel_reg;
                seg_ram_wr_cmd_be_reg <= temp_seg_ram_wr_cmd_be_reg;
                seg_ram_wr_cmd_addr_reg <= temp_seg_ram_wr_cmd_addr_reg;
                seg_ram_wr_cmd_data_reg <= temp_seg_ram_wr_cmd_data_reg;
            end

            if (store_axis_resp_int_to_temp) begin
                temp_seg_ram_wr_cmd_sel_reg <= seg_ram_wr_cmd_sel_int;
                temp_seg_ram_wr_cmd_be_reg <= seg_ram_wr_cmd_be_int;
                temp_seg_ram_wr_cmd_addr_reg <= seg_ram_wr_cmd_addr_int;
                temp_seg_ram_wr_cmd_data_reg <= seg_ram_wr_cmd_data_int;
            end

            if (rst) begin
                seg_ram_wr_cmd_valid_reg <= '0;
                seg_ram_wr_cmd_ready_int_reg <= 1'b0;
                temp_seg_ram_wr_cmd_valid_reg <= '0;
            end
        end

        // RAM write done mux

        wire [PORTS-1:0] seg_ram_wr_done;
        wire [PORTS-1:0] seg_ram_wr_done_out;
        wire [PORTS-1:0] seg_ram_wr_done_ack;
        wire seg_ctrl_wr_done;

        for (genvar p = 0; p < PORTS; p = p + 1) begin
            assign seg_ram_wr_done[p] = ram_wr[p].wr_done[n];
        end

        assign dma_ram_wr.wr_done[n] = seg_ctrl_wr_done;

        for (genvar p = 0; p < PORTS; p = p + 1) begin
            logic [FIFO_AW+1-1:0] done_count_reg = '0;
            logic done_reg = 1'b0;

            assign seg_ram_wr_done_out[p] = done_reg;

            always_ff @(posedge clk) begin
                if (done_count_reg < 2**FIFO_AW && seg_ram_wr_done[p] && !seg_ram_wr_done_ack[p]) begin
                    done_count_reg <= done_count_reg + 1;
                    done_reg <= 1;
                end else if (done_count_reg > 0 && !seg_ram_wr_done[p] && seg_ram_wr_done_ack[p]) begin
                    done_count_reg <= done_count_reg - 1;
                    done_reg <= done_count_reg > 1;
                end

                if (rst) begin
                    done_count_reg <= '0;
                    done_reg <= 1'b0;
                end
            end
        end

        logic [CL_PORTS-1:0] select_resp_reg = '0;
        logic select_resp_valid_reg = 1'b0;

        assign seg_ram_wr_done_ack = seg_ram_wr_done_out & (select_resp_valid_reg ? (1 << select_resp_reg) : 0);
        assign seg_ctrl_wr_done = |seg_ram_wr_done_ack;

        always_ff @(posedge clk) begin
            if (!select_resp_valid_reg || seg_ctrl_wr_done) begin
                select_resp_valid_reg <= 1'b0;
                if (!fifo_empty) begin
                    select_resp_reg <= fifo_sel[fifo_rd_ptr_reg[FIFO_AW-1:0]];
                    fifo_rd_ptr_reg <= fifo_rd_ptr_reg + 1;
                    select_resp_valid_reg <= 1'b1;
                end
            end

            if (rst) begin
                fifo_rd_ptr_reg <= '0;
                select_resp_valid_reg <= 1'b0;
            end
        end

    end

end

endmodule

`resetall
