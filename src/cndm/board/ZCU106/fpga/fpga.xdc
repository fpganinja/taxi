# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx ZCU106 board
# part: xczu7ev-ffvc1156-2-e

# General configuration
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]

# System clocks
# 125 MHz
set_property -dict {LOC H9  IOSTANDARD LVDS} [get_ports clk_125mhz_p]
set_property -dict {LOC G9  IOSTANDARD LVDS} [get_ports clk_125mhz_n]
create_clock -period 8.000 -name clk_125mhz [get_ports clk_125mhz_p]

# LEDs
set_property -dict {LOC AL11 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[0]}]
set_property -dict {LOC AL13 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[1]}]
set_property -dict {LOC AK13 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[2]}]
set_property -dict {LOC AE15 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[3]}]
set_property -dict {LOC AM8  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[4]}]
set_property -dict {LOC AM9  IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[5]}]
set_property -dict {LOC AM10 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[6]}]
set_property -dict {LOC AM11 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[7]}]

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Reset button
set_property -dict {LOC G13  IOSTANDARD LVCMOS12} [get_ports reset]

set_false_path -from [get_ports {reset}]
set_input_delay 0 [get_ports {reset}]

# Push buttons
set_property -dict {LOC AG13 IOSTANDARD LVCMOS12} [get_ports btnu]
set_property -dict {LOC AK12 IOSTANDARD LVCMOS12} [get_ports btnl]
set_property -dict {LOC AP20 IOSTANDARD LVCMOS12} [get_ports btnd]
set_property -dict {LOC AC14 IOSTANDARD LVCMOS12} [get_ports btnr]
set_property -dict {LOC AL10 IOSTANDARD LVCMOS12} [get_ports btnc]

set_false_path -from [get_ports {btnu btnl btnd btnr btnc}]
set_input_delay 0 [get_ports {btnu btnl btnd btnr btnc}]

# DIP switches
set_property -dict {LOC A17  IOSTANDARD LVCMOS18} [get_ports {sw[0]}]
set_property -dict {LOC A16  IOSTANDARD LVCMOS18} [get_ports {sw[1]}]
set_property -dict {LOC B16  IOSTANDARD LVCMOS18} [get_ports {sw[2]}]
set_property -dict {LOC B15  IOSTANDARD LVCMOS18} [get_ports {sw[3]}]
set_property -dict {LOC A15  IOSTANDARD LVCMOS18} [get_ports {sw[4]}]
set_property -dict {LOC A14  IOSTANDARD LVCMOS18} [get_ports {sw[5]}]
set_property -dict {LOC B14  IOSTANDARD LVCMOS18} [get_ports {sw[6]}]
set_property -dict {LOC B13  IOSTANDARD LVCMOS18} [get_ports {sw[7]}]

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# PMOD0
#set_property -dict {LOC B23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[0]}] ;# J55.1
#set_property -dict {LOC A23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[1]}] ;# J55.3
#set_property -dict {LOC F25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[2]}] ;# J55.5
#set_property -dict {LOC E20  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[3]}] ;# J55.7
#set_property -dict {LOC K24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[4]}] ;# J55.2
#set_property -dict {LOC L23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[5]}] ;# J55.4
#set_property -dict {LOC L22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[6]}] ;# J55.6
#set_property -dict {LOC D7   IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod0[7]}] ;# J55.8

#set_false_path -to [get_ports {pmod0[*]}]
#set_output_delay 0 [get_ports {pmod0[*]}]

# PMOD1
#set_property -dict {LOC AN8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[0]}] ;# J87.1
#set_property -dict {LOC AN9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[1]}] ;# J87.3
#set_property -dict {LOC AP11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[2]}] ;# J87.5
#set_property -dict {LOC AN11 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[3]}] ;# J87.7
#set_property -dict {LOC AP9  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[4]}] ;# J87.2
#set_property -dict {LOC AP10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[5]}] ;# J87.4
#set_property -dict {LOC AP12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[6]}] ;# J87.6
#set_property -dict {LOC AN12 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {pmod1[7]}] ;# J87.8

#set_false_path -to [get_ports {pmod1[*]}]
#set_output_delay 0 [get_ports {pmod1[*]}]

# "Prototype header" GPIO
#set_property -dict {LOC K13  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[0]}] ;# J3.6
#set_property -dict {LOC L14  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[1]}] ;# J3.8
#set_property -dict {LOC J14  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[2]}] ;# J3.10
#set_property -dict {LOC K14  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[3]}] ;# J3.12
#set_property -dict {LOC J11  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[4]}] ;# J3.14
#set_property -dict {LOC K12  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[5]}] ;# J3.16
#set_property -dict {LOC L11  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[6]}] ;# J3.18
#set_property -dict {LOC L12  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[7]}] ;# J3.20
#set_property -dict {LOC G24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[8]}] ;# J3.22
#set_property -dict {LOC G23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {proto_gpio[9]}] ;# J3.24

#set_false_path -to [get_ports {proto_gpio[*]}]
#set_output_delay 0 [get_ports {proto_gpio[*]}]

