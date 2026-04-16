# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-R2 board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# System clocks
# DDR4 clocks from U48 (300 MHz)
#set_property -dict {LOC G13  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_p] ;# U48.28 OUT1_P
#set_property -dict {LOC G12  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_n] ;# U48.27 OUT1_N
#create_clock -period 3.333 -name sys_clk_ddr4 [get_ports sys_clk_ddr4_p]

# User clock 1 from U48 (200 MHz)
set_property -dict {LOC C8   IOSTANDARD LVDS_25} [get_ports clk_pl_user1_p] ;# U48.24 OUT0_P
set_property -dict {LOC C7   IOSTANDARD LVDS_25} [get_ports clk_pl_user1_n] ;# U48.23 OUT0_N
create_clock -period 5.000 -name clk_pl_user1 [get_ports clk_pl_user1_p]

# Source pin is in an HDIO bank, so it must be routed to an MMCM via a BUFG
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets clk_pl_user1_bufg]

# User clock 2 from U48 (200 MHz)
#set_property -dict {LOC AM15 IOSTANDARD LVDS} [get_ports clk_pl_user2_p] ;# U48.42 OUT5_P
#set_property -dict {LOC AN15 IOSTANDARD LVDS} [get_ports clk_pl_user2_n] ;# U48.41 OUT5_N
#create_clock -period 5.000 -name clk_pl_user2 [get_ports clk_pl_user2_p]

# PLL control
set_property -dict {LOC AU4  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {clk_fdec}]
set_property -dict {LOC AV2  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {clk_finc}]
set_property -dict {LOC AU1  IOSTANDARD LVCMOS33} [get_ports {clk_intr_n}]
set_property -dict {LOC AV3  IOSTANDARD LVCMOS33} [get_ports {clk_lol_n}]
set_property -dict {LOC AU3  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {clk_sync_n}]
set_property -dict {LOC AU2  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {clk_rst_n}]

set_false_path -to [get_ports {clk_fdec clk_finc clk_sync_n clk_rst_n}]
set_output_delay 0 [get_ports {clk_fdec clk_finc clk_sync_n clk_rst_n}]
set_false_path -from [get_ports {clk_intr_n clk_lol_n}]
set_input_delay 0 [get_ports {clk_intr_n clk_lol_n}]
