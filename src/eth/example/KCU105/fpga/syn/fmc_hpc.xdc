# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e
# FMC HPC J22
set_property -dict {LOC H11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[0]"]  ;# J22.G9  LA00_P_CC
set_property -dict {LOC G11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[0]"]  ;# J22.G10 LA00_N_CC
set_property -dict {LOC G9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[1]"]  ;# J22.D8  LA01_P_CC
set_property -dict {LOC F9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[1]"]  ;# J22.D9  LA01_N_CC
set_property -dict {LOC K10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[2]"]  ;# J22.H7  LA02_P
set_property -dict {LOC J10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[2]"]  ;# J22.H8  LA02_N
set_property -dict {LOC A13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[3]"]  ;# J22.G12 LA03_P
set_property -dict {LOC A12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[3]"]  ;# J22.G13 LA03_N
set_property -dict {LOC L12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[4]"]  ;# J22.H10 LA04_P
set_property -dict {LOC K12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[4]"]  ;# J22.H11 LA04_N
set_property -dict {LOC L13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[5]"]  ;# J22.D11 LA05_P
set_property -dict {LOC K13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[5]"]  ;# J22.D12 LA05_N
set_property -dict {LOC D13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[6]"]  ;# J22.C10 LA06_P
set_property -dict {LOC C13  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[6]"]  ;# J22.C11 LA06_N
set_property -dict {LOC F8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[7]"]  ;# J22.H13 LA07_P
set_property -dict {LOC E8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[7]"]  ;# J22.H14 LA07_N
set_property -dict {LOC J8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[8]"]  ;# J22.G12 LA08_P
set_property -dict {LOC H8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[8]"]  ;# J22.G13 LA08_N
set_property -dict {LOC J9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[9]"]  ;# J22.D14 LA09_P
set_property -dict {LOC H9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[9]"]  ;# J22.D15 LA09_N
set_property -dict {LOC L8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[10]"] ;# J22.C14 LA10_P
set_property -dict {LOC K8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[10]"] ;# J22.C15 LA10_N
set_property -dict {LOC K11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[11]"] ;# J22.H16 LA11_P
set_property -dict {LOC J11  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[11]"] ;# J22.H17 LA11_N
set_property -dict {LOC E10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[12]"] ;# J22.G15 LA12_P
set_property -dict {LOC D10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[12]"] ;# J22.G16 LA12_N
set_property -dict {LOC D9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[13]"] ;# J22.D17 LA13_P
set_property -dict {LOC C9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[13]"] ;# J22.D18 LA13_N
set_property -dict {LOC B10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[14]"] ;# J22.C18 LA14_P
set_property -dict {LOC A10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[14]"] ;# J22.C19 LA14_N
set_property -dict {LOC D8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[15]"] ;# J22.H19 LA15_P
set_property -dict {LOC C8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[15]"] ;# J22.H20 LA15_N
set_property -dict {LOC B9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[16]"] ;# J22.G18 LA16_P
set_property -dict {LOC A9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[16]"] ;# J22.G19 LA16_N
set_property -dict {LOC D24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[17]"] ;# J22.D20 LA17_P_CC
set_property -dict {LOC C24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[17]"] ;# J22.D21 LA17_N_CC
set_property -dict {LOC E22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[18]"] ;# J22.C22 LA18_P_CC
set_property -dict {LOC E23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[18]"] ;# J22.C23 LA18_N_CC
set_property -dict {LOC C21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[19]"] ;# J22.H22 LA19_P
set_property -dict {LOC C22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[19]"] ;# J22.H23 LA19_N
set_property -dict {LOC B24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[20]"] ;# J22.G21 LA20_P
set_property -dict {LOC A24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[20]"] ;# J22.G22 LA20_N
set_property -dict {LOC F23  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[21]"] ;# J22.H25 LA21_P
set_property -dict {LOC F24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[21]"] ;# J22.H26 LA21_N
set_property -dict {LOC G24  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[22]"] ;# J22.G24 LA22_P
set_property -dict {LOC F25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[22]"] ;# J22.G25 LA22_N
set_property -dict {LOC G22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[23]"] ;# J22.D23 LA23_P
set_property -dict {LOC F22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[23]"] ;# J22.D24 LA23_N
set_property -dict {LOC E20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[24]"] ;# J22.H28 LA24_P
set_property -dict {LOC E21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[24]"] ;# J22.H29 LA24_N
set_property -dict {LOC D20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[25]"] ;# J22.G27 LA25_P
set_property -dict {LOC D21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[25]"] ;# J22.G28 LA25_N
set_property -dict {LOC G20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[26]"] ;# J22.D26 LA26_P
set_property -dict {LOC F20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[26]"] ;# J22.D27 LA26_N
set_property -dict {LOC H21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[27]"] ;# J22.C26 LA27_P
set_property -dict {LOC G21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[27]"] ;# J22.C27 LA27_N
set_property -dict {LOC B21  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[28]"] ;# J22.H31 LA28_P
set_property -dict {LOC B22  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[28]"] ;# J22.H32 LA28_N
set_property -dict {LOC B20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[29]"] ;# J22.G30 LA29_P
set_property -dict {LOC A20  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[29]"] ;# J22.G31 LA29_N
set_property -dict {LOC C26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[30]"] ;# J22.H34 LA30_P
set_property -dict {LOC B26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[30]"] ;# J22.H35 LA30_N
set_property -dict {LOC B25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[31]"] ;# J22.G33 LA31_P
set_property -dict {LOC A25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[31]"] ;# J22.G34 LA31_N
set_property -dict {LOC E26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[32]"] ;# J22.H37 LA32_P
set_property -dict {LOC D26  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[32]"] ;# J22.H38 LA32_N
set_property -dict {LOC A27  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_p[33]"] ;# J22.G36 LA33_P
set_property -dict {LOC A28  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_la_n[33]"] ;# J22.G37 LA33_N

set_property -dict {LOC G17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[0]"]  ;# J22.F4  HA00_P_CC
set_property -dict {LOC G16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[0]"]  ;# J22.F5  HA00_N_CC
set_property -dict {LOC E16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[1]"]  ;# J22.E2  HA01_P_CC
set_property -dict {LOC D16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[1]"]  ;# J22.E3  HA01_N_CC
set_property -dict {LOC H19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[2]"]  ;# J22.K7  HA02_P
set_property -dict {LOC H18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[2]"]  ;# J22.K8  HA02_N
set_property -dict {LOC G15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[3]"]  ;# J22.J6  HA03_P
set_property -dict {LOC G14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[3]"]  ;# J22.J7  HA03_N
set_property -dict {LOC G19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[4]"]  ;# J22.F7  HA04_P
set_property -dict {LOC F19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[4]"]  ;# J22.F8  HA04_N
set_property -dict {LOC J15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[5]"]  ;# J22.E6  HA05_P
set_property -dict {LOC J14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[5]"]  ;# J22.E7  HA05_N
set_property -dict {LOC L15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[6]"]  ;# J22.K10 HA06_P
set_property -dict {LOC K15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[6]"]  ;# J22.K11 HA06_N
set_property -dict {LOC L19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[7]"]  ;# J22.J9  HA07_P
set_property -dict {LOC L18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[7]"]  ;# J22.J10 HA07_N
set_property -dict {LOC K18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[8]"]  ;# J22.F10 HA08_P
set_property -dict {LOC K17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[8]"]  ;# J22.F11 HA08_N
set_property -dict {LOC F18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[9]"]  ;# J22.E9  HA09_P
set_property -dict {LOC F17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[9]"]  ;# J22.E10 HA09_N
set_property -dict {LOC H17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[10]"] ;# J22.K13 HA10_P
set_property -dict {LOC H16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[10]"] ;# J22.K14 HA10_N
set_property -dict {LOC J19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[11]"] ;# J22.J12 HA11_P
set_property -dict {LOC J18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[11]"] ;# J22.J13 HA11_N
set_property -dict {LOC K16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[12]"] ;# J22.F13 HA12_P
set_property -dict {LOC J16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[12]"] ;# J22.F14 HA12_N
set_property -dict {LOC B14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[13]"] ;# J22.E12 HA13_P
set_property -dict {LOC A14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[13]"] ;# J22.E13 HA13_N
set_property -dict {LOC F15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[14]"] ;# J22.J15 HA14_P
set_property -dict {LOC F14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[14]"] ;# J22.J16 HA14_N
set_property -dict {LOC D14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[15]"] ;# J22.F14 HA15_P
set_property -dict {LOC C14  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[15]"] ;# J22.F16 HA15_N
set_property -dict {LOC A19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[16]"] ;# J22.E15 HA16_P
set_property -dict {LOC A18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[16]"] ;# J22.E16 HA16_N
set_property -dict {LOC E18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[17]"] ;# J22.K16 HA17_P_CC
set_property -dict {LOC E17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[17]"] ;# J22.K17 HA17_N_CC
set_property -dict {LOC B17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[18]"] ;# J22.J18 HA18_P_CC
set_property -dict {LOC B16  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[18]"] ;# J22.J19 HA18_N_CC
set_property -dict {LOC D19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[19]"] ;# J22.F19 HA19_P
set_property -dict {LOC D18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[19]"] ;# J22.F20 HA19_N
set_property -dict {LOC C19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[20]"] ;# J22.E18 HA20_P
set_property -dict {LOC B19  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[20]"] ;# J22.E19 HA20_N
set_property -dict {LOC E15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[21]"] ;# J22.K19 HA21_P
set_property -dict {LOC D15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[21]"] ;# J22.K20 HA21_N
set_property -dict {LOC C18  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[22]"] ;# J22.J21 HA22_P
set_property -dict {LOC C17  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[22]"] ;# J22.J22 HA22_N
set_property -dict {LOC B15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_p[23]"] ;# J22.K22 HA23_P
set_property -dict {LOC A15  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_ha_n[23]"] ;# J22.K23 HA23_N

set_property -dict {LOC H12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk0_m2c_p"] ;# J22.H4 CLK0_M2C_P
set_property -dict {LOC G12  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk0_m2c_n"] ;# J22.H5 CLK0_M2C_N
set_property -dict {LOC E25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk1_m2c_p"] ;# J22.G2 CLK1_M2C_P
set_property -dict {LOC D25  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports "fmc_hpc_clk1_m2c_n"] ;# J22.G3 CLK1_M2C_N

set_property -dict {LOC L27  IOSTANDARD LVCMOS18} [get_ports {fmc_hpc_pg_m2c}]      ;# J22.F1 PG_M2C
set_property -dict {LOC H24  IOSTANDARD LVCMOS18} [get_ports {fmc_hpc_prsnt_m2c_l}] ;# J22.H2 PRSNT_M2C_L

set_property -dict {LOC F6} [get_ports {fmc_hpc_dp_c2m_p[0]}] ;# MGTHTXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C2  DP0_C2M_P
set_property -dict {LOC F5} [get_ports {fmc_hpc_dp_c2m_n[0]}] ;# MGTHTXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C3  DP0_C2M_N
set_property -dict {LOC E4} [get_ports {fmc_hpc_dp_m2c_p[0]}] ;# MGTHRXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C6  DP0_M2C_P
set_property -dict {LOC E3} [get_ports {fmc_hpc_dp_m2c_n[0]}] ;# MGTHRXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4 from J22.C7  DP0_M2C_N
set_property -dict {LOC D6} [get_ports {fmc_hpc_dp_c2m_p[1]}] ;# MGTHTXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A22 DP1_C2M_P
set_property -dict {LOC D5} [get_ports {fmc_hpc_dp_c2m_n[1]}] ;# MGTHTXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A23 DP1_C2M_N
set_property -dict {LOC D2} [get_ports {fmc_hpc_dp_m2c_p[1]}] ;# MGTHRXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A2  DP1_M2C_P
set_property -dict {LOC D1} [get_ports {fmc_hpc_dp_m2c_n[1]}] ;# MGTHRXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4 from J22.A3  DP1_M2C_N
set_property -dict {LOC C4} [get_ports {fmc_hpc_dp_c2m_p[2]}] ;# MGTHTXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A26 DP2_C2M_P
set_property -dict {LOC C3} [get_ports {fmc_hpc_dp_c2m_n[2]}] ;# MGTHTXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A27 DP2_C2M_N
set_property -dict {LOC B2} [get_ports {fmc_hpc_dp_m2c_p[2]}] ;# MGTHRXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A6  DP2_M2C_P
set_property -dict {LOC B1} [get_ports {fmc_hpc_dp_m2c_n[2]}] ;# MGTHRXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4 from J22.A7  DP2_M2C_N
set_property -dict {LOC B6} [get_ports {fmc_hpc_dp_c2m_p[3]}] ;# MGTHTXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A30 DP3_C2M_P
set_property -dict {LOC B5} [get_ports {fmc_hpc_dp_c2m_n[3]}] ;# MGTHTXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A31 DP3_C2M_N
set_property -dict {LOC A4} [get_ports {fmc_hpc_dp_m2c_p[3]}] ;# MGTHRXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A10 DP3_M2C_P
set_property -dict {LOC A3} [get_ports {fmc_hpc_dp_m2c_n[3]}] ;# MGTHRXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4 from J22.A11 DP3_M2C_N
set_property -dict {LOC K6  } [get_ports fmc_hpc_mgt_refclk_0_p] ;# MGTREFCLK0P_228 from J22.D4 GBTCLK0_M2C_P
set_property -dict {LOC K5  } [get_ports fmc_hpc_mgt_refclk_0_n] ;# MGTREFCLK0N_228 from J22.D5 GBTCLK0_M2C_N
set_property -dict {LOC H6  } [get_ports fmc_hpc_mgt_refclk_1_p] ;# MGTREFCLK1P_228 from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC H5  } [get_ports fmc_hpc_mgt_refclk_1_n] ;# MGTREFCLK1N_228 from J22.B21 GBTCLK1_M2C_N

set_property -dict {LOC N4} [get_ports {fmc_hpc_dp_c2m_p[4]}] ;# MGTHTXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A34 DP4_C2M_P
set_property -dict {LOC N3} [get_ports {fmc_hpc_dp_c2m_n[4]}] ;# MGTHTXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A35 DP4_C2M_N
set_property -dict {LOC M2} [get_ports {fmc_hpc_dp_m2c_p[4]}] ;# MGTHRXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A14 DP4_M2C_P
set_property -dict {LOC M1} [get_ports {fmc_hpc_dp_m2c_n[4]}] ;# MGTHRXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3 from J22.A15 DP4_M2C_N
set_property -dict {LOC J4} [get_ports {fmc_hpc_dp_c2m_p[5]}] ;# MGTHTXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B36 DP5_C2M_P
set_property -dict {LOC J3} [get_ports {fmc_hpc_dp_c2m_n[5]}] ;# MGTHTXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B37 DP5_C2M_N
set_property -dict {LOC H2} [get_ports {fmc_hpc_dp_m2c_p[5]}] ;# MGTHRXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B16 DP5_M2C_P
set_property -dict {LOC H1} [get_ports {fmc_hpc_dp_m2c_n[5]}] ;# MGTHRXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3 from J22.B17 DP5_M2C_N
set_property -dict {LOC L4} [get_ports {fmc_hpc_dp_c2m_p[6]}] ;# MGTHTXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A38 DP6_C2M_P
set_property -dict {LOC L3} [get_ports {fmc_hpc_dp_c2m_n[6]}] ;# MGTHTXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A39 DP6_C2M_N
set_property -dict {LOC K2} [get_ports {fmc_hpc_dp_m2c_p[6]}] ;# MGTHRXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A18 DP6_M2C_P
set_property -dict {LOC K1} [get_ports {fmc_hpc_dp_m2c_n[6]}] ;# MGTHRXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3 from J22.A19 DP6_M2C_N
set_property -dict {LOC G4} [get_ports {fmc_hpc_dp_c2m_p[7]}] ;# MGTHTXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B32 DP7_C2M_P
set_property -dict {LOC G3} [get_ports {fmc_hpc_dp_c2m_n[7]}] ;# MGTHTXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B33 DP7_C2M_N
set_property -dict {LOC F2} [get_ports {fmc_hpc_dp_m2c_p[7]}] ;# MGTHRXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B12 DP7_M2C_P
set_property -dict {LOC F1} [get_ports {fmc_hpc_dp_m2c_n[7]}] ;# MGTHRXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3 from J22.B13 DP7_M2C_N

# reference clock
create_clock -period 6.400 -name fmc_hpc_mgt_refclk_0 [get_ports fmc_hpc_mgt_refclk_0_p]
create_clock -period 6.400 -name fmc_hpc_mgt_refclk_1 [get_ports fmc_hpc_mgt_refclk_1_p]
