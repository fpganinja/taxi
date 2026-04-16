# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# LEDs
set_property -dict {LOC AT32 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[0]}] ;# DS7
set_property -dict {LOC AV34 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[1]}] ;# DS6
set_property -dict {LOC AY30 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[2]}] ;# DS8
set_property -dict {LOC BB32 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[3]}] ;# DS9
set_property -dict {LOC BF32 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[4]}] ;# DS10
set_property -dict {LOC AU37 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[5]}] ;# DS12
set_property -dict {LOC AV36 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[6]}] ;# DS13
set_property -dict {LOC BA37 IOSTANDARD LVCMOS12 SLEW SLOW DRIVE 8} [get_ports {led[7]}] ;# DS18

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Reset button
set_property -dict {LOC L19  IOSTANDARD LVCMOS12} [get_ports {reset}] ;# SW5

set_false_path -from [get_ports {reset}]
set_input_delay 0 [get_ports {reset}]

# Push buttons
set_property -dict {LOC BB24 IOSTANDARD LVCMOS18} [get_ports {btnu}] ;# SW10
set_property -dict {LOC BF22 IOSTANDARD LVCMOS18} [get_ports {btnl}] ;# SW6
set_property -dict {LOC BE22 IOSTANDARD LVCMOS18} [get_ports {btnd}] ;# SW17
set_property -dict {LOC BE23 IOSTANDARD LVCMOS18} [get_ports {btnr}] ;# SW9
set_property -dict {LOC BD23 IOSTANDARD LVCMOS18} [get_ports {btnc}] ;# SW7

set_false_path -from [get_ports {btnu btnl btnd btnr btnc}]
set_input_delay 0 [get_ports {btnu btnl btnd btnr btnc}]

# DIP switches
set_property -dict {LOC B17  IOSTANDARD LVCMOS12} [get_ports {sw[0]}] ;# SW12.1
set_property -dict {LOC G16  IOSTANDARD LVCMOS12} [get_ports {sw[1]}] ;# SW12.2
set_property -dict {LOC J16  IOSTANDARD LVCMOS12} [get_ports {sw[2]}] ;# SW12.3
set_property -dict {LOC D21  IOSTANDARD LVCMOS12} [get_ports {sw[3]}] ;# SW12.4

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# UART (U34 CP2105 SCI)
set_property -dict {LOC BB21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_txd}] ;# U34.20 RXD_SCI_I
set_property -dict {LOC AW25 IOSTANDARD LVCMOS18} [get_ports {uart_rxd}] ;# U34.21 TXD_SCI_O
set_property -dict {LOC BB22 IOSTANDARD LVCMOS18} [get_ports {uart_rts}] ;# U34.19 RTS_SCI_O
set_property -dict {LOC AY25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_cts}] ;# U34.18 CTS_SCI_I

set_false_path -to [get_ports {uart_txd uart_cts}]
set_output_delay 0 [get_ports {uart_txd uart_cts}]
set_false_path -from [get_ports {uart_rxd uart_rts}]
set_input_delay 0 [get_ports {uart_rxd uart_rts}]
