# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# PMOD0
set_property -dict {LOC AK25 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[0]}] ;# J52.1
set_property -dict {LOC AN21 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[1]}] ;# J52.3
set_property -dict {LOC AH18 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[2]}] ;# J52.5
set_property -dict {LOC AM19 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[3]}] ;# J52.7
set_property -dict {LOC AE26 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[4]}] ;# J52.2
set_property -dict {LOC AF25 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[5]}] ;# J52.4
set_property -dict {LOC AE21 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[6]}] ;# J52.6
set_property -dict {LOC AM17 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {pmod0[7]}] ;# J52.8

set_false_path -to [get_ports {pmod0[*]}]
set_output_delay 0 [get_ports {pmod0[*]}]
