// SPDX-License-Identifier: MIT
/*

Copyright (c) 2014-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * FPGA core logic
 */
module fpga_core #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtexuplus",
    // 10G/25G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
)
(
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    input  wire logic        clk_125mhz,
    input  wire logic        rst_125mhz,

    /*
     * GPIO
     */
    input  wire logic        btnu,
    input  wire logic        btnl,
    input  wire logic        btnd,
    input  wire logic        btnr,
    input  wire logic        btnc,
    input  wire logic [3:0]  sw,
    output wire logic [7:0]  led,

    /*
     * UART: 115200 bps, 8N1
     */
    input  wire logic        uart_rxd,
    output wire logic        uart_txd,
    input  wire logic        uart_rts,
    output wire logic        uart_cts,

    /*
     * Ethernet: 1000BASE-T SGMII
     */
    input  wire logic        phy_gmii_clk,
    input  wire logic        phy_gmii_rst,
    input  wire logic        phy_gmii_clk_en,
    input  wire logic [7:0]  phy_gmii_rxd,
    input  wire logic        phy_gmii_rx_dv,
    input  wire logic        phy_gmii_rx_er,
    output wire logic [7:0]  phy_gmii_txd,
    output wire logic        phy_gmii_tx_en,
    output wire logic        phy_gmii_tx_er,
    output wire logic        phy_reset_n,
    input  wire logic        phy_int_n,
    input  wire logic        phy_mdio_i,
    output wire logic        phy_mdio_o,
    output wire logic        phy_mdio_t,
    output wire logic        phy_mdc,

    /*
     * Ethernet: QSFP28
     */
    input  wire logic        qsfp1_rx_p[4],
    input  wire logic        qsfp1_rx_n[4],
    output wire logic        qsfp1_tx_p[4],
    output wire logic        qsfp1_tx_n[4],
    input  wire logic        qsfp1_mgt_refclk_0_p,
    input  wire logic        qsfp1_mgt_refclk_0_n,
    // input  wire logic        qsfp1_mgt_refclk_1_p,
    // input  wire logic        qsfp1_mgt_refclk_1_n,
    // output wire logic        qsfp1_recclk_p,
    // output wire logic        qsfp1_recclk_n,
    output wire logic        qsfp1_modsell,
    output wire logic        qsfp1_resetl,
    input  wire logic        qsfp1_modprsl,
    input  wire logic        qsfp1_intl,
    output wire logic        qsfp1_lpmode,

    input  wire logic        qsfp2_rx_p[4],
    input  wire logic        qsfp2_rx_n[4],
    output wire logic        qsfp2_tx_p[4],
    output wire logic        qsfp2_tx_n[4],
    // input  wire logic        qsfp2_mgt_refclk_0_p,
    // input  wire logic        qsfp2_mgt_refclk_0_n,
    // input  wire logic        qsfp2_mgt_refclk_1_p,
    // input  wire logic        qsfp2_mgt_refclk_1_n,
    // output wire logic        qsfp2_recclk_p,
    // output wire logic        qsfp2_recclk_n,
    output wire logic        qsfp2_modsell,
    output wire logic        qsfp2_resetl,
    input  wire logic        qsfp2_modprsl,
    input  wire logic        qsfp2_intl,
    output wire logic        qsfp2_lpmode
);

// assign led = 8'(sw);

// XFCP
taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_ds(), xfcp_us();

taxi_xfcp_if_uart #(
    .TX_FIFO_DEPTH(512),
    .RX_FIFO_DEPTH(512)
)
xfcp_if_uart_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * UART interface
     */
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd),

    /*
     * XFCP downstream interface
     */
    .xfcp_dsp_ds(xfcp_ds),
    .xfcp_dsp_us(xfcp_us),

    /*
     * Configuration
     */
    .prescale(16'(125000000/921600))
);

localparam XFCP_PORTS = 1+2;

taxi_axis_if #(.DATA_W(8), .USER_EN(1), .USER_W(1)) xfcp_sw_ds[XFCP_PORTS](), xfcp_sw_us[XFCP_PORTS]();

