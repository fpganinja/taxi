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
 * 1000BASE-X Ethernet PHY RX IF
 */
module taxi_eth_phy_1g_basex_rx_if #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic DEC_8B10B_EN = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * 10GBASE-R encoded interface
     */
    output wire logic [DATA_W-1:0]  encoded_rx_data,
    output wire logic [CTRL_W-1:0]  encoded_rx_data_k,
    output wire logic               encoded_rx_data_valid,

    /*
     * SERDES interface
     */
    input  wire logic [DATA_W-1:0]  serdes_rx_data,
    input  wire logic [CTRL_W-1:0]  serdes_rx_data_k,
    input  wire logic               serdes_rx_data_valid,
    output wire logic               serdes_rx_reset_req,

    /*
     * Status
     */
    input  wire logic               rx_bad_block,
    input  wire logic               rx_sequence_error,
    output wire logic [4:0]         rx_error_count,
    output wire logic               rx_block_lock,
    output wire logic               rx_high_ber,
    output wire logic               rx_status,

    /*
     * Configuration
     */
    input  wire logic               cfg_rx_prbs31_enable
);

// check configuration
if (DATA_W != 8 && DATA_W != 16)
    $fatal(0, "Error: Interface width must be 8 or 16");

if (CTRL_W != DATA_W/8)
    $fatal(0, "Error: CTRL_W must be DATA_W/8");

wire [DATA_W-1:0] serdes_rx_data_rev, serdes_rx_data_int;
wire [CTRL_W-1:0] serdes_rx_data_k_rev, serdes_rx_data_k_int;
wire serdes_rx_data_valid_int;

if (BIT_REVERSE) begin
    for (genvar n = 0; n < DATA_W; n = n + 1) begin
        assign serdes_rx_data_rev[n] = serdes_rx_data[DATA_W-n-1];
    end
    for (genvar n = 0; n < CTRL_W; n = n + 1) begin
        assign serdes_rx_data_k_rev[n] = serdes_rx_data_k[CTRL_W-n-1];
    end
end else begin
    assign serdes_rx_data_rev = serdes_rx_data;
    assign serdes_rx_data_k_rev = serdes_rx_data_k;
end

if (SERDES_PIPELINE > 0) begin
    (* srl_style = "register" *)
    logic [DATA_W-1:0] serdes_rx_data_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic [CTRL_W-1:0] serdes_rx_data_k_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic serdes_rx_data_valid_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};

    for (genvar n = 0; n < SERDES_PIPELINE; n = n + 1) begin
        always_ff @(posedge clk) begin
            serdes_rx_data_pipe_reg[n] <= n == 0 ? serdes_rx_data_rev : serdes_rx_data_pipe_reg[n-1];
            serdes_rx_data_k_pipe_reg[n] <= n == 0 ? serdes_rx_data_k_rev : serdes_rx_data_k_pipe_reg[n-1];
            serdes_rx_data_valid_pipe_reg[n] <= n == 0 ? serdes_rx_data_valid : serdes_rx_data_valid_pipe_reg[n-1];
        end
    end

    assign serdes_rx_data_int = serdes_rx_data_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_rx_data_k_int = serdes_rx_data_k_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_rx_data_valid_int = GBX_IF_EN ? serdes_rx_data_valid_pipe_reg[SERDES_PIPELINE-1] : 1'b1;
end else begin
    assign serdes_rx_data_int = serdes_rx_data_rev;
    assign serdes_rx_data_k_int = serdes_rx_data_k_rev;
    assign serdes_rx_data_valid_int = GBX_IF_EN ? serdes_rx_data_valid : 1'b1;
end

logic [DATA_W-1:0] encoded_rx_data_reg = '0;
logic [CTRL_W-1:0] encoded_rx_data_k_reg = '0;
logic encoded_rx_data_valid_reg = 1'b0;

logic [30:0] prbs31_state_reg = '1;
wire [30:0] prbs31_state;
wire [DATA_W-1:0] prbs31_data;
logic [DATA_W-1:0] prbs31_data_reg = '0;

logic [4:0] rx_error_count_reg = '0;
logic [3:0] rx_error_count_1_reg = '0;
logic [3:0] rx_error_count_2_reg = '0;
logic [3:0] rx_error_count_1_temp;
logic [3:0] rx_error_count_2_temp;

taxi_lfsr #(
    .LFSR_W(31),
    .LFSR_POLY(31'h10000001),
    .LFSR_GALOIS(0),
    .LFSR_FEED_FORWARD(1),
    .REVERSE(1),
    .DATA_W(DATA_W),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b1)
)
prbs31_check_inst (
    .data_in(~serdes_rx_data_int),
    .state_in(prbs31_state_reg),
    .data_out(prbs31_data),
    .state_out(prbs31_state)
);

always_comb begin
    rx_error_count_1_temp = '0;
    rx_error_count_2_temp = '0;
    for (integer i = 0; i < DATA_W; i = i + 1) begin
        if (i[0]) begin
            rx_error_count_1_temp = rx_error_count_1_temp + 4'(prbs31_data_reg[i]);
        end else begin
            rx_error_count_2_temp = rx_error_count_2_temp + 4'(prbs31_data_reg[i]);
        end
    end
end

always_ff @(posedge clk) begin
    encoded_rx_data_reg <= serdes_rx_data_int;
    encoded_rx_data_k_reg <= serdes_rx_data_k_int;
    encoded_rx_data_valid_reg <= serdes_rx_data_valid_int;

    if (PRBS31_EN) begin
        if (cfg_rx_prbs31_enable && (!GBX_IF_EN || serdes_rx_data_valid_int)) begin
            prbs31_state_reg <= prbs31_state;
            prbs31_data_reg <= prbs31_data;
        end else begin
            prbs31_data_reg <= '0;
        end

        rx_error_count_1_reg <= rx_error_count_1_temp;
        rx_error_count_2_reg <= rx_error_count_2_temp;
        rx_error_count_reg <= rx_error_count_1_reg + rx_error_count_2_reg;
    end else begin
        rx_error_count_reg <= '0;
    end
end

assign encoded_rx_data = encoded_rx_data_reg;
assign encoded_rx_data_k = encoded_rx_data_k_reg;
assign encoded_rx_data_valid = GBX_IF_EN ? encoded_rx_data_valid_reg : 1'b1;

assign rx_error_count = rx_error_count_reg;

wire serdes_rx_reset_req_int;
assign serdes_rx_reset_req = serdes_rx_reset_req_int && !(PRBS31_EN && cfg_rx_prbs31_enable);

assign serdes_rx_reset_req_int = 1'b0;

assign rx_block_lock = 1'b1;
assign rx_high_ber = 1'b1;
assign rx_status = 1'b1;

endmodule

`resetall
