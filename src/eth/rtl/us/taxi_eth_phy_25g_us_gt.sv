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
 * Transceiver wrapper for UltraScale/UltraScale+
 */
module taxi_eth_phy_25g_us_gt #
(
    parameter logic SIM = 1'b0,
    parameter string VENDOR = "XILINX",
    parameter string FAMILY = "virtexuplus",

    parameter logic HAS_COMMON = 1'b1,

    // GT type
    parameter string GT_TYPE = "GTY",

    // PLL parameters
    parameter logic QPLL0_PD = 1'b0,
    parameter logic QPLL1_PD = 1'b1,
    parameter logic QPLL0_EXT_CTRL = 1'b0,
    parameter logic QPLL1_EXT_CTRL = 1'b0,

    // GT parameters
    parameter logic GT_TX_PD = 1'b0,
    parameter logic GT_TX_QPLL_SEL = 1'b0,
    parameter logic GT_TX_POLARITY = 1'b0,
    parameter logic GT_TX_ELECIDLE = 1'b0,
    parameter logic GT_TX_INHIBIT = 1'b0,
    parameter logic [4:0] GT_TX_DIFFCTRL = 5'd16,
    parameter logic [6:0] GT_TX_MAINCURSOR = 7'd64,
    parameter logic [4:0] GT_TX_POSTCURSOR = 5'd0,
    parameter logic [4:0] GT_TX_PRECURSOR = 5'd0,
    parameter logic GT_RX_PD = 1'b0,
    parameter logic GT_RX_QPLL_SEL = 1'b0,
    parameter logic GT_RX_LPM_EN = 1'b0,
    parameter logic GT_RX_POLARITY = 1'b0,

    // MAC/PHY parameters
    parameter DATA_W = 64,
    parameter HDR_W = 2
)
(
    input  wire logic               xcvr_ctrl_clk,
    input  wire logic               xcvr_ctrl_rst,

    /*
     * Transceiver control
     */
    taxi_apb_if.slv                 s_apb_ctrl,

    /*
     * Common
     */
    output wire logic               xcvr_gtpowergood_out,

    /*
     * PLL out
     */
    input  wire logic               xcvr_gtrefclk00_in = 1'b0,
    input  wire logic               xcvr_qpll0pd_in = 1'b0,
    input  wire logic               xcvr_qpll0reset_in = 1'b0,
    input  wire logic [2:0]         xcvr_qpll0pcierate_in = 3'd0,
    output wire logic               xcvr_qpll0lock_out,
    output wire logic               xcvr_qpll0clk_out,
    output wire logic               xcvr_qpll0refclk_out,
    input  wire logic               xcvr_gtrefclk01_in = 1'b0,
    input  wire logic               xcvr_qpll1pd_in = 1'b0,
    input  wire logic               xcvr_qpll1reset_in = 1'b0,
    input  wire logic [2:0]         xcvr_qpll1pcierate_in = 3'd0,
    output wire logic               xcvr_qpll1lock_out,
    output wire logic               xcvr_qpll1clk_out,
    output wire logic               xcvr_qpll1refclk_out,

    /*
     * PLL in
     */
    input  wire logic               xcvr_qpll0lock_in = 1'b0,
    input  wire logic               xcvr_qpll0clk_in = 1'b0,
    input  wire logic               xcvr_qpll0refclk_in = 1'b0,
    input  wire logic               xcvr_qpll1lock_in = 1'b0,
    input  wire logic               xcvr_qpll1clk_in = 1'b0,
    input  wire logic               xcvr_qpll1refclk_in = 1'b0,

    /*
     * Serial data
     */
    output wire logic               xcvr_txp,
    output wire logic               xcvr_txn,
    input  wire logic               xcvr_rxp,
    input  wire logic               xcvr_rxn,

    /*
     * GT user clocks
     */
    output wire logic               rx_clk,
    input  wire logic               rx_rst_in = 1'b0,
    output wire logic               rx_rst_out,
    output wire logic               tx_clk,
    input  wire logic               tx_rst_in = 1'b0,
    output wire logic               tx_rst_out,

    /*
     * Serdes interface
     */
    input  wire logic [DATA_W-1:0]  serdes_tx_data,
    input  wire logic               serdes_tx_data_valid,
    input  wire logic [HDR_W-1:0]   serdes_tx_hdr,
    input  wire logic               serdes_tx_hdr_valid,
    output wire logic               serdes_tx_gbx_req_sync,
    output wire logic               serdes_tx_gbx_req_stall,
    input  wire logic               serdes_tx_gbx_sync,
    output wire logic [DATA_W-1:0]  serdes_rx_data,
    output wire logic               serdes_rx_data_valid,
    output wire logic [HDR_W-1:0]   serdes_rx_hdr,
    output wire logic               serdes_rx_hdr_valid,
    input  wire logic               serdes_rx_bitslip
);

localparam GT_USP = FAMILY == "kintexuplus" || FAMILY == "virtexuplus" || FAMILY == "virtexuplusHBM"
    || FAMILY == "virtexuplus58G" || FAMILY == "zynquplus" || FAMILY == "zynquplusRFSOC" || FAMILY == "artixuplus";

// check configuration
if (DATA_W != 64)
    $fatal(0, "Error: Interface width must be 64");

if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2");

// status
wire qpll0_lock;
wire qpll1_lock;

wire tx_reset_done;
wire tx_pma_reset_done;
wire tx_prgdiv_reset_done;

wire rx_reset_done;
wire rx_pma_reset_done;
wire rx_prgdiv_reset_done;

