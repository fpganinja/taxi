# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# FMC+ HSPC J22
set_property -dict {LOC AL35 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[0]}]  ;# J22.G9  LA00_P_CC
set_property -dict {LOC AL36 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[0]}]  ;# J22.G10 LA00_N_CC
set_property -dict {LOC AL30 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[1]}]  ;# J22.D8  LA01_P_CC
set_property -dict {LOC AL31 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[1]}]  ;# J22.D9  LA01_N_CC
set_property -dict {LOC AJ32 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[2]}]  ;# J22.H7  LA02_P
set_property -dict {LOC AK32 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[2]}]  ;# J22.H8  LA02_N
set_property -dict {LOC AT39 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[3]}]  ;# J22.G12 LA03_P
set_property -dict {LOC AT40 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[3]}]  ;# J22.G13 LA03_N
set_property -dict {LOC AR37 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[4]}]  ;# J22.H10 LA04_P
set_property -dict {LOC AT37 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[4]}]  ;# J22.H11 LA04_N
set_property -dict {LOC AP38 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[5]}]  ;# J22.D11 LA05_P
set_property -dict {LOC AR38 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[5]}]  ;# J22.D12 LA05_N
set_property -dict {LOC AT35 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[6]}]  ;# J22.C10 LA06_P
set_property -dict {LOC AT36 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[6]}]  ;# J22.C11 LA06_N
set_property -dict {LOC AP36 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[7]}]  ;# J22.H13 LA07_P
set_property -dict {LOC AP37 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[7]}]  ;# J22.H14 LA07_N
set_property -dict {LOC AK29 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[8]}]  ;# J22.G12 LA08_P
set_property -dict {LOC AK30 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[8]}]  ;# J22.G13 LA08_N
set_property -dict {LOC AJ33 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[9]}]  ;# J22.D14 LA09_P
set_property -dict {LOC AK33 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[9]}]  ;# J22.D15 LA09_N
set_property -dict {LOC AP35 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[10]}] ;# J22.C14 LA10_P
set_property -dict {LOC AR35 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[10]}] ;# J22.C15 LA10_N
set_property -dict {LOC AJ30 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[11]}] ;# J22.H16 LA11_P
set_property -dict {LOC AJ31 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[11]}] ;# J22.H17 LA11_N
set_property -dict {LOC AH33 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[12]}] ;# J22.G15 LA12_P
set_property -dict {LOC AH34 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[12]}] ;# J22.G16 LA12_N
set_property -dict {LOC AJ35 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[13]}] ;# J22.D17 LA13_P
set_property -dict {LOC AJ36 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[13]}] ;# J22.D18 LA13_N
set_property -dict {LOC AG31 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[14]}] ;# J22.C18 LA14_P
set_property -dict {LOC AH31 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[14]}] ;# J22.C19 LA14_N
set_property -dict {LOC AG32 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[15]}] ;# J22.H19 LA15_P
set_property -dict {LOC AG33 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[15]}] ;# J22.H20 LA15_N
set_property -dict {LOC AG34 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[16]}] ;# J22.G18 LA16_P
set_property -dict {LOC AH35 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[16]}] ;# J22.G19 LA16_N
set_property -dict {LOC R34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[17]}] ;# J22.D20 LA17_P_CC
set_property -dict {LOC P34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[17]}] ;# J22.D21 LA17_N_CC
set_property -dict {LOC R31  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[18]}] ;# J22.C22 LA18_P_CC
set_property -dict {LOC P31  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[18]}] ;# J22.C23 LA18_N_CC
set_property -dict {LOC N33  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[19]}] ;# J22.H22 LA19_P
set_property -dict {LOC M33  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[19]}] ;# J22.H23 LA19_N
set_property -dict {LOC N32  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[20]}] ;# J22.G21 LA20_P
set_property -dict {LOC M32  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[20]}] ;# J22.G22 LA20_N
set_property -dict {LOC M35  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[21]}] ;# J22.H25 LA21_P
set_property -dict {LOC L35  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[21]}] ;# J22.H26 LA21_N
set_property -dict {LOC N34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[22]}] ;# J22.G24 LA22_P
set_property -dict {LOC N35  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[22]}] ;# J22.G25 LA22_N
set_property -dict {LOC Y32  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[23]}] ;# J22.D23 LA23_P
set_property -dict {LOC W32  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[23]}] ;# J22.D24 LA23_N
set_property -dict {LOC T34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[24]}] ;# J22.H28 LA24_P
set_property -dict {LOC T35  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[24]}] ;# J22.H29 LA24_N
set_property -dict {LOC Y34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[25]}] ;# J22.G27 LA25_P
set_property -dict {LOC W34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[25]}] ;# J22.G28 LA25_N
set_property -dict {LOC V32  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[26]}] ;# J22.D26 LA26_P
set_property -dict {LOC U33  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[26]}] ;# J22.D27 LA26_N
set_property -dict {LOC V33  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[27]}] ;# J22.C26 LA27_P
set_property -dict {LOC V34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[27]}] ;# J22.C27 LA27_N
set_property -dict {LOC M36  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[28]}] ;# J22.H31 LA28_P
set_property -dict {LOC L36  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[28]}] ;# J22.H32 LA28_N
set_property -dict {LOC U35  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[29]}] ;# J22.G30 LA29_P
set_property -dict {LOC T36  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[29]}] ;# J22.G31 LA29_N
set_property -dict {LOC N38  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[30]}] ;# J22.H34 LA30_P
set_property -dict {LOC M38  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[30]}] ;# J22.H35 LA30_N
set_property -dict {LOC P37  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[31]}] ;# J22.G33 LA31_P
set_property -dict {LOC N37  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[31]}] ;# J22.G34 LA31_N
set_property -dict {LOC L33  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[32]}] ;# J22.H37 LA32_P
set_property -dict {LOC K33  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[32]}] ;# J22.H38 LA32_N
set_property -dict {LOC L34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_p[33]}] ;# J22.G36 LA33_P
set_property -dict {LOC K34  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_la_n[33]}] ;# J22.G37 LA33_N

