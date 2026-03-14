# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN {DIV-1} [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 8           [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup         [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# 300 MHz system clock
#set_property -dict {LOC AK17 IOSTANDARD DIFF_SSTL12} [get_ports clk_300mhz_p] ;# from U122 Si5335
#set_property -dict {LOC AK16 IOSTANDARD DIFF_SSTL12} [get_ports clk_300mhz_n] ;# from U122 Si5335
#create_clock -period 3.333 -name clk_300mhz [get_ports clk_300mhz_p]

# 125 MHz system clock
set_property -dict {LOC G10 IOSTANDARD LVDS} [get_ports clk_125mhz_p] ;# from U122 Si5335
set_property -dict {LOC F10 IOSTANDARD LVDS} [get_ports clk_125mhz_n] ;# from U122 Si5335
create_clock -period 8.000 -name clk_125mhz [get_ports clk_125mhz_p]

# Si570 user clock (156.25 MHz default)
#set_property -dict {LOC M25 IOSTANDARD LVDS_25} [get_ports clk_user_p] ;# from U122 Si5335
#set_property -dict {LOC M26 IOSTANDARD LVDS_25} [get_ports clk_user_n] ;# from U122 Si5335
#create_clock -period 6.400 -name clk_user [get_ports clk_user_p]

# 90 MHz
#set_property -dict {LOC K20 IOSTANDARD LVCMOS18} [get_ports clk_90mhz] ;# from U122 Si5335
#create_clock -period 11.111 -name clk_90mhz [get_ports clk_90mhz]

# User SMA clock J34/J35
#set_property -dict {LOC D23 IOSTANDARD LVDS} [get_ports clk_user_sma_p] ;# J34
#set_property -dict {LOC C23 IOSTANDARD LVDS} [get_ports clk_user_sma_n] ;# J35
#create_clock -period 10.000 -name clk_user_sma [get_ports clk_user_sma_p]

# User SMA GPIO J36/J37
#set_property -dict {LOC H27 IOSTANDARD LVDS} [get_ports user_sma_gpio_p] ;# J36
#set_property -dict {LOC G27 IOSTANDARD LVDS} [get_ports user_sma_gpio_n] ;# J37

# LEDs
set_property -dict {LOC AP8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[0]}] ;# to DS7
set_property -dict {LOC H23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[1]}] ;# to DS6
set_property -dict {LOC P20  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[2]}] ;# to DS8
set_property -dict {LOC P21  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[3]}] ;# to DS9
set_property -dict {LOC N22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[4]}] ;# to DS10
set_property -dict {LOC M22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[5]}] ;# to DS33
set_property -dict {LOC R23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[6]}] ;# to DS32
set_property -dict {LOC P23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[7]}] ;# to DS31

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Reset button
set_property -dict {LOC AN8  IOSTANDARD LVCMOS18} [get_ports reset] ;# from SW5

set_false_path -from [get_ports {reset}]
set_input_delay 0 [get_ports {reset}]

# Push buttons
set_property -dict {LOC AD10 IOSTANDARD LVCMOS18} [get_ports btnu] ;# from SW10
set_property -dict {LOC AF9  IOSTANDARD LVCMOS18} [get_ports btnl] ;# from SW6
set_property -dict {LOC AF8  IOSTANDARD LVCMOS18} [get_ports btnd] ;# from SW8
set_property -dict {LOC AE8  IOSTANDARD LVCMOS18} [get_ports btnr] ;# from SW9
set_property -dict {LOC AE10 IOSTANDARD LVCMOS18} [get_ports btnc] ;# from SW7

set_false_path -from [get_ports {btnu btnl btnd btnr btnc}]
set_input_delay 0 [get_ports {btnu btnl btnd btnr btnc}]

# DIP switches
set_property -dict {LOC AN16 IOSTANDARD LVCMOS12} [get_ports {sw[0]}] ;# from SW12.4
set_property -dict {LOC AN19 IOSTANDARD LVCMOS12} [get_ports {sw[1]}] ;# from SW12.3
set_property -dict {LOC AP18 IOSTANDARD LVCMOS12} [get_ports {sw[2]}] ;# from SW12.2
set_property -dict {LOC AN14 IOSTANDARD LVCMOS12} [get_ports {sw[3]}] ;# from SW12.1

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# PMOD0
#set_property -dict {LOC AK25 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[0]}] ;# J52.1
#set_property -dict {LOC AN21 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[1]}] ;# J52.3
#set_property -dict {LOC AH18 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[2]}] ;# J52.5
#set_property -dict {LOC AM19 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[3]}] ;# J52.7
#set_property -dict {LOC AE26 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[4]}] ;# J52.2
#set_property -dict {LOC AF25 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[5]}] ;# J52.4
#set_property -dict {LOC AE21 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[6]}] ;# J52.6
#set_property -dict {LOC AM17 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[7]}] ;# J52.8

#set_false_path -to [get_ports {pmod0[*]}]
#set_output_delay 0 [get_ports {pmod0[*]}]

# PMOD1
#set_property -dict {LOC AL14 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[0]}] ;# J53.1
#set_property -dict {LOC AM14 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[1]}] ;# J53.3
#set_property -dict {LOC AP16 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[2]}] ;# J53.5
#set_property -dict {LOC AP15 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[3]}] ;# J53.7
#set_property -dict {LOC AM16 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[4]}] ;# J53.2
#set_property -dict {LOC AM15 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[5]}] ;# J53.4
#set_property -dict {LOC AN18 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[6]}] ;# J53.6
#set_property -dict {LOC AN17 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod1[7]}] ;# J53.8

#set_false_path -to [get_ports {pmod1[*]}]
#set_output_delay 0 [get_ports {pmod1[*]}]

# UART (U34 CP2105 SCI)
set_property -dict {LOC K26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_txd}] ;# U34.20 RXD_SCI_I
set_property -dict {LOC G25  IOSTANDARD LVCMOS18} [get_ports {uart_rxd}] ;# U34.21 TXD_SCI_O
set_property -dict {LOC L23  IOSTANDARD LVCMOS18} [get_ports {uart_rts}] ;# U34.19 RTS_SCI_O
set_property -dict {LOC K27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_cts}] ;# U34.18 CTS_SCI_I

