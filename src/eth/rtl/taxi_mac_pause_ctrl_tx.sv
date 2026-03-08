// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2023-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PFC and pause frame transmit handling
 */
module taxi_mac_pause_ctrl_tx #
(
    parameter MCF_PARAMS_SIZE = 18,
    parameter logic PFC_EN = 1'b1
)
(
    input  wire logic                          clk,
    input  wire logic                          rst,

    /*
     * MAC control frame interface
     */
    output wire logic                          mcf_valid,
    input  wire logic                          mcf_ready,
    output wire logic [47:0]                   mcf_eth_dst,
    output wire logic [47:0]                   mcf_eth_src,
    output wire logic [15:0]                   mcf_eth_type,
    output wire logic [15:0]                   mcf_opcode,
    output wire logic [MCF_PARAMS_SIZE*8-1:0]  mcf_params,

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    input  wire logic                          tx_lfc_req,
    input  wire logic                          tx_lfc_resend,

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D)
     */
    input  wire logic [7:0]                    tx_pfc_req,
    input  wire logic                          tx_pfc_resend,

    /*
     * Configuration
     */
    input  wire logic [47:0]                   cfg_tx_lfc_eth_dst = 48'h01_80_C2_00_00_01,
    input  wire logic [47:0]                   cfg_tx_lfc_eth_src = 48'h80_23_31_43_54_4C,
    input  wire logic [15:0]                   cfg_tx_lfc_eth_type = 16'h8808,
    input  wire logic [15:0]                   cfg_tx_lfc_opcode = 16'h0001,
    input  wire logic                          cfg_tx_lfc_en = 1'b0,
    input  wire logic [15:0]                   cfg_tx_lfc_quanta = 16'hffff,
    input  wire logic [15:0]                   cfg_tx_lfc_refresh = 16'h7fff,
    input  wire logic [47:0]                   cfg_tx_pfc_eth_dst = 48'h01_80_C2_00_00_01,
    input  wire logic [47:0]                   cfg_tx_pfc_eth_src = 48'h80_23_31_43_54_4C,
    input  wire logic [15:0]                   cfg_tx_pfc_eth_type = 16'h8808,
    input  wire logic [15:0]                   cfg_tx_pfc_opcode = 16'h0101,
    input  wire logic                          cfg_tx_pfc_en = 1'b0,
    input  wire logic [15:0]                   cfg_tx_pfc_quanta[8] = '{8{16'hffff}},
    input  wire logic [15:0]                   cfg_tx_pfc_refresh[8] = '{8{16'h7fff}},
    input  wire logic [9:0]                    cfg_quanta_step,
    input  wire logic                          cfg_quanta_clk_en = 1'b1,

    /*
     * Status
     */
    output wire logic                          stat_tx_lfc_pkt,
    output wire logic                          stat_tx_lfc_xon,
    output wire logic                          stat_tx_lfc_xoff,
    output wire logic                          stat_tx_lfc_paused,
    output wire logic                          stat_tx_pfc_pkt,
    output wire logic [7:0]                    stat_tx_pfc_xon,
    output wire logic [7:0]                    stat_tx_pfc_xoff,
    output wire logic [7:0]                    stat_tx_pfc_paused
);

localparam QW = 16;
localparam QFB = 8;

// check configuration
if (MCF_PARAMS_SIZE < (PFC_EN ? 18 : 2))
    $fatal(0, "Error: MCF_PARAMS_SIZE too small for requested configuration (instance %m)");

logic lfc_req_reg = 1'b0, lfc_req_next;
logic lfc_act_reg = 1'b0, lfc_act_next;
logic lfc_send_reg = 1'b0, lfc_send_next;
logic [7:0] pfc_req_reg = 8'd0, pfc_req_next;
logic [7:0] pfc_act_reg = 8'd0, pfc_act_next;
logic [7:0] pfc_en_reg = 8'd0, pfc_en_next;
logic pfc_send_reg = 1'b0, pfc_send_next;

logic [QFB-1:0] quanta_cnt_reg = '0, quanta_cnt_next;
logic [1:0] quanta_inc_reg = '0, quanta_inc_next;

logic [QW-1:0] lfc_refresh_reg = '0, lfc_refresh_next;
logic [QW-1:0] pfc_refresh_reg[8] = '{default: '0}, pfc_refresh_next[8];

logic stat_tx_lfc_pkt_reg = 1'b0, stat_tx_lfc_pkt_next;
logic stat_tx_lfc_xon_reg = 1'b0, stat_tx_lfc_xon_next;
logic stat_tx_lfc_xoff_reg = 1'b0, stat_tx_lfc_xoff_next;
logic stat_tx_pfc_pkt_reg = 1'b0, stat_tx_pfc_pkt_next;
logic [7:0] stat_tx_pfc_xon_reg = '0, stat_tx_pfc_xon_next;
logic [7:0] stat_tx_pfc_xoff_reg = '0, stat_tx_pfc_xoff_next;

// MAC control interface
logic          mcf_pfc_sel_reg = PFC_EN != 0, mcf_pfc_sel_next;
logic          mcf_valid_reg = 1'b0, mcf_valid_next;

