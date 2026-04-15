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

# LEDs
set_property -dict {LOC BA24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[0]}]
set_property -dict {LOC BB24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[1]}]
set_property -dict {LOC BC24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[2]}]
set_property -dict {LOC BD24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[3]}]
set_property -dict {LOC AP25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[4]}]
set_property -dict {LOC BD25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[5]}]
set_property -dict {LOC BC26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[6]}]
set_property -dict {LOC BC27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[7]}]

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Push buttons
set_property -dict {LOC B31  IOSTANDARD LVCMOS12} [get_ports {btn[0]}]
set_property -dict {LOC C31  IOSTANDARD LVCMOS12} [get_ports {btn[1]}]

set_false_path -from [get_ports {btn[*]}]
set_input_delay 0 [get_ports {btn[*]}]

# DIP switches
set_property -dict {LOC P33  IOSTANDARD LVCMOS12} [get_ports {sw[0]}]
set_property -dict {LOC K34  IOSTANDARD LVCMOS12} [get_ports {sw[1]}]
set_property -dict {LOC E35  IOSTANDARD LVCMOS12} [get_ports {sw[2]}]
set_property -dict {LOC H38  IOSTANDARD LVCMOS12} [get_ports {sw[3]}]
set_property -dict {LOC D35  IOSTANDARD LVCMOS12} [get_ports {sw[4]}]
set_property -dict {LOC D36  IOSTANDARD LVCMOS12} [get_ports {sw[5]}]
set_property -dict {LOC E37  IOSTANDARD LVCMOS12} [get_ports {sw[6]}]
set_property -dict {LOC F38  IOSTANDARD LVCMOS12} [get_ports {sw[7]}]

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# GPIO
#set_property -dict {LOC AY25 IOSTANDARD LVCMOS18} [get_ports {gpio[0]}]
#set_property -dict {LOC AW25 IOSTANDARD LVCMOS18} [get_ports {gpio[1]}]
#set_property -dict {LOC AU26 IOSTANDARD LVCMOS18} [get_ports {gpio[2]}]
#set_property -dict {LOC BD26 IOSTANDARD LVCMOS18} [get_ports {gpio[3]}]
#set_property -dict {LOC BE27 IOSTANDARD LVCMOS18} [get_ports {gpio[4]}]
#set_property -dict {LOC BE26 IOSTANDARD LVCMOS18} [get_ports {gpio[5]}]
#set_property -dict {LOC AU25 IOSTANDARD LVCMOS18} [get_ports {gpio[6]}]
#set_property -dict {LOC AR26 IOSTANDARD LVCMOS18} [get_ports {gpio[7]}]

#set_false_path -to [get_ports {gpio[*]}]
#set_output_delay 0 [get_ports {gpio[*]}]

# UART
set_property -dict {LOC BB27 IOSTANDARD LVCMOS18} [get_ports uart_txd]
set_property -dict {LOC AY27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports uart_rxd]
set_property -dict {LOC BC28 IOSTANDARD LVCMOS18} [get_ports uart_rts]
set_property -dict {LOC AY28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports uart_cts]
set_property -dict {LOC AY26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports uart_rst_n]
set_property -dict {LOC BB26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports uart_suspend_n]
#set_property -dict {LOC AW28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_gpio[0]}]
#set_property -dict {LOC AV28 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_gpio[1]}]
#set_property -dict {LOC AV27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_gpio[2]}]
#set_property -dict {LOC AU27 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_gpio[3]}]

set_false_path -to [get_ports {uart_rxd uart_cts uart_rst_n uart_suspend_n}]
set_output_delay 0 [get_ports {uart_rxd uart_cts uart_rst_n uart_suspend_n}]
set_false_path -from [get_ports {uart_txd uart_rts}]
set_input_delay 0 [get_ports {uart_txd uart_rts}]
