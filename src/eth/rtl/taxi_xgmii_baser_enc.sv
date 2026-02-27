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
 * XGMII 10GBASE-R encoder
 */
module taxi_xgmii_baser_enc #
(
    parameter DATA_W = 64,
    parameter CTRL_W = (DATA_W/8),
    parameter HDR_W = 2,
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1
)
(
    input  wire logic                clk,
    input  wire logic                rst,

    /*
     * XGMII interface
     */
    input  wire logic [DATA_W-1:0]   xgmii_txd,
    input  wire logic [CTRL_W-1:0]   xgmii_txc,
    input  wire logic                xgmii_tx_valid = 1'b1,
    input  wire logic [GBX_CNT-1:0]  tx_gbx_sync_in = '0,

    /*
     * 10GBASE-R encoded interface
     */
    output wire logic [DATA_W-1:0]   encoded_tx_data,
    output wire logic                encoded_tx_data_valid,
    output wire logic [HDR_W-1:0]    encoded_tx_hdr,
    output wire logic                encoded_tx_hdr_valid,
    output wire logic [GBX_CNT-1:0]  tx_gbx_sync_out,

    /*
     * Status
     */
    output wire logic                tx_bad_block
);

localparam DATA_W_INT = 64;
localparam CTRL_W_INT = 8;

localparam USE_HDR_VLD = GBX_IF_EN || DATA_W != 64;

localparam SEG_CNT = DATA_W_INT / DATA_W;

// check configuration
if (DATA_W != 32 && DATA_W != 64)
    $fatal(0, "Error: Interface width must be 32 or 64");

