# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-ZRF8-EM board
# part: xczu28dr-ffvg1517-2-e
# part: xczu48dr-ffvg1517-2-e

# FMC+ J25
set_property -dict {LOC B8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[0]}]  ;# J25.G9  LA00_P_CC
set_property -dict {LOC B7   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[0]}]  ;# J25.G10 LA00_N_CC
set_property -dict {LOC E9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[1]}]  ;# J25.D8  LA01_P_CC
set_property -dict {LOC E8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[1]}]  ;# J25.D9  LA01_N_CC
set_property -dict {LOC A7   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[2]}]  ;# J25.H7  LA02_P
set_property -dict {LOC A6   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[2]}]  ;# J25.H8  LA02_N
set_property -dict {LOC E7   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[3]}]  ;# J25.G12 LA03_P
set_property -dict {LOC E6   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[3]}]  ;# J25.G13 LA03_N
set_property -dict {LOC F6   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[4]}]  ;# J25.H10 LA04_P
set_property -dict {LOC E6   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[4]}]  ;# J25.H11 LA04_N
set_property -dict {LOC D9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[5]}]  ;# J25.D11 LA05_P
set_property -dict {LOC D8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[5]}]  ;# J25.D12 LA05_N
set_property -dict {LOC D10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[6]}]  ;# J25.C10 LA06_P
set_property -dict {LOC C10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[6]}]  ;# J25.C11 LA06_N
set_property -dict {LOC C6   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[7]}]  ;# J25.H13 LA07_P
set_property -dict {LOC C5   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[7]}]  ;# J25.H14 LA07_N
set_property -dict {LOC B5   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[8]}]  ;# J25.G12 LA08_P
set_property -dict {LOC A5   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[8]}]  ;# J25.G13 LA08_N
set_property -dict {LOC A10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_p[9]}]  ;# J25.D14 LA09_P
set_property -dict {LOC A9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_la_n[9]}]  ;# J25.D15 LA09_N

set_property -dict {LOC C8   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_clk0_m2c_p}] ;# J25.H4 CLK0_M2C_P
set_property -dict {LOC C7   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_clk0_m2c_n}] ;# J25.H5 CLK0_M2C_N

set_property -dict {LOC B10  IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_refclk_m2c_p}] ;# J25.L24 REFCLK_M2C_P
set_property -dict {LOC B9   IOSTANDARD LVDS DIFF_TERM TRUE} [get_ports {fmc_refclk_m2c_n}] ;# J25.L25 REFCLK_M2C_N

set_property -dict {LOC F17  IOSTANDARD LVCMOS12} [get_ports {fmc_prsnt_m2c}]        ;# J25.H2 PRSNT_M2C_L
set_property -dict {LOC M18  IOSTANDARD LVCMOS12} [get_ports {fmc_hspc_prsnt_m2c_l}] ;# J25.Z1 HSPC_PRSNT_M2C_L

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
set_property -dict {LOC U33 } [get_ports fmc_mgt_refclk_0_0_p] ;# MGTREFCLK0P_130 from U48.42 OUT5_P
set_property -dict {LOC U34 } [get_ports fmc_mgt_refclk_0_0_n] ;# MGTREFCLK0N_130 from U48.41 OUT5_N
set_property -dict {LOC T31 } [get_ports fmc_mgt_refclk_0_1_p] ;# MGTREFCLK1P_130 from J25.D4 GBTCLK0_M2C_P
set_property -dict {LOC T32 } [get_ports fmc_mgt_refclk_0_1_n] ;# MGTREFCLK1N_130 from J25.D5 GBTCLK0_M2C_N

# reference clock from U48
create_clock -period 6.206 -name fmc_mgt_refclk_0_0 [get_ports fmc_mgt_refclk_0_0_p]

# reference clock from J25
create_clock -period 6.400 -name fmc_mgt_refclk_0_1 [get_ports fmc_mgt_refclk_0_1_p]

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
set_property -dict {LOC P31 } [get_ports fmc_mgt_refclk_1_0_p] ;# MGTREFCLK0P_131 from U48.45 OUT6_P
set_property -dict {LOC P32 } [get_ports fmc_mgt_refclk_1_0_n] ;# MGTREFCLK0N_131 from U48.44 OUT6_N
set_property -dict {LOC M31 } [get_ports fmc_mgt_refclk_1_1_p] ;# MGTREFCLK1P_131 from J25.B20 GBTCLK1_M2C_P
set_property -dict {LOC M32 } [get_ports fmc_mgt_refclk_1_1_n] ;# MGTREFCLK1N_131 from J25.B21 GBTCLK1_M2C_N

# reference clock from U48
create_clock -period 6.206 -name fmc_mgt_refclk_1_0 [get_ports fmc_mgt_refclk_1_0_p]

# reference clock from J25
create_clock -period 6.400 -name fmc_mgt_refclk_1_1 [get_ports fmc_mgt_refclk_1_1_p]
