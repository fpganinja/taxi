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
 * DMA RAM demux (read)
 */
module taxi_dma_ram_demux_rd #
(
    // Number of ports
    parameter PORTS = 2
)
(
    input  wire logic       clk,
    input  wire logic       rst,

    /*
     * RAM interface (from DMA client/interface)
     */
    taxi_dma_ram_if.rd_slv  dma_ram_rd,

    /*
     * RAM interface (towards RAM)
     */
    taxi_dma_ram_if.rd_mst  ram_rd[PORTS]
);

localparam SEGS = dma_ram_rd.SEGS;
localparam SEG_ADDR_W = dma_ram_rd.SEG_ADDR_W;
localparam SEG_DATA_W = dma_ram_rd.SEG_DATA_W;
localparam DMA_SEL_W = dma_ram_rd.SEL_W;
localparam RAM_SEL_W = ram_rd[0].SEL_W;

localparam CL_PORTS = $clog2(PORTS);

localparam RAM_SEL_W_INT = RAM_SEL_W > 0 ? RAM_SEL_W : 1;

localparam FIFO_AW = 5;
localparam OUTPUT_FIFO_AW = 5;

// check configuration
if (ram_rd[0].SEGS != SEGS || ram_rd[0].SEG_ADDR_W > SEG_ADDR_W ||
    ram_rd[0].SEG_DATA_W != SEG_DATA_W)
    $error("Error: interface configuration mismatch (instance %m)");

if (DMA_SEL_W < RAM_SEL_W+$clog2(PORTS))
    $error("Error: dma_ram_rd.SEL_W must be at least $clog2(PORTS) larger than ram_rd.SEL_W (instance %m)");

