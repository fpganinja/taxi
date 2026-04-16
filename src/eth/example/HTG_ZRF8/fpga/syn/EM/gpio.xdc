# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-EM board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# LEDs
set_property -dict {LOC AP6  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[0]}] ;# D16
set_property -dict {LOC AW5  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[1]}] ;# D15
set_property -dict {LOC AW6  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[2]}] ;# D14
set_property -dict {LOC AR6  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[3]}] ;# D3

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Push buttons
set_property -dict {LOC AG14 IOSTANDARD LVCMOS12} [get_ports {btn}] ;# PB4

set_false_path -from [get_ports {btn}]
set_input_delay 0 [get_ports {btn}]

# DIP switches
set_property -dict {LOC E19  IOSTANDARD LVCMOS12} [get_ports {sw[0]}] ;# S1.1
set_property -dict {LOC D19  IOSTANDARD LVCMOS12} [get_ports {sw[1]}] ;# S1.2
set_property -dict {LOC C18  IOSTANDARD LVCMOS12} [get_ports {sw[2]}] ;# S1.3
set_property -dict {LOC A25  IOSTANDARD LVCMOS12} [get_ports {sw[3]}] ;# S1.4

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# GPIO
set_property -dict {LOC N21  IOSTANDARD LVCMOS12} [get_ports {gpio[0]}] ;# J32.1
set_property -dict {LOC M12  IOSTANDARD LVCMOS12} [get_ports {gpio[1]}] ;# J32.3
set_property -dict {LOC F22  IOSTANDARD LVCMOS12} [get_ports {gpio[2]}] ;# J32.5
set_property -dict {LOC B23  IOSTANDARD LVCMOS12} [get_ports {gpio[3]}] ;# J32.7
set_property -dict {LOC G24  IOSTANDARD LVCMOS12} [get_ports {gpio[4]}] ;# J32.9
set_property -dict {LOC D20  IOSTANDARD LVCMOS12} [get_ports {gpio[5]}] ;# J32.11
set_property -dict {LOC J24  IOSTANDARD LVCMOS12} [get_ports {gpio[6]}] ;# J32.13
set_property -dict {LOC H15  IOSTANDARD LVCMOS12} [get_ports {gpio[7]}] ;# J32.15

set_false_path -to [get_ports {gpio[*]}]
set_output_delay 0 [get_ports {gpio[*]}]

# UART
set_property -dict {LOC AV7  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_rxd]
set_property -dict {LOC AV8  IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {LOC AU8  IOSTANDARD LVCMOS33} [get_ports uart_rts]
set_property -dict {LOC AU7  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_cts]
set_property -dict {LOC AT6  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_rst_n]
set_property -dict {LOC AT7  IOSTANDARD LVCMOS33} [get_ports uart_suspend_n]

set_false_path -to [get_ports {uart_rxd uart_cts uart_rst_n}]
set_output_delay 0 [get_ports {uart_rxd uart_cts uart_rst_n}]
set_false_path -from [get_ports {uart_txd uart_rts uart_suspend_n}]
set_input_delay 0 [get_ports {uart_txd uart_rts uart_suspend_n}]
