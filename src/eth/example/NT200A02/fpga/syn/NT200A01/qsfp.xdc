# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A01 board
# part: xcvu095-ffva2104-2-e

# QSFP28 Interfaces
set_property -dict {LOC R45 } [get_ports {qsfp0_rx_p[0]}] ;# MGTYRXP2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC R46 } [get_ports {qsfp0_rx_n[0]}] ;# MGTYRXN2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC M42 } [get_ports {qsfp0_tx_p[0]}] ;# MGTYTXP2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC M43 } [get_ports {qsfp0_tx_n[0]}] ;# MGTYTXN2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC U45 } [get_ports {qsfp0_rx_p[1]}] ;# MGTYRXP1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC U46 } [get_ports {qsfp0_rx_n[1]}] ;# MGTYRXN1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC P42 } [get_ports {qsfp0_tx_p[1]}] ;# MGTYTXP1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC P43 } [get_ports {qsfp0_tx_n[1]}] ;# MGTYTXN1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC N45 } [get_ports {qsfp0_rx_p[2]}] ;# MGTYRXP3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC N46 } [get_ports {qsfp0_rx_n[2]}] ;# MGTYRXN3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC K42 } [get_ports {qsfp0_tx_p[2]}] ;# MGTYTXP3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC K43 } [get_ports {qsfp0_tx_n[2]}] ;# MGTYTXN3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC W45 } [get_ports {qsfp0_rx_p[3]}] ;# MGTYRXP0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC W46 } [get_ports {qsfp0_rx_n[3]}] ;# MGTYRXN0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC T42 } [get_ports {qsfp0_tx_p[3]}] ;# MGTYTXP0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC T43 } [get_ports {qsfp0_tx_n[3]}] ;# MGTYTXN0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC V38 } [get_ports qsfp0_mgt_refclk_p] ;# MGTREFCLK0P_129 from Si5340 U23 OUT1
set_property -dict {LOC V39 } [get_ports qsfp0_mgt_refclk_n] ;# MGTREFCLK0N_129 from Si5340 U23 OUT1
set_property -dict {LOC A26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
set_property -dict {LOC C25  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_modprsl]
set_property -dict {LOC B26  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC G25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]
set_property -dict {LOC B25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_scl]
set_property -dict {LOC F25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_sda]

# 322.265625 MHz MGT reference clock
create_clock -period 3.103 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

set_false_path -to [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_output_delay 0 [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]

set_false_path -to [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_output_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_false_path -from [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_input_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]

set_property -dict {LOC G45 } [get_ports {qsfp1_rx_p[0]}] ;# MGTYRXP2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC G46 } [get_ports {qsfp1_rx_n[0]}] ;# MGTYRXN2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC D42 } [get_ports {qsfp1_tx_p[0]}] ;# MGTYTXP2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC D43 } [get_ports {qsfp1_tx_n[0]}] ;# MGTYTXN2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC J45 } [get_ports {qsfp1_rx_p[1]}] ;# MGTYRXP1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC J46 } [get_ports {qsfp1_rx_n[1]}] ;# MGTYRXN1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC F42 } [get_ports {qsfp1_tx_p[1]}] ;# MGTYTXP1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC F43 } [get_ports {qsfp1_tx_n[1]}] ;# MGTYTXN1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC E45 } [get_ports {qsfp1_rx_p[2]}] ;# MGTYRXP3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC E46 } [get_ports {qsfp1_rx_n[2]}] ;# MGTYRXN3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC B42 } [get_ports {qsfp1_tx_p[2]}] ;# MGTYTXP3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC B43 } [get_ports {qsfp1_tx_n[2]}] ;# MGTYTXN3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC L45 } [get_ports {qsfp1_rx_p[3]}] ;# MGTYRXP0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC L46 } [get_ports {qsfp1_rx_n[3]}] ;# MGTYRXN0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC H42 } [get_ports {qsfp1_tx_p[3]}] ;# MGTYTXP0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC H43 } [get_ports {qsfp1_tx_n[3]}] ;# MGTYTXN0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC R40 } [get_ports qsfp1_mgt_refclk_p] ;# MGTREFCLK0P_130 from Si5340 U23 OUT2
set_property -dict {LOC R41 } [get_ports qsfp1_mgt_refclk_n] ;# MGTREFCLK0N_130 from Si5340 U23 OUT2
set_property -dict {LOC B27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
set_property -dict {LOC H28  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC N24  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC H25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]
set_property -dict {LOC P27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_scl]
set_property -dict {LOC R24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_sda]

# 322.265625 MHz MGT reference clock
create_clock -period 3.103 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

set_false_path -to [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_output_delay 0 [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

set_false_path -to [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_output_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_false_path -from [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_input_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
