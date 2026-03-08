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
module taxi_apb_dp_ram #
(
    // Width of address bus in bits
    parameter ADDR_W = 16,
    // Extra pipeline register on output
    parameter logic PIPELINE_OUTPUT = 1'b0
)
(
    /*
     * Port A
     */
    input  wire logic  a_clk,
    input  wire logic  a_rst,
    taxi_apb_if.slv    s_apb_a,

    /*
     * Port B
     */
    input  wire logic  b_clk,
    input  wire logic  b_rst,
    taxi_apb_if.slv    s_apb_b
);

// extract parameters
localparam DATA_W = s_apb_a.DATA_W;
localparam STRB_W = s_apb_a.STRB_W;

localparam VALID_ADDR_W = ADDR_W - $clog2(STRB_W);
localparam BYTE_LANES = STRB_W;
localparam BYTE_W = DATA_W/BYTE_LANES;

// check configuration
if (BYTE_W * STRB_W != DATA_W)
    $fatal(0, "Error: APB data width not evenly divisible (instance %m)");

if (2**$clog2(BYTE_LANES) != BYTE_LANES)
    $fatal(0, "Error: APB byte lane count must be even power of two (instance %m)");

if (s_apb_a.DATA_W != s_apb_b.DATA_W)
    $fatal(0, "Error: APB interface configuration mismatch (instance %m)");

if (s_apb_a.ADDR_W < ADDR_W || s_apb_a.ADDR_W < ADDR_W)
    $fatal(0, "Error: APB address width is insufficient (instance %m)");

logic mem_wr_en_a;
logic mem_rd_en_a;

logic mem_wr_en_b;
logic mem_rd_en_b;

logic s_apb_a_pready_reg = 1'b0, s_apb_a_pready_next;
logic s_apb_a_pready_pipe_reg = 1'b0;
logic [DATA_W-1:0] s_apb_a_prdata_reg = '0, s_apb_a_prdata_next;
logic [DATA_W-1:0] s_apb_a_prdata_pipe_reg = '0;

logic s_apb_b_pready_reg = 1'b0, s_apb_b_pready_next;
logic s_apb_b_pready_pipe_reg = 1'b0;
logic [DATA_W-1:0] s_apb_b_prdata_reg = '0, s_apb_b_prdata_next;
logic [DATA_W-1:0] s_apb_b_prdata_pipe_reg = '0;

// verilator lint_off MULTIDRIVEN
// (* RAM_STYLE="BLOCK" *)
logic [DATA_W-1:0] mem[2**VALID_ADDR_W] = '{default: '0};
// verilator lint_on MULTIDRIVEN

wire [VALID_ADDR_W-1:0] s_apb_a_paddr_valid = VALID_ADDR_W'(s_apb_a.paddr >> (ADDR_W - VALID_ADDR_W));
wire [VALID_ADDR_W-1:0] s_apb_b_paddr_valid = VALID_ADDR_W'(s_apb_b.paddr >> (ADDR_W - VALID_ADDR_W));

assign s_apb_a.prdata = PIPELINE_OUTPUT ? s_apb_a_prdata_pipe_reg : s_apb_a_prdata_reg;
assign s_apb_a.pready = PIPELINE_OUTPUT ? s_apb_a_pready_pipe_reg : s_apb_a_pready_reg;
assign s_apb_a.pslverr = 1'b0;
assign s_apb_a.pruser = '0;
assign s_apb_a.pbuser = '0;

assign s_apb_b.prdata = PIPELINE_OUTPUT ? s_apb_b_prdata_pipe_reg : s_apb_b_prdata_reg;
assign s_apb_b.pready = PIPELINE_OUTPUT ? s_apb_b_pready_pipe_reg : s_apb_b_pready_reg;
assign s_apb_b.pslverr = 1'b0;
assign s_apb_b.pruser = '0;
assign s_apb_b.pbuser = '0;

always_comb begin
    mem_wr_en_a = 1'b0;
    mem_rd_en_a = 1'b0;

    s_apb_a_pready_next = 1'b0;

    if (s_apb_a.psel && s_apb_a.penable && (!s_apb_a_pready_reg && (PIPELINE_OUTPUT || !s_apb_a_pready_pipe_reg))) begin
        s_apb_a_pready_next = 1'b1;

        if (s_apb_a.pwrite) begin
            mem_wr_en_a = 1'b1;
        end else begin
            mem_rd_en_a = 1'b1;
        end
    end
end

always_ff @(posedge a_clk) begin
    s_apb_a_pready_reg <= s_apb_a_pready_next;

    for (integer i = 0; i < BYTE_LANES; i = i + 1) begin
        if (mem_wr_en_a && s_apb_a.pstrb[i]) begin
            mem[s_apb_a_paddr_valid][BYTE_W*i +: BYTE_W] <= s_apb_a.pwdata[BYTE_W*i +: BYTE_W];
        end
    end

    if (mem_rd_en_a) begin
        s_apb_a_prdata_reg <= mem[s_apb_a_paddr_valid];
    end

    s_apb_a_prdata_pipe_reg <= s_apb_a_prdata_reg;
    s_apb_a_pready_pipe_reg <= s_apb_a_pready_reg;

    if (a_rst) begin
        s_apb_a_pready_reg <= 1'b0;
    end
end

always_comb begin
    mem_wr_en_b = 1'b0;
    mem_rd_en_b = 1'b0;

    s_apb_b_pready_next = 1'b0;

    if (s_apb_b.psel && s_apb_b.penable && (!s_apb_b_pready_reg && (PIPELINE_OUTPUT || !s_apb_b_pready_pipe_reg))) begin
        s_apb_b_pready_next = 1'b1;

        if (s_apb_b.pwrite) begin
            mem_wr_en_b = 1'b1;
        end else begin
            mem_rd_en_b = 1'b1;
        end
    end
end

always_ff @(posedge b_clk) begin
    s_apb_b_pready_reg <= s_apb_b_pready_next;

    for (integer i = 0; i < BYTE_LANES; i = i + 1) begin
        if (mem_wr_en_b && s_apb_b.pstrb[i]) begin
            mem[s_apb_b_paddr_valid][BYTE_W*i +: BYTE_W] <= s_apb_b.pwdata[BYTE_W*i +: BYTE_W];
        end
    end

    if (mem_rd_en_b) begin
        s_apb_b_prdata_reg <= mem[s_apb_b_paddr_valid];
    end

    s_apb_b_prdata_pipe_reg <= s_apb_b_prdata_reg;
    s_apb_b_pready_pipe_reg <= s_apb_b_pready_reg;

    if (b_rst) begin
        s_apb_b_pready_reg <= 1'b0;
    end
end

endmodule

`resetall