set_false_path -to [get_ports {uart_txd uart_cts}]
set_output_delay 0 [get_ports {uart_txd uart_cts}]
set_false_path -from [get_ports {uart_rxd uart_rts}]
set_input_delay 0 [get_ports {uart_rxd uart_rts}]

# I2C interface
set_property -dict {LOC J24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_scl]
set_property -dict {LOC J25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_sda]
set_property -dict {LOC AP10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_mux_reset]

set_false_path -to [get_ports {i2c_sda i2c_scl}]
set_output_delay 0 [get_ports {i2c_sda i2c_scl}]
set_false_path -from [get_ports {i2c_sda i2c_scl}]
set_input_delay 0 [get_ports {i2c_sda i2c_scl}]

# Gigabit Ethernet SGMII PHY
set_property -dict {LOC P24  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_rx_p]
set_property -dict {LOC P25  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_rx_n]
set_property -dict {LOC N24  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_tx_p]
set_property -dict {LOC M24  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_tx_n]
set_property -dict {LOC P26  IOSTANDARD LVDS_25} [get_ports phy_sgmii_clk_p]
set_property -dict {LOC N26  IOSTANDARD LVDS_25} [get_ports phy_sgmii_clk_n]
set_property -dict {LOC J23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports phy_reset_n]
set_property -dict {LOC K25  IOSTANDARD LVCMOS18} [get_ports phy_int_n]
#set_property -dict {LOC H26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports phy_mdio]
#set_property -dict {LOC L25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports phy_mdc]

# 625 MHz ref clock from SGMII PHY
#create_clock -period 1.600 -name phy_sgmii_clk [get_ports phy_sgmii_clk_p]

set_false_path -to [get_ports {phy_reset_n}]
set_output_delay 0 [get_ports {phy_reset_n}]
set_false_path -from [get_ports {phy_int_n}]
set_input_delay 0 [get_ports {phy_int_n}]

#set_false_path -to [get_ports {phy_mdio phy_mdc}]
#set_output_delay 0 [get_ports {phy_mdio phy_mdc}]
#set_false_path -from [get_ports {phy_mdio}]
#set_input_delay 0 [get_ports {phy_mdio}]

# SFP+ interface
set_property -dict {LOC T2  } [get_ports {sfp_rx_p[0]}] ;# MGTYRXP2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC T1  } [get_ports {sfp_rx_n[0]}] ;# MGTYRXN2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC U4  } [get_ports {sfp_tx_p[0]}] ;# MGTYTXP2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC U3  } [get_ports {sfp_tx_n[0]}] ;# MGTYTXN2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC V2  } [get_ports {sfp_rx_p[1]}] ;# MGTYRXP1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC V1  } [get_ports {sfp_rx_n[1]}] ;# MGTYRXN1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC W4  } [get_ports {sfp_tx_p[1]}] ;# MGTYTXP1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC W3  } [get_ports {sfp_tx_n[1]}] ;# MGTYTXN1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC P6  } [get_ports sfp_mgt_refclk_0_p] ;# MGTREFCLK0P_227 from U32 Si570 via U104 Si53340
set_property -dict {LOC P5  } [get_ports sfp_mgt_refclk_0_n] ;# MGTREFCLK0N_227 from U32 Si570 via U104 Si53340
#set_property -dict {LOC M6  } [get_ports sfp_mgt_refclk_1_p] ;# MGTREFCLK1P_227 from U57 Si5328B
#set_property -dict {LOC M5  } [get_ports sfp_mgt_refclk_1_n] ;# MGTREFCLK1N_227 from U57 Si5328B
#set_property -dict {LOC AG11 IOSTANDARD LVDS} [get_ports sfp_recclk_p] ;# to U57 CKIN1 SI5328
#set_property -dict {LOC AH11 IOSTANDARD LVDS} [get_ports sfp_recclk_n] ;# to U57 CKIN1 SI5328

set_property -dict {LOC AL8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {sfp_tx_disable_b[0]}]
set_property -dict {LOC K21  IOSTANDARD LVCMOS18} [get_ports {sfp_rx_los[0]}]
set_property -dict {LOC D28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {sfp_tx_disable_b[1]}]
set_property -dict {LOC AM9  IOSTANDARD LVCMOS18} [get_ports {sfp_rx_los[1]}]

# 156.25 MHz MGT reference clock
create_clock -period 6.400 -name sfp_mgt_refclk_0 [get_ports sfp_mgt_refclk_0_p]
#create_clock -period 6.400 -name sfp_mgt_refclk_1 [get_ports sfp_mgt_refclk_1_p]

set_false_path -to [get_ports {sfp_tx_disable_b[*]}]
set_output_delay 0 [get_ports {sfp_tx_disable_b[*]}]