// control registers
wire [10:0]  gt_drp_addr;
wire [15:0]  gt_drp_di;
wire         gt_drp_en;
wire         gt_drp_we;
wire [15:0]  gt_drp_do;
wire         gt_drp_rdy;

wire [10:0]  com_drp_addr;
wire [15:0]  com_drp_di;
wire         com_drp_en;
wire         com_drp_we;
wire [15:0]  com_drp_do;
wire         com_drp_rdy;

wire         ctrl_qpll0_reset;
wire         ctrl_qpll0_pd;
wire         ctrl_qpll1_reset;
wire         ctrl_qpll1_pd;

wire [2:0]   ctrl_loopback;

wire         ctrl_tx_reset;
wire         ctrl_tx_pma_reset;
wire         ctrl_tx_pcs_reset;
wire         ctrl_tx_pd;
wire         ctrl_tx_qpll_sel;
wire         ctrl_rx_reset;
wire         ctrl_rx_pma_reset;
wire         ctrl_rx_pcs_reset;
wire         ctrl_rx_dfe_lpm_reset;
wire         ctrl_eyescan_reset;
wire         ctrl_rx_pd;
wire         ctrl_rx_qpll_sel;

wire         ctrl_rxcdrhold;
wire         ctrl_rxlpmen;

wire [3:0]   ctrl_txprbssel;
wire         ctrl_txprbsforceerr;
wire         ctrl_txpolarity;
wire         ctrl_txelecidle;
wire         ctrl_txinhibit;
wire [4:0]   ctrl_txdiffctrl;
wire [6:0]   ctrl_txmaincursor;
wire [4:0]   ctrl_txpostcursor;
wire [4:0]   ctrl_txprecursor;

wire         ctrl_rxpolarity;
wire         ctrl_rxprbscntreset;
wire [3:0]   ctrl_rxprbssel;

wire         ctrl_rxprbserr;

wire [15:0]  ctrl_dmonitorout;

wire         ctrl_phy_rx_reset_req_en;

taxi_eth_phy_25g_us_gt_apb #(
    .HAS_COMMON(HAS_COMMON),

    // PLL parameters
    .QPLL0_PD(QPLL0_PD),
    .QPLL1_PD(QPLL1_PD),

    // GT parameters
    .GT_TX_PD(GT_TX_PD),
    .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL),
    .GT_TX_POLARITY(GT_TX_POLARITY),
    .GT_TX_ELECIDLE(GT_TX_ELECIDLE),
    .GT_TX_INHIBIT(GT_TX_INHIBIT),
    .GT_TX_DIFFCTRL(GT_TX_DIFFCTRL),
    .GT_TX_MAINCURSOR(GT_TX_MAINCURSOR),
    .GT_TX_POSTCURSOR(GT_TX_POSTCURSOR),
    .GT_TX_PRECURSOR(GT_TX_PRECURSOR),
    .GT_RX_PD(GT_RX_PD),
    .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL),
    .GT_RX_LPM_EN(GT_RX_LPM_EN),
    .GT_RX_POLARITY(GT_RX_POLARITY)
)
ctrl_regs_inst (
    .clk(xcvr_ctrl_clk),
    .rst(xcvr_ctrl_rst),

    /*
     * Transceiver clocks
     */
    .gt_txusrclk2(tx_clk),
    .gt_rxusrclk2(rx_clk),

    /*
     * Transceiver control
     */
    .s_apb_ctrl(s_apb_ctrl),

    /*
     * DRP (channel)
     */
    .gt_drp_addr(gt_drp_addr),
    .gt_drp_di(gt_drp_di),
    .gt_drp_en(gt_drp_en),
    .gt_drp_we(gt_drp_we),
    .gt_drp_do(gt_drp_do),
    .gt_drp_rdy(gt_drp_rdy),

    /*
     * DRP (common)
     */
    .com_drp_addr(com_drp_addr),
    .com_drp_di(com_drp_di),
    .com_drp_en(com_drp_en),
    .com_drp_we(com_drp_we),
    .com_drp_do(com_drp_do),
    .com_drp_rdy(com_drp_rdy),

    /*
     * Control and status signals
     */
    .qpll0_reset(ctrl_qpll0_reset),
    .qpll0_pd(ctrl_qpll0_pd),
    .qpll0_lock(qpll0_lock),
    .qpll1_reset(ctrl_qpll1_reset),
    .qpll1_pd(ctrl_qpll1_pd),
    .qpll1_lock(qpll1_lock),

    .gt_loopback(ctrl_loopback),

    .gt_tx_reset(ctrl_tx_reset),
    .gt_tx_pma_reset(ctrl_tx_pma_reset),
    .gt_tx_pcs_reset(ctrl_tx_pcs_reset),
    .gt_tx_reset_done(tx_reset_done),
    .gt_tx_pma_reset_done(tx_pma_reset_done),
    .gt_tx_prgdiv_reset_done(tx_prgdiv_reset_done),
    .gt_tx_pd(ctrl_tx_pd),
    .gt_tx_qpll_sel(ctrl_tx_qpll_sel),
    .gt_rx_reset(ctrl_rx_reset),
    .gt_rx_pma_reset(ctrl_rx_pma_reset),
    .gt_rx_pcs_reset(ctrl_rx_pcs_reset),
    .gt_rx_dfe_lpm_reset(ctrl_rx_dfe_lpm_reset),
    .gt_eyescan_reset(ctrl_eyescan_reset),
    .gt_rx_reset_done(rx_reset_done),
    .gt_rx_pma_reset_done(rx_pma_reset_done),
    .gt_rx_prgdiv_reset_done(rx_prgdiv_reset_done),
    .gt_rx_pd(ctrl_rx_pd),
    .gt_rx_qpll_sel(ctrl_rx_qpll_sel),

    .gt_rxcdrhold(ctrl_rxcdrhold),
    .gt_rxlpmen(ctrl_rxlpmen),

    .gt_txprbssel(ctrl_txprbssel),
    .gt_txprbsforceerr(ctrl_txprbsforceerr),
    .gt_txpolarity(ctrl_txpolarity),
    .gt_txelecidle(ctrl_txelecidle),
    .gt_txinhibit(ctrl_txinhibit),
    .gt_txdiffctrl(ctrl_txdiffctrl),
    .gt_txmaincursor(ctrl_txmaincursor),
    .gt_txpostcursor(ctrl_txpostcursor),
    .gt_txprecursor(ctrl_txprecursor),

    .gt_rxpolarity(ctrl_rxpolarity),
    .gt_rxprbscntreset(ctrl_rxprbscntreset),
    .gt_rxprbssel(ctrl_rxprbssel),

    .gt_rxprbserr(ctrl_rxprbserr),

    .gt_dmonitorout(ctrl_dmonitorout),

    .phy_rx_reset_req_en(ctrl_phy_rx_reset_req_en)
);

