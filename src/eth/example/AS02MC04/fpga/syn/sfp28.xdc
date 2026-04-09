# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Alibaba AS02MC04
# part: xcku3p-ffvb676-1-e

# SFP28 Interfaces
set_property -dict {LOC A4  } [get_ports {sfp_rx_p[0]}] ;# MGTYRXP3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC A3  } [get_ports {sfp_rx_n[0]}] ;# MGTYRXN3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B2  } [get_ports {sfp_rx_p[1]}] ;# MGTYRXP2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B1  } [get_ports {sfp_rx_n[1]}] ;# MGTYRXN2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B7  } [get_ports {sfp_tx_p[0]}] ;# MGTYTXP3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B6  } [get_ports {sfp_tx_n[0]}] ;# MGTYTXN3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D7  } [get_ports {sfp_tx_p[1]}] ;# MGTYTXP2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D6  } [get_ports {sfp_tx_n[1]}] ;# MGTYTXN2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC K7  } [get_ports {sfp_mgt_refclk_p}] ;# MGTREFCLK0P_227 from Y1
set_property -dict {LOC K6  } [get_ports {sfp_mgt_refclk_n}] ;# MGTREFCLK0N_227 from Y1
set_property -dict {LOC D14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_npres[0]}]
set_property -dict {LOC E11  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_npres[1]}]
set_property -dict {LOC B14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_tx_fault[0]}]
set_property -dict {LOC F9   IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_tx_fault[1]}]
set_property -dict {LOC D13  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_los[0]}]
set_property -dict {LOC E10  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_los[1]}]
#set_property -dict {LOC C13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[0]}]
#set_property -dict {LOC D10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[1]}]
#set_property -dict {LOC C14  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[0]}]
#set_property -dict {LOC D11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[1]}]

# 156.25 MHz MGT reference clock
create_clock -period 6.4 -name sfp_mgt_refclk [get_ports {sfp_mgt_refclk_p}]

set_false_path -from [get_ports {sfp_npres[*] sfp_tx_fault[*] sfp_los[*]}]
set_input_delay 0 [get_ports {sfp_npres[*] sfp_tx_fault[*] sfp_los[*]}]

#set_false_path -to [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
#set_output_delay 0 [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
#set_false_path -from [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
#set_input_delay 0 [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
