// SPDX-License-Identifier: MIT
/*

Copyright (c) 2014-2026 FPGA Ninja, LLC

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
    parameter string FAMILY = "virtexu",
    // 10G/25G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1,
    parameter MAC_DATA_W = 64
)
(
    /*
     * Clock: 50MHz
     */
    input  wire logic         clk_50mhz,

    /*
     * GPIO
     */
    output wire logic [3:0]   led,
    output wire logic [3:0]   qsfp_led[2],
    output wire logic         led_red,
    output wire logic         led_green,
    output wire logic [1:0]   led_sync,
    output wire logic         eth_led_yellow,
    output wire logic         eth_led_green,

    /*
     * I2C
     */
    inout  wire logic         si5340_i2c_scl,
    inout  wire logic         si5340_i2c_sda,
    input  wire logic         si5340_intr,

    /*
     * Ethernet: QSFP28
     */
    output wire logic         qsfp0_tx_p[4],
    output wire logic         qsfp0_tx_n[4],
    input  wire logic         qsfp0_rx_p[4],
    input  wire logic         qsfp0_rx_n[4],
    input  wire logic         qsfp0_mgt_refclk_p,
    input  wire logic         qsfp0_mgt_refclk_n,
    output wire logic         qsfp0_resetl,
    input  wire logic         qsfp0_modprsl,
    input  wire logic         qsfp0_intl,
    output wire logic         qsfp0_lpmode,
    inout  wire logic         qsfp0_i2c_scl,
    inout  wire logic         qsfp0_i2c_sda,

    output wire logic         qsfp1_tx_p[4],
    output wire logic         qsfp1_tx_n[4],
    input  wire logic         qsfp1_rx_p[4],
    input  wire logic         qsfp1_rx_n[4],
    input  wire logic         qsfp1_mgt_refclk_p,
    input  wire logic         qsfp1_mgt_refclk_n,
    output wire logic         qsfp1_resetl,
    input  wire logic         qsfp1_modprsl,
    input  wire logic         qsfp1_intl,
    output wire logic         qsfp1_lpmode,
    inout  wire logic         qsfp1_i2c_scl,
    inout  wire logic         qsfp1_i2c_sda
);

// Clock and reset

wire clk_125mhz_mmcm_out;

// Internal 125 MHz clock
wire clk_125mhz_int;
wire rst_125mhz_int;

wire mmcm_rst = 1'b0;
wire mmcm_locked;
wire mmcm_clkfb;

// MMCM instance
MMCME3_BASE #(
    // 50 MHz input
    .CLKIN1_PERIOD(20.000),
    .REF_JITTER1(0.010),
    // 50 MHz input / 1 = 50 MHz PFD (range 10 MHz to 500 MHz)
    .DIVCLK_DIVIDE(1),
    // 50 MHz PFD * 20 = 1000 MHz VCO (range 600 MHz to 1440 MHz)
    .CLKFBOUT_MULT_F(20),
    .CLKFBOUT_PHASE(0),
    // 1000 MHz / 8 = 125 MHz, 0 degrees
    .CLKOUT0_DIVIDE_F(8),
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
    // 50 MHz input
    .CLKIN1(clk_50mhz),
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
wire qsfp0_modprsl_int;
wire qsfp0_intl_int;
wire qsfp0_i2c_scl_i;
wire qsfp0_i2c_scl_o;
wire qsfp0_i2c_sda_i;
wire qsfp0_i2c_sda_o;

wire qsfp1_modprsl_int;
wire qsfp1_intl_int;
wire qsfp1_i2c_scl_i;
wire qsfp1_i2c_scl_o;
wire qsfp1_i2c_sda_i;
wire qsfp1_i2c_sda_o;

logic qsfp0_i2c_scl_o_reg;
logic qsfp0_i2c_sda_o_reg;

logic qsfp1_i2c_scl_o_reg;
logic qsfp1_i2c_sda_o_reg;

always_ff @(posedge clk_125mhz_int) begin
    qsfp0_i2c_scl_o_reg <= qsfp0_i2c_scl_o;
    qsfp0_i2c_sda_o_reg <= qsfp0_i2c_sda_o;

    qsfp1_i2c_scl_o_reg <= qsfp1_i2c_scl_o;
    qsfp1_i2c_sda_o_reg <= qsfp1_i2c_sda_o;
end

taxi_sync_signal #(
    .WIDTH(8),
    .N(2)
)
sync_signal_inst (
    .clk(clk_125mhz_int),
    .in({qsfp0_modprsl, qsfp0_intl, qsfp0_i2c_scl, qsfp0_i2c_sda,
        qsfp1_modprsl, qsfp1_intl, qsfp1_i2c_scl, qsfp1_i2c_sda}),
    .out({qsfp0_modprsl_int, qsfp0_intl_int, qsfp0_i2c_scl_i, qsfp0_i2c_sda_i,
        qsfp1_modprsl_int, qsfp1_intl_int, qsfp1_i2c_scl_i, qsfp1_i2c_sda_i})
);

assign qsfp0_i2c_scl = qsfp0_i2c_scl_o_reg ? 1'bz : 1'b0;
assign qsfp0_i2c_sda = qsfp0_i2c_sda_o_reg ? 1'bz : 1'b0;

assign qsfp1_i2c_scl = qsfp1_i2c_scl_o_reg ? 1'bz : 1'b0;
assign qsfp1_i2c_sda = qsfp1_i2c_sda_o_reg ? 1'bz : 1'b0;

