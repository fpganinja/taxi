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
 * AXI4 RAM write interface
 */
module taxi_axi_ram_if_wr #
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
    // Width of wuser signal
    parameter WUSER_W = 1
)
(
    input  wire logic                clk,
    input  wire logic                rst,

    /*
     * AXI4 slave interface
     */
    taxi_axi_if.wr_slv               s_axi_wr,

    /*
     * RAM interface
     */
    output wire logic [ID_W-1:0]     ram_wr_cmd_id,
    output wire logic [ADDR_W-1:0]   ram_wr_cmd_addr,
    output wire logic                ram_wr_cmd_lock,
    output wire logic [3:0]          ram_wr_cmd_cache,
    output wire logic [2:0]          ram_wr_cmd_prot,
    output wire logic [3:0]          ram_wr_cmd_qos,
    output wire logic [3:0]          ram_wr_cmd_region,
    output wire logic [AUSER_W-1:0]  ram_wr_cmd_auser,
    output wire logic [DATA_W-1:0]   ram_wr_cmd_data,
    output wire logic [STRB_W-1:0]   ram_wr_cmd_strb,
    output wire logic [WUSER_W-1:0]  ram_wr_cmd_user,
    output wire logic                ram_wr_cmd_en,
    output wire logic                ram_wr_cmd_last,
    input  wire logic                ram_wr_cmd_ready
);

// extract parameters
localparam logic AUSER_EN = s_axi_wr.AWUSER_EN;
localparam logic WUSER_EN = s_axi_wr.WUSER_EN;

localparam VALID_ADDR_W = ADDR_W - $clog2(STRB_W);
localparam BYTE_LANES = STRB_W;
localparam BYTE_W = DATA_W/BYTE_LANES;