wire gt_qpll0_pd;
wire gt_qpll0_reset;
wire gt_qpll1_pd;
wire gt_qpll1_reset;

if (HAS_COMMON) begin : common_ctrl

    taxi_gt_qpll_reset #(
        .QPLL_PD(QPLL0_PD),
        .CNT_W(8)
    )
    qpll0_reset_inst (
        .clk(xcvr_ctrl_clk),
        .rst(xcvr_ctrl_rst),

        /*
         * GT
         */
        .gt_qpll_reset_out(gt_qpll0_reset),
        .gt_qpll_pd_out(gt_qpll0_pd),
        .gt_qpll_lock_in(xcvr_qpll0lock_out),

        /*
         * Control/status
         */
        .qpll_reset_in(ctrl_qpll0_reset),
        .qpll_pd_in(ctrl_qpll0_pd),
        .qpll_lock_out(qpll0_lock)
    );

    taxi_gt_qpll_reset #(
        .QPLL_PD(QPLL1_PD),
        .CNT_W(8)
    )
    qpll1_reset_inst (
        .clk(xcvr_ctrl_clk),
        .rst(xcvr_ctrl_rst),

        /*
         * GT
         */
        .gt_qpll_reset_out(gt_qpll1_reset),
        .gt_qpll_pd_out(gt_qpll1_pd),
        .gt_qpll_lock_in(xcvr_qpll1lock_out),

        /*
         * Control/status
         */
        .qpll_reset_in(ctrl_qpll1_reset),
        .qpll_pd_in(ctrl_qpll1_pd),
        .qpll_lock_out(qpll1_lock)
    );

end else begin : common_ctrl

    assign gt_qpll0_pd = 1'b1;
    assign gt_qpll0_reset = 1'b1;
    assign gt_qpll1_pd = 1'b1;
    assign gt_qpll1_reset = 1'b1;

    taxi_sync_signal #(
        .WIDTH(2),
        .N(2)
    )
    qpll_lock_sync_inst (
        .clk(xcvr_ctrl_clk),
        .in({xcvr_qpll1lock_in, xcvr_qpll0lock_in}),
        .out({qpll1_lock, qpll0_lock})
    );

end

wire gt_tx_pd;
wire gt_tx_reset;
wire gt_tx_reset_done;
wire gt_userclk_tx_active;
wire gt_tx_pma_reset;
wire gt_tx_pcs_reset;
wire gt_tx_pma_reset_done;
wire gt_tx_prgdiv_reset;
wire gt_tx_prgdiv_reset_done;
wire gt_tx_qpll_sel;
wire gt_tx_userrdy;

taxi_sync_reset #(
    .N(4)
)
tx_reset_sync_inst (
    .clk(tx_clk),
    .rst(!tx_reset_done || tx_rst_in),
    .out(tx_rst_out)
);

taxi_gt_tx_reset #(
    .GT_TX_PD(GT_TX_PD),
    .GT_TX_QPLL_SEL(GT_TX_QPLL_SEL),
    .CNT_W(8)
)
gt_tx_reset_inst (
    .clk(xcvr_ctrl_clk),
    .rst(xcvr_ctrl_rst),

    /*
     * GT
     */
    .gt_txusrclk2(tx_clk),
    .gt_tx_pd_out(gt_tx_pd),
    .gt_tx_reset_out(gt_tx_reset),
    .gt_tx_reset_done_in(gt_tx_reset_done),
    .gt_userclk_tx_active_in(gt_userclk_tx_active),
    .gt_tx_pma_reset_out(gt_tx_pma_reset),
    .gt_tx_pcs_reset_out(gt_tx_pcs_reset),
    .gt_tx_pma_reset_done_in(gt_tx_pma_reset_done),
    .gt_tx_prgdiv_reset_out(gt_tx_prgdiv_reset),
    .gt_tx_prgdiv_reset_done_in(gt_tx_prgdiv_reset_done),
    .gt_tx_qpll_sel_out(gt_tx_qpll_sel),
    .gt_tx_userrdy_out(gt_tx_userrdy),

    /*
     * Control/status
     */
    .qpll0_lock_in(qpll0_lock),
    .qpll1_lock_in(qpll1_lock),
    .tx_reset_in(tx_rst_in || ctrl_tx_reset),
    .tx_reset_done_out(tx_reset_done),
    .tx_pma_reset_in(ctrl_tx_pma_reset),
    .tx_pma_reset_done_out(tx_pma_reset_done),
    .tx_prgdiv_reset_done_out(tx_prgdiv_reset_done),
    .tx_pcs_reset_in(ctrl_tx_pcs_reset),
    .tx_pd_in(ctrl_tx_pd),
    .tx_qpll_sel_in(ctrl_tx_qpll_sel)
);

