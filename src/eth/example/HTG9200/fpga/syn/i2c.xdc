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

# I2C
set_property -dict {LOC BB21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_main_scl]
set_property -dict {LOC BC21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_main_sda]
set_property -dict {LOC BF20 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_main_rst_n]

set_false_path -to [get_ports {i2c_main_sda i2c_main_scl i2c_main_rst_n}]
set_output_delay 0 [get_ports {i2c_main_sda i2c_main_scl i2c_main_rst_n}]
set_false_path -from [get_ports {i2c_main_sda i2c_main_scl}]
set_input_delay 0 [get_ports {i2c_main_sda i2c_main_scl}]
