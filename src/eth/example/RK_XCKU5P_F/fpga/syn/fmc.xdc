# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# FMC interface
# FMC HPC J4
set_property -dict {LOC G24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[0]}]  ;# J4.G9  LA00_P_CC
set_property -dict {LOC G25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[0]}]  ;# J4.G10 LA00_N_CC
set_property -dict {LOC J23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[1]}]  ;# J4.D8  LA01_P_CC
set_property -dict {LOC J24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[1]}]  ;# J4.D9  LA01_N_CC
set_property -dict {LOC H21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[2]}]  ;# J4.H7  LA02_P
set_property -dict {LOC H22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[2]}]  ;# J4.H8  LA02_N
set_property -dict {LOC J19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[3]}]  ;# J4.G12 LA03_P
set_property -dict {LOC J20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[3]}]  ;# J4.G13 LA03_N
set_property -dict {LOC H26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[4]}]  ;# J4.H10 LA04_P
set_property -dict {LOC G26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[4]}]  ;# J4.H11 LA04_N
set_property -dict {LOC F24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[5]}]  ;# J4.D11 LA05_P
set_property -dict {LOC F25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[5]}]  ;# J4.D12 LA05_N
set_property -dict {LOC G20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[6]}]  ;# J4.C10 LA06_P
set_property -dict {LOC G21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[6]}]  ;# J4.C11 LA06_N
set_property -dict {LOC D24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[7]}]  ;# J4.H13 LA07_P
set_property -dict {LOC D25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[7]}]  ;# J4.H14 LA07_N
set_property -dict {LOC D26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[8]}]  ;# J4.G12 LA08_P
set_property -dict {LOC C26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[8]}]  ;# J4.G13 LA08_N
set_property -dict {LOC E25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[9]}]  ;# J4.D14 LA09_P
set_property -dict {LOC E26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[9]}]  ;# J4.D15 LA09_N
set_property -dict {LOC B25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[10]}] ;# J4.C14 LA10_P
set_property -dict {LOC B26  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[10]}] ;# J4.C15 LA10_N
set_property -dict {LOC A24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[11]}] ;# J4.H16 LA11_P
set_property -dict {LOC A25  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[11]}] ;# J4.H17 LA11_N
set_property -dict {LOC D23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[12]}] ;# J4.G15 LA12_P
set_property -dict {LOC C24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[12]}] ;# J4.G16 LA12_N
set_property -dict {LOC F23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[13]}] ;# J4.D17 LA13_P
set_property -dict {LOC E23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[13]}] ;# J4.D18 LA13_N
set_property -dict {LOC C23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[14]}] ;# J4.C18 LA14_P
set_property -dict {LOC B24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[14]}] ;# J4.C19 LA14_N
set_property -dict {LOC H18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[15]}] ;# J4.H19 LA15_P
set_property -dict {LOC H19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[15]}] ;# J4.H20 LA15_N
set_property -dict {LOC E21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[16]}] ;# J4.G18 LA16_P
set_property -dict {LOC D21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[16]}] ;# J4.G19 LA16_N
set_property -dict {LOC C18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[17]}] ;# J4.D20 LA17_P_CC
set_property -dict {LOC C19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[17]}] ;# J4.D21 LA17_N_CC
set_property -dict {LOC D19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[18]}] ;# J4.C22 LA18_P_CC
set_property -dict {LOC D20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[18]}] ;# J4.C23 LA18_N_CC
set_property -dict {LOC A22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[19]}] ;# J4.H22 LA19_P
set_property -dict {LOC A23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[19]}] ;# J4.H23 LA19_N
set_property -dict {LOC F20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[20]}] ;# J4.G21 LA20_P
set_property -dict {LOC E20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[20]}] ;# J4.G22 LA20_N
set_property -dict {LOC C21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[21]}] ;# J4.H25 LA21_P
set_property -dict {LOC B21  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[21]}] ;# J4.H26 LA21_N
set_property -dict {LOC H16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[22]}] ;# J4.G24 LA22_P
set_property -dict {LOC G16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[22]}] ;# J4.G25 LA22_N
set_property -dict {LOC C22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[23]}] ;# J4.D23 LA23_P
set_property -dict {LOC B22  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[23]}] ;# J4.D24 LA23_N
set_property -dict {LOC A17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[24]}] ;# J4.H28 LA24_P
set_property -dict {LOC A18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[24]}] ;# J4.H29 LA24_N
set_property -dict {LOC E18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[25]}] ;# J4.G27 LA25_P
set_property -dict {LOC D18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[25]}] ;# J4.G28 LA25_N
set_property -dict {LOC A19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[26]}] ;# J4.D26 LA26_P
set_property -dict {LOC A20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[26]}] ;# J4.D27 LA26_N
set_property -dict {LOC F18  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[27]}] ;# J4.C26 LA27_P
set_property -dict {LOC F19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[27]}] ;# J4.C27 LA27_N
set_property -dict {LOC C17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[28]}] ;# J4.H31 LA28_P
set_property -dict {LOC B17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[28]}] ;# J4.H32 LA28_N
set_property -dict {LOC E16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[29]}] ;# J4.G30 LA29_P
set_property -dict {LOC E17  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[29]}] ;# J4.G31 LA29_N
set_property -dict {LOC D16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[30]}] ;# J4.H34 LA30_P
set_property -dict {LOC C16  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[30]}] ;# J4.H35 LA30_N
set_property -dict {LOC G15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[31]}] ;# J4.G33 LA31_P
set_property -dict {LOC F15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[31]}] ;# J4.G34 LA31_N
set_property -dict {LOC B15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[32]}] ;# J4.H37 LA32_P
set_property -dict {LOC A15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[32]}] ;# J4.H38 LA32_N
set_property -dict {LOC E15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_p[33]}] ;# J4.G36 LA33_P
set_property -dict {LOC D15  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_la_n[33]}] ;# J4.G37 LA33_N

