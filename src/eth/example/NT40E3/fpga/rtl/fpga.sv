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
    parameter string FAMILY = "virtex7",
    // 10G MAC configuration
    parameter logic CFG_LOW_LATENCY = 1'b1,
    parameter logic COMBINED_MAC_PCS = 1'b1
)
(
    /*
     * Clock: 80MHz
     */
    input  wire logic        clk_80mhz,

    /*
     * GPIO
     */
    output wire logic [3:0]  sfp_led,
    output wire logic [3:0]  led,
    output wire logic        led_red,
    output wire logic        led_green,
    output wire logic [1:0]  led_sync,

    /*
     * I2C
     */
    inout  wire logic        si5338_i2c_scl,
    inout  wire logic        si5338_i2c_sda,
    input  wire logic        si5338_intr,

    /*
     * Ethernet: SFP+
     */
    input  wire logic        sfp_rx_p[4],
    input  wire logic        sfp_rx_n[4],
    output wire logic        sfp_tx_p[4],
    output wire logic        sfp_tx_n[4],
    input  wire logic        sfp_mgt_refclk_p[2],
    input  wire logic        sfp_mgt_refclk_n[2],

    input  wire logic        sfp_mod_abs[4],
    output wire logic [1:0]  sfp_rs[4],
    output wire logic        sfp_tx_disable[4]
);

// Clock and reset

wire clk_80mhz_ibufg;

// Internal 125 MHz clock
wire clk_125mhz_mmcm_out;
wire clk_125mhz_int;
wire rst_125mhz_int;

// Internal 156.25 MHz clock
wire clk_156mhz_int;
wire rst_156mhz_int;

wire mmcm_rst = 1'b0;
wire mmcm_locked;
wire mmcm_clkfb;

IBUFG
clk_80mhz_ibufg_inst (
    .I(clk_80mhz),
    .O(clk_80mhz_ibufg)
);

// MMCM instance
// 80 MHz in, 125 MHz out
// PFD range: 10 MHz to 500 MHz
// VCO range: 600 MHz to 1440 MHz
// M = 25, D = 2 sets Fvco = 1000 MHz
// Divide by 8 to get output frequency of 125 MHz
MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKOUT0_DIVIDE_F(8),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    .CLKOUT1_DIVIDE(1),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(0),
    .CLKOUT2_DIVIDE(1),
    .CLKOUT2_DUTY_CYCLE(0.5),
    .CLKOUT2_PHASE(0),
    .CLKOUT3_DIVIDE(1),
    .CLKOUT3_DUTY_CYCLE(0.5),
    .CLKOUT3_PHASE(0),
    .CLKOUT4_DIVIDE(1),
    .CLKOUT4_DUTY_CYCLE(0.5),
    .CLKOUT4_PHASE(0),
    .CLKOUT5_DIVIDE(1),
    .CLKOUT5_DUTY_CYCLE(0.5),
    .CLKOUT5_PHASE(0),
    .CLKOUT6_DIVIDE(1),
    .CLKOUT6_DUTY_CYCLE(0.5),
    .CLKOUT6_PHASE(0),
    .CLKFBOUT_MULT_F(25),
    .CLKFBOUT_PHASE(0),
    .DIVCLK_DIVIDE(2),
    .REF_JITTER1(0.010),
    .CLKIN1_PERIOD(12.5),
    .STARTUP_WAIT("FALSE"),
    .CLKOUT4_CASCADE("FALSE")
)
clk_mmcm_inst (
    .CLKIN1(clk_80mhz_ibufg),
    .CLKFBIN(mmcm_clkfb),
    .RST(mmcm_rst),
    .PWRDWN(1'b0),
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    .CLKOUT1(),
    .CLKOUT1B(),
    .CLKOUT2(),
    .CLKOUT2B(),
    .CLKOUT3(),
    .CLKOUT3B(),
    .CLKOUT4(),
    .CLKOUT5(),
    .CLKOUT6(),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    .LOCKED(mmcm_locked)
);

BUFG
clk_bufg_inst (
    .I(clk_125mhz_mmcm_out),
    .O(clk_125mhz_int)
);

taxi_sync_reset #(
    .N(4)
)
sync_reset_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