# UART (U40 CP2108 ch 2)
set_property -dict {LOC AL17 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports uart_txd] ;# U40.15 RX_2
set_property -dict {LOC AH17 IOSTANDARD LVCMOS12} [get_ports uart_rxd] ;# U40.16 TX_2
set_property -dict {LOC AM15 IOSTANDARD LVCMOS12} [get_ports uart_rts] ;# U40.14 RTS_2
set_property -dict {LOC AP17 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports uart_cts] ;# U40.13 CTS_2

set_false_path -to [get_ports {uart_txd uart_cts}]
set_output_delay 0 [get_ports {uart_txd uart_cts}]
set_false_path -from [get_ports {uart_rxd uart_rts}]
set_input_delay 0 [get_ports {uart_rxd uart_rts}]

# I2C interfaces
#set_property -dict {LOC AE19 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports i2c0_scl]
#set_property -dict {LOC AH23 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports i2c0_sda]
#set_property -dict {LOC AH19 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports i2c1_scl]
#set_property -dict {LOC AL21 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports i2c1_sda]

#set_false_path -to [get_ports {i2c1_sda i2c1_scl}]
#set_output_delay 0 [get_ports {i2c1_sda i2c1_scl}]
#set_false_path -from [get_ports {i2c1_sda i2c1_scl}]
#set_input_delay 0 [get_ports {i2c1_sda i2c1_scl}]

# SFP+ Interface
set_property -dict {LOC AA2 } [get_ports {sfp_rx_p[0]}] ;# MGTHRXP2_225 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y2
set_property -dict {LOC AA1 } [get_ports {sfp_rx_n[0]}] ;# MGTHRXN2_225 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y2
set_property -dict {LOC Y4  } [get_ports {sfp_tx_p[0]}] ;# MGTHTXP2_225 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y2
set_property -dict {LOC Y3  } [get_ports {sfp_tx_n[0]}] ;# MGTHTXN2_225 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y2
set_property -dict {LOC W2  } [get_ports {sfp_rx_p[1]}] ;# MGTHRXP3_225 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y2
set_property -dict {LOC W1  } [get_ports {sfp_rx_n[1]}] ;# MGTHRXN3_225 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y2
set_property -dict {LOC W6  } [get_ports {sfp_tx_p[1]}] ;# MGTHTXP3_225 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y2
set_property -dict {LOC W5  } [get_ports {sfp_tx_n[1]}] ;# MGTHTXN3_225 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y2
set_property -dict {LOC U10 } [get_ports {sfp_mgt_refclk_0_p}] ;# MGTREFCLK1P_226 from U56 SI570 via U51 SI53340
set_property -dict {LOC U9  } [get_ports {sfp_mgt_refclk_0_n}] ;# MGTREFCLK1N_226 from U56 SI570 via U51 SI53340
#set_property -dict {LOC W10 } [get_ports {sfp_mgt_refclk_1_p}] ;# MGTREFCLK1P_225 from U20 CKOUT2 SI5328
#set_property -dict {LOC W9  } [get_ports {sfp_mgt_refclk_1_n}] ;# MGTREFCLK1N_225 from U20 CKOUT2 SI5328
#set_property -dict {LOC H11 IOSTANDARD LVDS} [get_ports {sfp_recclk_p}] ;# to U20 CKIN1 SI5328
#set_property -dict {LOC G11 IOSTANDARD LVDS} [get_ports {sfp_recclk_n}] ;# to U20 CKIN1 SI5328
set_property -dict {LOC AE22 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {sfp_tx_disable_b[0]}]
set_property -dict {LOC AF20 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {sfp_tx_disable_b[1]}]

# 156.25 MHz MGT reference clock
create_clock -period 6.400 -name sfp_mgt_refclk_0 [get_ports {sfp_mgt_refclk_0_p}]

set_false_path -to [get_ports {sfp_tx_disable_b[*]}]
set_output_delay 0 [get_ports {sfp_tx_disable_b[*]}]

