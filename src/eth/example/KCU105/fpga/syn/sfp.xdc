# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# SFP+ interface
set_property -dict {LOC T2  } [get_ports {sfp_rx_p[0]}] ;# MGTYRXP2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC T1  } [get_ports {sfp_rx_n[0]}] ;# MGTYRXN2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC U4  } [get_ports {sfp_tx_p[0]}] ;# MGTYTXP2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC U3  } [get_ports {sfp_tx_n[0]}] ;# MGTYTXN2_226 GTYE3_CHANNEL_X0Y10 / GTYE3_COMMON_X0Y2
set_property -dict {LOC V2  } [get_ports {sfp_rx_p[1]}] ;# MGTYRXP1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC V1  } [get_ports {sfp_rx_n[1]}] ;# MGTYRXN1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC W4  } [get_ports {sfp_tx_p[1]}] ;# MGTYTXP1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC W3  } [get_ports {sfp_tx_n[1]}] ;# MGTYTXN1_226 GTYE3_CHANNEL_X0Y9 / GTYE3_COMMON_X0Y2
set_property -dict {LOC P6  } [get_ports sfp_mgt_refclk_0_p] ;# MGTREFCLK0P_227 from U32 Si570 via U104 Si53340
set_property -dict {LOC P5  } [get_ports sfp_mgt_refclk_0_n] ;# MGTREFCLK0N_227 from U32 Si570 via U104 Si53340
#set_property -dict {LOC M6  } [get_ports sfp_mgt_refclk_1_p] ;# MGTREFCLK1P_227 from U57 Si5328B
#set_property -dict {LOC M5  } [get_ports sfp_mgt_refclk_1_n] ;# MGTREFCLK1N_227 from U57 Si5328B
#set_property -dict {LOC AG11 IOSTANDARD LVDS} [get_ports sfp_recclk_p] ;# to U57 CKIN1 SI5328
#set_property -dict {LOC AH11 IOSTANDARD LVDS} [get_ports sfp_recclk_n] ;# to U57 CKIN1 SI5328

set_property -dict {LOC AL8  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {sfp_tx_disable_b[0]}]
set_property -dict {LOC K21  IOSTANDARD LVCMOS18} [get_ports {sfp_rx_los[0]}]
set_property -dict {LOC D28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {sfp_tx_disable_b[1]}]
set_property -dict {LOC AM9  IOSTANDARD LVCMOS18} [get_ports {sfp_rx_los[1]}]

# 156.25 MHz MGT reference clock
create_clock -period 6.400 -name sfp_mgt_refclk_0 [get_ports sfp_mgt_refclk_0_p]
#create_clock -period 6.400 -name sfp_mgt_refclk_1 [get_ports sfp_mgt_refclk_1_p]

set_false_path -to [get_ports {sfp_tx_disable_b[*]}]
set_output_delay 0 [get_ports {sfp_tx_disable_b[*]}]
