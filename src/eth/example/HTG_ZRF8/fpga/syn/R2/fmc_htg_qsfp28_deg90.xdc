# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-R2 board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# FMC+ J25

# for HTG-FMC-QSFP28-DEG90
set_property -dict {LOC AJ12 IOSTANDARD LVCMOS18} [get_ports {fmc_qsfp_resetl}] ;# J25.G33 LA31_P
set_property -dict {LOC AK12 IOSTANDARD LVCMOS18} [get_ports {fmc_qsfp_modsell}] ;# J25.G34 LA31_N
set_property -dict {LOC AL7  IOSTANDARD LVCMOS18} [get_ports {fmc_qsfp_lpmode}] ;# J25.H38 LA32_N

#set_property -dict {LOC AP18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[0]}]  ;# J25.G9  LA00_P_CC
#set_property -dict {LOC AR18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[0]}]  ;# J25.G10 LA00_N_CC
#set_property -dict {LOC AM20 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[1]}]  ;# J25.D8  LA01_P_CC
#set_property -dict {LOC AN20 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[1]}]  ;# J25.D9  LA01_N_CC
#set_property -dict {LOC AR22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[2]}]  ;# J25.H7  LA02_P
#set_property -dict {LOC AT22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[2]}]  ;# J25.H8  LA02_N
#set_property -dict {LOC AR21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[3]}]  ;# J25.G12 LA03_P
#set_property -dict {LOC AT21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[3]}]  ;# J25.G13 LA03_N
#set_property -dict {LOC AV21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[4]}]  ;# J25.H10 LA04_P
#set_property -dict {LOC AW21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[4]}]  ;# J25.H11 LA04_N
#set_property -dict {LOC AK22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[5]}]  ;# J25.D11 LA05_P
#set_property -dict {LOC AK21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[5]}]  ;# J25.D12 LA05_N
#set_property -dict {LOC AU18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[6]}]  ;# J25.C10 LA06_P
#set_property -dict {LOC AV18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[6]}]  ;# J25.C11 LA06_N
#set_property -dict {LOC AL21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[7]}]  ;# J25.H13 LA07_P
#set_property -dict {LOC AL20 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[7]}]  ;# J25.H14 LA07_N
#set_property -dict {LOC AL22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[8]}]  ;# J25.G12 LA08_P
#set_property -dict {LOC AM22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[8]}]  ;# J25.G13 LA08_N
#set_property -dict {LOC AR19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[9]}]  ;# J25.D14 LA09_P
#set_property -dict {LOC AT19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[9]}]  ;# J25.D15 LA09_N
#set_property -dict {LOC AU17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[10]}] ;# J25.C14 LA10_P
#set_property -dict {LOC AV17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[10]}] ;# J25.C15 LA10_N
#set_property -dict {LOC AL19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[11]}] ;# J25.H16 LA11_P
#set_property -dict {LOC AM19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[11]}] ;# J25.H17 LA11_N
#set_property -dict {LOC AG20 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[12]}] ;# J25.G15 LA12_P
#set_property -dict {LOC AH20 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[12]}] ;# J25.G16 LA12_N
#set_property -dict {LOC AJ20 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[13]}] ;# J25.D17 LA13_P
#set_property -dict {LOC AJ19 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[13]}] ;# J25.D18 LA13_N
#set_property -dict {LOC AJ18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[14]}] ;# J25.C18 LA14_P
#set_property -dict {LOC AK18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[14]}] ;# J25.C19 LA14_N
#set_property -dict {LOC AR17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[15]}] ;# J25.H19 LA15_P
#set_property -dict {LOC AT17 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[15]}] ;# J25.H20 LA15_N
#set_property -dict {LOC AG18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[16]}] ;# J25.G18 LA16_P
#set_property -dict {LOC AH18 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[16]}] ;# J25.G19 LA16_N
#set_property -dict {LOC AP8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[17]}] ;# J25.D20 LA17_P_CC
#set_property -dict {LOC AR8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[17]}] ;# J25.D21 LA17_N_CC
#set_property -dict {LOC AP9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[18]}] ;# J25.C22 LA18_P_CC
#set_property -dict {LOC AR9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[18]}] ;# J25.C23 LA18_N_CC
#set_property -dict {LOC AU12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[19]}] ;# J25.H22 LA19_P
#set_property -dict {LOC AV12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[19]}] ;# J25.H23 LA19_N
#set_property -dict {LOC AW9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[20]}] ;# J25.G21 LA20_P
#set_property -dict {LOC AW8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[20]}] ;# J25.G22 LA20_N
#set_property -dict {LOC AM13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[21]}] ;# J25.H25 LA21_P
#set_property -dict {LOC AN13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[21]}] ;# J25.H26 LA21_N
#set_property -dict {LOC AT10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[22]}] ;# J25.G24 LA22_P
#set_property -dict {LOC AU10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[22]}] ;# J25.G25 LA22_N
#set_property -dict {LOC AV11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[23]}] ;# J25.D23 LA23_P
#set_property -dict {LOC AW11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[23]}] ;# J25.D24 LA23_N
#set_property -dict {LOC AN8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[24]}] ;# J25.H28 LA24_P
#set_property -dict {LOC AN7  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[24]}] ;# J25.H29 LA24_N
#set_property -dict {LOC AL14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[25]}] ;# J25.G27 LA25_P
#set_property -dict {LOC AM14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[25]}] ;# J25.G28 LA25_N
#set_property -dict {LOC AM12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[26]}] ;# J25.D26 LA26_P
#set_property -dict {LOC AN12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[26]}] ;# J25.D27 LA26_N
#set_property -dict {LOC AR12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[27]}] ;# J25.C26 LA27_P
#set_property -dict {LOC AR11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[27]}] ;# J25.C27 LA27_N
#set_property -dict {LOC AL10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[28]}] ;# J25.H31 LA28_P
#set_property -dict {LOC AM10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[28]}] ;# J25.H32 LA28_N
#set_property -dict {LOC AJ14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[29]}] ;# J25.G30 LA29_P
#set_property -dict {LOC AK14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[29]}] ;# J25.G31 LA29_N
#set_property -dict {LOC AG12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[30]}] ;# J25.H34 LA30_P
#set_property -dict {LOC AH12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[30]}] ;# J25.H35 LA30_N
#set_property -dict {LOC AJ12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[31]}] ;# J25.G33 LA31_P
#set_property -dict {LOC AK12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[31]}] ;# J25.G34 LA31_N
#set_property -dict {LOC AL8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[32]}] ;# J25.H37 LA32_P
#set_property -dict {LOC AL7  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[32]}] ;# J25.H38 LA32_N
#set_property -dict {LOC AL9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[33]}] ;# J25.G36 LA33_P
#set_property -dict {LOC AM9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[33]}] ;# J25.G37 LA33_N