set_property -dict {LOC H23  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk0_m2c_p}] ;# J4.H4 CLK0_M2C_P
set_property -dict {LOC H24  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk0_m2c_n}] ;# J4.H5 CLK0_M2C_N
set_property -dict {LOC B19  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk1_m2c_p}] ;# J4.G2 CLK1_M2C_P
set_property -dict {LOC B20  IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {fmc_clk1_m2c_n}] ;# J4.G3 CLK1_M2C_N

set_property -dict {LOC F10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {fmc_scl}] ;# J4.C30 SCL
set_property -dict {LOC F9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 8} [get_ports {fmc_sda}] ;# J4.C31 SDA
set_property -dict {LOC G10  IOSTANDARD LVCMOS33} [get_ports {fmc_pg_m2c}]                ;# J4.F1 PG_M2C

set_property -dict {LOC N5  } [get_ports {fmc_dp_c2m_p[0]}] ;# MGTHTXP0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C2  DP0_C2M_P
set_property -dict {LOC N4  } [get_ports {fmc_dp_c2m_n[0]}] ;# MGTHTXN0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C3  DP0_C2M_N
set_property -dict {LOC M2  } [get_ports {fmc_dp_m2c_p[0]}] ;# MGTHRXP0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C6  DP0_M2C_P
set_property -dict {LOC M1  } [get_ports {fmc_dp_m2c_n[0]}] ;# MGTHRXN0_226 GTHE4_CHANNEL_X0Y8  / GTHE4_COMMON_X0Y3 from J4.C7  DP0_M2C_N
set_property -dict {LOC L5  } [get_ports {fmc_dp_c2m_p[1]}] ;# MGTHTXP1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A22 DP1_C2M_P
set_property -dict {LOC L4  } [get_ports {fmc_dp_c2m_n[1]}] ;# MGTHTXN1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A23 DP1_C2M_N
set_property -dict {LOC K2  } [get_ports {fmc_dp_m2c_p[1]}] ;# MGTHRXP1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A2  DP1_M2C_P
set_property -dict {LOC K1  } [get_ports {fmc_dp_m2c_n[1]}] ;# MGTHRXN1_226 GTHE4_CHANNEL_X0Y9  / GTHE4_COMMON_X0Y3 from J4.A3  DP1_M2C_N
set_property -dict {LOC J5  } [get_ports {fmc_dp_c2m_p[2]}] ;# MGTHTXP2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A26 DP2_C2M_P
set_property -dict {LOC J4  } [get_ports {fmc_dp_c2m_n[2]}] ;# MGTHTXN2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A27 DP2_C2M_N
set_property -dict {LOC H2  } [get_ports {fmc_dp_m2c_p[2]}] ;# MGTHRXP2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A6  DP2_M2C_P
set_property -dict {LOC H1  } [get_ports {fmc_dp_m2c_n[2]}] ;# MGTHRXN2_226 GTHE4_CHANNEL_X0Y10 / GTHE4_COMMON_X0Y3 from J4.A7  DP2_M2C_N
set_property -dict {LOC G5  } [get_ports {fmc_dp_c2m_p[3]}] ;# MGTHTXP3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A30 DP3_C2M_P
set_property -dict {LOC G4  } [get_ports {fmc_dp_c2m_n[3]}] ;# MGTHTXN3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A31 DP3_C2M_N
set_property -dict {LOC F2  } [get_ports {fmc_dp_m2c_p[3]}] ;# MGTHRXP3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A10 DP3_M2C_P
set_property -dict {LOC F1  } [get_ports {fmc_dp_m2c_n[3]}] ;# MGTHRXN3_226 GTHE4_CHANNEL_X0Y11 / GTHE4_COMMON_X0Y3 from J4.A11 DP3_M2C_N

