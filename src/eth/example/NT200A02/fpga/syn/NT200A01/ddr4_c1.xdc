# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A01 board
# part: xcvu095-ffva2104-2-e

# 100 MHz DDR4 C1 clock from Si5340 OUT0 via U167
set_property -dict {LOC BB39 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c1_p]
set_property -dict {LOC BB38 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c1_n]
create_clock -period 10.000 -name clk_ddr_c1 [get_ports clk_ddr_c1_p]
