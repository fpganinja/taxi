# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# LEDs
set_property -dict {LOC AP8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[0]}] ;# to DS7
set_property -dict {LOC H23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[1]}] ;# to DS6
set_property -dict {LOC P20  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[2]}] ;# to DS8
set_property -dict {LOC P21  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[3]}] ;# to DS9
set_property -dict {LOC N22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[4]}] ;# to DS10
set_property -dict {LOC M22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[5]}] ;# to DS33
set_property -dict {LOC R23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[6]}] ;# to DS32
set_property -dict {LOC P23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {led[7]}] ;# to DS31

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Reset button
set_property -dict {LOC AN8  IOSTANDARD LVCMOS18} [get_ports reset] ;# from SW5

set_false_path -from [get_ports {reset}]
set_input_delay 0 [get_ports {reset}]

# Push buttons
set_property -dict {LOC AD10 IOSTANDARD LVCMOS18} [get_ports btnu] ;# from SW10
set_property -dict {LOC AF9  IOSTANDARD LVCMOS18} [get_ports btnl] ;# from SW6
set_property -dict {LOC AF8  IOSTANDARD LVCMOS18} [get_ports btnd] ;# from SW8
set_property -dict {LOC AE8  IOSTANDARD LVCMOS18} [get_ports btnr] ;# from SW9
set_property -dict {LOC AE10 IOSTANDARD LVCMOS18} [get_ports btnc] ;# from SW7

set_false_path -from [get_ports {btnu btnl btnd btnr btnc}]
set_input_delay 0 [get_ports {btnu btnl btnd btnr btnc}]

# DIP switches
set_property -dict {LOC AN16 IOSTANDARD LVCMOS12} [get_ports {sw[0]}] ;# from SW12.4
set_property -dict {LOC AN19 IOSTANDARD LVCMOS12} [get_ports {sw[1]}] ;# from SW12.3
set_property -dict {LOC AP18 IOSTANDARD LVCMOS12} [get_ports {sw[2]}] ;# from SW12.2
set_property -dict {LOC AN14 IOSTANDARD LVCMOS12} [get_ports {sw[3]}] ;# from SW12.1

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# UART (U34 CP2105 SCI)
set_property -dict {LOC K26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_txd}] ;# U34.20 RXD_SCI_I
set_property -dict {LOC G25  IOSTANDARD LVCMOS18} [get_ports {uart_rxd}] ;# U34.21 TXD_SCI_O
set_property -dict {LOC L23  IOSTANDARD LVCMOS18} [get_ports {uart_rts}] ;# U34.19 RTS_SCI_O
set_property -dict {LOC K27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {uart_cts}] ;# U34.18 CTS_SCI_I

set_false_path -to [get_ports {uart_txd uart_cts}]
set_output_delay 0 [get_ports {uart_txd uart_cts}]
set_false_path -from [get_ports {uart_rxd uart_rts}]
set_input_delay 0 [get_ports {uart_rxd uart_rts}]
