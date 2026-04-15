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

# FMC+ J9
set_property -dict {LOC BA15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[0]}]  ;# J9.G9  LA00_P_CC
set_property -dict {LOC BA14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[0]}]  ;# J9.G10 LA00_N_CC
set_property -dict {LOC AY13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[1]}]  ;# J9.D8  LA01_P_CC
set_property -dict {LOC BA13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[1]}]  ;# J9.D9  LA01_N_CC
set_property -dict {LOC AL15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[2]}]  ;# J9.H7  LA02_P
set_property -dict {LOC AM15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[2]}]  ;# J9.H8  LA02_N
set_property -dict {LOC AN14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[3]}]  ;# J9.G12 LA03_P
set_property -dict {LOC AN13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[3]}]  ;# J9.G13 LA03_N
set_property -dict {LOC AL14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[4]}]  ;# J9.H10 LA04_P
set_property -dict {LOC AM14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[4]}]  ;# J9.H11 LA04_N
set_property -dict {LOC AP13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[5]}]  ;# J9.D11 LA05_P
set_property -dict {LOC AR13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[5]}]  ;# J9.D12 LA05_N
set_property -dict {LOC AP15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[6]}]  ;# J9.C10 LA06_P
set_property -dict {LOC AP14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[6]}]  ;# J9.C11 LA06_N
set_property -dict {LOC AU16 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[7]}]  ;# J9.H13 LA07_P
set_property -dict {LOC AV16 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[7]}]  ;# J9.H14 LA07_N
set_property -dict {LOC AR16 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[8]}]  ;# J9.G12 LA08_P
set_property -dict {LOC AR15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[8]}]  ;# J9.G13 LA08_N
set_property -dict {LOC AT15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[9]}]  ;# J9.D14 LA09_P
set_property -dict {LOC AU15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[9]}]  ;# J9.D15 LA09_N
set_property -dict {LOC AU14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[10]}] ;# J9.C14 LA10_P
set_property -dict {LOC AV14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[10]}] ;# J9.C15 LA10_N
set_property -dict {LOC BD15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[11]}] ;# J9.H16 LA11_P
set_property -dict {LOC BD14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[11]}] ;# J9.H17 LA11_N
set_property -dict {LOC AY12 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[12]}] ;# J9.G15 LA12_P
set_property -dict {LOC AY11 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[12]}] ;# J9.G16 LA12_N
set_property -dict {LOC BA12 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[13]}] ;# J9.D17 LA13_P
set_property -dict {LOC BB12 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[13]}] ;# J9.D18 LA13_N
set_property -dict {LOC BB15 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[14]}] ;# J9.C18 LA14_P
set_property -dict {LOC BB14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[14]}] ;# J9.C19 LA14_N
set_property -dict {LOC BF14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[15]}] ;# J9.H19 LA15_P
set_property -dict {LOC BF13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[15]}] ;# J9.H20 LA15_N
set_property -dict {LOC BD16 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[16]}] ;# J9.G18 LA16_P
set_property -dict {LOC BE16 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[16]}] ;# J9.G19 LA16_N
set_property -dict {LOC AT20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[17]}] ;# J9.D20 LA17_P_CC
set_property -dict {LOC AU20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[17]}] ;# J9.D21 LA17_N_CC
set_property -dict {LOC AV19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[18]}] ;# J9.C22 LA18_P_CC
set_property -dict {LOC AW19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[18]}] ;# J9.C23 LA18_N_CC
set_property -dict {LOC AR17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[19]}] ;# J9.H22 LA19_P
set_property -dict {LOC AT17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[19]}] ;# J9.H23 LA19_N
set_property -dict {LOC AN18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[20]}] ;# J9.G21 LA20_P
set_property -dict {LOC AN17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[20]}] ;# J9.G22 LA20_N
set_property -dict {LOC AW20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[21]}] ;# J9.H25 LA21_P
set_property -dict {LOC AY20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[21]}] ;# J9.H26 LA21_N
set_property -dict {LOC AT19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[22]}] ;# J9.G24 LA22_P
set_property -dict {LOC AU19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[22]}] ;# J9.G25 LA22_N
set_property -dict {LOC AL17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[23]}] ;# J9.D23 LA23_P
set_property -dict {LOC AM17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[23]}] ;# J9.D24 LA23_N
set_property -dict {LOC AY17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[24]}] ;# J9.H28 LA24_P
set_property -dict {LOC BA17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[24]}] ;# J9.H29 LA24_N
set_property -dict {LOC AY18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[25]}] ;# J9.G27 LA25_P
set_property -dict {LOC BA18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[25]}] ;# J9.G28 LA25_N
set_property -dict {LOC AP20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[26]}] ;# J9.D26 LA26_P
set_property -dict {LOC AP20 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[26]}] ;# J9.D27 LA26_N
set_property -dict {LOC AN19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[27]}] ;# J9.C26 LA27_P
set_property -dict {LOC AP19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[27]}] ;# J9.C27 LA27_N
set_property -dict {LOC BB17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[28]}] ;# J9.H31 LA28_P
set_property -dict {LOC BC17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[28]}] ;# J9.H32 LA28_N
set_property -dict {LOC BB19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[29]}] ;# J9.G30 LA29_P
set_property -dict {LOC BC18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[29]}] ;# J9.G31 LA29_N
set_property -dict {LOC BD18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[30]}] ;# J9.H34 LA30_P
set_property -dict {LOC BE18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[30]}] ;# J9.H35 LA30_N
set_property -dict {LOC BC19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[31]}] ;# J9.G33 LA31_P
set_property -dict {LOC BD19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[31]}] ;# J9.G34 LA31_N
set_property -dict {LOC BF19 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[32]}] ;# J9.H37 LA32_P
set_property -dict {LOC BF18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[32]}] ;# J9.H38 LA32_N
set_property -dict {LOC BE17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[33]}] ;# J9.G36 LA33_P
set_property -dict {LOC BF17 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[33]}] ;# J9.G37 LA33_N

