# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# FMC LPC J2
set_property -dict {LOC W23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[0]"]  ;# J2.G9  LA00_P_CC
set_property -dict {LOC W24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[0]"]  ;# J2.G10 LA00_N_CC
set_property -dict {LOC W25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[1]"]  ;# J2.D8  LA01_P_CC
set_property -dict {LOC Y25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[1]"]  ;# J2.D9  LA01_N_CC
set_property -dict {LOC AA22 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[2]"]  ;# J2.H7  LA02_P
set_property -dict {LOC AB22 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[2]"]  ;# J2.H8  LA02_N
set_property -dict {LOC W28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[3]"]  ;# J2.G12 LA03_P
set_property -dict {LOC Y28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[3]"]  ;# J2.G13 LA03_N
set_property -dict {LOC U26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[4]"]  ;# J2.H10 LA04_P
set_property -dict {LOC U27  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[4]"]  ;# J2.H11 LA04_N
set_property -dict {LOC V27  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[5]"]  ;# J2.D11 LA05_P
set_property -dict {LOC V28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[5]"]  ;# J2.D12 LA05_N
set_property -dict {LOC V29  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[6]"]  ;# J2.C10 LA06_P
set_property -dict {LOC W29  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[6]"]  ;# J2.C11 LA06_N
set_property -dict {LOC V22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[7]"]  ;# J2.H13 LA07_P
set_property -dict {LOC V23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[7]"]  ;# J2.H14 LA07_N
set_property -dict {LOC U24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[8]"]  ;# J2.G12 LA08_P
set_property -dict {LOC U25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[8]"]  ;# J2.G13 LA08_N
set_property -dict {LOC V26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[9]"]  ;# J2.D14 LA09_P
set_property -dict {LOC W26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[9]"]  ;# J2.D15 LA09_N
set_property -dict {LOC T22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[10]"] ;# J2.C14 LA10_P
set_property -dict {LOC T23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[10]"] ;# J2.C15 LA10_N
set_property -dict {LOC V21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[11]"] ;# J2.H16 LA11_P
set_property -dict {LOC W21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[11]"] ;# J2.H17 LA11_N
set_property -dict {LOC AC22 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[12]"] ;# J2.G15 LA12_P
set_property -dict {LOC AC23 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[12]"] ;# J2.G16 LA12_N
set_property -dict {LOC AA20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[13]"] ;# J2.D17 LA13_P
set_property -dict {LOC AB20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[13]"] ;# J2.D18 LA13_N
set_property -dict {LOC U21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[14]"] ;# J2.C18 LA14_P
set_property -dict {LOC U22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[14]"] ;# J2.C19 LA14_N
set_property -dict {LOC AB25 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[15]"] ;# J2.H19 LA15_P
set_property -dict {LOC AB26 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[15]"] ;# J2.H20 LA15_N
set_property -dict {LOC AB21 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[16]"] ;# J2.G18 LA16_P
set_property -dict {LOC AC21 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[16]"] ;# J2.G19 LA16_N
set_property -dict {LOC AA32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[17]"] ;# J2.D20 LA17_P_CC
set_property -dict {LOC AB32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[17]"] ;# J2.D21 LA17_N_CC
set_property -dict {LOC AB30 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[18]"] ;# J2.C22 LA18_P_CC
set_property -dict {LOC AB31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[18]"] ;# J2.C23 LA18_N_CC
set_property -dict {LOC AA29 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[19]"] ;# J2.H22 LA19_P
set_property -dict {LOC AB29 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[19]"] ;# J2.H23 LA19_N
set_property -dict {LOC AA34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[20]"] ;# J2.G21 LA20_P
set_property -dict {LOC AB34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[20]"] ;# J2.G22 LA20_N
set_property -dict {LOC AC33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[21]"] ;# J2.H25 LA21_P
set_property -dict {LOC AD33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[21]"] ;# J2.H26 LA21_N
set_property -dict {LOC AC34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[22]"] ;# J2.G24 LA22_P
set_property -dict {LOC AD34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[22]"] ;# J2.G25 LA22_N
set_property -dict {LOC AD30 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[23]"] ;# J2.D23 LA23_P
set_property -dict {LOC AD31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[23]"] ;# J2.D24 LA23_N
set_property -dict {LOC AE32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[24]"] ;# J2.H28 LA24_P
set_property -dict {LOC AF32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[24]"] ;# J2.H29 LA24_N
set_property -dict {LOC AE33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[25]"] ;# J2.G27 LA25_P
set_property -dict {LOC AF34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[25]"] ;# J2.G28 LA25_N
set_property -dict {LOC AF33 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[26]"] ;# J2.D26 LA26_P
set_property -dict {LOC AG34 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[26]"] ;# J2.D27 LA26_N
set_property -dict {LOC AG31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[27]"] ;# J2.C26 LA27_P
set_property -dict {LOC AG32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[27]"] ;# J2.C27 LA27_N
set_property -dict {LOC V31  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[28]"] ;# J2.H31 LA28_P
set_property -dict {LOC W31  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[28]"] ;# J2.H32 LA28_N
set_property -dict {LOC U34  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[29]"] ;# J2.G30 LA29_P
set_property -dict {LOC V34  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[29]"] ;# J2.G31 LA29_N
set_property -dict {LOC Y31  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[30]"] ;# J2.H34 LA30_P
set_property -dict {LOC Y32  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[30]"] ;# J2.H35 LA30_N
set_property -dict {LOC V33  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[31]"] ;# J2.G33 LA31_P
set_property -dict {LOC W34  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[31]"] ;# J2.G34 LA31_N
set_property -dict {LOC W30  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[32]"] ;# J2.H37 LA32_P
set_property -dict {LOC Y30  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[32]"] ;# J2.H38 LA32_N
set_property -dict {LOC W33  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_p[33]"] ;# J2.G36 LA33_P
set_property -dict {LOC Y33  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_la_n[33]"] ;# J2.G37 LA33_N

set_property -dict {LOC AA24 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk0_m2c_p"] ;# J2.H4 CLK0_M2C_P
set_property -dict {LOC AA25 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk0_m2c_n"] ;# J2.H5 CLK0_M2C_N
set_property -dict {LOC AC31 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk1_m2c_p"] ;# J2.G2 CLK1_M2C_P
set_property -dict {LOC AC32 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_lpc_clk1_m2c_n"] ;# J2.G3 CLK1_M2C_N

set_property -dict {LOC J26  IOSTANDARD LVCMOS18} [get_ports {fmc_lpc_prsnt_m2c_l}] ;# J2.H2 PRSNT_M2C_L

set_property -dict {LOC AA4 } [get_ports {fmc_lpc_dp_c2m_p[0]}] ;# MGTHTXP0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C2  DP0_C2M_P
set_property -dict {LOC AA3 } [get_ports {fmc_lpc_dp_c2m_n[0]}] ;# MGTHTXN0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C3  DP0_C2M_N
set_property -dict {LOC Y2  } [get_ports {fmc_lpc_dp_m2c_p[0]}] ;# MGTHRXP0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C6  DP0_M2C_P
set_property -dict {LOC Y1  } [get_ports {fmc_lpc_dp_m2c_n[0]}] ;# MGTHRXN0_226 GTHE3_CHANNEL_X0Y8 / GTHE3_COMMON_X0Y2 from J2.C7  DP0_M2C_N
set_property -dict {LOC T6  } [get_ports fmc_lpc_mgt_refclk_p] ;# MGTREFCLK1P_226 from J2.D4 GBTCLK0_M2C_P
set_property -dict {LOC T5  } [get_ports fmc_lpc_mgt_refclk_n] ;# MGTREFCLK1N_226 from J2.D5 GBTCLK0_M2C_N

# reference clock
create_clock -period 6.400 -name fmc_lpc_mgt_refclk [get_ports fmc_lpc_mgt_refclk_p]