set_property -dict {LOC N14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[0]}]  ;# J22.F4  HA00_P_CC
set_property -dict {LOC N13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[0]}]  ;# J22.F5  HA00_N_CC
set_property -dict {LOC V15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[1]}]  ;# J22.E2  HA01_P_CC
set_property -dict {LOC U15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[1]}]  ;# J22.E3  HA01_N_CC
set_property -dict {LOC AA12 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[2]}]  ;# J22.K7  HA02_P
set_property -dict {LOC Y12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[2]}]  ;# J22.K8  HA02_N
set_property -dict {LOC W12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[3]}]  ;# J22.J6  HA03_P
set_property -dict {LOC V12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[3]}]  ;# J22.J7  HA03_N
set_property -dict {LOC AA13 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[4]}]  ;# J22.F7  HA04_P
set_property -dict {LOC Y13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[4]}]  ;# J22.F8  HA04_N
set_property -dict {LOC R14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[5]}]  ;# J22.E6  HA05_P
set_property -dict {LOC P14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[5]}]  ;# J22.E7  HA05_N
set_property -dict {LOC U13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[6]}]  ;# J22.K10 HA06_P
set_property -dict {LOC T13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[6]}]  ;# J22.K11 HA06_N
set_property -dict {LOC AA14 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[7]}]  ;# J22.J9  HA07_P
set_property -dict {LOC Y14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[7]}]  ;# J22.J10 HA07_N
set_property -dict {LOC U11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[8]}]  ;# J22.F10 HA08_P
set_property -dict {LOC T11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[8]}]  ;# J22.F11 HA08_N
set_property -dict {LOC W14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[9]}]  ;# J22.E9  HA09_P
set_property -dict {LOC V14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[9]}]  ;# J22.E10 HA09_N
set_property -dict {LOC V16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[10]}] ;# J22.K13 HA10_P
set_property -dict {LOC U16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[10]}] ;# J22.K14 HA10_N
set_property -dict {LOC R12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[11]}] ;# J22.J12 HA11_P
set_property -dict {LOC P12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[11]}] ;# J22.J13 HA11_N
set_property -dict {LOC T16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[12]}] ;# J22.F13 HA12_P
set_property -dict {LOC T15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[12]}] ;# J22.F14 HA12_N
set_property -dict {LOC V13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[13]}] ;# J22.E12 HA13_P
set_property -dict {LOC U12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[13]}] ;# J22.E13 HA13_N
set_property -dict {LOC M11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[14]}] ;# J22.J15 HA14_P
set_property -dict {LOC L11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[14]}] ;# J22.J16 HA14_N
set_property -dict {LOC M13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[15]}] ;# J22.F14 HA15_P
set_property -dict {LOC M12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[15]}] ;# J22.F16 HA15_N
set_property -dict {LOC T14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[16]}] ;# J22.E15 HA16_P
set_property -dict {LOC R13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[16]}] ;# J22.E16 HA16_N
set_property -dict {LOC R11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[17]}] ;# J22.K16 HA17_P_CC
set_property -dict {LOC P11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[17]}] ;# J22.K17 HA17_N_CC
set_property -dict {LOC P15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[18]}] ;# J22.J18 HA18_P_CC
set_property -dict {LOC N15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[18]}] ;# J22.J19 HA18_N_CC
set_property -dict {LOC L14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[19]}] ;# J22.F19 HA19_P
set_property -dict {LOC L13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[19]}] ;# J22.F20 HA19_N
set_property -dict {LOC M15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[20]}] ;# J22.E18 HA20_P
set_property -dict {LOC L15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[20]}] ;# J22.E19 HA20_N
set_property -dict {LOC K14  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[21]}] ;# J22.K19 HA21_P
set_property -dict {LOC K13  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[21]}] ;# J22.K20 HA21_N
set_property -dict {LOC K12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[22]}] ;# J22.J21 HA22_P
set_property -dict {LOC J12  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[22]}] ;# J22.J22 HA22_N
set_property -dict {LOC K11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_p[23]}] ;# J22.K22 HA23_P
set_property -dict {LOC J11  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_ha_n[23]}] ;# J22.K23 HA23_N