taxi_xfcp_switch #(
    .XFCP_ID_STR("VCU118"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR("Taxi example"),
    .PORTS($size(xfcp_sw_us))
)
xfcp_sw_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_ds),
    .xfcp_usp_us(xfcp_us),

    /*
     * XFCP downstream ports
     */
    .xfcp_dsp_ds(xfcp_sw_ds),
    .xfcp_dsp_us(xfcp_sw_us)
);

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_stat();

taxi_xfcp_mod_stats #(
    .XFCP_ID_STR("Statistics"),
    .XFCP_EXT_ID(0),
    .XFCP_EXT_ID_STR(""),
    .STAT_COUNT_W(64),
    .STAT_PIPELINE(2)
)
xfcp_stats_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * XFCP upstream port
     */
    .xfcp_usp_ds(xfcp_sw_ds[0]),
    .xfcp_usp_us(xfcp_sw_us[0]),

    /*
     * Statistics increment input
     */
    .s_axis_stat(axis_stat)
);

taxi_axis_if #(.DATA_W(16), .KEEP_W(1), .KEEP_EN(0), .LAST_EN(0), .USER_EN(1), .USER_W(1), .ID_EN(1), .ID_W(10)) axis_eth_stat[3]();

taxi_axis_arb_mux #(
    .S_COUNT($size(axis_eth_stat)),
    .UPDATE_TID(1'b0),
    .ARB_ROUND_ROBIN(1'b1),
    .ARB_LSB_HIGH_PRIO(1'b0)
)
stat_mux_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    /*
     * AXI4-Stream inputs (sink)
     */
    .s_axis(axis_eth_stat),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(axis_stat)
);

// BASE-T PHY
assign phy_reset_n = !rst_125mhz;

taxi_axis_if #(.DATA_W(8), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_eth();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_tx_cpl();

taxi_eth_mac_1g_fifo #(
    .PADDING_EN(1),
    .MIN_FRAME_LEN(64),
    .STAT_EN(1),
    .STAT_TX_LEVEL(1),
    .STAT_RX_LEVEL(1),
    .STAT_ID_BASE(0),
    .STAT_UPDATE_PERIOD(1024),
    .STAT_STR_EN(1),
    .STAT_PREFIX_STR("SGMII0"),
    .TX_FIFO_DEPTH(16384),
    .TX_FRAME_FIFO(1),
    .RX_FIFO_DEPTH(16384),
    .RX_FRAME_FIFO(1)
)
eth_mac_inst (
    .rx_clk(phy_gmii_clk),
    .rx_rst(phy_gmii_rst),
    .tx_clk(phy_gmii_clk),
    .tx_rst(phy_gmii_rst),
    .logic_clk(clk_125mhz),
    .logic_rst(rst_125mhz),

    /*
     * Transmit interface (AXI stream)
     */
    .s_axis_tx(axis_eth),
    .m_axis_tx_cpl(axis_tx_cpl),

    /*
     * Receive interface (AXI stream)
     */
    .m_axis_rx(axis_eth),

    /*
     * GMII interface
     */
    .gmii_rxd(phy_gmii_rxd),
    .gmii_rx_dv(phy_gmii_rx_dv),
    .gmii_rx_er(phy_gmii_rx_er),
    .gmii_txd(phy_gmii_txd),
    .gmii_tx_en(phy_gmii_tx_en),
    .gmii_tx_er(phy_gmii_tx_er),

    /*
     * Control
     */
    .rx_clk_enable(phy_gmii_clk_en),
    .tx_clk_enable(phy_gmii_clk_en),
    .rx_mii_select(1'b0),
    .tx_mii_select(1'b0),

    /*
     * Statistics
     */
    .stat_clk(clk_125mhz),
    .stat_rst(rst_125mhz),
    .m_axis_stat(axis_eth_stat[0]),

    /*
     * Status
     */
    .tx_error_underflow(),
    .tx_fifo_overflow(),
    .tx_fifo_bad_frame(),
    .tx_fifo_good_frame(),
    .rx_error_bad_frame(),
    .rx_error_bad_fcs(),
    .rx_fifo_overflow(),
    .rx_fifo_bad_frame(),
    .rx_fifo_good_frame(),

    /*
     * Configuration
     */
    .cfg_tx_max_pkt_len(16'd9218),
    .cfg_tx_ifg(8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_max_pkt_len(16'd9218),
    .cfg_rx_enable(1'b1)
);

// PHY MDIO init
reg [19:0] delay_reg = '1;

reg [1:0] mdio_cmd_st_reg = 2'b01; // clause 22
reg [1:0] mdio_cmd_op_reg = 2'b01; // write
reg [4:0] mdio_cmd_phy_addr_reg = 5'h03;
reg [4:0] mdio_cmd_reg_addr_reg = 5'h00;
reg [15:0] mdio_cmd_data_reg = '0;
reg mdio_cmd_valid_reg = 1'b0;
wire mdio_cmd_ready;

taxi_axis_if #(.DATA_W(32)) axis_mdio_cmd();
taxi_axis_if #(.DATA_W(16)) axis_mdio_rd_data();

assign axis_mdio_cmd.tdata = {mdio_cmd_st_reg, mdio_cmd_op_reg, mdio_cmd_phy_addr_reg, mdio_cmd_reg_addr_reg, 2'b10, mdio_cmd_data_reg};
assign axis_mdio_cmd.tvalid = mdio_cmd_valid_reg;
assign mdio_cmd_ready = axis_mdio_cmd.tready;

assign axis_mdio_rd_data.tready = 1'b1;

reg [3:0] state_reg = '0;

always_ff @(posedge clk_125mhz) begin
    mdio_cmd_valid_reg <= mdio_cmd_valid_reg && !mdio_cmd_ready;

    if (delay_reg != 0) begin
        delay_reg <= delay_reg - 1;
    end else if (mdio_cmd_valid_reg) begin
        // wait for ready
        state_reg <= state_reg;
    end else begin
        case (state_reg)
            // set SGMII autonegotiation timer to 11 ms
            // write 0x0070 to CFG4 (0x0031)
            4'd0: begin
                // write to REGCR to load address
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h001F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd1;
            end
            4'd1: begin
                // write address of CFG4 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h0031;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd2;
            end
            4'd2: begin
                // write to REGCR to load data
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h401F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd3;
            end
            4'd3: begin
                // write data for CFG4 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h0070;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd4;
            end
            // enable SGMII clock output
            // write 0x4000 to SGMIICTL1 (0x00D3)
            4'd4: begin
                // write to REGCR to load address
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h001F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd5;
            end
            4'd5: begin
                // write address of SGMIICTL1 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h00D3;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd6;
            end
            4'd6: begin
                // write to REGCR to load data
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h401F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd7;
            end
            4'd7: begin
                // write data for SGMIICTL1 to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h4000;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd8;
            end
            // enable 10Mbps operation
            // write 0x0015 to 10M_SGMII_CFG (0x016F)
            4'd8: begin
                // write to REGCR to load address
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h001F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd9;
            end
            4'd9: begin
                // write address of 10M_SGMII_CFG to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h016F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd10;
            end
            4'd10: begin
                // write to REGCR to load data
                mdio_cmd_reg_addr_reg <= 5'h0D;
                mdio_cmd_data_reg <= 16'h401F;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd11;
            end
            4'd11: begin
                // write data for 10M_SGMII_CFG to ADDAR
                mdio_cmd_reg_addr_reg <= 5'h0E;
                mdio_cmd_data_reg <= 16'h0015;
                mdio_cmd_valid_reg <= 1'b1;
                state_reg <= 4'd12;
            end
            4'd12: begin
                // done
                state_reg <= 4'd12;
            end
            default: begin
                // go to idle
                state_reg <= 4'd0;
            end
        endcase
    end

    if (rst_125mhz) begin
        state_reg <= '0;
        delay_reg <= SIM ? 100 : '1;
        mdio_cmd_valid_reg <= 1'b0;
    end
end

taxi_mdio_master
mdio_master_inst (
    .clk(clk_125mhz),
    .rst(rst_125mhz),

    .s_axis_cmd(axis_mdio_cmd),
    .m_axis_rd_data(axis_mdio_rd_data),

    .mdc_o(phy_mdc),
    .mdio_i(phy_mdio_i),
    .mdio_o(phy_mdio_o),
    .mdio_t(phy_mdio_t),

    .busy(),

    // The TI DP83867IS PHY chip supports an MDC frequency of 25 MHz
    .prescale(8'(125/25/2))
);

// QSFP28
assign qsfp1_modsell = 1'b0;
assign qsfp1_resetl = 1'b1;
assign qsfp1_lpmode = 1'b0;
assign qsfp2_modsell = 1'b0;
assign qsfp2_resetl = 1'b1;
assign qsfp2_lpmode = 1'b0;

wire qsfp_tx_clk[8];
wire qsfp_tx_rst[8];
wire qsfp_rx_clk[8];
wire qsfp_rx_rst[8];

wire qsfp_rx_status[8];

for (genvar n = 0; n < 8; n = n + 1) begin
    assign led[n] = qsfp_rx_status[n];
end

wire [1:0] qsfp_gtpowergood;

wire qsfp1_mgt_refclk_0;
wire qsfp1_mgt_refclk_0_int;
wire qsfp1_mgt_refclk_0_bufg;

wire qsfp_rst;

taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_qsfp_tx[8]();
taxi_axis_if #(.DATA_W(96), .KEEP_W(1), .ID_W(8)) axis_qsfp_tx_cpl[8]();
taxi_axis_if #(.DATA_W(MAC_DATA_W), .ID_W(8), .USER_EN(1), .USER_W(1)) axis_qsfp_rx[8]();

if (SIM) begin

    assign qsfp1_mgt_refclk_0 = qsfp1_mgt_refclk_0_p;
    assign qsfp1_mgt_refclk_0_int = qsfp1_mgt_refclk_0_p;
    assign qsfp1_mgt_refclk_0_bufg = qsfp1_mgt_refclk_0_int;

end else begin

    IBUFDS_GTE4 ibufds_gte4_qsfp1_mgt_refclk_0_inst (
        .I     (qsfp1_mgt_refclk_0_p),
        .IB    (qsfp1_mgt_refclk_0_n),
        .CEB   (1'b0),
        .O     (qsfp1_mgt_refclk_0),
        .ODIV2 (qsfp1_mgt_refclk_0_int)
    );

    BUFG_GT bufg_gt_qsfp1_mgt_refclk_0_inst (
        .CE      (&qsfp_gtpowergood),
        .CEMASK  (1'b1),
        .CLR     (1'b0),
        .CLRMASK (1'b1),
        .DIV     (3'd0),
        .I       (qsfp1_mgt_refclk_0_int),
        .O       (qsfp1_mgt_refclk_0_bufg)
    );

end

taxi_sync_reset #(
    .N(4)
)
qsfp_sync_reset_inst (
    .clk(qsfp1_mgt_refclk_0_bufg),
    .rst(rst_125mhz),
    .out(qsfp_rst)
);

wire qsfp_tx_p[8];
wire qsfp_tx_n[8];
wire qsfp_rx_p[8];
wire qsfp_rx_n[8];

assign qsfp1_tx_p = qsfp_tx_p[4*0 +: 4];
assign qsfp1_tx_n = qsfp_tx_n[4*0 +: 4];
assign qsfp2_tx_p = qsfp_tx_p[4*1 +: 4];
assign qsfp2_tx_n = qsfp_tx_n[4*1 +: 4];

assign qsfp_rx_p[4*0 +: 4] = qsfp1_rx_p;
assign qsfp_rx_n[4*0 +: 4] = qsfp1_rx_n;
assign qsfp_rx_p[4*1 +: 4] = qsfp2_rx_p;
assign qsfp_rx_n[4*1 +: 4] = qsfp2_rx_n;


localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP1[4] = '{"QSFP1.1", "QSFP1.2", "QSFP1.3",  "QSFP1.4"};
localparam logic [8*8-1:0] STAT_PREFIX_STR_QSFP2[4] = '{"QSFP2.1", "QSFP2.2", "QSFP2.3",  "QSFP2.4"};

for (genvar n = 0; n < 2; n = n + 1) begin : gt_quad

    localparam CNT = 4;

    taxi_apb_if #(
        .ADDR_W(18),
        .DATA_W(16)
    )
    gt_apb_ctrl();

    taxi_xfcp_mod_apb #(
        .XFCP_EXT_ID_STR("GTY CTRL")
    )
    xfcp_mod_apb_inst (
        .clk(clk_125mhz),
        .rst(rst_125mhz),

        /*
         * XFCP upstream port
         */
        .xfcp_usp_ds(xfcp_sw_ds[n+1]),
        .xfcp_usp_us(xfcp_sw_us[n+1]),

        /*
         * APB master interface
         */
        .m_apb(gt_apb_ctrl)
    );

    taxi_eth_mac_25g_us #(
        .SIM(SIM),
        .VENDOR(VENDOR),
        .FAMILY(FAMILY),

        .CNT(4),

        // GT config
        .CFG_LOW_LATENCY(CFG_LOW_LATENCY),

        // GT type
        .GT_TYPE("GTY"),

        // MAC/PHY config
        .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
        .DATA_W(MAC_DATA_W),
        .PADDING_EN(1'b1),
        .DIC_EN(1'b1),
        .MIN_FRAME_LEN(64),
        .PTP_TS_EN(1'b0),
        .PTP_TD_EN(1'b0),
        .PTP_TS_FMT_TOD(1'b1),
        .PTP_TS_W(96),
        .PTP_TD_SDI_PIPELINE(2),
        .PRBS31_EN(1'b0),
        .TX_SERDES_PIPELINE(1),
        .RX_SERDES_PIPELINE(1),
        .COUNT_125US(125000/6.4),
        .STAT_EN(1),
        .STAT_TX_LEVEL(1),
        .STAT_RX_LEVEL(1),
        .STAT_ID_BASE((16+16)+n*CNT*(16+16)),
        .STAT_UPDATE_PERIOD(1024),
        .STAT_STR_EN(1),
        .STAT_PREFIX_STR(n == 0 ? STAT_PREFIX_STR_QSFP1 : STAT_PREFIX_STR_QSFP2)
    )
    mac_inst (
        .xcvr_ctrl_clk(clk_125mhz),
        .xcvr_ctrl_rst(qsfp_rst),

        /*
         * Transceiver control
         */
        .s_apb_ctrl(gt_apb_ctrl),

        /*
         * Common
         */
        .xcvr_gtpowergood_out(qsfp_gtpowergood[n]),
        .xcvr_gtrefclk00_in(qsfp1_mgt_refclk_0),
        .xcvr_qpll0pd_in(1'b0),
        .xcvr_qpll0reset_in(1'b0),
        .xcvr_qpll0pcierate_in(3'd0),
        .xcvr_qpll0lock_out(),
        .xcvr_qpll0clk_out(),
        .xcvr_qpll0refclk_out(),
        .xcvr_gtrefclk01_in(qsfp1_mgt_refclk_0),
        .xcvr_qpll1pd_in(1'b0),
        .xcvr_qpll1reset_in(1'b0),
        .xcvr_qpll1pcierate_in(3'd0),
        .xcvr_qpll1lock_out(),
        .xcvr_qpll1clk_out(),
        .xcvr_qpll1refclk_out(),

        /*
         * Serial data
         */
        .xcvr_txp(qsfp_tx_p[n*CNT +: CNT]),
        .xcvr_txn(qsfp_tx_n[n*CNT +: CNT]),
        .xcvr_rxp(qsfp_rx_p[n*CNT +: CNT]),
        .xcvr_rxn(qsfp_rx_n[n*CNT +: CNT]),

        /*
         * MAC clocks
         */
        .rx_clk(qsfp_rx_clk[n*CNT +: CNT]),
        .rx_rst_in('{CNT{1'b0}}),
        .rx_rst_out(qsfp_rx_rst[n*CNT +: CNT]),
        .tx_clk(qsfp_tx_clk[n*CNT +: CNT]),
        .tx_rst_in('{CNT{1'b0}}),
        .tx_rst_out(qsfp_tx_rst[n*CNT +: CNT]),

        /*
         * Transmit interface (AXI stream)
         */
        .s_axis_tx(axis_qsfp_tx[n*CNT +: CNT]),
        .m_axis_tx_cpl(axis_qsfp_tx_cpl[n*CNT +: CNT]),

        /*
         * Receive interface (AXI stream)
         */
        .m_axis_rx(axis_qsfp_rx[n*CNT +: CNT]),

        /*
         * PTP clock
         */
        .ptp_clk(1'b0),
        .ptp_rst(1'b0),
        .ptp_sample_clk(1'b0),
        .ptp_td_sdi(1'b0),
        .tx_ptp_ts_in('{CNT{'0}}),
        .tx_ptp_ts_out(),
        .tx_ptp_ts_step_out(),
        .tx_ptp_locked(),
        .rx_ptp_ts_in('{CNT{'0}}),
        .rx_ptp_ts_out(),
        .rx_ptp_ts_step_out(),
        .rx_ptp_locked(),

        /*
         * Link-level Flow Control (LFC) (IEEE 802.3 annex 31B PAUSE)
         */
        .tx_lfc_req('{CNT{1'b0}}),
        .tx_lfc_resend('{CNT{1'b0}}),
        .rx_lfc_en('{CNT{1'b0}}),
        .rx_lfc_req(),
        .rx_lfc_ack('{CNT{1'b0}}),

        /*
         * Priority Flow Control (PFC) (IEEE 802.3 annex 31D PFC)
         */
        .tx_pfc_req('{CNT{'0}}),
        .tx_pfc_resend('{CNT{1'b0}}),
        .rx_pfc_en('{CNT{'0}}),
        .rx_pfc_req(),
        .rx_pfc_ack('{CNT{'0}}),

        /*
         * Pause interface
         */
        .tx_lfc_pause_en('{CNT{1'b0}}),
        .tx_pause_req('{CNT{1'b0}}),
        .tx_pause_ack(),

        /*
         * Statistics
         */
        .stat_clk(clk_125mhz),
        .stat_rst(rst_125mhz),
        .m_axis_stat(axis_eth_stat[n+1]),

        /*
         * Status
         */
        .tx_start_packet(),
        .stat_tx_byte(),
        .stat_tx_pkt_len(),
        .stat_tx_pkt_ucast(),
        .stat_tx_pkt_mcast(),
        .stat_tx_pkt_bcast(),
        .stat_tx_pkt_vlan(),
        .stat_tx_pkt_good(),
        .stat_tx_pkt_bad(),
        .stat_tx_err_oversize(),
        .stat_tx_err_user(),
        .stat_tx_err_underflow(),
        .rx_start_packet(),
        .rx_error_count(),
        .rx_block_lock(),
        .rx_high_ber(),
        .rx_status(qsfp_rx_status[n*CNT +: CNT]),
        .stat_rx_byte(),
        .stat_rx_pkt_len(),
        .stat_rx_pkt_fragment(),
        .stat_rx_pkt_jabber(),
        .stat_rx_pkt_ucast(),
        .stat_rx_pkt_mcast(),
        .stat_rx_pkt_bcast(),
        .stat_rx_pkt_vlan(),
        .stat_rx_pkt_good(),
        .stat_rx_pkt_bad(),
        .stat_rx_err_oversize(),
        .stat_rx_err_bad_fcs(),
        .stat_rx_err_bad_block(),
        .stat_rx_err_framing(),
        .stat_rx_err_preamble(),
        .stat_rx_fifo_drop('{CNT{1'b0}}),
        .stat_tx_mcf(),
        .stat_rx_mcf(),
        .stat_tx_lfc_pkt(),
        .stat_tx_lfc_xon(),
        .stat_tx_lfc_xoff(),
        .stat_tx_lfc_paused(),
        .stat_tx_pfc_pkt(),
        .stat_tx_pfc_xon(),
        .stat_tx_pfc_xoff(),
        .stat_tx_pfc_paused(),
        .stat_rx_lfc_pkt(),
        .stat_rx_lfc_xon(),
        .stat_rx_lfc_xoff(),
        .stat_rx_lfc_paused(),
        .stat_rx_pfc_pkt(),
        .stat_rx_pfc_xon(),
        .stat_rx_pfc_xoff(),
        .stat_rx_pfc_paused(),

        /*
         * Configuration
         */
        .cfg_tx_max_pkt_len('{CNT{16'd9218}}),
        .cfg_tx_ifg('{CNT{8'd12}}),
        .cfg_tx_enable('{CNT{1'b1}}),
        .cfg_rx_max_pkt_len('{CNT{16'd9218}}),
        .cfg_rx_enable('{CNT{1'b1}}),
        .cfg_tx_prbs31_enable('{CNT{1'b0}}),
        .cfg_rx_prbs31_enable('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_dst_mcast('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_mcf_rx_check_eth_dst_mcast('{CNT{1'b1}}),
        .cfg_mcf_rx_eth_dst_ucast('{CNT{48'd0}}),
        .cfg_mcf_rx_check_eth_dst_ucast('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_src('{CNT{48'd0}}),
        .cfg_mcf_rx_check_eth_src('{CNT{1'b0}}),
        .cfg_mcf_rx_eth_type('{CNT{16'h8808}}),
        .cfg_mcf_rx_opcode_lfc('{CNT{16'h0001}}),
        .cfg_mcf_rx_check_opcode_lfc('{CNT{1'b1}}),
        .cfg_mcf_rx_opcode_pfc('{CNT{16'h0101}}),
        .cfg_mcf_rx_check_opcode_pfc('{CNT{1'b1}}),
        .cfg_mcf_rx_forward('{CNT{1'b0}}),
        .cfg_mcf_rx_enable('{CNT{1'b0}}),
        .cfg_tx_lfc_eth_dst('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_tx_lfc_eth_src('{CNT{48'h80_23_31_43_54_4C}}),
        .cfg_tx_lfc_eth_type('{CNT{16'h8808}}),
        .cfg_tx_lfc_opcode('{CNT{16'h0001}}),
        .cfg_tx_lfc_en('{CNT{1'b0}}),
        .cfg_tx_lfc_quanta('{CNT{16'hffff}}),
        .cfg_tx_lfc_refresh('{CNT{16'h7fff}}),
        .cfg_tx_pfc_eth_dst('{CNT{48'h01_80_C2_00_00_01}}),
        .cfg_tx_pfc_eth_src('{CNT{48'h80_23_31_43_54_4C}}),
        .cfg_tx_pfc_eth_type('{CNT{16'h8808}}),
        .cfg_tx_pfc_opcode('{CNT{16'h0101}}),
        .cfg_tx_pfc_en('{CNT{1'b0}}),
        .cfg_tx_pfc_quanta('{CNT{'{8{16'hffff}}}}),
        .cfg_tx_pfc_refresh('{CNT{'{8{16'h7fff}}}}),
        .cfg_rx_lfc_opcode('{CNT{16'h0001}}),
        .cfg_rx_lfc_en('{CNT{1'b0}}),
        .cfg_rx_pfc_opcode('{CNT{16'h0101}}),
        .cfg_rx_pfc_en('{CNT{1'b0}})
    );

