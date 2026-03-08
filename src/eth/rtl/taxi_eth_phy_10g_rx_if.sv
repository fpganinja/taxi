// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2018-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet PHY RX IF
 */
module taxi_eth_phy_10g_rx_if #
(
    parameter DATA_W = 64,
    parameter HDR_W = 2,
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic SCRAMBLER_DISABLE = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 1,
    parameter BITSLIP_LOW_CYCLES = 7,
    parameter COUNT_125US = 125000/6.4
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * 10GBASE-R encoded interface
     */
    output wire logic [DATA_W-1:0]  encoded_rx_data,
    output wire logic               encoded_rx_data_valid,
    output wire logic [HDR_W-1:0]   encoded_rx_hdr,
    output wire logic               encoded_rx_hdr_valid,

    /*
     * SERDES interface
     */
    input  wire logic [DATA_W-1:0]  serdes_rx_data,
    input  wire logic               serdes_rx_data_valid,
    input  wire logic [HDR_W-1:0]   serdes_rx_hdr,
    input  wire logic               serdes_rx_hdr_valid,
    output wire logic               serdes_rx_bitslip,
    output wire logic               serdes_rx_reset_req,

    /*
     * Status
     */
    input  wire logic               rx_bad_block,
    input  wire logic               rx_sequence_error,
    output wire logic [6:0]         rx_error_count,
    output wire logic               rx_block_lock,
    output wire logic               rx_high_ber,
    output wire logic               rx_status,

    /*
     * Configuration
     */
    input  wire logic               cfg_rx_prbs31_enable
);

localparam USE_HDR_VLD = GBX_IF_EN || DATA_W != 64;

// check configuration
if (DATA_W != 32 && DATA_W != 64)
    $fatal(0, "Error: Interface width must be 32 or 64");

if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2");

wire [DATA_W-1:0] serdes_rx_data_rev, serdes_rx_data_int;
wire serdes_rx_data_valid_int;
wire [HDR_W-1:0] serdes_rx_hdr_rev, serdes_rx_hdr_int;
wire serdes_rx_hdr_valid_int;

if (BIT_REVERSE) begin
    for (genvar n = 0; n < DATA_W; n = n + 1) begin
        assign serdes_rx_data_rev[n] = serdes_rx_data[DATA_W-n-1];
    end

    for (genvar n = 0; n < HDR_W; n = n + 1) begin
        assign serdes_rx_hdr_rev[n] = serdes_rx_hdr[HDR_W-n-1];
    end
end else begin
    assign serdes_rx_data_rev = serdes_rx_data;
    assign serdes_rx_hdr_rev = serdes_rx_hdr;
end

if (SERDES_PIPELINE > 0) begin
    (* srl_style = "register" *)
    logic [DATA_W-1:0] serdes_rx_data_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic serdes_rx_data_valid_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic [HDR_W-1:0] serdes_rx_hdr_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic serdes_rx_hdr_valid_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};

    for (genvar n = 0; n < SERDES_PIPELINE; n = n + 1) begin
        always_ff @(posedge clk) begin
            serdes_rx_data_pipe_reg[n] <= n == 0 ? serdes_rx_data_rev : serdes_rx_data_pipe_reg[n-1];
            serdes_rx_data_valid_pipe_reg[n] <= n == 0 ? serdes_rx_data_valid : serdes_rx_data_valid_pipe_reg[n-1];
            serdes_rx_hdr_pipe_reg[n] <= n == 0 ? serdes_rx_hdr_rev : serdes_rx_hdr_pipe_reg[n-1];
            serdes_rx_hdr_valid_pipe_reg[n] <= n == 0 ? serdes_rx_hdr_valid : serdes_rx_hdr_valid_pipe_reg[n-1];
        end
    end

    assign serdes_rx_data_int = serdes_rx_data_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_rx_data_valid_int = GBX_IF_EN ? serdes_rx_data_valid_pipe_reg[SERDES_PIPELINE-1] : 1'b1;
    assign serdes_rx_hdr_int = serdes_rx_hdr_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_rx_hdr_valid_int = USE_HDR_VLD ? serdes_rx_hdr_valid_pipe_reg[SERDES_PIPELINE-1] : 1'b1;
end else begin
    assign serdes_rx_data_int = serdes_rx_data_rev;
    assign serdes_rx_data_valid_int = GBX_IF_EN ? serdes_rx_data_valid : 1'b1;
    assign serdes_rx_hdr_int = serdes_rx_hdr_rev;
    assign serdes_rx_hdr_valid_int = USE_HDR_VLD ? serdes_rx_hdr_valid : 1'b1;
end

wire [DATA_W-1:0] descrambled_rx_data;

logic [DATA_W-1:0] encoded_rx_data_reg = '0;
logic encoded_rx_data_valid_reg = 1'b0;
logic [HDR_W-1:0] encoded_rx_hdr_reg = '0;
logic encoded_rx_hdr_valid_reg = 1'b0;