// check configuration
if (BYTE_W * STRB_W != DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (2**$clog2(BYTE_LANES) != BYTE_LANES)
    $fatal(0, "Error: AXI word width must be even power of two (instance %m)");

if (s_axi_wr.ADDR_W < ADDR_W)
    $fatal(0, "Error: AXI address width is insufficient (instance %m)");

if (s_axi_wr.AWUSER_EN && s_axi_wr.AWUSER_W > AUSER_W)
    $fatal(0, "Error: AUESR_W setting is insufficient (instance %m)");

if (s_axi_wr.WUSER_EN && s_axi_wr.WUSER_W > WUSER_W)
    $fatal(0, "Error: WUESR_W setting is insufficient (instance %m)");

typedef enum logic [1:0] {
    STATE_IDLE,
    STATE_BURST,
    STATE_RESP
} state_t;

state_t state_reg = STATE_IDLE, state_next;

logic [ID_W-1:0] write_id_reg = '0, write_id_next;
logic [ADDR_W-1:0] write_addr_reg = '0, write_addr_next;
logic write_lock_reg = 1'b0, write_lock_next;
logic [3:0] write_cache_reg = 4'd0, write_cache_next;
logic [2:0] write_prot_reg = 3'd0, write_prot_next;
logic [3:0] write_qos_reg = 4'd0, write_qos_next;
logic [3:0] write_region_reg = 4'd0, write_region_next;
logic [AUSER_W-1:0] write_auser_reg = '0, write_auser_next;
logic write_addr_valid_reg = 1'b0, write_addr_valid_next;
logic write_last_reg = 1'b0, write_last_next;
logic [7:0] write_count_reg = 8'd0, write_count_next;
logic [2:0] write_size_reg = 3'd0, write_size_next;
logic [1:0] write_burst_reg = 2'd0, write_burst_next;

logic s_axi_awready_reg = 1'b0, s_axi_awready_next;
logic [ID_W-1:0] s_axi_bid_reg = '0, s_axi_bid_next;
logic s_axi_bvalid_reg = 1'b0, s_axi_bvalid_next;

assign s_axi_wr.awready = s_axi_awready_reg;
assign s_axi_wr.wready = write_addr_valid_reg && ram_wr_cmd_ready;
assign s_axi_wr.bid = s_axi_bid_reg;
assign s_axi_wr.bresp = 2'b00;
assign s_axi_wr.buser = '0;
assign s_axi_wr.bvalid = s_axi_bvalid_reg;

assign ram_wr_cmd_id = write_id_reg;
assign ram_wr_cmd_addr = write_addr_reg;
assign ram_wr_cmd_lock = write_lock_reg;
assign ram_wr_cmd_cache = write_cache_reg;
assign ram_wr_cmd_prot = write_prot_reg;
assign ram_wr_cmd_qos = write_qos_reg;
assign ram_wr_cmd_region = write_region_reg;
assign ram_wr_cmd_auser = AUSER_EN ? write_auser_reg : '0;
assign ram_wr_cmd_data = s_axi_wr.wdata;
assign ram_wr_cmd_strb = s_axi_wr.wstrb;
assign ram_wr_cmd_user = WUSER_EN ? s_axi_wr.wuser : '0;
assign ram_wr_cmd_en = write_addr_valid_reg && s_axi_wr.wvalid;
assign ram_wr_cmd_last = write_last_reg;

always_comb begin
    state_next = STATE_IDLE;

    write_id_next = write_id_reg;
    write_addr_next = write_addr_reg;
    write_lock_next = write_lock_reg;
    write_cache_next = write_cache_reg;
    write_prot_next = write_prot_reg;
    write_qos_next = write_qos_reg;
    write_region_next = write_region_reg;
    write_auser_next = write_auser_reg;
    write_addr_valid_next = write_addr_valid_reg;
    write_last_next = write_last_reg;
    write_count_next = write_count_reg;
    write_size_next = write_size_reg;
    write_burst_next = write_burst_reg;

    s_axi_awready_next = 1'b0;
    s_axi_bid_next = s_axi_bid_reg;
    s_axi_bvalid_next = s_axi_bvalid_reg && !s_axi_wr.bready;

    case (state_reg)
        STATE_IDLE: begin
            s_axi_awready_next = 1'b1;

            if (s_axi_wr.awready && s_axi_wr.awvalid) begin
                write_id_next = s_axi_wr.awid;
                write_addr_next = ADDR_W'(s_axi_wr.awaddr);
                write_lock_next = s_axi_wr.awlock;
                write_cache_next = s_axi_wr.awcache;
                write_prot_next = s_axi_wr.awprot;
                write_qos_next = s_axi_wr.awqos;
                write_region_next = s_axi_wr.awregion;
                write_auser_next = AUSER_W'(s_axi_wr.awuser);
                write_count_next = s_axi_wr.awlen;
                write_size_next = s_axi_wr.awsize <= 3'($clog2(STRB_W)) ? s_axi_wr.awsize : 3'($clog2(STRB_W));
                write_burst_next = s_axi_wr.awburst;

                write_addr_valid_next = 1'b1;
                s_axi_awready_next = 1'b0;
                if (s_axi_wr.awlen > 0) begin
                    write_last_next = 1'b0;
                end else begin
                    write_last_next = 1'b1;
                end
                state_next = STATE_BURST;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_BURST: begin
            if (s_axi_wr.wready && s_axi_wr.wvalid) begin
                if (write_burst_reg != 2'b00) begin
                    write_addr_next = write_addr_reg + (1 << write_size_reg);
                end
                write_count_next = write_count_reg - 1;
                write_last_next = write_count_next == 0;
                if (write_count_reg > 0) begin
                    write_addr_valid_next = 1'b1;
                    state_next = STATE_BURST;
                end else begin
                    write_addr_valid_next = 1'b0;
                    if (s_axi_wr.bready || !s_axi_wr.bvalid) begin
                        s_axi_bid_next = write_id_reg;
                        s_axi_bvalid_next = 1'b1;
                        s_axi_awready_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_RESP;
                    end
                end
            end else begin
                state_next = STATE_BURST;
            end
        end
        STATE_RESP: begin
            if (s_axi_wr.bready || !s_axi_wr.bvalid) begin
                s_axi_bid_next = write_id_reg;
                s_axi_bvalid_next = 1'b1;
                s_axi_awready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_RESP;
            end
        end
        default: begin
            // unknown state
            state_next = STATE_IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    write_id_reg <= write_id_next;
    write_addr_reg <= write_addr_next;
    write_lock_reg <= write_lock_next;
    write_cache_reg <= write_cache_next;
    write_prot_reg <= write_prot_next;
    write_qos_reg <= write_qos_next;
    write_region_reg <= write_region_next;
    write_auser_reg <= write_auser_next;
    write_addr_valid_reg <= write_addr_valid_next;
    write_last_reg <= write_last_next;
    write_count_reg <= write_count_next;
    write_size_reg <= write_size_next;
    write_burst_reg <= write_burst_next;

    s_axi_awready_reg <= s_axi_awready_next;
    s_axi_bid_reg <= s_axi_bid_next;
    s_axi_bvalid_reg <= s_axi_bvalid_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        write_addr_valid_reg <= 1'b0;

        s_axi_awready_reg <= 1'b0;
        s_axi_bvalid_reg <= 1'b0;
    end
end

endmodule

`resetall