set_property -dict {LOC AL32 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_clk0_m2c_p}] ;# J22.H4 CLK0_M2C_P
set_property -dict {LOC AM32 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_clk0_m2c_n}] ;# J22.H5 CLK0_M2C_N
set_property -dict {LOC P35  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_clk1_m2c_p}] ;# J22.G2 CLK1_M2C_P
set_property -dict {LOC P36  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_clk1_m2c_n}] ;# J22.G3 CLK1_M2C_N

set_property -dict {LOC AN33 IOSTANDARD LVDS               } [get_ports {fmcp_hspc_refclk_c2m_p}] ;# J22.L20 REFCLK_C2M_P
set_property -dict {LOC AP33 IOSTANDARD LVDS               } [get_ports {fmcp_hspc_refclk_c2m_n}] ;# J22.L21 REFCLK_C2M_N
set_property -dict {LOC AK34 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_refclk_m2c_p}] ;# J22.L24 REFCLK_M2C_P
set_property -dict {LOC AL34 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_refclk_m2c_n}] ;# J22.L25 REFCLK_M2C_N
set_property -dict {LOC AN34 IOSTANDARD LVDS               } [get_ports {fmcp_hspc_sync_c2m_p}]   ;# J22.L16 SYNC_C2M_P
set_property -dict {LOC AN35 IOSTANDARD LVDS               } [get_ports {fmcp_hspc_sync_c2m_n}]   ;# J22.L17 SYNC_C2M_N
set_property -dict {LOC AM36 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_sync_m2c_p}]   ;# J22.L28 SYNC_M2C_P
set_property -dict {LOC AN36 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmcp_hspc_sync_m2c_n}]   ;# J22.L29 SYNC_M2C_N

set_property -dict {LOC AL36 IOSTANDARD LVCMOS18} [get_ports {fmcp_hspc_pg_m2c}]        ;# J22.F1 PG_M2C
set_property -dict {LOC AM33 IOSTANDARD LVCMOS18} [get_ports {fmcp_hspc_h_prsnt_m2c_l}] ;# J22.H2 PRSNT_M2C_L
set_property -dict {LOC AM29 IOSTANDARD LVCMOS18} [get_ports {fmcp_hspc_z_prsnt_m2c_l}] ;# J22.Z1 HSPC_PRSNT_M2C_L

