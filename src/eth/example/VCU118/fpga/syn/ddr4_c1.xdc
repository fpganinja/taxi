# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# DDR4 C1
# 5x MT40A256M16GE-075E
set_property -dict {LOC D14  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[0]}]
set_property -dict {LOC B15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[1]}]
set_property -dict {LOC B16  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[2]}]
set_property -dict {LOC C14  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[3]}]
set_property -dict {LOC C15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[4]}]
set_property -dict {LOC A13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[5]}]
set_property -dict {LOC A14  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[6]}]
set_property -dict {LOC A15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[7]}]
set_property -dict {LOC A16  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[8]}]
set_property -dict {LOC B12  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[9]}]
set_property -dict {LOC C12  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[10]}]
set_property -dict {LOC B13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[11]}]
set_property -dict {LOC C13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[12]}]
set_property -dict {LOC D15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[13]}]
set_property -dict {LOC H14  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[14]}]
set_property -dict {LOC H15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[15]}]
set_property -dict {LOC F15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_adr[16]}]
set_property -dict {LOC G15  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_ba[0]}]
set_property -dict {LOC G13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_ba[1]}]
set_property -dict {LOC H13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_bg[0]}]
set_property -dict {LOC F14  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c1_ck_t}]
set_property -dict {LOC E14  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c1_ck_c}]
set_property -dict {LOC A10  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_cke}]
set_property -dict {LOC F13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_cs_n}]
set_property -dict {LOC E13  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_act_n}]
set_property -dict {LOC C8   IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_odt}]
set_property -dict {LOC G10  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c1_par}]
set_property -dict {LOC N20  IOSTANDARD LVCMOS12       } [get_ports {ddr4_c1_reset_n}]
set_property -dict {LOC R17  IOSTANDARD LVCMOS12       } [get_ports {ddr4_c1_alert_n}]
set_property -dict {LOC A20  IOSTANDARD LVCMOS12       } [get_ports {ddr4_c1_ten}]

set_property -dict {LOC F11  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[0]}]       ;# U60.G2 DQL0
set_property -dict {LOC E11  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[1]}]       ;# U60.F7 DQL1
set_property -dict {LOC F10  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[2]}]       ;# U60.H3 DQL2
set_property -dict {LOC F9   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[3]}]       ;# U60.H7 DQL3
set_property -dict {LOC H12  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[4]}]       ;# U60.H2 DQL4
set_property -dict {LOC G12  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[5]}]       ;# U60.H8 DQL5
set_property -dict {LOC E9   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[6]}]       ;# U60.J3 DQL6
set_property -dict {LOC D9   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[7]}]       ;# U60.J7 DQL7
set_property -dict {LOC R19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[8]}]       ;# U60.A3 DQU0
set_property -dict {LOC P19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[9]}]       ;# U60.B8 DQU1
set_property -dict {LOC M18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[10]}]      ;# U60.C3 DQU2
set_property -dict {LOC M17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[11]}]      ;# U60.C7 DQU3
set_property -dict {LOC N19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[12]}]      ;# U60.C2 DQU4
set_property -dict {LOC N18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[13]}]      ;# U60.C8 DQU5
set_property -dict {LOC N17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[14]}]      ;# U60.D3 DQU6
set_property -dict {LOC M16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[15]}]      ;# U60.D7 DQU7
set_property -dict {LOC D11  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[0]}]    ;# U60.G3 DQSL_T
set_property -dict {LOC D10  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[0]}]    ;# U60.F3 DQSL_C
set_property -dict {LOC P17  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[1]}]    ;# U60.B7 DQSU_T
set_property -dict {LOC P16  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[1]}]    ;# U60.A7 DQSU_C
set_property -dict {LOC G11  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[0]}] ;# U60.E7 DML_B/DBIL_B
set_property -dict {LOC R18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[1]}] ;# U60.E2 DMU_B/DBIU_B

