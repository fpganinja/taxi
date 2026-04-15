# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# QSPI flash
set_property -dict {LOC M20  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[0]}]
set_property -dict {LOC L20  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[1]}]
set_property -dict {LOC R21  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[2]}]
set_property -dict {LOC R22  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_dq[3]}]
set_property -dict {LOC G26  IOSTANDARD LVCMOS18 DRIVE 12} [get_ports {qspi_1_cs}]

set_false_path -to [get_ports {qspi_1_dq[*] qspi_1_cs}]
set_output_delay 0 [get_ports {qspi_1_dq[*] qspi_1_cs}]
set_false_path -from [get_ports {qspi_1_dq}]
set_input_delay 0 [get_ports {qspi_1_dq}]