logic [57:0] scrambler_state_reg = '1;
wire [57:0] scrambler_state;

logic [30:0] prbs31_state_reg = '1;
wire [30:0] prbs31_state;
wire [DATA_W+HDR_W-1:0] prbs31_data;
logic [DATA_W+HDR_W-1:0] prbs31_data_reg = '0;

logic [6:0] rx_error_count_reg = '0;
logic [5:0] rx_error_count_1_reg = '0;
logic [5:0] rx_error_count_2_reg = '0;
logic [5:0] rx_error_count_1_temp;
logic [5:0] rx_error_count_2_temp;

taxi_lfsr #(
    .LFSR_W(58),
    .LFSR_POLY(58'h8000000001),
    .LFSR_GALOIS(0),
    .LFSR_FEED_FORWARD(1),
    .REVERSE(1),
    .DATA_W(DATA_W),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b1)
)
descrambler_inst (
    .data_in(serdes_rx_data_int),
    .state_in(scrambler_state_reg),
    .data_out(descrambled_rx_data),
    .state_out(scrambler_state)
);

always_ff @(posedge clk) begin
    if (!GBX_IF_EN || serdes_rx_data_valid_int) begin
        scrambler_state_reg <= scrambler_state;
    end
end

taxi_lfsr #(
    .LFSR_W(31),
    .LFSR_POLY(31'h10000001),
    .LFSR_GALOIS(0),
    .LFSR_FEED_FORWARD(1),
    .REVERSE(1),
    .DATA_W(DATA_W+HDR_W),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b1)
)
prbs31_check_inst (
    .data_in(~{serdes_rx_data_int, serdes_rx_hdr_int}),
    .state_in(prbs31_state_reg),
    .data_out(prbs31_data),
    .state_out(prbs31_state)
);

always_comb begin
    rx_error_count_1_temp = '0;
    rx_error_count_2_temp = '0;
    for (integer i = 0; i < DATA_W+HDR_W; i = i + 1) begin
        if (i[0]) begin
            rx_error_count_1_temp = rx_error_count_1_temp + 6'(prbs31_data_reg[i]);
        end else begin
            rx_error_count_2_temp = rx_error_count_2_temp + 6'(prbs31_data_reg[i]);
        end
    end
end

always_ff @(posedge clk) begin
    encoded_rx_data_reg <= SCRAMBLER_DISABLE ? serdes_rx_data_int : descrambled_rx_data;
    encoded_rx_data_valid_reg <= serdes_rx_data_valid_int;
    encoded_rx_hdr_reg <= serdes_rx_hdr_int;
    encoded_rx_hdr_valid_reg <= serdes_rx_hdr_valid_int;

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
assign encoded_rx_data_valid = GBX_IF_EN ? encoded_rx_data_valid_reg : 1'b1;
assign encoded_rx_hdr = encoded_rx_hdr_reg;
assign encoded_rx_hdr_valid = USE_HDR_VLD ? encoded_rx_hdr_valid_reg : 1'b1;

assign rx_error_count = rx_error_count_reg;

wire serdes_rx_bitslip_int;
wire serdes_rx_reset_req_int;
assign serdes_rx_bitslip = serdes_rx_bitslip_int && !(PRBS31_EN && cfg_rx_prbs31_enable);
assign serdes_rx_reset_req = serdes_rx_reset_req_int && !(PRBS31_EN && cfg_rx_prbs31_enable);

taxi_eth_phy_10g_rx_frame_sync #(
    .HDR_W(HDR_W),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES)
)
eth_phy_10g_rx_frame_sync_inst (
    .clk(clk),
    .rst(rst),
    .serdes_rx_hdr(serdes_rx_hdr_int),
    .serdes_rx_hdr_valid(serdes_rx_hdr_valid_int),
    .serdes_rx_bitslip(serdes_rx_bitslip_int),
    .rx_block_lock(rx_block_lock)
);

taxi_eth_phy_10g_rx_ber_mon #(
    .HDR_W(HDR_W),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_ber_mon_inst (
    .clk(clk),
    .rst(rst),
    .serdes_rx_hdr(serdes_rx_hdr_int),
    .serdes_rx_hdr_valid(serdes_rx_hdr_valid_int),
    .rx_high_ber(rx_high_ber)
);

taxi_eth_phy_10g_rx_watchdog #(
    .HDR_W(HDR_W),
    .COUNT_125US(COUNT_125US)
)
eth_phy_10g_rx_watchdog_inst (
    .clk(clk),
    .rst(rst),
    .serdes_rx_hdr(serdes_rx_hdr_int),
    .serdes_rx_hdr_valid(serdes_rx_hdr_valid_int),
    .serdes_rx_reset_req(serdes_rx_reset_req_int),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status)
);

endmodule

`resetall