// I2C
wire si5338_i2c_scl_i;
wire si5338_i2c_scl_o;
wire si5338_i2c_sda_i;
wire si5338_i2c_sda_o;

assign si5338_i2c_scl_i = si5338_i2c_scl;
assign si5338_i2c_scl = si5338_i2c_scl_o ? 1'bz : 1'b0;
assign si5338_i2c_sda_i = si5338_i2c_sda;
assign si5338_i2c_sda = si5338_i2c_sda_o ? 1'bz : 1'b0;

// wire i2c_init_scl_i = i2c_scl_i;
// wire i2c_init_scl_o;
// wire i2c_init_sda_i = i2c_sda_i;
// wire i2c_init_sda_o;

// wire i2c_int_scl_i = i2c_scl_i;
// wire i2c_int_scl_o;
// wire i2c_int_sda_i = i2c_sda_i;
// wire i2c_int_sda_o;

// assign si5338_i2c_scl_o = si5338_i2c_init_scl_o & si5338_i2c_int_scl_o;
// assign si5338_i2c_sda_o = si5338_i2c_init_sda_o & si5338_i2c_int_sda_o;

// Si5338 init
taxi_axis_if #(.DATA_W(12)) si5338_i2c_cmd();
taxi_axis_if #(.DATA_W(8)) si5338_i2c_tx();
taxi_axis_if #(.DATA_W(8)) si5338_i2c_rx();

assign si5338_i2c_rx.tready = 1'b1;

wire si5338_i2c_busy;

// assign si5338_rst = ~rst_125mhz_int;

taxi_i2c_master
si5338_i2c_master_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),

    /*
     * Host interface
     */
    .s_axis_cmd(si5338_i2c_cmd),
    .s_axis_tx(si5338_i2c_tx),
    .m_axis_rx(si5338_i2c_rx),

    /*
     * I2C interface
     */
    .scl_i(si5338_i2c_scl_i),
    .scl_o(si5338_i2c_scl_o),
    .sda_i(si5338_i2c_sda_i),
    .sda_o(si5338_i2c_sda_o),

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

si5338_i2c_init #(
    .SIM_SPEEDUP(SIM)
)
si5338_i2c_init_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),

    /*
     * I2C master interface
     */
    .m_axis_cmd(si5338_i2c_cmd),
    .m_axis_tx(si5338_i2c_tx),

    /*
     * Status
     */
    .busy(si5338_i2c_busy),

    /*
     * Configuration
     */
    .start(1'b1)
);

fpga_core #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .CFG_LOW_LATENCY(CFG_LOW_LATENCY),
    .COMBINED_MAC_PCS(COMBINED_MAC_PCS)
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
    .sfp_led(sfp_led),
    .led(led),
    .led_red(led_red),
    .led_green(led_green),
    .led_sync(led_sync),

    /*
     * Ethernet: SFP+
     */
    .sfp_rx_p(sfp_rx_p),
    .sfp_rx_n(sfp_rx_n),
    .sfp_tx_p(sfp_tx_p),
    .sfp_tx_n(sfp_tx_n),
    .sfp_mgt_refclk_p(sfp_mgt_refclk_p),
    .sfp_mgt_refclk_n(sfp_mgt_refclk_n),
    // .sma_mgt_refclk_p(sma_mgt_refclk_p),
    // .sma_mgt_refclk_n(sma_mgt_refclk_n),
    // .sfp_recclk_p(sfp_recclk_p),
    // .sfp_recclk_n(sfp_recclk_n),

    .sfp_mod_abs(sfp_mod_abs),
    .sfp_rs(sfp_rs),
    .sfp_tx_disable(sfp_tx_disable)
);

endmodule

`resetall