if (CTRL_W * 8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity");

if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2");

typedef enum logic [7:0] {
    XGMII_IDLE   = 8'h07,
    XGMII_LPI    = 8'h06,
    XGMII_START  = 8'hfb,
    XGMII_TERM   = 8'hfd,
    XGMII_ERROR  = 8'hfe,
    XGMII_SEQ_OS = 8'h9c,
    XGMII_RES_0  = 8'h1c,
    XGMII_RES_1  = 8'h3c,
    XGMII_RES_2  = 8'h7c,
    XGMII_RES_3  = 8'hbc,
    XGMII_RES_4  = 8'hdc,
    XGMII_RES_5  = 8'hf7,
    XGMII_SIG_OS = 8'h5c
} xgmii_ctrl_t;

typedef enum logic [6:0] {
    CTRL_IDLE  = 7'h00,
    CTRL_LPI   = 7'h06,
    CTRL_ERROR = 7'h1e,
    CTRL_RES_0 = 7'h2d,
    CTRL_RES_1 = 7'h33,
    CTRL_RES_2 = 7'h4b,
    CTRL_RES_3 = 7'h55,
    CTRL_RES_4 = 7'h66,
    CTRL_RES_5 = 7'h78
} baser_ctrl_t;

typedef enum logic [3:0] {
    O_SEQ_OS = 4'h0,
    O_SIG_OS = 4'hf
} baser_o_t;

typedef enum logic [1:0] {
    SYNC_DATA = 2'b10,
    SYNC_CTRL = 2'b01
} baser_sync_t;

typedef enum logic [7:0] {
    BLOCK_TYPE_CTRL     = 8'h1e, // C7 C6 C5 C4 C3 C2 C1 C0 BT
    BLOCK_TYPE_OS_4     = 8'h2d, // D7 D6 D5 O4 C3 C2 C1 C0 BT
    BLOCK_TYPE_START_4  = 8'h33, // D7 D6 D5    C3 C2 C1 C0 BT
    BLOCK_TYPE_OS_START = 8'h66, // D7 D6 D5    O0 D3 D2 D1 BT
    BLOCK_TYPE_OS_04    = 8'h55, // D7 D6 D5 O4 O0 D3 D2 D1 BT
    BLOCK_TYPE_START_0  = 8'h78, // D7 D6 D5 D4 D3 D2 D1    BT
    BLOCK_TYPE_OS_0     = 8'h4b, // C7 C6 C5 C4 O0 D3 D2 D1 BT
    BLOCK_TYPE_TERM_0   = 8'h87, // C7 C6 C5 C4 C3 C2 C1    BT
    BLOCK_TYPE_TERM_1   = 8'h99, // C7 C6 C5 C4 C3 C2    D0 BT
    BLOCK_TYPE_TERM_2   = 8'haa, // C7 C6 C5 C4 C3    D1 D0 BT
    BLOCK_TYPE_TERM_3   = 8'hb4, // C7 C6 C5 C4    D2 D1 D0 BT
    BLOCK_TYPE_TERM_4   = 8'hcc, // C7 C6 C5    D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_5   = 8'hd2, // C7 C6    D4 D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_6   = 8'he1, // C7    D5 D4 D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_7   = 8'hff  //    D6 D5 D4 D3 D2 D1 D0 BT
} baser_block_type_t;

wire [DATA_W_INT-1:0] xgmii_txd_int;
wire [CTRL_W_INT-1:0] xgmii_txc_int;
wire xgmii_tx_valid_int;

logic [DATA_W_INT*7/8-1:0] encoded_ctrl;
logic [CTRL_W_INT-1:0] encode_err;

logic [DATA_W_INT-1:0] encoded_tx_data_reg = '0, encoded_tx_data_next;
logic [SEG_CNT-1:0] encoded_tx_data_valid_reg = '0, encoded_tx_data_valid_next;
logic [HDR_W-1:0] encoded_tx_hdr_reg = '0, encoded_tx_hdr_next;
logic encoded_tx_hdr_valid_reg = 1'b0, encoded_tx_hdr_valid_next;
logic [GBX_CNT-1:0] tx_gbx_sync_reg = '0, tx_gbx_sync_next;

logic tx_bad_block_reg = 1'b0, tx_bad_block_next;

assign encoded_tx_data = encoded_tx_data_reg[DATA_W-1:0];
assign encoded_tx_data_valid = GBX_IF_EN ? encoded_tx_data_valid_reg[0] : 1'b1;
assign encoded_tx_hdr = encoded_tx_hdr_reg;
assign encoded_tx_hdr_valid = USE_HDR_VLD ? encoded_tx_hdr_valid_reg : 1'b1;
assign tx_gbx_sync_out = GBX_IF_EN ? tx_gbx_sync_reg : '0;

assign tx_bad_block = tx_bad_block_reg;

if (DATA_W == 64) begin : repack_in

    assign xgmii_txd_int = xgmii_txd;
    assign xgmii_txc_int = xgmii_txc;
    assign xgmii_tx_valid_int = xgmii_tx_valid;

end else begin : repack_in

    logic [DATA_W_INT-DATA_W-1:0] xgmii_txd_reg = '0;
    logic [CTRL_W_INT-CTRL_W-1:0] xgmii_txc_reg = '0;
    logic xgmii_tx_valid_reg = '0;

    assign xgmii_txd_int = {xgmii_txd, xgmii_txd_reg};
    assign xgmii_txc_int = {xgmii_txc, xgmii_txc_reg};
    assign xgmii_tx_valid_int = xgmii_tx_valid_reg && (GBX_IF_EN ? xgmii_tx_valid : 1'b1);

    always_ff @(posedge clk) begin
        if (!GBX_IF_EN || xgmii_tx_valid) begin
            xgmii_txd_reg <= xgmii_txd;
            xgmii_txc_reg <= xgmii_txc;
            xgmii_tx_valid_reg <= !xgmii_tx_valid_reg;
            if (GBX_IF_EN && tx_gbx_sync_in[0]) begin
                // align header output with sync pulse
                xgmii_tx_valid_reg <= 1'b0;
            end
        end

        if (rst) begin
            xgmii_tx_valid_reg <= '0;
        end
    end

end

always_comb begin
    encoded_tx_data_next = {{CTRL_W_INT{CTRL_ERROR}}, BLOCK_TYPE_CTRL};
    encoded_tx_data_valid_next = '0;
    encoded_tx_hdr_next = SYNC_CTRL;
    encoded_tx_hdr_valid_next = '0;
    tx_gbx_sync_next = '0;

    tx_bad_block_next = 1'b0;

    for (integer i = 0; i < CTRL_W_INT; i = i + 1) begin
        if (xgmii_txc_int[i]) begin
            // control
            case (xgmii_txd_int[8*i +: 8])
                XGMII_IDLE: begin
                    encoded_ctrl[7*i +: 7] = CTRL_IDLE;
                    encode_err[i] = 1'b0;
                end
                XGMII_LPI: begin
                    encoded_ctrl[7*i +: 7] = CTRL_LPI;
                    encode_err[i] = 1'b0;
                end
                XGMII_ERROR: begin
                    encoded_ctrl[7*i +: 7] = CTRL_ERROR;
                    encode_err[i] = 1'b0;
                end
                XGMII_RES_0: begin
                    encoded_ctrl[7*i +: 7] = CTRL_RES_0;
                    encode_err[i] = 1'b0;
                end
                XGMII_RES_1: begin
                    encoded_ctrl[7*i +: 7] = CTRL_RES_1;
                    encode_err[i] = 1'b0;
                end
                XGMII_RES_2: begin
                    encoded_ctrl[7*i +: 7] = CTRL_RES_2;
                    encode_err[i] = 1'b0;
                end
                XGMII_RES_3: begin
                    encoded_ctrl[7*i +: 7] = CTRL_RES_3;
                    encode_err[i] = 1'b0;
                end
                XGMII_RES_4: begin
                    encoded_ctrl[7*i +: 7] = CTRL_RES_4;
                    encode_err[i] = 1'b0;
                end
                XGMII_RES_5: begin
                    encoded_ctrl[7*i +: 7] = CTRL_RES_5;
                    encode_err[i] = 1'b0;
                end
                default: begin
                    encoded_ctrl[7*i +: 7] = CTRL_ERROR;
                    encode_err[i] = 1'b1;
                end
            endcase
        end else begin
            // data (always invalid as control)
            encoded_ctrl[7*i +: 7] = CTRL_ERROR;
            encode_err[i] = 1'b1;
        end
    end

    if (SEG_CNT > 1) begin
        // repack output
        // disable broken verilator linter (unreachable code by parameter value)
        // verilator lint_off WIDTH
        // verilator lint_off SELRANGE
        encoded_tx_data_next = {{DATA_W{1'b0}}, encoded_tx_data_reg[DATA_W_INT-1:DATA_W]};
        encoded_tx_data_valid_next = {1'b0, encoded_tx_data_valid_reg[SEG_CNT-1:1]};
        encoded_tx_hdr_next = 2'b00;
        encoded_tx_hdr_valid_next = 1'b0;
        // verilator lint_on WIDTH
        // verilator lint_on SELRANGE
    end

    if (!xgmii_tx_valid_int) begin
        // wait for block
    end else if (xgmii_txc_int == 8'h00) begin
        encoded_tx_data_next = xgmii_txd_int;
        encoded_tx_data_valid_next = '1;
        encoded_tx_hdr_next = SYNC_DATA;
        encoded_tx_hdr_valid_next = 1'b1;
        tx_bad_block_next = 1'b0;
    end else begin
        if (xgmii_txc_int == 8'h1f && xgmii_txd_int[39:32] == XGMII_SEQ_OS) begin
            // ordered set in lane 4
            encoded_tx_data_next = {xgmii_txd_int[63:40], O_SEQ_OS, encoded_ctrl[27:0], BLOCK_TYPE_OS_4};
            tx_bad_block_next = encode_err[3:0] != 0;
        end else if (xgmii_txc_int == 8'h1f && xgmii_txd_int[39:32] == XGMII_START) begin
            // start in lane 4
            encoded_tx_data_next = {xgmii_txd_int[63:40], 4'd0, encoded_ctrl[27:0], BLOCK_TYPE_START_4};
            tx_bad_block_next = encode_err[3:0] != 0;
        end else if (xgmii_txc_int == 8'h11 && xgmii_txd_int[7:0] == XGMII_SEQ_OS && xgmii_txd_int[39:32] == XGMII_START) begin
            // ordered set in lane 0, start in lane 4
            encoded_tx_data_next = {xgmii_txd_int[63:40], 4'd0, O_SEQ_OS, xgmii_txd_int[31:8], BLOCK_TYPE_OS_START};
            tx_bad_block_next = 1'b0;
        end else if (xgmii_txc_int == 8'h11 && xgmii_txd_int[7:0] == XGMII_SEQ_OS && xgmii_txd_int[39:32] == XGMII_SEQ_OS) begin
            // ordered set in lane 0 and lane 4
            encoded_tx_data_next = {xgmii_txd_int[63:40], O_SEQ_OS, O_SEQ_OS, xgmii_txd_int[31:8], BLOCK_TYPE_OS_04};
            tx_bad_block_next = 1'b0;
        end else if (xgmii_txc_int == 8'h01 && xgmii_txd_int[7:0] == XGMII_START) begin
            // start in lane 0
            encoded_tx_data_next = {xgmii_txd_int[63:8], BLOCK_TYPE_START_0};
            tx_bad_block_next = 1'b0;
        end else if (xgmii_txc_int == 8'hf1 && xgmii_txd_int[7:0] == XGMII_SEQ_OS) begin
            // ordered set in lane 0
            encoded_tx_data_next = {encoded_ctrl[55:28], O_SEQ_OS, xgmii_txd_int[31:8], BLOCK_TYPE_OS_0};
            tx_bad_block_next = encode_err[7:4] != 0;
        end else if (xgmii_txc_int == 8'hff && xgmii_txd_int[7:0] == XGMII_TERM) begin
            // terminate in lane 0
            encoded_tx_data_next = {encoded_ctrl[55:7], 7'd0, BLOCK_TYPE_TERM_0};
            tx_bad_block_next = encode_err[7:1] != 0;
        end else if (xgmii_txc_int == 8'hfe && xgmii_txd_int[15:8] == XGMII_TERM) begin
            // terminate in lane 1
            encoded_tx_data_next = {encoded_ctrl[55:14], 6'd0, xgmii_txd_int[7:0], BLOCK_TYPE_TERM_1};
            tx_bad_block_next = encode_err[7:2] != 0;
        end else if (xgmii_txc_int == 8'hfc && xgmii_txd_int[23:16] == XGMII_TERM) begin
            // terminate in lane 2
            encoded_tx_data_next = {encoded_ctrl[55:21], 5'd0, xgmii_txd_int[15:0], BLOCK_TYPE_TERM_2};
            tx_bad_block_next = encode_err[7:3] != 0;
        end else if (xgmii_txc_int == 8'hf8 && xgmii_txd_int[31:24] == XGMII_TERM) begin
            // terminate in lane 3
            encoded_tx_data_next = {encoded_ctrl[55:28], 4'd0, xgmii_txd_int[23:0], BLOCK_TYPE_TERM_3};
            tx_bad_block_next = encode_err[7:4] != 0;
        end else if (xgmii_txc_int == 8'hf0 && xgmii_txd_int[39:32] == XGMII_TERM) begin
            // terminate in lane 4
            encoded_tx_data_next = {encoded_ctrl[55:35], 3'd0, xgmii_txd_int[31:0], BLOCK_TYPE_TERM_4};
            tx_bad_block_next = encode_err[7:5] != 0;
        end else if (xgmii_txc_int == 8'he0 && xgmii_txd_int[47:40] == XGMII_TERM) begin
            // terminate in lane 5
            encoded_tx_data_next = {encoded_ctrl[55:42], 2'd0, xgmii_txd_int[39:0], BLOCK_TYPE_TERM_5};
            tx_bad_block_next = encode_err[7:6] != 0;
        end else if (xgmii_txc_int == 8'hc0 && xgmii_txd_int[55:48] == XGMII_TERM) begin
            // terminate in lane 6
            encoded_tx_data_next = {encoded_ctrl[55:49], 1'd0, xgmii_txd_int[47:0], BLOCK_TYPE_TERM_6};
            tx_bad_block_next = encode_err[7] != 0;
        end else if (xgmii_txc_int == 8'h80 && xgmii_txd_int[63:56] == XGMII_TERM) begin
            // terminate in lane 7
            encoded_tx_data_next = {xgmii_txd_int[55:0], BLOCK_TYPE_TERM_7};
            tx_bad_block_next = 1'b0;
        end else if (xgmii_txc_int == 8'hff) begin
            // all control
            encoded_tx_data_next = {encoded_ctrl, BLOCK_TYPE_CTRL};
            tx_bad_block_next = encode_err != 0;
        end else begin
            // no corresponding block format
            encoded_tx_data_next = {{CTRL_W_INT{CTRL_ERROR}}, BLOCK_TYPE_CTRL};
            tx_bad_block_next = 1'b1;
        end
        encoded_tx_data_valid_next = '1;
        encoded_tx_hdr_next = SYNC_CTRL;
        encoded_tx_hdr_valid_next = 1'b1;
    end

    if (GBX_IF_EN && !xgmii_tx_valid_int) begin
        tx_bad_block_next = 1'b0;
    end

    tx_gbx_sync_next = tx_gbx_sync_in;
end

always_ff @(posedge clk) begin
    encoded_tx_data_reg <= encoded_tx_data_next;
    encoded_tx_data_valid_reg <= encoded_tx_data_valid_next;
    encoded_tx_hdr_reg <= encoded_tx_hdr_next;
    encoded_tx_hdr_valid_reg <= encoded_tx_hdr_valid_next;
    tx_gbx_sync_reg <= tx_gbx_sync_next;

    tx_bad_block_reg <= tx_bad_block_next;
end

endmodule

`resetall
