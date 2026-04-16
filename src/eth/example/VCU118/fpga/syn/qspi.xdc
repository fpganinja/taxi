# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# QSPI flash
set_property -dict {LOC AM19 IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[0]}]
set_property -dict {LOC AM18 IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[1]}]
set_property -dict {LOC AN20 IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[2]}]
set_property -dict {LOC AP20 IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[3]}]
set_property -dict {LOC BF16 IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_cs}]

set_false_path -to [get_ports {qspi_1_dq[*] qspi_1_cs}]
set_output_delay 0 [get_ports {qspi_1_dq[*] qspi_1_cs}]
set_false_path -from [get_ports {qspi_1_dq}]
set_input_delay 0 [get_ports {qspi_1_dq}]