wire [2*8-1:0] mcf_lfc_params;
assign mcf_lfc_params[QW*0 +: QW] = lfc_req_reg ? {cfg_tx_lfc_quanta[0 +: 8], cfg_tx_lfc_quanta[8 +: 8]} : '0;

wire [18*8-1:0] mcf_pfc_params;
assign mcf_pfc_params[QW*0 +: QW] = {pfc_en_reg, 8'd0};
assign mcf_pfc_params[QW*1 +: QW] = pfc_req_reg[0] ? {cfg_tx_pfc_quanta[0][0 +: 8], cfg_tx_pfc_quanta[0][8 +: 8]} : '0;
assign mcf_pfc_params[QW*2 +: QW] = pfc_req_reg[1] ? {cfg_tx_pfc_quanta[1][0 +: 8], cfg_tx_pfc_quanta[1][8 +: 8]} : '0;
assign mcf_pfc_params[QW*3 +: QW] = pfc_req_reg[2] ? {cfg_tx_pfc_quanta[2][0 +: 8], cfg_tx_pfc_quanta[2][8 +: 8]} : '0;
assign mcf_pfc_params[QW*4 +: QW] = pfc_req_reg[3] ? {cfg_tx_pfc_quanta[3][0 +: 8], cfg_tx_pfc_quanta[3][8 +: 8]} : '0;
assign mcf_pfc_params[QW*5 +: QW] = pfc_req_reg[4] ? {cfg_tx_pfc_quanta[4][0 +: 8], cfg_tx_pfc_quanta[4][8 +: 8]} : '0;
assign mcf_pfc_params[QW*6 +: QW] = pfc_req_reg[5] ? {cfg_tx_pfc_quanta[5][0 +: 8], cfg_tx_pfc_quanta[5][8 +: 8]} : '0;
assign mcf_pfc_params[QW*7 +: QW] = pfc_req_reg[6] ? {cfg_tx_pfc_quanta[6][0 +: 8], cfg_tx_pfc_quanta[6][8 +: 8]} : '0;
assign mcf_pfc_params[QW*8 +: QW] = pfc_req_reg[7] ? {cfg_tx_pfc_quanta[7][0 +: 8], cfg_tx_pfc_quanta[7][8 +: 8]} : '0;

assign mcf_valid = mcf_valid_reg;
assign mcf_eth_dst  = (PFC_EN && mcf_pfc_sel_reg) ? cfg_tx_pfc_eth_dst  : cfg_tx_lfc_eth_dst;
assign mcf_eth_src  = (PFC_EN && mcf_pfc_sel_reg) ? cfg_tx_pfc_eth_src  : cfg_tx_lfc_eth_src;
assign mcf_eth_type = (PFC_EN && mcf_pfc_sel_reg) ? cfg_tx_pfc_eth_type : cfg_tx_lfc_eth_type;
assign mcf_opcode   = (PFC_EN && mcf_pfc_sel_reg) ? cfg_tx_pfc_opcode   : cfg_tx_lfc_opcode;
if (PFC_EN) begin
    assign mcf_params = mcf_pfc_sel_reg ? mcf_pfc_params : (MCF_PARAMS_SIZE*8)'(mcf_lfc_params);
end else begin
    assign mcf_params = mcf_lfc_params;
end

assign stat_tx_lfc_pkt = stat_tx_lfc_pkt_reg;
assign stat_tx_lfc_xon = stat_tx_lfc_xon_reg;
assign stat_tx_lfc_xoff = stat_tx_lfc_xoff_reg;
assign stat_tx_lfc_paused = lfc_req_reg;
assign stat_tx_pfc_pkt = stat_tx_pfc_pkt_reg;
assign stat_tx_pfc_xon = stat_tx_pfc_xon_reg;
assign stat_tx_pfc_xoff = stat_tx_pfc_xoff_reg;
assign stat_tx_pfc_paused = pfc_req_reg;

always_comb begin
    lfc_req_next = lfc_req_reg;
    lfc_act_next = lfc_act_reg;
    lfc_send_next = lfc_send_reg | tx_lfc_resend;
    pfc_req_next = pfc_req_reg;
    pfc_act_next = pfc_act_reg;
    pfc_en_next = pfc_en_reg;
    pfc_send_next = pfc_send_reg | tx_pfc_resend;

    mcf_pfc_sel_next = mcf_pfc_sel_reg;
    mcf_valid_next = mcf_valid_reg && !mcf_ready;

    stat_tx_lfc_pkt_next = 1'b0;
    stat_tx_lfc_xon_next = 1'b0;
    stat_tx_lfc_xoff_next = 1'b0;
    stat_tx_pfc_pkt_next = 1'b0;
    stat_tx_pfc_xon_next = '0;
    stat_tx_pfc_xoff_next = '0;

    quanta_cnt_next = quanta_cnt_reg;
    quanta_inc_next = 0;
    if (cfg_quanta_clk_en) begin
        {quanta_inc_next, quanta_cnt_next} = (2+QFB)'(quanta_cnt_reg) + cfg_quanta_step;
    end

    if (lfc_refresh_reg >= QW'(quanta_inc_reg)) begin
        lfc_refresh_next = lfc_refresh_reg - QW'(quanta_inc_reg);
    end else begin
        lfc_refresh_next = '0;
        if (lfc_req_reg) begin
            lfc_send_next = 1'b1;
        end
    end

    for (integer k = 0; k < 8; k = k + 1) begin
        if (pfc_refresh_reg[k] >= QW'(quanta_inc_reg)) begin
            pfc_refresh_next[k] = pfc_refresh_reg[k] - QW'(quanta_inc_reg);
        end else begin
            pfc_refresh_next[k] = '0;
            if (pfc_req_reg[k]) begin
                pfc_send_next = 1'b1;
            end
        end
    end

    if (cfg_tx_lfc_en) begin
        if (!mcf_valid_reg) begin
            if (lfc_req_reg != tx_lfc_req) begin
                lfc_req_next = tx_lfc_req;
                lfc_act_next = lfc_act_reg | tx_lfc_req;
                lfc_send_next = 1'b1;
            end

            if (lfc_send_reg && !(PFC_EN && cfg_tx_pfc_en && pfc_send_reg)) begin
                mcf_pfc_sel_next = 1'b0;
                mcf_valid_next = lfc_act_reg;
                lfc_act_next = lfc_req_reg;
                lfc_refresh_next = lfc_req_reg ? cfg_tx_lfc_refresh : '0;
                lfc_send_next = 1'b0;

                stat_tx_lfc_pkt_next = lfc_act_reg;
                stat_tx_lfc_xon_next = lfc_act_reg && !lfc_req_reg;
                stat_tx_lfc_xoff_next = lfc_act_reg && lfc_req_reg;
            end
        end
    end

    if (PFC_EN && cfg_tx_pfc_en) begin
        if (!mcf_valid_reg) begin
            if (pfc_req_reg != tx_pfc_req) begin
                pfc_req_next = tx_pfc_req;
                pfc_act_next = pfc_act_reg | tx_pfc_req;
                pfc_send_next = 1'b1;
            end

            if (pfc_send_reg) begin
                mcf_pfc_sel_next = 1'b1;
                mcf_valid_next = pfc_act_reg != 0;
                pfc_en_next = pfc_act_reg;
                pfc_act_next = pfc_req_reg;
                for (integer k = 0; k < 8; k = k + 1) begin
                    pfc_refresh_next[k] = pfc_req_reg[k] ? cfg_tx_pfc_refresh[k] : '0;
                end
                pfc_send_next = 1'b0;

                stat_tx_pfc_pkt_next = pfc_act_reg != 0;
                stat_tx_pfc_xon_next = pfc_act_reg & ~pfc_req_reg;
                stat_tx_pfc_xoff_next = pfc_act_reg & pfc_req_reg;
            end
        end
    end
end

always_ff @(posedge clk) begin
    lfc_req_reg <= lfc_req_next;
    lfc_act_reg <= lfc_act_next;
    lfc_send_reg <= lfc_send_next;
    pfc_req_reg <= pfc_req_next;
    pfc_act_reg <= pfc_act_next;
    pfc_en_reg <= pfc_en_next;
    pfc_send_reg <= pfc_send_next;

    mcf_pfc_sel_reg <= mcf_pfc_sel_next;
    mcf_valid_reg <= mcf_valid_next;

    quanta_cnt_reg <= quanta_cnt_next;
    quanta_inc_reg <= quanta_inc_next;

    lfc_refresh_reg <= lfc_refresh_next;
    for (integer k = 0; k < 8; k = k + 1) begin
        pfc_refresh_reg[k] <= pfc_refresh_next[k];
    end

    stat_tx_lfc_pkt_reg <= stat_tx_lfc_pkt_next;
    stat_tx_lfc_xon_reg <= stat_tx_lfc_xon_next;
    stat_tx_lfc_xoff_reg <= stat_tx_lfc_xoff_next;
    stat_tx_pfc_pkt_reg <= stat_tx_pfc_pkt_next;
    stat_tx_pfc_xon_reg <= stat_tx_pfc_xon_next;
    stat_tx_pfc_xoff_reg <= stat_tx_pfc_xoff_next;

    if (rst) begin
        lfc_req_reg <= 1'b0;
        lfc_act_reg <= 1'b0;
        lfc_send_reg <= 1'b0;
        pfc_req_reg <= '0;
        pfc_act_reg <= '0;
        pfc_send_reg <= '0;
        mcf_pfc_sel_reg <= PFC_EN != 0;
        mcf_valid_reg <= 1'b0;
        lfc_refresh_reg <= '0;
        for (integer k = 0; k < 8; k = k + 1) begin
            pfc_refresh_reg[k] <= '0;
        end

        stat_tx_lfc_pkt_reg <= 1'b0;
        stat_tx_lfc_xon_reg <= 1'b0;
        stat_tx_lfc_xoff_reg <= 1'b0;
        stat_tx_pfc_pkt_reg <= 1'b0;
        stat_tx_pfc_xon_reg <= '0;
        stat_tx_pfc_xoff_reg <= '0;
    end
end

endmodule

`resetall
