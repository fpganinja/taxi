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
 * AXI4-Stream GMII frame receiver (GMII in, AXI out)
 */
module taxi_axis_gmii_rx #
(
    parameter DATA_W = 8,
    parameter logic PTP_TS_EN = 1'b0,
    parameter PTP_TS_W = 96
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * GMII input
     */
    input  wire logic [DATA_W-1:0]    gmii_rxd,
    input  wire logic                 gmii_rx_dv,
    input  wire logic                 gmii_rx_er,

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx,

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
    input  wire logic [15:0]          cfg_rx_max_pkt_len = 16'd1518,
    input  wire logic                 cfg_rx_enable,

    /*
     * Status
     */
    output wire logic                 rx_start_packet,
    output wire logic                 stat_rx_byte,
    output wire logic [15:0]          stat_rx_pkt_len,
    output wire logic                 stat_rx_pkt_fragment,
    output wire logic                 stat_rx_pkt_jabber,
    output wire logic                 stat_rx_pkt_ucast,
    output wire logic                 stat_rx_pkt_mcast,
    output wire logic                 stat_rx_pkt_bcast,
    output wire logic                 stat_rx_pkt_vlan,
    output wire logic                 stat_rx_pkt_good,
    output wire logic                 stat_rx_pkt_bad,
    output wire logic                 stat_rx_err_oversize,
    output wire logic                 stat_rx_err_bad_fcs,
    output wire logic                 stat_rx_err_bad_block,
    output wire logic                 stat_rx_err_framing,
    output wire logic                 stat_rx_err_preamble
);

localparam USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

// check configuration
if (DATA_W != 8)
    $fatal(0, "Error: Interface width must be 8 (instance %m)");

if (m_axis_rx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axis_rx.USER_W != USER_W)
    $fatal(0, "Error: Interface USER_W parameter mismatch (instance %m)");

typedef enum logic [7:0] {
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5
} eth_pre_t;

typedef enum logic [1:0] {
    STATE_IDLE,
    STATE_PIPE,
    STATE_PAYLOAD
} state_t;

state_t state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;
logic update_crc;

logic mii_odd_reg = 1'b0;
logic in_frame_reg = 1'b0;

logic [DATA_W-1:0] gmii_rxd_d0_reg = '0;
logic [DATA_W-1:0] gmii_rxd_d1_reg = '0;
logic [DATA_W-1:0] gmii_rxd_d2_reg = '0;
logic [DATA_W-1:0] gmii_rxd_d3_reg = '0;
logic [DATA_W-1:0] gmii_rxd_d4_reg = '0;

logic gmii_rx_dv_d0_reg = 1'b0;
logic gmii_rx_dv_d1_reg = 1'b0;
logic gmii_rx_dv_d2_reg = 1'b0;
logic gmii_rx_dv_d3_reg = 1'b0;
logic gmii_rx_dv_d4_reg = 1'b0;

logic gmii_rx_er_d0_reg = 1'b0;
logic gmii_rx_er_d1_reg = 1'b0;
logic gmii_rx_er_d2_reg = 1'b0;
logic gmii_rx_er_d3_reg = 1'b0;
logic gmii_rx_er_d4_reg = 1'b0;

logic frame_error_reg = 1'b0, frame_error_next;
logic in_pre_reg = 1'b0, in_pre_next;
logic pre_ok_reg = 1'b0, pre_ok_next;
logic [3:0] hdr_ptr_reg = '0, hdr_ptr_next;
logic is_mcast_reg = 1'b0, is_mcast_next;
logic is_bcast_reg = 1'b0, is_bcast_next;
logic is_8021q_reg = 1'b0, is_8021q_next;
logic [15:0] frame_len_reg = '0, frame_len_next;
logic [15:0] frame_len_lim_reg = '0, frame_len_lim_next;

logic [DATA_W-1:0] m_axis_rx_tdata_reg = '0, m_axis_rx_tdata_next;
logic m_axis_rx_tvalid_reg = 1'b0, m_axis_rx_tvalid_next;
logic m_axis_rx_tlast_reg = 1'b0, m_axis_rx_tlast_next;
logic m_axis_rx_tuser_reg = 1'b0, m_axis_rx_tuser_next;

logic start_packet_int_reg = 1'b0;
logic start_packet_reg = 1'b0;

