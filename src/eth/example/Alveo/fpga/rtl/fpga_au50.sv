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
 * FPGA top-level module
 */
module fpga #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA")
    parameter string VENDOR = "XILINX",
    // device family
    parameter string FAMILY = "virtexuplus",
    // Board configuration
    parameter QSFP_CNT = 1,
    parameter UART_CNT = 3,
    // 10G/25G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
)
(
    /*
     * GPIO
     */
    output wire logic [QSFP_CNT-1:0]  qsfp_led_act,
    output wire logic [QSFP_CNT-1:0]  qsfp_led_stat_g,
    output wire logic [QSFP_CNT-1:0]  qsfp_led_stat_y,
    output wire logic                 hbm_cattrip,

    /*
     * UART
     */
    output wire logic                 uart_txd[UART_CNT],
    input  wire logic                 uart_rxd[UART_CNT],

    /*
     * Ethernet: QSFP28
     */
    output wire logic                 qsfp_tx_p[4],
    output wire logic                 qsfp_tx_n[4],
    input  wire logic                 qsfp_rx_p[4],
    input  wire logic                 qsfp_rx_n[4],
    input  wire logic                 qsfp_mgt_refclk_0_p,
    input  wire logic                 qsfp_mgt_refclk_0_n
    // input  wire logic                 qsfp_mgt_refclk_1_p,
    // input  wire logic                 qsfp_mgt_refclk_1_n
);

// Clock and reset

wire clk_161mhz_ref_int;

// Internal 125 MHz clock
wire clk_125mhz_mmcm_out;
wire clk_125mhz_int;
wire rst_125mhz_int;

wire mmcm_rst = 1'b0;
wire mmcm_locked;
wire mmcm_clkfb;

// MMCM instance
MMCME4_BASE #(
    // 161.13 MHz input
    .CLKIN1_PERIOD(6.206),
    .REF_JITTER1(0.010),
    // 161.13 MHz input / 11 = 14.65 MHz PFD (range 10 MHz to 500 MHz)
    .DIVCLK_DIVIDE(11),
    // 14.65 MHz PFD * 64 = 937.5 MHz VCO (range 800 MHz to 1600 MHz)
    .CLKFBOUT_MULT_F(64),
    .CLKFBOUT_PHASE(0),
    // 937.5 MHz / 7.5 = 125 MHz, 0 degrees
    .CLKOUT0_DIVIDE_F(7.5),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    // Not used
    .CLKOUT1_DIVIDE(1),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0),
    // Not used
    .CLKOUT2_DIVIDE(1),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    // Not used
    .CLKOUT3_DIVIDE(1),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0),
    // Not used
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0),
    .CLKOUT4_CASCADE("FALSE"),
    // Not used
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0),
    // Not used
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT6_PHASE(0),

    // optimized bandwidth
    .BANDWIDTH("OPTIMIZED"),
    // don't wait for lock during startup
    .STARTUP_WAIT("FALSE")
)
clk_mmcm_inst (
    // 161.13 MHz input
    .CLKIN1(clk_161mhz_ref_int),
    // direct clkfb feeback
    .CLKFBIN(mmcm_clkfb),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    // 125 MHz, 0 degrees
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    // Not used
    .CLKOUT1(),
    .CLKOUT1B(),
    // Not used
    .CLKOUT2(),
    .CLKOUT2B(),
    // Not used
    .CLKOUT3(),
    .CLKOUT3B(),
    // Not used
    .CLKOUT4(),
    // Not used
    .CLKOUT5(),
    // Not used
    .CLKOUT6(),
    // reset input
    .RST(mmcm_rst),
    // don't power down
    .PWRDWN(1'b0),
    // locked output
    .LOCKED(mmcm_locked)
);

BUFG
clk_125mhz_bufg_inst (
    .I(clk_125mhz_mmcm_out),
    .O(clk_125mhz_int)
);

taxi_sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

// GPIO
assign hbm_cattrip = 1'b0;

localparam PORT_CNT = QSFP_CNT;
localparam GTY_QUAD_CNT = PORT_CNT;
localparam GTY_CNT = GTY_QUAD_CNT*4;
localparam GTY_CLK_CNT = GTY_QUAD_CNT;

wire eth_gty_tx_p[GTY_CNT];
wire eth_gty_tx_n[GTY_CNT];
wire eth_gty_rx_p[GTY_CNT];
wire eth_gty_rx_n[GTY_CNT];
wire eth_gty_mgt_refclk_p[GTY_CLK_CNT];
wire eth_gty_mgt_refclk_n[GTY_CLK_CNT];
wire eth_gty_mgt_refclk_out[GTY_CLK_CNT];

assign qsfp_tx_p = eth_gty_tx_p[4*0 +: 4];
assign qsfp_tx_n = eth_gty_tx_n[4*0 +: 4];
assign eth_gty_rx_p[4*0 +: 4] = qsfp_rx_p;
assign eth_gty_rx_n[4*0 +: 4] = qsfp_rx_n;

assign eth_gty_mgt_refclk_p[0] = qsfp_mgt_refclk_0_p;
assign eth_gty_mgt_refclk_n[0] = qsfp_mgt_refclk_0_n;

assign clk_161mhz_ref_int = eth_gty_mgt_refclk_out[0];

fpga_core #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .SW_CNT(4),
    .LED_CNT(3),
    .UART_CNT(UART_CNT),
    .PORT_CNT(PORT_CNT),
    .GTY_QUAD_CNT(GTY_QUAD_CNT),
    .GTY_CNT(GTY_CNT),
    .GTY_CLK_CNT(GTY_CLK_CNT),
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),
    .COMBINED_MAC_PCS(COMBINED_MAC_PCS),
    .MAC_DATA_W(MAC_DATA_W)
)
core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk_125mhz(clk_125mhz_int),
    .rst_125mhz(rst_125mhz_int),

    /*
     * GPIO
     */
    .sw('0),
    .led(),
    .port_led_act(qsfp_led_act),
    .port_led_stat_r(),
    .port_led_stat_g(qsfp_led_stat_g),
    .port_led_stat_b(),
    .port_led_stat_y(qsfp_led_stat_y),

    /*
     * UART
     */
    .uart_txd(uart_txd),
    .uart_rxd(uart_rxd),

    /*
     * Ethernet
     */
    .eth_gty_tx_p(eth_gty_tx_p),
    .eth_gty_tx_n(eth_gty_tx_n),
    .eth_gty_rx_p(eth_gty_rx_p),
    .eth_gty_rx_n(eth_gty_rx_n),
    .eth_gty_mgt_refclk_p(eth_gty_mgt_refclk_p),
    .eth_gty_mgt_refclk_n(eth_gty_mgt_refclk_n),
    .eth_gty_mgt_refclk_out(eth_gty_mgt_refclk_out),

    .eth_port_modsell(),
    .eth_port_resetl(),
    .eth_port_modprsl('0),
    .eth_port_intl('0),
    .eth_port_lpmode()
);

endmodule

`resetall
