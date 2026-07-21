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
 * 1000BASE-X Ethernet PHY autonegotiation
 */
module taxi_eth_phy_1g_basex_an #
(
    parameter DATA_W = 16,
    parameter logic SGMII_EN = 1'b1
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * AN config register
     */
    input  wire logic [15:0]  rx_an_cfg,
    input  wire logic         rx_an_cfg_valid,
    input  wire logic         rx_an_ability_match,
    input  wire logic         rx_an_ack_match,
    input  wire logic         rx_an_idle_match,

    output wire logic [15:0]  tx_an_cfg,
    output wire logic         tx_an_cfg_valid,
    input  wire logic         tx_an_cfg_ready,

    /*
     * Autonegotiation
     */
    input  wire logic         an_en = 1'b1,
    input  wire logic         an_restart = 1'b0,
    input  wire logic         an_speedup = 1'b0,
    input  wire logic         an_timeout_en = 1'b1,
    input  wire logic         an_sgmii_en = 1'b0,
    input  wire logic         an_sgmii_auto = 1'b1,
    output wire logic         an_intr,
    output wire logic         an_running,
    output wire logic         an_complete,
    output wire logic         an_timeout,
    output wire logic         an_sgmii_mode,
    input  wire logic [15:0]  an_adv_ability_basex = 16'h0020,
    input  wire logic [15:0]  an_adv_ability_sgmii = 16'h0001,
    output wire logic [15:0]  an_lp_adv_ability,
    output wire logic [1:0]   an_lp_remote_fault,
    output wire logic         an_lp_sgmii_link,
    output wire logic [1:0]   an_lp_sgmii_speed,
    output wire logic         an_res_full_duplex,
    output wire logic         an_res_tx_pause,
    output wire logic         an_res_rx_pause
);

localparam logic [15:0] AN_ACK = 16'h4000;
localparam logic [15:0] AN_NP  = 16'h8000;

typedef enum logic [2:0] {
    STATE_START,
    STATE_AN_RESTART,
    STATE_ABILITY_DET,
    STATE_ACK_DET,
    STATE_ACK_CPL,
    STATE_IDLE_DET,
    STATE_DONE
} state_t;

state_t state_reg = STATE_START, state_next;

// 1 pulse per 100 us for timers
localparam CYC_PER_US = DATA_W == 16 ? 62.5 : 125;
localparam PRESC_CYC = $rtoi(CYC_PER_US*100);

logic [16:0] presc_cnt_reg = '0;
logic presc_pulse_reg = 1'b0;
logic [7:0] delay_cnt_reg = '0, delay_cnt_next;
logic delay_run_reg = 1'b0, delay_run_next;
logic [9:0] timeout_cnt_reg = '0, timeout_cnt_next;
logic timeout_run_reg = 1'b0, timeout_run_next;
logic [1:0] mode_mismatch_cnt_reg = '0, mode_mismatch_cnt_next;

logic [15:0]  tx_an_cfg_reg = '0, tx_an_cfg_next;
logic         tx_an_cfg_valid_reg = 1'b0, tx_an_cfg_valid_next;

logic         an_intr_reg = 1'b0, an_intr_next;
logic         an_running_reg = 1'b0, an_running_next;
logic         an_complete_reg = 1'b0, an_complete_next;
logic         an_timeout_reg = 1'b0, an_timeout_next;
logic         an_sgmii_mode_reg = 1'b0, an_sgmii_mode_next;
logic [15:0]  an_lp_adv_ability_reg = '0, an_lp_adv_ability_next;

assign tx_an_cfg = tx_an_cfg_reg;
assign tx_an_cfg_valid = tx_an_cfg_valid_reg;

assign an_intr = an_intr_reg;
assign an_running = an_running_reg;
assign an_complete = an_complete_reg;
assign an_timeout = an_timeout_reg;
assign an_sgmii_mode = an_sgmii_mode_reg;
assign an_lp_adv_ability = an_lp_adv_ability_reg;

// extract remote fault bits from link partner ability value
assign an_lp_remote_fault = an_sgmii_mode_reg ? 2'b00 : an_lp_adv_ability_reg[13:12];
assign an_lp_sgmii_link = an_sgmii_mode_reg ? an_lp_adv_ability_reg[15] : 1'b1;
assign an_lp_sgmii_speed = an_sgmii_mode_reg ? an_lp_adv_ability_reg[11:10] : 2'b10;
// fall back to half duplex only if both ends support it and at least one end does not support full duplex
assign an_res_full_duplex = an_sgmii_mode_reg ? an_lp_adv_ability_reg[12] : !((an_adv_ability_basex[6] && an_lp_adv_ability_reg[6]) && (!an_adv_ability_basex[5] || !an_lp_adv_ability_reg[5]));
// both sides support symmetric pause, or asymmetric pause towards link partner
assign an_res_tx_pause = an_sgmii_mode_reg ? 1'b0 : (an_adv_ability_basex[7] && an_lp_adv_ability_reg[7]) || (an_adv_ability_basex[8:7] == 2'b10 && an_lp_adv_ability_reg[8:7] == 2'b11);
// both sides support symmetric pause, or asymmetric pause towards local device
assign an_res_rx_pause = an_sgmii_mode_reg ? 1'b0 : (an_adv_ability_basex[7] && an_lp_adv_ability_reg[7]) || (an_adv_ability_basex[8:7] == 2'b11 && an_lp_adv_ability_reg[8:7] == 2'b10);

