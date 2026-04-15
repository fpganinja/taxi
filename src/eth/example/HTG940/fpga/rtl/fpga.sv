// SPDX-License-Identifier: MIT
/*

Copyright (c) 2025 FPGA Ninja, LLC

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
    // Use 90 degree clock for RGMII transmit
    parameter logic USE_CLK90 = 1'b0
)
(
    /*
     * Clock: 156.25 MHz LVDS
     */
    input  wire logic        ref_clk_p,
    input  wire logic        ref_clk_n,

    /*
     * GPIO
     */
    input  wire logic [1:0]  btn,
    input  wire logic [7:0]  sw,
    output wire logic [7:0]  led,

    /*
     * I2C for board management
     */
    inout  wire logic        i2c_main_scl,
    inout  wire logic        i2c_main_sda,
    output wire logic        i2c_main_rst_n,

    /*
     * UART: 115200 bps, 8N1
     */
    output wire logic        uart_rxd,
    input  wire logic        uart_txd,
    input  wire logic        uart_rts,
    output wire logic        uart_cts,
    output wire logic        uart_rst_n,

    /*
     * Ethernet: 1000BASE-T RGMII
     */
    input  wire logic        phy_rx_clk,
    input  wire logic [3:0]  phy_rxd,
    input  wire logic        phy_rx_ctl,
    output wire logic        phy_tx_clk,
    output wire logic [3:0]  phy_txd,
    output wire logic        phy_tx_ctl
);

// Clock and reset

wire ref_clk_ibufg;

// Internal 125 MHz clock
wire clk_125mhz_mmcm_out;
wire clk90_125mhz_mmcm_out;
wire clk_125mhz_int;
wire clk90_125mhz_int;
wire rst_125mhz_int;

// Internal 312.5 MHz clock
wire clk_312mhz_mmcm_out;
wire clk_312mhz_int;
wire rst_312mhz_int;

wire mmcm_rst = ~btn[0];
wire mmcm_locked;
wire mmcm_clkfb;

IBUFGDS #(
    .DIFF_TERM("FALSE"),
    .IBUF_LOW_PWR("FALSE")
)
ref_clk_ibufg_inst (
    .O   (ref_clk_ibufg),
    .I   (ref_clk_p),
    .IB  (ref_clk_n)
);

// MMCM instance
MMCME4_BASE #(
    // 156.25 MHz input
    .CLKIN1_PERIOD(6.4),
    .REF_JITTER1(0.010),
    // 156.25 MHz input / 1 = 156.25 MHz PFD (range 10 MHz to 500 MHz)
    .DIVCLK_DIVIDE(1),
    // 156.25 MHz PFD * 8 = 1250 MHz VCO (range 800 MHz to 1600 MHz)
    .CLKFBOUT_MULT_F(8),
    .CLKFBOUT_PHASE(0),
    // 1250 MHz / 10 = 125 MHz, 0 degrees
    .CLKOUT0_DIVIDE_F(10),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0),
    // 1250 MHz / 10 = 125 MHz, 90 degrees
    .CLKOUT1_DIVIDE(10),
    .CLKOUT1_DUTY_CYCLE(0.5),
    .CLKOUT1_PHASE(90),
    // 1250 MHz / 4 = 312.5 MHz, 0 degrees
    .CLKOUT2_DIVIDE(4),
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
    // 156.25 MHz input
    .CLKIN1(ref_clk_ibufg),
    // direct clkfb feeback
    .CLKFBIN(mmcm_clkfb),
    .CLKFBOUT(mmcm_clkfb),
    .CLKFBOUTB(),
    // 125 MHz, 0 degrees
    .CLKOUT0(clk_125mhz_mmcm_out),
    .CLKOUT0B(),
    // 125 MHz, 90 degrees
    .CLKOUT1(clk90_125mhz_mmcm_out),
    .CLKOUT1B(),
    // 312.5 MHz, 0 degrees
    .CLKOUT2(clk_312mhz_mmcm_out),
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

BUFG
clk90_125mhz_bufg_inst (
    .I(clk90_125mhz_mmcm_out),
    .O(clk90_125mhz_int)
);

BUFG
clk_312mhz_bufg_inst (
    .I(clk_312mhz_mmcm_out),
    .O(clk_312mhz_int)
);

taxi_sync_reset #(
    .N(4)
)
sync_reset_125mhz_inst (
    .clk(clk_125mhz_int),
    .rst(~mmcm_locked),
    .out(rst_125mhz_int)
);

taxi_sync_reset #(
    .N(4)
)
sync_reset_312mhz_inst (
    .clk(clk_312mhz_int),
    .rst(~mmcm_locked),
    .out(rst_312mhz_int)
);

