# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the ADM-PCIE-9V3
# part: xcvu3p-ffvc1517-2-i

# I2C interface
set_property -dict {LOC AT25 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_i2c_scl]
set_property -dict {LOC AT26 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_i2c_sda]
set_property -dict {LOC AP23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports eeprom_wp]

set_false_path -to [get_ports {eeprom_i2c_sda eeprom_i2c_scl eeprom_wp}]
set_output_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl eeprom_wp}]
set_false_path -from [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
set_input_delay 0 [get_ports {eeprom_i2c_sda eeprom_i2c_scl}]