set_property -dict {LOC AT42} [get_ports {fmcp_hspc_dp_c2m_p[0]}]  ;# MGTYTXP0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2 from J22.C2  DP0_C2M_P
set_property -dict {LOC AT43} [get_ports {fmcp_hspc_dp_c2m_n[0]}]  ;# MGTYTXN0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2 from J22.C3  DP0_C2M_N
set_property -dict {LOC AR45} [get_ports {fmcp_hspc_dp_m2c_p[0]}]  ;# MGTYRXP0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2 from J22.C6  DP0_M2C_P
set_property -dict {LOC AR46} [get_ports {fmcp_hspc_dp_m2c_n[0]}]  ;# MGTYRXN0_121 GTYE4_CHANNEL_X0Y8 / GTYE4_COMMON_X0Y2 from J22.C7  DP0_M2C_N
set_property -dict {LOC AP42} [get_ports {fmcp_hspc_dp_c2m_p[1]}]  ;# MGTYTXP1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2 from J22.A22 DP1_C2M_P
set_property -dict {LOC AP43} [get_ports {fmcp_hspc_dp_c2m_n[1]}]  ;# MGTYTXN1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2 from J22.A23 DP1_C2M_N
set_property -dict {LOC AN45} [get_ports {fmcp_hspc_dp_m2c_p[1]}]  ;# MGTYRXP1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2 from J22.A2  DP1_M2C_P
set_property -dict {LOC AN46} [get_ports {fmcp_hspc_dp_m2c_n[1]}]  ;# MGTYRXN1_121 GTYE4_CHANNEL_X0Y9 / GTYE4_COMMON_X0Y2 from J22.A3  DP1_M2C_N
set_property -dict {LOC AM42} [get_ports {fmcp_hspc_dp_c2m_p[2]}]  ;# MGTYTXP2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2 from J22.A26 DP2_C2M_P
set_property -dict {LOC AM43} [get_ports {fmcp_hspc_dp_c2m_n[2]}]  ;# MGTYTXN2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2 from J22.A27 DP2_C2M_N
set_property -dict {LOC AL45} [get_ports {fmcp_hspc_dp_m2c_p[2]}]  ;# MGTYRXP2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2 from J22.A6  DP2_M2C_P
set_property -dict {LOC AL46} [get_ports {fmcp_hspc_dp_m2c_n[2]}]  ;# MGTYRXN2_121 GTYE4_CHANNEL_X0Y10 / GTYE4_COMMON_X0Y2 from J22.A7  DP2_M2C_N
set_property -dict {LOC AL40} [get_ports {fmcp_hspc_dp_c2m_p[3]}]  ;# MGTYTXP3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2 from J22.A30 DP3_C2M_P
set_property -dict {LOC AL41} [get_ports {fmcp_hspc_dp_c2m_n[3]}]  ;# MGTYTXN3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2 from J22.A31 DP3_C2M_N
set_property -dict {LOC AJ45} [get_ports {fmcp_hspc_dp_m2c_p[3]}]  ;# MGTYRXP3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2 from J22.A10 DP3_M2C_P
set_property -dict {LOC AJ46} [get_ports {fmcp_hspc_dp_m2c_n[3]}]  ;# MGTYRXN3_121 GTYE4_CHANNEL_X0Y11 / GTYE4_COMMON_X0Y2 from J22.A11 DP3_M2C_N
set_property -dict {LOC AK38} [get_ports {fmcp_hspc_mgt_refclk_0_0_p}] ;# MGTREFCLK0P_121 from U40.1 Q0 from J22.D4 GBTCLK0_M2C_P
set_property -dict {LOC AK39} [get_ports {fmcp_hspc_mgt_refclk_0_0_n}] ;# MGTREFCLK0N_121 from U40.2 NQ0 from J22.D5 GBTCLK0_M2C_N
set_property -dict {LOC AH38} [get_ports {fmcp_hspc_mgt_refclk_0_1_p}] ;# MGTREFCLK1P_121 from U39.5 Q0_P from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC AH39} [get_ports {fmcp_hspc_mgt_refclk_0_1_n}] ;# MGTREFCLK1N_121 from U39.6 Q0_N from J22.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_0_0 [get_ports {fmcp_hspc_mgt_refclk_0_0_p}]
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_0_1 [get_ports {fmcp_hspc_mgt_refclk_0_1_p}]

