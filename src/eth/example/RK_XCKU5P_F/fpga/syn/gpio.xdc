# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# LEDs
set_property -dict {LOC H9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[0]}] ;# LED2
set_property -dict {LOC J9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[1]}] ;# LED3
set_property -dict {LOC G11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[2]}] ;# LED4
set_property -dict {LOC H11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[3]}] ;# LED5

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Buttons
set_property -dict {LOC K9   IOSTANDARD LVCMOS33} [get_ports {btn[0]}] ;# K1
set_property -dict {LOC K10  IOSTANDARD LVCMOS33} [get_ports {btn[1]}] ;# K2
set_property -dict {LOC J10  IOSTANDARD LVCMOS33} [get_ports {btn[2]}] ;# K3
set_property -dict {LOC J11  IOSTANDARD LVCMOS33} [get_ports {btn[3]}] ;# K4

set_false_path -from [get_ports {btn[*]}]
set_input_delay 0 [get_ports {btn[*]}]

# GPIO
#set_property -dict {LOC D10  IOSTANDARD LVCMOS33} [get_ports {gpio[0]}]  ;# J1.3
#set_property -dict {LOC D11  IOSTANDARD LVCMOS33} [get_ports {gpio[1]}]  ;# J1.4
#set_property -dict {LOC E10  IOSTANDARD LVCMOS33} [get_ports {gpio[2]}]  ;# J1.5
#set_property -dict {LOC E11  IOSTANDARD LVCMOS33} [get_ports {gpio[3]}]  ;# J1.6
#set_property -dict {LOC B11  IOSTANDARD LVCMOS33} [get_ports {gpio[4]}]  ;# J1.7
#set_property -dict {LOC C11  IOSTANDARD LVCMOS33} [get_ports {gpio[5]}]  ;# J1.8
#set_property -dict {LOC C9   IOSTANDARD LVCMOS33} [get_ports {gpio[6]}]  ;# J1.9
#set_property -dict {LOC D9   IOSTANDARD LVCMOS33} [get_ports {gpio[7]}]  ;# J1.10
#set_property -dict {LOC A9   IOSTANDARD LVCMOS33} [get_ports {gpio[8]}]  ;# J1.11
#set_property -dict {LOC B9   IOSTANDARD LVCMOS33} [get_ports {gpio[9]}]  ;# J1.12
#set_property -dict {LOC A10  IOSTANDARD LVCMOS33} [get_ports {gpio[10]}] ;# J1.13
#set_property -dict {LOC B10  IOSTANDARD LVCMOS33} [get_ports {gpio[11]}] ;# J1.14
#set_property -dict {LOC A12  IOSTANDARD LVCMOS33} [get_ports {gpio[12]}] ;# J1.15
#set_property -dict {LOC A13  IOSTANDARD LVCMOS33} [get_ports {gpio[13]}] ;# J1.16
#set_property -dict {LOC A14  IOSTANDARD LVCMOS33} [get_ports {gpio[14]}] ;# J1.17
#set_property -dict {LOC B14  IOSTANDARD LVCMOS33} [get_ports {gpio[15]}] ;# J1.18
#set_property -dict {LOC C13  IOSTANDARD LVCMOS33} [get_ports {gpio[16]}] ;# J1.19
#set_property -dict {LOC C14  IOSTANDARD LVCMOS33} [get_ports {gpio[17]}] ;# J1.20
#set_property -dict {LOC B12  IOSTANDARD LVCMOS33} [get_ports {gpio[18]}] ;# J1.21
#set_property -dict {LOC C12  IOSTANDARD LVCMOS33} [get_ports {gpio[19]}] ;# J1.22
#set_property -dict {LOC D13  IOSTANDARD LVCMOS33} [get_ports {gpio[20]}] ;# J1.23
#set_property -dict {LOC D14  IOSTANDARD LVCMOS33} [get_ports {gpio[21]}] ;# J1.24
#set_property -dict {LOC E12  IOSTANDARD LVCMOS33} [get_ports {gpio[22]}] ;# J1.25
#set_property -dict {LOC E13  IOSTANDARD LVCMOS33} [get_ports {gpio[23]}] ;# J1.26
#set_property -dict {LOC F13  IOSTANDARD LVCMOS33} [get_ports {gpio[24]}] ;# J1.27
#set_property -dict {LOC F14  IOSTANDARD LVCMOS33} [get_ports {gpio[25]}] ;# J1.28
#set_property -dict {LOC F12  IOSTANDARD LVCMOS33} [get_ports {gpio[26]}] ;# J1.29
#set_property -dict {LOC G12  IOSTANDARD LVCMOS33} [get_ports {gpio[27]}] ;# J1.30
#set_property -dict {LOC G14  IOSTANDARD LVCMOS33} [get_ports {gpio[28]}] ;# J1.31
#set_property -dict {LOC H14  IOSTANDARD LVCMOS33} [get_ports {gpio[29]}] ;# J1.32
#set_property -dict {LOC J14  IOSTANDARD LVCMOS33} [get_ports {gpio[30]}] ;# J1.33
#set_property -dict {LOC J15  IOSTANDARD LVCMOS33} [get_ports {gpio[31]}] ;# J1.34
#set_property -dict {LOC H13  IOSTANDARD LVCMOS33} [get_ports {gpio[32]}] ;# J1.35
#set_property -dict {LOC J13  IOSTANDARD LVCMOS33} [get_ports {gpio[33]}] ;# J1.36

# UART
set_property -dict {LOC AC14 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {uart_txd}] ;# U9.38 BDBUS0
set_property -dict {LOC AD13 IOSTANDARD LVCMOS33} [get_ports {uart_rxd}] ;# U9.39 BDBUS1

set_false_path -to [get_ports {uart_txd}]
set_output_delay 0 [get_ports {uart_txd}]
set_false_path -from [get_ports {uart_rxd}]
set_input_delay 0 [get_ports {uart_rxd}]

# Fan
#set_property -dict {LOC G9 IOSTANDARD LVCMOS33 QUIETIO SLOW DRIVE 8} [get_ports {fan}] ;# J2