#set_property -dict {LOC AN21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk0_m2c_p}] ;# J25.H4 CLK0_M2C_P
#set_property -dict {LOC AP21 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk0_m2c_n}] ;# J25.H5 CLK0_M2C_N

#set_property -dict {LOC AN11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_refclk_m2c_p}] ;# J25.L24 REFCLK_M2C_P
#set_property -dict {LOC AP11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_refclk_m2c_n}] ;# J25.L25 REFCLK_M2C_N
#set_property -dict {LOC AV10 IOSTANDARD LVDS                       } [get_ports {fmc_sync_c2m_p}]   ;# J25.L16 SYNC_C2M_P
#set_property -dict {LOC AW10 IOSTANDARD LVDS                       } [get_ports {fmc_sync_c2m_n}]   ;# J25.L17 SYNC_C2M_N
#set_property -dict {LOC AN10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_sync_m2c_p}]   ;# J25.L28 SYNC_M2C_P
#set_property -dict {LOC AP10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_sync_m2c_n}]   ;# J25.L29 SYNC_M2C_N

#set_property -dict {LOC A10  IOSTANDARD LVCMOS18} [get_ports {fmc_pg_m2c}]           ;# J25.F1 PG_M2C
#set_property -dict {LOC C10  IOSTANDARD LVCMOS12} [get_ports {fmc_prsnt_m2c_l}]      ;# J25.H2 PRSNT_M2C_L
#set_property -dict {LOC B10  IOSTANDARD LVCMOS12} [get_ports {fmc_hspc_prsnt_m2c_l}] ;# J25.Z1 HSPC_PRSNT_M2C_L

