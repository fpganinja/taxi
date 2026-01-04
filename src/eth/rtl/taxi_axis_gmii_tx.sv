// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2015-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream GMII frame transmitter (AXI in, GMII out)
 */
module taxi_axis_gmii_tx #
(
    parameter DATA_W = 8,
    parameter logic PADDING_EN = 1'b1,
    parameter MIN_FRAME_LEN = 64,
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
     * GMII output
     */
    output wire logic [DATA_W-1:0]    gmii_txd,
    output wire logic                 gmii_tx_en,
    output wire logic                 gmii_tx_er,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Control
     */
    input  wire logic                 clk_enable,
    input  wire logic                 mii_select,

    /*
     * Configuration
     */
    input  wire logic [15:0]          cfg_tx_max_pkt_len = 16'd1518,
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

localparam [7:0]
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5;

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_PREAMBLE = 3'd1,
    STATE_PAYLOAD = 3'd2,
    STATE_LAST = 3'd3,
    STATE_PAD = 3'd4,
    STATE_FCS = 3'd5,
    STATE_IFG = 3'd6;

logic [2:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic [7:0] s_tdata_reg = 8'd0, s_tdata_next;

logic mii_odd_reg = 1'b0, mii_odd_next;
logic [3:0] mii_msn_reg = 4'b0, mii_msn_next;

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

logic [7:0] gmii_txd_reg = 8'd0, gmii_txd_next;
logic gmii_tx_en_reg = 1'b0, gmii_tx_en_next;
logic gmii_tx_er_reg = 1'b0, gmii_tx_er_next;

logic s_axis_tx_tready_reg = 1'b0, s_axis_tx_tready_next;

logic [PTP_TS_W-1:0] m_axis_tx_cpl_ts_reg = '0, m_axis_tx_cpl_ts_next;
logic [TX_TAG_W-1:0] m_axis_tx_cpl_tag_reg = '0, m_axis_tx_cpl_tag_next;
logic m_axis_tx_cpl_valid_reg = 1'b0, m_axis_tx_cpl_valid_next;

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

assign s_axis_tx.tready = s_axis_tx_tready_reg;

assign gmii_txd = gmii_txd_reg;
assign gmii_tx_en = gmii_tx_en_reg;
assign gmii_tx_er = gmii_tx_er_reg;

assign m_axis_tx_cpl.tdata = PTP_TS_EN ? m_axis_tx_cpl_ts_reg : '0;
assign m_axis_tx_cpl.tkeep = 1'b1;
assign m_axis_tx_cpl.tstrb = m_axis_tx_cpl.tkeep;
assign m_axis_tx_cpl.tvalid = m_axis_tx_cpl_valid_reg;
assign m_axis_tx_cpl.tlast = 1'b1;
assign m_axis_tx_cpl.tid = m_axis_tx_cpl_tag_reg;
assign m_axis_tx_cpl.tdest = '0;
assign m_axis_tx_cpl.tuser = '0;

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

    mii_odd_next = mii_odd_reg;
    mii_msn_next = mii_msn_reg;

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

    s_axis_tx_tready_next = 1'b0;

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

    gmii_txd_next = '0;
    gmii_tx_en_next = 1'b0;
    gmii_tx_er_next = 1'b0;

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

    if (!clk_enable) begin
        // clock disabled - hold state and outputs
        gmii_txd_next = gmii_txd_reg;
        gmii_tx_en_next = gmii_tx_en_reg;
        gmii_tx_er_next = gmii_tx_er_reg;
        state_next = state_reg;
    end else if (mii_select && mii_odd_reg) begin
        // MII odd cycle - hold state, output MSN
        mii_odd_next = 1'b0;
        gmii_txd_next = {4'd0, mii_msn_reg};
        gmii_tx_en_next = gmii_tx_en_reg;
        gmii_tx_er_next = gmii_tx_er_reg;
        state_next = state_reg;
        if (start_packet_int_reg) begin
            start_packet_int_next = 1'b0;
            start_packet_next = 1'b1;
        end
    end else begin
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

                mii_odd_next = 1'b0;
                hdr_ptr_next = 0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_tx_max_pkt_len;
                pre_cnt_next = 3'd6;

                frame_error_next = 1'b0;
                frame_min_count_next = MIN_LEN_W'(MIN_FRAME_LEN-4-1);

                gmii_txd_next = '0;
                gmii_tx_en_next = 1'b0;

                m_axis_tx_cpl_tag_next = s_axis_tx.tid;

                if (s_axis_tx.tvalid && cfg_tx_enable) begin
                    mii_odd_next = 1'b1;
                    gmii_txd_next = ETH_PRE;
                    gmii_tx_en_next = 1'b1;
                    state_next = STATE_PREAMBLE;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_PREAMBLE: begin
                // send preamble
                reset_crc = 1'b1;

                mii_odd_next = 1'b1;
                hdr_ptr_next = 0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_tx_max_pkt_len;

                frame_error_next = 1'b0;
                frame_min_count_next = MIN_LEN_W'(MIN_FRAME_LEN-4-1);

                gmii_txd_next = ETH_PRE;
                gmii_tx_en_next = 1'b1;

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
                    gmii_txd_next = ETH_SFD;
                    if (mii_select) begin
                        start_packet_int_next = 1'b1;
                    end else begin
                        start_packet_next = 1'b1;
                    end
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_PREAMBLE;
                end
            end
            STATE_PAYLOAD: begin
                // send payload

                update_crc = 1'b1;
                s_axis_tx_tready_next = 1'b1;

                mii_odd_next = 1'b1;

                gmii_txd_next = s_tdata_reg;
                gmii_tx_en_next = 1'b1;

                s_tdata_next = s_axis_tx.tdata;

                stat_tx_byte_next = 1'b1;

                if (!s_axis_tx.tvalid || s_axis_tx.tlast || frame_len_lim_reg < 6) begin
                    s_axis_tx_tready_next = frame_next; // drop frame
                    frame_error_next = !s_axis_tx.tvalid || s_axis_tx.tuser[0] || frame_len_lim_reg < 6;
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

                mii_odd_next = 1'b1;
                fcs_ptr_next = 2'd0;

                gmii_txd_next = s_tdata_reg;
                gmii_tx_en_next = 1'b1;
                gmii_tx_er_next = frame_error_reg;

                stat_tx_byte_next = 1'b1;

                if (PADDING_EN && frame_min_count_reg != 0) begin
                    s_tdata_next = 8'd0;
                    state_next = STATE_PAD;
                end else begin
                    state_next = STATE_FCS;
                end
            end
            STATE_PAD: begin
                // send padding
                s_axis_tx_tready_next = frame_next; // drop frame

                update_crc = 1'b1;
                mii_odd_next = 1'b1;
                fcs_ptr_next = 2'd0;

                gmii_txd_next = s_tdata_reg;
                gmii_tx_en_next = 1'b1;
                gmii_tx_er_next = frame_error_reg;

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

                mii_odd_next = 1'b1;
                ifg_cnt_next = cfg_tx_ifg;

                case (fcs_ptr_reg)
                    2'd0: gmii_txd_next = ~crc_state_reg[7:0];
                    2'd1: gmii_txd_next = ~crc_state_reg[15:8];
                    2'd2: gmii_txd_next = ~crc_state_reg[23:16];
                    2'd3: gmii_txd_next = ~crc_state_reg[31:24];
                endcase
                gmii_tx_en_next = 1'b1;
                gmii_tx_er_next = frame_error_reg;

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
                    stat_tx_err_oversize_next = frame_len_lim_reg == 0;
                    state_next = STATE_IFG;
                end
            end
            STATE_IFG: begin
                // send IFG
                s_axis_tx_tready_next = frame_next; // drop frame

                mii_odd_next = 1'b1;

                if (ifg_cnt_reg[7:1] != 0 || frame_reg) begin
                    state_next = STATE_IFG;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            default: begin
                // invalid state, return to idle
                state_next = STATE_IDLE;
            end
        endcase

        if (mii_select) begin
            mii_msn_next = gmii_txd_next[7:4];
            gmii_txd_next[7:4] = 4'd0;
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

    m_axis_tx_cpl_ts_reg <= m_axis_tx_cpl_ts_next;
    m_axis_tx_cpl_tag_reg <= m_axis_tx_cpl_tag_next;
    m_axis_tx_cpl_valid_reg <= m_axis_tx_cpl_valid_next;

    mii_odd_reg <= mii_odd_next;
    mii_msn_reg <= mii_msn_next;

    s_tdata_reg <= s_tdata_next;

    s_axis_tx_tready_reg <= s_axis_tx_tready_next;

    gmii_txd_reg <= gmii_txd_next;
    gmii_tx_en_reg <= gmii_tx_en_next;
    gmii_tx_er_reg <= gmii_tx_er_next;

    if (reset_crc) begin
        crc_state_reg <= '1;
    end else if (update_crc) begin
        crc_state_reg <= crc_state;
    end

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

    if (rst) begin
        state_reg <= STATE_IDLE;

        frame_reg <= 1'b0;

        s_axis_tx_tready_reg <= 1'b0;

        m_axis_tx_cpl_valid_reg <= 1'b0;

        gmii_tx_en_reg <= 1'b0;
        gmii_tx_er_reg <= 1'b0;

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