set_property -dict {LOC G14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[0]}]  ;# J9.F4  HA00_P_CC
set_property -dict {LOC F14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[0]}]  ;# J9.F5  HA00_N_CC
set_property -dict {LOC G15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[1]}]  ;# J9.E2  HA01_P_CC
set_property -dict {LOC F15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[1]}]  ;# J9.E3  HA01_N_CC
set_property -dict {LOC A14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[2]}]  ;# J9.K7  HA02_P
set_property -dict {LOC A13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[2]}]  ;# J9.K8  HA02_N
set_property -dict {LOC B17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[3]}]  ;# J9.J6  HA03_P
set_property -dict {LOC A17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[3]}]  ;# J9.J7  HA03_N
set_property -dict {LOC C16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[4]}]  ;# J9.F7  HA04_P
set_property -dict {LOC B16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[4]}]  ;# J9.F8  HA04_N
set_property -dict {LOC B15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[5]}]  ;# J9.E6  HA05_P
set_property -dict {LOC A15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[5]}]  ;# J9.E7  HA05_N
set_property -dict {LOC G17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[6]}]  ;# J9.K10 HA06_P
set_property -dict {LOC G16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[6]}]  ;# J9.K11 HA06_N
set_property -dict {LOC D13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[7]}]  ;# J9.J9  HA07_P
set_property -dict {LOC C13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[7]}]  ;# J9.J10 HA07_N
set_property -dict {LOC E15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[8]}]  ;# J9.F10 HA08_P
set_property -dict {LOC D15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[8]}]  ;# J9.F11 HA08_N
set_property -dict {LOC E16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[9]}]  ;# J9.E9  HA09_P
set_property -dict {LOC D16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[9]}]  ;# J9.E10 HA09_N
set_property -dict {LOC R16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[10]}] ;# J9.K13 HA10_P
set_property -dict {LOC P16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[10]}] ;# J9.K14 HA10_N
set_property -dict {LOC L13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[11]}] ;# J9.J12 HA11_P
set_property -dict {LOC K13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[11]}] ;# J9.J13 HA11_N
set_property -dict {LOC H17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[12]}] ;# J9.F13 HA12_P
set_property -dict {LOC H16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[12]}] ;# J9.F14 HA12_N
set_property -dict {LOC J13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[13]}] ;# J9.E12 HA13_P
set_property -dict {LOC H13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[13]}] ;# J9.E13 HA13_N
set_property -dict {LOC P14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[14]}] ;# J9.J15 HA14_P
set_property -dict {LOC N14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[14]}] ;# J9.J16 HA14_N
set_property -dict {LOC N16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[15]}] ;# J9.F14 HA15_P
set_property -dict {LOC M16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[15]}] ;# J9.F16 HA15_N
set_property -dict {LOC M14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[16]}] ;# J9.E15 HA16_P
set_property -dict {LOC L14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[16]}] ;# J9.E16 HA16_N
set_property -dict {LOC J14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[17]}] ;# J9.K16 HA17_P_CC
set_property -dict {LOC H14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[17]}] ;# J9.K17 HA17_N_CC
set_property -dict {LOC J16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[18]}] ;# J9.J18 HA18_P_CC
set_property -dict {LOC J15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[18]}] ;# J9.J19 HA18_N_CC
set_property -dict {LOC F13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[19]}] ;# J9.F19 HA19_P
set_property -dict {LOC E13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[19]}] ;# J9.F20 HA19_N
set_property -dict {LOC K16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[20]}] ;# J9.E18 HA20_P
set_property -dict {LOC K15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[20]}] ;# J9.E19 HA20_N
set_property -dict {LOC C14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[21]}] ;# J9.K19 HA21_P
set_property -dict {LOC B14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[21]}] ;# J9.K20 HA21_N
set_property -dict {LOC R15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[22]}] ;# J9.J21 HA22_P
set_property -dict {LOC P15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[22]}] ;# J9.J22 HA22_N
set_property -dict {LOC P13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_p[23]}] ;# J9.K22 HA23_P
set_property -dict {LOC N13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_ha_n[23]}] ;# J9.K23 HA23_N