set_property -dict {LOC E33 } [get_ports {fmc_dp_c2m_p[0]}]  ;# MGTYTXP3_130 GTYE4_CHANNEL_X0Y41 / GTYE4_COMMON_X0Y10 from J25.C2  DP0_C2M_P
set_property -dict {LOC E34 } [get_ports {fmc_dp_c2m_n[0]}]  ;# MGTYTXN3_130 GTYE4_CHANNEL_X0Y41 / GTYE4_COMMON_X0Y10 from J25.C3  DP0_C2M_N
set_property -dict {LOC F36 } [get_ports {fmc_dp_m2c_p[0]}]  ;# MGTYRXP3_130 GTYE4_CHANNEL_X0Y41 / GTYE4_COMMON_X0Y10 from J25.C6  DP0_M2C_P
set_property -dict {LOC F37 } [get_ports {fmc_dp_m2c_n[0]}]  ;# MGTYRXN3_130 GTYE4_CHANNEL_X0Y41 / GTYE4_COMMON_X0Y10 from J25.C7  DP0_M2C_N
set_property -dict {LOC H31 } [get_ports {fmc_dp_c2m_p[1]}]  ;# MGTYTXP0_130 GTYE4_CHANNEL_X0Y43 / GTYE4_COMMON_X0Y10 from J25.A22 DP1_C2M_P
set_property -dict {LOC H32 } [get_ports {fmc_dp_c2m_n[1]}]  ;# MGTYTXN0_130 GTYE4_CHANNEL_X0Y43 / GTYE4_COMMON_X0Y10 from J25.A23 DP1_C2M_N
set_property -dict {LOC J38 } [get_ports {fmc_dp_m2c_p[1]}]  ;# MGTYRXP0_130 GTYE4_CHANNEL_X0Y43 / GTYE4_COMMON_X0Y10 from J25.A2  DP1_M2C_P
set_property -dict {LOC J39 } [get_ports {fmc_dp_m2c_n[1]}]  ;# MGTYRXN0_130 GTYE4_CHANNEL_X0Y43 / GTYE4_COMMON_X0Y10 from J25.A3  DP1_M2C_N
set_property -dict {LOC G33 } [get_ports {fmc_dp_c2m_p[2]}]  ;# MGTYTXP1_130 GTYE4_CHANNEL_X0Y42 / GTYE4_COMMON_X0Y10 from J25.A26 DP2_C2M_P
set_property -dict {LOC G34 } [get_ports {fmc_dp_c2m_n[2]}]  ;# MGTYTXN1_130 GTYE4_CHANNEL_X0Y42 / GTYE4_COMMON_X0Y10 from J25.A27 DP2_C2M_N
set_property -dict {LOC H36 } [get_ports {fmc_dp_m2c_p[2]}]  ;# MGTYRXP1_130 GTYE4_CHANNEL_X0Y42 / GTYE4_COMMON_X0Y10 from J25.A6  DP2_M2C_P
set_property -dict {LOC H37 } [get_ports {fmc_dp_m2c_n[2]}]  ;# MGTYRXN1_130 GTYE4_CHANNEL_X0Y42 / GTYE4_COMMON_X0Y10 from J25.A7  DP2_M2C_N
set_property -dict {LOC F31 } [get_ports {fmc_dp_c2m_p[3]}]  ;# MGTYTXP2_130 GTYE4_CHANNEL_X0Y40 / GTYE4_COMMON_X0Y10 from J25.A30 DP3_C2M_P
set_property -dict {LOC F32 } [get_ports {fmc_dp_c2m_n[3]}]  ;# MGTYTXN2_130 GTYE4_CHANNEL_X0Y40 / GTYE4_COMMON_X0Y10 from J25.A31 DP3_C2M_N
set_property -dict {LOC G38 } [get_ports {fmc_dp_m2c_p[3]}]  ;# MGTYRXP2_130 GTYE4_CHANNEL_X0Y40 / GTYE4_COMMON_X0Y10 from J25.A10 DP3_M2C_P
set_property -dict {LOC G39 } [get_ports {fmc_dp_m2c_n[3]}]  ;# MGTYRXN2_130 GTYE4_CHANNEL_X0Y40 / GTYE4_COMMON_X0Y10 from J25.A11 DP3_M2C_N
set_property -dict {LOC U33 } [get_ports fmc_mgt_refclk_0_0_p] ;# MGTREFCLK0P_130 from U19.38 OUT4_P
set_property -dict {LOC U34 } [get_ports fmc_mgt_refclk_0_0_n] ;# MGTREFCLK0N_130 from U19.37 OUT4_N
#set_property -dict {LOC T31 } [get_ports fmc_mgt_refclk_0_1_p] ;# MGTREFCLK1P_130 from J25.D4 GBTCLK0_M2C_P
#set_property -dict {LOC T32 } [get_ports fmc_mgt_refclk_0_1_n] ;# MGTREFCLK1N_130 from J25.D5 GBTCLK0_M2C_N

