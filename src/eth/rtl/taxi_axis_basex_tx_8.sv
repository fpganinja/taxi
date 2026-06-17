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
 * AXI4-Stream 1000BASE-X frame transmitter (AXI in, 1000BASE-X out)
 */
module taxi_axis_basex_tx_8 #
(
    parameter DATA_W = 8,
    parameter CTRL_W = (DATA_W/8),
    parameter logic PADDING_EN = 1'b1,
    parameter MIN_FRAME_LEN = 64,
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1,
    parameter logic AN_EN = 1'b1,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter PTP_TS_W = 96,
    parameter logic TX_CPL_CTRL_IN_TUSER = 1'b1
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * Transmit interface (AXI stream)
     */
    taxi_axis_if.snk                  s_axis_tx,
    taxi_axis_if.src                  m_axis_tx_cpl,

    /*
     * 1000BASE-X encoded interface
     */
    output wire logic [DATA_W-1:0]    encoded_tx_data,
    output wire logic [CTRL_W-1:0]    encoded_tx_data_k,
    output wire logic [CTRL_W-1:0]    encoded_tx_data_dm,
    output wire logic [CTRL_W-1:0]    encoded_tx_data_dv,
    output wire logic                 encoded_tx_data_valid,
    input  wire logic [GBX_CNT-1:0]   tx_gbx_req_sync = '0,
    input  wire logic                 tx_gbx_req_stall = '0,
    output wire logic [GBX_CNT-1:0]   tx_gbx_sync,

    /*
     * AN config register
     */
    input  wire logic [15:0]          tx_an_cfg = '0,
    input  wire logic                 tx_an_cfg_valid = 1'b0,
    output wire logic                 tx_an_cfg_ready,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_tx_max_pkt_len = 16'd1518-1,
    input  wire logic [7:0]           cfg_tx_ifg = 8'd12,
    input  wire logic                 cfg_tx_enable,

    /*
     * Status
     */
    output wire logic                 tx_start_packet,
    output wire logic                 stat_tx_byte,
    output wire logic [15:0]          stat_tx_pkt_len,
    output wire logic                 stat_tx_pkt_ucast,
    output wire logic                 stat_tx_pkt_mcast,
    output wire logic                 stat_tx_pkt_bcast,
    output wire logic                 stat_tx_pkt_vlan,
    output wire logic                 stat_tx_pkt_good,
    output wire logic                 stat_tx_pkt_bad,
    output wire logic                 stat_tx_err_oversize,
    output wire logic                 stat_tx_err_user,
    output wire logic                 stat_tx_err_underflow
);

localparam USER_W = TX_CPL_CTRL_IN_TUSER ? 2 : 1;
localparam TX_TAG_W = s_axis_tx.ID_W;

localparam MIN_LEN_W = $clog2(MIN_FRAME_LEN-4-1+1);

// check configuration
if (DATA_W != 8)
    $fatal(0, "Error: Interface width must be 8 (instance %m)");