// I2C
wire si5340_i2c_scl_i;
wire si5340_i2c_scl_o;
wire si5340_i2c_sda_i;
wire si5340_i2c_sda_o;

assign si5340_i2c_scl_i = si5340_i2c_scl;
assign si5340_i2c_scl = si5340_i2c_scl_o ? 1'bz : 1'b0;
assign si5340_i2c_sda_i = si5340_i2c_sda;
assign si5340_i2c_sda = si5340_i2c_sda_o ? 1'bz : 1'b0;

// wire i2c_init_scl_i = i2c_scl_i;
// wire i2c_init_scl_o;
// wire i2c_init_sda_i = i2c_sda_i;
// wire i2c_init_sda_o;

// wire i2c_int_scl_i = i2c_scl_i;
// wire i2c_int_scl_o;
// wire i2c_int_sda_i = i2c_sda_i;
// wire i2c_int_sda_o;

// assign si5340_i2c_scl_o = si5340_i2c_init_scl_o & si5340_i2c_int_scl_o;
// assign si5340_i2c_sda_o = si5340_i2c_init_sda_o & si5340_i2c_int_sda_o;

// Si5340 init
taxi_axis_if #(.DATA_W(12)) si5340_i2c_cmd();
taxi_axis_if #(.DATA_W(8)) si5340_i2c_tx();
taxi_axis_if #(.DATA_W(8)) si5340_i2c_rx();

assign si5340_i2c_rx.tready = 1'b1;

wire si5340_i2c_busy;

taxi_i2c_master
si5340_i2c_master_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),

    /*
     * Host interface
     */
    .s_axis_cmd(si5340_i2c_cmd),
    .s_axis_tx(si5340_i2c_tx),
    .m_axis_rx(si5340_i2c_rx),

    /*
     * I2C interface
     */
    .scl_i(si5340_i2c_scl_i),
    .scl_o(si5340_i2c_scl_o),
    .sda_i(si5340_i2c_sda_i),
    .sda_o(si5340_i2c_sda_o),

    /*
     * Status
     */
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),

    /*
     * Configuration
     */
    .prescale(SIM ? 32 : 312),
    .stop_on_idle(1)
);

si5340_i2c_init #(
    .SIM_SPEEDUP(SIM)
)
si5340_i2c_init_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),

    /*
     * I2C master interface
     */
    .m_axis_cmd(si5340_i2c_cmd),
    .m_axis_tx(si5340_i2c_tx),

    /*
     * Status
     */
    .busy(si5340_i2c_busy),

    /*
     * Configuration
     */
    .start(1'b1)
);

localparam PORT_CNT = 2;
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

assign qsfp0_tx_p = eth_gty_tx_p[4*0 +: 4];
assign qsfp0_tx_n = eth_gty_tx_n[4*0 +: 4];
assign eth_gty_rx_p[4*0 +: 4] = qsfp0_rx_p;
assign eth_gty_rx_n[4*0 +: 4] = qsfp0_rx_n;

assign qsfp1_tx_p = eth_gty_tx_p[4*1 +: 4];
assign qsfp1_tx_n = eth_gty_tx_n[4*1 +: 4];
assign eth_gty_rx_p[4*1 +: 4] = qsfp1_rx_p;
assign eth_gty_rx_n[4*1 +: 4] = qsfp1_rx_n;

assign eth_gty_mgt_refclk_p[0] = qsfp0_mgt_refclk_p;
assign eth_gty_mgt_refclk_n[0] = qsfp0_mgt_refclk_n;
assign eth_gty_mgt_refclk_p[1] = qsfp1_mgt_refclk_p;
assign eth_gty_mgt_refclk_n[1] = qsfp1_mgt_refclk_n;

fpga_core #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
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
     * Clock: 125 MHz
     * Synchronous reset
     */
    .clk_125mhz(clk_125mhz_int),
    .rst_125mhz(rst_125mhz_int),

    /*
     * GPIO
     */
     .led(led),
     .qsfp_led(qsfp_led),
     .led_red(led_red),
     .led_green(led_green),
     .led_sync(led_sync),
     .eth_led_yellow(eth_led_yellow),
     .eth_led_green(eth_led_green),

    /*
     * Ethernet: QSFP28
     */
    .eth_gty_tx_p(eth_gty_tx_p),
    .eth_gty_tx_n(eth_gty_tx_n),
    .eth_gty_rx_p(eth_gty_rx_p),
    .eth_gty_rx_n(eth_gty_rx_n),
    .eth_gty_mgt_refclk_p(eth_gty_mgt_refclk_p),
    .eth_gty_mgt_refclk_n(eth_gty_mgt_refclk_n),
    .eth_gty_mgt_refclk_out(eth_gty_mgt_refclk_out),

    .eth_port_resetl({qsfp1_resetl, qsfp0_resetl}),
    .eth_port_modprsl({qsfp1_modprsl, qsfp0_modprsl}),
    .eth_port_intl({qsfp1_intl, qsfp0_intl}),
    .eth_port_lpmode({qsfp1_lpmode, qsfp0_lpmode}),

    .eth_port_i2c_scl_i({qsfp1_i2c_scl_i, qsfp0_i2c_scl_i}),
    .eth_port_i2c_scl_o({qsfp1_i2c_scl_o, qsfp0_i2c_scl_o}),
    .eth_port_i2c_sda_i({qsfp1_i2c_sda_i, qsfp0_i2c_sda_i}),
    .eth_port_i2c_sda_o({qsfp1_i2c_sda_o, qsfp0_i2c_sda_o})
);

endmodule

`resetall
