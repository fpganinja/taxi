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
 * PFC and pause frame receive handling
 */
module taxi_mac_pause_ctrl_rx #
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
    input  wire logic                          mcf_valid,
    input  wire logic [47:0]                   mcf_eth_dst,
    input  wire logic [47:0]                   mcf_eth_src,
    input  wire logic [15:0]                   mcf_eth_type,
    input  wire logic [15:0]                   mcf_opcode,
    input  wire logic [MCF_PARAMS_SIZE*8-1:0]  mcf_params,

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    input  wire logic                          rx_lfc_en,
    output wire logic                          rx_lfc_req,
    input  wire logic                          rx_lfc_ack,

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    input  wire logic [7:0]                    rx_pfc_en,
    output wire logic [7:0]                    rx_pfc_req,
    input  wire logic [7:0]                    rx_pfc_ack,

    /*
     * Configuration
     */
    input  wire logic [15:0]                   cfg_rx_lfc_opcode = 16'h0001,
    input  wire logic                          cfg_rx_lfc_en = 1'b0,
    input  wire logic [15:0]                   cfg_rx_pfc_opcode = 16'h0101,
    input  wire logic                          cfg_rx_pfc_en = 1'b0,
    input  wire logic [9:0]                    cfg_quanta_step,
    input  wire logic                          cfg_quanta_clk_en = 1'b1,

    /*
     * Status
     */
    output wire logic                          stat_rx_lfc_pkt,
    output wire logic                          stat_rx_lfc_xon,
    output wire logic                          stat_rx_lfc_xoff,
    output wire logic                          stat_rx_lfc_paused,
    output wire logic                          stat_rx_pfc_pkt,
    output wire logic [7:0]                    stat_rx_pfc_xon,
    output wire logic [7:0]                    stat_rx_pfc_xoff,
    output wire logic [7:0]                    stat_rx_pfc_paused
);

localparam QW = 16;
localparam QFB = 8;

// check configuration
if (MCF_PARAMS_SIZE < (PFC_EN ? 18 : 2))
    $fatal(0, "Error: MCF_PARAMS_SIZE too small for requested configuration (instance %m)");

logic lfc_req_reg = 1'b0, lfc_req_next;
logic [7:0] pfc_req_reg = 8'd0, pfc_req_next;

logic [QFB-1:0] quanta_cnt_reg = '0, quanta_cnt_next;
logic [1:0] quanta_inc_reg = '0, quanta_inc_next;

logic [QW-1:0] lfc_quanta_reg = '0, lfc_quanta_next;
logic [QW-1:0] pfc_quanta_reg[8] = '{default: '0}, pfc_quanta_next[8];

logic stat_rx_lfc_pkt_reg = 1'b0, stat_rx_lfc_pkt_next;
logic stat_rx_lfc_xon_reg = 1'b0, stat_rx_lfc_xon_next;
logic stat_rx_lfc_xoff_reg = 1'b0, stat_rx_lfc_xoff_next;
logic stat_rx_pfc_pkt_reg = 1'b0, stat_rx_pfc_pkt_next;
logic [7:0] stat_rx_pfc_xon_reg = '0, stat_rx_pfc_xon_next;
logic [7:0] stat_rx_pfc_xoff_reg = '0, stat_rx_pfc_xoff_next;

assign rx_lfc_req = lfc_req_reg;
assign rx_pfc_req = pfc_req_reg;

assign stat_rx_lfc_pkt = stat_rx_lfc_pkt_reg;
assign stat_rx_lfc_xon = stat_rx_lfc_xon_reg;
assign stat_rx_lfc_xoff = stat_rx_lfc_xoff_reg;
assign stat_rx_lfc_paused = lfc_req_reg;
assign stat_rx_pfc_pkt = stat_rx_pfc_pkt_reg;
assign stat_rx_pfc_xon = stat_rx_pfc_xon_reg;
assign stat_rx_pfc_xoff = stat_rx_pfc_xoff_reg;
assign stat_rx_pfc_paused = pfc_req_reg;

