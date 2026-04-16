# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A02 board
# part: xcvu5p-flva2104-2-e

# QSFP28 Interfaces
set_property -dict {LOC R45 } [get_ports {qsfp0_rx_p[0]}] ;# MGTYRXP2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC R46 } [get_ports {qsfp0_rx_n[0]}] ;# MGTYRXN2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC M42 } [get_ports {qsfp0_tx_p[0]}] ;# MGTYTXP2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC M43 } [get_ports {qsfp0_tx_n[0]}] ;# MGTYTXN2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC U45 } [get_ports {qsfp0_rx_p[1]}] ;# MGTYRXP1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC U46 } [get_ports {qsfp0_rx_n[1]}] ;# MGTYRXN1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC P42 } [get_ports {qsfp0_tx_p[1]}] ;# MGTYTXP1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC P43 } [get_ports {qsfp0_tx_n[1]}] ;# MGTYTXN1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC N45 } [get_ports {qsfp0_rx_p[2]}] ;# MGTYRXP3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC N46 } [get_ports {qsfp0_rx_n[2]}] ;# MGTYRXN3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC K42 } [get_ports {qsfp0_tx_p[2]}] ;# MGTYTXP3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC K43 } [get_ports {qsfp0_tx_n[2]}] ;# MGTYTXN3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC W45 } [get_ports {qsfp0_rx_p[3]}] ;# MGTYRXP0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC W46 } [get_ports {qsfp0_rx_n[3]}] ;# MGTYRXN0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC T42 } [get_ports {qsfp0_tx_p[3]}] ;# MGTYTXP0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC T43 } [get_ports {qsfp0_tx_n[3]}] ;# MGTYTXN0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC V38 } [get_ports qsfp0_mgt_refclk_p] ;# MGTREFCLK0P_131 from Si5340 U23 OUT1
set_property -dict {LOC V39 } [get_ports qsfp0_mgt_refclk_n] ;# MGTREFCLK0N_131 from Si5340 U23 OUT1
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

set_property -dict {LOC G45 } [get_ports {qsfp1_rx_p[0]}] ;# MGTYRXP2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC G46 } [get_ports {qsfp1_rx_n[0]}] ;# MGTYRXN2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC D42 } [get_ports {qsfp1_tx_p[0]}] ;# MGTYTXP2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC D43 } [get_ports {qsfp1_tx_n[0]}] ;# MGTYTXN2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J45 } [get_ports {qsfp1_rx_p[1]}] ;# MGTYRXP1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J46 } [get_ports {qsfp1_rx_n[1]}] ;# MGTYRXN1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC F42 } [get_ports {qsfp1_tx_p[1]}] ;# MGTYTXP1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC F43 } [get_ports {qsfp1_tx_n[1]}] ;# MGTYTXN1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC E45 } [get_ports {qsfp1_rx_p[2]}] ;# MGTYRXP3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC E46 } [get_ports {qsfp1_rx_n[2]}] ;# MGTYRXN3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC B42 } [get_ports {qsfp1_tx_p[2]}] ;# MGTYTXP3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC B43 } [get_ports {qsfp1_tx_n[2]}] ;# MGTYTXN3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L45 } [get_ports {qsfp1_rx_p[3]}] ;# MGTYRXP0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L46 } [get_ports {qsfp1_rx_n[3]}] ;# MGTYRXN0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC H42 } [get_ports {qsfp1_tx_p[3]}] ;# MGTYTXP0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC H43 } [get_ports {qsfp1_tx_n[3]}] ;# MGTYTXN0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC R40 } [get_ports qsfp1_mgt_refclk_p] ;# MGTREFCLK0P_132 from Si5340 U23 OUT2
set_property -dict {LOC R41 } [get_ports qsfp1_mgt_refclk_n] ;# MGTREFCLK0N_132 from Si5340 U23 OUT2
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