set_property -dict {LOC L16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[16]}]      ;# U61.G2 DQL0
set_property -dict {LOC K16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[17]}]      ;# U61.F7 DQL1
set_property -dict {LOC L18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[18]}]      ;# U61.H3 DQL2
set_property -dict {LOC K18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[19]}]      ;# U61.H7 DQL3
set_property -dict {LOC J17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[20]}]      ;# U61.H2 DQL4
set_property -dict {LOC H17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[21]}]      ;# U61.H8 DQL5
set_property -dict {LOC H19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[22]}]      ;# U61.J3 DQL6
set_property -dict {LOC H18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[23]}]      ;# U61.J7 DQL7
set_property -dict {LOC F19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[24]}]      ;# U61.A3 DQU0
set_property -dict {LOC F18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[25]}]      ;# U61.B8 DQU1
set_property -dict {LOC E19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[26]}]      ;# U61.C3 DQU2
set_property -dict {LOC E18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[27]}]      ;# U61.C7 DQU3
set_property -dict {LOC G20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[28]}]      ;# U61.C2 DQU4
set_property -dict {LOC F20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[29]}]      ;# U61.C8 DQU5
set_property -dict {LOC E17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[30]}]      ;# U61.D3 DQU6
set_property -dict {LOC D16  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[31]}]      ;# U61.D7 DQU7
set_property -dict {LOC K19  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[2]}]    ;# U61.G3 DQSL_T
set_property -dict {LOC J19  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[2]}]    ;# U61.F3 DQSL_C
set_property -dict {LOC F16  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[3]}]    ;# U61.B7 DQSU_T
set_property -dict {LOC E16  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[3]}]    ;# U61.A7 DQSU_C
set_property -dict {LOC K17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[2]}] ;# U61.E7 DML_B/DBIL_B
set_property -dict {LOC G18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[3]}] ;# U61.E2 DMU_B/DBIU_B

set_property -dict {LOC D17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[32]}]      ;# U62.G2 DQL0
set_property -dict {LOC C17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[33]}]      ;# U62.F7 DQL1
set_property -dict {LOC C19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[34]}]      ;# U62.H3 DQL2
set_property -dict {LOC C18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[35]}]      ;# U62.H7 DQL3
set_property -dict {LOC D20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[36]}]      ;# U62.H2 DQL4
set_property -dict {LOC D19  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[37]}]      ;# U62.H8 DQL5
set_property -dict {LOC C20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[38]}]      ;# U62.J3 DQL6
set_property -dict {LOC B20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[39]}]      ;# U62.J7 DQL7
set_property -dict {LOC N23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[40]}]      ;# U62.A3 DQU0
set_property -dict {LOC M23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[41]}]      ;# U62.B8 DQU1
set_property -dict {LOC R21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[42]}]      ;# U62.C3 DQU2
set_property -dict {LOC P21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[43]}]      ;# U62.C7 DQU3
set_property -dict {LOC R22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[44]}]      ;# U62.C2 DQU4
set_property -dict {LOC P22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[45]}]      ;# U62.C8 DQU5
set_property -dict {LOC T23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[46]}]      ;# U62.D3 DQU6
set_property -dict {LOC R23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[47]}]      ;# U62.D7 DQU7
set_property -dict {LOC A19  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[4]}]    ;# U62.G3 DQSL_T
set_property -dict {LOC A18  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[4]}]    ;# U62.F3 DQSL_C
set_property -dict {LOC N22  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[5]}]    ;# U62.B7 DQSU_T
set_property -dict {LOC M22  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[5]}]    ;# U62.A7 DQSU_C
set_property -dict {LOC B18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[4]}] ;# U62.E7 DML_B/DBIL_B
set_property -dict {LOC P20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[5]}] ;# U62.E2 DMU_B/DBIU_B