end

for (genvar n = 0; n < 8; n = n + 1) begin : qsfp_ch

    taxi_axis_async_fifo #(
        .DEPTH(16384),
        .RAM_PIPELINE(2),
        .FRAME_FIFO(1),
        .USER_BAD_FRAME_VALUE(1'b1),
        .USER_BAD_FRAME_MASK(1'b1),
        .DROP_OVERSIZE_FRAME(1),
        .DROP_BAD_FRAME(1),
        .DROP_WHEN_FULL(1)
    )
    ch_fifo (
        /*
         * AXI4-Stream input (sink)
         */
        .s_clk(qsfp_rx_clk[n]),
        .s_rst(qsfp_rx_rst[n]),
        .s_axis(axis_qsfp_rx[n]),

        /*
         * AXI4-Stream output (source)
         */
        .m_clk(qsfp_tx_clk[n]),
        .m_rst(qsfp_tx_rst[n]),
        .m_axis(axis_qsfp_tx[n]),

        /*
         * Pause
         */
        .s_pause_req(1'b0),
        .s_pause_ack(),
        .m_pause_req(1'b0),
        .m_pause_ack(),

        /*
         * Status
         */
        .s_status_depth(),
        .s_status_depth_commit(),
        .s_status_overflow(),
        .s_status_bad_frame(),
        .s_status_good_frame(),
        .m_status_depth(),
        .m_status_depth_commit(),
        .m_status_overflow(),
        .m_status_bad_frame(),
        .m_status_good_frame()
    );

end

endmodule

`resetall
