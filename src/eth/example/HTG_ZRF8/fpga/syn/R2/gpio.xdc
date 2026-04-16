# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-R2 board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# LEDs
set_property -dict {LOC A6   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[0]}] ;# D10
set_property -dict {LOC C6   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[1]}] ;# D9
set_property -dict {LOC D6   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[2]}] ;# D8
set_property -dict {LOC E6   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {led[3]}] ;# D7

set_false_path -to [get_ports {led[*]}]
set_output_delay 0 [get_ports {led[*]}]

# Push buttons
set_property -dict {LOC AT5  IOSTANDARD LVCMOS33} [get_ports {btn}] ;# PB3

set_false_path -from [get_ports {btn}]
set_input_delay 0 [get_ports {btn}]

# DIP switches
set_property -dict {LOC D20  IOSTANDARD LVCMOS12} [get_ports {sw[0]}] ;# S1.1
set_property -dict {LOC A25  IOSTANDARD LVCMOS12} [get_ports {sw[1]}] ;# S1.2
set_property -dict {LOC B23  IOSTANDARD LVCMOS12} [get_ports {sw[2]}] ;# S1.3
set_property -dict {LOC D19  IOSTANDARD LVCMOS12} [get_ports {sw[3]}] ;# S1.4

set_false_path -from [get_ports {sw[*]}]
set_input_delay 0 [get_ports {sw[*]}]

# Trace
#set_property -dict {LOC AR16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[0]}]  ;# J22.38
#set_property -dict {LOC AN17 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[1]}]  ;# J22.28
#set_property -dict {LOC AM17 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[2]}]  ;# J22.26
#set_property -dict {LOC AF16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[3]}]  ;# J22.24
#set_property -dict {LOC AP14 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[4]}]  ;# J22.22
#set_property -dict {LOC AR14 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[5]}]  ;# J22.20
#set_property -dict {LOC AT13 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[6]}]  ;# J22.18
#set_property -dict {LOC AT15 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[7]}]  ;# J22.16
#set_property -dict {LOC AN16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[8]}]  ;# J22.37
#set_property -dict {LOC AK17 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[9]}]  ;# J22.35
#set_property -dict {LOC AR13 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[10]}] ;# J22.33
#set_property -dict {LOC AU13 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[11]}] ;# J22.31
#set_property -dict {LOC AK16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[12]}] ;# J22.29
#set_property -dict {LOC AL15 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[13]}] ;# J22.27
#set_property -dict {LOC AH14 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[14]}] ;# J22.25
#set_property -dict {LOC AJ16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_data[15]}] ;# J22.23
#set_property -dict {LOC AL16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_clk}]      ;# J22.6
#set_property -dict {LOC AT16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_tdi}]      ;# J22.19
#set_property -dict {LOC AH16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_tdo}]      ;# J22.11
#set_property -dict {LOC AF17 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_tms}]      ;# J22.17
#set_property -dict {LOC AG17 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_tck}]      ;# J22.15
#set_property -dict {LOC AL17 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_rtck}]     ;# J22.13
#set_property -dict {LOC AJ15 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_dbgrq}]    ;# J22.7
#set_property -dict {LOC AU14 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_dbgack}]   ;# J22.8
#set_property -dict {LOC AP15 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_trst_b}]   ;# J22.21
#set_property -dict {LOC AH15 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_srst_b}]   ;# J22.9
#set_property -dict {LOC AP16 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_ctl}]      ;# J22.36
#set_property -dict {LOC AU15 IOSTANDARD LVCMOS18 SLEW FAST DRIVE 8} [get_ports {trace_exttrig}]  ;# J22.10

#set_false_path -to [get_ports {trace_data trace_clk trace_tdi trace_tdo trace_tms trace_tck trace_rtck trace_dbgrq trace_dbgack trace_rst_b trace_ctl trace_exttrig[*]}]
#set_output_delay 0 [get_ports {trace_data trace_clk trace_tdi trace_tdo trace_tms trace_tck trace_rtck trace_dbgrq trace_dbgack trace_rst_b trace_ctl trace_exttrig[*]}]

# UART
set_property -dict {LOC AU8  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_rxd]
set_property -dict {LOC AV8  IOSTANDARD LVCMOS33} [get_ports uart_txd]
set_property -dict {LOC AV7  IOSTANDARD LVCMOS33} [get_ports uart_rts]
set_property -dict {LOC AU7  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_cts]
set_property -dict {LOC AT7  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports uart_rst_n]
set_property -dict {LOC AR7  IOSTANDARD LVCMOS33} [get_ports uart_suspend_n]

set_false_path -to [get_ports {uart_rxd uart_cts uart_rst_n}]
set_output_delay 0 [get_ports {uart_rxd uart_cts uart_rst_n}]
set_false_path -from [get_ports {uart_txd uart_rts uart_suspend_n}]
set_input_delay 0 [get_ports {uart_txd uart_rts uart_suspend_n}]
