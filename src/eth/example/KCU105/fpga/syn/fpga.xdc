# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
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