// GPIO
wire btn_int;
wire [7:0] sw_int;

taxi_debounce_switch #(
    .WIDTH(9),
    .N(4),
    .RATE(125000)
)
debounce_switch_inst (
    .clk(clk_125mhz_int),
    .rst(rst_125mhz_int),
    .in({btn[1],
        ~sw}),
    .out({btn_int,
        sw_int})
);

wire uart_txd_int;
wire uart_rts_int;

taxi_sync_signal #(
    .WIDTH(2),
    .N(2)
)
sync_signal_inst (
    .clk(clk_125mhz_int),
    .in({uart_txd, uart_rts}),
    .out({uart_txd_int, uart_rts_int})
);

wire i2c_scl_i;
wire i2c_scl_o;
wire i2c_scl_t;
wire i2c_sda_i;
wire i2c_sda_o;
wire i2c_sda_t;

assign i2c_scl_i = i2c_main_scl;
assign i2c_main_scl = i2c_scl_t ? 1'bz : i2c_scl_o;
assign i2c_sda_i = i2c_main_sda;
assign i2c_main_sda = i2c_sda_t ? 1'bz : i2c_sda_o;
assign i2c_main_rst_n = 1'b1;

// IODELAY elements for RGMII interface to PHY
wire [3:0] phy_rxd_int;
wire phy_rx_ctl_int;

IDELAYCTRL #(
    .SIM_DEVICE("ULTRASCALE")
)
idelayctrl_inst (
    .REFCLK(clk_312mhz_int),
    .RST(rst_312mhz_int),
    .RDY()
);

for (genvar n = 0; n < 4; n = n + 1) begin : phy_rxd_idelay_bit

    IDELAYE3 #(
        .DELAY_SRC("IDATAIN"),
        .CASCADE("NONE"),
        .DELAY_TYPE("FIXED"),
        .DELAY_VALUE(0),
        .REFCLK_FREQUENCY(312.5),
        .DELAY_FORMAT("TIME"),
        .UPDATE_MODE("SYNC"),
        .SIM_DEVICE("ULTRASCALE_PLUS")
    )
    idelay_inst (
        .CASC_IN(1'b0),
        .CASC_RETURN(1'b0),
        .CASC_OUT(),
        .IDATAIN(phy_rxd[n]),
        .DATAIN(1'b0),
        .DATAOUT(phy_rxd_int[n]),
        .CLK(1'b0),
        .EN_VTC(1'b1),
        .CE(1'b0),
        .INC(1'b0),
        .LOAD(1'b0),
        .RST(1'b0),
        .CNTVALUEIN(9'd0),
        .CNTVALUEOUT()
    );

end

IDELAYE3 #(
    .DELAY_SRC("IDATAIN"),
    .CASCADE("NONE"),
    .DELAY_TYPE("FIXED"),
    .DELAY_VALUE(0),
    .REFCLK_FREQUENCY(312.5),
    .DELAY_FORMAT("TIME"),
    .UPDATE_MODE("SYNC"),
    .SIM_DEVICE("ULTRASCALE_PLUS")
)
phy_rx_ctl_idelay (
    .CASC_IN(1'b0),
    .CASC_RETURN(1'b0),
    .CASC_OUT(),
    .IDATAIN(phy_rx_ctl),
    .DATAIN(1'b0),
    .DATAOUT(phy_rx_ctl_int),
    .CLK(1'b0),
    .EN_VTC(1'b1),
    .CE(1'b0),
    .INC(1'b0),
    .LOAD(1'b0),
    .RST(1'b0),
    .CNTVALUEIN(9'd0),
    .CNTVALUEOUT()
);

fpga_core #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .USE_CLK90(USE_CLK90)
)
core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk(clk_125mhz_int),
    .clk90(clk90_125mhz_int),
    .rst(rst_125mhz_int),

    /*
     * GPIO
     */
    .btn(btn_int),
    .sw(sw_int),
    .led(led),

    /*
     * UART: 115200 bps, 8N1
     */
    .uart_rxd(uart_rxd),
    .uart_txd(uart_txd_int),
    .uart_rts(uart_rts_int),
    .uart_cts(uart_cts),
    .uart_rst_n(uart_rst_n),

    /*
     * Ethernet: 1000BASE-T RGMII
     */
    .phy_rgmii_rx_clk(phy_rx_clk),
    .phy_rgmii_rxd(phy_rxd),
    .phy_rgmii_rx_ctl(phy_rx_ctl),
    .phy_rgmii_tx_clk(phy_tx_clk),
    .phy_rgmii_txd(phy_txd),
    .phy_rgmii_tx_ctl(phy_tx_ctl)
);

endmodule

`resetall