always_comb begin
    stat_rx_lfc_pkt_next = 1'b0;
    stat_rx_lfc_xon_next = 1'b0;
    stat_rx_lfc_xoff_next = 1'b0;
    stat_rx_pfc_pkt_next = 1'b0;
    stat_rx_pfc_xon_next = '0;
    stat_rx_pfc_xoff_next = '0;

    quanta_cnt_next = quanta_cnt_reg;
    quanta_inc_next = 0;
    if (cfg_quanta_clk_en) begin
        {quanta_inc_next, quanta_cnt_next} = (2+QFB)'(quanta_cnt_reg) + cfg_quanta_step;
    end

    if (rx_lfc_ack) begin
        if (lfc_quanta_reg >= QW'(quanta_inc_reg)) begin
            lfc_quanta_next = lfc_quanta_reg - QW'(quanta_inc_reg);
        end else begin
            lfc_quanta_next = '0;
        end
    end else begin
        lfc_quanta_next = lfc_quanta_reg;
    end

    lfc_req_next = (lfc_quanta_reg != 0) && rx_lfc_en && cfg_rx_lfc_en;

    for (integer k = 0; k < 8; k = k + 1) begin
        if (rx_pfc_ack[k]) begin
            if (pfc_quanta_reg[k] >= QW'(quanta_inc_reg)) begin
                pfc_quanta_next[k] = pfc_quanta_reg[k] - QW'(quanta_inc_reg);
            end else begin
                pfc_quanta_next[k] = '0;
            end
        end else begin
            pfc_quanta_next[k] = pfc_quanta_reg[k];
        end

        pfc_req_next[k] = (pfc_quanta_reg[k] != 0) && rx_pfc_en[k] && cfg_rx_pfc_en;
    end

    if (mcf_valid) begin
        if (mcf_opcode == cfg_rx_lfc_opcode && cfg_rx_lfc_en) begin
            stat_rx_lfc_pkt_next = 1'b1;
            stat_rx_lfc_xon_next = {mcf_params[7:0], mcf_params[15:8]} == 0;
            stat_rx_lfc_xoff_next = {mcf_params[7:0], mcf_params[15:8]} != 0;
            lfc_quanta_next = {mcf_params[7:0], mcf_params[15:8]};
        end else if (PFC_EN && mcf_opcode == cfg_rx_pfc_opcode && cfg_rx_pfc_en) begin
            stat_rx_pfc_pkt_next = 1'b1;
            for (integer k = 0; k < 8; k = k + 1) begin
                if (mcf_params[k+8]) begin
                    stat_rx_pfc_xon_next[k] = {mcf_params[16+(k*QW)+0 +: 8], mcf_params[16+(k*QW)+8 +: 8]} == 0;
                    stat_rx_pfc_xoff_next[k] = {mcf_params[16+(k*QW)+0 +: 8], mcf_params[16+(k*QW)+8 +: 8]} != 0;
                    pfc_quanta_next[k] = {mcf_params[16+(k*QW)+0 +: 8], mcf_params[16+(k*QW)+8 +: 8]};
                end
            end
        end
    end
end

always_ff @(posedge clk) begin
    lfc_req_reg <= lfc_req_next;
    pfc_req_reg <= pfc_req_next;

    quanta_cnt_reg <= quanta_cnt_next;
    quanta_inc_reg <= quanta_inc_next;

    lfc_quanta_reg <= lfc_quanta_next;
    for (integer k = 0; k < 8; k = k + 1) begin
        pfc_quanta_reg[k] <= pfc_quanta_next[k];
    end

    stat_rx_lfc_pkt_reg <= stat_rx_lfc_pkt_next;
    stat_rx_lfc_xon_reg <= stat_rx_lfc_xon_next;
    stat_rx_lfc_xoff_reg <= stat_rx_lfc_xoff_next;
    stat_rx_pfc_pkt_reg <= stat_rx_pfc_pkt_next;
    stat_rx_pfc_xon_reg <= stat_rx_pfc_xon_next;
    stat_rx_pfc_xoff_reg <= stat_rx_pfc_xoff_next;

    if (rst) begin
        lfc_req_reg <= 1'b0;
        pfc_req_reg <= 8'd0;
        lfc_quanta_reg <= '0;
        for (integer k = 0; k < 8; k = k + 1) begin
            pfc_quanta_reg[k] <= '0;
        end

        stat_rx_lfc_pkt_reg <= 1'b0;
        stat_rx_lfc_xon_reg <= 1'b0;
        stat_rx_lfc_xoff_reg <= 1'b0;
        stat_rx_pfc_pkt_reg <= 1'b0;
        stat_rx_pfc_xon_reg <= '0;
        stat_rx_pfc_xoff_reg <= '0;
    end
end

endmodule

`resetall
