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
 * 1000BASE-X decoder
 */
module taxi_gmii_basex_dec #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * 1000BASE-X encoded input
     */
    input  wire logic [DATA_W-1:0]  encoded_rx_data,
    input  wire logic [CTRL_W-1:0]  encoded_rx_data_k,
    input  wire logic               encoded_rx_data_valid = 1'b1,

    /*
     * GMII interface
     */
    output wire logic [DATA_W-1:0]  gmii_rxd,
    output wire logic [CTRL_W-1:0]  gmii_rx_dv,
    output wire logic [CTRL_W-1:0]  gmii_rx_er,
    output wire logic               gmii_rx_valid,

    /*
     * Status
     */
    output wire logic               stat_rx_err_bad_block,
    output wire logic               stat_rx_err_framing
);

// check configuration
if (DATA_W != CTRL_W*8)
    $fatal(0, "Error: DATA_W must equal CTRL_W*8 (instance %m)");

if (2**$clog2(CTRL_W) != CTRL_W)
    $fatal(0, "Error: CTRL_W must be even power of two (instance %m)");

typedef enum logic [7:0] {
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5
} eth_pre_t;

function [7:0] D(input [4:0] edcba, input [2:0] hgf);
    D = {hgf, edcba};
endfunction

function [7:0] K(input [4:0] edcba, input [2:0] hgf);
    K = {hgf, edcba};
endfunction

localparam logic [15:0] CTRL_C1 = {D(21,5), K(28,5)};
localparam logic [15:0] CTRL_C2 = {D(2,2),  K(28,5)};
localparam logic [15:0] CTRL_I1 = {D(5,6),  K(28,5)};
localparam logic [15:0] CTRL_I2 = {D(16,2), K(28,5)};
localparam logic [7:0] CTRL_R = K(23,7);
localparam logic [7:0] CTRL_S = K(27,7);
localparam logic [7:0] CTRL_T = K(29,7);
localparam logic [7:0] CTRL_V = K(30,7);
localparam logic [15:0] CTRL_L1 = {D(6,5),  K(28,5)};
localparam logic [15:0] CTRL_L2 = {D(26,4), K(28,5)};

logic frame_reg = 1'b0, frame_next;
logic frame_cyc;
logic odd_reg = 1'b0, odd_next;
logic odd_cyc;

logic [DATA_W-1:0]  gmii_rxd_reg = '0, gmii_rxd_next;
logic [CTRL_W-1:0]  gmii_rx_dv_reg = '0, gmii_rx_dv_next;
logic [CTRL_W-1:0]  gmii_rx_er_reg = '0, gmii_rx_er_next;
logic               gmii_rx_valid_reg = '0, gmii_rx_valid_next;

logic stat_rx_err_bad_block_reg = '0, stat_rx_err_bad_block_next;
logic stat_rx_err_framing_reg = '0, stat_rx_err_framing_next;

assign gmii_rxd = gmii_rxd_reg;
assign gmii_rx_dv = gmii_rx_dv_reg;
assign gmii_rx_er = gmii_rx_er_reg;
assign gmii_rx_valid = gmii_rx_valid_reg;

assign stat_rx_err_bad_block = stat_rx_err_bad_block_reg;
assign stat_rx_err_framing = stat_rx_err_framing_reg;

always_comb begin
    frame_next = frame_reg;
    odd_next = odd_reg;

    gmii_rxd_next = '0;
    gmii_rx_dv_next = '0;
    gmii_rx_er_next = '0;
    gmii_rx_valid_next = 1'b0;

    stat_rx_err_bad_block_next = 1'b0;
    stat_rx_err_framing_next = 1'b0;

    frame_cyc = frame_reg;
    odd_cyc = odd_reg;

    if (encoded_rx_data_valid) begin
        // loop over bytes
        for (integer seg = 0; seg < CTRL_W; seg = seg + 1) begin
            if (CTRL_W > 1) begin
                odd_cyc = 1'(seg & 1);
            end

            if (encoded_rx_data_k[seg]) begin
                // Kx.y
                if (encoded_rx_data[seg*8 +: 8] == K(28,5)) begin
                    // K28.5
                    odd_cyc = 1'b0; // sync
                    frame_cyc = 1'b0;
                    stat_rx_err_framing_next = frame_cyc;
                end else if (encoded_rx_data[seg*8 +: 8] == CTRL_T) begin
                    // terminate
                    frame_cyc = 1'b0;
                end else if (encoded_rx_data[seg*8 +: 8] == CTRL_R) begin
                    // carrier extend
                    frame_cyc = 1'b0;
                    gmii_rx_er_next[seg] = 1'b1;
                    stat_rx_err_framing_next = frame_cyc;
                end else if (encoded_rx_data[seg*8 +: 8] == CTRL_V) begin
                    // error
                    gmii_rxd_next[seg*8 +: 8] = encoded_rx_data[seg*8 +: 8];
                    gmii_rx_dv_next[seg] = frame_cyc;
                    gmii_rx_er_next[seg] = 1'b1;
                end else if (encoded_rx_data[seg*8 +: 8] == CTRL_S && odd_cyc == 0) begin
                    // start
                    frame_cyc = 1'b1;
                    gmii_rxd_next[seg*8 +: 8] = ETH_PRE;
                    gmii_rx_dv_next[seg] = 1'b1;
                    gmii_rx_er_next[seg] = 1'b0;
                    stat_rx_err_framing_next = frame_cyc;
                end else begin
                    // unknown control character
                    frame_cyc = 1'b0;
                    stat_rx_err_bad_block_next = 1'b1;
                    stat_rx_err_framing_next = frame_cyc;
                end
            end else begin
                // Dx.y
                if (frame_cyc) begin
                    // frame data
                    gmii_rxd_next[seg*8 +: 8] = encoded_rx_data[seg*8 +: 8];
                    gmii_rx_dv_next[seg] = 1'b1;
                    gmii_rx_er_next[seg] = 1'b0;
                end
            end

            odd_cyc = !odd_cyc;
        end

        frame_next = frame_cyc;
        odd_next = odd_cyc;

        gmii_rx_valid_next = 1'b1;
    end
end

always_ff @(posedge clk) begin
    frame_reg <= frame_next;
    odd_reg <= odd_next;

    gmii_rxd_reg <= gmii_rxd_next;
    gmii_rx_dv_reg <= gmii_rx_dv_next;
    gmii_rx_er_reg <= gmii_rx_er_next;
    gmii_rx_valid_reg <= gmii_rx_valid_next;

    stat_rx_err_bad_block_reg <= stat_rx_err_bad_block_next;
    stat_rx_err_framing_reg <= stat_rx_err_framing_next;

    if (rst) begin
        frame_reg <= 1'b0;
        odd_reg <= 1'b0;

        gmii_rxd_reg <= '0;
        gmii_rx_dv_reg <= '0;
        gmii_rx_er_reg <= '0;
        gmii_rx_valid_reg <= 1'b0;

        stat_rx_err_bad_block_reg <= 1'b0;
        stat_rx_err_framing_reg <= 1'b0;
    end
end

endmodule

`resetall
