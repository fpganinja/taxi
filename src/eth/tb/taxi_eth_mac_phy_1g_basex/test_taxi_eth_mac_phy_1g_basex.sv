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
 * 1000BASE-X Ethernet MAC/PHY combination testbench
 */
module test_taxi_eth_mac_phy_1g_basex #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter DATA_W = 16,
    parameter CTRL_W = DATA_W/8,
    parameter logic TX_GBX_IF_EN = 1'b0,
    parameter logic RX_GBX_IF_EN = TX_GBX_IF_EN,
    parameter logic AN_EN = 1'b1,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TD_EN = PTP_TS_EN,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter PTP_TD_SDI_PIPELINE = 2,
    parameter TX_TAG_W = 16,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic ENC_8B10B_EN = 1'b0,
    parameter logic DEC_8B10B_EN = ENC_8B10B_EN,
    parameter logic PRBS31_EN = 1'b0,
    parameter TX_SERDES_PIPELINE = 0,
    parameter RX_SERDES_PIPELINE = 0,
    parameter logic PFC_EN = 1'b0,
    parameter logic PAUSE_EN = PFC_EN,
    parameter logic STAT_EN = 1'b0,
    parameter STAT_TX_LEVEL = 1,
    parameter STAT_RX_LEVEL = STAT_TX_LEVEL,
    parameter STAT_ID_BASE = 0,
    parameter STAT_UPDATE_PERIOD = 1024,
    parameter logic STAT_STR_EN = 1'b1,
    parameter logic [8*8-1:0] STAT_PREFIX_STR = "MAC"
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam TX_USER_W = 1;
localparam RX_USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

logic rx_clk;
logic rx_rst;
logic tx_clk;
logic tx_rst;

taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(TX_USER_W), .ID_EN(1), .ID_W(TX_TAG_W)) s_axis_tx();
taxi_axis_if #(.DATA_W(PTP_TS_W), .KEEP_W(1), .ID_EN(1), .ID_W(TX_TAG_W)) m_axis_tx_cpl();
taxi_axis_if #(.DATA_W(DATA_W), .USER_EN(1), .USER_W(RX_USER_W)) m_axis_rx();

logic [DATA_W-1:0] serdes_tx_data;
logic [CTRL_W-1:0] serdes_tx_data_k;
logic [CTRL_W-1:0] serdes_tx_data_dm;
logic [CTRL_W-1:0] serdes_tx_data_dv;
logic serdes_tx_data_valid;
logic serdes_tx_gbx_req_sync;
logic serdes_tx_gbx_req_stall;
logic serdes_tx_gbx_sync;
logic [DATA_W-1:0] serdes_rx_data;
logic [CTRL_W-1:0] serdes_rx_data_k;
logic serdes_rx_data_valid;
logic serdes_rx_reset_req;

logic an_en;
logic an_restart;
logic an_speedup;
logic an_intr;
logic an_complete;
logic [15:0] an_adv_ability;
logic [15:0] an_lp_adv_ability;

logic ptp_clk;
logic ptp_rst;
logic ptp_sample_clk;
logic ptp_td_sdi;
logic [PTP_TS_W-1:0] tx_ptp_ts_in;
logic [PTP_TS_W-1:0] tx_ptp_ts_out;
logic tx_ptp_ts_step_out;
logic tx_ptp_locked;
logic [PTP_TS_W-1:0] rx_ptp_ts_in;
logic [PTP_TS_W-1:0] rx_ptp_ts_out;
logic rx_ptp_ts_step_out;
logic rx_ptp_locked;

logic tx_lfc_req;
logic tx_lfc_resend;
logic rx_lfc_en;
logic rx_lfc_req;
logic rx_lfc_ack;

logic [7:0] tx_pfc_req;
logic tx_pfc_resend;
logic [7:0] rx_pfc_en;
logic [7:0] rx_pfc_req;
logic [7:0] rx_pfc_ack;

