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

# PLL refclk from U78 (250 MHz)
set_property -dict {LOC AV6  IOSTANDARD LVDS_25} [get_ports fpga_refclk_p] ;# U78.51 CLKout8_P
set_property -dict {LOC AV5  IOSTANDARD LVDS_25} [get_ports fpga_refclk_n] ;# U78.52 CLKout8_N
create_clock -period 4.000 -name fpga_refclk [get_ports fpga_refclk_p]

# Source pin is in an HDIO bank, so it must be routed to an MMCM via a BUFG
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets fpga_refclk_int fpga_refclk_bufg_inst_n_0]

# PLL sysref from U78
set_property -dict {LOC AP20 IOSTANDARD LVDS} [get_ports fpga_sysref_p] ;# U78.22 CLKout5_P
set_property -dict {LOC AP19 IOSTANDARD LVDS} [get_ports fpga_sysref_n] ;# U78.23 CLKout5_N
create_clock -period 100.000 -name fpga_sysref [get_ports fpga_sysref_p]

# PLL control
set_property -dict {LOC AW6  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {lmk_rst}]
set_property -dict {LOC AW4  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {lmk_clkin_s[0]}]
set_property -dict {LOC AW3  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {lmk_clkin_s[1]}]

set_false_path -to [get_ports {lmk_rst}]
set_output_delay 0 [get_ports {lmk_rst}]
