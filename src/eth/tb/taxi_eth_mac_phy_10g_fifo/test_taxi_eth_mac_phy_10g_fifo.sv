// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * 10G Ethernet MAC with TX and RX FIFOs testbench
 */
module test_taxi_eth_mac_phy_10g_fifo #
(
    /* verilator lint_off WIDTHTRUNC */
    parameter DATA_W = 64,
    parameter HDR_W = 2,
    parameter logic TX_GBX_IF_EN = 1'b0,
    parameter logic RX_GBX_IF_EN = TX_GBX_IF_EN,
    parameter logic USXGMII_EN = 1'b1,
    parameter AXIS_DATA_W = 8,
    parameter logic DIC_EN = 1'b1,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TD_EN = PTP_TS_EN,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64,
    parameter PTP_TD_SDI_PIPELINE = 2,
    parameter TX_TAG_W = 16,
    parameter logic BIT_REVERSE = 1'b0,
    parameter logic SCRAMBLER_DISABLE = 1'b0,
    parameter logic PRBS31_EN = 1'b0,
    parameter TX_SERDES_PIPELINE = 0,
    parameter RX_SERDES_PIPELINE = 0,
    parameter BITSLIP_HIGH_CYCLES = 0,
    parameter BITSLIP_LOW_CYCLES = 7,
    parameter COUNT_125US = 125000/6.4,
    parameter logic STAT_EN = 1'b0,
    parameter STAT_TX_LEVEL = 1,
    parameter STAT_RX_LEVEL = STAT_TX_LEVEL,
    parameter STAT_ID_BASE = 0,
    parameter STAT_UPDATE_PERIOD = 1024,
    parameter logic STAT_STR_EN = 1'b1,
    parameter logic [8*8-1:0] STAT_PREFIX_STR = "MAC",
    parameter TX_FIFO_DEPTH = 4096,
    parameter TX_FIFO_RAM_PIPELINE = 1,
    parameter logic TX_FRAME_FIFO = 1'b1,
    parameter logic TX_DROP_OVERSIZE_FRAME = TX_FRAME_FIFO,
    parameter logic TX_DROP_BAD_FRAME = TX_DROP_OVERSIZE_FRAME,
    parameter logic TX_DROP_WHEN_FULL = 1'b0,
    parameter TX_CPL_FIFO_DEPTH = 64,
    parameter RX_FIFO_DEPTH = 4096,
    parameter RX_FIFO_RAM_PIPELINE = 1,
    parameter logic RX_FRAME_FIFO = 1'b1,
    parameter logic RX_DROP_OVERSIZE_FRAME = RX_FRAME_FIFO,
    parameter logic RX_DROP_BAD_FRAME = RX_DROP_OVERSIZE_FRAME,
    parameter logic RX_DROP_WHEN_FULL = RX_DROP_OVERSIZE_FRAME
    /* verilator lint_on WIDTHTRUNC */
)
();

localparam TX_USER_W = 1;
localparam RX_USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

logic rx_clk;
logic rx_rst;
logic tx_clk;
logic tx_rst;
logic logic_clk;
logic logic_rst;

taxi_axis_if #(.DATA_W(AXIS_DATA_W), .USER_EN(1), .USER_W(TX_USER_W), .ID_EN(1), .ID_W(TX_TAG_W)) s_axis_tx();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_EN(1), .ID_W(TX_TAG_W)) m_axis_tx_cpl();
taxi_axis_if #(.DATA_W(AXIS_DATA_W), .USER_EN(1), .USER_W(RX_USER_W)) m_axis_rx();

logic [DATA_W-1:0] serdes_tx_data;
logic serdes_tx_data_valid;
logic [HDR_W-1:0] serdes_tx_hdr;
logic serdes_tx_hdr_valid;
logic serdes_tx_gbx_req_sync;
logic serdes_tx_gbx_req_stall;
logic serdes_tx_gbx_sync;
logic [DATA_W-1:0] serdes_rx_data;
logic serdes_rx_data_valid;
logic [HDR_W-1:0] serdes_rx_hdr;
logic serdes_rx_hdr_valid;
logic serdes_rx_bitslip;
logic serdes_rx_reset_req;

