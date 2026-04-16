# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# QSFP28 Interface
set_property -dict {LOC Y2  } [get_ports {qsfp_rx_p[0]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC Y1  } [get_ports {qsfp_rx_n[0]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA5 } [get_ports {qsfp_tx_p[0]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA4 } [get_ports {qsfp_tx_n[0]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V2  } [get_ports {qsfp_rx_p[1]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V1  } [get_ports {qsfp_rx_n[1]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W5  } [get_ports {qsfp_tx_p[1]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W4  } [get_ports {qsfp_tx_n[1]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T2  } [get_ports {qsfp_rx_p[2]}] ;# MGTYRXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T1  } [get_ports {qsfp_rx_n[2]}] ;# MGTYRXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U5  } [get_ports {qsfp_tx_p[2]}] ;# MGTYTXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U4  } [get_ports {qsfp_tx_n[2]}] ;# MGTYTXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P2  } [get_ports {qsfp_rx_p[3]}] ;# MGTYRXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P1  } [get_ports {qsfp_rx_n[3]}] ;# MGTYRXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R5  } [get_ports {qsfp_tx_p[3]}] ;# MGTYTXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R4  } [get_ports {qsfp_tx_n[3]}] ;# MGTYTXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V7  } [get_ports {qsfp_mgt_refclk_p}] ;# MGTREFCLK0P_225
set_property -dict {LOC V6  } [get_ports {qsfp_mgt_refclk_n}] ;# MGTREFCLK0N_225
set_property -dict {LOC W13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_modsell]
set_property -dict {LOC W12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_resetl]
set_property -dict {LOC AA13 IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_modprsl]
set_property -dict {LOC Y13  IOSTANDARD LVCMOS33 PULLUP true} [get_ports qsfp_intl]
set_property -dict {LOC W14  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports qsfp_lpmode]
set_property -dict {LOC AE15 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {qsfp_i2c_scl}]
set_property -dict {LOC AE13 IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {qsfp_i2c_sda}]

# 156.25 MHz MGT reference clock
create_clock -period 6.4 -name qsfp_mgt_refclk [get_ports {qsfp_mgt_refclk_p}]

set_false_path -to [get_ports {qsfp_modsell qsfp_resetl qsfp_lpmode}]
set_output_delay 0 [get_ports {qsfp_modsell qsfp_resetl qsfp_lpmode}]
set_false_path -from [get_ports {qsfp_modprsl qsfp_intl}]
set_input_delay 0 [get_ports {qsfp_modprsl qsfp_intl}]

set_false_path -to [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
set_output_delay 0 [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
set_false_path -from [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
set_input_delay 0 [get_ports {qsfp_i2c_sda[*] qsfp_i2c_scl[*]}]
