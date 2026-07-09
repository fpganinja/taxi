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
module taxi_axis_basex_tx_16 #
(
    parameter DATA_W = 16,
    parameter CTRL_W = (DATA_W/8),
    parameter logic GBX_IF_EN = 1'b0,
    parameter GBX_CNT = 1,
    parameter logic SGMII_EN = 1'b1,
    parameter logic AN_EN = SGMII_EN,
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
    input  wire logic                 cfg_tx_enable = 1'b1,
    input  wire logic                 cfg_tx_sgmii_en = 1'b1,
    input  wire logic [1:0]           cfg_tx_sgmii_speed = 2'b10,

    /*
     * Status
     */
    output wire logic [1:0]           tx_start_packet,
    output wire logic [1:0]           stat_tx_byte,
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

// extract parameters
localparam KEEP_W = DATA_W/8;
localparam USER_W = TX_CPL_CTRL_IN_TUSER ? 2 : 1;
localparam TX_TAG_W = s_axis_tx.ID_W;

localparam EMPTY_W = $clog2(KEEP_W);

// check configuration
if (DATA_W != 16)
    $fatal(0, "Error: Interface width must be 16 (instance %m)");

if (KEEP_W*8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (CTRL_W != 2)
    $fatal(0, "Error: CTRL_W must be 2 (instance %m)");

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

typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PAYLOAD,
    STATE_FCS_1,
    STATE_FCS_2,
    STATE_FCS_3,
    STATE_IFG
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic [DATA_W-1:0] s_tdata_reg = '0, s_tdata_next;
logic [EMPTY_W-1:0] s_empty_reg = '0, s_empty_next;

logic frame_reg = 1'b0, frame_next;
logic frame_error_reg = 1'b0, frame_error_next;
logic frame_oversize_reg = 1'b0, frame_oversize_next;
logic [2:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [14:0] frame_len_lim_cyc_reg = '0, frame_len_lim_cyc_next;
logic frame_len_lim_last_reg = '0, frame_len_lim_last_next;
logic frame_len_lim_check_reg = '0, frame_len_lim_check_next;
logic [1:0] pre_cnt_reg = '0, pre_cnt_next;
logic [7:0] ifg_cnt_reg = '0, ifg_cnt_next;
logic deficit_idle_cnt_reg = 1'd0, deficit_idle_cnt_next;
logic gmii_frame_reg = 1'b0, gmii_frame_next;
logic cext_reg = 1'b0, cext_next;
logic an_cfg_reg = 1'b0, an_cfg_next;
logic an_phase_reg = 1'b0, an_phase_next;
logic rd_reg = 1'b0, rd_next;

logic [5:0] rep_cnt_reg = '0;
logic rep_stall_reg = 1'b0;
logic rep_en_reg = 1'b0;
logic rep_sel_reg = 1'b0;

logic [DATA_W-1:0] gmii_txd_reg = '0, gmii_txd_next, gmii_txd_rep;
logic [CTRL_W-1:0] gmii_tx_en_reg = '0, gmii_tx_en_next, gmii_tx_en_rep;
logic [CTRL_W-1:0] gmii_tx_er_reg = '0, gmii_tx_er_next, gmii_tx_er_rep;

logic s_axis_tx_tready_reg = 1'b0, s_axis_tx_tready_next;

logic tx_an_cfg_ready_reg = 1'b0, tx_an_cfg_ready_next;

logic [PTP_TS_W-1:0] m_axis_tx_cpl_ts_reg = '0, m_axis_tx_cpl_ts_next;
logic [TX_TAG_W-1:0] m_axis_tx_cpl_tag_reg = '0, m_axis_tx_cpl_tag_next;
logic m_axis_tx_cpl_valid_reg = 1'b0, m_axis_tx_cpl_valid_next;

logic [DATA_W-1:0] encoded_tx_data_reg = '0, encoded_tx_data_next;
logic [CTRL_W-1:0] encoded_tx_data_k_reg = '0, encoded_tx_data_k_next;
logic [CTRL_W-1:0] encoded_tx_data_dm_reg = '0, encoded_tx_data_dm_next;
logic [CTRL_W-1:0] encoded_tx_data_dv_reg = '0, encoded_tx_data_dv_next;
logic encoded_tx_data_valid_reg = 1'b0;
logic [GBX_CNT-1:0] tx_gbx_sync_reg = '0;

logic start_packet_int_reg = 1'b0, start_packet_int_next;
logic start_packet_reg = 1'b0, start_packet_next;

logic [1:0] stat_tx_byte_reg = '0, stat_tx_byte_next;
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

assign s_axis_tx.tready = s_axis_tx_tready_reg && (!GBX_IF_EN || !tx_gbx_req_stall) && (!SGMII_EN || !rep_stall_reg);

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

assign tx_start_packet = {1'b0, start_packet_reg};

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

logic [DATA_W+24-1:0] crc_data_reg = '0, crc_data_next;
logic [31:0] crc_state_reg = '0;
wire [31:0] crc_state;

taxi_lfsr #(
    .LFSR_W(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_GALOIS(1),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_W(DATA_W+24),
    .DATA_IN_EN(1'b1),
    .DATA_OUT_EN(1'b0),
    .STATE_SHIFT_PRE(0),
    .STATE_SHIFT_POST(-24)
)
eth_crc (
    .data_in(crc_data_reg),
    .state_in('0),
    .data_out(),
    .state_out(crc_state)
);

function [0:0] keep2empty(input [1:0] k);
    casez (k)
        2'bz0: keep2empty = 1'd1;
        2'b01: keep2empty = 1'd1;
        2'b11: keep2empty = 1'd0;
    endcase
endfunction

// FCS cycle calculation
logic [DATA_W-1:0] fcs_output_data_0;
logic [DATA_W-1:0] fcs_output_data_1;
logic [DATA_W-1:0] fcs_output_data_2;
logic [CTRL_W-1:0] fcs_output_valid_0;
logic [CTRL_W-1:0] fcs_output_valid_1;
logic [CTRL_W-1:0] fcs_output_valid_2;
logic [7:0] ifg_offset;

always_comb begin
    casez (s_empty_reg)
        1'd1: begin
            fcs_output_data_0 = {~crc_state[7:0], s_tdata_reg[7:0]};
            fcs_output_data_1 = ~crc_state_reg[23:8];
            fcs_output_data_2 = {8'd0, ~crc_state_reg[31:24]};
            fcs_output_valid_0 = 2'b11;
            fcs_output_valid_1 = 2'b11;
            fcs_output_valid_2 = 2'b01;
            ifg_offset = 8'd1;
        end
        1'd0: begin
            fcs_output_data_0 = s_tdata_reg;
            fcs_output_data_1 = ~crc_state_reg[15:0];
            fcs_output_data_2 = ~crc_state_reg[31:16];
            fcs_output_valid_0 = 2'b11;
            fcs_output_valid_1 = 2'b11;
            fcs_output_valid_2 = 2'b11;
            ifg_offset = 8'd0;
        end
    endcase
end

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_next = frame_reg;
    frame_error_next = frame_error_reg;
    frame_oversize_next = frame_oversize_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_cyc_next = frame_len_lim_cyc_reg;
    frame_len_lim_last_next = frame_len_lim_last_reg;
    frame_len_lim_check_next = frame_len_lim_check_reg;
    pre_cnt_next = pre_cnt_reg;
    ifg_cnt_next = ifg_cnt_reg;
    deficit_idle_cnt_next = deficit_idle_cnt_reg;
    gmii_frame_next = gmii_frame_reg;
    cext_next = cext_reg;
    an_cfg_next = an_cfg_reg;
    an_phase_next = an_phase_reg;
    rd_next = rd_reg;

    s_axis_tx_tready_next = 1'b0;

    m_axis_tx_cpl_ts_next = m_axis_tx_cpl_ts_reg;
    m_axis_tx_cpl_tag_next = m_axis_tx_cpl_tag_reg;
    m_axis_tx_cpl_valid_next = 1'b0;

    tx_an_cfg_ready_next = 1'b0;

    s_tdata_next = s_tdata_reg;
    s_empty_next = s_empty_reg;

    crc_data_next = crc_data_reg;

    if (start_packet_reg) begin
        if (PTP_TS_EN) begin
            m_axis_tx_cpl_ts_next = ptp_ts;
        end
        if (TX_CPL_CTRL_IN_TUSER) begin
            m_axis_tx_cpl_valid_next = (s_axis_tx.tuser >> 1) == 0;
        end else begin
            m_axis_tx_cpl_valid_next = 1'b1;
        end
    end

    gmii_txd_next = gmii_txd_reg;
    gmii_tx_en_next = gmii_tx_en_reg;
    gmii_tx_er_next = gmii_tx_er_reg;

    encoded_tx_data_next = '0;
    encoded_tx_data_k_next = '0;
    encoded_tx_data_dm_next = '0;
    encoded_tx_data_dv_next = '0;

    start_packet_int_next = start_packet_int_reg;
    start_packet_next = 1'b0;

    stat_tx_byte_next = '0;
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

        gmii_txd_next = gmii_txd_reg;
        gmii_tx_en_next = gmii_tx_en_reg;
        gmii_tx_er_next = gmii_tx_er_reg;
    end else if (SGMII_EN && rep_stall_reg) begin
        // SGMII stall - replicate GMII symbol
        state_next = state_reg;
        s_axis_tx_tready_next = s_axis_tx_tready_reg;

        gmii_txd_next = gmii_txd_reg;
        gmii_tx_en_next = gmii_tx_en_reg;
        gmii_tx_er_next = gmii_tx_er_reg;
    end else begin
        // counter to measure frame length
        if (&frame_len_reg[15:1] == 0) begin
            frame_len_next = frame_len_reg + 16'(KEEP_W);
        end else begin
            frame_len_next = '1;
        end

        // counter for max frame length enforcement
        if (frame_len_lim_cyc_reg != 0) begin
            frame_len_lim_cyc_next = frame_len_lim_cyc_reg - 1;
        end else begin
            frame_len_lim_cyc_next = '0;
        end

        if (frame_len_lim_cyc_reg == 4) begin
            frame_len_lim_check_next = 1'b1;
        end

        // address and ethertype checks
        if (&hdr_ptr_reg == 0) begin
            hdr_ptr_next = hdr_ptr_reg + 1;
        end

        case (hdr_ptr_reg)
            3'd0: begin
                is_mcast_next = s_tdata_reg[0];
                is_bcast_next = &s_tdata_reg;
            end
            3'd1: is_bcast_next = is_bcast_reg && &s_tdata_reg;
            3'd2: is_bcast_next = is_bcast_reg && &s_tdata_reg;
            3'd6: is_8021q_next = {s_tdata_reg[7:0], s_tdata_reg[15:8]} == 16'h8100;
            default: begin
                // do nothing
            end
        endcase

        if (pre_cnt_reg != 0) begin
            pre_cnt_next = pre_cnt_reg - 1;
        end

        if (ifg_cnt_reg[7:1] != 0) begin
            ifg_cnt_next = ifg_cnt_reg - 8'(KEEP_W);
        end else begin
            ifg_cnt_next = '0;
        end

        // FCS
        casez (s_axis_tx.tkeep)
            2'b11:   crc_data_next = {24'd0, s_axis_tx.tdata}            ^ {8'd0, crc_state};
            default: crc_data_next = {24'd0, s_axis_tx.tdata[7:0], 8'd0} ^ {crc_state, 8'd0};
        endcase

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for data
                reset_crc = 1'b1;

                frame_error_next = 1'b0;
                frame_oversize_next = 1'b0;
                hdr_ptr_next = 0;
                frame_len_next = 0;
                {frame_len_lim_cyc_next, frame_len_lim_last_next} = cfg_tx_max_pkt_len;
                frame_len_lim_check_next = 1'b0;
                pre_cnt_next = 2'd2;

                gmii_txd_next = {CTRL_W{ETH_PRE}};
                gmii_tx_en_next = 2'b00;
                gmii_tx_er_next = 2'b00;

                s_tdata_next = s_axis_tx.tdata;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                m_axis_tx_cpl_tag_next = s_axis_tx.tid;

                if (s_axis_tx.tvalid && cfg_tx_enable) begin
                    // Preamble and SFD
                    gmii_txd_next = {CTRL_W{ETH_PRE}};
                    gmii_tx_en_next = 2'b11;
                    gmii_tx_er_next = 2'b00;
                    state_next = STATE_PREAMBLE;
                end else begin
                    ifg_cnt_next = 8'd0;
                    deficit_idle_cnt_next = 1'd0;
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // send preamble
                reset_crc = 1'b1;

                hdr_ptr_next = 0;
                frame_len_next = 0;
                {frame_len_lim_cyc_next, frame_len_lim_last_next} = cfg_tx_max_pkt_len;
                frame_len_lim_check_next = 1'b0;

                s_tdata_next = s_axis_tx.tdata;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                crc_data_next = {24'd0, s_axis_tx.tdata} ^ {8'd0, 32'hffffffff};

                gmii_txd_next = {CTRL_W{ETH_PRE}};
                gmii_tx_en_next = 2'b11;
                gmii_tx_er_next = 2'b00;

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
                    gmii_txd_next = {ETH_SFD, {1{ETH_PRE}}};
                    gmii_tx_en_next = 2'b11;
                    start_packet_int_next = 1'b1;
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_PREAMBLE;
                end
            end
            STATE_PAYLOAD: begin
                // transfer payload

                update_crc = 1'b1;
                s_axis_tx_tready_next = 1'b1;

                gmii_txd_next = s_tdata_reg;
                gmii_tx_en_next = 2'b11;
                gmii_tx_er_next = 2'b00;

                s_tdata_next = s_axis_tx.tdata;
                s_empty_next = keep2empty(s_axis_tx.tkeep);

                stat_tx_byte_next = 2'(KEEP_W);

                start_packet_next = start_packet_int_reg;
                start_packet_int_next = 1'b0;

                if (s_axis_tx.tvalid && s_axis_tx.tlast) begin
                    if (frame_len_lim_check_reg) begin
                        if (frame_len_lim_last_reg < 1'(1-keep2empty(s_axis_tx.tkeep))) begin
                            frame_oversize_next = 1'b1;
                        end
                    end
                end else begin
                    if (frame_len_lim_check_reg) begin
                        // at the limit but the frame doesn't end in this cycle
                        frame_oversize_next = 1'b1;
                    end
                end

                if (!s_axis_tx.tvalid || s_axis_tx.tlast || frame_oversize_next) begin
                    s_axis_tx_tready_next = frame_next; // drop frame
                    frame_error_next = !s_axis_tx.tvalid || s_axis_tx.tuser[0] || frame_oversize_next;
                    stat_tx_err_user_next = s_axis_tx.tuser[0];
                    stat_tx_err_underflow_next = !s_axis_tx.tvalid;

                    state_next = STATE_FCS_1;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            STATE_FCS_1: begin
                // FCS

                update_crc = 1'b1;
                s_axis_tx_tready_next = frame_next; // drop frame

                gmii_txd_next = fcs_output_data_0;
                gmii_tx_en_next = fcs_output_valid_0;
                gmii_tx_er_next = {CTRL_W{frame_error_reg}};

                stat_tx_byte_next = 2'(KEEP_W);

                state_next = STATE_FCS_2;
            end
            STATE_FCS_2: begin
                // FCS
                s_axis_tx_tready_next = frame_next; // drop frame

                gmii_txd_next = fcs_output_data_1;
                gmii_tx_en_next = fcs_output_valid_1;
                gmii_tx_er_next = {CTRL_W{frame_error_reg}};

                stat_tx_byte_next = 2'(KEEP_W);

                state_next = STATE_FCS_3;
            end
            STATE_FCS_3: begin
                // FCS
                s_axis_tx_tready_next = frame_next; // drop frame

                gmii_txd_next = fcs_output_data_2;
                gmii_tx_en_next = fcs_output_valid_2;
                gmii_tx_er_next = {CTRL_W{frame_error_reg}};

                stat_tx_byte_next = 2-s_empty_reg;
                frame_len_next = frame_len_reg + 16'(2-s_empty_reg);

                ifg_cnt_next = (cfg_tx_ifg > 8'd2 ? cfg_tx_ifg : 8'd2) - ifg_offset + 8'(deficit_idle_cnt_reg);

                stat_tx_pkt_len_next = frame_len_next;
                stat_tx_pkt_good_next = !frame_error_reg;
                stat_tx_pkt_bad_next = frame_error_reg;
                stat_tx_pkt_ucast_next = !is_mcast_reg;
                stat_tx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                stat_tx_pkt_bcast_next = is_bcast_reg;
                stat_tx_pkt_vlan_next = is_8021q_reg;
                stat_tx_err_oversize_next = frame_oversize_reg;
                state_next = STATE_IFG;
            end
            STATE_IFG: begin
                // send IFG
                s_axis_tx_tready_next = frame_next; // drop frame

                gmii_txd_next = '0;
                gmii_tx_en_next = 2'b00;
                gmii_tx_er_next = 2'b00;

                if (DIC_EN) begin
                    if (ifg_cnt_next > 8'd1 || frame_reg) begin
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
            default: begin
                // invalid state, return to idle
                state_next = STATE_IDLE;
            end
        endcase
    end

    if (rep_en_reg) begin
        if (rep_sel_reg) begin
            gmii_txd_rep = {2{gmii_txd_next[15:8]}};
            gmii_tx_en_rep = {2{gmii_tx_en_next[1]}};
            gmii_tx_er_rep = {2{gmii_tx_er_next[1]}};
        end else begin
            gmii_txd_rep = {2{gmii_txd_next[7:0]}};
            gmii_tx_en_rep = {2{gmii_tx_en_next[0]}};
            gmii_tx_er_rep = {2{gmii_tx_er_next[0]}};
        end
    end else begin
        gmii_txd_rep = gmii_txd_next;
        gmii_tx_en_rep = gmii_tx_en_next;
        gmii_tx_er_rep = gmii_tx_er_next;
    end

    if (GBX_IF_EN && tx_gbx_req_stall) begin
        // gearbox stall
    end else begin
        if (gmii_frame_reg) begin
            if ((gmii_tx_en_rep & gmii_tx_er_rep) != 0) begin
                // propagate error
                encoded_tx_data_next = {CTRL_W{CTRL_V}};
                encoded_tx_data_k_next = 2'b11;
            end else if (gmii_tx_en_rep == 2'b11) begin
                // data
                encoded_tx_data_next = gmii_txd_rep;
                encoded_tx_data_k_next = 2'b00;
            end else if (gmii_tx_en_rep == 2'b01) begin
                // end of frame (lane 1)
                gmii_frame_next = 1'b0;
                encoded_tx_data_next = {CTRL_T, gmii_txd_rep[7:0]};
                encoded_tx_data_k_next = 2'b10;
                cext_next = 1'b1;
            end else begin
                // end of frame (lane 0)
                gmii_frame_next = 1'b0;
                encoded_tx_data_next = {CTRL_R, CTRL_T};
                encoded_tx_data_k_next = 2'b11;
            end
        end else if (AN_EN && an_cfg_reg) begin
            // config reg
            encoded_tx_data_next = tx_an_cfg;
            encoded_tx_data_k_next = 2'b00;
            tx_an_cfg_ready_next = 1'b1;
            an_phase_next = !an_phase_reg;
            an_cfg_next = 1'b0;
        end else begin
            if (gmii_tx_en_rep != 0) begin
                // start of frame
                gmii_frame_next = 1'b1;
                encoded_tx_data_next = {gmii_txd_rep[15:8], CTRL_S};
                encoded_tx_data_k_next = 2'b01;
            end else if (AN_EN && tx_an_cfg_valid) begin
                // config reg
                an_cfg_next = 1'b1;
                encoded_tx_data_next = an_phase_reg ? CTRL_C2 : CTRL_C1;
                encoded_tx_data_k_next = 2'b01;
            end else begin
                if (cext_reg) begin
                    // carrier extend
                    encoded_tx_data_next = {CTRL_W{CTRL_R}};
                    encoded_tx_data_k_next = 2'b11;
                    cext_next = 1'b0;
                end else begin
                    // idle
                    encoded_tx_data_next = rd_reg ? CTRL_I1 : CTRL_I2;
                    encoded_tx_data_k_next = 2'b01;
                    encoded_tx_data_dm_next = 2'b01;
                    encoded_tx_data_dv_next = {1'b0, rd_reg};
                end
            end
        end

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
    frame_oversize_reg <= frame_oversize_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_cyc_reg <= frame_len_lim_cyc_next;
    frame_len_lim_last_reg <= frame_len_lim_last_next;
    frame_len_lim_check_reg <= frame_len_lim_check_next;
    pre_cnt_reg <= pre_cnt_next;
    ifg_cnt_reg <= ifg_cnt_next;
    deficit_idle_cnt_reg <= deficit_idle_cnt_next;
    gmii_frame_reg <= gmii_frame_next;
    cext_reg <= cext_next;
    an_cfg_reg <= an_cfg_next;
    an_phase_reg <= an_phase_next;
    rd_reg <= rd_next;

    s_tdata_reg <= s_tdata_next;
    s_empty_reg <= s_empty_next;

    crc_data_reg <= crc_data_next;

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
        gmii_txd_reg <= gmii_txd_next;
        gmii_tx_en_reg <= gmii_tx_en_next;
        gmii_tx_er_reg <= gmii_tx_er_next;

        encoded_tx_data_reg <= encoded_tx_data_next;
        encoded_tx_data_k_reg <= encoded_tx_data_k_next;
        encoded_tx_data_dm_reg <= encoded_tx_data_dm_next;
        encoded_tx_data_dv_reg <= encoded_tx_data_dv_next;
        encoded_tx_data_valid_reg <= 1'b1;

        encoded_tx_data_valid_reg <= 1'b1;

        if (reset_crc) begin
            crc_state_reg <= '1;
        end else if (update_crc) begin
            crc_state_reg <= crc_state;
        end

        if (SGMII_EN && cfg_tx_sgmii_en) begin
            if (rep_cnt_reg == 0) begin
                rep_stall_reg <= !rep_sel_reg;
                rep_en_reg <= 1'b1;
                rep_sel_reg <= !rep_sel_reg;
                case (cfg_tx_sgmii_speed)
                    2'b00: rep_cnt_reg <= 49; // 10 Mbps
                    2'b01: rep_cnt_reg <= 4; // 100 Mbps
                    default: begin
                        rep_cnt_reg <= 0; // 1 Gbps
                        rep_stall_reg <= 1'b0;
                        rep_en_reg <= 1'b0;
                        rep_sel_reg <= 1'b0;
                    end
                endcase
            end else begin
                rep_cnt_reg <= rep_cnt_reg-1;
                rep_stall_reg <= 1'b1;
                rep_en_reg <= 1'b1;
            end
        end else begin
            rep_cnt_reg <= '0;
            rep_stall_reg <= 1'b0;
            rep_en_reg <= 1'b0;
            rep_sel_reg <= 1'b0;
        end
    end

    tx_gbx_sync_reg <= tx_gbx_req_sync;

    if (rst) begin
        state_reg <= STATE_IDLE;

        frame_reg <= 1'b0;
        deficit_idle_cnt_reg <= 1'd0;
        gmii_frame_reg <= 1'b0;
        cext_reg <= 1'b0;
        an_cfg_reg <= 1'b0;
        an_phase_reg <= 1'b0;
        rd_reg <= 1'b0;

        rep_cnt_reg <= '0;
        rep_stall_reg <= 1'b0;
        rep_en_reg <= 1'b0;
        rep_sel_reg <= 1'b0;

        s_axis_tx_tready_reg <= 1'b0;

        m_axis_tx_cpl_valid_reg <= 1'b0;

        tx_an_cfg_ready_reg <= 1'b0;

        encoded_tx_data_reg <= '0;
        encoded_tx_data_k_reg <= '0;
        encoded_tx_data_dm_reg <= '0;
        encoded_tx_data_dv_reg <= '0;
        encoded_tx_data_valid_reg <= 1'b0;
        tx_gbx_sync_reg <= '0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= 1'b0;

        stat_tx_byte_reg <= '0;
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
