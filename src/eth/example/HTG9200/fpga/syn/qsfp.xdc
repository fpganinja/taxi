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

# QSFP 1
set_property -dict {LOC G40 } [get_ports {qsfp_1_tx_p[1]}] ;# MGTYTXP0_133 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9
set_property -dict {LOC G41 } [get_ports {qsfp_1_tx_n[1]}] ;# MGTYTXN0_133 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9
set_property -dict {LOC J45 } [get_ports {qsfp_1_rx_p[1]}] ;# MGTYRXP0_133 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9
set_property -dict {LOC J46 } [get_ports {qsfp_1_rx_n[1]}] ;# MGTYRXN0_133 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9
set_property -dict {LOC E42 } [get_ports {qsfp_1_tx_p[2]}] ;# MGTYTXP1_133 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9
set_property -dict {LOC E43 } [get_ports {qsfp_1_tx_n[2]}] ;# MGTYTXN1_133 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9
set_property -dict {LOC H43 } [get_ports {qsfp_1_rx_p[2]}] ;# MGTYRXP1_133 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9
set_property -dict {LOC H44 } [get_ports {qsfp_1_rx_n[2]}] ;# MGTYRXN1_133 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9
set_property -dict {LOC C42 } [get_ports {qsfp_1_tx_p[0]}] ;# MGTYTXP2_133 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9
set_property -dict {LOC C43 } [get_ports {qsfp_1_tx_n[0]}] ;# MGTYTXN2_133 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9
set_property -dict {LOC F45 } [get_ports {qsfp_1_rx_p[0]}] ;# MGTYRXP2_133 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9
set_property -dict {LOC F46 } [get_ports {qsfp_1_rx_n[0]}] ;# MGTYRXN2_133 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9
set_property -dict {LOC A42 } [get_ports {qsfp_1_tx_p[3]}] ;# MGTYTXP3_133 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9
set_property -dict {LOC A43 } [get_ports {qsfp_1_tx_n[3]}] ;# MGTYTXN3_133 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9
set_property -dict {LOC D45 } [get_ports {qsfp_1_rx_p[3]}] ;# MGTYRXP3_133 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9
set_property -dict {LOC D46 } [get_ports {qsfp_1_rx_n[3]}] ;# MGTYRXN3_133 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9
set_property -dict {LOC K38 } [get_ports qsfp_1_mgt_refclk_p] ;# MGTREFCLK1P_133 from U48.28 OUT1_P
set_property -dict {LOC K39 } [get_ports qsfp_1_mgt_refclk_n] ;# MGTREFCLK1N_133 from U48.27 OUT1_N
set_property -dict {LOC BB20 IOSTANDARD LVCMOS18} [get_ports qsfp_1_resetl]
set_property -dict {LOC BE21 IOSTANDARD LVCMOS18} [get_ports qsfp_1_modprsl]
set_property -dict {LOC BA20 IOSTANDARD LVCMOS18} [get_ports qsfp_1_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_1_mgt_refclk [get_ports qsfp_1_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_1_mgt_refclk [get_ports qsfp_1_mgt_refclk_p]

# QSFP 2
set_property -dict {LOC N40 } [get_ports {qsfp_2_tx_p[1]}] ;# MGTYTXP0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N41 } [get_ports {qsfp_2_tx_n[1]}] ;# MGTYTXN0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N45 } [get_ports {qsfp_2_rx_p[1]}] ;# MGTYRXP0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC N46 } [get_ports {qsfp_2_rx_n[1]}] ;# MGTYRXN0_132 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M38 } [get_ports {qsfp_2_tx_p[2]}] ;# MGTYTXP1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M39 } [get_ports {qsfp_2_tx_n[2]}] ;# MGTYTXN1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M43 } [get_ports {qsfp_2_rx_p[2]}] ;# MGTYRXP1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC M44 } [get_ports {qsfp_2_rx_n[2]}] ;# MGTYRXN1_132 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L40 } [get_ports {qsfp_2_tx_p[0]}] ;# MGTYTXP2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L41 } [get_ports {qsfp_2_tx_n[0]}] ;# MGTYTXN2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L45 } [get_ports {qsfp_2_rx_p[0]}] ;# MGTYRXP2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC L46 } [get_ports {qsfp_2_rx_n[0]}] ;# MGTYRXN2_132 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J40 } [get_ports {qsfp_2_tx_p[3]}] ;# MGTYTXP3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC J41 } [get_ports {qsfp_2_tx_n[3]}] ;# MGTYTXN3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K43 } [get_ports {qsfp_2_rx_p[3]}] ;# MGTYRXP3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC K44 } [get_ports {qsfp_2_rx_n[3]}] ;# MGTYRXN3_132 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8
set_property -dict {LOC R36 } [get_ports qsfp_2_mgt_refclk_p] ;# MGTREFCLK0P_132 from U48.35 OUT3_P
set_property -dict {LOC R37 } [get_ports qsfp_2_mgt_refclk_n] ;# MGTREFCLK0N_132 from U48.34 OUT3_N
set_property -dict {LOC BE22 IOSTANDARD LVCMOS18} [get_ports qsfp_2_resetl]
set_property -dict {LOC BD21 IOSTANDARD LVCMOS18} [get_ports qsfp_2_modprsl]
set_property -dict {LOC BF22 IOSTANDARD LVCMOS18} [get_ports qsfp_2_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_2_mgt_refclk [get_ports qsfp_2_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_2_mgt_refclk [get_ports qsfp_2_mgt_refclk_p]

# QSFP 3
set_property -dict {LOC U40 } [get_ports {qsfp_3_tx_p[1]}] ;# MGTYTXP0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC U41 } [get_ports {qsfp_3_tx_n[1]}] ;# MGTYTXN0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC U45 } [get_ports {qsfp_3_rx_p[1]}] ;# MGTYRXP0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC U46 } [get_ports {qsfp_3_rx_n[1]}] ;# MGTYRXN0_131 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7
set_property -dict {LOC T38 } [get_ports {qsfp_3_tx_p[2]}] ;# MGTYTXP1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC T39 } [get_ports {qsfp_3_tx_n[2]}] ;# MGTYTXN1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC T43 } [get_ports {qsfp_3_rx_p[2]}] ;# MGTYRXP1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC T44 } [get_ports {qsfp_3_rx_n[2]}] ;# MGTYRXN1_131 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7
set_property -dict {LOC R40 } [get_ports {qsfp_3_tx_p[0]}] ;# MGTYTXP2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC R41 } [get_ports {qsfp_3_tx_n[0]}] ;# MGTYTXN2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC R45 } [get_ports {qsfp_3_rx_p[0]}] ;# MGTYRXP2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC R46 } [get_ports {qsfp_3_rx_n[0]}] ;# MGTYRXN2_131 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7
set_property -dict {LOC P38 } [get_ports {qsfp_3_tx_p[3]}] ;# MGTYTXP3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC P39 } [get_ports {qsfp_3_tx_n[3]}] ;# MGTYTXN3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC P43 } [get_ports {qsfp_3_rx_p[3]}] ;# MGTYRXP3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC P44 } [get_ports {qsfp_3_rx_n[3]}] ;# MGTYRXN3_131 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7
set_property -dict {LOC W36 } [get_ports qsfp_3_mgt_refclk_p] ;# MGTREFCLK0P_131 from U48.38 OUT4_P
set_property -dict {LOC W37 } [get_ports qsfp_3_mgt_refclk_n] ;# MGTREFCLK0N_131 from U48.37 OUT4_N
set_property -dict {LOC AY23 IOSTANDARD LVCMOS18} [get_ports qsfp_3_resetl]
set_property -dict {LOC AY22 IOSTANDARD LVCMOS18} [get_ports qsfp_3_modprsl]
set_property -dict {LOC BA22 IOSTANDARD LVCMOS18} [get_ports qsfp_3_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_3_mgt_refclk [get_ports qsfp_3_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_3_mgt_refclk [get_ports qsfp_3_mgt_refclk_p]

# QSFP 4
set_property -dict {LOC AA40} [get_ports {qsfp_4_tx_p[1]}] ;# MGTYTXP0_130 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA41} [get_ports {qsfp_4_tx_n[1]}] ;# MGTYTXN0_130 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA45} [get_ports {qsfp_4_rx_p[1]}] ;# MGTYRXP0_130 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AA46} [get_ports {qsfp_4_rx_n[1]}] ;# MGTYRXN0_130 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y38 } [get_ports {qsfp_4_tx_p[2]}] ;# MGTYTXP1_130 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y39 } [get_ports {qsfp_4_tx_n[2]}] ;# MGTYTXN1_130 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y43 } [get_ports {qsfp_4_rx_p[2]}] ;# MGTYRXP1_130 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC Y44 } [get_ports {qsfp_4_rx_n[2]}] ;# MGTYRXN1_130 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W40 } [get_ports {qsfp_4_tx_p[0]}] ;# MGTYTXP2_130 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W41 } [get_ports {qsfp_4_tx_n[0]}] ;# MGTYTXN2_130 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W45 } [get_ports {qsfp_4_rx_p[0]}] ;# MGTYRXP2_130 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC W46 } [get_ports {qsfp_4_rx_n[0]}] ;# MGTYRXN2_130 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V38 } [get_ports {qsfp_4_tx_p[3]}] ;# MGTYTXP3_130 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V39 } [get_ports {qsfp_4_tx_n[3]}] ;# MGTYTXN3_130 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V43 } [get_ports {qsfp_4_rx_p[3]}] ;# MGTYRXP3_130 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC V44 } [get_ports {qsfp_4_rx_n[3]}] ;# MGTYRXN3_130 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6
set_property -dict {LOC AC36} [get_ports qsfp_4_mgt_refclk_p] ;# MGTREFCLK0P_130 from U48.42 OUT5_P
set_property -dict {LOC AC37} [get_ports qsfp_4_mgt_refclk_n] ;# MGTREFCLK0N_130 from U48.41 OUT5_N
set_property -dict {LOC BC22 IOSTANDARD LVCMOS18} [get_ports qsfp_4_resetl]
set_property -dict {LOC BB22 IOSTANDARD LVCMOS18} [get_ports qsfp_4_modprsl]
set_property -dict {LOC BA23 IOSTANDARD LVCMOS18} [get_ports qsfp_4_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_4_mgt_refclk [get_ports qsfp_4_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_4_mgt_refclk [get_ports qsfp_4_mgt_refclk_p]

# QSFP 5
set_property -dict {LOC AE40} [get_ports {qsfp_5_tx_p[1]}] ;# MGTYTXP0_129 GTYE4_CHANNEL_X0Y20 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AE41} [get_ports {qsfp_5_tx_n[1]}] ;# MGTYTXN0_129 GTYE4_CHANNEL_X0Y20 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AE45} [get_ports {qsfp_5_rx_p[1]}] ;# MGTYRXP0_129 GTYE4_CHANNEL_X0Y20 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AE46} [get_ports {qsfp_5_rx_n[1]}] ;# MGTYRXN0_129 GTYE4_CHANNEL_X0Y20 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AD38} [get_ports {qsfp_5_tx_p[2]}] ;# MGTYTXP1_129 GTYE4_CHANNEL_X0Y21 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AD39} [get_ports {qsfp_5_tx_n[2]}] ;# MGTYTXN1_129 GTYE4_CHANNEL_X0Y21 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AD43} [get_ports {qsfp_5_rx_p[2]}] ;# MGTYRXP1_129 GTYE4_CHANNEL_X0Y21 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AD44} [get_ports {qsfp_5_rx_n[2]}] ;# MGTYRXN1_129 GTYE4_CHANNEL_X0Y21 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AC40} [get_ports {qsfp_5_tx_p[3]}] ;# MGTYTXP2_129 GTYE4_CHANNEL_X0Y22 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AC41} [get_ports {qsfp_5_tx_n[3]}] ;# MGTYTXN2_129 GTYE4_CHANNEL_X0Y22 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AC45} [get_ports {qsfp_5_rx_p[3]}] ;# MGTYRXP2_129 GTYE4_CHANNEL_X0Y22 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AC46} [get_ports {qsfp_5_rx_n[3]}] ;# MGTYRXN2_129 GTYE4_CHANNEL_X0Y22 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AB38} [get_ports {qsfp_5_tx_p[0]}] ;# MGTYTXP3_129 GTYE4_CHANNEL_X0Y23 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AB39} [get_ports {qsfp_5_tx_n[0]}] ;# MGTYTXN3_129 GTYE4_CHANNEL_X0Y23 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AB43} [get_ports {qsfp_5_rx_p[0]}] ;# MGTYRXP3_129 GTYE4_CHANNEL_X0Y23 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AB44} [get_ports {qsfp_5_rx_n[0]}] ;# MGTYRXN3_129 GTYE4_CHANNEL_X0Y23 / GTYE4_COMMON_X0Y5
set_property -dict {LOC AG36} [get_ports qsfp_5_mgt_refclk_p] ;# MGTREFCLK0P_129 from U48.24 OUT0_P
set_property -dict {LOC AG37} [get_ports qsfp_5_mgt_refclk_n] ;# MGTREFCLK0N_129 from U48.23 OUT0_N
set_property -dict {LOC BD23 IOSTANDARD LVCMOS18} [get_ports qsfp_5_resetl]
set_property -dict {LOC BE23 IOSTANDARD LVCMOS18} [get_ports qsfp_5_modprsl]
set_property -dict {LOC BF23 IOSTANDARD LVCMOS18} [get_ports qsfp_5_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_5_mgt_refclk [get_ports qsfp_5_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_5_mgt_refclk [get_ports qsfp_5_mgt_refclk_p]

# QSFP 6
set_property -dict {LOC AJ40} [get_ports {qsfp_6_tx_p[1]}] ;# MGTYTXP0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ41} [get_ports {qsfp_6_tx_n[1]}] ;# MGTYTXN0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ45} [get_ports {qsfp_6_rx_p[1]}] ;# MGTYRXP0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AJ46} [get_ports {qsfp_6_rx_n[1]}] ;# MGTYRXN0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH38} [get_ports {qsfp_6_tx_p[2]}] ;# MGTYTXP1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH39} [get_ports {qsfp_6_tx_n[2]}] ;# MGTYTXN1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH43} [get_ports {qsfp_6_rx_p[2]}] ;# MGTYRXP1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AH44} [get_ports {qsfp_6_rx_n[2]}] ;# MGTYRXN1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG40} [get_ports {qsfp_6_tx_p[0]}] ;# MGTYTXP2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG41} [get_ports {qsfp_6_tx_n[0]}] ;# MGTYTXN2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG45} [get_ports {qsfp_6_rx_p[0]}] ;# MGTYRXP2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AG46} [get_ports {qsfp_6_rx_n[0]}] ;# MGTYRXN2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF38} [get_ports {qsfp_6_tx_p[3]}] ;# MGTYTXP3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF39} [get_ports {qsfp_6_tx_n[3]}] ;# MGTYTXN3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF43} [get_ports {qsfp_6_rx_p[3]}] ;# MGTYRXP3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AF44} [get_ports {qsfp_6_rx_n[3]}] ;# MGTYRXN3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC AL36} [get_ports qsfp_6_mgt_refclk_p] ;# MGTREFCLK0P_128 from U48.59 OUT9_P
set_property -dict {LOC AL37} [get_ports qsfp_6_mgt_refclk_n] ;# MGTREFCLK0N_128 from U48.58 OUT9_N
set_property -dict {LOC AW24 IOSTANDARD LVCMOS18} [get_ports qsfp_6_resetl]
set_property -dict {LOC AR23 IOSTANDARD LVCMOS18} [get_ports qsfp_6_modprsl]
set_property -dict {LOC AV24 IOSTANDARD LVCMOS18} [get_ports qsfp_6_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_6_mgt_refclk [get_ports qsfp_6_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_6_mgt_refclk [get_ports qsfp_6_mgt_refclk_p]

# QSFP 7
set_property -dict {LOC AN40} [get_ports {qsfp_7_tx_p[1]}] ;# MGTYTXP0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN41} [get_ports {qsfp_7_tx_n[1]}] ;# MGTYTXN0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN45} [get_ports {qsfp_7_rx_p[1]}] ;# MGTYRXP0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AN46} [get_ports {qsfp_7_rx_n[1]}] ;# MGTYRXN0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM38} [get_ports {qsfp_7_tx_p[2]}] ;# MGTYTXP1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM39} [get_ports {qsfp_7_tx_n[2]}] ;# MGTYTXN1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM43} [get_ports {qsfp_7_rx_p[2]}] ;# MGTYRXP1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AM44} [get_ports {qsfp_7_rx_n[2]}] ;# MGTYRXN1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL40} [get_ports {qsfp_7_tx_p[0]}] ;# MGTYTXP2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL41} [get_ports {qsfp_7_tx_n[0]}] ;# MGTYTXN2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL45} [get_ports {qsfp_7_rx_p[0]}] ;# MGTYRXP2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AL46} [get_ports {qsfp_7_rx_n[0]}] ;# MGTYRXN2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK38} [get_ports {qsfp_7_tx_p[3]}] ;# MGTYTXP3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK39} [get_ports {qsfp_7_tx_n[3]}] ;# MGTYTXN3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK43} [get_ports {qsfp_7_rx_p[3]}] ;# MGTYRXP3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AK44} [get_ports {qsfp_7_rx_n[3]}] ;# MGTYRXN3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC AR36} [get_ports qsfp_7_mgt_refclk_p] ;# MGTREFCLK0P_127 from U48.54 OUT8_P
set_property -dict {LOC AR37} [get_ports qsfp_7_mgt_refclk_n] ;# MGTREFCLK0N_127 from U48.53 OUT8_N
set_property -dict {LOC AU24 IOSTANDARD LVCMOS18} [get_ports qsfp_7_resetl]
set_property -dict {LOC AN23 IOSTANDARD LVCMOS18} [get_ports qsfp_7_modprsl]
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18} [get_ports qsfp_7_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_7_mgt_refclk [get_ports qsfp_7_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_7_mgt_refclk [get_ports qsfp_7_mgt_refclk_p]

# QSFP 8
set_property -dict {LOC AU40} [get_ports {qsfp_8_tx_p[1]}] ;# MGTYTXP0_126 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU41} [get_ports {qsfp_8_tx_n[1]}] ;# MGTYTXN0_126 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU45} [get_ports {qsfp_8_rx_p[1]}] ;# MGTYRXP0_126 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AU46} [get_ports {qsfp_8_rx_n[1]}] ;# MGTYRXN0_126 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT38} [get_ports {qsfp_8_tx_p[2]}] ;# MGTYTXP1_126 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT39} [get_ports {qsfp_8_tx_n[2]}] ;# MGTYTXN1_126 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT43} [get_ports {qsfp_8_rx_p[2]}] ;# MGTYRXP1_126 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AT44} [get_ports {qsfp_8_rx_n[2]}] ;# MGTYRXN1_126 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR40} [get_ports {qsfp_8_tx_p[0]}] ;# MGTYTXP2_126 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR41} [get_ports {qsfp_8_tx_n[0]}] ;# MGTYTXN2_126 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR45} [get_ports {qsfp_8_rx_p[0]}] ;# MGTYRXP2_126 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AR46} [get_ports {qsfp_8_rx_n[0]}] ;# MGTYRXN2_126 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP38} [get_ports {qsfp_8_tx_p[3]}] ;# MGTYTXP3_126 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP39} [get_ports {qsfp_8_tx_n[3]}] ;# MGTYTXN3_126 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP43} [get_ports {qsfp_8_rx_p[3]}] ;# MGTYRXP3_126 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AP44} [get_ports {qsfp_8_rx_n[3]}] ;# MGTYRXN3_126 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2
set_property -dict {LOC AV38} [get_ports qsfp_8_mgt_refclk_p] ;# MGTREFCLK0P_126 from U48.45 OUT6_P
set_property -dict {LOC AV39} [get_ports qsfp_8_mgt_refclk_n] ;# MGTREFCLK0N_126 from U48.44 OUT6_N
set_property -dict {LOC AN24 IOSTANDARD LVCMOS18} [get_ports qsfp_8_resetl]
set_property -dict {LOC AP24 IOSTANDARD LVCMOS18} [get_ports qsfp_8_modprsl]
set_property -dict {LOC AP23 IOSTANDARD LVCMOS18} [get_ports qsfp_8_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_8_mgt_refclk [get_ports qsfp_8_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_8_mgt_refclk [get_ports qsfp_8_mgt_refclk_p]

# QSFP 9
set_property -dict {LOC BF42} [get_ports {qsfp_9_tx_p[1]}] ;# MGTYTXP0_125 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BF43} [get_ports {qsfp_9_tx_n[1]}] ;# MGTYTXN0_125 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BC45} [get_ports {qsfp_9_rx_p[1]}] ;# MGTYRXP0_125 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BC46} [get_ports {qsfp_9_rx_n[1]}] ;# MGTYRXN0_125 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BD42} [get_ports {qsfp_9_tx_p[2]}] ;# MGTYTXP1_125 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BD43} [get_ports {qsfp_9_tx_n[2]}] ;# MGTYTXN1_125 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA45} [get_ports {qsfp_9_rx_p[2]}] ;# MGTYRXP1_125 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA46} [get_ports {qsfp_9_rx_n[2]}] ;# MGTYRXN1_125 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BB42} [get_ports {qsfp_9_tx_p[0]}] ;# MGTYTXP2_125 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BB43} [get_ports {qsfp_9_tx_n[0]}] ;# MGTYTXN2_125 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW45} [get_ports {qsfp_9_rx_p[0]}] ;# MGTYRXP2_125 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW46} [get_ports {qsfp_9_rx_n[0]}] ;# MGTYRXN2_125 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW40} [get_ports {qsfp_9_tx_p[3]}] ;# MGTYTXP3_125 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AW41} [get_ports {qsfp_9_tx_n[3]}] ;# MGTYTXN3_125 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AV43} [get_ports {qsfp_9_rx_p[3]}] ;# MGTYRXP3_125 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AV44} [get_ports {qsfp_9_rx_n[3]}] ;# MGTYRXN3_125 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC BA40} [get_ports qsfp_9_mgt_refclk_p] ;# MGTREFCLK0P_125 from U48.51 OUT7_P
set_property -dict {LOC BA41} [get_ports qsfp_9_mgt_refclk_n] ;# MGTREFCLK0N_125 from U48.50 OUT7_N
set_property -dict {LOC AM24 IOSTANDARD LVCMOS18} [get_ports qsfp_9_resetl]
set_property -dict {LOC AM22 IOSTANDARD LVCMOS18} [get_ports qsfp_9_modprsl]
set_property -dict {LOC AL24 IOSTANDARD LVCMOS18} [get_ports qsfp_9_intl]

# 156.25 MHz MGT reference clock
# create_clock -period 6.400 -name qsfp_9_mgt_refclk [get_ports qsfp_9_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_9_mgt_refclk [get_ports qsfp_9_mgt_refclk_p]
