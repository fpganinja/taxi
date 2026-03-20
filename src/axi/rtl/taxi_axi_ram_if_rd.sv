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
 * AXI4 RAM read interface
 */
module taxi_axi_ram_if_rd #
(
    // Width of data bus in bits
    parameter DATA_W = 32,
    // Width of address bus in bits
    parameter ADDR_W = 16,
    // Width of wstrb (width of data bus in words)
    parameter STRB_W = (DATA_W/8),
    // Width of ID signal
    parameter ID_W = 8,
    // Width of auser signal
    parameter AUSER_W = 1,
    // Width of ruser signal
    parameter RUSER_W = 1,
    // Extra pipeline register on output
    parameter logic PIPELINE_OUTPUT = 1'b0
)
(
    input  wire logic                clk,
    input  wire logic                rst,

    /*
     * AXI4 slave interface
     */
    taxi_axi_if.rd_slv               s_axi_rd,

    /*
     * RAM interface
     */
    output wire logic [ID_W-1:0]     ram_rd_cmd_id,
    output wire logic [ADDR_W-1:0]   ram_rd_cmd_addr,
    output wire logic                ram_rd_cmd_lock,
    output wire logic [3:0]          ram_rd_cmd_cache,
    output wire logic [2:0]          ram_rd_cmd_prot,
    output wire logic [3:0]          ram_rd_cmd_qos,
    output wire logic [3:0]          ram_rd_cmd_region,
    output wire logic [AUSER_W-1:0]  ram_rd_cmd_auser,
    output wire logic                ram_rd_cmd_en,
    output wire logic                ram_rd_cmd_last,
    input  wire logic                ram_rd_cmd_ready,
    input  wire logic [ID_W-1:0]     ram_rd_resp_id,
    input  wire logic [DATA_W-1:0]   ram_rd_resp_data,
    input  wire logic                ram_rd_resp_last,
    input  wire logic [RUSER_W-1:0]  ram_rd_resp_user,
    input  wire logic                ram_rd_resp_valid,
    output wire logic                ram_rd_resp_ready
);

// extract parameters
localparam logic AUSER_EN = s_axi_rd.ARUSER_EN;
localparam logic RUSER_EN = s_axi_rd.RUSER_EN;

localparam VALID_ADDR_W = ADDR_W - $clog2(STRB_W);
localparam BYTE_LANES = STRB_W;
localparam BYTE_W = DATA_W/BYTE_LANES;

