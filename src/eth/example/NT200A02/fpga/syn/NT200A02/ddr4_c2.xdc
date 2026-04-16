# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A02 board
# part: xcvu5p-flva2104-2-e

# 100 MHz DDR4 C2 clock from Si5340 OUT0 via U167
set_property -dict {LOC B10  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c2_p]
set_property -dict {LOC C10  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c2_n]
create_clock -period 10.000 -name clk_ddr_c2 [get_ports clk_ddr_c2_p]
