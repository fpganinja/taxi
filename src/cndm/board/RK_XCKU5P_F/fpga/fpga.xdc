# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# General configuration
set_property CFGBVS GND                                      [current_design]
set_property CONFIG_VOLTAGE 1.8                              [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true                 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup               [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 72.9                [current_design]
set_property CONFIG_MODE SPIx4                               [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4                 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes              [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable        [current_design]

# 200 MHz system clock (Y2)
set_property -dict {LOC T24  IOSTANDARD LVDS} [get_ports {clk_200mhz_p}]
set_property -dict {LOC U24  IOSTANDARD LVDS} [get_ports {clk_200mhz_n}]
create_clock -period 5.000 -name clk_200mhz [get_ports {clk_200mhz_p}]

# LEDs
set_property -dict {LOC H9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[0]}] ;# LED2
set_property -dict {LOC J9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[1]}] ;# LED3
set_property -dict {LOC G11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[2]}] ;# LED4
set_property -dict {LOC H11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[3]}] ;# LED5

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Buttons
set_property -dict {LOC K9   IOSTANDARD LVCMOS33} [get_ports {btn[0]}] ;# K1
set_property -dict {LOC K10  IOSTANDARD LVCMOS33} [get_ports {btn[1]}] ;# K2
set_property -dict {LOC J10  IOSTANDARD LVCMOS33} [get_ports {btn[2]}] ;# K3
set_property -dict {LOC J11  IOSTANDARD LVCMOS33} [get_ports {btn[3]}] ;# K4

set_false_path -from [get_ports {btn[*]}]
set_input_delay 0 [get_ports {btn[*]}]

# GPIO
#set_property -dict {LOC D10  IOSTANDARD LVCMOS33} [get_ports {gpio[0]}]  ;# J1.3
#set_property -dict {LOC D11  IOSTANDARD LVCMOS33} [get_ports {gpio[1]}]  ;# J1.4
#set_property -dict {LOC E10  IOSTANDARD LVCMOS33} [get_ports {gpio[2]}]  ;# J1.5
#set_property -dict {LOC E11  IOSTANDARD LVCMOS33} [get_ports {gpio[3]}]  ;# J1.6
#set_property -dict {LOC B11  IOSTANDARD LVCMOS33} [get_ports {gpio[4]}]  ;# J1.7
#set_property -dict {LOC C11  IOSTANDARD LVCMOS33} [get_ports {gpio[5]}]  ;# J1.8
#set_property -dict {LOC C9   IOSTANDARD LVCMOS33} [get_ports {gpio[6]}]  ;# J1.9
#set_property -dict {LOC D9   IOSTANDARD LVCMOS33} [get_ports {gpio[7]}]  ;# J1.10
#set_property -dict {LOC A9   IOSTANDARD LVCMOS33} [get_ports {gpio[8]}]  ;# J1.11
#set_property -dict {LOC B9   IOSTANDARD LVCMOS33} [get_ports {gpio[9]}]  ;# J1.12
#set_property -dict {LOC A10  IOSTANDARD LVCMOS33} [get_ports {gpio[10]}] ;# J1.13
#set_property -dict {LOC B10  IOSTANDARD LVCMOS33} [get_ports {gpio[11]}] ;# J1.14
#set_property -dict {LOC A12  IOSTANDARD LVCMOS33} [get_ports {gpio[12]}] ;# J1.15
#set_property -dict {LOC A13  IOSTANDARD LVCMOS33} [get_ports {gpio[13]}] ;# J1.16
#set_property -dict {LOC A14  IOSTANDARD LVCMOS33} [get_ports {gpio[14]}] ;# J1.17
#set_property -dict {LOC B14  IOSTANDARD LVCMOS33} [get_ports {gpio[15]}] ;# J1.18
#set_property -dict {LOC C13  IOSTANDARD LVCMOS33} [get_ports {gpio[16]}] ;# J1.19
#set_property -dict {LOC C14  IOSTANDARD LVCMOS33} [get_ports {gpio[17]}] ;# J1.20
#set_property -dict {LOC B12  IOSTANDARD LVCMOS33} [get_ports {gpio[18]}] ;# J1.21
#set_property -dict {LOC C12  IOSTANDARD LVCMOS33} [get_ports {gpio[19]}] ;# J1.22
#set_property -dict {LOC D13  IOSTANDARD LVCMOS33} [get_ports {gpio[20]}] ;# J1.23
#set_property -dict {LOC D14  IOSTANDARD LVCMOS33} [get_ports {gpio[21]}] ;# J1.24
#set_property -dict {LOC E12  IOSTANDARD LVCMOS33} [get_ports {gpio[22]}] ;# J1.25
#set_property -dict {LOC E13  IOSTANDARD LVCMOS33} [get_ports {gpio[23]}] ;# J1.26
#set_property -dict {LOC F13  IOSTANDARD LVCMOS33} [get_ports {gpio[24]}] ;# J1.27
#set_property -dict {LOC F14  IOSTANDARD LVCMOS33} [get_ports {gpio[25]}] ;# J1.28
#set_property -dict {LOC F12  IOSTANDARD LVCMOS33} [get_ports {gpio[26]}] ;# J1.29
#set_property -dict {LOC G12  IOSTANDARD LVCMOS33} [get_ports {gpio[27]}] ;# J1.30
#set_property -dict {LOC G14  IOSTANDARD LVCMOS33} [get_ports {gpio[28]}] ;# J1.31
#set_property -dict {LOC H14  IOSTANDARD LVCMOS33} [get_ports {gpio[29]}] ;# J1.32
#set_property -dict {LOC J14  IOSTANDARD LVCMOS33} [get_ports {gpio[30]}] ;# J1.33
#set_property -dict {LOC J15  IOSTANDARD LVCMOS33} [get_ports {gpio[31]}] ;# J1.34
#set_property -dict {LOC H13  IOSTANDARD LVCMOS33} [get_ports {gpio[32]}] ;# J1.35
#set_property -dict {LOC J13  IOSTANDARD LVCMOS33} [get_ports {gpio[33]}] ;# J1.36

