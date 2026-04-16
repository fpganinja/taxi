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

# PLL refclk from U2 (250 MHz)
set_property -dict {LOC AU4  IOSTANDARD LVDS_25} [get_ports fpga_refclk_p] ;# U2.60 CLKout13_P
set_property -dict {LOC AU3  IOSTANDARD LVDS_25} [get_ports fpga_refclk_n] ;# U2.61 CLKout13_N
create_clock -period 4.000 -name fpga_refclk [get_ports fpga_refclk_p]

# Source pin is in an HDIO bank, so it must be routed to an MMCM via a BUFG
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets fpga_refclk_int fpga_refclk_bufg_inst_n_0]

# PLL sysref from U2
set_property -dict {LOC AT5  IOSTANDARD LVDS_25} [get_ports fpga_sysref_p] ;# U2.62 CLKout12_P
set_property -dict {LOC AU5  IOSTANDARD LVDS_25} [get_ports fpga_sysref_n] ;# U2.63 CLKout12_N
create_clock -period 100.000 -name fpga_sysref [get_ports fpga_sysref_p]