always_comb begin
    state_next = STATE_START;

    delay_cnt_next = delay_cnt_reg;
    delay_run_next = delay_run_reg;
    timeout_cnt_next = timeout_cnt_reg;
    timeout_run_next = timeout_run_reg;
    mode_mismatch_cnt_next = mode_mismatch_cnt_reg;

    tx_an_cfg_next = tx_an_cfg_reg;
    tx_an_cfg_valid_next = tx_an_cfg_valid_reg && !tx_an_cfg_ready;

    an_intr_next = 1'b0;
    an_running_next = an_running_reg;
    an_complete_next = an_complete_reg;
    an_timeout_next = an_timeout_reg;
    an_sgmii_mode_next = an_sgmii_mode_reg;
    an_lp_adv_ability_next = an_lp_adv_ability_reg;

    if (delay_run_reg) begin
        if (presc_pulse_reg) begin
            if (delay_cnt_reg != 0) begin
                delay_cnt_next = delay_cnt_reg - 1;
            end else begin
                delay_run_next = 1'b0;
            end
        end
    end else begin
        // 1000BASE-X: 10 ms timer
        // SGMII: 1.6 ms timer
        delay_cnt_next = an_sgmii_mode_reg ? 16 : 100;
    end

    if (timeout_run_reg) begin
        if (presc_pulse_reg) begin
            if (timeout_cnt_reg != 0) begin
                    timeout_cnt_next = timeout_cnt_reg - 1;
            end else begin
                timeout_run_next = 1'b0;
            end
        end
    end else begin
        // 100 ms timer
        timeout_cnt_next = 1000;
    end

    case (state_reg)
        STATE_START: begin
            // start
            an_running_next = 1'b0;
            an_complete_next = 1'b0;
            an_timeout_next = 1'b0;
            timeout_run_next = 1'b0;

            if (an_sgmii_en) begin
                an_sgmii_mode_next = 1'b1;
                mode_mismatch_cnt_next = '0;
            end else if (!an_sgmii_auto) begin
                an_sgmii_mode_next = 1'b0;
                mode_mismatch_cnt_next = '0;
            end

            tx_an_cfg_next = '0;

            if (an_en) begin
                tx_an_cfg_valid_next = 1'b1;
                if (delay_run_reg) begin
                    // restart link timer
                    delay_run_next = 1'b0;
                    state_next = STATE_START;
                end else begin
                    // AN restart state
                    delay_run_next = 1'b1;
                    an_running_next = 1'b1;
                    state_next = STATE_AN_RESTART;
                end
            end else begin
                // AN disabled
                an_sgmii_mode_next = 1'b0;
                state_next = STATE_START;
            end
        end
        STATE_AN_RESTART: begin
            // AN restart - send zeroed config reg to trigger link partner to restart the AN process
            tx_an_cfg_next = '0;
            tx_an_cfg_valid_next = 1'b1;

            if (!delay_run_reg) begin
                // link timer expired
                timeout_run_next = 1'b1;
                state_next = STATE_ABILITY_DET;
            end else begin
                state_next = STATE_AN_RESTART;
            end
        end
        STATE_ABILITY_DET: begin
            // ability detect state - transfer AN ability value with ACK clear
            tx_an_cfg_next = (an_sgmii_mode_reg ? an_adv_ability_sgmii : an_adv_ability_basex) & ~AN_ACK;
            tx_an_cfg_valid_next = 1'b1;

            if (rx_an_ability_match && rx_an_cfg != 0) begin
                // got ability advertisement from link partner
                an_lp_adv_ability_next = rx_an_cfg;
                state_next = STATE_ACK_DET;
            end else if (!timeout_run_reg && an_timeout_en) begin
                // timed out, no AN response from link partner
                an_timeout_next = 1'b1;
                if (!an_sgmii_en) begin
                    an_sgmii_mode_next = 1'b0;
                end
                mode_mismatch_cnt_next = '0;
                state_next = STATE_DONE;
            end else begin
                state_next = STATE_ABILITY_DET;
            end
        end
        STATE_ACK_DET: begin
            // acknowledge detect - wait for ACK from link partner
            tx_an_cfg_next = tx_an_cfg_reg | AN_ACK;
            tx_an_cfg_valid_next = 1'b1;

            if (rx_an_ability_match && rx_an_cfg == 0) begin
                // restart request from link partner
                state_next = STATE_START;
            end else if (rx_an_ack_match) begin
                // acknowledge match
                an_lp_adv_ability_next = rx_an_cfg;
                if (rx_an_cfg == (an_lp_adv_ability_reg | AN_ACK)) begin
                    // consistent with previously-seen value
                    delay_run_next = 1'b1;
                    state_next = STATE_ACK_CPL;
                end else begin
                    // inconsistent, restart AN
                    state_next = STATE_START;
                end
            end else begin
                state_next = STATE_ACK_DET;
            end
        end
        STATE_ACK_CPL: begin
            // complete acknowledge - give link partner time to detect our ACK
            tx_an_cfg_next = tx_an_cfg_reg | AN_ACK;
            tx_an_cfg_valid_next = 1'b1;

            if (rx_an_ability_match && rx_an_cfg == 0) begin
                // restart request from link partner
                state_next = STATE_START;
            end else if (!delay_run_reg) begin
                // link timer expired
                if (an_lp_adv_ability_reg[0] == an_sgmii_mode_reg) begin
                    // mode matches
                    delay_run_next = 1'b1;
                    state_next = STATE_IDLE_DET;
                end else begin
                    // mode mismatch, restart
                    if (an_sgmii_auto) begin
                        // in SGMII auto mode, switch modes after a few mismatches
                        if (&mode_mismatch_cnt_reg) begin
                            mode_mismatch_cnt_next = '0;
                            an_sgmii_mode_next = rx_an_cfg[0];
                        end else begin
                            mode_mismatch_cnt_next = mode_mismatch_cnt_reg + 1;
                        end
                    end
                    state_next = STATE_START;
                end
            end else begin
                state_next = STATE_ACK_CPL;
            end
        end
        STATE_IDLE_DET: begin
            // idle detect - wait for link to go idle
            if (rx_an_ability_match && rx_an_cfg == 0) begin
                // restart request from link partner
                state_next = STATE_START;
            end else if (rx_an_idle_match && !delay_run_reg) begin
                // idle match and link timer expired
                an_complete_next = 1'b1;
                state_next = STATE_DONE;
            end else begin
                state_next = STATE_IDLE_DET;
            end
        end
        STATE_DONE: begin
            // AN operation complete
            an_running_next = 1'b0;
            timeout_run_next = 1'b0;
            mode_mismatch_cnt_next = '0;

            if (rx_an_ability_match && rx_an_cfg == 0) begin
                // restart request from link partner
                state_next = STATE_START;
            end else begin
                state_next = STATE_DONE;
            end
        end
        default: begin
            state_next = STATE_START;
        end
    endcase

    if (!an_en || an_restart) begin
        state_next = STATE_START;
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    delay_cnt_reg <= delay_cnt_next;
    delay_run_reg <= delay_run_next;
    timeout_cnt_reg <= timeout_cnt_next;
    timeout_run_reg <= timeout_run_next;
    mode_mismatch_cnt_reg <= mode_mismatch_cnt_next;

    tx_an_cfg_reg <= tx_an_cfg_next;
    tx_an_cfg_valid_reg <= tx_an_cfg_valid_next;

    an_intr_reg <= an_intr_next;
    an_running_reg <= an_running_next;
    an_complete_reg <= an_complete_next;
    an_timeout_reg <= an_timeout_next;
    an_sgmii_mode_reg <= an_sgmii_mode_next;
    an_lp_adv_ability_reg <= an_lp_adv_ability_next;

    presc_pulse_reg <= 1'b0;
    if (presc_cnt_reg != 0) begin
        presc_cnt_reg <= presc_cnt_reg - 1;
    end else begin
        presc_pulse_reg <= 1'b1;
        presc_cnt_reg <= 17'(an_speedup ? PRESC_CYC / 1000 : PRESC_CYC);
    end

    if (rst) begin
        state_reg <= STATE_START;

        presc_cnt_reg <= '0;
        presc_pulse_reg <= 1'b0;
        delay_cnt_reg <= '0;
        delay_run_reg <= 1'b0;
        timeout_cnt_reg <= '0;
        timeout_run_reg <= 1'b0;
        mode_mismatch_cnt_reg <= '0;

        tx_an_cfg_valid_reg <= 1'b0;

        an_intr_reg <= 1'b0;
        an_running_reg <= 1'b0;
        an_complete_reg <= 1'b0;
        an_timeout_reg <= 1'b0;
        an_sgmii_mode_reg <= 1'b0;
    end
end

endmodule

`resetall