set_property -dict {LOC T42 } [get_ports {fmcp_hspc_dp_c2m_p[4]}]  ;# MGTYTXP0_126 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7 from J22.A34 DP4_C2M_P
set_property -dict {LOC T43 } [get_ports {fmcp_hspc_dp_c2m_n[4]}]  ;# MGTYTXN0_126 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7 from J22.A35 DP4_C2M_N
set_property -dict {LOC W45 } [get_ports {fmcp_hspc_dp_m2c_p[4]}]  ;# MGTYRXP0_126 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7 from J22.A14 DP4_M2C_P
set_property -dict {LOC W46 } [get_ports {fmcp_hspc_dp_m2c_n[4]}]  ;# MGTYRXN0_126 GTYE4_CHANNEL_X0Y28 / GTYE4_COMMON_X0Y7 from J22.A15 DP4_M2C_N
set_property -dict {LOC P42 } [get_ports {fmcp_hspc_dp_c2m_p[5]}]  ;# MGTYTXP1_126 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7 from J22.A38 DP5_C2M_P
set_property -dict {LOC P43 } [get_ports {fmcp_hspc_dp_c2m_n[5]}]  ;# MGTYTXN1_126 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7 from J22.A39 DP5_C2M_N
set_property -dict {LOC U45 } [get_ports {fmcp_hspc_dp_m2c_p[5]}]  ;# MGTYRXP1_126 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7 from J22.A18 DP5_M2C_P
set_property -dict {LOC U46 } [get_ports {fmcp_hspc_dp_m2c_n[5]}]  ;# MGTYRXN1_126 GTYE4_CHANNEL_X0Y29 / GTYE4_COMMON_X0Y7 from J22.A19 DP5_M2C_N
set_property -dict {LOC M42 } [get_ports {fmcp_hspc_dp_c2m_p[6]}]  ;# MGTYTXP2_126 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7 from J22.B36 DP6_C2M_P
set_property -dict {LOC M43 } [get_ports {fmcp_hspc_dp_c2m_n[6]}]  ;# MGTYTXN2_126 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7 from J22.B37 DP6_C2M_N
set_property -dict {LOC R45 } [get_ports {fmcp_hspc_dp_m2c_p[6]}]  ;# MGTYRXP2_126 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7 from J22.B16 DP6_M2C_P
set_property -dict {LOC R46 } [get_ports {fmcp_hspc_dp_m2c_n[6]}]  ;# MGTYRXN2_126 GTYE4_CHANNEL_X0Y30 / GTYE4_COMMON_X0Y7 from J22.B17 DP6_M2C_N
set_property -dict {LOC K42 } [get_ports {fmcp_hspc_dp_c2m_p[7]}]  ;# MGTYTXP3_126 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7 from J22.B32 DP7_C2M_P
set_property -dict {LOC K43 } [get_ports {fmcp_hspc_dp_c2m_n[7]}]  ;# MGTYTXN3_126 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7 from J22.B33 DP7_C2M_N
set_property -dict {LOC N45 } [get_ports {fmcp_hspc_dp_m2c_p[7]}]  ;# MGTYRXP3_126 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7 from J22.B12 DP7_M2C_P
set_property -dict {LOC N46 } [get_ports {fmcp_hspc_dp_m2c_n[7]}]  ;# MGTYRXN3_126 GTYE4_CHANNEL_X0Y31 / GTYE4_COMMON_X0Y7 from J22.B13 DP7_M2C_N
set_property -dict {LOC V38 } [get_ports {fmcp_hspc_mgt_refclk_1_0_p}] ;# MGTREFCLK0P_126 from U40.3 Q1 from J22.D4 GBTCLK0_M2C_P
set_property -dict {LOC V39 } [get_ports {fmcp_hspc_mgt_refclk_1_0_n}] ;# MGTREFCLK0N_126 from U40.4 NQ1 from J22.D5 GBTCLK0_M2C_N
set_property -dict {LOC T38 } [get_ports {fmcp_hspc_mgt_refclk_1_1_p}] ;# MGTREFCLK1P_126 from U39.8 Q1_P from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC T39 } [get_ports {fmcp_hspc_mgt_refclk_1_1_n}] ;# MGTREFCLK1N_126 from U39.9 Q1_N from J22.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_1_0 [get_ports {fmcp_hspc_mgt_refclk_1_0_p}]
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_1_1 [get_ports {fmcp_hspc_mgt_refclk_1_1_p}]

set_property -dict {LOC AK42} [get_ports {fmcp_hspc_dp_c2m_p[8]}]  ;# MGTYTXP0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3 from J22.B28 DP8_C2M_P
set_property -dict {LOC AK43} [get_ports {fmcp_hspc_dp_c2m_n[8]}]  ;# MGTYTXN0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3 from J22.B29 DP8_C2M_N
set_property -dict {LOC AG45} [get_ports {fmcp_hspc_dp_m2c_p[8]}]  ;# MGTYRXP0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3 from J22.B8  DP8_M2C_P
set_property -dict {LOC AG46} [get_ports {fmcp_hspc_dp_m2c_n[8]}]  ;# MGTYRXN0_122 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3 from J22.B9  DP8_M2C_N
set_property -dict {LOC AJ40} [get_ports {fmcp_hspc_dp_c2m_p[9]}]  ;# MGTYTXP1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3 from J22.B24 DP9_C2M_P
set_property -dict {LOC AJ41} [get_ports {fmcp_hspc_dp_c2m_n[9]}]  ;# MGTYTXN1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3 from J22.B25 DP9_C2M_N
set_property -dict {LOC AF43} [get_ports {fmcp_hspc_dp_m2c_p[9]}]  ;# MGTYRXP1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3 from J22.B4  DP9_M2C_P
set_property -dict {LOC AF44} [get_ports {fmcp_hspc_dp_m2c_n[9]}]  ;# MGTYRXN1_122 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3 from J22.B5  DP9_M2C_N
set_property -dict {LOC AG40} [get_ports {fmcp_hspc_dp_c2m_p[10]}] ;# MGTYTXP2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3 from J22.Z24 DP10_C2M_P
set_property -dict {LOC AG41} [get_ports {fmcp_hspc_dp_c2m_n[10]}] ;# MGTYTXN2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3 from J22.Z25 DP10_C2M_N
set_property -dict {LOC AE45} [get_ports {fmcp_hspc_dp_m2c_p[10]}] ;# MGTYRXP2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3 from J22.Y10 DP10_M2C_P
set_property -dict {LOC AE46} [get_ports {fmcp_hspc_dp_m2c_n[10]}] ;# MGTYRXN2_122 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3 from J22.Y11 DP10_M2C_N
set_property -dict {LOC AE40} [get_ports {fmcp_hspc_dp_c2m_p[11]}] ;# MGTYTXP3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3 from J22.Y26 DP11_C2M_P
set_property -dict {LOC AE41} [get_ports {fmcp_hspc_dp_c2m_n[11]}] ;# MGTYTXN3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3 from J22.Y27 DP11_C2M_N
set_property -dict {LOC AD43} [get_ports {fmcp_hspc_dp_m2c_p[11]}] ;# MGTYRXP3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3 from J22.Z12 DP11_M2C_P
set_property -dict {LOC AD44} [get_ports {fmcp_hspc_dp_m2c_n[11]}] ;# MGTYRXN3_122 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3 from J22.Z13 DP11_M2C_N
set_property -dict {LOC AF38} [get_ports {fmcp_hspc_mgt_refclk_2_0_p}] ;# MGTREFCLK0P_122 from J22.L12 GBTCLK2_M2C_P
set_property -dict {LOC AF39} [get_ports {fmcp_hspc_mgt_refclk_2_0_n}] ;# MGTREFCLK0N_122 from J22.L13 GBTCLK2_M2C_N
set_property -dict {LOC AD38} [get_ports {fmcp_hspc_mgt_refclk_2_1_p}] ;# MGTREFCLK1P_122 from U39.11 Q2_P from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC AD39} [get_ports {fmcp_hspc_mgt_refclk_2_1_n}] ;# MGTREFCLK1N_122 from U39.12 Q2_N from J22.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_2_0 [get_ports {fmcp_hspc_mgt_refclk_2_0_p}]
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_2_1 [get_ports {fmcp_hspc_mgt_refclk_2_1_p}]