logic tx_lfc_pause_en;
logic tx_pause_req;
logic tx_pause_ack;

logic stat_clk;
logic stat_rst;
taxi_axis_if #(.DATA_W(24), .KEEP_W(1), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) m_axis_stat();

logic [1:0] tx_start_packet;
logic [1:0] stat_tx_byte;
logic [15:0] stat_tx_pkt_len;
logic stat_tx_pkt_ucast;
logic stat_tx_pkt_mcast;
logic stat_tx_pkt_bcast;
logic stat_tx_pkt_vlan;
logic stat_tx_pkt_good;
logic stat_tx_pkt_bad;
logic stat_tx_pad_frame;
logic stat_tx_err_oversize;
logic stat_tx_err_user;
logic stat_tx_err_underflow;
logic [1:0] rx_start_packet;
logic [4:0] rx_error_count;
logic rx_block_lock;
logic rx_high_ber;
logic rx_status;
logic [1:0] stat_rx_byte;
logic [15:0] stat_rx_pkt_len;
logic stat_rx_pkt_fragment;
logic stat_rx_pkt_jabber;
logic stat_rx_pkt_ucast;
logic stat_rx_pkt_mcast;
logic stat_rx_pkt_bcast;
logic stat_rx_pkt_vlan;
logic stat_rx_pkt_good;
logic stat_rx_pkt_bad;
logic stat_rx_err_oversize;
logic stat_rx_err_bad_fcs;
logic stat_rx_err_bad_block;
logic stat_rx_err_framing;
logic stat_rx_err_preamble;
logic stat_rx_fifo_drop;
logic stat_tx_mcf;
logic stat_rx_mcf;
logic stat_tx_lfc_pkt;
logic stat_tx_lfc_xon;
logic stat_tx_lfc_xoff;
logic stat_tx_lfc_paused;
logic stat_tx_pfc_pkt;
logic [7:0] stat_tx_pfc_xon;
logic [7:0] stat_tx_pfc_xoff;
logic [7:0] stat_tx_pfc_paused;
logic stat_rx_lfc_pkt;
logic stat_rx_lfc_xon;
logic stat_rx_lfc_xoff;
logic stat_rx_lfc_paused;
logic stat_rx_pfc_pkt;
logic [7:0] stat_rx_pfc_xon;
logic [7:0] stat_rx_pfc_xoff;
logic [7:0] stat_rx_pfc_paused;

logic cfg_tx_pad_en;
logic [7:0] cfg_tx_min_pkt_len;
logic [15:0] cfg_tx_max_pkt_len;
logic [7:0] cfg_tx_ifg;
logic cfg_tx_enable;
logic [15:0] cfg_rx_max_pkt_len;
logic cfg_rx_enable;
logic cfg_tx_prbs31_enable;
logic cfg_rx_prbs31_enable;
logic [47:0] cfg_mcf_rx_eth_dst_mcast;
logic cfg_mcf_rx_check_eth_dst_mcast;
logic [47:0] cfg_mcf_rx_eth_dst_ucast;
logic cfg_mcf_rx_check_eth_dst_ucast;
logic [47:0] cfg_mcf_rx_eth_src;
logic cfg_mcf_rx_check_eth_src;
logic [15:0] cfg_mcf_rx_eth_type;
logic [15:0] cfg_mcf_rx_opcode_lfc;
logic cfg_mcf_rx_check_opcode_lfc;
logic [15:0] cfg_mcf_rx_opcode_pfc;
logic cfg_mcf_rx_check_opcode_pfc;
logic cfg_mcf_rx_forward;
logic cfg_mcf_rx_enable;
logic [47:0] cfg_tx_lfc_eth_dst;
logic [47:0] cfg_tx_lfc_eth_src;
logic [15:0] cfg_tx_lfc_eth_type;
logic [15:0] cfg_tx_lfc_opcode;
logic cfg_tx_lfc_en;
logic [15:0] cfg_tx_lfc_quanta;
logic [15:0] cfg_tx_lfc_refresh;
logic [47:0] cfg_tx_pfc_eth_dst;
logic [47:0] cfg_tx_pfc_eth_src;
logic [15:0] cfg_tx_pfc_eth_type;
logic [15:0] cfg_tx_pfc_opcode;
logic cfg_tx_pfc_en;
logic [15:0] cfg_tx_pfc_quanta[8];
logic [15:0] cfg_tx_pfc_refresh[8];
logic [15:0] cfg_rx_lfc_opcode;
logic cfg_rx_lfc_en;
logic [15:0] cfg_rx_pfc_opcode;
logic cfg_rx_pfc_en;

