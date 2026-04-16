# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A02 board
# part: xcvu5p-flva2104-2-e

# LEDs
set_property -dict {LOC R26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[0]}] ;# D5
set_property -dict {LOC M28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[1]}] ;# D6
set_property -dict {LOC R27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[2]}] ;# D7
set_property -dict {LOC T24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[3]}] ;# D8
set_property -dict {LOC J27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][0]}] ;# D16
set_property -dict {LOC K27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][1]}] ;# D17
set_property -dict {LOC L25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][2]}] ;# D18
set_property -dict {LOC L24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][3]}] ;# D29
set_property -dict {LOC B28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][0]}] ;# D27
set_property -dict {LOC C27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][1]}] ;# D28
set_property -dict {LOC J25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][2]}] ;# D29
set_property -dict {LOC K26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][3]}] ;# D30
set_property -dict {LOC D27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_red}] ;# D52
set_property -dict {LOC D26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_green}] ;# D52
set_property -dict {LOC AN21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_sync[0]}] ;# D54
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_sync[1]}] ;# D56
set_property -dict {LOC M15  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {eth_led_yellow}] ;# J28
set_property -dict {LOC M13  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {eth_led_green}] ;# J28

set_false_path -to [get_ports {led[*] qsfp_led[*][*] led_red led_green led_sync[*] eth_led_yellow eth_led_green}]
set_output_delay 0 [get_ports {led[*] qsfp_led[*][*] led_red led_green led_sync[*] eth_led_yellow eth_led_green}]

# Si5340 U18
set_property -dict {LOC AT36 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports si5340_i2c_scl] ;# U23.14 SCLK
set_property -dict {LOC AT35 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports si5340_i2c_sda] ;# U23.13 SDA
set_property -dict {LOC AT37 IOSTANDARD LVCMOS18} [get_ports si5340_intr] ;# U18.33 INTR

set_false_path -to [get_ports {si5340_i2c_scl si5340_i2c_sda}]
set_output_delay 0 [get_ports {si5340_i2c_scl si5340_i2c_sda}]
set_false_path -from [get_ports {si5340_i2c_scl si5340_i2c_sda si5340_intr}]
set_input_delay 0 [get_ports {si5340_i2c_scl si5340_i2c_sda si5340_intr}]
