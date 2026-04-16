# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A02 board
# part: xcvu5p-flva2104-2-e

# 100 MHz DDR4 C0 clock from Si5340 OUT0 via U167
set_property -dict {LOC BA19 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c0_p]
set_property -dict {LOC AY19 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c0_n]
create_clock -period 10.000 -name clk_ddr_c0 [get_ports clk_ddr_c0_p]