wire gt_rx_pd;
wire gt_rx_reset;
wire gt_rx_reset_done;
wire gt_userclk_rx_active;
wire gt_rx_pma_reset;
wire gt_rx_dfe_lpm_reset;
wire gt_rx_eyescan_reset;
wire gt_rx_pcs_reset;
wire gt_rx_pma_reset_done;
wire gt_rx_prgdiv_reset;
wire gt_rx_prgdiv_reset_done;
wire gt_rx_qpll_sel;
wire gt_rx_userrdy;
wire gt_rx_cdr_lock;
wire gt_rx_lpm_en;

taxi_sync_reset #(
    .N(4)
)
rx_reset_sync_inst (
    .clk(rx_clk),
    .rst(!rx_reset_done || rx_rst_in),
    .out(rx_rst_out)
);

taxi_gt_rx_reset #(
    .GT_RX_PD(GT_RX_PD),
    .GT_RX_QPLL_SEL(GT_RX_QPLL_SEL),
    .GT_RX_LPM_EN(GT_RX_LPM_EN),
    .CNT_W(8),
    .CDR_CNT_W(20)
)
gt_rx_reset_inst (
    .clk(xcvr_ctrl_clk),
    .rst(xcvr_ctrl_rst),

    /*
     * GT
     */
    .gt_rxusrclk2(rx_clk),
    .gt_rx_pd_out(gt_rx_pd),
    .gt_rx_reset_out(gt_rx_reset),
    .gt_rx_reset_done_in(gt_rx_reset_done),
    .gt_userclk_rx_active_in(gt_userclk_rx_active),
    .gt_rx_pma_reset_out(gt_rx_pma_reset),
    .gt_rx_dfe_lpm_reset_out(gt_rx_dfe_lpm_reset),
    .gt_rx_eyescan_reset_out(gt_rx_eyescan_reset),
    .gt_rx_pcs_reset_out(gt_rx_pcs_reset),
    .gt_rx_pma_reset_done_in(gt_rx_pma_reset_done),
    .gt_rx_prgdiv_reset_out(gt_rx_prgdiv_reset),
    .gt_rx_prgdiv_reset_done_in(gt_rx_prgdiv_reset_done),
    .gt_rx_qpll_sel_out(gt_rx_qpll_sel),
    .gt_rx_userrdy_out(gt_rx_userrdy),
    .gt_rx_cdr_lock_in(gt_rx_cdr_lock),
    .gt_rx_lpm_en_out(gt_rx_lpm_en),

    /*
     * Control/status
     */
    .qpll0_lock_in(qpll0_lock),
    .qpll1_lock_in(qpll1_lock),
    .rx_reset_in(rx_rst_in || ctrl_rx_reset),
    .rx_reset_done_out(rx_reset_done),
    .rx_pma_reset_in(ctrl_rx_pma_reset),
    .rx_pma_reset_done_out(rx_pma_reset_done),
    .rx_prgdiv_reset_done_out(rx_prgdiv_reset_done),
    .rx_pcs_reset_in(ctrl_rx_pcs_reset),
    .rx_dfe_lpm_reset_in(ctrl_rx_dfe_lpm_reset),
    .eyescan_reset_in(ctrl_eyescan_reset),
    .rx_pd_in(ctrl_rx_pd),
    .rx_qpll_sel_in(ctrl_rx_qpll_sel),
    .rx_lpm_en_in(ctrl_rxlpmen)
);

wire [6:0] gt_txsequence;
wire [5:0] gt_txheader;
wire [63:0] gt_txdata;
wire gt_rxgearboxslip;
wire [1:0] gt_rxstartofseq;
wire [5:0] gt_rxheader;
wire [1:0] gt_rxheadervalid;
wire [63:0] gt_rxdata;
wire [1:0] gt_rxdatavalid;