set_property -dict {LOC AC40} [get_ports {fmcp_hspc_dp_c2m_p[12]}] ;# MGTYTXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6 from J22.Z28 DP12_C2M_P
set_property -dict {LOC AC41} [get_ports {fmcp_hspc_dp_c2m_n[12]}] ;# MGTYTXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6 from J22.Z29 DP12_C2M_N
set_property -dict {LOC AC45} [get_ports {fmcp_hspc_dp_m2c_p[12]}] ;# MGTYRXP0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6 from J22.Y14 DP12_M2C_P
set_property -dict {LOC AC46} [get_ports {fmcp_hspc_dp_m2c_n[12]}] ;# MGTYRXN0_125 GTYE4_CHANNEL_X0Y24 / GTYE4_COMMON_X0Y6 from J22.Y15 DP12_M2C_N
set_property -dict {LOC AA40} [get_ports {fmcp_hspc_dp_c2m_p[13]}] ;# MGTYTXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6 from J22.Y30 DP13_C2M_P
set_property -dict {LOC AA41} [get_ports {fmcp_hspc_dp_c2m_n[13]}] ;# MGTYTXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6 from J22.Y31 DP13_C2M_N
set_property -dict {LOC AB43} [get_ports {fmcp_hspc_dp_m2c_p[13]}] ;# MGTYRXP1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6 from J22.Z16 DP13_M2C_P
set_property -dict {LOC AB44} [get_ports {fmcp_hspc_dp_m2c_n[13]}] ;# MGTYRXN1_125 GTYE4_CHANNEL_X0Y25 / GTYE4_COMMON_X0Y6 from J22.Z17 DP13_M2C_N
set_property -dict {LOC W40 } [get_ports {fmcp_hspc_dp_c2m_p[14]}] ;# MGTYTXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6 from J22.M18 DP14_C2M_P
set_property -dict {LOC W41 } [get_ports {fmcp_hspc_dp_c2m_n[14]}] ;# MGTYTXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6 from J22.M19 DP14_C2M_N
set_property -dict {LOC AA45} [get_ports {fmcp_hspc_dp_m2c_p[14]}] ;# MGTYRXP2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6 from J22.Y18 DP14_M2C_P
set_property -dict {LOC AA46} [get_ports {fmcp_hspc_dp_m2c_n[14]}] ;# MGTYRXN2_125 GTYE4_CHANNEL_X0Y26 / GTYE4_COMMON_X0Y6 from J22.Y19 DP14_M2C_N
set_property -dict {LOC U40 } [get_ports {fmcp_hspc_dp_c2m_p[15]}] ;# MGTYTXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6 from J22.M22 DP15_C2M_P
set_property -dict {LOC U41 } [get_ports {fmcp_hspc_dp_c2m_n[15]}] ;# MGTYTXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6 from J22.M23 DP15_C2M_N
set_property -dict {LOC Y43 } [get_ports {fmcp_hspc_dp_m2c_p[15]}] ;# MGTYRXP3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6 from J22.Y22 DP15_M2C_P
set_property -dict {LOC Y44 } [get_ports {fmcp_hspc_dp_m2c_n[15]}] ;# MGTYRXN3_125 GTYE4_CHANNEL_X0Y27 / GTYE4_COMMON_X0Y6 from J22.Y23 DP15_M2C_N
set_property -dict {LOC AB38} [get_ports {fmcp_hspc_mgt_refclk_3_0_p}] ;# MGTREFCLK0P_125 from J22.L8 GBTCLK3_M2C_P
set_property -dict {LOC AB39} [get_ports {fmcp_hspc_mgt_refclk_3_0_n}] ;# MGTREFCLK0N_125 from J22.L9 GBTCLK3_M2C_N
set_property -dict {LOC Y38 } [get_ports {fmcp_hspc_mgt_refclk_3_1_p}] ;# MGTREFCLK1P_125 from U39.13 Q3_P from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC Y39 } [get_ports {fmcp_hspc_mgt_refclk_3_1_n}] ;# MGTREFCLK1N_125 from U39.14 Q3_N from J22.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_3_0 [get_ports {fmcp_hspc_mgt_refclk_3_0_p}]
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_3_1 [get_ports {fmcp_hspc_mgt_refclk_3_1_p}]