# PCIe Interface
set_property -dict {LOC AE2 } [get_ports {pcie_rx_p[0]}] ;# MGTHRXP3_224 GTHE4_CHANNEL_X0Y7 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AE1 } [get_ports {pcie_rx_n[0]}] ;# MGTHRXN3_224 GTHE4_CHANNEL_X0Y7 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AD4 } [get_ports {pcie_tx_p[0]}] ;# MGTHTXP3_224 GTHE4_CHANNEL_X0Y7 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AD3 } [get_ports {pcie_tx_n[0]}] ;# MGTHTXN3_224 GTHE4_CHANNEL_X0Y7 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AF4 } [get_ports {pcie_rx_p[1]}] ;# MGTHRXP2_224 GTHE4_CHANNEL_X0Y6 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AF3 } [get_ports {pcie_rx_n[1]}] ;# MGTHRXN2_224 GTHE4_CHANNEL_X0Y6 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AE6 } [get_ports {pcie_tx_p[1]}] ;# MGTHTXP2_224 GTHE4_CHANNEL_X0Y6 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AE5 } [get_ports {pcie_tx_n[1]}] ;# MGTHTXN2_224 GTHE4_CHANNEL_X0Y6 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AG2 } [get_ports {pcie_rx_p[2]}] ;# MGTHRXP1_224 GTHE4_CHANNEL_X0Y5 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AG1 } [get_ports {pcie_rx_n[2]}] ;# MGTHRXN1_224 GTHE4_CHANNEL_X0Y5 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AG6 } [get_ports {pcie_tx_p[2]}] ;# MGTHTXP1_224 GTHE4_CHANNEL_X0Y5 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AG5 } [get_ports {pcie_tx_n[2]}] ;# MGTHTXN1_224 GTHE4_CHANNEL_X0Y5 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AJ2 } [get_ports {pcie_rx_p[3]}] ;# MGTHRXP0_224 GTHE4_CHANNEL_X0Y4 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AJ1 } [get_ports {pcie_rx_n[3]}] ;# MGTHRXN0_224 GTHE4_CHANNEL_X0Y4 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AH4 } [get_ports {pcie_tx_p[3]}] ;# MGTHTXP0_224 GTHE4_CHANNEL_X0Y4 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AH3 } [get_ports {pcie_tx_n[3]}] ;# MGTHTXN0_224 GTHE4_CHANNEL_X0Y4 / GTHE4_COMMON_X0Y1
set_property -dict {LOC AB8 } [get_ports pcie_refclk_p] ;# MGTREFCLK0P_224
set_property -dict {LOC AB7 } [get_ports pcie_refclk_n] ;# MGTREFCLK0N_224
set_property -dict {LOC L8  IOSTANDARD LVCMOS33 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_mgt_refclk_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# FMC interface
# FMC HPC0 J5
#set_property -dict {LOC F17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[0]}]  ;# J5.G9  LA00_P_CC
#set_property -dict {LOC F16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[0]}]  ;# J5.G10 LA00_N_CC
#set_property -dict {LOC H18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[1]}]  ;# J5.D8  LA01_P_CC
#set_property -dict {LOC H17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[1]}]  ;# J5.D9  LA01_N_CC
#set_property -dict {LOC L20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[2]}]  ;# J5.H7  LA02_P
#set_property -dict {LOC K20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[2]}]  ;# J5.H8  LA02_N
#set_property -dict {LOC K19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[3]}]  ;# J5.G12 LA03_P
#set_property -dict {LOC K18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[3]}]  ;# J5.G13 LA03_N
#set_property -dict {LOC L17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[4]}]  ;# J5.H10 LA04_P
#set_property -dict {LOC L16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[4]}]  ;# J5.H11 LA04_N
#set_property -dict {LOC K17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[5]}]  ;# J5.D11 LA05_P
#set_property -dict {LOC J17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[5]}]  ;# J5.D12 LA05_N
#set_property -dict {LOC H19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[6]}]  ;# J5.C10 LA06_P
#set_property -dict {LOC G19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[6]}]  ;# J5.C11 LA06_N
#set_property -dict {LOC J16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[7]}]  ;# J5.H13 LA07_P
#set_property -dict {LOC J15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[7]}]  ;# J5.H14 LA07_N
#set_property -dict {LOC E18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[8]}]  ;# J5.G12 LA08_P
#set_property -dict {LOC E17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[8]}]  ;# J5.G13 LA08_N
#set_property -dict {LOC H16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[9]}]  ;# J5.D14 LA09_P
#set_property -dict {LOC G16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[9]}]  ;# J5.D15 LA09_N
#set_property -dict {LOC L15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[10]}] ;# J5.C14 LA10_P
#set_property -dict {LOC K15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[10]}] ;# J5.C15 LA10_N
#set_property -dict {LOC A13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[11]}] ;# J5.H16 LA11_P
#set_property -dict {LOC A12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[11]}] ;# J5.H17 LA11_N
#set_property -dict {LOC G18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[12]}] ;# J5.G15 LA12_P
#set_property -dict {LOC F18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[12]}] ;# J5.G16 LA12_N
#set_property -dict {LOC G15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[13]}] ;# J5.D17 LA13_P
#set_property -dict {LOC F15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[13]}] ;# J5.D18 LA13_N
#set_property -dict {LOC C13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[14]}] ;# J5.C18 LA14_P
#set_property -dict {LOC C12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[14]}] ;# J5.C19 LA14_N
#set_property -dict {LOC D16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[15]}] ;# J5.H19 LA15_P
#set_property -dict {LOC C16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[15]}] ;# J5.H20 LA15_N
#set_property -dict {LOC D17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[16]}] ;# J5.G18 LA16_P
#set_property -dict {LOC C17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[16]}] ;# J5.G19 LA16_N
#set_property -dict {LOC F11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[17]}] ;# J5.D20 LA17_P_CC
#set_property -dict {LOC E10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[17]}] ;# J5.D21 LA17_N_CC
#set_property -dict {LOC D11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[18]}] ;# J5.C22 LA18_P_CC
#set_property -dict {LOC D10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[18]}] ;# J5.C23 LA18_N_CC
#set_property -dict {LOC D12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[19]}] ;# J5.H22 LA19_P
#set_property -dict {LOC C11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[19]}] ;# J5.H23 LA19_N
#set_property -dict {LOC F12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[20]}] ;# J5.G21 LA20_P
#set_property -dict {LOC E12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[20]}] ;# J5.G22 LA20_N
#set_property -dict {LOC B10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[21]}] ;# J5.H25 LA21_P
#set_property -dict {LOC A10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[21]}] ;# J5.H26 LA21_N
#set_property -dict {LOC H13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[22]}] ;# J5.G24 LA22_P
#set_property -dict {LOC H12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[22]}] ;# J5.G25 LA22_N
#set_property -dict {LOC B11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[23]}] ;# J5.D23 LA23_P
#set_property -dict {LOC A11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[23]}] ;# J5.D24 LA23_N
#set_property -dict {LOC B6   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[24]}] ;# J5.H28 LA24_P
#set_property -dict {LOC A6   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[24]}] ;# J5.H29 LA24_N
#set_property -dict {LOC C7   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[25]}] ;# J5.G27 LA25_P
#set_property -dict {LOC C6   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[25]}] ;# J5.G28 LA25_N
#set_property -dict {LOC B9   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[26]}] ;# J5.D26 LA26_P
#set_property -dict {LOC B8   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[26]}] ;# J5.D27 LA26_N
#set_property -dict {LOC A8   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[27]}] ;# J5.C26 LA27_P
#set_property -dict {LOC A7   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[27]}] ;# J5.C27 LA27_N
#set_property -dict {LOC M13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[28]}] ;# J5.H31 LA28_P
#set_property -dict {LOC L13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[28]}] ;# J5.H32 LA28_N
#set_property -dict {LOC K10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[29]}] ;# J5.G30 LA29_P
#set_property -dict {LOC J10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[29]}] ;# J5.G31 LA29_N
#set_property -dict {LOC E9   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[30]}] ;# J5.H34 LA30_P
#set_property -dict {LOC D9   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[30]}] ;# J5.H35 LA30_N
#set_property -dict {LOC F7   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[31]}] ;# J5.G33 LA31_P
#set_property -dict {LOC E7   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[31]}] ;# J5.G34 LA31_N
#set_property -dict {LOC F8   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[32]}] ;# J5.H37 LA32_P
#set_property -dict {LOC E8   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[32]}] ;# J5.H38 LA32_N
#set_property -dict {LOC C9   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_p[33]}] ;# J5.G36 LA33_P
#set_property -dict {LOC C8   IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_la_n[33]}] ;# J5.G37 LA33_N

#set_property -dict {LOC E15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_clk0_m2c_p}] ;# J5.H4 CLK0_M2C_P
#set_property -dict {LOC E14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_clk0_m2c_n}] ;# J5.H5 CLK0_M2C_N
#set_property -dict {LOC G10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_clk1_m2c_p}] ;# J5.G2 CLK1_M2C_P
#set_property -dict {LOC F10  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc0_clk1_m2c_n}] ;# J5.G3 CLK1_M2C_N

#set_property -dict {LOC R6  } [get_ports {fmc_hpc0_dp_c2m_p[0]}] ;# MGTHTXP2_226 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y3 from J5.C2  DP0_C2M_P
#set_property -dict {LOC R5  } [get_ports {fmc_hpc0_dp_c2m_n[0]}] ;# MGTHTXN2_226 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y3 from J5.C3  DP0_C2M_N
#set_property -dict {LOC R2  } [get_ports {fmc_hpc0_dp_m2c_p[0]}] ;# MGTHRXP2_226 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y3 from J5.C6  DP0_M2C_P
#set_property -dict {LOC R1  } [get_ports {fmc_hpc0_dp_m2c_n[0]}] ;# MGTHRXN2_226 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y3 from J5.C7  DP0_M2C_N
#set_property -dict {LOC T4  } [get_ports {fmc_hpc0_dp_c2m_p[1]}] ;# MGTHTXP1_226 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y3 from J5.A22 DP1_C2M_P
#set_property -dict {LOC T3  } [get_ports {fmc_hpc0_dp_c2m_n[1]}] ;# MGTHTXN1_226 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y3 from J5.A23 DP1_C2M_N
#set_property -dict {LOC U2  } [get_ports {fmc_hpc0_dp_m2c_p[1]}] ;# MGTHRXP1_226 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y3 from J5.A2  DP1_M2C_P
#set_property -dict {LOC U1  } [get_ports {fmc_hpc0_dp_m2c_n[1]}] ;# MGTHRXN1_226 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y3 from J5.A3  DP1_M2C_N
#set_property -dict {LOC N6  } [get_ports {fmc_hpc0_dp_c2m_p[2]}] ;# MGTHTXP3_226 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y3 from J5.A26 DP2_C2M_P
#set_property -dict {LOC N5  } [get_ports {fmc_hpc0_dp_c2m_n[2]}] ;# MGTHTXN3_226 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y3 from J5.A27 DP2_C2M_N
#set_property -dict {LOC P4  } [get_ports {fmc_hpc0_dp_m2c_p[2]}] ;# MGTHRXP3_226 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y3 from J5.A6  DP2_M2C_P
#set_property -dict {LOC P3  } [get_ports {fmc_hpc0_dp_m2c_n[2]}] ;# MGTHRXN3_226 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y3 from J5.A7  DP2_M2C_N
#set_property -dict {LOC U6  } [get_ports {fmc_hpc0_dp_c2m_p[3]}] ;# MGTHTXP0_226 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y3 from J5.A30 DP3_C2M_P
#set_property -dict {LOC U5  } [get_ports {fmc_hpc0_dp_c2m_n[3]}] ;# MGTHTXN0_226 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y3 from J5.A31 DP3_C2M_N
#set_property -dict {LOC V4  } [get_ports {fmc_hpc0_dp_m2c_p[3]}] ;# MGTHRXP0_226 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y3 from J5.A10 DP3_M2C_P
#set_property -dict {LOC V3  } [get_ports {fmc_hpc0_dp_m2c_n[3]}] ;# MGTHRXN0_226 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y3 from J5.A11 DP3_M2C_N

#set_property -dict {LOC H4  } [get_ports {fmc_hpc0_dp_c2m_p[4]}] ;# MGTHTXP3_227 GTHE4_CHANNEL_X0Y19 / GTHE4_COMMON_X0Y4 from J5.A34 DP4_C2M_P
#set_property -dict {LOC H3  } [get_ports {fmc_hpc0_dp_c2m_n[4]}] ;# MGTHTXN3_227 GTHE4_CHANNEL_X0Y19 / GTHE4_COMMON_X0Y4 from J5.A35 DP4_C2M_N
#set_property -dict {LOC G2  } [get_ports {fmc_hpc0_dp_m2c_p[4]}] ;# MGTHRXP3_227 GTHE4_CHANNEL_X0Y19 / GTHE4_COMMON_X0Y4 from J5.A14 DP4_M2C_P
#set_property -dict {LOC G1  } [get_ports {fmc_hpc0_dp_m2c_n[4]}] ;# MGTHRXN3_227 GTHE4_CHANNEL_X0Y19 / GTHE4_COMMON_X0Y4 from J5.A15 DP4_M2C_N
#set_property -dict {LOC L6  } [get_ports {fmc_hpc0_dp_c2m_p[5]}] ;# MGTHTXP1_227 GTHE4_CHANNEL_X0Y17 / GTHE4_COMMON_X0Y4 from J5.A38 DP5_C2M_P
#set_property -dict {LOC L5  } [get_ports {fmc_hpc0_dp_c2m_n[5]}] ;# MGTHTXN1_227 GTHE4_CHANNEL_X0Y17 / GTHE4_COMMON_X0Y4 from J5.A39 DP5_C2M_N
#set_property -dict {LOC L2  } [get_ports {fmc_hpc0_dp_m2c_p[5]}] ;# MGTHRXP1_227 GTHE4_CHANNEL_X0Y17 / GTHE4_COMMON_X0Y4 from J5.A18 DP5_M2C_P
#set_property -dict {LOC L1  } [get_ports {fmc_hpc0_dp_m2c_n[5]}] ;# MGTHRXN1_227 GTHE4_CHANNEL_X0Y17 / GTHE4_COMMON_X0Y4 from J5.A19 DP5_M2C_N
#set_property -dict {LOC M4  } [get_ports {fmc_hpc0_dp_c2m_p[6]}] ;# MGTHTXP0_227 GTHE4_CHANNEL_X0Y16 / GTHE4_COMMON_X0Y4 from J5.B36 DP6_C2M_P
#set_property -dict {LOC M3  } [get_ports {fmc_hpc0_dp_c2m_n[6]}] ;# MGTHTXN0_227 GTHE4_CHANNEL_X0Y16 / GTHE4_COMMON_X0Y4 from J5.B37 DP6_C2M_N
#set_property -dict {LOC N2  } [get_ports {fmc_hpc0_dp_m2c_p[6]}] ;# MGTHRXP0_227 GTHE4_CHANNEL_X0Y16 / GTHE4_COMMON_X0Y4 from J5.B16 DP6_M2C_P
#set_property -dict {LOC N1  } [get_ports {fmc_hpc0_dp_m2c_n[6]}] ;# MGTHRXN0_227 GTHE4_CHANNEL_X0Y16 / GTHE4_COMMON_X0Y4 from J5.B17 DP6_M2C_N
#set_property -dict {LOC K4  } [get_ports {fmc_hpc0_dp_c2m_p[7]}] ;# MGTHTXP2_227 GTHE4_CHANNEL_X0Y18 / GTHE4_COMMON_X0Y4 from J5.B32 DP7_C2M_P
#set_property -dict {LOC K3  } [get_ports {fmc_hpc0_dp_c2m_n[7]}] ;# MGTHTXN2_227 GTHE4_CHANNEL_X0Y18 / GTHE4_COMMON_X0Y4 from J5.B33 DP7_C2M_N
#set_property -dict {LOC J2  } [get_ports {fmc_hpc0_dp_m2c_p[7]}] ;# MGTHRXP2_227 GTHE4_CHANNEL_X0Y18 / GTHE4_COMMON_X0Y4 from J5.B12 DP7_M2C_P
#set_property -dict {LOC J1  } [get_ports {fmc_hpc0_dp_m2c_n[7]}] ;# MGTHRXN2_227 GTHE4_CHANNEL_X0Y18 / GTHE4_COMMON_X0Y4 from J5.B13 DP7_M2C_N
#set_property -dict {LOC V8  } [get_ports {fmc_hpc0_mgt_refclk_0_p}] ;# MGTREFCLK0P_226 from J5.D4 GBTCLK0_M2C_P
#set_property -dict {LOC V7  } [get_ports {fmc_hpc0_mgt_refclk_0_n}] ;# MGTREFCLK0N_226 from J5.D5 GBTCLK0_M2C_N
#set_property -dict {LOC T8  } [get_ports {fmc_hpc0_mgt_refclk_1_p}] ;# MGTREFCLK0P_227 from J5.B20 GBTCLK1_M2C_P
#set_property -dict {LOC T7  } [get_ports {fmc_hpc0_mgt_refclk_1_n}] ;# MGTREFCLK0N_227 from J5.B21 GBTCLK1_M2C_N

# reference clock
#create_clock -period 6.400 -name fmc_hpc0_mgt_refclk_0 [get_ports {fmc_hpc0_mgt_refclk_0_p}]
#create_clock -period 6.400 -name fmc_hpc0_mgt_refclk_1 [get_ports {fmc_hpc0_mgt_refclk_1_p}]

# FMC HPC1 J4
#set_property -dict {LOC B18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[0]}]  ;# J4.G9  LA00_P_CC
#set_property -dict {LOC B19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[0]}]  ;# J4.G10 LA00_N_CC
#set_property -dict {LOC E24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[1]}]  ;# J4.D8  LA01_P_CC
#set_property -dict {LOC D24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[1]}]  ;# J4.D9  LA01_N_CC
#set_property -dict {LOC K22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[2]}]  ;# J4.H7  LA02_P
#set_property -dict {LOC K23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[2]}]  ;# J4.H8  LA02_N
#set_property -dict {LOC J21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[3]}]  ;# J4.G12 LA03_P
#set_property -dict {LOC J22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[3]}]  ;# J4.G13 LA03_N
#set_property -dict {LOC J24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[4]}]  ;# J4.H10 LA04_P
#set_property -dict {LOC H24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[4]}]  ;# J4.H11 LA04_N
#set_property -dict {LOC G25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[5]}]  ;# J4.D11 LA05_P
#set_property -dict {LOC G26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[5]}]  ;# J4.D12 LA05_N
#set_property -dict {LOC H21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[6]}]  ;# J4.C10 LA06_P
#set_property -dict {LOC H22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[6]}]  ;# J4.C11 LA06_N
#set_property -dict {LOC D22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[7]}]  ;# J4.H13 LA07_P
#set_property -dict {LOC C23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[7]}]  ;# J4.H14 LA07_N
#set_property -dict {LOC J25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[8]}]  ;# J4.G12 LA08_P
#set_property -dict {LOC H26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[8]}]  ;# J4.G13 LA08_N
#set_property -dict {LOC G20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[9]}]  ;# J4.D14 LA09_P
#set_property -dict {LOC F20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[9]}]  ;# J4.D15 LA09_N
#set_property -dict {LOC F22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[10]}] ;# J4.C14 LA10_P
#set_property -dict {LOC E22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[10]}] ;# J4.C15 LA10_N
#set_property -dict {LOC A20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[11]}] ;# J4.H16 LA11_P
#set_property -dict {LOC A21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[11]}] ;# J4.H17 LA11_N
#set_property -dict {LOC E19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[12]}] ;# J4.G15 LA12_P
#set_property -dict {LOC D19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[12]}] ;# J4.G16 LA12_N
#set_property -dict {LOC C21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[13]}] ;# J4.D17 LA13_P
#set_property -dict {LOC C22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[13]}] ;# J4.D18 LA13_N
#set_property -dict {LOC D20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[14]}] ;# J4.C18 LA14_P
#set_property -dict {LOC D21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[14]}] ;# J4.C19 LA14_N
#set_property -dict {LOC A18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[15]}] ;# J4.H19 LA15_P
#set_property -dict {LOC A19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[15]}] ;# J4.H20 LA15_N
#set_property -dict {LOC C18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[16]}] ;# J4.G18 LA16_P
#set_property -dict {LOC C19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[16]}] ;# J4.G19 LA16_N

#set_property -dict {LOC F23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_clk0_m2c_p}] ;# J4.H4 CLK0_M2C_P
#set_property -dict {LOC E23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_clk0_m2c_n}] ;# J4.H5 CLK0_M2C_N

#set_property -dict {LOC AJ6 } [get_ports {fmc_hpc1_dp_c2m_p[0]}] ;# MGTHTXP3_223 GTHE4_CHANNEL_X0Y3 / GTHE4_COMMON_X0Y0 from J4.C2  DP0_C2M_P
#set_property -dict {LOC AJ5 } [get_ports {fmc_hpc1_dp_c2m_n[0]}] ;# MGTHTXN3_223 GTHE4_CHANNEL_X0Y3 / GTHE4_COMMON_X0Y0 from J4.C3  DP0_C2M_N
#set_property -dict {LOC AK4 } [get_ports {fmc_hpc1_dp_m2c_p[0]}] ;# MGTHRXP3_223 GTHE4_CHANNEL_X0Y3 / GTHE4_COMMON_X0Y0 from J4.C6  DP0_M2C_P
#set_property -dict {LOC AK3 } [get_ports {fmc_hpc1_dp_m2c_n[0]}] ;# MGTHRXN3_223 GTHE4_CHANNEL_X0Y3 / GTHE4_COMMON_X0Y0 from J4.C7  DP0_M2C_N
#set_property -dict {LOC Y8  } [get_ports {fmc_hpc1_mgt_refclk_p}] ;# MGTREFCLK0P_225 from J4.D4 GBTCLK0_M2C_P
#set_property -dict {LOC Y7  } [get_ports {fmc_hpc1_mgt_refclk_n}] ;# MGTREFCLK0N_225 from J4.D5 GBTCLK0_M2C_N

# reference clock
#create_clock -period 6.400 -name fmc_hpc1_mgt_refclk [get_ports {fmc_hpc1_mgt_refclk_p}]

# DDR4
# 4x MT40A256M16GE-075E
#set_property -dict {LOC AK9  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[0]}]
#set_property -dict {LOC AG11 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[1]}]
#set_property -dict {LOC AJ10 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[2]}]
#set_property -dict {LOC AL8  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[3]}]
#set_property -dict {LOC AK10 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[4]}]
#set_property -dict {LOC AH8  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[5]}]
#set_property -dict {LOC AJ9  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[6]}]
#set_property -dict {LOC AG8  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[7]}]
#set_property -dict {LOC AH9  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[8]}]
#set_property -dict {LOC AG10 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[9]}]
#set_property -dict {LOC AH13 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[10]}]
#set_property -dict {LOC AG9  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[11]}]
#set_property -dict {LOC AM13 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[12]}]
#set_property -dict {LOC AF8  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[13]}]
#set_property -dict {LOC AC12 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[14]}]
#set_property -dict {LOC AE12 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[15]}]
#set_property -dict {LOC AF11 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[16]}]
#set_property -dict {LOC AK8  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[0]}]
#set_property -dict {LOC AL12 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[1]}]
#set_property -dict {LOC AE14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[0]}]
#set_property -dict {LOC AH11 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_t}]
#set_property -dict {LOC AJ11 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_c}]
#set_property -dict {LOC AB13 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cke}]
#set_property -dict {LOC AD12 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cs_n}]
#set_property -dict {LOC AD14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_act_n}]
#set_property -dict {LOC AF10 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_odt}]
#set_property -dict {LOC AC13 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_par}]
#set_property -dict {LOC AF12 IOSTANDARD LVCMOS12       } [get_ports {ddr4_reset_n}]

#set_property -dict {LOC AF16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[0]}]       ;# U101.G2 DQL0
#set_property -dict {LOC AF18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[1]}]       ;# U101.F7 DQL1
#set_property -dict {LOC AG15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[2]}]       ;# U101.H3 DQL2
#set_property -dict {LOC AF17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[3]}]       ;# U101.H7 DQL3
#set_property -dict {LOC AF15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[4]}]       ;# U101.H2 DQL4
#set_property -dict {LOC AG18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[5]}]       ;# U101.H8 DQL5
#set_property -dict {LOC AG14 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[6]}]       ;# U101.J3 DQL6
#set_property -dict {LOC AE17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[7]}]       ;# U101.J7 DQL7
#set_property -dict {LOC AA14 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[8]}]       ;# U101.A3 DQU0
#set_property -dict {LOC AC16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[9]}]       ;# U101.B8 DQU1
#set_property -dict {LOC AB15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[10]}]      ;# U101.C3 DQU2
#set_property -dict {LOC AD16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[11]}]      ;# U101.C7 DQU3
#set_property -dict {LOC AB16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[12]}]      ;# U101.C2 DQU4
#set_property -dict {LOC AC17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[13]}]      ;# U101.C8 DQU5
#set_property -dict {LOC AB14 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[14]}]      ;# U101.D3 DQU6
#set_property -dict {LOC AD17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[15]}]      ;# U101.D7 DQU7
#set_property -dict {LOC AH14 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[0]}]    ;# U101.G3 DQSL_T
#set_property -dict {LOC AJ14 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[0]}]    ;# U101.F3 DQSL_C
#set_property -dict {LOC AA16 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[1]}]    ;# U101.B7 DQSU_T
#set_property -dict {LOC AA15 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[1]}]    ;# U101.A7 DQSU_C
#set_property -dict {LOC AH18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[0]}] ;# U101.E7 DML_B/DBIL_B
#set_property -dict {LOC AD15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[1]}] ;# U101.E2 DMU_B/DBIU_B

#set_property -dict {LOC AJ16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[16]}]      ;# U99.G2 DQL0
#set_property -dict {LOC AJ17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[17]}]      ;# U99.F7 DQL1
#set_property -dict {LOC AL15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[18]}]      ;# U99.H3 DQL2
#set_property -dict {LOC AK17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[19]}]      ;# U99.H7 DQL3
#set_property -dict {LOC AJ15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[20]}]      ;# U99.H2 DQL4
#set_property -dict {LOC AK18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[21]}]      ;# U99.H8 DQL5
#set_property -dict {LOC AL16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[22]}]      ;# U99.J3 DQL6
#set_property -dict {LOC AL18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[23]}]      ;# U99.J7 DQL7
#set_property -dict {LOC AP13 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[24]}]      ;# U99.A3 DQU0
#set_property -dict {LOC AP16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[25]}]      ;# U99.B8 DQU1
#set_property -dict {LOC AP15 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[26]}]      ;# U99.C3 DQU2
#set_property -dict {LOC AN16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[27]}]      ;# U99.C7 DQU3
#set_property -dict {LOC AN13 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[28]}]      ;# U99.C2 DQU4
#set_property -dict {LOC AM18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[29]}]      ;# U99.C8 DQU5
#set_property -dict {LOC AN17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[30]}]      ;# U99.D3 DQU6
#set_property -dict {LOC AN18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[31]}]      ;# U99.D7 DQU7
#set_property -dict {LOC AK15 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[2]}]    ;# U99.G3 DQSL_T
#set_property -dict {LOC AK14 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[2]}]    ;# U99.F3 DQSL_C
#set_property -dict {LOC AM14 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[3]}]    ;# U99.B7 DQSU_T
#set_property -dict {LOC AN14 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[3]}]    ;# U99.A7 DQSU_C
#set_property -dict {LOC AM16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[2]}] ;# U99.E7 DML_B/DBIL_B
#set_property -dict {LOC AP18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[3]}] ;# U99.E2 DMU_B/DBIU_B

#set_property -dict {LOC AB19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[32]}]      ;# U100.G2 DQL0
#set_property -dict {LOC AD19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[33]}]      ;# U100.F7 DQL1
#set_property -dict {LOC AC18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[34]}]      ;# U100.H3 DQL2
#set_property -dict {LOC AC19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[35]}]      ;# U100.H7 DQL3
#set_property -dict {LOC AA20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[36]}]      ;# U100.H2 DQL4
#set_property -dict {LOC AE20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[37]}]      ;# U100.H8 DQL5
#set_property -dict {LOC AA19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[38]}]      ;# U100.J3 DQL6
#set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[39]}]      ;# U100.J7 DQL7
#set_property -dict {LOC AF22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[40]}]      ;# U100.A3 DQU0
#set_property -dict {LOC AH21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[41]}]      ;# U100.B8 DQU1
#set_property -dict {LOC AG19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[42]}]      ;# U100.C3 DQU2
#set_property -dict {LOC AG21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[43]}]      ;# U100.C7 DQU3
#set_property -dict {LOC AE24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[44]}]      ;# U100.C2 DQU4
#set_property -dict {LOC AG20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[45]}]      ;# U100.C8 DQU5
#set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[46]}]      ;# U100.D3 DQU6
#set_property -dict {LOC AF21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[47]}]      ;# U100.D7 DQU7
#set_property -dict {LOC AA18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[4]}]    ;# U100.G3 DQSL_T
#set_property -dict {LOC AB18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[4]}]    ;# U100.F3 DQSL_C
#set_property -dict {LOC AF23 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[5]}]    ;# U100.B7 DQSU_T
#set_property -dict {LOC AG23 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[5]}]    ;# U100.A7 DQSU_C
#set_property -dict {LOC AE18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[4]}] ;# U100.E7 DML_B/DBIL_B
#set_property -dict {LOC AH22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[5]}] ;# U100.E2 DMU_B/DBIU_B

#set_property -dict {LOC AL22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[48]}]      ;# U2.G2 DQL0
#set_property -dict {LOC AJ22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[49]}]      ;# U2.F7 DQL1
#set_property -dict {LOC AL23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[50]}]      ;# U2.H3 DQL2
#set_property -dict {LOC AJ21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[51]}]      ;# U2.H7 DQL3
#set_property -dict {LOC AK20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[52]}]      ;# U2.H2 DQL4
#set_property -dict {LOC AJ19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[53]}]      ;# U2.H8 DQL5
#set_property -dict {LOC AK19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[54]}]      ;# U2.J3 DQL6
#set_property -dict {LOC AJ20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[55]}]      ;# U2.J7 DQL7
#set_property -dict {LOC AP22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[56]}]      ;# U2.A3 DQU0
#set_property -dict {LOC AN22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[57]}]      ;# U2.B8 DQU1
#set_property -dict {LOC AP21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[58]}]      ;# U2.C3 DQU2
#set_property -dict {LOC AP23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[59]}]      ;# U2.C7 DQU3
#set_property -dict {LOC AM19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[60]}]      ;# U2.C2 DQU4
#set_property -dict {LOC AM23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[61]}]      ;# U2.C8 DQU5
#set_property -dict {LOC AN19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[62]}]      ;# U2.D3 DQU6
#set_property -dict {LOC AN23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[63]}]      ;# U2.D7 DQU7
#set_property -dict {LOC AK22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[6]}]    ;# U2.G3 DQSL_T
#set_property -dict {LOC AK23 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[6]}]    ;# U2.F3 DQSL_C
#set_property -dict {LOC AM21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[7]}]    ;# U2.B7 DQSU_T
#set_property -dict {LOC AN21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[7]}]    ;# U2.A7 DQSU_C
#set_property -dict {LOC AL20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[6]}] ;# U2.E7 DML_B/DBIL_B
#set_property -dict {LOC AP19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[7]}] ;# U2.E2 DMU_B/DBIU_B