# UART
set_property -dict {LOC AC14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {uart_txd}] ;# U9.38 BDBUS0
set_property -dict {LOC AD13 IOSTANDARD LVCMOS33} [get_ports {uart_rxd}] ;# U9.39 BDBUS1

set_false_path -to [get_ports {uart_txd}]
set_output_delay 0 [get_ports {uart_txd}]
set_false_path -from [get_ports {uart_rxd}]
set_input_delay 0 [get_ports {uart_rxd}]

# Micro SD
#set_property -dict {LOC Y15  IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_clk}]  ;# SD1.5 CLK SCLK
#set_property -dict {LOC AA15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_cmd}]  ;# SD1.3 CMD DI
#set_property -dict {LOC AB14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[0]}] ;# SD1.7 D0 DO
#set_property -dict {LOC AA14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[1]}] ;# SD1.8 D1
#set_property -dict {LOC AB16 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[2]}] ;# SD1.1 D2
#set_property -dict {LOC AB15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[3]}] ;# SD1.2 D3 CS
#set_property -dict {LOC Y16  IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_cd}]   ;# SD1.9 CD

# Fan
#set_property -dict {LOC G9 IOSTANDARD LVCMOS33 QUIETIO SLOW DRIVE 8} [get_ports {fan}] ;# J2

# Gigabit Ethernet RGMII PHY
#set_property -dict {LOC K22  IOSTANDARD LVCMOS18} [get_ports {phy_rx_clk}] ;# from U16.28 RXC
#set_property -dict {LOC L24  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[0]}] ;# from U16.26 RXD0
#set_property -dict {LOC L25  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[1]}] ;# from U16.25 RXD1
#set_property -dict {LOC K25  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[2]}] ;# from U16.24 RXD2
#set_property -dict {LOC K26  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[3]}] ;# from U16.23 RXD3
#set_property -dict {LOC K23  IOSTANDARD LVCMOS18} [get_ports {phy_rx_ctl}] ;# from U16.27 RXCTL
#set_property -dict {LOC M25  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_tx_clk}] ;# from U16.21 TXC
#set_property -dict {LOC L23  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[0]}] ;# from U16.19 TXD0
#set_property -dict {LOC L22  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[1]}] ;# from U16.18 TXD1
#set_property -dict {LOC L20  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[2]}] ;# from U16.17 TXD2
#set_property -dict {LOC K20  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[3]}] ;# from U16.16 TXD3
#set_property -dict {LOC M26  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_tx_ctl}] ;# from U16.20 TXCTL
#set_property -dict {LOC M19  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {phy_mdio}] ;# from U16.14 MDIO
#set_property -dict {LOC L19  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {phy_mdc}] ;# from U16.13 MDC