set_property -dict {LOC H19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[0]}]  ;# J9.K25 HB00_P_CC
set_property -dict {LOC H18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[0]}]  ;# J9.K26 HB00_N_CC
set_property -dict {LOC D18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[1]}]  ;# J9.J24 HB01_P
set_property -dict {LOC C18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[1]}]  ;# J9.J25 HB01_N
set_property -dict {LOC D19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[2]}]  ;# J9.F22 HB02_P
set_property -dict {LOC C19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[2]}]  ;# J9.F23 HB02_N
set_property -dict {LOC B20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[3]}]  ;# J9.E21 HB03_P
set_property -dict {LOC A20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[3]}]  ;# J9.E22 HB03_N
set_property -dict {LOC F18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[4]}]  ;# J9.F25 HB04_P
set_property -dict {LOC F17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[4]}]  ;# J9.F26 HB04_N
set_property -dict {LOC E18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[5]}]  ;# J9.E24 HB05_P
set_property -dict {LOC E17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[5]}]  ;# J9.E25 HB05_N
set_property -dict {LOC J20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[6]}]  ;# J9.K28 HB06_P_CC
set_property -dict {LOC J19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[6]}]  ;# J9.K29 HB06_N_CC
set_property -dict {LOC F20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[7]}]  ;# J9.J27 HB07_P
set_property -dict {LOC F19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[7]}]  ;# J9.J28 HB07_N
set_property -dict {LOC J21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[8]}]  ;# J9.F28 HB08_P
set_property -dict {LOC H21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[8]}]  ;# J9.F29 HB08_N
set_property -dict {LOC G20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[9]}]  ;# J9.E27 HB09_P
set_property -dict {LOC G19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[9]}]  ;# J9.E28 HB09_N
set_property -dict {LOC P19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[10]}] ;# J9.K31 HB10_P
set_property -dict {LOC N19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[10]}] ;# J9.K32 HB10_N
set_property -dict {LOC L17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[11]}] ;# J9.J30 HB11_P
set_property -dict {LOC K17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[11]}] ;# J9.J31 HB11_N
set_property -dict {LOC L19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[12]}] ;# J9.F31 HB12_P
set_property -dict {LOC L18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[12]}] ;# J9.F32 HB12_N
set_property -dict {LOC N17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[13]}] ;# J9.E30 HB13_P
set_property -dict {LOC M17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[13]}] ;# J9.E31 HB13_N
set_property -dict {LOC N21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[14]}] ;# J9.K34 HB14_P
set_property -dict {LOC M21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[14]}] ;# J9.K35 HB14_N
set_property -dict {LOC R20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[15]}] ;# J9.J33 HB15_P
set_property -dict {LOC P20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[15]}] ;# J9.J34 HB15_N
set_property -dict {LOC L20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[16]}] ;# J9.F34 HB16_P
set_property -dict {LOC K20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[16]}] ;# J9.F35 HB16_N
set_property -dict {LOC K18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[17]}] ;# J9.K37 HB17_P_CC
set_property -dict {LOC J18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[17]}] ;# J9.K38 HB17_N_CC
set_property -dict {LOC C21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[18]}] ;# J9.J36 HB18_P
set_property -dict {LOC B21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[18]}] ;# J9.J37 HB18_N
set_property -dict {LOC E21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[19]}] ;# J9.E33 HB19_P
set_property -dict {LOC E20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[19]}] ;# J9.E34 HB19_N
set_property -dict {LOC B19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[20]}] ;# J9.F37 HB20_P
set_property -dict {LOC A19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[20]}] ;# J9.F38 HB20_N
set_property -dict {LOC D21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_p[21]}] ;# J9.E36 HB21_P
set_property -dict {LOC D20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_hb_n[21]}] ;# J9.E37 HB21_N

set_property -dict {LOC AW14 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_clk0_m2c_p}] ;# J9.H4 CLK0_M2C_P
set_property -dict {LOC AW13 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_clk0_m2c_n}] ;# J9.H5 CLK0_M2C_N
set_property -dict {LOC AV18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_clk1_m2c_p}] ;# J9.G2 CLK1_M2C_P
set_property -dict {LOC AW18 IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_clk1_m2c_n}] ;# J9.G3 CLK1_M2C_N

set_property -dict {LOC G25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_user_def0_p}]  ;# J9.L32 USER_DEF0_P
set_property -dict {LOC G24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_user_def0_n}]  ;# J9.L33 USER_DEF0_N
set_property -dict {LOC F24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_refclk_m2c_p}] ;# J9.L24 REFCLK_M2C_P
set_property -dict {LOC F23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_refclk_m2c_n}] ;# J9.L25 REFCLK_M2C_N
set_property -dict {LOC E23  IOSTANDARD LVDS               } [get_ports {fmc_sync_c2m_p}]   ;# J9.L16 SYNC_C2M_P
set_property -dict {LOC E22  IOSTANDARD LVDS               } [get_ports {fmc_sync_c2m_n}]   ;# J9.L17 SYNC_C2M_N
set_property -dict {LOC J24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_sync_m2c_p}]   ;# J9.L28 SYNC_M2C_P
set_property -dict {LOC H24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_sync_m2c_n}]   ;# J9.L29 SYNC_M2C_N

set_property -dict {LOC AV23 IOSTANDARD LVCMOS18} [get_ports {fmc_pg_m2c}]           ;# J9.F1 PG_M2C
set_property -dict {LOC AW23 IOSTANDARD LVCMOS18} [get_ports {fmc_prsnt_m2c_l}]      ;# J9.H2 PRSNT_M2C_L
set_property -dict {LOC BC23 IOSTANDARD LVCMOS18} [get_ports {fmc_hspc_prsnt_m2c_l}] ;# J9.Z1 HSPC_PRSNT_M2C_L

