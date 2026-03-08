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
 * APM RAM
 */
module taxi_apb_ram #
(
    // Width of address bus in bits
    parameter ADDR_W = 16,
    // Extra pipeline register on output
    parameter logic PIPELINE_OUTPUT = 1'b0
)
(
    input  wire logic  clk,
    input  wire logic  rst,

    /*
     * APB slave interface
     */
    taxi_apb_if.slv    s_apb
);

// extract parameters
localparam DATA_W = s_apb.DATA_W;
localparam STRB_W = s_apb.STRB_W;

localparam VALID_ADDR_W = ADDR_W - $clog2(STRB_W);
localparam BYTE_LANES = STRB_W;
localparam BYTE_W = DATA_W/BYTE_LANES;

// check configuration
if (BYTE_W * STRB_W != DATA_W)
    $fatal(0, "Error: APB data width not evenly divisible (instance %m)");

if (2**$clog2(BYTE_LANES) != BYTE_LANES)
    $fatal(0, "Error: APB byte lane count must be even power of two (instance %m)");

if (s_apb.ADDR_W < ADDR_W)
    $fatal(0, "Error: APB address width is insufficient (instance %m)");

logic mem_wr_en;
logic mem_rd_en;

logic s_apb_pready_reg = 1'b0, s_apb_pready_next;
logic s_apb_pready_pipe_reg = 1'b0;
logic [DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;
logic [DATA_W-1:0] s_apb_prdata_pipe_reg = '0;

// (* RAM_STYLE="BLOCK" *)
logic [DATA_W-1:0] mem[2**VALID_ADDR_W] = '{default: '0};

wire [VALID_ADDR_W-1:0] s_apb_paddr_valid = VALID_ADDR_W'(s_apb.paddr >> (ADDR_W - VALID_ADDR_W));

assign s_apb.prdata = PIPELINE_OUTPUT ? s_apb_prdata_pipe_reg : s_apb_prdata_reg;
assign s_apb.pready = PIPELINE_OUTPUT ? s_apb_pready_pipe_reg : s_apb_pready_reg;
assign s_apb.pslverr = 1'b0;
assign s_apb.pruser = '0;
assign s_apb.pbuser = '0;

always_comb begin
    mem_wr_en = 1'b0;
    mem_rd_en = 1'b0;

    s_apb_pready_next = 1'b0;

    if (s_apb.psel && s_apb.penable && (!s_apb_pready_reg && (PIPELINE_OUTPUT || !s_apb_pready_pipe_reg))) begin
        s_apb_pready_next = 1'b1;

        if (s_apb.pwrite) begin
            mem_wr_en = 1'b1;
        end else begin
            mem_rd_en = 1'b1;
        end
    end
end

always_ff @(posedge clk) begin
    s_apb_pready_reg <= s_apb_pready_next;

    for (integer i = 0; i < BYTE_LANES; i = i + 1) begin
        if (mem_wr_en && s_apb.pstrb[i]) begin
            mem[s_apb_paddr_valid][BYTE_W*i +: BYTE_W] <= s_apb.pwdata[BYTE_W*i +: BYTE_W];
        end
    end

    if (mem_rd_en) begin
        s_apb_prdata_reg <= mem[s_apb_paddr_valid];
    end

    s_apb_prdata_pipe_reg <= s_apb_prdata_reg;
    s_apb_pready_pipe_reg <= s_apb_pready_reg;

    if (rst) begin
        s_apb_pready_reg <= 1'b0;
    end
end

endmodule

`resetall