set_property -dict {LOC K24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[48]}]      ;# U63.G2 DQL0
set_property -dict {LOC J24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[49]}]      ;# U63.F7 DQL1
set_property -dict {LOC M21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[50]}]      ;# U63.H3 DQL2
set_property -dict {LOC L21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[51]}]      ;# U63.H7 DQL3
set_property -dict {LOC K21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[52]}]      ;# U63.H2 DQL4
set_property -dict {LOC J21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[53]}]      ;# U63.H8 DQL5
set_property -dict {LOC K22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[54]}]      ;# U63.J3 DQL6
set_property -dict {LOC J22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[55]}]      ;# U63.J7 DQL7
set_property -dict {LOC H23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[56]}]      ;# U63.A3 DQU0
set_property -dict {LOC H22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[57]}]      ;# U63.B8 DQU1
set_property -dict {LOC E23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[58]}]      ;# U63.C3 DQU2
set_property -dict {LOC E22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[59]}]      ;# U63.C7 DQU3
set_property -dict {LOC F21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[60]}]      ;# U63.C2 DQU4
set_property -dict {LOC E21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[61]}]      ;# U63.C8 DQU5
set_property -dict {LOC F24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[62]}]      ;# U63.D3 DQU6
set_property -dict {LOC F23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[63]}]      ;# U63.D7 DQU7
set_property -dict {LOC M20  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[6]}]    ;# U63.G3 DQSL_T
set_property -dict {LOC L20  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[6]}]    ;# U63.F3 DQSL_C
set_property -dict {LOC H24  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[7]}]    ;# U63.B7 DQSU_T
set_property -dict {LOC G23  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[7]}]    ;# U63.A7 DQSU_C
set_property -dict {LOC L23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[6]}] ;# U63.E7 DML_B/DBIL_B
set_property -dict {LOC G22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[7]}] ;# U63.E2 DMU_B/DBIU_B

set_property -dict {LOC A24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[64]}]      ;# U64.G2 DQL0
set_property -dict {LOC A23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[65]}]      ;# U64.F7 DQL1
set_property -dict {LOC C24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[66]}]      ;# U64.H3 DQL2
set_property -dict {LOC C23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[67]}]      ;# U64.H7 DQL3
set_property -dict {LOC B23  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[68]}]      ;# U64.H2 DQL4
set_property -dict {LOC B22  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[69]}]      ;# U64.H8 DQL5
set_property -dict {LOC B21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[70]}]      ;# U64.J3 DQL6
set_property -dict {LOC A21  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[71]}]      ;# U64.J7 DQL7
set_property -dict {LOC D7   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[72]}]      ;# U64.A3 DQU0
set_property -dict {LOC C7   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[73]}]      ;# U64.B8 DQU1
set_property -dict {LOC B8   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[74]}]      ;# U64.C3 DQU2
set_property -dict {LOC B7   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[75]}]      ;# U64.C7 DQU3
set_property -dict {LOC C10  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[76]}]      ;# U64.C2 DQU4
set_property -dict {LOC B10  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[77]}]      ;# U64.C8 DQU5
set_property -dict {LOC B11  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[78]}]      ;# U64.D3 DQU6
set_property -dict {LOC A11  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dq[79]}]      ;# U64.D7 DQU7
set_property -dict {LOC D22  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[8]}]    ;# U64.G3 DQSL_T
set_property -dict {LOC C22  IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[8]}]    ;# U64.F3 DQSL_C
set_property -dict {LOC A9   IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_t[9]}]    ;# U64.B7 DQSU_T
set_property -dict {LOC A8   IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c1_dqs_c[9]}]    ;# U64.A7 DQSU_C
set_property -dict {LOC E24  IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[8]}] ;# U64.E7 DML_B/DBIL_B
set_property -dict {LOC C9   IOSTANDARD POD12_DCI      } [get_ports {ddr4_c1_dm_dbi_n[9]}] ;# U64.E2 DMU_B/DBIU_B