set_property -dict {LOC Y7  } [get_ports {fmc_dp_c2m_p[0]}]  ;# MGTYTXP1_229 GTYE4_CHANNEL_X1Y41 / GTYE4_COMMON_X1Y10 from J9.C2  DP0_C2M_P
set_property -dict {LOC Y6  } [get_ports {fmc_dp_c2m_n[0]}]  ;# MGTYTXN1_229 GTYE4_CHANNEL_X1Y41 / GTYE4_COMMON_X1Y10 from J9.C3  DP0_C2M_N
set_property -dict {LOC Y2  } [get_ports {fmc_dp_m2c_p[0]}]  ;# MGTYRXP1_229 GTYE4_CHANNEL_X1Y41 / GTYE4_COMMON_X1Y10 from J9.C6  DP0_M2C_P
set_property -dict {LOC Y1  } [get_ports {fmc_dp_m2c_n[0]}]  ;# MGTYRXN1_229 GTYE4_CHANNEL_X1Y41 / GTYE4_COMMON_X1Y10 from J9.C7  DP0_M2C_N
set_property -dict {LOC V7  } [get_ports {fmc_dp_c2m_p[1]}]  ;# MGTYTXP3_229 GTYE4_CHANNEL_X1Y43 / GTYE4_COMMON_X1Y10 from J9.A22 DP1_C2M_P
set_property -dict {LOC V6  } [get_ports {fmc_dp_c2m_n[1]}]  ;# MGTYTXN3_229 GTYE4_CHANNEL_X1Y43 / GTYE4_COMMON_X1Y10 from J9.A23 DP1_C2M_N
set_property -dict {LOC V2  } [get_ports {fmc_dp_m2c_p[1]}]  ;# MGTYRXP3_229 GTYE4_CHANNEL_X1Y43 / GTYE4_COMMON_X1Y10 from J9.A2  DP1_M2C_P
set_property -dict {LOC V1  } [get_ports {fmc_dp_m2c_n[1]}]  ;# MGTYRXN3_229 GTYE4_CHANNEL_X1Y43 / GTYE4_COMMON_X1Y10 from J9.A3  DP1_M2C_N
set_property -dict {LOC W9  } [get_ports {fmc_dp_c2m_p[2]}]  ;# MGTYTXP2_229 GTYE4_CHANNEL_X1Y42 / GTYE4_COMMON_X1Y10 from J9.A26 DP2_C2M_P
set_property -dict {LOC W8  } [get_ports {fmc_dp_c2m_n[2]}]  ;# MGTYTXN2_229 GTYE4_CHANNEL_X1Y42 / GTYE4_COMMON_X1Y10 from J9.A27 DP2_C2M_N
set_property -dict {LOC W4  } [get_ports {fmc_dp_m2c_p[2]}]  ;# MGTYRXP2_229 GTYE4_CHANNEL_X1Y42 / GTYE4_COMMON_X1Y10 from J9.A6  DP2_M2C_P
set_property -dict {LOC W3  } [get_ports {fmc_dp_m2c_n[2]}]  ;# MGTYRXN2_229 GTYE4_CHANNEL_X1Y42 / GTYE4_COMMON_X1Y10 from J9.A7  DP2_M2C_N
set_property -dict {LOC AA9 } [get_ports {fmc_dp_c2m_p[3]}]  ;# MGTYTXP0_229 GTYE4_CHANNEL_X1Y40 / GTYE4_COMMON_X1Y10 from J9.A30 DP3_C2M_P
set_property -dict {LOC AA8 } [get_ports {fmc_dp_c2m_n[3]}]  ;# MGTYTXN0_229 GTYE4_CHANNEL_X1Y40 / GTYE4_COMMON_X1Y10 from J9.A31 DP3_C2M_N
set_property -dict {LOC AA4 } [get_ports {fmc_dp_m2c_p[3]}]  ;# MGTYRXP0_229 GTYE4_CHANNEL_X1Y40 / GTYE4_COMMON_X1Y10 from J9.A10 DP3_M2C_P
set_property -dict {LOC AA3 } [get_ports {fmc_dp_m2c_n[3]}]  ;# MGTYRXN0_229 GTYE4_CHANNEL_X1Y40 / GTYE4_COMMON_X1Y10 from J9.A11 DP3_M2C_N
set_property -dict {LOC Y11 } [get_ports fmc_mgt_refclk_0_0_p] ;# MGTREFCLK0P_229 from J9.D4 GBTCLK0_M2C_P
set_property -dict {LOC Y10 } [get_ports fmc_mgt_refclk_0_0_n] ;# MGTREFCLK0N_229 from J9.D5 GBTCLK0_M2C_N
set_property -dict {LOC V11 } [get_ports fmc_mgt_refclk_0_1_p] ;# MGTREFCLK1P_229 from U27.14 OUT3
set_property -dict {LOC V10 } [get_ports fmc_mgt_refclk_0_1_n] ;# MGTREFCLK1N_229 from U27.13 OUT3B

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_0_0 [get_ports fmc_mgt_refclk_0_0_p]
create_clock -period 6.400 -name fmc_mgt_refclk_0_1 [get_ports fmc_mgt_refclk_0_1_p]

