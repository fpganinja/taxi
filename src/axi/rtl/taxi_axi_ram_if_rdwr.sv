// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4 RAM read/write interface
 */
module taxi_axi_ram_if_rdwr #
(
    // Width of data bus in bits
    parameter DATA_W = 32,
    // Width of address bus in bits
    parameter ADDR_W = 16,
    // Width of wstrb (width of data bus in words)
    parameter STRB_W = (DATA_W/8),
    // Width of ID signal
    parameter ID_W = 8,
    // Width of auser output
    parameter AUSER_W = 1,
    // Width of wuser signal
    parameter WUSER_W = 1,
    // Width of ruser signal
    parameter RUSER_W = 1,
    // Extra pipeline register on output
    parameter logic PIPELINE_OUTPUT = 1'b0,
    // Interleave read and write burst cycles
    parameter logic INTERLEAVE = 1'b0
)
(
    input  wire logic          clk,
    input  wire logic          rst,

    /*
     * AXI4 slave interface
     */
    taxi_axi_if.wr_slv         s_axi_wr,
    taxi_axi_if.rd_slv         s_axi_rd,

    /*
     * RAM interface
     */
    output wire [ID_W-1:0]     ram_cmd_id,
    output wire [ADDR_W-1:0]   ram_cmd_addr,
    output wire                ram_cmd_lock,
    output wire [3:0]          ram_cmd_cache,
    output wire [2:0]          ram_cmd_prot,
    output wire [3:0]          ram_cmd_qos,
    output wire [3:0]          ram_cmd_region,
    output wire [AUSER_W-1:0]  ram_cmd_auser,
    output wire [DATA_W-1:0]   ram_cmd_wr_data,
    output wire [STRB_W-1:0]   ram_cmd_wr_strb,
    output wire [WUSER_W-1:0]  ram_cmd_wr_user,
    output wire                ram_cmd_wr_en,
    output wire                ram_cmd_rd_en,
    output wire                ram_cmd_last,
    input  wire                ram_cmd_ready,
    input  wire [ID_W-1:0]     ram_rd_resp_id,
    input  wire [DATA_W-1:0]   ram_rd_resp_data,
    input  wire                ram_rd_resp_last,
    input  wire [RUSER_W-1:0]  ram_rd_resp_user,
    input  wire                ram_rd_resp_valid,
    output wire                ram_rd_resp_ready
);

wire [ID_W-1:0]     ram_wr_cmd_id;
wire [ADDR_W-1:0]   ram_wr_cmd_addr;
wire                ram_wr_cmd_lock;
wire [3:0]          ram_wr_cmd_cache;
wire [2:0]          ram_wr_cmd_prot;
wire [3:0]          ram_wr_cmd_qos;
wire [3:0]          ram_wr_cmd_region;
wire [AUSER_W-1:0]  ram_wr_cmd_auser;
wire                ram_wr_cmd_en;
wire                ram_wr_cmd_last;
wire                ram_wr_cmd_ready;

wire [ID_W-1:0]     ram_rd_cmd_id;
wire [ADDR_W-1:0]   ram_rd_cmd_addr;
wire                ram_rd_cmd_lock;
wire [3:0]          ram_rd_cmd_cache;
wire [2:0]          ram_rd_cmd_prot;
wire [3:0]          ram_rd_cmd_qos;
wire [3:0]          ram_rd_cmd_region;
wire [AUSER_W-1:0]  ram_rd_cmd_auser;
wire                ram_rd_cmd_en;
wire                ram_rd_cmd_last;
wire                ram_rd_cmd_ready;

taxi_axi_ram_if_wr #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .ID_W(ID_W),
    .AUSER_W(AUSER_W),
    .WUSER_W(WUSER_W)
)
wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4 slave interface
     */
    .s_axi_wr(s_axi_wr),

    /*
     * RAM interface
     */
    .ram_wr_cmd_id(ram_wr_cmd_id),
    .ram_wr_cmd_addr(ram_wr_cmd_addr),
    .ram_wr_cmd_lock(ram_wr_cmd_lock),
    .ram_wr_cmd_cache(ram_wr_cmd_cache),
    .ram_wr_cmd_prot(ram_wr_cmd_prot),
    .ram_wr_cmd_qos(ram_wr_cmd_qos),
    .ram_wr_cmd_region(ram_wr_cmd_region),
    .ram_wr_cmd_auser(ram_wr_cmd_auser),
    .ram_wr_cmd_data(ram_cmd_wr_data),
    .ram_wr_cmd_strb(ram_cmd_wr_strb),
    .ram_wr_cmd_user(ram_cmd_wr_user),
    .ram_wr_cmd_en(ram_wr_cmd_en),
    .ram_wr_cmd_last(ram_wr_cmd_last),
    .ram_wr_cmd_ready(ram_wr_cmd_ready)
);