assign gt_txsequence = '0;
assign gt_txdata = serdes_tx_data;
assign gt_txheader = {4'd0, serdes_tx_hdr};
assign gt_rxgearboxslip = serdes_rx_bitslip;

if (!SIM) begin
    assign serdes_rx_data = gt_rxdata;
    assign serdes_rx_data_valid = gt_rxdatavalid;
    assign serdes_rx_hdr = gt_rxheader[1:0];
    assign serdes_rx_hdr_valid = gt_rxheadervalid[0];
end

assign serdes_tx_gbx_req_sync = 1'b0;
assign serdes_tx_gbx_req_stall = 1'b0;

if (SIM) begin : xcvr
    // simulation (no GT core)

    assign xcvr_gtpowergood_out = 1'b1;

    assign xcvr_qpll0lock_out = !gt_qpll0_reset && !gt_qpll0_pd;
    assign xcvr_qpll0clk_out = 1'b0;
    assign xcvr_qpll0refclk_out = xcvr_gtrefclk00_in;

    assign xcvr_qpll1lock_out = !gt_qpll1_reset && !gt_qpll1_pd;
    assign xcvr_qpll1clk_out = 1'b0;
    assign xcvr_qpll1refclk_out = xcvr_gtrefclk01_in;

    assign gt_tx_reset_done = !gt_tx_reset;
    assign gt_userclk_tx_active = gt_tx_qpll_sel ? qpll1_lock : qpll0_lock;
    assign gt_tx_pma_reset_done = gt_tx_reset_done;
    assign gt_tx_prgdiv_reset_done = gt_tx_reset_done;

    assign gt_rx_reset_done = !gt_rx_reset;
    assign gt_userclk_rx_active = gt_rx_qpll_sel ? qpll1_lock : qpll0_lock;
    assign gt_rx_pma_reset_done = gt_rx_reset_done;
    assign gt_rx_prgdiv_reset_done = gt_rx_reset_done;
    assign gt_rx_cdr_lock = gt_rx_reset_done;

    assign com_drp_do = 16'hCC00;
    assign com_drp_rdy = 1'b1;

    assign gt_drp_do = 16'hDA00;
    assign gt_drp_rdy = 1'b1;

end else if (HAS_COMMON && GT_TYPE == "GTY" && GT_USP) begin : xcvr
    // UltraScale+ GTY (with common)

    taxi_eth_phy_25g_us_gty_full
    taxi_eth_phy_25g_us_gty_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drpclk_common_in(xcvr_ctrl_clk),
        .drpaddr_common_in(com_drp_addr),
        .drpdi_common_in(com_drp_di),
        .drpen_common_in(com_drp_en),
        .drpwe_common_in(com_drp_we),
        .drpdo_common_out(com_drp_do),
        .drprdy_common_out(com_drp_rdy),

        .drpclk_in(xcvr_ctrl_clk),
        .drpaddr_in(gt_drp_addr),
        .drpdi_in(gt_drp_di),
        .drpen_in(gt_drp_en),
        .drpwe_in(gt_drp_we),
        .drpdo_out(gt_drp_do),
        .drprdy_out(gt_drp_rdy),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(xcvr_qpll0lock_out),
        .qpll0outclk_out(xcvr_qpll0clk_out),
        .qpll0outrefclk_out(xcvr_qpll0refclk_out),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(xcvr_qpll1lock_out),
        .qpll1outclk_out(xcvr_qpll1clk_out),
        .qpll1outrefclk_out(xcvr_qpll1refclk_out),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : gt_qpll0_pd),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : gt_qpll0_reset),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : gt_qpll1_pd),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : gt_qpll1_reset),

        .pcierateqpll0_in(QPLL0_EXT_CTRL ? xcvr_qpll0pcierate_in : 3'd0),
        .pcierateqpll1_in(QPLL1_EXT_CTRL ? xcvr_qpll1pcierate_in : 3'd0),

        // Serial data
        .gtytxp_out(xcvr_txp),
        .gtytxn_out(xcvr_txn),
        .gtyrxp_in(xcvr_rxp),
        .gtyrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_clk),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset),
        .txpmareset_in(gt_tx_pma_reset),
        .txpcsreset_in(gt_tx_pcs_reset),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy),

        .txpolarity_in(ctrl_txpolarity),
        .txelecidle_in(ctrl_txelecidle),
        .txinhibit_in(ctrl_txinhibit),
        .txdiffctrl_in(ctrl_txdiffctrl),
        .txmaincursor_in(ctrl_txmaincursor),
        .txprecursor_in(ctrl_txpostcursor),
        .txpostcursor_in(ctrl_txprecursor),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(gt_txsequence),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_clk),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done),
        .rxpd_in(gt_rx_pd ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset),
        .rxpmareset_in(gt_rx_pma_reset),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset),
        .eyescanreset_in(gt_rx_eyescan_reset),
        .rxpcsreset_in(gt_rx_pcs_reset),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy),

        .rxcdrlock_out(gt_rx_cdr_lock),
        .rxcdrhold_in(1'b0),
        .rxcdrovrden_in(1'b0),

        .rxlpmen_in(gt_rx_lpm_en),

        .rxpolarity_in(ctrl_rxpolarity),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

end else if (HAS_COMMON && GT_TYPE == "GTH" && GT_USP) begin : xcvr
    // UltraScale+ GTH (with common)

    taxi_eth_phy_25g_us_gth_full
    taxi_eth_phy_25g_us_gth_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drpclk_common_in(xcvr_ctrl_clk),
        .drpaddr_common_in(com_drp_addr),
        .drpdi_common_in(com_drp_di),
        .drpen_common_in(com_drp_en),
        .drpwe_common_in(com_drp_we),
        .drpdo_common_out(com_drp_do),
        .drprdy_common_out(com_drp_rdy),

        .drpclk_in(xcvr_ctrl_clk),
        .drpaddr_in(gt_drp_addr),
        .drpdi_in(gt_drp_di),
        .drpen_in(gt_drp_en),
        .drpwe_in(gt_drp_we),
        .drpdo_out(gt_drp_do),
        .drprdy_out(gt_drp_rdy),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(xcvr_qpll0lock_out),
        .qpll0outclk_out(xcvr_qpll0clk_out),
        .qpll0outrefclk_out(xcvr_qpll0refclk_out),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(xcvr_qpll1lock_out),
        .qpll1outclk_out(xcvr_qpll1clk_out),
        .qpll1outrefclk_out(xcvr_qpll1refclk_out),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : gt_qpll0_pd),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : gt_qpll0_reset),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : gt_qpll1_pd),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : gt_qpll1_reset),

        .pcierateqpll0_in(QPLL0_EXT_CTRL ? xcvr_qpll0pcierate_in : 3'd0),
        .pcierateqpll1_in(QPLL1_EXT_CTRL ? xcvr_qpll1pcierate_in : 3'd0),

        // Serial data
        .gthtxp_out(xcvr_txp),
        .gthtxn_out(xcvr_txn),
        .gthrxp_in(xcvr_rxp),
        .gthrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_clk),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset),
        .txpmareset_in(gt_tx_pma_reset),
        .txpcsreset_in(gt_tx_pcs_reset),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy),

        .txpolarity_in(ctrl_txpolarity),
        .txelecidle_in(ctrl_txelecidle),
        .txinhibit_in(ctrl_txinhibit),
        .txdiffctrl_in(ctrl_txdiffctrl),
        .txmaincursor_in(ctrl_txmaincursor),
        .txprecursor_in(ctrl_txpostcursor),
        .txpostcursor_in(ctrl_txprecursor),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(gt_txsequence),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_clk),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done),
        .rxpd_in(gt_rx_pd ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset),
        .rxpmareset_in(gt_rx_pma_reset),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset),
        .eyescanreset_in(gt_rx_eyescan_reset),
        .rxpcsreset_in(gt_rx_pcs_reset),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy),

        .rxcdrlock_out(gt_rx_cdr_lock),
        .rxcdrhold_in(1'b0),
        .rxcdrovrden_in(1'b0),

        .rxlpmen_in(gt_rx_lpm_en),

        .rxpolarity_in(ctrl_rxpolarity),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

end else if (HAS_COMMON && GT_TYPE == "GTY" && !GT_USP) begin : xcvr
    // UltraScale GTY (with common)

    taxi_eth_phy_25g_us_gty_full
    taxi_eth_phy_25g_us_gty_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drpclk_common_in(xcvr_ctrl_clk),
        .drpaddr_common_in(com_drp_addr),
        .drpdi_common_in(com_drp_di),
        .drpen_common_in(com_drp_en),
        .drpwe_common_in(com_drp_we),
        .drpdo_common_out(com_drp_do),
        .drprdy_common_out(com_drp_rdy),

        .drpclk_in(xcvr_ctrl_clk),
        .drpaddr_in(gt_drp_addr),
        .drpdi_in(gt_drp_di),
        .drpen_in(gt_drp_en),
        .drpwe_in(gt_drp_we),
        .drpdo_out(gt_drp_do),
        .drprdy_out(gt_drp_rdy),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(xcvr_qpll0lock_out),
        .qpll0outclk_out(xcvr_qpll0clk_out),
        .qpll0outrefclk_out(xcvr_qpll0refclk_out),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(xcvr_qpll1lock_out),
        .qpll1outclk_out(xcvr_qpll1clk_out),
        .qpll1outrefclk_out(xcvr_qpll1refclk_out),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : gt_qpll0_pd),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : gt_qpll0_reset),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : gt_qpll1_pd),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : gt_qpll1_reset),

        .qpllrsvd2_in(QPLL0_EXT_CTRL ? {2'd0, xcvr_qpll0pcierate_in} : 5'd0), // [2:0] : QPLL0 rate
        .qpllrsvd3_in(QPLL1_EXT_CTRL ? {2'd0, xcvr_qpll1pcierate_in} : 5'd0), // [2:0] : QPLL1 rate

        // Serial data
        .gtytxp_out(xcvr_txp),
        .gtytxn_out(xcvr_txn),
        .gtyrxp_in(xcvr_rxp),
        .gtyrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_clk),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset),
        .txpmareset_in(gt_tx_pma_reset),
        .txpcsreset_in(gt_tx_pcs_reset),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy),

        .txpolarity_in(ctrl_txpolarity),
        .txelecidle_in(ctrl_txelecidle),
        .txinhibit_in(ctrl_txinhibit),
        .txdiffctrl_in(ctrl_txdiffctrl),
        .txmaincursor_in(ctrl_txmaincursor),
        .txprecursor_in(ctrl_txpostcursor),
        .txpostcursor_in(ctrl_txprecursor),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(gt_txsequence),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_clk),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done),
        .rxpd_in(gt_rx_pd ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset),
        .rxpmareset_in(gt_rx_pma_reset),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset),
        .eyescanreset_in(gt_rx_eyescan_reset),
        .rxpcsreset_in(gt_rx_pcs_reset),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy),

        .rxcdrlock_out(gt_rx_cdr_lock),
        .rxcdrhold_in(1'b0),
        .rxcdrovrden_in(1'b0),

        .rxlpmen_in(gt_rx_lpm_en),

        .rxpolarity_in(ctrl_rxpolarity),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

end else if (HAS_COMMON && GT_TYPE == "GTH" && !GT_USP) begin : xcvr
    // UltraScale GTH (with common)

    taxi_eth_phy_25g_us_gth_full
    taxi_eth_phy_25g_us_gth_full_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drpclk_common_in(xcvr_ctrl_clk),
        .drpaddr_common_in(com_drp_addr),
        .drpdi_common_in(com_drp_di),
        .drpen_common_in(com_drp_en),
        .drpwe_common_in(com_drp_we),
        .drpdo_common_out(com_drp_do),
        .drprdy_common_out(com_drp_rdy),

        .drpclk_in(xcvr_ctrl_clk),
        .drpaddr_in(gt_drp_addr),
        .drpdi_in(gt_drp_di),
        .drpen_in(gt_drp_en),
        .drpwe_in(gt_drp_we),
        .drpdo_out(gt_drp_do),
        .drprdy_out(gt_drp_rdy),

        // PLL
        .gtrefclk00_in(xcvr_gtrefclk00_in),
        .qpll0lock_out(xcvr_qpll0lock_out),
        .qpll0outclk_out(xcvr_qpll0clk_out),
        .qpll0outrefclk_out(xcvr_qpll0refclk_out),
        .gtrefclk01_in(xcvr_gtrefclk01_in),
        .qpll1lock_out(xcvr_qpll1lock_out),
        .qpll1outclk_out(xcvr_qpll1clk_out),
        .qpll1outrefclk_out(xcvr_qpll1refclk_out),

        .qpll0pd_in(QPLL0_EXT_CTRL ? xcvr_qpll0pd_in : gt_qpll0_pd),
        .qpll0reset_in(QPLL0_EXT_CTRL ? xcvr_qpll0reset_in : gt_qpll0_reset),
        .qpll1pd_in(QPLL1_EXT_CTRL ? xcvr_qpll1pd_in : gt_qpll1_pd),
        .qpll1reset_in(QPLL1_EXT_CTRL ? xcvr_qpll1reset_in : gt_qpll1_reset),

        .qpllrsvd2_in(QPLL0_EXT_CTRL ? {2'd0, xcvr_qpll0pcierate_in} : 5'd0), // [2:0] : QPLL0 rate
        .qpllrsvd3_in(QPLL1_EXT_CTRL ? {2'd0, xcvr_qpll1pcierate_in} : 5'd0), // [2:0] : QPLL1 rate

        // Serial data
        .gthtxp_out(xcvr_txp),
        .gthtxn_out(xcvr_txn),
        .gthrxp_in(xcvr_rxp),
        .gthrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_clk),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset),
        .txpmareset_in(gt_tx_pma_reset),
        .txpcsreset_in(gt_tx_pcs_reset),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy),

        .txpolarity_in(ctrl_txpolarity),
        .txelecidle_in(ctrl_txelecidle),
        .txinhibit_in(ctrl_txinhibit),
        .txdiffctrl_in(ctrl_txdiffctrl),
        .txmaincursor_in(ctrl_txmaincursor),
        .txprecursor_in(ctrl_txpostcursor),
        .txpostcursor_in(ctrl_txprecursor),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(gt_txsequence),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_clk),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done),
        .rxpd_in(gt_rx_pd ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset),
        .rxpmareset_in(gt_rx_pma_reset),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset),
        .eyescanreset_in(gt_rx_eyescan_reset),
        .rxpcsreset_in(gt_rx_pcs_reset),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy),

        .rxcdrlock_out(gt_rx_cdr_lock),
        .rxcdrhold_in(1'b0),
        .rxcdrovrden_in(1'b0),

        .rxlpmen_in(gt_rx_lpm_en),

        .rxpolarity_in(ctrl_rxpolarity),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

end else if (!HAS_COMMON && GT_TYPE == "GTY") begin : xcvr
    // UltraScale/UltraScale+ GTY (channel only)

    taxi_eth_phy_25g_us_gty_ch
    taxi_eth_phy_25g_us_gty_ch_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drpclk_in(xcvr_ctrl_clk),
        .drpaddr_in(gt_drp_addr),
        .drpdi_in(gt_drp_di),
        .drpen_in(gt_drp_en),
        .drpwe_in(gt_drp_we),
        .drpdo_out(gt_drp_do),
        .drprdy_out(gt_drp_rdy),

        // PLL
        .qpll0clk_in(xcvr_qpll0clk_in),
        .qpll0refclk_in(xcvr_qpll0refclk_in),
        .qpll1clk_in(xcvr_qpll1clk_in),
        .qpll1refclk_in(xcvr_qpll1refclk_in),

        // Serial data
        .gtytxp_out(xcvr_txp),
        .gtytxn_out(xcvr_txn),
        .gtyrxp_in(xcvr_rxp),
        .gtyrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_clk),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset),
        .txpmareset_in(gt_tx_pma_reset),
        .txpcsreset_in(gt_tx_pcs_reset),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy),

        .txpolarity_in(ctrl_txpolarity),
        .txelecidle_in(ctrl_txelecidle),
        .txinhibit_in(ctrl_txinhibit),
        .txdiffctrl_in(ctrl_txdiffctrl),
        .txmaincursor_in(ctrl_txmaincursor),
        .txprecursor_in(ctrl_txpostcursor),
        .txpostcursor_in(ctrl_txprecursor),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(gt_txsequence),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_clk),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done),
        .rxpd_in(gt_rx_pd ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset),
        .rxpmareset_in(gt_rx_pma_reset),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset),
        .eyescanreset_in(gt_rx_eyescan_reset),
        .rxpcsreset_in(gt_rx_pcs_reset),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy),

        .rxcdrlock_out(gt_rx_cdr_lock),
        .rxcdrhold_in(1'b0),
        .rxcdrovrden_in(1'b0),

        .rxlpmen_in(gt_rx_lpm_en),

        .rxpolarity_in(ctrl_rxpolarity),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = 1'b0;
    assign xcvr_qpll0clk_out = 1'b0;
    assign xcvr_qpll0refclk_out = 1'b0;

    assign xcvr_qpll1lock_out = 1'b0;
    assign xcvr_qpll1clk_out = 1'b0;
    assign xcvr_qpll1refclk_out = 1'b0;

    assign com_drp_do = '0;
    assign com_drp_rdy = 1'b1;

end else if (!HAS_COMMON && GT_TYPE == "GTH") begin : xcvr
    // UltraScale/UltraScale+ GTH (channel only)

    taxi_eth_phy_25g_us_gth_ch
    taxi_eth_phy_25g_us_gth_ch_inst (
        // Common
        .gtpowergood_out(xcvr_gtpowergood_out),

        // DRP
        .drpclk_in(xcvr_ctrl_clk),
        .drpaddr_in(gt_drp_addr),
        .drpdi_in(gt_drp_di),
        .drpen_in(gt_drp_en),
        .drpwe_in(gt_drp_we),
        .drpdo_out(gt_drp_do),
        .drprdy_out(gt_drp_rdy),

        // PLL
        .qpll0clk_in(xcvr_qpll0clk_in),
        .qpll0refclk_in(xcvr_qpll0refclk_in),
        .qpll1clk_in(xcvr_qpll1clk_in),
        .qpll1refclk_in(xcvr_qpll1refclk_in),

        // Serial data
        .gthtxp_out(xcvr_txp),
        .gthtxn_out(xcvr_txn),
        .gthrxp_in(xcvr_rxp),
        .gthrxn_in(xcvr_rxn),

        // Transmit
        .gtwiz_userclk_tx_reset_in(gt_tx_reset),
        .gtwiz_userclk_tx_srcclk_out(),
        .gtwiz_userclk_tx_usrclk_out(),
        .gtwiz_userclk_tx_usrclk2_out(tx_clk),
        .gtwiz_userclk_tx_active_out(gt_userclk_tx_active),
        .gtwiz_reset_tx_done_in(tx_reset_done),
        .txpdelecidlemode_in(1'b1),
        .txpd_in(gt_tx_pd ? 2'b11 : 2'b00),
        .gttxreset_in(gt_tx_reset),
        .txpmareset_in(gt_tx_pma_reset),
        .txpcsreset_in(gt_tx_pcs_reset),
        .txresetdone_out(gt_tx_reset_done),
        .txpmaresetdone_out(gt_tx_pma_reset_done),
        .txprogdivreset_in(gt_tx_prgdiv_reset),
        .txprgdivresetdone_out(gt_tx_prgdiv_reset_done),
        .txpllclksel_in(gt_tx_qpll_sel ? 2'b10 : 2'b11),
        .txsysclksel_in(gt_tx_qpll_sel ? 2'b11 : 2'b10),
        .txuserrdy_in(gt_tx_userrdy),

        .txpolarity_in(ctrl_txpolarity),
        .txelecidle_in(ctrl_txelecidle),
        .txinhibit_in(ctrl_txinhibit),
        .txdiffctrl_in(ctrl_txdiffctrl),
        .txmaincursor_in(ctrl_txmaincursor),
        .txprecursor_in(ctrl_txpostcursor),
        .txpostcursor_in(ctrl_txprecursor),

        .gtwiz_userdata_tx_in(gt_txdata),
        .txheader_in(gt_txheader),
        .txsequence_in(gt_txsequence),

        // Receive
        .gtwiz_userclk_rx_reset_in(gt_rx_reset),
        .gtwiz_userclk_rx_srcclk_out(),
        .gtwiz_userclk_rx_usrclk_out(),
        .gtwiz_userclk_rx_usrclk2_out(rx_clk),
        .gtwiz_userclk_rx_active_out(gt_userclk_rx_active),
        .gtwiz_reset_rx_done_in(rx_reset_done),
        .rxpd_in(gt_rx_pd ? 2'b11 : 2'b00),
        .gtrxreset_in(gt_rx_reset),
        .rxpmareset_in(gt_rx_pma_reset),
        .rxdfelpmreset_in(gt_rx_dfe_lpm_reset),
        .eyescanreset_in(gt_rx_eyescan_reset),
        .rxpcsreset_in(gt_rx_pcs_reset),
        .rxresetdone_out(gt_rx_reset_done),
        .rxpmaresetdone_out(gt_rx_pma_reset_done),
        .rxprogdivreset_in(gt_rx_prgdiv_reset),
        .rxprgdivresetdone_out(gt_rx_prgdiv_reset_done),
        .rxpllclksel_in(gt_rx_qpll_sel ? 2'b10 : 2'b11),
        .rxsysclksel_in(gt_rx_qpll_sel ? 2'b11 : 2'b10),
        .rxuserrdy_in(gt_rx_userrdy),

        .rxcdrlock_out(gt_rx_cdr_lock),
        .rxcdrhold_in(1'b0),
        .rxcdrovrden_in(1'b0),

        .rxlpmen_in(gt_rx_lpm_en),

        .rxpolarity_in(ctrl_rxpolarity),

        .rxgearboxslip_in(gt_rxgearboxslip),
        .gtwiz_userdata_rx_out(gt_rxdata),
        .rxdatavalid_out(gt_rxdatavalid),
        .rxheader_out(gt_rxheader),
        .rxheadervalid_out(gt_rxheadervalid),
        .rxstartofseq_out()
    );

    assign xcvr_qpll0lock_out = 1'b0;
    assign xcvr_qpll0clk_out = 1'b0;
    assign xcvr_qpll0refclk_out = 1'b0;

    assign xcvr_qpll1lock_out = 1'b0;
    assign xcvr_qpll1clk_out = 1'b0;
    assign xcvr_qpll1refclk_out = 1'b0;

    assign com_drp_do = '0;
    assign com_drp_rdy = 1'b1;

end else begin

    $fatal(0, "Error: invalid configuration (%m)");

end

endmodule

`resetall