# PCIe Interface
#set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[0]}] ;# MGTHRXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[0]}] ;# MGTHRXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AC4 } [get_ports {pcie_tx_p[0]}] ;# MGTHTXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AC3 } [get_ports {pcie_tx_n[0]}] ;# MGTHTXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[1]}] ;# MGTHRXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[1]}] ;# MGTHRXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AE4 } [get_ports {pcie_tx_p[1]}] ;# MGTHTXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AE3 } [get_ports {pcie_tx_n[1]}] ;# MGTHTXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[2]}] ;# MGTHRXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[2]}] ;# MGTHRXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AG4 } [get_ports {pcie_tx_p[2]}] ;# MGTHTXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AG3 } [get_ports {pcie_tx_n[2]}] ;# MGTHTXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AH2 } [get_ports {pcie_rx_p[3]}] ;# MGTHRXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AH1 } [get_ports {pcie_rx_n[3]}] ;# MGTHRXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AH6 } [get_ports {pcie_tx_p[3]}] ;# MGTHTXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AH5 } [get_ports {pcie_tx_n[3]}] ;# MGTHTXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[4]}] ;# MGTHRXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[4]}] ;# MGTHRXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AK6 } [get_ports {pcie_tx_p[4]}] ;# MGTHTXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AK5 } [get_ports {pcie_tx_n[4]}] ;# MGTHTXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AK2 } [get_ports {pcie_rx_p[5]}] ;# MGTHRXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AK1 } [get_ports {pcie_rx_n[5]}] ;# MGTHRXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AL4 } [get_ports {pcie_tx_p[5]}] ;# MGTHTXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AL3 } [get_ports {pcie_tx_n[5]}] ;# MGTHTXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AM2 } [get_ports {pcie_rx_p[6]}] ;# MGTHRXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AM1 } [get_ports {pcie_rx_n[6]}] ;# MGTHRXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AM6 } [get_ports {pcie_tx_p[6]}] ;# MGTHTXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AM5 } [get_ports {pcie_tx_n[6]}] ;# MGTHTXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AP2 } [get_ports {pcie_rx_p[7]}] ;# MGTHRXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AP1 } [get_ports {pcie_rx_n[7]}] ;# MGTHRXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AN4 } [get_ports {pcie_tx_p[7]}] ;# MGTHTXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AN3 } [get_ports {pcie_tx_n[7]}] ;# MGTHTXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AB6 } [get_ports pcie_mgt_refclk_p] ;# MGTREFCLK0P_225
#set_property -dict {LOC AB5 } [get_ports pcie_mgt_refclk_n] ;# MGTREFCLK0N_225
#set_property -dict {LOC K22  IOSTANDARD LVCMOS18 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
#create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_mgt_refclk_p]

#set_false_path -from [get_ports {pcie_reset_n}]
#set_input_delay 0 [get_ports {pcie_reset_n}]

# FMC interface
# FMC HPC J22
#set_property -dict {LOC H11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[0]"]  ;# J22.G9  LA00_P_CC
#set_property -dict {LOC G11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[0]"]  ;# J22.G10 LA00_N_CC
#set_property -dict {LOC G9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[1]"]  ;# J22.D8  LA01_P_CC
#set_property -dict {LOC F9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[1]"]  ;# J22.D9  LA01_N_CC
#set_property -dict {LOC K10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[2]"]  ;# J22.H7  LA02_P
#set_property -dict {LOC J10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[2]"]  ;# J22.H8  LA02_N
#set_property -dict {LOC A13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[3]"]  ;# J22.G12 LA03_P
#set_property -dict {LOC A12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[3]"]  ;# J22.G13 LA03_N
#set_property -dict {LOC L12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[4]"]  ;# J22.H10 LA04_P
#set_property -dict {LOC K12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[4]"]  ;# J22.H11 LA04_N
#set_property -dict {LOC L13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[5]"]  ;# J22.D11 LA05_P
#set_property -dict {LOC K13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[5]"]  ;# J22.D12 LA05_N
#set_property -dict {LOC D13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[6]"]  ;# J22.C10 LA06_P
#set_property -dict {LOC C13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[6]"]  ;# J22.C11 LA06_N
#set_property -dict {LOC F8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[7]"]  ;# J22.H13 LA07_P
#set_property -dict {LOC E8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[7]"]  ;# J22.H14 LA07_N
#set_property -dict {LOC J8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[8]"]  ;# J22.G12 LA08_P
#set_property -dict {LOC H8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[8]"]  ;# J22.G13 LA08_N
#set_property -dict {LOC J9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[9]"]  ;# J22.D14 LA09_P
#set_property -dict {LOC H9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[9]"]  ;# J22.D15 LA09_N
#set_property -dict {LOC L8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[10]"] ;# J22.C14 LA10_P
#set_property -dict {LOC K8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[10]"] ;# J22.C15 LA10_N
#set_property -dict {LOC K11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[11]"] ;# J22.H16 LA11_P
#set_property -dict {LOC J11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[11]"] ;# J22.H17 LA11_N
#set_property -dict {LOC E10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[12]"] ;# J22.G15 LA12_P
#set_property -dict {LOC D10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[12]"] ;# J22.G16 LA12_N
#set_property -dict {LOC D9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[13]"] ;# J22.D17 LA13_P
#set_property -dict {LOC C9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[13]"] ;# J22.D18 LA13_N
#set_property -dict {LOC B10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[14]"] ;# J22.C18 LA14_P
#set_property -dict {LOC A10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[14]"] ;# J22.C19 LA14_N
#set_property -dict {LOC D8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[15]"] ;# J22.H19 LA15_P
#set_property -dict {LOC C8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[15]"] ;# J22.H20 LA15_N
#set_property -dict {LOC B9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[16]"] ;# J22.G18 LA16_P
#set_property -dict {LOC A9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[16]"] ;# J22.G19 LA16_N
#set_property -dict {LOC D24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[17]"] ;# J22.D20 LA17_P_CC
#set_property -dict {LOC C24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[17]"] ;# J22.D21 LA17_N_CC
#set_property -dict {LOC E22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[18]"] ;# J22.C22 LA18_P_CC
#set_property -dict {LOC E23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[18]"] ;# J22.C23 LA18_N_CC
#set_property -dict {LOC C21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[19]"] ;# J22.H22 LA19_P
#set_property -dict {LOC C22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[19]"] ;# J22.H23 LA19_N
#set_property -dict {LOC B24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[20]"] ;# J22.G21 LA20_P
#set_property -dict {LOC A24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[20]"] ;# J22.G22 LA20_N
#set_property -dict {LOC F23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[21]"] ;# J22.H25 LA21_P
#set_property -dict {LOC F24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[21]"] ;# J22.H26 LA21_N
#set_property -dict {LOC G24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[22]"] ;# J22.G24 LA22_P
#set_property -dict {LOC F25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[22]"] ;# J22.G25 LA22_N
#set_property -dict {LOC G22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[23]"] ;# J22.D23 LA23_P
#set_property -dict {LOC F22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[23]"] ;# J22.D24 LA23_N
#set_property -dict {LOC E20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[24]"] ;# J22.H28 LA24_P
#set_property -dict {LOC E21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[24]"] ;# J22.H29 LA24_N
#set_property -dict {LOC D20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[25]"] ;# J22.G27 LA25_P
#set_property -dict {LOC D21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[25]"] ;# J22.G28 LA25_N
#set_property -dict {LOC G20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[26]"] ;# J22.D26 LA26_P
#set_property -dict {LOC F20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[26]"] ;# J22.D27 LA26_N
#set_property -dict {LOC H21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[27]"] ;# J22.C26 LA27_P
#set_property -dict {LOC G21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[27]"] ;# J22.C27 LA27_N
#set_property -dict {LOC B21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[28]"] ;# J22.H31 LA28_P
#set_property -dict {LOC B22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[28]"] ;# J22.H32 LA28_N
#set_property -dict {LOC B20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[29]"] ;# J22.G30 LA29_P
#set_property -dict {LOC A20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[29]"] ;# J22.G31 LA29_N
#set_property -dict {LOC C26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[30]"] ;# J22.H34 LA30_P
#set_property -dict {LOC B26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[30]"] ;# J22.H35 LA30_N
#set_property -dict {LOC B25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[31]"] ;# J22.G33 LA31_P
#set_property -dict {LOC A25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[31]"] ;# J22.G34 LA31_N
#set_property -dict {LOC E26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[32]"] ;# J22.H37 LA32_P
#set_property -dict {LOC D26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[32]"] ;# J22.H38 LA32_N
#set_property -dict {LOC A27  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[33]"] ;# J22.G36 LA33_P
#set_property -dict {LOC A28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[33]"] ;# J22.G37 LA33_N