set_property -dict {LOC AC9 } [get_ports {fmc_dp_c2m_p[4]}]  ;# MGTYTXP2_228 GTYE4_CHANNEL_X1Y38 / GTYE4_COMMON_X1Y9 from J22.A34 DP4_C2M_P
set_property -dict {LOC AC8 } [get_ports {fmc_dp_c2m_n[4]}]  ;# MGTYTXN2_228 GTYE4_CHANNEL_X1Y38 / GTYE4_COMMON_X1Y9 from J22.A35 DP4_C2M_N
set_property -dict {LOC AC4 } [get_ports {fmc_dp_m2c_p[4]}]  ;# MGTYRXP2_228 GTYE4_CHANNEL_X1Y38 / GTYE4_COMMON_X1Y9 from J22.A14 DP4_M2C_P
set_property -dict {LOC AC3 } [get_ports {fmc_dp_m2c_n[4]}]  ;# MGTYRXN2_228 GTYE4_CHANNEL_X1Y38 / GTYE4_COMMON_X1Y9 from J22.A15 DP4_M2C_N
set_property -dict {LOC AE9 } [get_ports {fmc_dp_c2m_p[5]}]  ;# MGTYTXP0_228 GTYE4_CHANNEL_X1Y36 / GTYE4_COMMON_X1Y9 from J22.A38 DP5_C2M_P
set_property -dict {LOC AE8 } [get_ports {fmc_dp_c2m_n[5]}]  ;# MGTYTXN0_228 GTYE4_CHANNEL_X1Y36 / GTYE4_COMMON_X1Y9 from J22.A39 DP5_C2M_N
set_property -dict {LOC AE4 } [get_ports {fmc_dp_m2c_p[5]}]  ;# MGTYRXP0_228 GTYE4_CHANNEL_X1Y36 / GTYE4_COMMON_X1Y9 from J22.A18 DP5_M2C_P
set_property -dict {LOC AE3 } [get_ports {fmc_dp_m2c_n[5]}]  ;# MGTYRXN0_228 GTYE4_CHANNEL_X1Y36 / GTYE4_COMMON_X1Y9 from J22.A19 DP5_M2C_N
set_property -dict {LOC AD7 } [get_ports {fmc_dp_c2m_p[6]}]  ;# MGTYTXP1_228 GTYE4_CHANNEL_X1Y37 / GTYE4_COMMON_X1Y9 from J22.B36 DP6_C2M_P
set_property -dict {LOC AD6 } [get_ports {fmc_dp_c2m_n[6]}]  ;# MGTYTXN1_228 GTYE4_CHANNEL_X1Y37 / GTYE4_COMMON_X1Y9 from J22.B37 DP6_C2M_N
set_property -dict {LOC AD2 } [get_ports {fmc_dp_m2c_p[6]}]  ;# MGTYRXP1_228 GTYE4_CHANNEL_X1Y37 / GTYE4_COMMON_X1Y9 from J22.B16 DP6_M2C_P
set_property -dict {LOC AD1 } [get_ports {fmc_dp_m2c_n[6]}]  ;# MGTYRXN1_228 GTYE4_CHANNEL_X1Y37 / GTYE4_COMMON_X1Y9 from J22.B17 DP6_M2C_N
set_property -dict {LOC AB7 } [get_ports {fmc_dp_c2m_p[7]}]  ;# MGTYTXP3_228 GTYE4_CHANNEL_X1Y39 / GTYE4_COMMON_X1Y9 from J22.B32 DP7_C2M_P
set_property -dict {LOC AB6 } [get_ports {fmc_dp_c2m_n[7]}]  ;# MGTYTXN3_228 GTYE4_CHANNEL_X1Y39 / GTYE4_COMMON_X1Y9 from J22.B33 DP7_C2M_N
set_property -dict {LOC AB2 } [get_ports {fmc_dp_m2c_p[7]}]  ;# MGTYRXP3_228 GTYE4_CHANNEL_X1Y39 / GTYE4_COMMON_X1Y9 from J22.B12 DP7_M2C_P
set_property -dict {LOC AB1 } [get_ports {fmc_dp_m2c_n[7]}]  ;# MGTYRXN3_228 GTYE4_CHANNEL_X1Y39 / GTYE4_COMMON_X1Y9 from J22.B13 DP7_M2C_N
set_property -dict {LOC AD11} [get_ports fmc_mgt_refclk_1_0_p] ;# MGTREFCLK0P_228 from J9.B20 GBTCLK1_M2C_P
set_property -dict {LOC AD10} [get_ports fmc_mgt_refclk_1_0_n] ;# MGTREFCLK0N_228 from J9.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_1_0 [get_ports fmc_mgt_refclk_1_0_p]

