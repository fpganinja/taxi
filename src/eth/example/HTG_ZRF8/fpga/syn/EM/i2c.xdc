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

# I2C
set_property -dict {LOC AU2  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports i2c_scl]
set_property -dict {LOC AU1  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports i2c_sda]
set_property -dict {LOC AV2  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports i2c_rst_n]

set_false_path -to [get_ports {i2c_sda i2c_scl i2c_rst_n}]
set_output_delay 0 [get_ports {i2c_sda i2c_scl i2c_rst_n}]
set_false_path -from [get_ports {i2c_sda i2c_scl}]
set_input_delay 0 [get_ports {i2c_sda i2c_scl}]
