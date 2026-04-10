# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the ADM-PCIE-9V3
# part: xcvu3p-ffvc1517-2-i

# LEDs
set_property -dict {LOC AT27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {user_led_g[0]}]
set_property -dict {LOC AU27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {user_led_g[1]}]
set_property -dict {LOC AU23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {user_led_r}]
set_property -dict {LOC AH24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {front_led[0]}]
set_property -dict {LOC AJ23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {front_led[1]}]

set_false_path -to [get_ports {user_led_g[*] user_led_r front_led[*]}]
set_output_delay 0 [get_ports {user_led_g[*] user_led_r front_led[*]}]

# Switches
set_property -dict {LOC AV27 IOSTANDARD LVCMOS18} [get_ports {user_sw[0]}]
set_property -dict {LOC AW27 IOSTANDARD LVCMOS18} [get_ports {user_sw[1]}]

set_false_path -from [get_ports {user_sw[*]}]
set_input_delay 0 [get_ports {user_sw[*]}]

# GPIO
#set_property -dict {LOC G30  IOSTANDARD LVCMOS18} [get_ports gpio_p[0]]
#set_property -dict {LOC F30  IOSTANDARD LVCMOS18} [get_ports gpio_n[0]]
#set_property -dict {LOC J31  IOSTANDARD LVCMOS18} [get_ports gpio_p[1]]
#set_property -dict {LOC H31  IOSTANDARD LVCMOS18} [get_ports gpio_n[1]]
