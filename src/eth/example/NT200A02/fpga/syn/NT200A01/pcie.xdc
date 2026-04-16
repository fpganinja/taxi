# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A01 board
# part: xcvu095-ffva2104-2-e

# PCIe Interface
set_property -dict {LOC U4  } [get_ports {pcie_rx_p[0]}]  ;# MGTHRXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
set_property -dict {LOC U3  } [get_ports {pcie_rx_n[0]}]  ;# MGTHRXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
set_property -dict {LOC M7  } [get_ports {pcie_tx_p[0]}]  ;# MGTHTXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
set_property -dict {LOC M6  } [get_ports {pcie_tx_n[0]}]  ;# MGTHTXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
set_property -dict {LOC V2  } [get_ports {pcie_rx_p[1]}]  ;# MGTHRXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
set_property -dict {LOC V1  } [get_ports {pcie_rx_n[1]}]  ;# MGTHRXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
set_property -dict {LOC P7  } [get_ports {pcie_tx_p[1]}]  ;# MGTHTXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
set_property -dict {LOC P6  } [get_ports {pcie_tx_n[1]}]  ;# MGTHTXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
set_property -dict {LOC W4  } [get_ports {pcie_rx_p[2]}]  ;# MGTHRXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
set_property -dict {LOC W3  } [get_ports {pcie_rx_n[2]}]  ;# MGTHRXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
set_property -dict {LOC T7  } [get_ports {pcie_tx_p[2]}]  ;# MGTHTXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
set_property -dict {LOC T6  } [get_ports {pcie_tx_n[2]}]  ;# MGTHTXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
set_property -dict {LOC Y2  } [get_ports {pcie_rx_p[3]}]  ;# MGTHRXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
set_property -dict {LOC Y1  } [get_ports {pcie_rx_n[3]}]  ;# MGTHRXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
set_property -dict {LOC V7  } [get_ports {pcie_tx_p[3]}]  ;# MGTHTXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
set_property -dict {LOC V6  } [get_ports {pcie_tx_n[3]}]  ;# MGTHTXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
set_property -dict {LOC AA4 } [get_ports {pcie_rx_p[4]}]  ;# MGTHRXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AA3 } [get_ports {pcie_rx_n[4]}]  ;# MGTHRXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
set_property -dict {LOC Y7  } [get_ports {pcie_tx_p[4]}]  ;# MGTHTXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
set_property -dict {LOC Y6  } [get_ports {pcie_tx_n[4]}]  ;# MGTHTXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[5]}]  ;# MGTHRXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[5]}]  ;# MGTHRXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AB7 } [get_ports {pcie_tx_p[5]}]  ;# MGTHTXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AB6 } [get_ports {pcie_tx_n[5]}]  ;# MGTHTXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AC4 } [get_ports {pcie_rx_p[6]}]  ;# MGTHRXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AC3 } [get_ports {pcie_rx_n[6]}]  ;# MGTHRXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AD7 } [get_ports {pcie_tx_p[6]}]  ;# MGTHTXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AD6 } [get_ports {pcie_tx_n[6]}]  ;# MGTHTXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[7]}]  ;# MGTHRXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[7]}]  ;# MGTHRXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[7]}]  ;# MGTHTXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[7]}]  ;# MGTHTXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[8]}]  ;# MGTHRXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[8]}]  ;# MGTHRXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP7 } [get_ports {pcie_tx_p[8]}]  ;# MGTHTXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP6 } [get_ports {pcie_tx_n[8]}]  ;# MGTHTXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AK2 } [get_ports {pcie_rx_p[9]}]  ;# MGTHRXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AK1 } [get_ports {pcie_rx_n[9]}]  ;# MGTHRXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AR5 } [get_ports {pcie_tx_p[9]}]  ;# MGTHTXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AR4 } [get_ports {pcie_tx_n[9]}]  ;# MGTHTXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AM2 } [get_ports {pcie_rx_p[10]}] ;# MGTHRXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AM1 } [get_ports {pcie_rx_n[10]}] ;# MGTHRXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AT7 } [get_ports {pcie_tx_p[10]}] ;# MGTHTXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AT6 } [get_ports {pcie_tx_n[10]}] ;# MGTHTXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP2 } [get_ports {pcie_rx_p[11]}] ;# MGTHRXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP1 } [get_ports {pcie_rx_n[11]}] ;# MGTHRXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AU5 } [get_ports {pcie_tx_p[11]}] ;# MGTHTXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AU4 } [get_ports {pcie_tx_n[11]}] ;# MGTHTXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AT2 } [get_ports {pcie_rx_p[12]}] ;# MGTHRXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AT1 } [get_ports {pcie_rx_n[12]}] ;# MGTHRXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AW5 } [get_ports {pcie_tx_p[12]}] ;# MGTHTXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AW4 } [get_ports {pcie_tx_n[12]}] ;# MGTHTXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AV2 } [get_ports {pcie_rx_p[13]}] ;# MGTHRXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AV1 } [get_ports {pcie_rx_n[13]}] ;# MGTHRXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BA5 } [get_ports {pcie_tx_p[13]}] ;# MGTHTXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BA4 } [get_ports {pcie_tx_n[13]}] ;# MGTHTXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AY2 } [get_ports {pcie_rx_p[14]}] ;# MGTHRXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AY1 } [get_ports {pcie_rx_n[14]}] ;# MGTHRXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BC5 } [get_ports {pcie_tx_p[14]}] ;# MGTHTXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BC4 } [get_ports {pcie_tx_n[14]}] ;# MGTHTXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BB2 } [get_ports {pcie_rx_p[15]}] ;# MGTHRXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BB1 } [get_ports {pcie_rx_n[15]}] ;# MGTHRXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BE5 } [get_ports {pcie_tx_p[15]}] ;# MGTHTXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BE4 } [get_ports {pcie_tx_n[15]}] ;# MGTHTXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AR9 } [get_ports pcie_refclk_0_p] ;# MGTREFCLK0P_224
#set_property -dict {LOC AR8 } [get_ports pcie_refclk_0_n] ;# MGTREFCLK0N_224
set_property -dict {LOC AC9 } [get_ports pcie_refclk_1_p] ;# MGTREFCLK0P_227
set_property -dict {LOC AC8 } [get_ports pcie_refclk_1_n] ;# MGTREFCLK0N_227
set_property -dict {LOC AM17 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset]

# 100 MHz MGT reference clock
#create_clock -period 10.000 -name pcie_mgt_refclk_0 [get_ports pcie_refclk_0_p]
create_clock -period 10.000 -name pcie_mgt_refclk_1 [get_ports pcie_refclk_1_p]

set_false_path -from [get_ports {pcie_reset}]
set_input_delay 0 [get_ports {pcie_reset}]