#create_clock -period 8.000 -name {phy_rx_clk} [get_ports {phy_rx_clk}]

# QSFP28 Interface
set_property -dict {LOC Y2  } [get_ports {qsfp_rx_p[0]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC Y1  } [get_ports {qsfp_rx_n[0]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA5 } [get_ports {qsfp_tx_p[0]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA4 } [get_ports {qsfp_tx_n[0]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V2  } [get_ports {qsfp_rx_p[1]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V1  } [get_ports {qsfp_rx_n[1]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W5  } [get_ports {qsfp_tx_p[1]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W4  } [get_ports {qsfp_tx_n[1]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T2  } [get_ports {qsfp_rx_p[2]}] ;# MGTYRXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T1  } [get_ports {qsfp_rx_n[2]}] ;# MGTYRXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U5  } [get_ports {qsfp_tx_p[2]}] ;# MGTYTXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U4  } [get_ports {qsfp_tx_n[2]}] ;# MGTYTXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P2  } [get_ports {qsfp_rx_p[3]}] ;# MGTYRXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P1  } [get_ports {qsfp_rx_n[3]}] ;# MGTYRXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R5  } [get_ports {qsfp_tx_p[3]}] ;# MGTYTXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R4  } [get_ports {qsfp_tx_n[3]}] ;# MGTYTXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V7  } [get_ports {qsfp_mgt_refclk_p}] ;# MGTREFCLK0P_225
set_property -dict {LOC V6  } [get_ports {qsfp_mgt_refclk_n}] ;# MGTREFCLK0N_225
set_property -dict {LOC W13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_modsell]
set_property -dict {LOC W12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_resetl]
set_property -dict {LOC AA13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_modprsl]
set_property -dict {LOC Y13  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_intl]
set_property -dict {LOC W14  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_lpmode]
#set_property -dict {LOC AE15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {qsfp_i2c_scl}]
#set_property -dict {LOC AE13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {qsfp_i2c_sda}]

# 156.25 MHz MGT reference clock
create_clock -period 6.4 -name qsfp_mgt_refclk [get_ports {qsfp_mgt_refclk_p}]

set_false_path -to [get_ports {qsfp_modsell qsfp_resetl qsfp_lpmode}]
set_output_delay 0 [get_ports {qsfp_modsell qsfp_resetl qsfp_lpmode}]
set_false_path -from [get_ports {qsfp_modprsl qsfp_intl}]
set_input_delay 0 [get_ports {qsfp_modprsl qsfp_intl}]

#set_false_path -to [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
#set_output_delay 0 [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
#set_false_path -from [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
#set_input_delay 0 [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]

# PCIe Interface
set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[0]}] ;# MGTYRXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[0]}] ;# MGTYRXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AC5 } [get_ports {pcie_tx_p[0]}] ;# MGTYTXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AC4 } [get_ports {pcie_tx_n[0]}] ;# MGTYTXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[1]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[1]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD7 } [get_ports {pcie_tx_p[1]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD6 } [get_ports {pcie_tx_n[1]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE4 } [get_ports {pcie_rx_p[2]}] ;# MGTYRXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE3 } [get_ports {pcie_rx_n[2]}] ;# MGTYRXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE9 } [get_ports {pcie_tx_p[2]}] ;# MGTYTXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE8 } [get_ports {pcie_tx_n[2]}] ;# MGTYTXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[3]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[3]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[3]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[3]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AB7 } [get_ports pcie_refclk_p] ;# MGTREFCLK1P_224
set_property -dict {LOC AB6 } [get_ports pcie_refclk_n] ;# MGTREFCLK1N_224
set_property -dict {LOC T19 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset_n]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_p]

# FMC interface
# FMC HPC J4
#set_property -dict {LOC G24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[0]}]  ;# J4.G9  LA00_P_CC
#set_property -dict {LOC G25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[0]}]  ;# J4.G10 LA00_N_CC
#set_property -dict {LOC J23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[1]}]  ;# J4.D8  LA01_P_CC
#set_property -dict {LOC J24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[1]}]  ;# J4.D9  LA01_N_CC
#set_property -dict {LOC H21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[2]}]  ;# J4.H7  LA02_P
#set_property -dict {LOC H22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[2]}]  ;# J4.H8  LA02_N
#set_property -dict {LOC J19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[3]}]  ;# J4.G12 LA03_P
#set_property -dict {LOC J20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[3]}]  ;# J4.G13 LA03_N
#set_property -dict {LOC H26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[4]}]  ;# J4.H10 LA04_P
#set_property -dict {LOC G26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[4]}]  ;# J4.H11 LA04_N
#set_property -dict {LOC F24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[5]}]  ;# J4.D11 LA05_P
#set_property -dict {LOC F25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[5]}]  ;# J4.D12 LA05_N
#set_property -dict {LOC G20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[6]}]  ;# J4.C10 LA06_P
#set_property -dict {LOC G21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[6]}]  ;# J4.C11 LA06_N
#set_property -dict {LOC D24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[7]}]  ;# J4.H13 LA07_P
#set_property -dict {LOC D25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[7]}]  ;# J4.H14 LA07_N
#set_property -dict {LOC D26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[8]}]  ;# J4.G12 LA08_P
#set_property -dict {LOC C26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[8]}]  ;# J4.G13 LA08_N
#set_property -dict {LOC E25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[9]}]  ;# J4.D14 LA09_P
#set_property -dict {LOC E26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[9]}]  ;# J4.D15 LA09_N
#set_property -dict {LOC B25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[10]}] ;# J4.C14 LA10_P
#set_property -dict {LOC B26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[10]}] ;# J4.C15 LA10_N
#set_property -dict {LOC A24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[11]}] ;# J4.H16 LA11_P
#set_property -dict {LOC A25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[11]}] ;# J4.H17 LA11_N
#set_property -dict {LOC D23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[12]}] ;# J4.G15 LA12_P
#set_property -dict {LOC C24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[12]}] ;# J4.G16 LA12_N
#set_property -dict {LOC F23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[13]}] ;# J4.D17 LA13_P
#set_property -dict {LOC E23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[13]}] ;# J4.D18 LA13_N
#set_property -dict {LOC C23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[14]}] ;# J4.C18 LA14_P
#set_property -dict {LOC B24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[14]}] ;# J4.C19 LA14_N
#set_property -dict {LOC H18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[15]}] ;# J4.H19 LA15_P
#set_property -dict {LOC H19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[15]}] ;# J4.H20 LA15_N
#set_property -dict {LOC E21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[16]}] ;# J4.G18 LA16_P
#set_property -dict {LOC D21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[16]}] ;# J4.G19 LA16_N
#set_property -dict {LOC C18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[17]}] ;# J4.D20 LA17_P_CC
#set_property -dict {LOC C19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[17]}] ;# J4.D21 LA17_N_CC
#set_property -dict {LOC D19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[18]}] ;# J4.C22 LA18_P_CC
#set_property -dict {LOC D20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[18]}] ;# J4.C23 LA18_N_CC
#set_property -dict {LOC A22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[19]}] ;# J4.H22 LA19_P
#set_property -dict {LOC A23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[19]}] ;# J4.H23 LA19_N
#set_property -dict {LOC F20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[20]}] ;# J4.G21 LA20_P
#set_property -dict {LOC E20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[20]}] ;# J4.G22 LA20_N
#set_property -dict {LOC C21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[21]}] ;# J4.H25 LA21_P
#set_property -dict {LOC B21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[21]}] ;# J4.H26 LA21_N
#set_property -dict {LOC H16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[22]}] ;# J4.G24 LA22_P
#set_property -dict {LOC G16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[22]}] ;# J4.G25 LA22_N
#set_property -dict {LOC C22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[23]}] ;# J4.D23 LA23_P
#set_property -dict {LOC B22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[23]}] ;# J4.D24 LA23_N
#set_property -dict {LOC A17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[24]}] ;# J4.H28 LA24_P
#set_property -dict {LOC A18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[24]}] ;# J4.H29 LA24_N
#set_property -dict {LOC E18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[25]}] ;# J4.G27 LA25_P
#set_property -dict {LOC D18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[25]}] ;# J4.G28 LA25_N
#set_property -dict {LOC A19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[26]}] ;# J4.D26 LA26_P
#set_property -dict {LOC A20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[26]}] ;# J4.D27 LA26_N
#set_property -dict {LOC F18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[27]}] ;# J4.C26 LA27_P
#set_property -dict {LOC F19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[27]}] ;# J4.C27 LA27_N
#set_property -dict {LOC C17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[28]}] ;# J4.H31 LA28_P
#set_property -dict {LOC B17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[28]}] ;# J4.H32 LA28_N
#set_property -dict {LOC E16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[29]}] ;# J4.G30 LA29_P
#set_property -dict {LOC E17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[29]}] ;# J4.G31 LA29_N
#set_property -dict {LOC D16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[30]}] ;# J4.H34 LA30_P
#set_property -dict {LOC C16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[30]}] ;# J4.H35 LA30_N
#set_property -dict {LOC G15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[31]}] ;# J4.G33 LA31_P
#set_property -dict {LOC F15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[31]}] ;# J4.G34 LA31_N
#set_property -dict {LOC B15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[32]}] ;# J4.H37 LA32_P
#set_property -dict {LOC A15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[32]}] ;# J4.H38 LA32_N
#set_property -dict {LOC E15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[33]}] ;# J4.G36 LA33_P
#set_property -dict {LOC D15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[33]}] ;# J4.G37 LA33_N

#set_property -dict {LOC H23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk0_m2c_p}] ;# J4.H4 CLK0_M2C_P
#set_property -dict {LOC H24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk0_m2c_n}] ;# J4.H5 CLK0_M2C_N
#set_property -dict {LOC B19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk1_m2c_p}] ;# J4.G2 CLK1_M2C_P
#set_property -dict {LOC B20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk1_m2c_n}] ;# J4.G3 CLK1_M2C_N

#set_property -dict {LOC F10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {fmc_scl}] ;# J4.C30 SCL
#set_property -dict {LOC F9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {fmc_sda}] ;# J4.C31 SDA
#set_property -dict {LOC G10  IOSTANDARD LVCMOS33} [get_ports {fmc_pg_m2c}]                    ;# J4.F1 PG_M2C

#set_property -dict {LOC N5  } [get_ports {fmc_dp_c2m_p[0]}] ;# MGTHTXP0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C2  DP0_C2M_P
#set_property -dict {LOC N4  } [get_ports {fmc_dp_c2m_n[0]}] ;# MGTHTXN0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C3  DP0_C2M_N
#set_property -dict {LOC M2  } [get_ports {fmc_dp_m2c_p[0]}] ;# MGTHRXP0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C6  DP0_M2C_P
#set_property -dict {LOC M1  } [get_ports {fmc_dp_m2c_n[0]}] ;# MGTHRXN0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C7  DP0_M2C_N
#set_property -dict {LOC L5  } [get_ports {fmc_dp_c2m_p[1]}] ;# MGTHTXP1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A22 DP1_C2M_P
#set_property -dict {LOC L4  } [get_ports {fmc_dp_c2m_n[1]}] ;# MGTHTXN1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A23 DP1_C2M_N
#set_property -dict {LOC K2  } [get_ports {fmc_dp_m2c_p[1]}] ;# MGTHRXP1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A2  DP1_M2C_P
#set_property -dict {LOC K1  } [get_ports {fmc_dp_m2c_n[1]}] ;# MGTHRXN1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A3  DP1_M2C_N
#set_property -dict {LOC J5  } [get_ports {fmc_dp_c2m_p[2]}] ;# MGTHTXP2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A26 DP2_C2M_P
#set_property -dict {LOC J4  } [get_ports {fmc_dp_c2m_n[2]}] ;# MGTHTXN2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A27 DP2_C2M_N
#set_property -dict {LOC H2  } [get_ports {fmc_dp_m2c_p[2]}] ;# MGTHRXP2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A6  DP2_M2C_P
#set_property -dict {LOC H1  } [get_ports {fmc_dp_m2c_n[2]}] ;# MGTHRXN2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A7  DP2_M2C_N
#set_property -dict {LOC G5  } [get_ports {fmc_dp_c2m_p[3]}] ;# MGTHTXP3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A30 DP3_C2M_P
#set_property -dict {LOC G4  } [get_ports {fmc_dp_c2m_n[3]}] ;# MGTHTXN3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A31 DP3_C2M_N
#set_property -dict {LOC F2  } [get_ports {fmc_dp_m2c_p[3]}] ;# MGTHRXP3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A10 DP3_M2C_P
#set_property -dict {LOC F1  } [get_ports {fmc_dp_m2c_n[3]}] ;# MGTHRXN3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A11 DP3_M2C_N

#set_property -dict {LOC F7  } [get_ports {fmc_dp_c2m_p[4]}] ;# MGTHTXP0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A34 DP4_C2M_P
#set_property -dict {LOC F6  } [get_ports {fmc_dp_c2m_n[4]}] ;# MGTHTXN0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A35 DP4_C2M_N
#set_property -dict {LOC D2  } [get_ports {fmc_dp_m2c_p[4]}] ;# MGTHRXP0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A14 DP4_M2C_P
#set_property -dict {LOC D1  } [get_ports {fmc_dp_m2c_n[4]}] ;# MGTHRXN0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A15 DP4_M2C_N
#set_property -dict {LOC E5  } [get_ports {fmc_dp_c2m_p[5]}] ;# MGTHTXP1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A38 DP5_C2M_P
#set_property -dict {LOC E4  } [get_ports {fmc_dp_c2m_n[5]}] ;# MGTHTXN1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A39 DP5_C2M_N
#set_property -dict {LOC C4  } [get_ports {fmc_dp_m2c_p[5]}] ;# MGTHRXP1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A18 DP5_M2C_P
#set_property -dict {LOC C3  } [get_ports {fmc_dp_m2c_n[5]}] ;# MGTHRXN1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A19 DP5_M2C_N
#set_property -dict {LOC D7  } [get_ports {fmc_dp_c2m_p[6]}] ;# MGTHTXP2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B36 DP6_C2M_P
#set_property -dict {LOC D6  } [get_ports {fmc_dp_c2m_n[6]}] ;# MGTHTXN2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B37 DP6_C2M_N
#set_property -dict {LOC B2  } [get_ports {fmc_dp_m2c_p[6]}] ;# MGTHRXP2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B16 DP6_M2C_P
#set_property -dict {LOC B1  } [get_ports {fmc_dp_m2c_n[6]}] ;# MGTHRXN2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B17 DP6_M2C_N
#set_property -dict {LOC B7  } [get_ports {fmc_dp_c2m_p[7]}] ;# MGTHTXP3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B32 DP7_C2M_P
#set_property -dict {LOC B6  } [get_ports {fmc_dp_c2m_n[7]}] ;# MGTHTXN3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B33 DP7_C2M_N
#set_property -dict {LOC A4  } [get_ports {fmc_dp_m2c_p[7]}] ;# MGTHRXP3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B12 DP7_M2C_P
#set_property -dict {LOC A3  } [get_ports {fmc_dp_m2c_n[7]}] ;# MGTHRXN3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B13 DP7_M2C_N
#set_property -dict {LOC P7  } [get_ports {fmc_mgt_refclk_0_p}] ;# MGTREFCLK0P_226 from J4.D4 GBTCLK0_M2C_P
#set_property -dict {LOC P6  } [get_ports {fmc_mgt_refclk_0_n}] ;# MGTREFCLK0N_226 from J4.D5 GBTCLK0_M2C_N
#set_property -dict {LOC K7  } [get_ports {fmc_mgt_refclk_1_p}] ;# MGTREFCLK0P_227 from J4.B20 GBTCLK1_M2C_P
#set_property -dict {LOC K6  } [get_ports {fmc_mgt_refclk_1_n}] ;# MGTREFCLK0N_227 from J4.B21 GBTCLK1_M2C_N

# reference clock
#create_clock -period 6.400 -name fmc_mgt_refclk_0 [get_ports {fmc_mgt_refclk_0_p}]
#create_clock -period 6.400 -name fmc_mgt_refclk_1 [get_ports {fmc_mgt_refclk_1_p}]

# DDR4
# 2x MT40A512M16LY-062E:E U3, U6
#set_property -dict {LOC Y22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[0]}]
#set_property -dict {LOC Y25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[1]}]
#set_property -dict {LOC W23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[2]}]
#set_property -dict {LOC V26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[3]}]
#set_property -dict {LOC R26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[4]}]
#set_property -dict {LOC U26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[5]}]
#set_property -dict {LOC R21  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[6]}]
#set_property -dict {LOC W25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[7]}]
#set_property -dict {LOC R20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[8]}]
#set_property -dict {LOC Y26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[9]}]
#set_property -dict {LOC R25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[10]}]
#set_property -dict {LOC V23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[11]}]
#set_property -dict {LOC AA24 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[12]}]
#set_property -dict {LOC W26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[13]}]
#set_property -dict {LOC P23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[14]}]
#set_property -dict {LOC AA25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[15]}]
#set_property -dict {LOC T25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[16]}]
#set_property -dict {LOC P21  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[0]}]
#set_property -dict {LOC P26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[1]}]
#set_property -dict {LOC R22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[0]}]
#set_property -dict {LOC V24  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_t}]
#set_property -dict {LOC W24  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_c}]
#set_property -dict {LOC P20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cke}]
#set_property -dict {LOC P25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cs_n}]
#set_property -dict {LOC P24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_act_n}]
#set_property -dict {LOC R23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_odt}]
#set_property -dict {LOC Y23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_par}]
#set_property -dict {LOC P19  IOSTANDARD LVCMOS12       } [get_ports {ddr4_reset_n}]
#set_property -dict {LOC U25  IOSTANDARD LVCMOS12       } [get_ports {ddr4_alert_n}]

#set_property -dict {LOC AB26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[0]}]
#set_property -dict {LOC AB25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[1]}]
#set_property -dict {LOC AF25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[2]}]
#set_property -dict {LOC AF24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[3]}]
#set_property -dict {LOC AD25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[4]}]
#set_property -dict {LOC AD24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[5]}]
#set_property -dict {LOC AC24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[6]}]
#set_property -dict {LOC AB24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[7]}]
#set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[8]}]
#set_property -dict {LOC AD23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[9]}]
#set_property -dict {LOC AC23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[10]}]
#set_property -dict {LOC AC22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[11]}]
#set_property -dict {LOC AE21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[12]}]
#set_property -dict {LOC AD21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[13]}]
#set_property -dict {LOC AC21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[14]}]
#set_property -dict {LOC AB21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[15]}]
#set_property -dict {LOC AC26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[0]}]     ;# U3.G3 DQSL_T
#set_property -dict {LOC AD26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[0]}]     ;# U3.F3 DQSL_C
#set_property -dict {LOC AA22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[1]}]     ;# U3.B7 DQSU_T
#set_property -dict {LOC AB22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[1]}]     ;# U3.A7 DQSU_C
#set_property -dict {LOC AE25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[0]}]  ;# U3.E7 DML_B/DBIL_B
#set_property -dict {LOC AE22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[1]}]  ;# U3.E2 DMU_B/DBIU_B

#set_property -dict {LOC AD19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[0]}]
#set_property -dict {LOC AC19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[1]}]
#set_property -dict {LOC AF19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[2]}]
#set_property -dict {LOC AF18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[3]}]
#set_property -dict {LOC AF17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[4]}]
#set_property -dict {LOC AE17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[5]}]
#set_property -dict {LOC AE16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[6]}]
#set_property -dict {LOC AD16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[7]}]
#set_property -dict {LOC AB19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[8]}]
#set_property -dict {LOC AA19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[9]}]
#set_property -dict {LOC AB20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[10]}]
#set_property -dict {LOC AA20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[11]}]
#set_property -dict {LOC AA17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[12]}]
#set_property -dict {LOC Y17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[13]}]
#set_property -dict {LOC AA18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[14]}]
#set_property -dict {LOC Y18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[15]}]
#set_property -dict {LOC AC18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[2]}]     ;# U6.G3 DQSL_T
#set_property -dict {LOC AD18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[2]}]     ;# U6.F3 DQSL_C
#set_property -dict {LOC AB17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[3]}]     ;# U6.B7 DQSU_T
#set_property -dict {LOC AC17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[3]}]     ;# U6.A7 DQSU_C
#set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[2]}]  ;# U6.E7 DML_B/DBIL_B
#set_property -dict {LOC Y20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[3]}]  ;# U6.E2 DMU_B/DBIU_B