#set_property -dict {LOC G17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[0]"]  ;# J22.F4  HA00_P_CC
#set_property -dict {LOC G16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[0]"]  ;# J22.F5  HA00_N_CC
#set_property -dict {LOC E16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[1]"]  ;# J22.E2  HA01_P_CC
#set_property -dict {LOC D16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[1]"]  ;# J22.E3  HA01_N_CC
#set_property -dict {LOC H19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[2]"]  ;# J22.K7  HA02_P
#set_property -dict {LOC H18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[2]"]  ;# J22.K8  HA02_N
#set_property -dict {LOC G15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[3]"]  ;# J22.J6  HA03_P
#set_property -dict {LOC G14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[3]"]  ;# J22.J7  HA03_N
#set_property -dict {LOC G19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[4]"]  ;# J22.F7  HA04_P
#set_property -dict {LOC F19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[4]"]  ;# J22.F8  HA04_N
#set_property -dict {LOC J15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[5]"]  ;# J22.E6  HA05_P
#set_property -dict {LOC J14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[5]"]  ;# J22.E7  HA05_N
#set_property -dict {LOC L15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[6]"]  ;# J22.K10 HA06_P
#set_property -dict {LOC K15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[6]"]  ;# J22.K11 HA06_N
#set_property -dict {LOC L19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[7]"]  ;# J22.J9  HA07_P
#set_property -dict {LOC L18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[7]"]  ;# J22.J10 HA07_N
#set_property -dict {LOC K18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[8]"]  ;# J22.F10 HA08_P
#set_property -dict {LOC K17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[8]"]  ;# J22.F11 HA08_N
#set_property -dict {LOC F18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[9]"]  ;# J22.E9  HA09_P
#set_property -dict {LOC F17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[9]"]  ;# J22.E10 HA09_N
#set_property -dict {LOC H17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[10]"] ;# J22.K13 HA10_P
#set_property -dict {LOC H16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[10]"] ;# J22.K14 HA10_N
#set_property -dict {LOC J19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[11]"] ;# J22.J12 HA11_P
#set_property -dict {LOC J18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[11]"] ;# J22.J13 HA11_N
#set_property -dict {LOC K16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[12]"] ;# J22.F13 HA12_P
#set_property -dict {LOC J16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[12]"] ;# J22.F14 HA12_N
#set_property -dict {LOC B14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[13]"] ;# J22.E12 HA13_P
#set_property -dict {LOC A14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[13]"] ;# J22.E13 HA13_N
#set_property -dict {LOC F15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[14]"] ;# J22.J15 HA14_P
#set_property -dict {LOC F14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[14]"] ;# J22.J16 HA14_N
#set_property -dict {LOC D14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[15]"] ;# J22.F14 HA15_P
#set_property -dict {LOC C14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[15]"] ;# J22.F16 HA15_N
#set_property -dict {LOC A19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[16]"] ;# J22.E15 HA16_P
#set_property -dict {LOC A18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[16]"] ;# J22.E16 HA16_N
#set_property -dict {LOC E18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[17]"] ;# J22.K16 HA17_P_CC
#set_property -dict {LOC E17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[17]"] ;# J22.K17 HA17_N_CC
#set_property -dict {LOC B17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[18]"] ;# J22.J18 HA18_P_CC
#set_property -dict {LOC B16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[18]"] ;# J22.J19 HA18_N_CC
#set_property -dict {LOC D19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[19]"] ;# J22.F19 HA19_P
#set_property -dict {LOC D18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[19]"] ;# J22.F20 HA19_N
#set_property -dict {LOC C19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[20]"] ;# J22.E18 HA20_P
#set_property -dict {LOC B19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[20]"] ;# J22.E19 HA20_N
#set_property -dict {LOC E15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[21]"] ;# J22.K19 HA21_P
#set_property -dict {LOC D15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[21]"] ;# J22.K20 HA21_N
#set_property -dict {LOC C18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[22]"] ;# J22.J21 HA22_P
#set_property -dict {LOC C17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[22]"] ;# J22.J22 HA22_N
#set_property -dict {LOC B15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[23]"] ;# J22.K22 HA23_P
#set_property -dict {LOC A15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[23]"] ;# J22.K23 HA23_N

#set_property -dict {LOC H12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk0_m2c_p"] ;# J22.H4 CLK0_M2C_P
#set_property -dict {LOC G12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk0_m2c_n"] ;# J22.H5 CLK0_M2C_N
#set_property -dict {LOC E25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk1_m2c_p"] ;# J22.G2 CLK1_M2C_P
#set_property -dict {LOC D25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk1_m2c_n"] ;# J22.G3 CLK1_M2C_N

#set_property -dict {LOC L27  IOSTANDARD LVCMOS18} [get_ports {fmc_hpc_pg_m2c}]      ;# J22.F1 PG_M2C
#set_property -dict {LOC H24  IOSTANDARD LVCMOS18} [get_ports {fmc_hpc_prsnt_m2c_l}] ;# J22.H2 PRSNT_M2C_L