logic stat_rx_byte_reg = 1'b0, stat_rx_byte_next;
logic [15:0] stat_rx_pkt_len_reg = '0, stat_rx_pkt_len_next;
logic stat_rx_pkt_fragment_reg = 1'b0, stat_rx_pkt_fragment_next;
logic stat_rx_pkt_jabber_reg = 1'b0, stat_rx_pkt_jabber_next;
logic stat_rx_pkt_ucast_reg = 1'b0, stat_rx_pkt_ucast_next;
logic stat_rx_pkt_mcast_reg = 1'b0, stat_rx_pkt_mcast_next;
logic stat_rx_pkt_bcast_reg = 1'b0, stat_rx_pkt_bcast_next;
logic stat_rx_pkt_vlan_reg = 1'b0, stat_rx_pkt_vlan_next;
logic stat_rx_pkt_good_reg = 1'b0, stat_rx_pkt_good_next;
logic stat_rx_pkt_bad_reg = 1'b0, stat_rx_pkt_bad_next;
logic stat_rx_err_oversize_reg = 1'b0, stat_rx_err_oversize_next;
logic stat_rx_err_bad_fcs_reg = 1'b0, stat_rx_err_bad_fcs_next;
logic stat_rx_err_bad_block_reg = 1'b0, stat_rx_err_bad_block_next;
logic stat_rx_err_framing_reg = 1'b0, stat_rx_err_framing_next;
logic stat_rx_err_preamble_reg = 1'b0, stat_rx_err_preamble_next;

logic [PTP_TS_W-1:0] ptp_ts_out_reg = '0;

logic [31:0] crc_state_reg = '1;
wire [31:0] crc_state;

assign m_axis_rx.tdata = m_axis_rx_tdata_reg;
assign m_axis_rx.tkeep = 1'b1;
assign m_axis_rx.tstrb = m_axis_rx.tkeep;
assign m_axis_rx.tvalid = m_axis_rx_tvalid_reg;
assign m_axis_rx.tlast = m_axis_rx_tlast_reg;
assign m_axis_rx.tid = '0;
assign m_axis_rx.tdest = '0;
assign m_axis_rx.tuser[0] = m_axis_rx_tuser_reg;
if (PTP_TS_EN) begin
    assign m_axis_rx.tuser[1 +: PTP_TS_W] = ptp_ts_out_reg;
end

assign rx_start_packet = start_packet_reg;

assign stat_rx_byte = stat_rx_byte_reg;
assign stat_rx_pkt_len = stat_rx_pkt_len_reg;
assign stat_rx_pkt_fragment = stat_rx_pkt_fragment_reg;
assign stat_rx_pkt_jabber = stat_rx_pkt_jabber_reg;
assign stat_rx_pkt_ucast = stat_rx_pkt_ucast_reg;
assign stat_rx_pkt_mcast = stat_rx_pkt_mcast_reg;
assign stat_rx_pkt_bcast = stat_rx_pkt_bcast_reg;
assign stat_rx_pkt_vlan = stat_rx_pkt_vlan_reg;
assign stat_rx_pkt_good = stat_rx_pkt_good_reg;
assign stat_rx_pkt_bad = stat_rx_pkt_bad_reg;
assign stat_rx_err_oversize = stat_rx_err_oversize_reg;
assign stat_rx_err_bad_fcs = stat_rx_err_bad_fcs_reg;
assign stat_rx_err_bad_block = stat_rx_err_bad_block_reg;
assign stat_rx_err_framing = stat_rx_err_framing_reg;
assign stat_rx_err_preamble = stat_rx_err_preamble_reg;

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
    .data_in(gmii_rxd_d0_reg),
    .state_in(crc_state_reg),
    .data_out(),
    .state_out(crc_state)
);