// check configuration
if (BYTE_W * STRB_W != DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (2**$clog2(BYTE_LANES) != BYTE_LANES)
    $fatal(0, "Error: AXI word width must be even power of two (instance %m)");

if (s_axi_rd.ADDR_W < ADDR_W)
    $fatal(0, "Error: AXI address width is insufficient (instance %m)");

if (s_axi_rd.ARUSER_EN && s_axi_rd.ARUSER_W > AUSER_W)
    $fatal(0, "Error: AUESR_W setting is insufficient (instance %m)");

if (s_axi_rd.RUSER_EN && s_axi_rd.RUSER_W > RUSER_W)
    $fatal(0, "Error: RUESR_W setting is insufficient (instance %m)");

typedef enum logic [0:0] {
    STATE_IDLE,
    STATE_BURST
} state_t;

state_t state_reg = STATE_IDLE, state_next;

logic [ID_W-1:0] read_id_reg = '0, read_id_next;
logic [ADDR_W-1:0] read_addr_reg = '0, read_addr_next;
logic read_lock_reg = 1'b0, read_lock_next;
logic [3:0] read_cache_reg = 4'd0, read_cache_next;
logic [2:0] read_prot_reg = 3'd0, read_prot_next;
logic [3:0] read_qos_reg = 4'd0, read_qos_next;
logic [3:0] read_region_reg = 4'd0, read_region_next;
logic [AUSER_W-1:0] read_auser_reg = '0, read_auser_next;
logic read_addr_valid_reg = 1'b0, read_addr_valid_next;
logic read_last_reg = 1'b0, read_last_next;
logic [7:0] read_count_reg = 8'd0, read_count_next;
logic [2:0] read_size_reg = 3'd0, read_size_next;
logic [1:0] read_burst_reg = 2'd0, read_burst_next;

logic s_axi_arready_reg = 1'b0, s_axi_arready_next;
logic [ID_W-1:0] s_axi_rid_pipe_reg = '0;
logic [DATA_W-1:0] s_axi_rdata_pipe_reg = '0;
logic s_axi_rlast_pipe_reg = 1'b0;
logic [RUSER_W-1:0] s_axi_ruser_pipe_reg = '0;
logic s_axi_rvalid_pipe_reg = 1'b0;

assign s_axi_rd.arready = s_axi_arready_reg;
assign s_axi_rd.rid = PIPELINE_OUTPUT ? s_axi_rid_pipe_reg : ram_rd_resp_id;
assign s_axi_rd.rdata = PIPELINE_OUTPUT ? s_axi_rdata_pipe_reg : ram_rd_resp_data;
assign s_axi_rd.rresp = 2'b00;
assign s_axi_rd.rlast = PIPELINE_OUTPUT ? s_axi_rlast_pipe_reg : ram_rd_resp_last;
assign s_axi_rd.ruser = PIPELINE_OUTPUT ? s_axi_ruser_pipe_reg : ram_rd_resp_user;
assign s_axi_rd.rvalid = PIPELINE_OUTPUT ? s_axi_rvalid_pipe_reg : ram_rd_resp_valid;

assign ram_rd_cmd_id = read_id_reg;
assign ram_rd_cmd_addr = read_addr_reg;
assign ram_rd_cmd_lock = read_lock_reg;
assign ram_rd_cmd_cache = read_cache_reg;
assign ram_rd_cmd_prot = read_prot_reg;
assign ram_rd_cmd_qos = read_qos_reg;
assign ram_rd_cmd_region = read_region_reg;
assign ram_rd_cmd_auser = AUSER_EN ? read_auser_reg : '0;
assign ram_rd_cmd_en = read_addr_valid_reg;
assign ram_rd_cmd_last = read_last_reg;

assign ram_rd_resp_ready = s_axi_rd.rready || (PIPELINE_OUTPUT && !s_axi_rvalid_pipe_reg);

always_comb begin
    state_next = STATE_IDLE;

    read_id_next = read_id_reg;
    read_addr_next = read_addr_reg;
    read_lock_next = read_lock_reg;
    read_cache_next = read_cache_reg;
    read_prot_next = read_prot_reg;
    read_qos_next = read_qos_reg;
    read_region_next = read_region_reg;
    read_auser_next = read_auser_reg;
    read_addr_valid_next = read_addr_valid_reg && !ram_rd_cmd_ready;
    read_last_next = read_last_reg;
    read_count_next = read_count_reg;
    read_size_next = read_size_reg;
    read_burst_next = read_burst_reg;

    s_axi_arready_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            s_axi_arready_next = 1'b1;

            if (s_axi_rd.arready && s_axi_rd.arvalid) begin
                read_id_next = s_axi_rd.arid;
                read_addr_next = ADDR_W'(s_axi_rd.araddr);
                read_lock_next = s_axi_rd.arlock;
                read_cache_next = s_axi_rd.arcache;
                read_prot_next = s_axi_rd.arprot;
                read_qos_next = s_axi_rd.arqos;
                read_region_next = s_axi_rd.arregion;
                read_auser_next = AUSER_W'(s_axi_rd.aruser);
                read_count_next = s_axi_rd.arlen;
                read_size_next = s_axi_rd.arsize <= 3'($clog2(STRB_W)) ? s_axi_rd.arsize : 3'($clog2(STRB_W));
                read_burst_next = s_axi_rd.arburst;

                s_axi_arready_next = 1'b0;
                read_last_next = read_count_next == 0;
                read_addr_valid_next = 1'b1;
                state_next = STATE_BURST;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_BURST: begin
            if (ram_rd_cmd_ready && ram_rd_cmd_en) begin
                if (read_burst_reg != 2'b00) begin
                    read_addr_next = read_addr_reg + (1 << read_size_reg);
                end
                read_count_next = read_count_reg - 1;
                read_last_next = read_count_next == 0;
                if (read_count_reg > 0) begin
                    read_addr_valid_next = 1'b1;
                    state_next = STATE_BURST;
                end else begin
                    s_axi_arready_next = 1'b1;
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_BURST;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    read_id_reg <= read_id_next;
    read_addr_reg <= read_addr_next;
    read_lock_reg <= read_lock_next;
    read_cache_reg <= read_cache_next;
    read_prot_reg <= read_prot_next;
    read_qos_reg <= read_qos_next;
    read_region_reg <= read_region_next;
    read_auser_reg <= read_auser_next;
    read_addr_valid_reg <= read_addr_valid_next;
    read_last_reg <= read_last_next;
    read_count_reg <= read_count_next;
    read_size_reg <= read_size_next;
    read_burst_reg <= read_burst_next;

    s_axi_arready_reg <= s_axi_arready_next;

    if (!s_axi_rvalid_pipe_reg || s_axi_rd.rready) begin
        s_axi_rid_pipe_reg <= ram_rd_resp_id;
        s_axi_rdata_pipe_reg <= ram_rd_resp_data;
        s_axi_rlast_pipe_reg <= ram_rd_resp_last;
        s_axi_ruser_pipe_reg <= ram_rd_resp_user;
        s_axi_rvalid_pipe_reg <= ram_rd_resp_valid;
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        read_addr_valid_reg <= 1'b0;

        s_axi_arready_reg <= 1'b0;
        s_axi_rvalid_pipe_reg <= 1'b0;
    end
end

endmodule

`resetall