#set_property -dict {LOC F6} [get_ports {fmc_hpc_dp_c2m_p[0]}] ;# MGTHTXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C2  DP0_C2M_P
#set_property -dict {LOC F5} [get_ports {fmc_hpc_dp_c2m_n[0]}] ;# MGTHTXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C3  DP0_C2M_N
#set_property -dict {LOC E4} [get_ports {fmc_hpc_dp_m2c_p[0]}] ;# MGTHRXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C6  DP0_M2C_P
#set_property -dict {LOC E3} [get_ports {fmc_hpc_dp_m2c_n[0]}] ;# MGTHRXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C7  DP0_M2C_N
#set_property -dict {LOC D6} [get_ports {fmc_hpc_dp_c2m_p[1]}] ;# MGTHTXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A22 DP1_C2M_P
#set_property -dict {LOC D5} [get_ports {fmc_hpc_dp_c2m_n[1]}] ;# MGTHTXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A23 DP1_C2M_N
#set_property -dict {LOC D2} [get_ports {fmc_hpc_dp_m2c_p[1]}] ;# MGTHRXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A2  DP1_M2C_P
#set_property -dict {LOC D1} [get_ports {fmc_hpc_dp_m2c_n[1]}] ;# MGTHRXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A3  DP1_M2C_N
#set_property -dict {LOC C4} [get_ports {fmc_hpc_dp_c2m_p[2]}] ;# MGTHTXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A26 DP2_C2M_P
#set_property -dict {LOC C3} [get_ports {fmc_hpc_dp_c2m_n[2]}] ;# MGTHTXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A27 DP2_C2M_N
#set_property -dict {LOC B2} [get_ports {fmc_hpc_dp_m2c_p[2]}] ;# MGTHRXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A6  DP2_M2C_P
#set_property -dict {LOC B1} [get_ports {fmc_hpc_dp_m2c_n[2]}] ;# MGTHRXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A7  DP2_M2C_N
#set_property -dict {LOC B6} [get_ports {fmc_hpc_dp_c2m_p[3]}] ;# MGTHTXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A30 DP3_C2M_P
#set_property -dict {LOC B5} [get_ports {fmc_hpc_dp_c2m_n[3]}] ;# MGTHTXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A31 DP3_C2M_N
#set_property -dict {LOC A4} [get_ports {fmc_hpc_dp_m2c_p[3]}] ;# MGTHRXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A10 DP3_M2C_P
#set_property -dict {LOC A3} [get_ports {fmc_hpc_dp_m2c_n[3]}] ;# MGTHRXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A11 DP3_M2C_N
#set_property -dict {LOC K6  } [get_ports fmc_hpc_mgt_refclk_0_p] ;# MGTREFCLK0P_228 from J22.D4 GBTCLK0_M2C_P
#set_property -dict {LOC K5  } [get_ports fmc_hpc_mgt_refclk_0_n] ;# MGTREFCLK0N_228 from J22.D5 GBTCLK0_M2C_N
#set_property -dict {LOC H6  } [get_ports fmc_hpc_mgt_refclk_1_p] ;# MGTREFCLK1P_228 from J22.B20 GBTCLK1_M2C_P
#set_property -dict {LOC H5  } [get_ports fmc_hpc_mgt_refclk_1_n] ;# MGTREFCLK1N_228 from J22.B21 GBTCLK1_M2C_N

#set_property -dict {LOC N4} [get_ports {fmc_hpc_dp_c2m_p[4]}] ;# MGTHTXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A34 DP4_C2M_P
#set_property -dict {LOC N3} [get_ports {fmc_hpc_dp_c2m_n[4]}] ;# MGTHTXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A35 DP4_C2M_N
#set_property -dict {LOC M2} [get_ports {fmc_hpc_dp_m2c_p[4]}] ;# MGTHRXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A14 DP4_M2C_P
#set_property -dict {LOC M1} [get_ports {fmc_hpc_dp_m2c_n[4]}] ;# MGTHRXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A15 DP4_M2C_N
#set_property -dict {LOC J4} [get_ports {fmc_hpc_dp_c2m_p[5]}] ;# MGTHTXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B36 DP5_C2M_P
#set_property -dict {LOC J3} [get_ports {fmc_hpc_dp_c2m_n[5]}] ;# MGTHTXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B37 DP5_C2M_N
#set_property -dict {LOC H2} [get_ports {fmc_hpc_dp_m2c_p[5]}] ;# MGTHRXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B16 DP5_M2C_P
#set_property -dict {LOC H1} [get_ports {fmc_hpc_dp_m2c_n[5]}] ;# MGTHRXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B17 DP5_M2C_N
#set_property -dict {LOC L4} [get_ports {fmc_hpc_dp_c2m_p[6]}] ;# MGTHTXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A38 DP6_C2M_P
#set_property -dict {LOC L3} [get_ports {fmc_hpc_dp_c2m_n[6]}] ;# MGTHTXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A39 DP6_C2M_N
#set_property -dict {LOC K2} [get_ports {fmc_hpc_dp_m2c_p[6]}] ;# MGTHRXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A18 DP6_M2C_P
#set_property -dict {LOC K1} [get_ports {fmc_hpc_dp_m2c_n[6]}] ;# MGTHRXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A19 DP6_M2C_N
#set_property -dict {LOC G4} [get_ports {fmc_hpc_dp_c2m_p[7]}] ;# MGTHTXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B32 DP7_C2M_P
#set_property -dict {LOC G3} [get_ports {fmc_hpc_dp_c2m_n[7]}] ;# MGTHTXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B33 DP7_C2M_N
#set_property -dict {LOC F2} [get_ports {fmc_hpc_dp_m2c_p[7]}] ;# MGTHRXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B12 DP7_M2C_P
#set_property -dict {LOC F1} [get_ports {fmc_hpc_dp_m2c_n[7]}] ;# MGTHRXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B13 DP7_M2C_N