for (genvar n = 0; n < SEGS; n = n + 1) begin

    if (PORTS == 1) begin
        // degenerate case

        assign ram_rd[0].rd_cmd_sel = dma_ram_rd.rd_cmd_sel;
        assign ram_rd[0].rd_cmd_addr = dma_ram_rd.rd_cmd_addr;
        assign ram_rd[0].rd_cmd_valid = dma_ram_rd.rd_cmd_valid;
        assign dma_ram_rd.rd_cmd_ready = ram_rd[0].rd_cmd_ready;

        assign dma_ram_rd.rd_resp_data = ram_rd[0].rd_resp_data;
        assign dma_ram_rd.rd_resp_valid = ram_rd[0].rd_resp_valid;
        assign ram_rd[0].rd_resp_ready = dma_ram_rd.rd_resp_ready;

    end else begin

        // FIFO to maintain response ordering
        logic [FIFO_AW+1-1:0] fifo_wr_ptr_reg = '0;
        logic [FIFO_AW+1-1:0] fifo_rd_ptr_reg = '0;
        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        logic [CL_PORTS-1:0] fifo_sel[2**FIFO_AW] = '{default: '0};

        wire fifo_empty = fifo_wr_ptr_reg == fifo_rd_ptr_reg;
        wire fifo_full = fifo_wr_ptr_reg == (fifo_rd_ptr_reg ^ (1 << FIFO_AW));

        // RAM read command demux

        wire [DMA_SEL_W-1:0]   seg_ctrl_rd_cmd_sel   = dma_ram_rd.rd_cmd_sel[n];
        wire [SEG_ADDR_W-1:0]  seg_ctrl_rd_cmd_addr  = dma_ram_rd.rd_cmd_addr[n];
        wire                   seg_ctrl_rd_cmd_valid = dma_ram_rd.rd_cmd_valid[n];
        wire                   seg_ctrl_rd_cmd_ready;

        assign dma_ram_rd.rd_cmd_ready[n] = seg_ctrl_rd_cmd_ready;

        // internal datapath
        logic  [RAM_SEL_W-1:0]   seg_ram_rd_cmd_sel_int;
        logic  [SEG_ADDR_W-1:0]  seg_ram_rd_cmd_addr_int;
        logic  [PORTS-1:0]       seg_ram_rd_cmd_valid_int;
        logic                    seg_ram_rd_cmd_ready_int_reg = 1'b0;
        wire                     seg_ram_rd_cmd_ready_int_early;

        assign seg_ctrl_rd_cmd_ready = seg_ram_rd_cmd_ready_int_reg && !fifo_full;

        wire [CL_PORTS-1:0] select_cmd = CL_PORTS'(PORTS > 1 ? (seg_ctrl_rd_cmd_sel >> (DMA_SEL_W - CL_PORTS)) : '0);

        always_comb begin
            seg_ram_rd_cmd_sel_int   = RAM_SEL_W'(seg_ctrl_rd_cmd_sel);
            seg_ram_rd_cmd_addr_int  = seg_ctrl_rd_cmd_addr;
            seg_ram_rd_cmd_valid_int = 0;
            seg_ram_rd_cmd_valid_int[select_cmd] = seg_ctrl_rd_cmd_valid && seg_ctrl_rd_cmd_ready;
        end

        always_ff @(posedge clk) begin
            if (seg_ctrl_rd_cmd_valid && seg_ctrl_rd_cmd_ready) begin
                fifo_sel[fifo_wr_ptr_reg[FIFO_AW-1:0]] <= select_cmd;
                fifo_wr_ptr_reg <= fifo_wr_ptr_reg + 1;
            end

            if (rst) begin
                fifo_wr_ptr_reg <= '0;
            end
        end

        // output datapath logic
        logic [RAM_SEL_W-1:0]   seg_ram_rd_cmd_sel_reg   = '0;
        logic [SEG_ADDR_W-1:0]  seg_ram_rd_cmd_addr_reg  = '0;
        logic [PORTS-1:0]       seg_ram_rd_cmd_valid_reg = '0, seg_ram_rd_cmd_valid_next;

        logic [RAM_SEL_W-1:0]   temp_seg_ram_rd_cmd_sel_reg   = '0;
        logic [SEG_ADDR_W-1:0]  temp_seg_ram_rd_cmd_addr_reg  = '0;
        logic [PORTS-1:0]       temp_seg_ram_rd_cmd_valid_reg = '0, temp_seg_ram_rd_cmd_valid_next;

        // datapath control
        logic store_axis_resp_int_to_output;
        logic store_axis_resp_int_to_temp;
        logic store_axis_resp_temp_to_output;

        wire [PORTS-1:0]  seg_ram_rd_cmd_ready;

        for (genvar p = 0; p < PORTS; p = p + 1) begin
            assign ram_rd[p].rd_cmd_sel[n] = seg_ram_rd_cmd_sel_reg;
            assign ram_rd[p].rd_cmd_addr[n] = seg_ram_rd_cmd_addr_reg;
            assign ram_rd[p].rd_cmd_valid[n] = seg_ram_rd_cmd_valid_reg[p];
            assign seg_ram_rd_cmd_ready[p] = ram_rd[p].rd_cmd_ready[n];
        end

        // enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
        assign seg_ram_rd_cmd_ready_int_early = (seg_ram_rd_cmd_ready & seg_ram_rd_cmd_valid_reg) != 0 || (temp_seg_ram_rd_cmd_valid_reg == 0 && (seg_ram_rd_cmd_valid_reg == 0 || seg_ram_rd_cmd_valid_int == 0));

        always_comb begin
            // transfer sink ready state to source
            seg_ram_rd_cmd_valid_next = seg_ram_rd_cmd_valid_reg;
            temp_seg_ram_rd_cmd_valid_next = temp_seg_ram_rd_cmd_valid_reg;

            store_axis_resp_int_to_output = 1'b0;
            store_axis_resp_int_to_temp = 1'b0;
            store_axis_resp_temp_to_output = 1'b0;

            if (seg_ram_rd_cmd_ready_int_reg) begin
                // input is ready
                if ((seg_ram_rd_cmd_ready & seg_ram_rd_cmd_valid_reg) != 0 || seg_ram_rd_cmd_valid_reg == 0) begin
                    // output is ready or currently not valid, transfer data to output
                    seg_ram_rd_cmd_valid_next = seg_ram_rd_cmd_valid_int;
                    store_axis_resp_int_to_output = 1'b1;
                end else begin
                    // output is not ready, store input in temp
                    temp_seg_ram_rd_cmd_valid_next = seg_ram_rd_cmd_valid_int;
                    store_axis_resp_int_to_temp = 1'b1;
                end
            end else if ((seg_ram_rd_cmd_ready & seg_ram_rd_cmd_valid_reg) != 0) begin
                // input is not ready, but output is ready
                seg_ram_rd_cmd_valid_next = temp_seg_ram_rd_cmd_valid_reg;
                temp_seg_ram_rd_cmd_valid_next = '0;
                store_axis_resp_temp_to_output = 1'b1;
            end
        end

        always_ff @(posedge clk) begin
            seg_ram_rd_cmd_valid_reg <= seg_ram_rd_cmd_valid_next;
            seg_ram_rd_cmd_ready_int_reg <= seg_ram_rd_cmd_ready_int_early;
            temp_seg_ram_rd_cmd_valid_reg <= temp_seg_ram_rd_cmd_valid_next;

            // datapath
            if (store_axis_resp_int_to_output) begin
                seg_ram_rd_cmd_sel_reg <= seg_ram_rd_cmd_sel_int;
                seg_ram_rd_cmd_addr_reg <= seg_ram_rd_cmd_addr_int;
            end else if (store_axis_resp_temp_to_output) begin
                seg_ram_rd_cmd_sel_reg <= temp_seg_ram_rd_cmd_sel_reg;
                seg_ram_rd_cmd_addr_reg <= temp_seg_ram_rd_cmd_addr_reg;
            end

            if (store_axis_resp_int_to_temp) begin
                temp_seg_ram_rd_cmd_sel_reg <= seg_ram_rd_cmd_sel_int;
                temp_seg_ram_rd_cmd_addr_reg <= seg_ram_rd_cmd_addr_int;
            end

            if (rst) begin
                seg_ram_rd_cmd_valid_reg <= '0;
                seg_ram_rd_cmd_ready_int_reg <= 1'b0;
                temp_seg_ram_rd_cmd_valid_reg <= '0;
            end
        end

        // RAM read response mux
        wire [SEG_DATA_W-1:0]  seg_ram_rd_resp_data[PORTS];
        wire                   seg_ram_rd_resp_valid[PORTS];
        logic                  seg_ram_rd_resp_ready[PORTS];

        for (genvar p = 0; p < PORTS; p = p + 1) begin
            assign seg_ram_rd_resp_data[p] = ram_rd[p].rd_resp_data[n];
            assign seg_ram_rd_resp_valid[p] = ram_rd[p].rd_resp_valid[n];
            assign ram_rd[p].rd_resp_ready[n] = seg_ram_rd_resp_ready[p];
        end

        // internal datapath
        logic  [SEG_DATA_W-1:0]  seg_ctrl_rd_resp_data_int;
        logic                    seg_ctrl_rd_resp_valid_int;
        wire                     seg_ctrl_rd_resp_ready_int;

        wire [CL_PORTS-1:0] select_resp = fifo_sel[fifo_rd_ptr_reg[FIFO_AW-1:0]];

        always_comb begin
            seg_ram_rd_resp_ready = '{PORTS{1'b0}};
            seg_ram_rd_resp_ready[select_resp] = seg_ctrl_rd_resp_ready_int && !fifo_empty;
        end

        // mux for incoming packet
        wire [SEG_DATA_W-1:0]  current_resp_data  = seg_ram_rd_resp_data[select_resp];
        wire                   current_resp_valid = seg_ram_rd_resp_valid[select_resp];
        wire                   current_resp_ready = seg_ram_rd_resp_ready[select_resp];

        always_comb begin
            // pass through selected packet data
            seg_ctrl_rd_resp_data_int  = current_resp_data;
            seg_ctrl_rd_resp_valid_int = current_resp_valid && seg_ctrl_rd_resp_ready_int && !fifo_empty;
        end

        always_ff @(posedge clk) begin
            if (current_resp_valid && seg_ctrl_rd_resp_ready_int && !fifo_empty) begin
                fifo_rd_ptr_reg <= fifo_rd_ptr_reg + 1;
            end

            if (rst) begin
                fifo_rd_ptr_reg <= '0;
            end
        end

        // output datapath logic
        logic [SEG_DATA_W-1:0] seg_ctrl_rd_resp_data_reg  = '0;
        logic                  seg_ctrl_rd_resp_valid_reg = 1'b0;

        logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_wr_ptr_reg = '0;
        logic [OUTPUT_FIFO_AW+1-1:0] out_fifo_rd_ptr_reg = '0;
        logic out_fifo_half_full_reg = 1'b0;

        wire out_fifo_full = out_fifo_wr_ptr_reg == (out_fifo_rd_ptr_reg ^ {1'b1, {OUTPUT_FIFO_AW{1'b0}}});
        wire out_fifo_empty = out_fifo_wr_ptr_reg == out_fifo_rd_ptr_reg;

        (* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
        logic [SEG_DATA_W-1:0] out_fifo_rd_resp_data[2**OUTPUT_FIFO_AW];

        assign seg_ctrl_rd_resp_ready_int = !out_fifo_half_full_reg;

        wire seg_ctrl_rd_resp_ready = dma_ram_rd.rd_resp_ready[n];

        assign dma_ram_rd.rd_resp_data[n] = seg_ctrl_rd_resp_data_reg;
        assign dma_ram_rd.rd_resp_valid[n] = seg_ctrl_rd_resp_valid_reg;

        always_ff @(posedge clk) begin
            seg_ctrl_rd_resp_valid_reg <= seg_ctrl_rd_resp_valid_reg && !seg_ctrl_rd_resp_ready;

            out_fifo_half_full_reg <= $unsigned(out_fifo_wr_ptr_reg - out_fifo_rd_ptr_reg) >= 2**(OUTPUT_FIFO_AW-1);

            if (!out_fifo_full && seg_ctrl_rd_resp_valid_int) begin
                out_fifo_rd_resp_data[out_fifo_wr_ptr_reg[OUTPUT_FIFO_AW-1:0]] <= seg_ctrl_rd_resp_data_int;
                out_fifo_wr_ptr_reg <= out_fifo_wr_ptr_reg + 1;
            end

            if (!out_fifo_empty && (!seg_ctrl_rd_resp_valid_reg || seg_ctrl_rd_resp_ready)) begin
                seg_ctrl_rd_resp_data_reg <= out_fifo_rd_resp_data[out_fifo_rd_ptr_reg[OUTPUT_FIFO_AW-1:0]];
                seg_ctrl_rd_resp_valid_reg <= 1'b1;
                out_fifo_rd_ptr_reg <= out_fifo_rd_ptr_reg + 1;
            end

            if (rst) begin
                out_fifo_wr_ptr_reg <= '0;
                out_fifo_rd_ptr_reg <= '0;
                seg_ctrl_rd_resp_valid_reg <= 1'b0;
            end
        end

    end

end

endmodule

`resetall
