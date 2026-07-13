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
 * USXGMII autonegotiation
 */
module taxi_eth_phy_10g_usxgmii_an #
(
    parameter DATA_W = 32
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Ordered sets
     */
    input  wire logic [23:0]  rx_os,
    input  wire logic         rx_os_sig,
    input  wire logic         rx_os_valid,
    input  wire logic         rx_os_match,
    input  wire logic         rx_idle_match,
    input  wire logic         rx_block_lock,

    output wire logic [23:0]  tx_os,
    output wire logic         tx_os_sig,
    output wire logic         tx_os_valid,
    input  wire logic         tx_os_ready,

    /*
     * USXGMII Autonegotiation
     */
    input  wire logic         an_en = 1'b1,
    input  wire logic         an_restart = 1'b0,
    input  wire logic         an_speedup = 1'b0,
    input  wire logic         an_timeout_en = 1'b1,
    input  wire logic         an_usxgmii_en = 1'b0,
    input  wire logic         an_usxgmii_auto = 1'b1,
    input  wire logic         an_usxgmii_5g = 1'b0,
    output wire logic         an_intr,
    output wire logic         an_running,
    output wire logic         an_complete,
    output wire logic         an_timeout,
    output wire logic         an_usxgmii_mode,
    input  wire logic [15:0]  an_adv_ability_usxgmii = 16'h1601,
    output wire logic [15:0]  an_lp_adv_ability,
    output wire logic         an_lp_usxgmii_link,
    output wire logic [2:0]   an_lp_usxgmii_speed,
    output wire logic         an_res_full_duplex
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
localparam CYC_PER_US = DATA_W == 64 ? 156 : 312;
localparam PRESC_CYC = $rtoi(CYC_PER_US*100);

logic [16:0] presc_cnt_reg = '0;
logic presc_pulse_reg = 1'b0;
logic [4:0] delay_cnt_reg = '0, delay_cnt_next;
logic delay_run_reg = 1'b0, delay_run_next;
logic [9:0] timeout_cnt_reg = '0, timeout_cnt_next;
logic timeout_run_reg = 1'b0, timeout_run_next;

logic [23:0]  tx_os_reg = '0, tx_os_next;
logic         tx_os_valid_reg = 1'b0, tx_os_valid_next;

logic         an_intr_reg = 1'b0, an_intr_next;
logic         an_running_reg = 1'b0, an_running_next;
logic         an_complete_reg = 1'b0, an_complete_next;
logic         an_timeout_reg = 1'b0, an_timeout_next;
logic         an_usxgmii_mode_reg = 1'b0, an_usxgmii_mode_next;
logic [15:0]  an_lp_adv_ability_reg = '0, an_lp_adv_ability_next;

assign tx_os = tx_os_reg;
assign tx_os_sig = 1'b0;
assign tx_os_valid = tx_os_valid_reg;

assign an_intr = an_intr_reg;
assign an_running = an_running_reg;
assign an_complete = an_complete_reg;
assign an_timeout = an_timeout_reg;
assign an_usxgmii_mode = an_usxgmii_mode_reg;
assign an_lp_adv_ability = an_lp_adv_ability_reg;

// extract config information from link partner ability value
assign an_lp_usxgmii_link = an_usxgmii_mode_reg ? an_lp_adv_ability_reg[15] : 1'b1;
assign an_lp_usxgmii_speed = an_usxgmii_mode_reg ? an_lp_adv_ability_reg[11:9] : 3'b011;
assign an_res_full_duplex = an_usxgmii_mode_reg ? an_lp_adv_ability_reg[12] : 1'b1;

// TODO: check for stabilized RX config reg values

always_comb begin
    state_next = STATE_START;

    delay_cnt_next = delay_cnt_reg;
    delay_run_next = delay_run_reg;
    timeout_cnt_next = timeout_cnt_reg;
    timeout_run_next = timeout_run_reg;

    tx_os_next = tx_os_reg;
    tx_os_valid_next = tx_os_valid_reg && !tx_os_ready;

    an_intr_next = 1'b0;
    an_running_next = an_running_reg;
    an_complete_next = an_complete_reg;
    an_timeout_next = an_timeout_reg;
    an_usxgmii_mode_next = an_usxgmii_mode_reg;
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
        // USXGMII: 1.6 ms timer
        delay_cnt_next = 16;
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

            if (an_usxgmii_en) begin
                an_usxgmii_mode_next = 1'b1;
            end else if (!an_usxgmii_auto) begin
                an_usxgmii_mode_next = 1'b0;
            end

            tx_os_next = {16'd0, 8'h03};

            if (an_en) begin
                if (!an_usxgmii_mode_next) begin
                    state_next = STATE_DONE;
                end else begin
                    tx_os_valid_next = 1'b1;
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
                end
            end else begin
                // AN disabled
                an_usxgmii_mode_next = 1'b0;
                state_next = STATE_START;
            end
        end
        STATE_AN_RESTART: begin
            // AN restart - send zeroed config reg to trigger link partner to restart the AN process
            tx_os_next = {16'd0, 8'h03};
            tx_os_valid_next = 1'b1;

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
            tx_os_next[23:8] = an_adv_ability_usxgmii & ~AN_ACK;
            tx_os_valid_next = 1'b1;

            if (rx_os_match && rx_os[23:8] != 0 && rx_os[7:0] == 8'h03) begin
                // got USXGMII ability advertisement from link partner
                an_lp_adv_ability_next = rx_os[23:8];
                state_next = STATE_ACK_DET;
            end else if (!timeout_run_reg && an_timeout_en) begin
                // timed out, no AN response from link partner
                an_timeout_next = 1'b1;
                if (!an_usxgmii_en) begin
                    an_usxgmii_mode_next = 1'b0;
                end
                state_next = STATE_DONE;
            end else begin
                state_next = STATE_ABILITY_DET;
            end
        end
        STATE_ACK_DET: begin
            // acknowledge detect - wait for ACK from link partner
            tx_os_next[23:8] = tx_os_reg[23:8] | AN_ACK;
            tx_os_valid_next = 1'b1;

            if (rx_os_match && rx_os[23:8] == 0 && rx_os[7:0] == 8'h03) begin
                // restart request from link partner
                state_next = STATE_START;
            end else if (rx_os_match && rx_os[14+8] && rx_os[7:0] == 8'h03) begin
                // acknowledge match
                an_lp_adv_ability_next = rx_os[23:8];
                if (rx_os[23:8] == (an_lp_adv_ability_reg | AN_ACK)) begin
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
            tx_os_next[23:8] = tx_os_reg[23:8] | AN_ACK;
            tx_os_valid_next = 1'b1;

            if (rx_os_match && rx_os[23:8] == 0 && rx_os[7:0] == 8'h03) begin
                // restart request from link partner
                state_next = STATE_START;
            end else if (!delay_run_reg) begin
                // link timer expired
                if (an_lp_adv_ability_reg[0] == 1'b1 && rx_os[7:0] == 8'h03) begin
                    // mode matches
                    delay_run_next = 1'b1;
                    state_next = STATE_IDLE_DET;
                end else begin
                    // mode mismatch
                    if (an_usxgmii_en) begin
                        state_next = STATE_START;
                    end else begin
                        an_usxgmii_mode_next = 1'b0;
                        state_next = STATE_DONE;
                    end
                end
            end else begin
                state_next = STATE_ACK_CPL;
            end
        end
        STATE_IDLE_DET: begin
            // idle detect - wait for link to go idle
            if (rx_os_match && rx_os[23:8] == 0 && rx_os[7:0] == 8'h03) begin
                // restart request from link partner
                state_next = STATE_START;
            end else if (rx_idle_match && !delay_run_reg) begin
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

            if (rx_os_match && rx_os[23:8] == 0 && rx_os[7:0] == 8'h03) begin
                // restart request from link partner
                an_usxgmii_mode_next = 1'b1;
                state_next = STATE_START;
            end else begin
                state_next = STATE_DONE;
            end
        end
        default: begin
            state_next = STATE_START;
        end
    endcase

    if (!an_en || an_restart || !rx_block_lock) begin
        an_usxgmii_mode_next = an_en && an_usxgmii_en;
        if (an_usxgmii_en) begin
            an_usxgmii_mode_next = 1'b1;
        end else if (!an_usxgmii_auto) begin
            an_usxgmii_mode_next = 1'b0;
        end else if (an_usxgmii_auto && rx_os_match && rx_os[7:0] == 8'h03) begin
            an_usxgmii_mode_next = 1'b1;
        end
        state_next = STATE_START;
    end
end

always @(posedge clk) begin
    state_reg <= state_next;

    delay_cnt_reg <= delay_cnt_next;
    delay_run_reg <= delay_run_next;
    timeout_cnt_reg <= timeout_cnt_next;
    timeout_run_reg <= timeout_run_next;

    tx_os_reg <= tx_os_next;
    tx_os_valid_reg <= tx_os_valid_next;

    an_intr_reg <= an_intr_next;
    an_running_reg <= an_running_next;
    an_complete_reg <= an_complete_next;
    an_timeout_reg <= an_timeout_next;
    an_usxgmii_mode_reg <= an_usxgmii_mode_next;
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

        tx_os_valid_reg <= 1'b0;

        an_intr_reg <= 1'b0;
        an_running_reg <= 1'b0;
        an_complete_reg <= 1'b0;
        an_timeout_reg <= 1'b0;
        an_usxgmii_mode_reg <= 1'b0;
    end
end

endmodule

`resetall