taxi_axi_ram_if_rd #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .ID_W(ID_W),
    .AUSER_W(AUSER_W),
    .RUSER_W(RUSER_W),
    .PIPELINE_OUTPUT(PIPELINE_OUTPUT)
)
rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4 slave interface
     */
    .s_axi_rd(s_axi_rd),

    /*
     * RAM interface
     */
    .ram_rd_cmd_id(ram_rd_cmd_id),
    .ram_rd_cmd_addr(ram_rd_cmd_addr),
    .ram_rd_cmd_lock(ram_rd_cmd_lock),
    .ram_rd_cmd_cache(ram_rd_cmd_cache),
    .ram_rd_cmd_prot(ram_rd_cmd_prot),
    .ram_rd_cmd_qos(ram_rd_cmd_qos),
    .ram_rd_cmd_region(ram_rd_cmd_region),
    .ram_rd_cmd_auser(ram_rd_cmd_auser),
    .ram_rd_cmd_en(ram_rd_cmd_en),
    .ram_rd_cmd_last(ram_rd_cmd_last),
    .ram_rd_cmd_ready(ram_rd_cmd_ready),
    .ram_rd_resp_id(ram_rd_resp_id),
    .ram_rd_resp_data(ram_rd_resp_data),
    .ram_rd_resp_last(ram_rd_resp_last),
    .ram_rd_resp_user(ram_rd_resp_user),
    .ram_rd_resp_valid(ram_rd_resp_valid),
    .ram_rd_resp_ready(ram_rd_resp_ready)
);

// arbitration
logic read_eligible;
logic write_eligible;

logic write_en;
logic read_en;

logic last_read_reg = 1'b0, last_read_next;
logic transaction_reg = 1'b0, transaction_next;

assign ram_cmd_wr_en = write_en;
assign ram_cmd_rd_en = read_en;

assign ram_cmd_id     = ram_cmd_rd_en ? ram_rd_cmd_id     : ram_wr_cmd_id;
assign ram_cmd_addr   = ram_cmd_rd_en ? ram_rd_cmd_addr   : ram_wr_cmd_addr;
assign ram_cmd_lock   = ram_cmd_rd_en ? ram_rd_cmd_lock   : ram_wr_cmd_lock;
assign ram_cmd_cache  = ram_cmd_rd_en ? ram_rd_cmd_cache  : ram_wr_cmd_cache;
assign ram_cmd_prot   = ram_cmd_rd_en ? ram_rd_cmd_prot   : ram_wr_cmd_prot;
assign ram_cmd_qos    = ram_cmd_rd_en ? ram_rd_cmd_qos    : ram_wr_cmd_qos;
assign ram_cmd_region = ram_cmd_rd_en ? ram_rd_cmd_region : ram_wr_cmd_region;
assign ram_cmd_auser  = ram_cmd_rd_en ? ram_rd_cmd_auser  : ram_wr_cmd_auser;
assign ram_cmd_last   = ram_cmd_rd_en ? ram_rd_cmd_last   : ram_wr_cmd_last;

assign ram_wr_cmd_ready = ram_cmd_ready && write_en;
assign ram_rd_cmd_ready = ram_cmd_ready && read_en;

always_comb begin
    write_en = 1'b0;
    read_en = 1'b0;

    last_read_next = last_read_reg;
    transaction_next = transaction_reg;

    write_eligible = ram_wr_cmd_en && ram_cmd_ready;
    read_eligible = ram_rd_cmd_en && ram_cmd_ready;

    if (write_eligible && (!read_eligible || last_read_reg || (!INTERLEAVE && transaction_reg)) && (INTERLEAVE || !transaction_reg || !last_read_reg)) begin
        last_read_next = 1'b0;
        transaction_next = !ram_wr_cmd_last;

        write_en = 1'b1;
    end else if (read_eligible && (INTERLEAVE || !transaction_reg || last_read_reg)) begin
        last_read_next = 1'b1;
        transaction_next = !ram_rd_cmd_last;

        read_en = 1'b1;
    end
end

always_ff @(posedge clk) begin
    last_read_reg <= last_read_next;
    transaction_reg <= transaction_next;

    if (rst) begin
        last_read_reg <= 1'b0;
        transaction_reg <= 1'b0;
    end
end

endmodule

`resetall