set_property -dict {LOC F7  } [get_ports {fmc_dp_c2m_p[4]}] ;# MGTHTXP0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A34 DP4_C2M_P
set_property -dict {LOC F6  } [get_ports {fmc_dp_c2m_n[4]}] ;# MGTHTXN0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A35 DP4_C2M_N
set_property -dict {LOC D2  } [get_ports {fmc_dp_m2c_p[4]}] ;# MGTHRXP0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A14 DP4_M2C_P
set_property -dict {LOC D1  } [get_ports {fmc_dp_m2c_n[4]}] ;# MGTHRXN0_227 GTHE4_CHANNEL_X0Y12 / GTHE4_COMMON_X0Y4 from J4.A15 DP4_M2C_N
set_property -dict {LOC E5  } [get_ports {fmc_dp_c2m_p[5]}] ;# MGTHTXP1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A38 DP5_C2M_P
set_property -dict {LOC E4  } [get_ports {fmc_dp_c2m_n[5]}] ;# MGTHTXN1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A39 DP5_C2M_N
set_property -dict {LOC C4  } [get_ports {fmc_dp_m2c_p[5]}] ;# MGTHRXP1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A18 DP5_M2C_P
set_property -dict {LOC C3  } [get_ports {fmc_dp_m2c_n[5]}] ;# MGTHRXN1_227 GTHE4_CHANNEL_X0Y13 / GTHE4_COMMON_X0Y4 from J4.A19 DP5_M2C_N
set_property -dict {LOC D7  } [get_ports {fmc_dp_c2m_p[6]}] ;# MGTHTXP2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B36 DP6_C2M_P
set_property -dict {LOC D6  } [get_ports {fmc_dp_c2m_n[6]}] ;# MGTHTXN2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B37 DP6_C2M_N
set_property -dict {LOC B2  } [get_ports {fmc_dp_m2c_p[6]}] ;# MGTHRXP2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B16 DP6_M2C_P
set_property -dict {LOC B1  } [get_ports {fmc_dp_m2c_n[6]}] ;# MGTHRXN2_227 GTHE4_CHANNEL_X0Y14 / GTHE4_COMMON_X0Y4 from J4.B17 DP6_M2C_N
set_property -dict {LOC B7  } [get_ports {fmc_dp_c2m_p[7]}] ;# MGTHTXP3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B32 DP7_C2M_P
set_property -dict {LOC B6  } [get_ports {fmc_dp_c2m_n[7]}] ;# MGTHTXN3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B33 DP7_C2M_N
set_property -dict {LOC A4  } [get_ports {fmc_dp_m2c_p[7]}] ;# MGTHRXP3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B12 DP7_M2C_P
set_property -dict {LOC A3  } [get_ports {fmc_dp_m2c_n[7]}] ;# MGTHRXN3_227 GTHE4_CHANNEL_X0Y15 / GTHE4_COMMON_X0Y4 from J4.B13 DP7_M2C_N
set_property -dict {LOC P7  } [get_ports {fmc_mgt_refclk_0_p}] ;# MGTREFCLK0P_226 from J4.D4 GBTCLK0_M2C_P
set_property -dict {LOC P6  } [get_ports {fmc_mgt_refclk_0_n}] ;# MGTREFCLK0N_226 from J4.D5 GBTCLK0_M2C_N
set_property -dict {LOC K7  } [get_ports {fmc_mgt_refclk_1_p}] ;# MGTREFCLK0P_227 from J4.B20 GBTCLK1_M2C_P
set_property -dict {LOC K6  } [get_ports {fmc_mgt_refclk_1_n}] ;# MGTREFCLK0N_227 from J4.B21 GBTCLK1_M2C_N

# reference clock
create_clock -period 6.400 -name fmc_mgt_refclk_0 [get_ports {fmc_mgt_refclk_0_p}]
create_clock -period 6.400 -name fmc_mgt_refclk_1 [get_ports {fmc_mgt_refclk_1_p}]