wire crc_valid = crc_state == ~32'h2144df1c;

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;
    update_crc = 1'b0;

    frame_error_next = frame_error_reg;
    in_pre_next = in_pre_reg;
    pre_ok_next = pre_ok_reg;
    hdr_ptr_next = hdr_ptr_reg;
    is_mcast_next = is_mcast_reg;
    is_bcast_next = is_bcast_reg;
    is_8021q_next = is_8021q_reg;
    frame_len_next = frame_len_reg;
    frame_len_lim_next = frame_len_lim_reg;

    m_axis_rx_tdata_next = '0;
    m_axis_rx_tvalid_next = 1'b0;
    m_axis_rx_tlast_next = 1'b0;
    m_axis_rx_tuser_next = 1'b0;

    stat_rx_byte_next = 1'b0;
    stat_rx_pkt_len_next = '0;
    stat_rx_pkt_fragment_next = 1'b0;
    stat_rx_pkt_jabber_next = 1'b0;
    stat_rx_pkt_ucast_next = 1'b0;
    stat_rx_pkt_mcast_next = 1'b0;
    stat_rx_pkt_bcast_next = 1'b0;
    stat_rx_pkt_vlan_next = 1'b0;
    stat_rx_pkt_good_next = 1'b0;
    stat_rx_pkt_bad_next = 1'b0;
    stat_rx_err_oversize_next = 1'b0;
    stat_rx_err_bad_fcs_next = 1'b0;
    stat_rx_err_bad_block_next = 1'b0;
    stat_rx_err_framing_next = 1'b0;
    stat_rx_err_preamble_next = 1'b0;

    if (!clk_enable) begin
        // clock disabled - hold state
        state_next = state_reg;
    end else if (mii_select && !mii_odd_reg) begin
        // MII even cycle - hold state
        state_next = state_reg;
    end else begin

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
                is_mcast_next = gmii_rxd_d4_reg[0];
                is_bcast_next = gmii_rxd_d4_reg == 8'hff;
            end
            4'd1: is_bcast_next = is_bcast_reg && gmii_rxd_d4_reg == 8'hff;
            4'd2: is_bcast_next = is_bcast_reg && gmii_rxd_d4_reg == 8'hff;
            4'd3: is_bcast_next = is_bcast_reg && gmii_rxd_d4_reg == 8'hff;
            4'd4: is_bcast_next = is_bcast_reg && gmii_rxd_d4_reg == 8'hff;
            4'd5: is_bcast_next = is_bcast_reg && gmii_rxd_d4_reg == 8'hff;
            4'd12: is_8021q_next = gmii_rxd_d4_reg == 8'h81;
            4'd13: is_8021q_next = is_8021q_reg && gmii_rxd_d4_reg == 8'h00;
            default: begin
                // do nothing
            end
        endcase

        case (state_reg)
            STATE_IDLE: begin
                // idle state - wait for packet
                reset_crc = 1'b1;
                frame_error_next = 1'b0;
                frame_len_next = 1;
                frame_len_lim_next = cfg_rx_max_pkt_len;
                hdr_ptr_next = 0;
                is_mcast_next = 1'b0;
                is_bcast_next = 1'b0;
                is_8021q_next = 1'b0;

                state_next = STATE_IDLE;

                if (gmii_rx_dv_d0_reg) begin
                    if (gmii_rx_er_d0_reg) begin
                        // error in preamble
                        in_pre_next = 1'b0;
                        pre_ok_next = 1'b0;
                        stat_rx_err_framing_next = 1'b1;
                    end else if (gmii_rxd_d0_reg == ETH_PRE) begin
                        // normal preamble
                    end else if (gmii_rxd_d0_reg == ETH_SFD) begin
                        // start
                        in_pre_next = 1'b0;
                        if (in_pre_reg && cfg_rx_enable) begin
                            stat_rx_byte_next = 1'b1;
                            state_next = STATE_PIPE;
                        end
                    end else begin
                        // abnormal preamble
                        pre_ok_next = 1'b0;
                    end
                end else begin
                    // reset and wait for data
                    in_pre_next = 1'b1;
                    pre_ok_next = 1'b1;
                end
            end
            STATE_PIPE: begin
                // wait for FCS pipeline to fill
                update_crc = 1'b1;
                hdr_ptr_next = 0;
                is_mcast_next = 1'b0;
                is_bcast_next = 1'b0;
                is_8021q_next = 1'b0;

                stat_rx_byte_next = gmii_rx_dv;

                if (gmii_rx_dv && gmii_rx_er) begin
                    frame_error_next = 1'b1;
                    stat_rx_err_framing_next = 1'b1;
                end

                if (gmii_rx_dv_d4_reg && !gmii_rx_er_d4_reg && gmii_rxd_d4_reg == ETH_SFD) begin
                    state_next = STATE_PAYLOAD;
                end else begin
                    state_next = STATE_PIPE;
                end
            end
            STATE_PAYLOAD: begin
                // read payload
                update_crc = 1'b1;

                m_axis_rx_tdata_next = gmii_rxd_d4_reg;
                m_axis_rx_tvalid_next = 1'b1;

                stat_rx_byte_next = gmii_rx_dv;

                if (gmii_rx_dv && gmii_rx_er) begin
                    frame_error_next = 1'b1;
                    stat_rx_err_framing_next = 1'b1;
                end

                if (!gmii_rx_dv) begin
                    // end of packet
                    m_axis_rx_tlast_next = 1'b1;
                    stat_rx_pkt_len_next = frame_len_reg;
                    stat_rx_pkt_ucast_next = !is_mcast_reg;
                    stat_rx_pkt_mcast_next = is_mcast_reg && !is_bcast_reg;
                    stat_rx_pkt_bcast_next = is_bcast_reg;
                    stat_rx_pkt_vlan_next = is_8021q_reg;
                    stat_rx_err_oversize_next = frame_len_lim_reg == 0;
                    stat_rx_err_framing_next = !gmii_rx_dv_d0_reg;
                    stat_rx_err_preamble_next = !pre_ok_reg;
                    if (frame_error_next) begin
                        // error
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_pkt_fragment_next = frame_len_reg[15:6] == 0;
                        stat_rx_pkt_jabber_next = frame_len_lim_reg == 0;
                        stat_rx_pkt_bad_next = 1'b1;
                    end else if (crc_valid) begin
                        // FCS good
                        if (frame_len_lim_reg == 0) begin
                            // too long
                            m_axis_rx_tuser_next = 1'b1;
                            stat_rx_pkt_bad_next = 1'b1;
                        end else begin
                            // length OK
                            m_axis_rx_tuser_next = 1'b0;
                            stat_rx_pkt_good_next = 1'b1;
                        end
                    end else begin
                        // FCS bad
                        m_axis_rx_tuser_next = 1'b1;
                        stat_rx_pkt_fragment_next = frame_len_reg[15:6] == 0;
                        stat_rx_pkt_jabber_next = frame_len_lim_reg == 0;
                        stat_rx_pkt_bad_next = 1'b1;
                        stat_rx_err_bad_fcs_next = 1'b1;
                    end
                    reset_crc = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_PAYLOAD;
                end
            end
            default: begin
                // invalid state, return to idle
                state_next = STATE_IDLE;
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    frame_error_reg <= frame_error_next;
    in_pre_reg <= in_pre_next;
    pre_ok_reg <= pre_ok_next;
    hdr_ptr_reg <= hdr_ptr_next;
    is_mcast_reg <= is_mcast_next;
    is_bcast_reg <= is_bcast_next;
    is_8021q_reg <= is_8021q_next;
    frame_len_reg <= frame_len_next;
    frame_len_lim_reg <= frame_len_lim_next;

    m_axis_rx_tdata_reg <= m_axis_rx_tdata_next;
    m_axis_rx_tvalid_reg <= m_axis_rx_tvalid_next;
    m_axis_rx_tlast_reg <= m_axis_rx_tlast_next;
    m_axis_rx_tuser_reg <= m_axis_rx_tuser_next;

    start_packet_int_reg <= 1'b0;
    start_packet_reg <= 1'b0;

    if (start_packet_int_reg) begin
        ptp_ts_out_reg <= ptp_ts;
        start_packet_reg <= 1'b1;
    end

    if (clk_enable) begin
        if (mii_select) begin
            mii_odd_reg <= !mii_odd_reg || !gmii_rx_dv;

            if (in_frame_reg) begin
                in_frame_reg <= gmii_rx_dv;
            end else if (gmii_rx_dv && {gmii_rxd[3:0], gmii_rxd_d0_reg[7:4]} == ETH_SFD) begin
                in_frame_reg <= 1'b1;
                start_packet_int_reg <= 1'b1;
                mii_odd_reg <= 1'b1;
            end

            gmii_rxd_d0_reg <= {gmii_rxd[3:0], gmii_rxd_d0_reg[7:4]};

            if (mii_odd_reg) begin
                gmii_rxd_d1_reg <= gmii_rxd_d0_reg;
                gmii_rxd_d2_reg <= gmii_rxd_d1_reg;
                gmii_rxd_d3_reg <= gmii_rxd_d2_reg;
                gmii_rxd_d4_reg <= gmii_rxd_d3_reg;

                gmii_rx_dv_d0_reg <= gmii_rx_dv;
                gmii_rx_dv_d1_reg <= gmii_rx_dv_d0_reg;
                gmii_rx_dv_d2_reg <= gmii_rx_dv_d1_reg;
                gmii_rx_dv_d3_reg <= gmii_rx_dv_d2_reg;
                gmii_rx_dv_d4_reg <= gmii_rx_dv_d3_reg;

                gmii_rx_er_d0_reg <= gmii_rx_er;
                gmii_rx_er_d1_reg <= gmii_rx_er_d0_reg;
                gmii_rx_er_d2_reg <= gmii_rx_er_d1_reg;
                gmii_rx_er_d3_reg <= gmii_rx_er_d2_reg;
                gmii_rx_er_d4_reg <= gmii_rx_er_d3_reg;
            end else begin
                gmii_rx_dv_d0_reg <= gmii_rx_dv & gmii_rx_dv_d0_reg;
                gmii_rx_er_d0_reg <= gmii_rx_er | gmii_rx_er_d0_reg;
            end
        end else begin
            if (in_frame_reg) begin
                in_frame_reg <= gmii_rx_dv;
            end else if (gmii_rx_dv && gmii_rxd == ETH_SFD) begin
                in_frame_reg <= 1'b1;
                start_packet_int_reg <= 1'b1;
            end

            gmii_rxd_d0_reg <= gmii_rxd;
            gmii_rxd_d1_reg <= gmii_rxd_d0_reg;
            gmii_rxd_d2_reg <= gmii_rxd_d1_reg;
            gmii_rxd_d3_reg <= gmii_rxd_d2_reg;
            gmii_rxd_d4_reg <= gmii_rxd_d3_reg;

            gmii_rx_dv_d0_reg <= gmii_rx_dv;
            gmii_rx_dv_d1_reg <= gmii_rx_dv_d0_reg;
            gmii_rx_dv_d2_reg <= gmii_rx_dv_d1_reg;
            gmii_rx_dv_d3_reg <= gmii_rx_dv_d2_reg;
            gmii_rx_dv_d4_reg <= gmii_rx_dv_d3_reg;

            gmii_rx_er_d0_reg <= gmii_rx_er;
            gmii_rx_er_d1_reg <= gmii_rx_er_d0_reg;
            gmii_rx_er_d2_reg <= gmii_rx_er_d1_reg;
            gmii_rx_er_d3_reg <= gmii_rx_er_d2_reg;
            gmii_rx_er_d4_reg <= gmii_rx_er_d3_reg;
        end
    end

    if (reset_crc) begin
        crc_state_reg <= '1;
    end else if (update_crc) begin
        crc_state_reg <= crc_state;
    end

    stat_rx_byte_reg <= stat_rx_byte_next;
    stat_rx_pkt_len_reg <= stat_rx_pkt_len_next;
    stat_rx_pkt_fragment_reg <= stat_rx_pkt_fragment_next;
    stat_rx_pkt_jabber_reg <= stat_rx_pkt_jabber_next;
    stat_rx_pkt_ucast_reg <= stat_rx_pkt_ucast_next;
    stat_rx_pkt_mcast_reg <= stat_rx_pkt_mcast_next;
    stat_rx_pkt_bcast_reg <= stat_rx_pkt_bcast_next;
    stat_rx_pkt_vlan_reg <= stat_rx_pkt_vlan_next;
    stat_rx_pkt_good_reg <= stat_rx_pkt_good_next;
    stat_rx_pkt_bad_reg <= stat_rx_pkt_bad_next;
    stat_rx_err_oversize_reg <= stat_rx_err_oversize_next;
    stat_rx_err_bad_fcs_reg <= stat_rx_err_bad_fcs_next;
    stat_rx_err_bad_block_reg <= stat_rx_err_bad_block_next;
    stat_rx_err_framing_reg <= stat_rx_err_framing_next;
    stat_rx_err_preamble_reg <= stat_rx_err_preamble_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        m_axis_rx_tvalid_reg <= 1'b0;

        start_packet_int_reg <= 1'b0;
        start_packet_reg <= 1'b0;

        stat_rx_byte_reg <= 1'b0;
        stat_rx_pkt_len_reg <= '0;
        stat_rx_pkt_fragment_reg <= 1'b0;
        stat_rx_pkt_jabber_reg <= 1'b0;
        stat_rx_pkt_ucast_reg <= 1'b0;
        stat_rx_pkt_mcast_reg <= 1'b0;
        stat_rx_pkt_bcast_reg <= 1'b0;
        stat_rx_pkt_vlan_reg <= 1'b0;
        stat_rx_pkt_good_reg <= 1'b0;
        stat_rx_pkt_bad_reg <= 1'b0;
        stat_rx_err_oversize_reg <= 1'b0;
        stat_rx_err_bad_fcs_reg <= 1'b0;
        stat_rx_err_bad_block_reg <= 1'b0;
        stat_rx_err_framing_reg <= 1'b0;
        stat_rx_err_preamble_reg <= 1'b0;

        in_frame_reg <= 1'b0;
        mii_odd_reg <= 1'b0;

        gmii_rx_dv_d0_reg <= 1'b0;
        gmii_rx_dv_d1_reg <= 1'b0;
        gmii_rx_dv_d2_reg <= 1'b0;
        gmii_rx_dv_d3_reg <= 1'b0;
        gmii_rx_dv_d4_reg <= 1'b0;
    end
end

endmodule

`resetall