# reference clock from U19
create_clock -period 6.206 -name fmc_mgt_refclk_0_0 [get_ports fmc_mgt_refclk_0_0_p]

# reference clcok from J25
#create_clock -period 6.400 -name fmc_mgt_refclk_0_1 [get_ports fmc_mgt_refclk_0_1_p]

set_property -dict {LOC C33 } [get_ports {fmc_dp_c2m_p[4]}]  ;# MGTYTXP1_131 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9 from J25.A34 DP4_C2M_P
set_property -dict {LOC C34 } [get_ports {fmc_dp_c2m_n[4]}]  ;# MGTYTXN1_131 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9 from J25.A35 DP4_C2M_N
set_property -dict {LOC D36 } [get_ports {fmc_dp_m2c_p[4]}]  ;# MGTYRXP1_131 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9 from J25.A14 DP4_M2C_P
set_property -dict {LOC D37 } [get_ports {fmc_dp_m2c_n[4]}]  ;# MGTYRXN1_131 GTYE4_CHANNEL_X0Y38 / GTYE4_COMMON_X0Y9 from J25.A15 DP4_M2C_N
set_property -dict {LOC A33 } [get_ports {fmc_dp_c2m_p[5]}]  ;# MGTYTXP3_131 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9 from J25.A38 DP5_C2M_P
set_property -dict {LOC A34 } [get_ports {fmc_dp_c2m_n[5]}]  ;# MGTYTXN3_131 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9 from J25.A39 DP5_C2M_N
set_property -dict {LOC B36 } [get_ports {fmc_dp_m2c_p[5]}]  ;# MGTYRXP3_131 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9 from J25.A18 DP5_M2C_P
set_property -dict {LOC B37 } [get_ports {fmc_dp_m2c_n[5]}]  ;# MGTYRXN3_131 GTYE4_CHANNEL_X0Y36 / GTYE4_COMMON_X0Y9 from J25.A19 DP5_M2C_N
set_property -dict {LOC B31 } [get_ports {fmc_dp_c2m_p[6]}]  ;# MGTYTXP2_131 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9 from J25.B36 DP6_C2M_P
set_property -dict {LOC B32 } [get_ports {fmc_dp_c2m_n[6]}]  ;# MGTYTXN2_131 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9 from J25.B37 DP6_C2M_N
set_property -dict {LOC C38 } [get_ports {fmc_dp_m2c_p[6]}]  ;# MGTYRXP2_131 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9 from J25.B16 DP6_M2C_P
set_property -dict {LOC C39 } [get_ports {fmc_dp_m2c_n[6]}]  ;# MGTYRXN2_131 GTYE4_CHANNEL_X0Y37 / GTYE4_COMMON_X0Y9 from J25.B17 DP6_M2C_N
set_property -dict {LOC D31 } [get_ports {fmc_dp_c2m_p[7]}]  ;# MGTYTXP0_131 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9 from J25.B32 DP7_C2M_P
set_property -dict {LOC D32 } [get_ports {fmc_dp_c2m_n[7]}]  ;# MGTYTXN0_131 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9 from J25.B33 DP7_C2M_N
set_property -dict {LOC E38 } [get_ports {fmc_dp_m2c_p[7]}]  ;# MGTYRXP0_131 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9 from J25.B12 DP7_M2C_P
set_property -dict {LOC E39 } [get_ports {fmc_dp_m2c_n[7]}]  ;# MGTYRXN0_131 GTYE4_CHANNEL_X0Y39 / GTYE4_COMMON_X0Y9 from J25.B13 DP7_M2C_N
set_property -dict {LOC P31 } [get_ports fmc_mgt_refclk_1_0_p] ;# MGTREFCLK0P_131 from U19.35 OUT3_P
set_property -dict {LOC P32 } [get_ports fmc_mgt_refclk_1_0_n] ;# MGTREFCLK0N_131 from U19.34 OUT3_N
#set_property -dict {LOC M31 } [get_ports fmc_mgt_refclk_1_1_p] ;# MGTREFCLK1P_131 from J25.B20 GBTCLK1_M2C_P
#set_property -dict {LOC M32 } [get_ports fmc_mgt_refclk_1_1_n] ;# MGTREFCLK1N_131 from J25.B21 GBTCLK1_M2C_N

# reference clock from U19
create_clock -period 6.206 -name fmc_mgt_refclk_1_0 [get_ports fmc_mgt_refclk_1_0_p]

# reference clcok from J25
#create_clock -period 6.400 -name fmc_mgt_refclk_1_1 [get_ports fmc_mgt_refclk_1_1_p]
