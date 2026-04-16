# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# FMC HPC1 J2
set_property -dict {LOC AY9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[0]}]  ;# J2.G9  LA00_P_CC
set_property -dict {LOC BA9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[0]}]  ;# J2.G10 LA00_N_CC
set_property -dict {LOC BF10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[1]}]  ;# J2.D8  LA01_P_CC
set_property -dict {LOC BF9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[1]}]  ;# J2.D9  LA01_N_CC
set_property -dict {LOC BC11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[2]}]  ;# J2.H7  LA02_P
set_property -dict {LOC BD11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[2]}]  ;# J2.H8  LA02_N
set_property -dict {LOC BD12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[3]}]  ;# J2.G12 LA03_P
set_property -dict {LOC BE12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[3]}]  ;# J2.G13 LA03_N
set_property -dict {LOC BD12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[4]}]  ;# J2.H10 LA04_P
set_property -dict {LOC BF11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[4]}]  ;# J2.H11 LA04_N
set_property -dict {LOC BE14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[5]}]  ;# J2.D11 LA05_P
set_property -dict {LOC BF14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[5]}]  ;# J2.D12 LA05_N
set_property -dict {LOC BD13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[6]}]  ;# J2.C10 LA06_P
set_property -dict {LOC BE13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[6]}]  ;# J2.C11 LA06_N
set_property -dict {LOC BC15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[7]}]  ;# J2.H13 LA07_P
set_property -dict {LOC BD15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[7]}]  ;# J2.H14 LA07_N
set_property -dict {LOC BE15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[8]}]  ;# J2.G12 LA08_P
set_property -dict {LOC BF15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[8]}]  ;# J2.G13 LA08_N
set_property -dict {LOC BA14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[9]}]  ;# J2.D14 LA09_P
set_property -dict {LOC BB14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[9]}]  ;# J2.D15 LA09_N
set_property -dict {LOC BB13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[10]}] ;# J2.C14 LA10_P
set_property -dict {LOC BB12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[10]}] ;# J2.C15 LA10_N
set_property -dict {LOC BA16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[11]}] ;# J2.H16 LA11_P
set_property -dict {LOC BA15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[11]}] ;# J2.H17 LA11_N
set_property -dict {LOC BC14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[12]}] ;# J2.G15 LA12_P
set_property -dict {LOC BC13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[12]}] ;# J2.G16 LA12_N
set_property -dict {LOC AY8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[13]}] ;# J2.D17 LA13_P
set_property -dict {LOC AY7  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[13]}] ;# J2.D18 LA13_N
set_property -dict {LOC AW8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[14]}] ;# J2.C18 LA14_P
set_property -dict {LOC AW7  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[14]}] ;# J2.C19 LA14_N
set_property -dict {LOC BB16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[15]}] ;# J2.H19 LA15_P
set_property -dict {LOC BC16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[15]}] ;# J2.H20 LA15_N
set_property -dict {LOC AV9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[16]}] ;# J2.G18 LA16_P
set_property -dict {LOC AB8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[16]}] ;# J2.G19 LA16_N
set_property -dict {LOC AR14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[17]}] ;# J2.D20 LA17_P_CC
set_property -dict {LOC AT14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[17]}] ;# J2.D21 LA17_N_CC
set_property -dict {LOC AP12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[18]}] ;# J2.C22 LA18_P_CC
set_property -dict {LOC AR12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[18]}] ;# J2.C23 LA18_N_CC
set_property -dict {LOC AW12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[19]}] ;# J2.H22 LA19_P
set_property -dict {LOC AY12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[19]}] ;# J2.H23 LA19_N
set_property -dict {LOC AW11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[20]}] ;# J2.G21 LA20_P
set_property -dict {LOC AY10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[20]}] ;# J2.G22 LA20_N
set_property -dict {LOC AU11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[21]}] ;# J2.H25 LA21_P
set_property -dict {LOC AV11 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[21]}] ;# J2.H26 LA21_N
set_property -dict {LOC AW13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[22]}] ;# J2.G24 LA22_P
set_property -dict {LOC AY13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[22]}] ;# J2.G25 LA22_N
set_property -dict {LOC AN16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[23]}] ;# J2.D23 LA23_P
set_property -dict {LOC AP16 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[23]}] ;# J2.D24 LA23_N
set_property -dict {LOC AP13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[24]}] ;# J2.H28 LA24_P
set_property -dict {LOC AR13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[24]}] ;# J2.H29 LA24_N
set_property -dict {LOC AT12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[25]}] ;# J2.G27 LA25_P
set_property -dict {LOC AU12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[25]}] ;# J2.G28 LA25_N
set_property -dict {LOC AK15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[26]}] ;# J2.D26 LA26_P
set_property -dict {LOC AL15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[26]}] ;# J2.D27 LA26_N
set_property -dict {LOC AL14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[27]}] ;# J2.C26 LA27_P
set_property -dict {LOC AM14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[27]}] ;# J2.C27 LA27_N
set_property -dict {LOC AV10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[28]}] ;# J2.H31 LA28_P
set_property -dict {LOC AW10 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[28]}] ;# J2.H32 LA28_N
set_property -dict {LOC AN15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[29]}] ;# J2.G30 LA29_P
set_property -dict {LOC AP15 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[29]}] ;# J2.G31 LA29_N
set_property -dict {LOC AK12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[30]}] ;# J2.H34 LA30_P
set_property -dict {LOC AL12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[30]}] ;# J2.H35 LA30_N
set_property -dict {LOC AM13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[31]}] ;# J2.G33 LA31_P
set_property -dict {LOC AM12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[31]}] ;# J2.G34 LA31_N
set_property -dict {LOC AJ13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[32]}] ;# J2.H37 LA32_P
set_property -dict {LOC AJ12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[32]}] ;# J2.H38 LA32_N
set_property -dict {LOC AK14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_p[33]}] ;# J2.G36 LA33_P
set_property -dict {LOC AK13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_la_n[33]}] ;# J2.G37 LA33_N

set_property -dict {LOC BC9  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_clk0_m2c_p}] ;# J2.H4 CLK0_M2C_P
set_property -dict {LOC BC8  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_clk0_m2c_n}] ;# J2.H5 CLK0_M2C_N
set_property -dict {LOC AV14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_clk1_m2c_p}] ;# J2.G2 CLK1_M2C_P
set_property -dict {LOC AV13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_hpc1_clk1_m2c_n}] ;# J2.G3 CLK1_M2C_N

set_property -dict {LOC BA7  IOSTANDARD LVCMOS18} [get_ports {fmc_hpc1_pg_m2c}]      ;# J2.F1 PG_M2C
set_property -dict {LOC BB7  IOSTANDARD LVCMOS18} [get_ports {fmc_hpc1_prsnt_m2c_l}] ;# J2.H2 PRSNT_M2C_L
