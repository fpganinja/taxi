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
 * 1000BASE-X Ethernet PHY TX IF
 */
module taxi_eth_phy_1g_basex_tx_if #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic ENC_8B10B_EN = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter SERDES_PIPELINE = 0
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * 1000BASE-X encoded interface
     */
    input  wire logic [DATA_W-1:0]  encoded_tx_data,
    input  wire logic [CTRL_W-1:0]  encoded_tx_data_k,
    input  wire logic [CTRL_W-1:0]  encoded_tx_data_dm,
    input  wire logic [CTRL_W-1:0]  encoded_tx_data_dv,
    input  wire logic               encoded_tx_data_valid = 1'b1,
    output wire logic               tx_gbx_req_sync,
    output wire logic               tx_gbx_req_stall,
    input  wire logic               tx_gbx_sync = 1'b0,

    /*
     * SERDES interface
     */
    output wire logic [DATA_W-1:0]  serdes_tx_data,
    output wire logic [CTRL_W-1:0]  serdes_tx_data_k,
    output wire logic [CTRL_W-1:0]  serdes_tx_data_dm,
    output wire logic [CTRL_W-1:0]  serdes_tx_data_dv,
    output wire logic               serdes_tx_data_valid,
    input  wire logic               serdes_tx_gbx_req_sync = 1'b0,
    input  wire logic               serdes_tx_gbx_req_stall = 1'b0,
    output wire logic               serdes_tx_gbx_sync,

    /*
     * Configuration
     */
    input  wire logic               cfg_tx_prbs31_enable
);

// check configuration
if (DATA_W != 8 && DATA_W != 16)
    $fatal(0, "Error: Interface width must be 8 or 16");

if (CTRL_W != DATA_W/8)
    $fatal(0, "Error: CTRL_W must be DATA_W/8");

assign tx_gbx_req_sync = GBX_IF_EN ? serdes_tx_gbx_req_sync : '0;
assign tx_gbx_req_stall = GBX_IF_EN ? serdes_tx_gbx_req_stall : '0;

logic [30:0] prbs31_state_reg = '1;
wire [30:0] prbs31_state;
wire [DATA_W-1:0] prbs31_data;

logic [DATA_W-1:0] serdes_tx_data_reg = '0;
logic [CTRL_W-1:0] serdes_tx_data_k_reg = '0;
logic [CTRL_W-1:0] serdes_tx_data_dm_reg = '0;
logic [CTRL_W-1:0] serdes_tx_data_dv_reg = '0;
logic serdes_tx_data_valid_reg = 1'b0;
logic serdes_tx_gbx_sync_reg = 1'b0;

wire [DATA_W-1:0] serdes_tx_data_int;
wire [CTRL_W-1:0] serdes_tx_data_k_int;
wire [CTRL_W-1:0] serdes_tx_data_dm_int;
wire [CTRL_W-1:0] serdes_tx_data_dv_int;

if (BIT_REVERSE) begin
    for (genvar n = 0; n < DATA_W; n = n + 1) begin
        assign serdes_tx_data_int[n] = serdes_tx_data_reg[DATA_W-n-1];
    end
    for (genvar n = 0; n < CTRL_W; n = n + 1) begin
        assign serdes_tx_data_k_int[n] = serdes_tx_data_k_reg[CTRL_W-n-1];
        assign serdes_tx_data_dm_int[n] = serdes_tx_data_dm_reg[CTRL_W-n-1];
        assign serdes_tx_data_dv_int[n] = serdes_tx_data_dv_reg[CTRL_W-n-1];
    end
end else begin
    assign serdes_tx_data_int = serdes_tx_data_reg;
    assign serdes_tx_data_k_int = serdes_tx_data_k_reg;
    assign serdes_tx_data_dm_int = serdes_tx_data_dm_reg;
    assign serdes_tx_data_dv_int = serdes_tx_data_dv_reg;
end