# reference clock
#create_clock -period 6.400 -name fmc_hpc_mgt_refclk_0 [get_ports fmc_hpc_mgt_refclk_0_p]
#create_clock -period 6.400 -name fmc_hpc_mgt_refclk_1 [get_ports fmc_hpc_mgt_refclk_1_p]

# FMC LPC J2
#set_property -dict {LOC W23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[0]"]  ;# J2.G9  LA00_P_CC
#set_property -dict {LOC W24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[0]"]  ;# J2.G10 LA00_N_CC
#set_property -dict {LOC W25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[1]"]  ;# J2.D8  LA01_P_CC
#set_property -dict {LOC Y25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[1]"]  ;# J2.D9  LA01_N_CC
#set_property -dict {LOC AA22 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[2]"]  ;# J2.H7  LA02_P
#set_property -dict {LOC AB22 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[2]"]  ;# J2.H8  LA02_N
#set_property -dict {LOC W28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[3]"]  ;# J2.G12 LA03_P
#set_property -dict {LOC Y28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[3]"]  ;# J2.G13 LA03_N
#set_property -dict {LOC U26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[4]"]  ;# J2.H10 LA04_P
#set_property -dict {LOC U27  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[4]"]  ;# J2.H11 LA04_N
#set_property -dict {LOC V27  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[5]"]  ;# J2.D11 LA05_P
#set_property -dict {LOC V28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[5]"]  ;# J2.D12 LA05_N
#set_property -dict {LOC V29  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[6]"]  ;# J2.C10 LA06_P
#set_property -dict {LOC W29  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[6]"]  ;# J2.C11 LA06_N
#set_property -dict {LOC V22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[7]"]  ;# J2.H13 LA07_P
#set_property -dict {LOC V23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[7]"]  ;# J2.H14 LA07_N
#set_property -dict {LOC U24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[8]"]  ;# J2.G12 LA08_P
#set_property -dict {LOC U25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[8]"]  ;# J2.G13 LA08_N
#set_property -dict {LOC V26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[9]"]  ;# J2.D14 LA09_P
#set_property -dict {LOC W26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[9]"]  ;# J2.D15 LA09_N
#set_property -dict {LOC T22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[10]"] ;# J2.C14 LA10_P
#set_property -dict {LOC T23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[10]"] ;# J2.C15 LA10_N
#set_property -dict {LOC V21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[11]"] ;# J2.H16 LA11_P
#set_property -dict {LOC W21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[11]"] ;# J2.H17 LA11_N
#set_property -dict {LOC AC22 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[12]"] ;# J2.G15 LA12_P
#set_property -dict {LOC AC23 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[12]"] ;# J2.G16 LA12_N
#set_property -dict {LOC AA20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[13]"] ;# J2.D17 LA13_P
#set_property -dict {LOC AB20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[13]"] ;# J2.D18 LA13_N
#set_property -dict {LOC U21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[14]"] ;# J2.C18 LA14_P
#set_property -dict {LOC U22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[14]"] ;# J2.C19 LA14_N
#set_property -dict {LOC AB25 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[15]"] ;# J2.H19 LA15_P
#set_property -dict {LOC AB26 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[15]"] ;# J2.H20 LA15_N
#set_property -dict {LOC AB21 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[16]"] ;# J2.G18 LA16_P
#set_property -dict {LOC AC21 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[16]"] ;# J2.G19 LA16_N
#set_property -dict {LOC AA32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[17]"] ;# J2.D20 LA17_P_CC
#set_property -dict {LOC AB32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[17]"] ;# J2.D21 LA17_N_CC
#set_property -dict {LOC AB30 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[18]"] ;# J2.C22 LA18_P_CC
#set_property -dict {LOC AB31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[18]"] ;# J2.C23 LA18_N_CC
#set_property -dict {LOC AA29 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[19]"] ;# J2.H22 LA19_P
#set_property -dict {LOC AB29 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[19]"] ;# J2.H23 LA19_N
#set_property -dict {LOC AA34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[20]"] ;# J2.G21 LA20_P
#set_property -dict {LOC AB34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[20]"] ;# J2.G22 LA20_N
#set_property -dict {LOC AC33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[21]"] ;# J2.H25 LA21_P
#set_property -dict {LOC AD33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[21]"] ;# J2.H26 LA21_N
#set_property -dict {LOC AC34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[22]"] ;# J2.G24 LA22_P
#set_property -dict {LOC AD34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[22]"] ;# J2.G25 LA22_N
#set_property -dict {LOC AD30 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[23]"] ;# J2.D23 LA23_P
#set_property -dict {LOC AD31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[23]"] ;# J2.D24 LA23_N
#set_property -dict {LOC AE32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[24]"] ;# J2.H28 LA24_P
#set_property -dict {LOC AF32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[24]"] ;# J2.H29 LA24_N
#set_property -dict {LOC AE33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[25]"] ;# J2.G27 LA25_P
#set_property -dict {LOC AF34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[25]"] ;# J2.G28 LA25_N
#set_property -dict {LOC AF33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[26]"] ;# J2.D26 LA26_P
#set_property -dict {LOC AG34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[26]"] ;# J2.D27 LA26_N
#set_property -dict {LOC AG31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[27]"] ;# J2.C26 LA27_P
#set_property -dict {LOC AG32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[27]"] ;# J2.C27 LA27_N
#set_property -dict {LOC V31  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[28]"] ;# J2.H31 LA28_P
#set_property -dict {LOC W31  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[28]"] ;# J2.H32 LA28_N
#set_property -dict {LOC U34  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[29]"] ;# J2.G30 LA29_P
#set_property -dict {LOC V34  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[29]"] ;# J2.G31 LA29_N
#set_property -dict {LOC Y31  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[30]"] ;# J2.H34 LA30_P
#set_property -dict {LOC Y32  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[30]"] ;# J2.H35 LA30_N
#set_property -dict {LOC V33  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[31]"] ;# J2.G33 LA31_P
#set_property -dict {LOC W34  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[31]"] ;# J2.G34 LA31_N
#set_property -dict {LOC W30  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[32]"] ;# J2.H37 LA32_P
#set_property -dict {LOC Y30  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[32]"] ;# J2.H38 LA32_N
#set_property -dict {LOC W33  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[33]"] ;# J2.G36 LA33_P
#set_property -dict {LOC Y33  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[33]"] ;# J2.G37 LA33_N