set_property -dict {LOC H42 } [get_ports {fmcp_hspc_dp_c2m_p[16]}] ;# MGTYTXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8 from J22.M26 DP16_C2M_P
set_property -dict {LOC H43 } [get_ports {fmcp_hspc_dp_c2m_n[16]}] ;# MGTYTXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8 from J22.M27 DP16_C2M_N
set_property -dict {LOC L45 } [get_ports {fmcp_hspc_dp_m2c_p[16]}] ;# MGTYRXP0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8 from J22.Z32 DP16_M2C_P
set_property -dict {LOC L46 } [get_ports {fmcp_hspc_dp_m2c_n[16]}] ;# MGTYRXN0_127 GTYE4_CHANNEL_X0Y32 / GTYE4_COMMON_X0Y8 from J22.Z33 DP16_M2C_N
set_property -dict {LOC F42 } [get_ports {fmcp_hspc_dp_c2m_p[17]}] ;# MGTYTXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8 from J22.M30 DP17_C2M_P
set_property -dict {LOC F43 } [get_ports {fmcp_hspc_dp_c2m_n[17]}] ;# MGTYTXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8 from J22.M31 DP17_C2M_N
set_property -dict {LOC J45 } [get_ports {fmcp_hspc_dp_m2c_p[17]}] ;# MGTYRXP1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8 from J22.Y34 DP17_M2C_P
set_property -dict {LOC J46 } [get_ports {fmcp_hspc_dp_m2c_n[17]}] ;# MGTYRXN1_127 GTYE4_CHANNEL_X0Y33 / GTYE4_COMMON_X0Y8 from J22.Y35 DP17_M2C_N
set_property -dict {LOC D42 } [get_ports {fmcp_hspc_dp_c2m_p[18]}] ;# MGTYTXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8 from J22.M34 DP18_C2M_P
set_property -dict {LOC D43 } [get_ports {fmcp_hspc_dp_c2m_n[18]}] ;# MGTYTXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8 from J22.M35 DP18_C2M_N
set_property -dict {LOC G45 } [get_ports {fmcp_hspc_dp_m2c_p[18]}] ;# MGTYRXP2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8 from J22.Z36 DP18_M2C_P
set_property -dict {LOC G46 } [get_ports {fmcp_hspc_dp_m2c_n[18]}] ;# MGTYRXN2_127 GTYE4_CHANNEL_X0Y34 / GTYE4_COMMON_X0Y8 from J22.Z37 DP18_M2C_N
set_property -dict {LOC B42 } [get_ports {fmcp_hspc_dp_c2m_p[19]}] ;# MGTYTXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8 from J22.M38 DP19_C2M_P
set_property -dict {LOC B43 } [get_ports {fmcp_hspc_dp_c2m_n[19]}] ;# MGTYTXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8 from J22.M39 DP19_C2M_N
set_property -dict {LOC E45 } [get_ports {fmcp_hspc_dp_m2c_p[19]}] ;# MGTYRXP3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8 from J22.Y38 DP19_M2C_P
set_property -dict {LOC E46 } [get_ports {fmcp_hspc_dp_m2c_n[19]}] ;# MGTYRXN3_127 GTYE4_CHANNEL_X0Y35 / GTYE4_COMMON_X0Y8 from J22.Y39 DP19_M2C_N
set_property -dict {LOC R40 } [get_ports {fmcp_hspc_mgt_refclk_4_0_p}] ;# MGTREFCLK0P_127 from J22.L4 GBTCLK4_M2C_P
set_property -dict {LOC R41 } [get_ports {fmcp_hspc_mgt_refclk_4_0_n}] ;# MGTREFCLK0N_127 from J22.L5 GBTCLK4_M2C_N
set_property -dict {LOC N40 } [get_ports {fmcp_hspc_mgt_refclk_4_1_p}] ;# MGTREFCLK1P_127 from U39.16 Q4_P from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC N41 } [get_ports {fmcp_hspc_mgt_refclk_4_1_n}] ;# MGTREFCLK1N_127 from U39.17 Q4_N from J22.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_4_0 [get_ports {fmcp_hspc_mgt_refclk_4_0_p}]
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_4_1 [get_ports {fmcp_hspc_mgt_refclk_4_1_p}]