if (SERDES_PIPELINE > 0) begin
    (* srl_style = "register" *)
    logic [DATA_W-1:0] serdes_tx_data_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic [CTRL_W-1:0] serdes_tx_data_k_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic [CTRL_W-1:0] serdes_tx_data_dm_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic [CTRL_W-1:0] serdes_tx_data_dv_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic serdes_tx_data_valid_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};
    (* srl_style = "register" *)
    logic serdes_tx_gbx_sync_pipe_reg[SERDES_PIPELINE-1:0] = '{default: '0};

    for (genvar n = 0; n < SERDES_PIPELINE; n = n + 1) begin
        always_ff @(posedge clk) begin
            serdes_tx_data_pipe_reg[n] <= n == 0 ? serdes_tx_data_int : serdes_tx_data_pipe_reg[n-1];
            serdes_tx_data_k_pipe_reg[n] <= n == 0 ? serdes_tx_data_k_int : serdes_tx_data_k_pipe_reg[n-1];
            serdes_tx_data_dm_pipe_reg[n] <= n == 0 ? serdes_tx_data_dm_int : serdes_tx_data_dm_pipe_reg[n-1];
            serdes_tx_data_dv_pipe_reg[n] <= n == 0 ? serdes_tx_data_dv_int : serdes_tx_data_dv_pipe_reg[n-1];
            serdes_tx_data_valid_pipe_reg[n] <= n == 0 ? serdes_tx_data_valid_reg : serdes_tx_data_valid_pipe_reg[n-1];
            serdes_tx_gbx_sync_pipe_reg[n] <= n == 0 ? serdes_tx_gbx_sync_reg : serdes_tx_gbx_sync_pipe_reg[n-1];
        end
    end

    assign serdes_tx_data = serdes_tx_data_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_tx_data_k = serdes_tx_data_k_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_tx_data_dm = serdes_tx_data_dm_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_tx_data_dv = serdes_tx_data_dv_pipe_reg[SERDES_PIPELINE-1];
    assign serdes_tx_data_valid = GBX_IF_EN ? serdes_tx_data_valid_pipe_reg[SERDES_PIPELINE-1] : 1'b1;
    assign serdes_tx_gbx_sync = GBX_IF_EN ? serdes_tx_gbx_sync_pipe_reg[SERDES_PIPELINE-1] : 1'b0;
end else begin
    assign serdes_tx_data = serdes_tx_data_int;
    assign serdes_tx_data_k = serdes_tx_data_k_int;
    assign serdes_tx_data_dm = serdes_tx_data_dm_int;
    assign serdes_tx_data_dv = serdes_tx_data_dv_int;
    assign serdes_tx_data_valid = GBX_IF_EN ? serdes_tx_data_valid_reg : 1'b1;
    assign serdes_tx_gbx_sync = GBX_IF_EN ? serdes_tx_gbx_sync_reg : 1'b0;
end

taxi_lfsr #(
    .LFSR_W(31),
    .LFSR_POLY(31'h10000001),
    .LFSR_GALOIS(0),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_W(DATA_W),
    .DATA_IN_EN(1'b0),
    .DATA_OUT_EN(1'b1)
)
prbs31_gen_inst (
    .data_in('0),
    .state_in(prbs31_state_reg),
    .data_out(prbs31_data),
    .state_out(prbs31_state)
);

always_ff @(posedge clk) begin
    if (PRBS31_EN && cfg_tx_prbs31_enable) begin
        if (!GBX_IF_EN || encoded_tx_data_valid) begin
            prbs31_state_reg <= prbs31_state;
        end

        serdes_tx_data_reg <= ~prbs31_data;
        serdes_tx_data_k_reg <= '0;
        serdes_tx_data_dm_reg <= '0;
        serdes_tx_data_dv_reg <= '0;
    end else begin
        serdes_tx_data_reg <= encoded_tx_data;
        serdes_tx_data_k_reg <= encoded_tx_data_k;
        serdes_tx_data_dm_reg <= encoded_tx_data_dm;
        serdes_tx_data_dv_reg <= encoded_tx_data_dv;
    end

    serdes_tx_data_valid_reg <= encoded_tx_data_valid;
    serdes_tx_gbx_sync_reg <= tx_gbx_sync;
end

endmodule

`resetall
