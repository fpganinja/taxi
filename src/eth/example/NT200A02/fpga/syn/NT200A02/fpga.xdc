# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A02 board
# part: xcvu5p-flva2104-2-e

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN {DIV-1} [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4           [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP         [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# 50 MHz system clock
set_property -dict {LOC AK34 IOSTANDARD LVCMOS18} [get_ports clk_50mhz] ;# U10
create_clock -period 20.000 -name clk_50mhz [get_ports clk_50mhz]

# 80 MHz EMCCLK
#set_property -dict {LOC AL20 IOSTANDARD LVCMOS18} [get_ports clk_80mhz] ;# U9
#create_clock -period 12.500 -name clk_80mhz [get_ports clk_80mhz]

# 20 MHz reference clock
#set_property -dict {LOC AM33 IOSTANDARD LVCMOS18} [get_ports clk_20mhz] ;# U201/U22
#create_clock -period 12.500 -name clk_20mhz [get_ports clk_20mhz]