set_property -dict {LOC BD42} [get_ports {fmcp_hspc_dp_c2m_p[20]}] ;# MGTYTXP0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1 from J22.Z8  DP20_C2M_P
set_property -dict {LOC BD43} [get_ports {fmcp_hspc_dp_c2m_n[20]}] ;# MGTYTXN0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1 from J22.Z9  DP20_C2M_N
set_property -dict {LOC BC45} [get_ports {fmcp_hspc_dp_m2c_p[20]}] ;# MGTYRXP0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1 from J22.M14 DP20_M2C_P
set_property -dict {LOC BC46} [get_ports {fmcp_hspc_dp_m2c_n[20]}] ;# MGTYRXN0_120 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1 from J22.M15 DP20_M2C_N
set_property -dict {LOC BB42} [get_ports {fmcp_hspc_dp_c2m_p[21]}] ;# MGTYTXP1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1 from J22.Y6  DP21_C2M_P
set_property -dict {LOC BB43} [get_ports {fmcp_hspc_dp_c2m_n[21]}] ;# MGTYTXN1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1 from J22.Y7  DP21_C2M_N
set_property -dict {LOC BA45} [get_ports {fmcp_hspc_dp_m2c_p[21]}] ;# MGTYRXP1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1 from J22.M10 DP21_M2C_P
set_property -dict {LOC BA46} [get_ports {fmcp_hspc_dp_m2c_n[21]}] ;# MGTYRXN1_120 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1 from J22.M11 DP21_M2C_N
set_property -dict {LOC AY42} [get_ports {fmcp_hspc_dp_c2m_p[22]}] ;# MGTYTXP2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1 from J22.Z4  DP22_C2M_P
set_property -dict {LOC AY43} [get_ports {fmcp_hspc_dp_c2m_n[22]}] ;# MGTYTXN2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1 from J22.Z5  DP22_C2M_N
set_property -dict {LOC AW45} [get_ports {fmcp_hspc_dp_m2c_p[22]}] ;# MGTYRXP2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1 from J22.M6  DP22_M2C_P
set_property -dict {LOC AW46} [get_ports {fmcp_hspc_dp_m2c_n[22]}] ;# MGTYRXN2_120 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1 from J22.M7  DP22_M2C_N
set_property -dict {LOC AV42} [get_ports {fmcp_hspc_dp_c2m_p[23]}] ;# MGTYTXP3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1 from J22.Y2  DP23_C2M_P
set_property -dict {LOC AV43} [get_ports {fmcp_hspc_dp_c2m_n[23]}] ;# MGTYTXN3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1 from J22.Y3  DP23_C2M_N
set_property -dict {LOC AU45} [get_ports {fmcp_hspc_dp_m2c_p[23]}] ;# MGTYRXP3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1 from J22.M2  DP23_M2C_P
set_property -dict {LOC AU46} [get_ports {fmcp_hspc_dp_m2c_n[23]}] ;# MGTYRXN3_120 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1 from J22.M3  DP23_M2C_N
set_property -dict {LOC AN40} [get_ports {fmcp_hspc_mgt_refclk_5_0_p}] ;# MGTREFCLK0P_120 from J22.Z20 GBTCLK5_M2C_P
set_property -dict {LOC AN41} [get_ports {fmcp_hspc_mgt_refclk_5_0_n}] ;# MGTREFCLK0N_120 from J22.Z21 GBTCLK5_M2C_N
set_property -dict {LOC AM38} [get_ports {fmcp_hspc_mgt_refclk_5_1_p}] ;# MGTREFCLK1P_120 from U39.19 Q5_P from J22.B20 GBTCLK1_M2C_P
set_property -dict {LOC AM39} [get_ports {fmcp_hspc_mgt_refclk_5_1_n}] ;# MGTREFCLK1N_120 from U39.20 Q5_N from J22.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_5_0 [get_ports {fmcp_hspc_mgt_refclk_5_0_p}]
create_clock -period 6.400 -name fmcp_hspc_mgt_refclk_5_1 [get_ports {fmcp_hspc_mgt_refclk_5_1_p}]
