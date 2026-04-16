# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# Micro SD
set_property -dict {LOC Y15  IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_clk}]  ;# SD1.5 CLK SCLK
set_property -dict {LOC AA15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_cmd}]  ;# SD1.3 CMD DI
set_property -dict {LOC AB14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[0]}] ;# SD1.7 D0 DO
set_property -dict {LOC AA14 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[1]}] ;# SD1.8 D1
set_property -dict {LOC AB16 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[2]}] ;# SD1.1 D2
set_property -dict {LOC AB15 IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_d[3]}] ;# SD1.2 D3 CS
set_property -dict {LOC Y16  IOSTANDARD LVCMOS33 SLEW FAST DRIVE 8} [get_ports {sd_cd}]   ;# SD1.9 CD
