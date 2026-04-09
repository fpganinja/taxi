# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Alibaba AS02MC04
# part: xcku3p-ffvb676-1-e

# SMBus interface
# PCIe SMBus pins
# U4 PCA9535 0x20
# U10 M24C24 0x50 "SYS_FRU"
set_property -dict {LOC G9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {smbclk}]
set_property -dict {LOC G10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {smbdat}]

set_false_path -to [get_ports {smbdat smbclk}]
set_output_delay 0 [get_ports {smbdat smbclk}]
set_false_path -from [get_ports {smbdat smbclk}]
set_input_delay 0 [get_ports {smbdat smbclk}]