set_property -dict {LOC L9  } [get_ports {fmc_dp_c2m_p[8]}]  ;# MGTYTXP2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12 from J22.B28 DP8_C2M_P
set_property -dict {LOC L8  } [get_ports {fmc_dp_c2m_n[8]}]  ;# MGTYTXN2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12 from J22.B29 DP8_C2M_N
set_property -dict {LOC L4  } [get_ports {fmc_dp_m2c_p[8]}]  ;# MGTYRXP2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12 from J22.B8  DP8_M2C_P
set_property -dict {LOC L3  } [get_ports {fmc_dp_m2c_n[8]}]  ;# MGTYRXN2_231 GTYE4_CHANNEL_X1Y50 / GTYE4_COMMON_X1Y12 from J22.B9  DP8_M2C_N
set_property -dict {LOC K7  } [get_ports {fmc_dp_c2m_p[9]}]  ;# MGTYTXP3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12 from J22.B24 DP9_C2M_P
set_property -dict {LOC K6  } [get_ports {fmc_dp_c2m_n[9]}]  ;# MGTYTXN3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12 from J22.B25 DP9_C2M_N
set_property -dict {LOC K2  } [get_ports {fmc_dp_m2c_p[9]}]  ;# MGTYRXP3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12 from J22.B4  DP9_M2C_P
set_property -dict {LOC K1  } [get_ports {fmc_dp_m2c_n[9]}]  ;# MGTYRXN3_231 GTYE4_CHANNEL_X1Y51 / GTYE4_COMMON_X1Y12 from J22.B5  DP9_M2C_N
set_property -dict {LOC M7  } [get_ports {fmc_dp_c2m_p[10]}] ;# MGTYTXP1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12 from J22.Z24 DP10_C2M_P
set_property -dict {LOC M6  } [get_ports {fmc_dp_c2m_n[10]}] ;# MGTYTXN1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12 from J22.Z25 DP10_C2M_N
set_property -dict {LOC M2  } [get_ports {fmc_dp_m2c_p[10]}] ;# MGTYRXP1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12 from J22.Y10 DP10_M2C_P
set_property -dict {LOC M1  } [get_ports {fmc_dp_m2c_n[10]}] ;# MGTYRXN1_231 GTYE4_CHANNEL_X1Y49 / GTYE4_COMMON_X1Y12 from J22.Y11 DP10_M2C_N
set_property -dict {LOC N9  } [get_ports {fmc_dp_c2m_p[11]}] ;# MGTYTXP0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12 from J22.Y26 DP11_C2M_P
set_property -dict {LOC N8  } [get_ports {fmc_dp_c2m_n[11]}] ;# MGTYTXN0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12 from J22.Y27 DP11_C2M_N
set_property -dict {LOC N4  } [get_ports {fmc_dp_m2c_p[11]}] ;# MGTYRXP0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12 from J22.Z12 DP11_M2C_P
set_property -dict {LOC N3  } [get_ports {fmc_dp_m2c_n[11]}] ;# MGTYRXN0_231 GTYE4_CHANNEL_X1Y48 / GTYE4_COMMON_X1Y12 from J22.Z13 DP11_M2C_N
set_property -dict {LOC M11 } [get_ports fmc_mgt_refclk_2_0_p] ;# MGTREFCLK0P_231 from J9.L12 GBTCLK2_M2C_P
set_property -dict {LOC M10 } [get_ports fmc_mgt_refclk_2_0_n] ;# MGTREFCLK0N_231 from J9.L13 GBTCLK2_M2C_N
set_property -dict {LOC K11 } [get_ports fmc_mgt_refclk_2_1_p] ;# MGTREFCLK1P_231 from U27.17 OUT2
set_property -dict {LOC K10 } [get_ports fmc_mgt_refclk_2_1_n] ;# MGTREFCLK1N_231 from U27.16 OUT2B

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_2_0 [get_ports fmc_mgt_refclk_2_0_p]
create_clock -period 6.400 -name fmc_mgt_refclk_2_1 [get_ports fmc_mgt_refclk_2_1_p]