logic an_en;
logic an_restart;
logic an_speedup;
logic an_timeout_en;
logic an_usxgmii_en;
logic an_usxgmii_auto;
logic an_usxgmii_5g;
logic an_intr;
logic an_running;
logic an_complete;
logic an_timeout;
logic an_usxgmii_mode;
logic [15:0] an_adv_ability_usxgmii;
logic [15:0] an_lp_adv_ability;
logic an_lp_usxgmii_link;
logic [2:0]  an_lp_usxgmii_speed;
logic an_res_full_duplex;

logic ptp_clk;
logic ptp_rst;
logic ptp_sample_clk;
logic ptp_td_sdi;
logic [PTP_TS_W-1:0] ptp_ts_in;
logic ptp_ts_step_in;
logic [PTP_TS_W-1:0] tx_ptp_ts_out;
logic tx_ptp_ts_step_out;
logic tx_ptp_locked;
logic [PTP_TS_W-1:0] rx_ptp_ts_out;
logic rx_ptp_ts_step_out;
logic rx_ptp_locked;

logic stat_clk;
logic stat_rst;
taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(8)) m_axis_stat();

logic tx_error_underflow;
logic tx_fifo_overflow;
logic tx_fifo_bad_frame;
logic tx_fifo_good_frame;
logic rx_error_bad_frame;
logic rx_error_bad_fcs;
logic rx_bad_block;
logic rx_sequence_error;
logic rx_block_lock;
logic rx_high_ber;
logic rx_status;
logic rx_fifo_overflow;
logic rx_fifo_bad_frame;
logic rx_fifo_good_frame;

logic cfg_tx_pad_en;
logic [7:0] cfg_tx_min_pkt_len;
logic [15:0] cfg_tx_max_pkt_len;
logic [7:0] cfg_tx_ifg;
logic cfg_tx_enable;
logic [15:0] cfg_rx_max_pkt_len;
logic cfg_rx_enable;
logic cfg_tx_prbs31_enable;
logic cfg_rx_prbs31_enable;

