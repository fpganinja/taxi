# SPDX-License-Identifier: MIT
#
# Copyright (c) 2021-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-9200 board
# part: xcvu9p-flgb2104-2-e
# part: xcvu13p-fhgb2104-2-e

# QSPI flash
set_property -dict {LOC AM26 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {qspi_1_dq[0]}]
set_property -dict {LOC AN26 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {qspi_1_dq[1]}]
set_property -dict {LOC AL25 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {qspi_1_dq[2]}]
set_property -dict {LOC AM25 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {qspi_1_dq[3]}]
set_property -dict {LOC BF27 IOSTANDARD LVCMOS18 DRIVE 8} [get_ports {qspi_1_cs_n}]

set_false_path -to [get_ports {qspi_1_dq[*] qspi_1_cs}]
set_output_delay 0 [get_ports {qspi_1_dq[*] qspi_1_cs}]
set_false_path -from [get_ports {qspi_1_dq}]
set_input_delay 0 [get_ports {qspi_1_dq}]