set_property -dict {LOC P7  } [get_ports {fmc_dp_c2m_p[12]}] ;# MGTYTXP3_230 GTYE4_CHANNEL_X1Y47 / GTYE4_COMMON_X1Y11 from J22.Z28 DP12_C2M_P
set_property -dict {LOC P6  } [get_ports {fmc_dp_c2m_n[12]}] ;# MGTYTXN3_230 GTYE4_CHANNEL_X1Y47 / GTYE4_COMMON_X1Y11 from J22.Z29 DP12_C2M_N
set_property -dict {LOC P2  } [get_ports {fmc_dp_m2c_p[12]}] ;# MGTYRXP3_230 GTYE4_CHANNEL_X1Y47 / GTYE4_COMMON_X1Y11 from J22.Y14 DP12_M2C_P
set_property -dict {LOC P1  } [get_ports {fmc_dp_m2c_n[12]}] ;# MGTYRXN3_230 GTYE4_CHANNEL_X1Y47 / GTYE4_COMMON_X1Y11 from J22.Y15 DP12_M2C_N
set_property -dict {LOC R9  } [get_ports {fmc_dp_c2m_p[13]}] ;# MGTYTXP2_230 GTYE4_CHANNEL_X1Y46 / GTYE4_COMMON_X1Y11 from J22.Y30 DP13_C2M_P
set_property -dict {LOC R8  } [get_ports {fmc_dp_c2m_n[13]}] ;# MGTYTXN2_230 GTYE4_CHANNEL_X1Y46 / GTYE4_COMMON_X1Y11 from J22.Y31 DP13_C2M_N
set_property -dict {LOC R4  } [get_ports {fmc_dp_m2c_p[13]}] ;# MGTYRXP2_230 GTYE4_CHANNEL_X1Y46 / GTYE4_COMMON_X1Y11 from J22.Z16 DP13_M2C_P
set_property -dict {LOC R3  } [get_ports {fmc_dp_m2c_n[13]}] ;# MGTYRXN2_230 GTYE4_CHANNEL_X1Y46 / GTYE4_COMMON_X1Y11 from J22.Z17 DP13_M2C_N
set_property -dict {LOC T7  } [get_ports {fmc_dp_c2m_p[14]}] ;# MGTYTXP1_230 GTYE4_CHANNEL_X1Y45 / GTYE4_COMMON_X1Y11 from J22.M18 DP14_C2M_P
set_property -dict {LOC T6  } [get_ports {fmc_dp_c2m_n[14]}] ;# MGTYTXN1_230 GTYE4_CHANNEL_X1Y45 / GTYE4_COMMON_X1Y11 from J22.M19 DP14_C2M_N
set_property -dict {LOC T2  } [get_ports {fmc_dp_m2c_p[14]}] ;# MGTYRXP1_230 GTYE4_CHANNEL_X1Y45 / GTYE4_COMMON_X1Y11 from J22.Y18 DP14_M2C_P
set_property -dict {LOC T1  } [get_ports {fmc_dp_m2c_n[14]}] ;# MGTYRXN1_230 GTYE4_CHANNEL_X1Y45 / GTYE4_COMMON_X1Y11 from J22.Y19 DP14_M2C_N
set_property -dict {LOC U9  } [get_ports {fmc_dp_c2m_p[15]}] ;# MGTYTXP0_230 GTYE4_CHANNEL_X1Y44 / GTYE4_COMMON_X1Y11 from J22.M22 DP15_C2M_P
set_property -dict {LOC U8  } [get_ports {fmc_dp_c2m_n[15]}] ;# MGTYTXN0_230 GTYE4_CHANNEL_X1Y44 / GTYE4_COMMON_X1Y11 from J22.M23 DP15_C2M_N
set_property -dict {LOC U4  } [get_ports {fmc_dp_m2c_p[15]}] ;# MGTYRXP0_230 GTYE4_CHANNEL_X1Y44 / GTYE4_COMMON_X1Y11 from J22.Y22 DP15_M2C_P
set_property -dict {LOC U3  } [get_ports {fmc_dp_m2c_n[15]}] ;# MGTYRXN0_230 GTYE4_CHANNEL_X1Y44 / GTYE4_COMMON_X1Y11 from J22.Y23 DP15_M2C_N
set_property -dict {LOC T11 } [get_ports fmc_mgt_refclk_3_0_p] ;# MGTREFCLK0P_230 from J9.L8 GBTCLK3_M2C_P
set_property -dict {LOC T10 } [get_ports fmc_mgt_refclk_3_0_n] ;# MGTREFCLK0N_230 from J9.L9 GBTCLK3_M2C_N

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_3_0 [get_ports fmc_mgt_refclk_3_0_p]

set_property -dict {LOC AF7 } [get_ports {fmc_dp_c2m_p[16]}] ;# MGTYTXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8 from J22.M26 DP16_C2M_P
set_property -dict {LOC AF6 } [get_ports {fmc_dp_c2m_n[16]}] ;# MGTYTXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8 from J22.M27 DP16_C2M_N
set_property -dict {LOC AF2 } [get_ports {fmc_dp_m2c_p[16]}] ;# MGTYRXP3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8 from J22.Z32 DP16_M2C_P
set_property -dict {LOC AF1 } [get_ports {fmc_dp_m2c_n[16]}] ;# MGTYRXN3_227 GTYE4_CHANNEL_X1Y35 / GTYE4_COMMON_X1Y8 from J22.Z33 DP16_M2C_N
set_property -dict {LOC AG9 } [get_ports {fmc_dp_c2m_p[17]}] ;# MGTYTXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8 from J22.M30 DP17_C2M_P
set_property -dict {LOC AG8 } [get_ports {fmc_dp_c2m_n[17]}] ;# MGTYTXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8 from J22.M31 DP17_C2M_N
set_property -dict {LOC AG4 } [get_ports {fmc_dp_m2c_p[17]}] ;# MGTYRXP2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8 from J22.Y34 DP17_M2C_P
set_property -dict {LOC AG3 } [get_ports {fmc_dp_m2c_n[17]}] ;# MGTYRXN2_227 GTYE4_CHANNEL_X1Y34 / GTYE4_COMMON_X1Y8 from J22.Y35 DP17_M2C_N
set_property -dict {LOC AH7 } [get_ports {fmc_dp_c2m_p[18]}] ;# MGTYTXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8 from J22.M34 DP18_C2M_P
set_property -dict {LOC AH6 } [get_ports {fmc_dp_c2m_n[18]}] ;# MGTYTXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8 from J22.M35 DP18_C2M_N
set_property -dict {LOC AH2 } [get_ports {fmc_dp_m2c_p[18]}] ;# MGTYRXP1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8 from J22.Z36 DP18_M2C_P
set_property -dict {LOC AH1 } [get_ports {fmc_dp_m2c_n[18]}] ;# MGTYRXN1_227 GTYE4_CHANNEL_X1Y33 / GTYE4_COMMON_X1Y8 from J22.Z37 DP18_M2C_N
set_property -dict {LOC AJ9 } [get_ports {fmc_dp_c2m_p[19]}] ;# MGTYTXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8 from J22.M38 DP19_C2M_P
set_property -dict {LOC AJ8 } [get_ports {fmc_dp_c2m_n[19]}] ;# MGTYTXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8 from J22.M39 DP19_C2M_N
set_property -dict {LOC AJ4 } [get_ports {fmc_dp_m2c_p[19]}] ;# MGTYRXP0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8 from J22.Y38 DP19_M2C_P
set_property -dict {LOC AJ3 } [get_ports {fmc_dp_m2c_n[19]}] ;# MGTYRXN0_227 GTYE4_CHANNEL_X1Y32 / GTYE4_COMMON_X1Y8 from J22.Y39 DP19_M2C_N
set_property -dict {LOC AH11} [get_ports fmc_mgt_refclk_4_0_p] ;# MGTREFCLK0P_227 from J9.L4 GBTCLK4_M2C_P
set_property -dict {LOC AH10} [get_ports fmc_mgt_refclk_4_0_n] ;# MGTREFCLK0N_227 from J9.L5 GBTCLK4_M2C_N
set_property -dict {LOC AF11} [get_ports fmc_mgt_refclk_4_1_p] ;# MGTREFCLK1P_227 from U27.11 OUT4
set_property -dict {LOC AF10} [get_ports fmc_mgt_refclk_4_1_n] ;# MGTREFCLK1N_227 from U27.12 OUT4B

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_4_0 [get_ports fmc_mgt_refclk_4_0_p]
create_clock -period 6.400 -name fmc_mgt_refclk_4_1 [get_ports fmc_mgt_refclk_4_1_p]