taxi_eth_mac_phy_10g_fifo #(
    .DATA_W(DATA_W),
    .HDR_W(HDR_W),
    .TX_GBX_IF_EN(TX_GBX_IF_EN),
    .RX_GBX_IF_EN(RX_GBX_IF_EN),
    .USXGMII_EN(USXGMII_EN),
    .DIC_EN(DIC_EN),
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TD_EN(PTP_TD_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD),
    .PTP_TS_W(PTP_TS_W),
    .PTP_TD_SDI_PIPELINE(PTP_TD_SDI_PIPELINE),
    .BIT_REVERSE(BIT_REVERSE),
    .SCRAMBLER_DISABLE(SCRAMBLER_DISABLE),
    .PRBS31_EN(PRBS31_EN),
    .TX_SERDES_PIPELINE(TX_SERDES_PIPELINE),
    .RX_SERDES_PIPELINE(RX_SERDES_PIPELINE),
    .BITSLIP_HIGH_CYCLES(BITSLIP_HIGH_CYCLES),
    .BITSLIP_LOW_CYCLES(BITSLIP_LOW_CYCLES),
    .COUNT_125US(COUNT_125US),
    .STAT_EN(STAT_EN),
    .STAT_TX_LEVEL(STAT_TX_LEVEL),
    .STAT_RX_LEVEL(STAT_RX_LEVEL),
    .STAT_ID_BASE(STAT_ID_BASE),
    .STAT_UPDATE_PERIOD(STAT_UPDATE_PERIOD),
    .STAT_STR_EN(STAT_STR_EN),
    .STAT_PREFIX_STR(STAT_PREFIX_STR),
    .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
    .TX_FIFO_RAM_PIPELINE(TX_FIFO_RAM_PIPELINE),
    .TX_FRAME_FIFO(TX_FRAME_FIFO),
    .TX_DROP_OVERSIZE_FRAME(TX_DROP_OVERSIZE_FRAME),
    .TX_DROP_BAD_FRAME(TX_DROP_BAD_FRAME),
    .TX_DROP_WHEN_FULL(TX_DROP_WHEN_FULL),
    .TX_CPL_FIFO_DEPTH(TX_CPL_FIFO_DEPTH),
    .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
    .RX_FIFO_RAM_PIPELINE(RX_FIFO_RAM_PIPELINE),
    .RX_FRAME_FIFO(RX_FRAME_FIFO),
    .RX_DROP_OVERSIZE_FRAME(RX_DROP_OVERSIZE_FRAME),
    .RX_DROP_BAD_FRAME(RX_DROP_BAD_FRAME),
    .RX_DROP_WHEN_FULL(RX_DROP_WHEN_FULL)
)
uut (
    .rx_clk(rx_clk),
    .rx_rst(rx_rst),
    .tx_clk(tx_clk),
    .tx_rst(tx_rst),
    .logic_clk(logic_clk),
    .logic_rst(logic_rst),

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
    .serdes_tx_data_valid(serdes_tx_data_valid),
    .serdes_tx_hdr(serdes_tx_hdr),
    .serdes_tx_hdr_valid(serdes_tx_hdr_valid),
    .serdes_tx_gbx_req_sync(serdes_tx_gbx_req_sync),
    .serdes_tx_gbx_req_stall(serdes_tx_gbx_req_stall),
    .serdes_tx_gbx_sync(serdes_tx_gbx_sync),
    .serdes_rx_data(serdes_rx_data),
    .serdes_rx_data_valid(serdes_rx_data_valid),
    .serdes_rx_hdr(serdes_rx_hdr),
    .serdes_rx_hdr_valid(serdes_rx_hdr_valid),
    .serdes_rx_bitslip(serdes_rx_bitslip),
    .serdes_rx_reset_req(serdes_rx_reset_req),

    /*
     * USXGMII autonegotiation
     */
    .an_en(an_en),
    .an_restart(an_restart),
    .an_speedup(an_speedup),
    .an_timeout_en(an_timeout_en),
    .an_usxgmii_en(an_usxgmii_en),
    .an_usxgmii_auto(an_usxgmii_auto),
    .an_usxgmii_5g(an_usxgmii_5g),
    .an_intr(an_intr),
    .an_running(an_running),
    .an_complete(an_complete),
    .an_timeout(an_timeout),
    .an_usxgmii_mode(an_usxgmii_mode),
    .an_adv_ability_usxgmii(an_adv_ability_usxgmii),
    .an_lp_adv_ability(an_lp_adv_ability),
    .an_lp_usxgmii_link(an_lp_usxgmii_link),
    .an_lp_usxgmii_speed(an_lp_usxgmii_speed),
    .an_res_full_duplex(an_res_full_duplex),

    /*
     * PTP clock
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_sample_clk(ptp_sample_clk),
    .ptp_td_sdi(ptp_td_sdi),
    .ptp_ts_in(ptp_ts_in),
    .ptp_ts_step_in(ptp_ts_step_in),
    .tx_ptp_ts_out(tx_ptp_ts_out),
    .tx_ptp_ts_step_out(tx_ptp_ts_step_out),
    .tx_ptp_locked(tx_ptp_locked),
    .rx_ptp_ts_out(rx_ptp_ts_out),
    .rx_ptp_ts_step_out(rx_ptp_ts_step_out),
    .rx_ptp_locked(rx_ptp_locked),

    /*
     * Statistics
     */
    .stat_clk(stat_clk),
    .stat_rst(stat_rst),
    .m_axis_stat(m_axis_stat),

    /*
     * Status
     */
    .tx_error_underflow(tx_error_underflow),
    .tx_fifo_overflow(tx_fifo_overflow),
    .tx_fifo_bad_frame(tx_fifo_bad_frame),
    .tx_fifo_good_frame(tx_fifo_good_frame),
    .rx_error_bad_frame(rx_error_bad_frame),
    .rx_error_bad_fcs(rx_error_bad_fcs),
    .rx_bad_block(rx_bad_block),
    .rx_sequence_error(rx_sequence_error),
    .rx_block_lock(rx_block_lock),
    .rx_high_ber(rx_high_ber),
    .rx_status(rx_status),
    .rx_fifo_overflow(rx_fifo_overflow),
    .rx_fifo_bad_frame(rx_fifo_bad_frame),
    .rx_fifo_good_frame(rx_fifo_good_frame),

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
    .cfg_rx_prbs31_enable(cfg_rx_prbs31_enable)
);

endmodule

`resetall