#set_property -dict {LOC AA24 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk0_m2c_p"] ;# J2.H4 CLK0_M2C_P
#set_property -dict {LOC AA25 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk0_m2c_n"] ;# J2.H5 CLK0_M2C_N
#set_property -dict {LOC AC31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk1_m2c_p"] ;# J2.G2 CLK1_M2C_P
#set_property -dict {LOC AC32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk1_m2c_n"] ;# J2.G3 CLK1_M2C_N

#set_property -dict {LOC J26  IOSTANDARD LVCMOS18} [get_ports {fmc_lpc_prsnt_m2c_l}] ;# J2.H2 PRSNT_M2C_L

#set_property -dict {LOC AA4 } [get_ports {fmc_lpc_dp_c2m_p[0]}] ;# MGTHTXP0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C2  DP0_C2M_P
#set_property -dict {LOC AA3 } [get_ports {fmc_lpc_dp_c2m_n[0]}] ;# MGTHTXN0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C3  DP0_C2M_N
#set_property -dict {LOC Y2  } [get_ports {fmc_lpc_dp_m2c_p[0]}] ;# MGTHRXP0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C6  DP0_M2C_P
#set_property -dict {LOC Y1  } [get_ports {fmc_lpc_dp_m2c_n[0]}] ;# MGTHRXN0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C7  DP0_M2C_N
#set_property -dict {LOC T6  } [get_ports fmc_lpc_mgt_refclk_p] ;# MGTREFCLK1P_226 from J2.D4 GBTCLK0_M2C_P
#set_property -dict {LOC T5  } [get_ports fmc_lpc_mgt_refclk_n] ;# MGTREFCLK1N_226 from J2.D5 GBTCLK0_M2C_N

# reference clock
#create_clock -period 6.400 -name fmc_lpc_mgt_refclk [get_ports fmc_lpc_mgt_refclk_p]

# DDR4 C1
# 4x MT40A256M16GE-075E
#set_property -dict {LOC AE17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[0]}]
#set_property -dict {LOC AH17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[1]}]
#set_property -dict {LOC AE18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[2]}]
#set_property -dict {LOC AJ15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[3]}]
#set_property -dict {LOC AG16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[4]}]
#set_property -dict {LOC AL17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[5]}]
#set_property -dict {LOC AK18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[6]}]
#set_property -dict {LOC AG17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[7]}]
#set_property -dict {LOC AF18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[8]}]
#set_property -dict {LOC AH19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[9]}]
#set_property -dict {LOC AF15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[10]}]
#set_property -dict {LOC AD19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[11]}]
#set_property -dict {LOC AJ14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[12]}]
#set_property -dict {LOC AG19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[13]}]
#set_property -dict {LOC AD16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[14]}]
#set_property -dict {LOC AG14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[15]}]
#set_property -dict {LOC AF14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[16]}]
#set_property -dict {LOC AF17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_ba[0]}]
#set_property -dict {LOC AL15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_ba[1]}]
#set_property -dict {LOC AG15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_bg[0]}]
#set_property -dict {LOC AE16 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c1_ck_t}]
#set_property -dict {LOC AE15 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c1_ck_c}]
#set_property -dict {LOC AD15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_cke}]
#set_property -dict {LOC AL19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_cs_n}]
#set_property -dict {LOC AH14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_act_n}]
#set_property -dict {LOC AJ18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_odt}]
#set_property -dict {LOC AD18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_par}]
#set_property -dict {LOC AL18 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c1_reset_n}]
#set_property -dict {LOC AJ16 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c1_alert_n}]
#set_property -dict {LOC AH16 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c1_ten}]

#set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[0]}]       ;# U60.G2 DQL0
#set_property -dict {LOC AG20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[1]}]       ;# U60.F7 DQL1
#set_property -dict {LOC AF22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[2]}]       ;# U60.H3 DQL2
#set_property -dict {LOC AF20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[3]}]       ;# U60.H7 DQL3
#set_property -dict {LOC AE22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[4]}]       ;# U60.H2 DQL4
#set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[5]}]       ;# U60.H8 DQL5
#set_property -dict {LOC AG22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[6]}]       ;# U60.J3 DQL6
#set_property -dict {LOC AE20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[7]}]       ;# U60.J7 DQL7
#set_property -dict {LOC AJ24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[8]}]       ;# U60.A3 DQU0
#set_property -dict {LOC AG24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[9]}]       ;# U60.B8 DQU1
#set_property -dict {LOC AJ23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[10]}]      ;# U60.C3 DQU2
#set_property -dict {LOC AF23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[11]}]      ;# U60.C7 DQU3
#set_property -dict {LOC AH23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[12]}]      ;# U60.C2 DQU4
#set_property -dict {LOC AF24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[13]}]      ;# U60.C8 DQU5
#set_property -dict {LOC AH22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[14]}]      ;# U60.D3 DQU6
#set_property -dict {LOC AG25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[15]}]      ;# U60.D7 DQU7
#set_property -dict {LOC AG21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[0]}]    ;# U60.G3 DQSL_T
#set_property -dict {LOC AH21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[0]}]    ;# U60.F3 DQSL_C
#set_property -dict {LOC AH24 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[1]}]    ;# U60.B7 DQSU_T
#set_property -dict {LOC AJ25 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[1]}]    ;# U60.A7 DQSU_C
#set_property -dict {LOC AD21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[0]}] ;# U60.E7 DML_B/DBIL_B
#set_property -dict {LOC AE25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[1]}] ;# U60.E2 DMU_B/DBIU_B