set_property -dict {LOC J9  } [get_ports {fmc_dp_c2m_p[20]}] ;# MGTYTXP0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13 from J22.Z8  DP20_C2M_P
set_property -dict {LOC J8  } [get_ports {fmc_dp_c2m_n[20]}] ;# MGTYTXN0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13 from J22.Z9  DP20_C2M_N
set_property -dict {LOC J4  } [get_ports {fmc_dp_m2c_p[20]}] ;# MGTYRXP0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13 from J22.M14 DP20_M2C_P
set_property -dict {LOC J3  } [get_ports {fmc_dp_m2c_n[20]}] ;# MGTYRXN0_232 GTYE4_CHANNEL_X1Y52 / GTYE4_COMMON_X1Y13 from J22.M15 DP20_M2C_N
set_property -dict {LOC H7  } [get_ports {fmc_dp_c2m_p[21]}] ;# MGTYTXP1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13 from J22.Y6  DP21_C2M_P
set_property -dict {LOC H6  } [get_ports {fmc_dp_c2m_n[21]}] ;# MGTYTXN1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13 from J22.Y7  DP21_C2M_N
set_property -dict {LOC H2  } [get_ports {fmc_dp_m2c_p[21]}] ;# MGTYRXP1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13 from J22.M10 DP21_M2C_P
set_property -dict {LOC H1  } [get_ports {fmc_dp_m2c_n[21]}] ;# MGTYRXN1_232 GTYE4_CHANNEL_X1Y53 / GTYE4_COMMON_X1Y13 from J22.M11 DP21_M2C_N
set_property -dict {LOC G9  } [get_ports {fmc_dp_c2m_p[22]}] ;# MGTYTXP2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13 from J22.Z4  DP22_C2M_P
set_property -dict {LOC G8  } [get_ports {fmc_dp_c2m_n[22]}] ;# MGTYTXN2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13 from J22.Z5  DP22_C2M_N
set_property -dict {LOC G4  } [get_ports {fmc_dp_m2c_p[22]}] ;# MGTYRXP2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13 from J22.M6  DP22_M2C_P
set_property -dict {LOC G3  } [get_ports {fmc_dp_m2c_n[22]}] ;# MGTYRXN2_232 GTYE4_CHANNEL_X1Y54 / GTYE4_COMMON_X1Y13 from J22.M7  DP22_M2C_N
set_property -dict {LOC F7  } [get_ports {fmc_dp_c2m_p[23]}] ;# MGTYTXP3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13 from J22.Y2  DP23_C2M_P
set_property -dict {LOC F6  } [get_ports {fmc_dp_c2m_n[23]}] ;# MGTYTXN3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13 from J22.Y3  DP23_C2M_N
set_property -dict {LOC F2  } [get_ports {fmc_dp_m2c_p[23]}] ;# MGTYRXP3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13 from J22.M2  DP23_M2C_P
set_property -dict {LOC F1  } [get_ports {fmc_dp_m2c_n[23]}] ;# MGTYRXN3_232 GTYE4_CHANNEL_X1Y55 / GTYE4_COMMON_X1Y13 from J22.M3  DP23_M2C_N
set_property -dict {LOC H11 } [get_ports fmc_mgt_refclk_5_0_p] ;# MGTREFCLK0P_232 from J9.Z20 GBTCLK5_M2C_P
set_property -dict {LOC H10 } [get_ports fmc_mgt_refclk_5_0_n] ;# MGTREFCLK0N_232 from J9.Z21 GBTCLK5_M2C_N

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_5_0 [get_ports fmc_mgt_refclk_5_0_p]
