# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Alibaba AS02MC04
# part: xcku3p-ffvb676-1-e

# LEDs
set_property -dict {LOC B12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {sfp_led[0]}] ;# DS3
set_property -dict {LOC C12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {sfp_led[1]}] ;# DS2
set_property -dict {LOC B11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[0]}] ;# DS6
set_property -dict {LOC C11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[1]}] ;# DS7
set_property -dict {LOC A10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[2]}] ;# DS8
set_property -dict {LOC B10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[3]}] ;# DS9
set_property -dict {LOC A13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led_r}] ;# C1
set_property -dict {LOC A12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led_g}] ;# C1
set_property -dict {LOC B9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led_hb}] ;# DS5

set_false_path -to [get_ports {sfp_led[*] led[*] led_r led_g led_hb}]
set_output_delay 0 [get_ports {sfp_led[*] led[*] led_r led_g led_hb}]

# Reset button
set_property -dict {LOC F12  IOSTANDARD LVCMOS33} [get_ports reset] ;# SW1

set_false_path -from [get_ports {reset}]
set_input_delay 0 [get_ports {reset}]

# GPIO
#set_property -dict {LOC A14 IOSTANDARD LVCMOS33} [get_ports {gpio[0]}] ;# J5.3,4
#set_property -dict {LOC E12 IOSTANDARD LVCMOS33} [get_ports {gpio[1]}] ;# J5.5,6
#set_property -dict {LOC E13 IOSTANDARD LVCMOS33} [get_ports {gpio[2]}] ;# J5.7,8
#set_property -dict {LOC F10 IOSTANDARD LVCMOS33} [get_ports {gpio[3]}] ;# J5.9,10
#set_property -dict {LOC C9  IOSTANDARD LVCMOS33} [get_ports {gpio[4]}] ;# J5.11,12
#set_property -dict {LOC D9  IOSTANDARD LVCMOS33} [get_ports {gpio[5]}] ;# J5.13,14

# 1-wire for DS28E15
#set_property -dict {LOC A15  IOSTANDARD LVCMOS33} [get_ports {onewire}] ;# U3 DS28E15
