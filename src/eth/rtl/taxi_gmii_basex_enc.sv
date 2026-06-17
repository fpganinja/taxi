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
 * 1000BASE-X encoder
 */
module taxi_gmii_basex_enc #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1,
    parameter logic AN_EN = 1'b1
)
(
    input  wire logic                clk,
    input  wire logic                rst,

    /*
     * GMII interface
     */
    input  wire logic [DATA_W-1:0]   gmii_txd,
    input  wire logic [CTRL_W-1:0]   gmii_tx_en,
    input  wire logic [CTRL_W-1:0]   gmii_tx_er,
    input  wire logic                gmii_tx_valid = 1'b1,
    input  wire logic [GBX_CNT-1:0]  tx_gbx_sync_in = '0,

    /*
     * 1000BASE-X encoded interface
     */
    output wire logic [DATA_W-1:0]   encoded_tx_data,
    output wire logic [CTRL_W-1:0]   encoded_tx_data_k,
    output wire logic [CTRL_W-1:0]   encoded_tx_data_dm,
    output wire logic [CTRL_W-1:0]   encoded_tx_data_dv,
    output wire logic                encoded_tx_data_valid,
    output wire logic [GBX_CNT-1:0]  tx_gbx_sync_out,

    /*
     * AN config register
     */
    input  wire logic [15:0]         tx_an_cfg = '0,
    input  wire logic                tx_an_cfg_valid = 1'b0,
    output wire logic                tx_an_cfg_ready
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

function logic rd_flip_3b4b(input [2:0] hgf);
    case (hgf)
        3'b000: rd_flip_3b4b = 1'b1;
        3'b001: rd_flip_3b4b = 1'b0;
        3'b010: rd_flip_3b4b = 1'b0;
        3'b011: rd_flip_3b4b = 1'b0;
        3'b100: rd_flip_3b4b = 1'b1;
        3'b101: rd_flip_3b4b = 1'b0;
        3'b110: rd_flip_3b4b = 1'b0;
        3'b111: rd_flip_3b4b = 1'b1;
    endcase
endfunction

function logic rd_flip_5b6b(input [4:0] edcba, input k);
    case (edcba)
        5'b00000: rd_flip_5b6b = 1'b1;
        5'b00001: rd_flip_5b6b = 1'b1;
        5'b00010: rd_flip_5b6b = 1'b1;
        5'b00011: rd_flip_5b6b = 1'b0;
        5'b00100: rd_flip_5b6b = 1'b1;
        5'b00101: rd_flip_5b6b = 1'b0;
        5'b00110: rd_flip_5b6b = 1'b0;
        5'b00111: rd_flip_5b6b = 1'b0;
        5'b01000: rd_flip_5b6b = 1'b1;
        5'b01001: rd_flip_5b6b = 1'b0;
        5'b01010: rd_flip_5b6b = 1'b0;
        5'b01011: rd_flip_5b6b = 1'b0;
        5'b01100: rd_flip_5b6b = 1'b0;
        5'b01101: rd_flip_5b6b = 1'b0;
        5'b01110: rd_flip_5b6b = 1'b0;
        5'b01111: rd_flip_5b6b = 1'b1;
        5'b10000: rd_flip_5b6b = 1'b1;
        5'b10001: rd_flip_5b6b = 1'b0;
        5'b10010: rd_flip_5b6b = 1'b0;
        5'b10011: rd_flip_5b6b = 1'b0;
        5'b10100: rd_flip_5b6b = 1'b0;
        5'b10101: rd_flip_5b6b = 1'b0;
        5'b10110: rd_flip_5b6b = 1'b0;
        5'b10111: rd_flip_5b6b = 1'b1;
        5'b11000: rd_flip_5b6b = 1'b1;
        5'b11001: rd_flip_5b6b = 1'b0;
        5'b11010: rd_flip_5b6b = 1'b0;
        5'b11011: rd_flip_5b6b = 1'b1;
        5'b11100: rd_flip_5b6b = k; // K28
        5'b11101: rd_flip_5b6b = 1'b1;
        5'b11110: rd_flip_5b6b = 1'b1;
        5'b11111: rd_flip_5b6b = 1'b1;
    endcase
endfunction

function logic rd_flip_8b10b(input [7:0] d, input k);
    rd_flip_8b10b = rd_flip_5b6b(d[4:0], k) ^ rd_flip_3b4b(d[7:5]);
endfunction

logic frame_reg = 1'b0, frame_next;
logic frame_cyc;
logic odd_reg = 1'b0, odd_next;
logic odd_cyc;
logic cext_reg = 1'b0, cext_next;
logic cext_cyc;
logic an_cfg_reg = 1'b0, an_cfg_next;
logic an_cfg_cyc;
logic an_phase_reg = 1'b0, an_phase_next;
logic an_phase_cyc;
logic rd_reg = 1'b0, rd_next;
logic rd_cyc;

logic [DATA_W-1:0]   encoded_tx_data_reg = '0, encoded_tx_data_next;
logic [CTRL_W-1:0]   encoded_tx_data_k_reg = '0, encoded_tx_data_k_next;
logic [CTRL_W-1:0]   encoded_tx_data_dm_reg = '0, encoded_tx_data_dm_next;
logic [CTRL_W-1:0]   encoded_tx_data_dv_reg = '0, encoded_tx_data_dv_next;
logic                encoded_tx_data_valid_reg = '0, encoded_tx_data_valid_next;
logic [GBX_CNT-1:0]  tx_gbx_sync_reg = '0, tx_gbx_sync_next;

logic tx_an_cfg_ready_reg = 1'b0, tx_an_cfg_ready_next;

assign encoded_tx_data = encoded_tx_data_reg;
assign encoded_tx_data_k = encoded_tx_data_k_reg;
assign encoded_tx_data_dm = encoded_tx_data_dm_reg;
assign encoded_tx_data_dv = encoded_tx_data_dv_reg;
assign encoded_tx_data_valid = encoded_tx_data_valid_reg;
assign tx_gbx_sync_out = tx_gbx_sync_reg;

assign tx_an_cfg_ready = AN_EN ? tx_an_cfg_ready_reg : 1'b0;

always_comb begin
    frame_next = frame_reg;
    odd_next = odd_reg;
    cext_next = cext_reg;
    an_cfg_next = an_cfg_reg;
    an_phase_next = an_phase_reg;
    rd_next = rd_reg;

    encoded_tx_data_next = '0;
    encoded_tx_data_k_next = '0;
    encoded_tx_data_dm_next = '0;
    encoded_tx_data_dv_next = '0;
    encoded_tx_data_valid_next = '0;

    tx_gbx_sync_next = tx_gbx_sync_in;

    tx_an_cfg_ready_next = 1'b0;

    frame_cyc = frame_reg;
    odd_cyc = odd_reg;
    cext_cyc = cext_reg;
    an_cfg_cyc = an_cfg_reg;
    an_phase_cyc = an_phase_reg;
    rd_cyc = rd_reg;

    if (gmii_tx_valid) begin
        // loop over bytes
        for (integer seg = 0; seg < CTRL_W; seg = seg + 1) begin
            if (CTRL_W > 1) begin
                odd_cyc = 1'(seg & 1);
            end

            if (frame_cyc) begin
                if (gmii_tx_en[seg]) begin
                    if (gmii_tx_er[seg]) begin
                        // propagate error
                        encoded_tx_data_next[seg*8 +: 8] = CTRL_V;
                        encoded_tx_data_k_next[seg] = 1'b1;
                    end else begin
                        // data
                        encoded_tx_data_next[seg*8 +: 8] = gmii_txd[seg*8 +: 8];
                        encoded_tx_data_k_next[seg] = 1'b0;
                    end
                end else begin
                    // end of frame
                    frame_cyc = 1'b0;
                    encoded_tx_data_next[seg*8 +: 8] = CTRL_T;
                    encoded_tx_data_k_next[seg] = 1'b1;
                    cext_cyc = 1'b1;
                end
            end else if (AN_EN && an_cfg_cyc) begin
                // config reg
                if (!odd_cyc) begin
                    encoded_tx_data_next[seg*8 +: 8] = tx_an_cfg[7:0];
                    encoded_tx_data_k_next[seg] = 1'b0;
                end else begin
                    encoded_tx_data_next[seg*8 +: 8] = tx_an_cfg[15:8];
                    encoded_tx_data_k_next[seg] = 1'b0;
                    tx_an_cfg_ready_next = 1'b1;
                    an_phase_cyc = !an_phase_cyc;
                    an_cfg_cyc = 1'b0;
                end
            end else begin
                if (gmii_tx_en[seg] && odd_cyc == 0) begin
                    // start of frame
                    frame_cyc = 1'b1;
                    encoded_tx_data_next[seg*8 +: 8] = CTRL_S;
                    encoded_tx_data_k_next[seg] = 1'b1;
                end else if (AN_EN && tx_an_cfg_valid && odd_cyc == 1) begin
                    // config reg
                    an_cfg_cyc = 1'b1;
                    encoded_tx_data_next[seg*8 +: 8] = an_phase_reg ? D(2,2) : D(21,5);
                    encoded_tx_data_k_next[seg] = 1'b0;
                end else begin
                    if (cext_cyc) begin
                        // carrier extend
                        encoded_tx_data_next[seg*8 +: 8] = CTRL_R;
                        encoded_tx_data_k_next[seg] = 1'b1;
                        if (odd_cyc) begin
                            cext_cyc = 1'b0;
                        end
                    end else if (!odd_cyc) begin
                        // K28.5
                        encoded_tx_data_next[seg*8 +: 8] = K(28,5);
                        encoded_tx_data_k_next[seg] = 1'b1;
                        encoded_tx_data_dm_next[seg] = 1'b1;
                        encoded_tx_data_dv_next[seg] = rd_cyc;
                    end else begin
                        // idle
                        encoded_tx_data_next[seg*8 +: 8] = rd_cyc ? D(16,2) : D(5,6);
                        encoded_tx_data_k_next[seg] = 1'b0;
                        encoded_tx_data_dm_next[seg] = 1'b1;
                        encoded_tx_data_dv_next[seg] = rd_cyc;
                    end
                end
            end

            odd_cyc = !odd_cyc;
            rd_cyc = rd_cyc ^ rd_flip_8b10b(encoded_tx_data_next[seg*8 +: 8], encoded_tx_data_k_next[seg]);
        end

        frame_next = frame_cyc;
        odd_next = odd_cyc;
        cext_next = cext_cyc;
        an_cfg_next = an_cfg_cyc;
        an_phase_next = an_phase_cyc;
        rd_next = rd_cyc;

        encoded_tx_data_valid_next = 1'b1;
    end
end

always_ff @(posedge clk) begin
    frame_reg <= frame_next;
    odd_reg <= odd_next;
    cext_reg <= cext_next;
    an_cfg_reg <= an_cfg_next;
    an_phase_reg <= an_phase_next;
    rd_reg <= rd_next;

    encoded_tx_data_reg <= encoded_tx_data_next;
    encoded_tx_data_k_reg <= encoded_tx_data_k_next;
    encoded_tx_data_dm_reg <= encoded_tx_data_dm_next;
    encoded_tx_data_dv_reg <= encoded_tx_data_dv_next;
    encoded_tx_data_valid_reg <= encoded_tx_data_valid_next;
    tx_gbx_sync_reg <= tx_gbx_sync_next;

    tx_an_cfg_ready_reg <= tx_an_cfg_ready_next;

    if (rst) begin
        frame_reg <= 1'b0;
        odd_reg <= 1'b0;
        cext_reg <= 1'b0;
        an_cfg_reg <= 1'b0;
        an_phase_reg <= 1'b0;
        rd_reg <= 1'b0;

        encoded_tx_data_reg <= '0;
        encoded_tx_data_k_reg <= '0;
        encoded_tx_data_dm_reg <= '0;
        encoded_tx_data_dv_reg <= '0;
        encoded_tx_data_valid_reg <= 1'b0;
        tx_gbx_sync_reg <= '0;

        tx_an_cfg_ready_reg <= 1'b0;
    end
end

endmodule

`resetall