#set_property -dict {LOC AL22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[16]}]      ;# U61.G2 DQL0
#set_property -dict {LOC AL25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[17]}]      ;# U61.F7 DQL1
#set_property -dict {LOC AM20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[18]}]      ;# U61.H3 DQL2
#set_property -dict {LOC AK23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[19]}]      ;# U61.H7 DQL3
#set_property -dict {LOC AK22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[20]}]      ;# U61.H2 DQL4
#set_property -dict {LOC AL24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[21]}]      ;# U61.H8 DQL5
#set_property -dict {LOC AL20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[22]}]      ;# U61.J3 DQL6
#set_property -dict {LOC AL23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[23]}]      ;# U61.J7 DQL7
#set_property -dict {LOC AM24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[24]}]      ;# U61.A3 DQU0
#set_property -dict {LOC AN23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[25]}]      ;# U61.B8 DQU1
#set_property -dict {LOC AN24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[26]}]      ;# U61.C3 DQU2
#set_property -dict {LOC AP23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[27]}]      ;# U61.C7 DQU3
#set_property -dict {LOC AP25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[28]}]      ;# U61.C2 DQU4
#set_property -dict {LOC AN22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[29]}]      ;# U61.C8 DQU5
#set_property -dict {LOC AP24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[30]}]      ;# U61.D3 DQU6
#set_property -dict {LOC AM22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[31]}]      ;# U61.D7 DQU7
#set_property -dict {LOC AJ20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[2]}]    ;# U61.G3 DQSL_T
#set_property -dict {LOC AK20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[2]}]    ;# U61.F3 DQSL_C
#set_property -dict {LOC AP20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[3]}]    ;# U61.B7 DQSU_T
#set_property -dict {LOC AP21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[3]}]    ;# U61.A7 DQSU_C
#set_property -dict {LOC AJ21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[2]}] ;# U61.E7 DML_B/DBIL_B
#set_property -dict {LOC AM21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[3]}] ;# U61.E2 DMU_B/DBIU_B

#set_property -dict {LOC AH28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[32]}]      ;# U62.G2 DQL0
#set_property -dict {LOC AK26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[33]}]      ;# U62.F7 DQL1
#set_property -dict {LOC AK28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[34]}]      ;# U62.H3 DQL2
#set_property -dict {LOC AM27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[35]}]      ;# U62.H7 DQL3
#set_property -dict {LOC AJ28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[36]}]      ;# U62.H2 DQL4
#set_property -dict {LOC AH27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[37]}]      ;# U62.H8 DQL5
#set_property -dict {LOC AK27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[38]}]      ;# U62.J3 DQL6
#set_property -dict {LOC AM26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[39]}]      ;# U62.J7 DQL7
#set_property -dict {LOC AL30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[40]}]      ;# U62.A3 DQU0
#set_property -dict {LOC AP29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[41]}]      ;# U62.B8 DQU1
#set_property -dict {LOC AM30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[42]}]      ;# U62.C3 DQU2
#set_property -dict {LOC AN28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[43]}]      ;# U62.C7 DQU3
#set_property -dict {LOC AL29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[44]}]      ;# U62.C2 DQU4
#set_property -dict {LOC AP28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[45]}]      ;# U62.C8 DQU5
#set_property -dict {LOC AM29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[46]}]      ;# U62.D3 DQU6
#set_property -dict {LOC AN27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[47]}]      ;# U62.D7 DQU7
#set_property -dict {LOC AL27 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[4]}]    ;# U62.G3 DQSL_T
#set_property -dict {LOC AL28 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[4]}]    ;# U62.F3 DQSL_C
#set_property -dict {LOC AN29 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[5]}]    ;# U62.B7 DQSU_T
#set_property -dict {LOC AP30 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[5]}]    ;# U62.A7 DQSU_C
#set_property -dict {LOC AH26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[4]}] ;# U62.E7 DML_B/DBIL_B
#set_property -dict {LOC AN26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[5]}] ;# U62.E2 DMU_B/DBIU_B

#set_property -dict {LOC AH31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[48]}]      ;# U63.G2 DQL0
#set_property -dict {LOC AH32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[49]}]      ;# U63.F7 DQL1
#set_property -dict {LOC AJ34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[50]}]      ;# U63.H3 DQL2
#set_property -dict {LOC AK31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[51]}]      ;# U63.H7 DQL3
#set_property -dict {LOC AJ31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[52]}]      ;# U63.H2 DQL4
#set_property -dict {LOC AJ30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[53]}]      ;# U63.H8 DQL5
#set_property -dict {LOC AH34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[54]}]      ;# U63.J3 DQL6
#set_property -dict {LOC AK32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[55]}]      ;# U63.J7 DQL7
#set_property -dict {LOC AN33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[56]}]      ;# U63.A3 DQU0
#set_property -dict {LOC AP33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[57]}]      ;# U63.B8 DQU1
#set_property -dict {LOC AM34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[58]}]      ;# U63.C3 DQU2
#set_property -dict {LOC AP31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[59]}]      ;# U63.C7 DQU3
#set_property -dict {LOC AM32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[60]}]      ;# U63.C2 DQU4
#set_property -dict {LOC AN31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[61]}]      ;# U63.C8 DQU5
#set_property -dict {LOC AL34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[62]}]      ;# U63.D3 DQU6
#set_property -dict {LOC AN32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[63]}]      ;# U63.D7 DQU7
#set_property -dict {LOC AH33 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[6]}]    ;# U63.G3 DQSL_T
#set_property -dict {LOC AJ33 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[6]}]    ;# U63.F3 DQSL_C
#set_property -dict {LOC AN34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[7]}]    ;# U63.B7 DQSU_T
#set_property -dict {LOC AP34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[7]}]    ;# U63.A7 DQSU_C
#set_property -dict {LOC AJ29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[6]}] ;# U63.E7 DML_B/DBIL_B
#set_property -dict {LOC AL32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[7]}] ;# U63.E2 DMU_B/DBIU_B

# QSPI flash
#set_property -dict {LOC M20  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[0]}]
#set_property -dict {LOC L20  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[1]}]
#set_property -dict {LOC R21  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[2]}]
#set_property -dict {LOC R22  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[3]}]
#set_property -dict {LOC G26  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_cs}]

#set_false_path -to [get_ports {qspi_1_dq[*] qspi_1_cs}]
#set_output_delay 0 [get_ports {qspi_1_dq[*] qspi_1_cs}]
#set_false_path -from [get_ports {qspi_1_dq}]
#set_input_delay 0 [get_ports {qspi_1_dq}]