if (s_axis_tx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (s_axis_tx.USER_W != USER_W)
    $fatal(0, "Error: Interface USER_W parameter mismatch (instance %m)");

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

typedef enum logic [3:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PAYLOAD,
    STATE_LAST,
    STATE_PAD,
    STATE_FCS,
    STATE_T,
    STATE_R,
    STATE_IFG,
    STATE_AN
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic [7:0] s_tdata_reg = 8'd0, s_tdata_next;

logic frame_reg = 1'b0, frame_next;
logic frame_error_reg = 1'b0, frame_error_next;
logic [MIN_LEN_W-1:0] frame_min_count_reg = '0, frame_min_count_next;
logic [3:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [15:0] frame_len_lim_reg = '0, frame_len_lim_next;
logic [1:0] fcs_ptr_reg = '0, fcs_ptr_next;
logic [2:0] pre_cnt_reg = '0, pre_cnt_next;
logic [7:0] ifg_cnt_reg = '0, ifg_cnt_next;
logic deficit_idle_cnt_reg = 1'd0, deficit_idle_cnt_next;
logic odd_reg = 1'b0, odd_next;
logic an_phase_reg = 1'b0, an_phase_next;
logic rd_reg = 1'b0, rd_next;

logic [DATA_W-1:0] encoded_tx_data_reg = '0, encoded_tx_data_next;
logic [CTRL_W-1:0] encoded_tx_data_k_reg = '0, encoded_tx_data_k_next;
logic [CTRL_W-1:0] encoded_tx_data_dm_reg = '0, encoded_tx_data_dm_next;
logic [CTRL_W-1:0] encoded_tx_data_dv_reg = '0, encoded_tx_data_dv_next;
logic encoded_tx_data_valid_reg = 1'b0;
logic [GBX_CNT-1:0] tx_gbx_sync_reg = '0;

logic s_axis_tx_tready_reg = 1'b0, s_axis_tx_tready_next;

logic [PTP_TS_W-1:0] m_axis_tx_cpl_ts_reg = '0, m_axis_tx_cpl_ts_next;
logic [TX_TAG_W-1:0] m_axis_tx_cpl_tag_reg = '0, m_axis_tx_cpl_tag_next;
logic m_axis_tx_cpl_valid_reg = 1'b0, m_axis_tx_cpl_valid_next;

logic tx_an_cfg_ready_reg = 1'b0, tx_an_cfg_ready_next;

logic start_packet_int_reg = 1'b0, start_packet_int_next;
logic start_packet_reg = 1'b0, start_packet_next;

logic stat_tx_byte_reg = 1'b0, stat_tx_byte_next;
logic [15:0] stat_tx_pkt_len_reg = '0, stat_tx_pkt_len_next;
logic stat_tx_pkt_ucast_reg = 1'b0, stat_tx_pkt_ucast_next;
logic stat_tx_pkt_mcast_reg = 1'b0, stat_tx_pkt_mcast_next;
logic stat_tx_pkt_bcast_reg = 1'b0, stat_tx_pkt_bcast_next;
logic stat_tx_pkt_vlan_reg = 1'b0, stat_tx_pkt_vlan_next;
logic stat_tx_pkt_good_reg = 1'b0, stat_tx_pkt_good_next;
logic stat_tx_pkt_bad_reg = 1'b0, stat_tx_pkt_bad_next;
logic stat_tx_err_oversize_reg = 1'b0, stat_tx_err_oversize_next;
logic stat_tx_err_user_reg = 1'b0, stat_tx_err_user_next;
logic stat_tx_err_underflow_reg = 1'b0, stat_tx_err_underflow_next;

logic [31:0] crc_state_reg = '1;
wire [31:0] crc_state;

assign s_axis_tx.tready = s_axis_tx_tready_reg && (!GBX_IF_EN || !tx_gbx_req_stall);

assign encoded_tx_data = encoded_tx_data_reg;
assign encoded_tx_data_k = encoded_tx_data_k_reg;
assign encoded_tx_data_dm = encoded_tx_data_dm_reg;
assign encoded_tx_data_dv = encoded_tx_data_dv_reg;
assign encoded_tx_data_valid = GBX_IF_EN ? encoded_tx_data_valid_reg : 1'b1;
assign tx_gbx_sync = GBX_IF_EN ? tx_gbx_sync_reg : '0;

assign m_axis_tx_cpl.tdata = PTP_TS_EN ? m_axis_tx_cpl_ts_reg : '0;
assign m_axis_tx_cpl.tkeep = 1'b1;
assign m_axis_tx_cpl.tstrb = m_axis_tx_cpl.tkeep;
assign m_axis_tx_cpl.tvalid = m_axis_tx_cpl_valid_reg;
assign m_axis_tx_cpl.tlast = 1'b1;
assign m_axis_tx_cpl.tid = m_axis_tx_cpl_tag_reg;
assign m_axis_tx_cpl.tdest = '0;
assign m_axis_tx_cpl.tuser = '0;

assign tx_an_cfg_ready = AN_EN ? tx_an_cfg_ready_reg : 1'b0;

assign tx_start_packet = start_packet_reg;
assign stat_tx_byte = stat_tx_byte_reg;
assign stat_tx_pkt_len = stat_tx_pkt_len_reg;
assign stat_tx_pkt_ucast = stat_tx_pkt_ucast_reg;
assign stat_tx_pkt_mcast = stat_tx_pkt_mcast_reg;
assign stat_tx_pkt_bcast = stat_tx_pkt_bcast_reg;
assign stat_tx_pkt_vlan = stat_tx_pkt_vlan_reg;
assign stat_tx_pkt_good = stat_tx_pkt_good_reg;
assign stat_tx_pkt_bad = stat_tx_pkt_bad_reg;
assign stat_tx_err_oversize = stat_tx_err_oversize_reg;
assign stat_tx_err_user = stat_tx_err_user_reg;
assign stat_tx_err_underflow = stat_tx_err_underflow_reg;

taxi_lfsr #(
    .LFSR_W(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_GALOIS(1),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_W(DATA_W),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b0)
)
eth_crc_8 (
    .data_in(s_tdata_reg),
    .state_in(crc_state_reg),
    .data_out(),
    .state_out(crc_state)
);

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_next = frame_reg;
    frame_error_next = frame_error_reg;
    frame_min_count_next = frame_min_count_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_next = frame_len_lim_reg;
    fcs_ptr_next = fcs_ptr_reg;
    pre_cnt_next = pre_cnt_reg;
    ifg_cnt_next = ifg_cnt_reg;
    deficit_idle_cnt_next = deficit_idle_cnt_reg;
    odd_next = odd_reg;
    an_phase_next = an_phase_reg;
    rd_next = rd_reg;

    s_axis_tx_tready_next = 1'b0;

    tx_an_cfg_ready_next = 1'b0;

    s_tdata_next = s_tdata_reg;

    m_axis_tx_cpl_ts_next = m_axis_tx_cpl_ts_reg;
    m_axis_tx_cpl_tag_next = m_axis_tx_cpl_tag_reg;
    m_axis_tx_cpl_valid_next = 1'b0;

    if (start_packet_reg) begin
        m_axis_tx_cpl_ts_next = ptp_ts;
        if (TX_CPL_CTRL_IN_TUSER) begin
            m_axis_tx_cpl_valid_next = (s_axis_tx.tuser >> 1) == 0;
        end else begin
            m_axis_tx_cpl_valid_next = 1'b1;
        end
    end

    encoded_tx_data_next = '0;
    encoded_tx_data_k_next = 1'b0;
    encoded_tx_data_dm_next = 1'b0;
    encoded_tx_data_dv_next = 1'b0;

    start_packet_int_next = start_packet_int_reg;
    start_packet_next = 1'b0;

    stat_tx_byte_next = 1'b0;
    stat_tx_pkt_len_next = '0;
    stat_tx_pkt_ucast_next = 1'b0;
    stat_tx_pkt_mcast_next = 1'b0;
    stat_tx_pkt_bcast_next = 1'b0;
    stat_tx_pkt_vlan_next = 1'b0;
    stat_tx_pkt_good_next = 1'b0;
    stat_tx_pkt_bad_next = 1'b0;
    stat_tx_err_oversize_next = 1'b0;
    stat_tx_err_user_next = 1'b0;
    stat_tx_err_underflow_next = 1'b0;

    if (s_axis_tx.tvalid && s_axis_tx.tready) begin
        frame_next = !s_axis_tx.tlast;
    end

    if (GBX_IF_EN && tx_gbx_req_stall) begin
        // gearbox stall - hold state
        state_next = state_reg;
        s_axis_tx_tready_next = s_axis_tx_tready_reg;
    end else begin
        odd_next = !odd_reg;

        // counter for min frame length enforcement
        if (frame_min_count_reg != 0) begin
            frame_min_count_next = frame_min_count_reg - 1;
        end

        // counter to measure frame length
        if (&frame_len_reg == 0) begin
            frame_len_next = frame_len_reg + 1;
        end

        // counter for max frame length enforcement
        if (frame_len_lim_reg != 0) begin
            frame_len_lim_next = frame_len_lim_reg - 1;
        end

        // address and ethertype checks
        if (&hdr_ptr_reg == 0) begin
            hdr_ptr_next = hdr_ptr_reg + 1;
        end

        case (hdr_ptr_reg)
            4'd0: begin
                is_mcast_next = s_tdata_reg[0];
                is_bcast_next = s_tdata_reg == 8'hff;
            end
            4'd1: is_bcast_next = is_bcast_reg && s_tdata_reg == 8'hff;
            4'd2: is_bcast_next = is_bcast_reg && s_tdata_reg == 8'hff;
            4'd3: is_bcast_next = is_bcast_reg && s_tdata_reg == 8'hff;
            4'd4: is_bcast_next = is_bcast_reg && s_tdata_reg == 8'hff;
            4'd5: is_bcast_next = is_bcast_reg && s_tdata_reg == 8'hff;
            4'd12: is_8021q_next = s_tdata_reg == 8'h81;
            4'd13: is_8021q_next = is_8021q_reg && s_tdata_reg == 8'h00;
            default: begin
                // do nothing
            end
        endcase

        if (&fcs_ptr_reg == 0) begin
            fcs_ptr_next = fcs_ptr_reg + 1;
        end

        if (pre_cnt_reg != 0) begin
            pre_cnt_next = pre_cnt_reg - 1;
        end

        if (ifg_cnt_reg != 0) begin
            ifg_cnt_next = ifg_cnt_reg - 1;
        end

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;

                hdr_ptr_next = 0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_tx_max_pkt_len;
                pre_cnt_next = 3'd6;

                frame_error_next = 1'b0;
                frame_min_count_next = MIN_LEN_W'(MIN_FRAME_LEN-4-1);

                m_axis_tx_cpl_tag_next = s_axis_tx.tid;

                // generate idles
                if (!odd_reg) begin
                    encoded_tx_data_next = K(28,5);
                    encoded_tx_data_k_next = 1'b1;
                    encoded_tx_data_dm_next = 1'b1;
                    encoded_tx_data_dv_next = rd_reg;
                end else begin
                    encoded_tx_data_next = rd_reg ? D(16,2) : D(5,6);
                    encoded_tx_data_k_next = 1'b0;
                    encoded_tx_data_dm_next = 1'b1;
                    encoded_tx_data_dv_next = rd_reg;
                end

                if (!odd_reg && s_axis_tx.tvalid && cfg_tx_enable) begin
                    encoded_tx_data_next = CTRL_S;
                    encoded_tx_data_k_next = 1'b1;
                    state_next = STATE_PREAMBLE;
                end else if (AN_EN && odd_reg && tx_an_cfg_valid) begin
                    encoded_tx_data_next = an_phase_reg ? D(2,2) : D(21,5);
                    encoded_tx_data_k_next = 1'b0;
                    state_next = STATE_AN;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // send preamble
                reset_crc = 1'b1;

                hdr_ptr_next = 0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_tx_max_pkt_len;

                frame_error_next = 1'b0;
                frame_min_count_next = MIN_LEN_W'(MIN_FRAME_LEN-4-1);

                encoded_tx_data_next = ETH_PRE;
                encoded_tx_data_k_next = 1'b0;

                start_packet_int_next = 1'b0;

                if (pre_cnt_reg == 1) begin
                    s_axis_tx_tready_next = 1'b1;
                    s_tdata_next = s_axis_tx.tdata;
                    state_next = STATE_PREAMBLE;
                end else if (pre_cnt_reg == 0) begin
                    // end of preamble; start payload
                    if (s_axis_tx_tready_reg) begin
                        s_axis_tx_tready_next = 1'b1;
                        s_tdata_next = s_axis_tx.tdata;
                    end
                    encoded_tx_data_next = ETH_SFD;
                    encoded_tx_data_k_next = 1'b0;
                    start_packet_int_next = 1'b1;
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_PREAMBLE;
                end
            end
            STATE_PAYLOAD: begin
                // send payload

                update_crc = 1'b1;
                s_axis_tx_tready_next = 1'b1;

                encoded_tx_data_next = s_tdata_reg;
                encoded_tx_data_k_next = 1'b0;

                s_tdata_next = s_axis_tx.tdata;

                stat_tx_byte_next = 1'b1;
                start_packet_next = start_packet_int_reg;
                start_packet_int_next = 1'b0;

                if (!s_axis_tx.tvalid || s_axis_tx.tlast || frame_len_lim_reg < 6) begin
                    s_axis_tx_tready_next = frame_next; // drop frame
                    stat_tx_err_oversize_next = !s_axis_tx.tlast && frame_len_lim_reg < 6;
                    frame_error_next = !s_axis_tx.tvalid || s_axis_tx.tuser[0] || stat_tx_err_oversize_next;
                    stat_tx_err_user_next = s_axis_tx.tuser[0];
                    stat_tx_err_underflow_next = !s_axis_tx.tvalid;

                    state_next = STATE_LAST;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_LAST: begin
                // last payload word

                update_crc = 1'b1;
                s_axis_tx_tready_next = frame_next; // drop frame

                fcs_ptr_next = 2'd0;

                encoded_tx_data_next = s_tdata_reg;
                encoded_tx_data_k_next = 1'b0;

                if (frame_error_reg) begin
                    encoded_tx_data_next = CTRL_V;
                    encoded_tx_data_k_next = 1'b1;
                end

                s_tdata_next = 8'd0;

                stat_tx_byte_next = 1'b1;

                if (PADDING_EN && frame_min_count_reg != 0) begin
                    state_next = STATE_PAD;
                end else begin
                    state_next = STATE_FCS;
                end
            end
            STATE_PAD: begin
                // send padding
                s_axis_tx_tready_next = frame_next; // drop frame

                update_crc = 1'b1;
                fcs_ptr_next = 2'd0;

                encoded_tx_data_next = s_tdata_reg;
                encoded_tx_data_k_next = 1'b0;

                if (frame_error_reg) begin
                    encoded_tx_data_next = CTRL_V;
                    encoded_tx_data_k_next = 1'b1;
                end

                s_tdata_next = 8'd0;

                stat_tx_byte_next = 1'b1;

                if (frame_min_count_reg != 0) begin
                    state_next = STATE_PAD;
                end else begin
                    state_next = STATE_FCS;
                end
            end
            STATE_FCS: begin
                // send FCS
                s_axis_tx_tready_next = frame_next; // drop frame

                ifg_cnt_next = cfg_tx_ifg + 8'(deficit_idle_cnt_reg);

                case (fcs_ptr_reg)
                    2'd0: encoded_tx_data_next = ~crc_state_reg[7:0];
                    2'd1: encoded_tx_data_next = ~crc_state_reg[15:8];
                    2'd2: encoded_tx_data_next = ~crc_state_reg[23:16];
                    2'd3: encoded_tx_data_next = ~crc_state_reg[31:24];
                endcase
                encoded_tx_data_k_next = 1'b0;

                if (frame_error_reg) begin
                    encoded_tx_data_next = CTRL_V;
                    encoded_tx_data_k_next = 1'b1;
                end

                stat_tx_byte_next = 1'b1;

                if (&fcs_ptr_reg == 0) begin
                    state_next = STATE_FCS;
                end else begin
                    stat_tx_pkt_len_next = frame_len_reg;
                    stat_tx_pkt_good_next = !frame_error_reg;
                    stat_tx_pkt_bad_next = frame_error_reg;
                    stat_tx_pkt_ucast_next = !is_mcast_reg;
                    stat_tx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                    stat_tx_pkt_bcast_next = is_bcast_reg;
                    stat_tx_pkt_vlan_next = is_8021q_reg;
                    state_next = STATE_T;
                end
            end
            STATE_T: begin
                // send T
                s_axis_tx_tready_next = frame_next; // drop frame

                encoded_tx_data_next = CTRL_T;
                encoded_tx_data_k_next = 1'b1;

                state_next = STATE_R;
            end
            STATE_R: begin
                // send R
                s_axis_tx_tready_next = frame_next; // drop frame

                encoded_tx_data_next = CTRL_R;
                encoded_tx_data_k_next = 1'b1;

                if (odd_reg) begin
                    state_next = STATE_IFG;
                end else begin
                    state_next = STATE_R;
                end
            end
            STATE_IFG: begin
                // send IFG
                s_axis_tx_tready_next = frame_next; // drop frame

                // generate idles
                if (!odd_reg) begin
                    encoded_tx_data_next = K(28,5);
                    encoded_tx_data_k_next = 1'b1;
                    encoded_tx_data_dm_next = 1'b1;
                    encoded_tx_data_dv_next = rd_reg;
                end else begin
                    encoded_tx_data_next = rd_reg ? D(16,2) : D(5,6);
                    encoded_tx_data_k_next = 1'b0;
                    encoded_tx_data_dm_next = 1'b1;
                    encoded_tx_data_dv_next = rd_reg;
                end

                if (DIC_EN) begin
                    if (ifg_cnt_next > 8'd1 || !odd_reg || frame_reg) begin
                        state_next = STATE_IFG;
                    end else begin
                        deficit_idle_cnt_next = 1'(ifg_cnt_next);
                        ifg_cnt_next = 8'd0;
                        state_next = STATE_IDLE;
                    end
                end else begin
                    if (ifg_cnt_next > 8'd0 || frame_reg) begin
                        state_next = STATE_IFG;
                    end else begin
                        state_next = STATE_IDLE;
                    end
                end
            end
            STATE_AN: begin
                if (AN_EN) begin
                    // send config register
                    if (!odd_reg) begin
                        encoded_tx_data_next = tx_an_cfg[7:0];
                        encoded_tx_data_k_next = 1'b0;
                        state_next = STATE_AN;
                    end else begin
                        encoded_tx_data_next = tx_an_cfg[15:8];
                        encoded_tx_data_k_next = 1'b0;
                        tx_an_cfg_ready_next = 1'b1;
                        an_phase_next = !an_phase_reg;
                        state_next = STATE_IDLE;
                    end
                end
            end
            default: begin
                // invalid state, return to idle
                state_next = STATE_IDLE;
            end
        endcase

        // update running disparity
        rd_next = rd_reg;
        for (integer k = 0; k < CTRL_W; k = k + 1) begin
            rd_next = rd_next ^ rd_flip_8b10b(encoded_tx_data_next[k*8 +: 8], encoded_tx_data_k_next[k]);
        end
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    frame_reg <= frame_next;
    frame_error_reg <= frame_error_next;
    frame_min_count_reg <= frame_min_count_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_reg <= frame_len_lim_next;
    fcs_ptr_reg <= fcs_ptr_next;
    pre_cnt_reg <= pre_cnt_next;
    ifg_cnt_reg <= ifg_cnt_next;
    deficit_idle_cnt_reg <= deficit_idle_cnt_next;
    odd_reg <= odd_next;
    an_phase_reg <= an_phase_next;
    rd_reg <= rd_next;

    s_tdata_reg <= s_tdata_next;

    s_axis_tx_tready_reg <= s_axis_tx_tready_next;

    m_axis_tx_cpl_ts_reg <= m_axis_tx_cpl_ts_next;
    m_axis_tx_cpl_tag_reg <= m_axis_tx_cpl_tag_next;
    m_axis_tx_cpl_valid_reg <= m_axis_tx_cpl_valid_next;

    tx_an_cfg_ready_reg <= tx_an_cfg_ready_next;

    start_packet_int_reg <= start_packet_int_next;
    start_packet_reg <= start_packet_next;
    stat_tx_byte_reg <= stat_tx_byte_next;
    stat_tx_pkt_len_reg <= stat_tx_pkt_len_next;
    stat_tx_pkt_ucast_reg <= stat_tx_pkt_ucast_next;
    stat_tx_pkt_mcast_reg <= stat_tx_pkt_mcast_next;
    stat_tx_pkt_bcast_reg <= stat_tx_pkt_bcast_next;
    stat_tx_pkt_vlan_reg <= stat_tx_pkt_vlan_next;
    stat_tx_pkt_good_reg <= stat_tx_pkt_good_next;
    stat_tx_pkt_bad_reg <= stat_tx_pkt_bad_next;
    stat_tx_err_oversize_reg <= stat_tx_err_oversize_next;
    stat_tx_err_user_reg <= stat_tx_err_user_next;
    stat_tx_err_underflow_reg <= stat_tx_err_underflow_next;

    if (GBX_IF_EN && tx_gbx_req_stall) begin
        // gearbox stall
        encoded_tx_data_valid_reg <= 1'b0;
    end else begin
        encoded_tx_data_reg <= encoded_tx_data_next;
        encoded_tx_data_k_reg <= encoded_tx_data_k_next;
        encoded_tx_data_dm_reg <= encoded_tx_data_dm_next;
        encoded_tx_data_dv_reg <= encoded_tx_data_dv_next;
        encoded_tx_data_valid_reg <= 1'b1;

        if (reset_crc) begin
            crc_state_reg <= '1;
        end else if (update_crc) begin
            crc_state_reg <= crc_state;
        end
    end

    tx_gbx_sync_reg <= tx_gbx_req_sync;

    if (rst) begin
        state_reg <= STATE_IDLE;

        frame_reg <= 1'b0;
        odd_reg <= 1'b0;
        an_phase_reg <= 1'b0;
        rd_reg <= 1'b0;

        s_axis_tx_tready_reg <= 1'b0;

        m_axis_tx_cpl_valid_reg <= 1'b0;

        tx_an_cfg_ready_reg <= 1'b0;

        encoded_tx_data_valid_reg <= 1'b0;
        encoded_tx_data_k_reg <= 1'b0;
        encoded_tx_data_dm_reg <= 1'b0;
        encoded_tx_data_dv_reg <= 1'b0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= 1'b0;
        stat_tx_byte_reg <= 1'b0;
        stat_tx_pkt_len_reg <= '0;
        stat_tx_pkt_ucast_reg <= 1'b0;
        stat_tx_pkt_mcast_reg <= 1'b0;
        stat_tx_pkt_bcast_reg <= 1'b0;
        stat_tx_pkt_vlan_reg <= 1'b0;
        stat_tx_pkt_good_reg <= 1'b0;
        stat_tx_pkt_bad_reg <= 1'b0;
        stat_tx_err_oversize_reg <= 1'b0;
        stat_tx_err_user_reg <= 1'b0;
        stat_tx_err_underflow_reg <= 1'b0;
    end
end

endmodule

`resetall
