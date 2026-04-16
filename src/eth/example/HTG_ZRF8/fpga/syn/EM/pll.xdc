# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-EM board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# System clocks
# DDR4 clocks from U48 (300 MHz)
#set_property -dict {LOC G13  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_p] ;# U48.59 OUT9_P
#set_property -dict {LOC G12  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_n] ;# U48.58 OUT9_N
#create_clock -period 3.333 -name sys_clk_ddr4 [get_ports sys_clk_ddr4_p]

#set_property -dict {LOC AP8  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_c_p] ;# U48.51 OUT7_P
#set_property -dict {LOC AR9  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_c_n] ;# U48.50 OUT7_N
#create_clock -period 3.333 -name sys_clk_ddr4_c [get_ports sys_clk_ddr4_c_p]

# User clock from U48 (200 MHz)
set_property -dict {LOC AV6  IOSTANDARD LVDS_25} [get_ports clk_pl_user_p] ;# U48.54 OUT8_P
set_property -dict {LOC AV5  IOSTANDARD LVDS_25} [get_ports clk_pl_user_n] ;# U48.53 OUT8_N
create_clock -period 5.000 -name clk_pl_user [get_ports clk_pl_user_p]

# Source pin is in an HDIO bank, so it must be routed to an MMCM via a BUFG
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk_pl_user_bufg]
