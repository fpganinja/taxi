# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# QSFP28 Interfaces
set_property -dict {LOC Y2  } [get_ports {qsfp1_rx_p[0]}] ;# MGTYRXP0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12
set_property -dict {LOC Y1  } [get_ports {qsfp1_rx_n[0]}] ;# MGTYRXN0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12
set_property -dict {LOC V7  } [get_ports {qsfp1_tx_p[0]}] ;# MGTYTXP0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12
set_property -dict {LOC V6  } [get_ports {qsfp1_tx_n[0]}] ;# MGTYTXN0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12
set_property -dict {LOC W4  } [get_ports {qsfp1_rx_p[1]}] ;# MGTYRXP1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12
set_property -dict {LOC W3  } [get_ports {qsfp1_rx_n[1]}] ;# MGTYRXN1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12
set_property -dict {LOC T7  } [get_ports {qsfp1_tx_p[1]}] ;# MGTYTXP1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12
set_property -dict {LOC T6  } [get_ports {qsfp1_tx_n[1]}] ;# MGTYTXN1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12
set_property -dict {LOC V2  } [get_ports {qsfp1_rx_p[2]}] ;# MGTYRXP2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12
set_property -dict {LOC V1  } [get_ports {qsfp1_rx_n[2]}] ;# MGTYRXN2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12
set_property -dict {LOC P7  } [get_ports {qsfp1_tx_p[2]}] ;# MGTYTXP2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12
set_property -dict {LOC P6  } [get_ports {qsfp1_tx_n[2]}] ;# MGTYTXN2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12
set_property -dict {LOC U4  } [get_ports {qsfp1_rx_p[3]}] ;# MGTYRXP3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12
set_property -dict {LOC U3  } [get_ports {qsfp1_rx_n[3]}] ;# MGTYRXN3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12
set_property -dict {LOC M7  } [get_ports {qsfp1_tx_p[3]}] ;# MGTYTXP3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12
set_property -dict {LOC M6  } [get_ports {qsfp1_tx_n[3]}] ;# MGTYTXN3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12
set_property -dict {LOC W9  } [get_ports {qsfp1_mgt_refclk_0_p}] ;# MGTREFCLK0P_231 from U38.4
set_property -dict {LOC W8  } [get_ports {qsfp1_mgt_refclk_0_n}] ;# MGTREFCLK0N_231 from U38.5
#set_property -dict {LOC U9  } [get_ports {qsfp1_mgt_refclk_1_p}] ;# MGTREFCLK1P_231 from U57.28
#set_property -dict {LOC U8  } [get_ports {qsfp1_mgt_refclk_1_n}] ;# MGTREFCLK1N_231 from U57.29
#set_property -dict {LOC AM23 IOSTANDARD LVDS} [get_ports {qsfp1_recclk_p}] ;# to U57.16
#set_property -dict {LOC AM22 IOSTANDARD LVDS} [get_ports {qsfp1_recclk_n}] ;# to U57.17
set_property -dict {LOC AM21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {qsfp1_modsell}]
set_property -dict {LOC BA22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {qsfp1_resetl}]
set_property -dict {LOC AL21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {qsfp1_modprsl}]
set_property -dict {LOC AP21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {qsfp1_intl}]
set_property -dict {LOC AN21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {qsfp1_lpmode}]

# 156.25 MHz MGT reference clock
create_clock -period 6.400 -name qsfp1_mgt_refclk_0 [get_ports {qsfp1_mgt_refclk_0_p}]

set_false_path -to [get_ports {qsfp1_modsell qsfp1_resetl qsfp1_lpmode}]
set_output_delay 0 [get_ports {qsfp1_modsell qsfp1_resetl qsfp1_lpmode}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

set_property -dict {LOC T2  } [get_ports {qsfp2_rx_p[0]}] ;# MGTYRXP0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13
set_property -dict {LOC T1  } [get_ports {qsfp2_rx_n[0]}] ;# MGTYRXN0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13
set_property -dict {LOC L5  } [get_ports {qsfp2_tx_p[0]}] ;# MGTYTXP0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13
set_property -dict {LOC L4  } [get_ports {qsfp2_tx_n[0]}] ;# MGTYTXN0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13
set_property -dict {LOC R4  } [get_ports {qsfp2_rx_p[1]}] ;# MGTYRXP1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13
set_property -dict {LOC R3  } [get_ports {qsfp2_rx_n[1]}] ;# MGTYRXN1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13
set_property -dict {LOC K7  } [get_ports {qsfp2_tx_p[1]}] ;# MGTYTXP1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13
set_property -dict {LOC K6  } [get_ports {qsfp2_tx_n[1]}] ;# MGTYTXN1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13
set_property -dict {LOC P2  } [get_ports {qsfp2_rx_p[2]}] ;# MGTYRXP2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13
set_property -dict {LOC P1  } [get_ports {qsfp2_rx_n[2]}] ;# MGTYRXN2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13
set_property -dict {LOC J5  } [get_ports {qsfp2_tx_p[2]}] ;# MGTYTXP2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13
set_property -dict {LOC J4  } [get_ports {qsfp2_tx_n[2]}] ;# MGTYTXN2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13
set_property -dict {LOC M2  } [get_ports {qsfp2_rx_p[3]}] ;# MGTYRXP3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13
set_property -dict {LOC M1  } [get_ports {qsfp2_rx_n[3]}] ;# MGTYRXN3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13
set_property -dict {LOC H7  } [get_ports {qsfp2_tx_p[3]}] ;# MGTYTXP3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13
set_property -dict {LOC H6  } [get_ports {qsfp2_tx_n[3]}] ;# MGTYTXN3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13
#set_property -dict {LOC R9  } [get_ports {qsfp2_mgt_refclk_0_p}] ;# MGTREFCLK0P_232 from U32.4 via U104.13
#set_property -dict {LOC R8  } [get_ports {qsfp2_mgt_refclk_0_n}] ;# MGTREFCLK0N_232 from U32.5 via U104.14
#set_property -dict {LOC N9  } [get_ports {qsfp2_mgt_refclk_1_p}] ;# MGTREFCLK1P_232 from U57.35
#set_property -dict {LOC N8  } [get_ports {qsfp2_mgt_refclk_1_n}] ;# MGTREFCLK1N_232 from U57.34
#set_property -dict {LOC AP23 IOSTANDARD LVDS} [get_ports {qsfp2_recclk_p}] ;# to U57.12
#set_property -dict {LOC AP22 IOSTANDARD LVDS} [get_ports {qsfp2_recclk_n}] ;# to U57.13
set_property -dict {LOC AN23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {qsfp2_modsell}]
set_property -dict {LOC AY22 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {qsfp2_resetl}]
set_property -dict {LOC AN24 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {qsfp2_modprsl}]
set_property -dict {LOC AT21 IOSTANDARD LVCMOS18 PULLUP true} [get_ports {qsfp2_intl}]
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {qsfp2_lpmode}]

# 156.25 MHz MGT reference clock
#create_clock -period 6.400 -name qsfp2_mgt_refclk_0 [get_ports {qsfp2_mgt_refclk_0_p}]

set_false_path -to [get_ports {qsfp2_modsell qsfp2_resetl qsfp2_lpmode}]
set_output_delay 0 [get_ports {qsfp2_modsell qsfp2_resetl qsfp2_lpmode}]
set_false_path -from [get_ports {qsfp2_modprsl qsfp2_intl}]
set_input_delay 0 [get_ports {qsfp2_modprsl qsfp2_intl}]
