# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# I2C interface
set_property -dict {LOC J24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_scl]
set_property -dict {LOC J25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_sda]
set_property -dict {LOC AP10 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports i2c_mux_reset]

set_false_path -to [get_ports {i2c_sda i2c_scl}]
set_output_delay 0 [get_ports {i2c_sda i2c_scl}]
set_false_path -from [get_ports {i2c_sda i2c_scl}]
set_input_delay 0 [get_ports {i2c_sda i2c_scl}]