taxi_eth_mac_phy_1g_basex #(
    .DATA_W(DATA_W),
    .CTRL_W(CTRL_W),
    .TX_GBX_IF_EN(TX_GBX_IF_EN),
    .RX_GBX_IF_EN(RX_GBX_IF_EN),
    .AN_EN(AN_EN),
    .DIC_EN(DIC_EN),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TD_EN(PTP_TD_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
    .PTP_TS_W(PTP_TS_W),
    .PTP_TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE),
    .BIT_REVERSE(BIT_REVERSE),
    .ENC_8B10B_EN(ENC_8B10B_EN),
    .DEC_8B10B_EN(DEC_8B10B_EN),
    .PRBS31_EN(PRBS31_EN),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .PFC_EN(PFC_EN),
    .PAUSE_EN(PAUSE_EN),
    .STAT_EN(STAT_EN),
    .STAT_TX_LEVEL(STAT_TX_LEVEL),
    .STAT_RX_LEVEL(STAT_RX_LEVEL),
    .STAT_ID_BASE(STAT_ID_BASE),
    .STAT_UPDATE_PERIOD(STAT_UPDATE_PERIOD),
    .STAT_STR_EN(STAT_STR_EN),
    .STAT_PREFIX_STR(STAT_PREFIX_STR)
)
uut (
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(s_axis_tx),
    .m_axis_tx_cpl(m_axis_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(m_axis_rx),

    /*
     * SERDES interface
     */
    .serdes_tx_data(serdes_tx_data),
    .serdes_tx_data_k(serdes_tx_data_k),
    .serdes_tx_data_dm(serdes_tx_data_dm),
    .serdes_tx_data_dv(serdes_tx_data_dv),
    .serdes_tx_data_valid(serdes_tx_data_valid),
    .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
    .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
    .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_data_k(serdes_rx_data_k),
    .serdes_rx_data_valid(serdes_rx_data_valid),
    .serdes_rx_reset_req(serdes_rx_reset_req),

    /*
     * Autonegotiation
     */
    .an_en(an_en),
    .an_restart(an_restart),
    .an_speedup(an_speedup),
    .an_intr(an_intr),
    .an_complete(an_complete),
    .an_adv_ability(an_adv_ability),
    .an_lp_adv_ability(an_lp_adv_ability),

    /*
     * PTP
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sdi(ptp_td_sdi),
    .tx_ptp_ts_in(tx_ptp_ts_in),
    .tx_ptp_ts_out(tx_ptp_ts_out),
    .tx_ptp_ts_step_out(tx_ptp_ts_step_out),
    .tx_ptp_locked(tx_ptp_locked),
    .rx_ptp_ts_in(rx_ptp_ts_in),
    .rx_ptp_ts_out(rx_ptp_ts_out),
    .rx_ptp_ts_step_out(rx_ptp_ts_step_out),
    .rx_ptp_locked(rx_ptp_locked),

    /*
     * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
     */
    .tx_lfc_req(tx_lfc_req),
    .tx_lfc_resend(tx_lfc_resend),
    .rx_lfc_en(rx_lfc_en),
    .rx_lfc_req(rx_lfc_req),
    .rx_lfc_ack(rx_lfc_ack),

    /*
     * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
     */
    .tx_pfc_req(tx_pfc_req),
    .tx_pfc_resend(tx_pfc_resend),
    .rx_pfc_en(rx_pfc_en),
    .rx_pfc_req(rx_pfc_req),
    .rx_pfc_ack(rx_pfc_ack),

    /*
     * Pause interface
     */
    .tx_lfc_pause_en(tx_lfc_pause_en),
    .tx_pause_req(tx_pause_req),
    .tx_pause_ack(tx_pause_ack),

    /*
     * Statistics
     */
    .stat_clk(stat_clk),
    .stat_rst(stat_rst),
    .m_axis_stat(m_axis_stat),

    /*
     * Status
     */
    .tx_start_packet(tx_start_packet),
    .stat_tx_byte(stat_tx_byte),
    .stat_tx_pkt_len(stat_tx_pkt_len),
    .stat_tx_pkt_ucast(stat_tx_pkt_ucast),
    .stat_tx_pkt_mcast(stat_tx_pkt_mcast),
    .stat_tx_pkt_bcast(stat_tx_pkt_bcast),
    .stat_tx_pkt_vlan(stat_tx_pkt_vlan),
    .stat_tx_pkt_good(stat_tx_pkt_good),
    .stat_tx_pkt_bad(stat_tx_pkt_bad),
    .stat_tx_pad_frame(stat_tx_pad_frame),
    .stat_tx_err_oversize(stat_tx_err_oversize),
    .stat_tx_err_user(stat_tx_err_user),
    .stat_tx_err_underflow(stat_tx_err_underflow),
    .rx_start_packet(rx_start_packet),
    .rx_error_count(rx_error_count),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),
    .stat_rx_byte(stat_rx_byte),
    .stat_rx_pkt_len(stat_rx_pkt_len),
    .stat_rx_pkt_fragment(stat_rx_pkt_fragment),
    .stat_rx_pkt_jabber(stat_rx_pkt_jabber),
    .stat_rx_pkt_ucast(stat_rx_pkt_ucast),
    .stat_rx_pkt_mcast(stat_rx_pkt_mcast),
    .stat_rx_pkt_bcast(stat_rx_pkt_bcast),
    .stat_rx_pkt_vlan(stat_rx_pkt_vlan),
    .stat_rx_pkt_good(stat_rx_pkt_good),
    .stat_rx_pkt_bad(stat_rx_pkt_bad),
    .stat_rx_err_oversize(stat_rx_err_oversize),
    .stat_rx_err_bad_fcs(stat_rx_err_bad_fcs),
    .stat_rx_err_bad_block(stat_rx_err_bad_block),
    .stat_rx_err_framing(stat_rx_err_framing),
    .stat_rx_err_preamble(stat_rx_err_preamble),
    .stat_rx_fifo_drop(stat_rx_fifo_drop),
    .stat_tx_mcf(stat_tx_mcf),
    .stat_rx_mcf(stat_rx_mcf),
    .stat_tx_lfc_pkt(stat_tx_lfc_pkt),
    .stat_tx_lfc_xon(stat_tx_lfc_xon),
    .stat_tx_lfc_xoff(stat_tx_lfc_xoff),
    .stat_tx_lfc_paused(stat_tx_lfc_paused),
    .stat_tx_pfc_pkt(stat_tx_pfc_pkt),
    .stat_tx_pfc_xon(stat_tx_pfc_xon),
    .stat_tx_pfc_xoff(stat_tx_pfc_xoff),
    .stat_tx_pfc_paused(stat_tx_pfc_paused),
    .stat_rx_lfc_pkt(stat_rx_lfc_pkt),
    .stat_rx_lfc_xon(stat_rx_lfc_xon),
    .stat_rx_lfc_xoff(stat_rx_lfc_xoff),
    .stat_rx_lfc_paused(stat_rx_lfc_paused),
    .stat_rx_pfc_pkt(stat_rx_pfc_pkt),
    .stat_rx_pfc_xon(stat_rx_pfc_xon),
    .stat_rx_pfc_xoff(stat_rx_pfc_xoff),
    .stat_rx_pfc_paused(stat_rx_pfc_paused),

    /*
     * Configuration
     */
    .cfg_tx_pad_en(cfg_tx_pad_en),
    .cfg_tx_min_pkt_len(cfg_tx_min_pkt_len),
    .cfg_tx_max_pkt_len(cfg_tx_max_pkt_len),
    .cfg_tx_ifg(cfg_tx_ifg),
    .cfg_tx_enable(cfg_tx_enable),
    .cfg_rx_max_pkt_len(cfg_rx_max_pkt_len),
    .cfg_rx_enable(cfg_rx_enable),
    .cfg_tx_prbs31_enable(cfg_tx_prbs31_enable),
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable),
    .cfg_mcf_rx_eth_dst_mcast(cfg_mcf_rx_eth_dst_mcast),
    .cfg_mcf_rx_check_eth_dst_mcast(cfg_mcf_rx_check_eth_dst_mcast),
    .cfg_mcf_rx_eth_dst_ucast(cfg_mcf_rx_eth_dst_ucast),
    .cfg_mcf_rx_check_eth_dst_ucast(cfg_mcf_rx_check_eth_dst_ucast),
    .cfg_mcf_rx_eth_src(cfg_mcf_rx_eth_src),
    .cfg_mcf_rx_check_eth_src(cfg_mcf_rx_check_eth_src),
    .cfg_mcf_rx_eth_type(cfg_mcf_rx_eth_type),
    .cfg_mcf_rx_opcode_lfc(cfg_mcf_rx_opcode_lfc),
    .cfg_mcf_rx_check_opcode_lfc(cfg_mcf_rx_check_opcode_lfc),
    .cfg_mcf_rx_opcode_pfc(cfg_mcf_rx_opcode_pfc),
    .cfg_mcf_rx_check_opcode_pfc(cfg_mcf_rx_check_opcode_pfc),
    .cfg_mcf_rx_forward(cfg_mcf_rx_forward),
    .cfg_mcf_rx_enable(cfg_mcf_rx_enable),
    .cfg_tx_lfc_eth_dst(cfg_tx_lfc_eth_dst),
    .cfg_tx_lfc_eth_src(cfg_tx_lfc_eth_src),
    .cfg_tx_lfc_eth_type(cfg_tx_lfc_eth_type),
    .cfg_tx_lfc_opcode(cfg_tx_lfc_opcode),
    .cfg_tx_lfc_en(cfg_tx_lfc_en),
    .cfg_tx_lfc_quanta(cfg_tx_lfc_quanta),
    .cfg_tx_lfc_refresh(cfg_tx_lfc_refresh),
    .cfg_tx_pfc_eth_dst(cfg_tx_pfc_eth_dst),
    .cfg_tx_pfc_eth_src(cfg_tx_pfc_eth_src),
    .cfg_tx_pfc_eth_type(cfg_tx_pfc_eth_type),
    .cfg_tx_pfc_opcode(cfg_tx_pfc_opcode),
    .cfg_tx_pfc_en(cfg_tx_pfc_en),
    .cfg_tx_pfc_quanta(cfg_tx_pfc_quanta),
    .cfg_tx_pfc_refresh(cfg_tx_pfc_refresh),
    .cfg_rx_lfc_opcode(cfg_rx_lfc_opcode),
    .cfg_rx_lfc_en(cfg_rx_lfc_en),
    .cfg_rx_pfc_opcode(cfg_rx_pfc_opcode),
    .cfg_rx_pfc_en(cfg_rx_pfc_en)
);

endmodule

`resetall
