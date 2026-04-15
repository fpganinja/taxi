# SPDX-License-Identifier: MIT
#
# Copyright (c) 2021-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-9200 board
# part: xcvu9p-flgb2104-2-e
# part: xcvu13p-fhgb2104-2-e

# FireFly
set_property -dict {LOC BF5 } [get_ports {ff_tx_p[0]}]  ;# MGTYTXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BF4 } [get_ports {ff_tx_n[0]}]  ;# MGTYTXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BC2 } [get_ports {ff_rx_p[0]}]  ;# MGTYRXP0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BC1 } [get_ports {ff_rx_n[0]}]  ;# MGTYRXN0_226 GTYE4_CHANNEL_X1Y28 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BD5 } [get_ports {ff_tx_p[2]}]  ;# MGTYTXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BD4 } [get_ports {ff_tx_n[2]}]  ;# MGTYTXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BA2 } [get_ports {ff_rx_p[2]}]  ;# MGTYRXP1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BA1 } [get_ports {ff_rx_n[2]}]  ;# MGTYRXN1_226 GTYE4_CHANNEL_X1Y29 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BB5 } [get_ports {ff_tx_p[1]}]  ;# MGTYTXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC BB4 } [get_ports {ff_tx_n[1]}]  ;# MGTYTXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AW4 } [get_ports {ff_rx_p[1]}]  ;# MGTYRXP2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AW3 } [get_ports {ff_rx_n[1]}]  ;# MGTYRXN2_226 GTYE4_CHANNEL_X1Y30 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AV7 } [get_ports {ff_tx_p[3]}]  ;# MGTYTXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AV6 } [get_ports {ff_tx_n[3]}]  ;# MGTYTXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AV2 } [get_ports {ff_rx_p[3]}]  ;# MGTYRXP3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AV1 } [get_ports {ff_rx_n[3]}]  ;# MGTYRXN3_226 GTYE4_CHANNEL_X1Y31 / GTYE4_COMMON_X1Y7
set_property -dict {LOC AU9 } [get_ports {ff_tx_p[5]}]  ;# MGTYTXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU8 } [get_ports {ff_tx_n[5]}]  ;# MGTYTXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU4 } [get_ports {ff_rx_p[5]}]  ;# MGTYRXP0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AU3 } [get_ports {ff_rx_n[5]}]  ;# MGTYRXN0_225 GTYE4_CHANNEL_X1Y24 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT7 } [get_ports {ff_tx_p[7]}]  ;# MGTYTXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT6 } [get_ports {ff_tx_n[7]}]  ;# MGTYTXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT2 } [get_ports {ff_rx_p[7]}]  ;# MGTYRXP1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AT1 } [get_ports {ff_rx_n[7]}]  ;# MGTYRXN1_225 GTYE4_CHANNEL_X1Y25 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR9 } [get_ports {ff_tx_p[4]}]  ;# MGTYTXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR8 } [get_ports {ff_tx_n[4]}]  ;# MGTYTXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR4 } [get_ports {ff_rx_p[4]}]  ;# MGTYRXP2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AR3 } [get_ports {ff_rx_n[4]}]  ;# MGTYRXN2_225 GTYE4_CHANNEL_X1Y26 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP7 } [get_ports {ff_tx_p[6]}]  ;# MGTYTXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP6 } [get_ports {ff_tx_n[6]}]  ;# MGTYTXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP2 } [get_ports {ff_rx_p[6]}]  ;# MGTYRXP3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AP1 } [get_ports {ff_rx_n[6]}]  ;# MGTYRXN3_225 GTYE4_CHANNEL_X1Y27 / GTYE4_COMMON_X1Y6
set_property -dict {LOC AN9 } [get_ports {ff_tx_p[11]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AN8 } [get_ports {ff_tx_n[11]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AN4 } [get_ports {ff_rx_p[11]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AN3 } [get_ports {ff_rx_n[11]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X1Y20 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AM7 } [get_ports {ff_tx_p[9]}]  ;# MGTYTXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AM6 } [get_ports {ff_tx_n[9]}]  ;# MGTYTXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AM2 } [get_ports {ff_rx_p[9]}]  ;# MGTYRXP1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AM1 } [get_ports {ff_rx_n[9]}]  ;# MGTYRXN1_224 GTYE4_CHANNEL_X1Y21 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AL9 } [get_ports {ff_tx_p[10]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AL8 } [get_ports {ff_tx_n[10]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AL4 } [get_ports {ff_rx_p[10]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AL3 } [get_ports {ff_rx_n[10]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X1Y22 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AK7 } [get_ports {ff_tx_p[8]}]  ;# MGTYTXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AK6 } [get_ports {ff_tx_n[8]}]  ;# MGTYTXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AK2 } [get_ports {ff_rx_p[8]}]  ;# MGTYRXP3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AK1 } [get_ports {ff_rx_n[8]}]  ;# MGTYRXN3_224 GTYE4_CHANNEL_X1Y23 / GTYE4_COMMON_X1Y5
set_property -dict {LOC AP11} [get_ports ff_mgt_refclk_p] ;# MGTREFCLK1P_225 from U48.31 OUT2_P
set_property -dict {LOC AP10} [get_ports ff_mgt_refclk_n] ;# MGTREFCLK1N_225 from U48.30 OUT2_N
set_property -dict {LOC M22  IOSTANDARD LVCMOS18} [get_ports ff_tx_int_l]
set_property -dict {LOC P21  IOSTANDARD LVCMOS18} [get_ports ff_tx_gpio]
set_property -dict {LOC N23  IOSTANDARD LVCMOS18} [get_ports ff_tx_prsnt_l]
set_property -dict {LOC N22  IOSTANDARD LVCMOS18} [get_ports ff_rx_int_l]
set_property -dict {LOC R21  IOSTANDARD LVCMOS18} [get_ports ff_rx_gpio]
set_property -dict {LOC P23  IOSTANDARD LVCMOS18} [get_ports ff_rx_prsnt_l]

# 100 MHz MGT reference clock
#create_clock -period 10.000 -name ff_mgt_refclk [get_ports ff_mgt_refclk_p]

# 156.25 MHz MGT reference clock
#create_clock -period 6.400 -name ff_mgt_refclk [get_ports ff_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name ff_mgt_refclk [get_ports ff_mgt_refclk_p]
