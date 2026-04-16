# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# DDR4 C2
# 5x MT40A256M16GE-075E
set_property -dict {LOC AM27 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[0]}]
set_property -dict {LOC AL27 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[1]}]
set_property -dict {LOC AP26 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[2]}]
set_property -dict {LOC AP25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[3]}]
set_property -dict {LOC AN28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[4]}]
set_property -dict {LOC AM28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[5]}]
set_property -dict {LOC AP28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[6]}]
set_property -dict {LOC AP27 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[7]}]
set_property -dict {LOC AN26 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[8]}]
set_property -dict {LOC AM26 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[9]}]
set_property -dict {LOC AR28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[10]}]
set_property -dict {LOC AR27 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[11]}]
set_property -dict {LOC AV25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[12]}]
set_property -dict {LOC AT25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[13]}]
set_property -dict {LOC AV28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[14]}]
set_property -dict {LOC AU26 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[15]}]
set_property -dict {LOC AV26 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_adr[16]}]
set_property -dict {LOC AR25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_ba[0]}]
set_property -dict {LOC AU28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_ba[1]}]
set_property -dict {LOC AU27 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_bg[0]}]
set_property -dict {LOC AT26 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c2_ck_t}]
set_property -dict {LOC AT27 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c2_ck_c}]
set_property -dict {LOC AW28 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_cke}]
set_property -dict {LOC AY29 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_cs_n}]
set_property -dict {LOC AN25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_act_n}]
set_property -dict {LOC BB29 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_odt}]
set_property -dict {LOC BF29 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c2_par}]
set_property -dict {LOC BD35 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c2_reset_n}]
set_property -dict {LOC AR29 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c2_alert_n}]
set_property -dict {LOC AY35 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c2_ten}]

set_property -dict {LOC BD30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[0]}]       ;# U135.G2 DQL0
set_property -dict {LOC BE30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[1]}]       ;# U135.F7 DQL1
set_property -dict {LOC BD32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[2]}]       ;# U135.H3 DQL2
set_property -dict {LOC BE33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[3]}]       ;# U135.H7 DQL3
set_property -dict {LOC BC33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[4]}]       ;# U135.H2 DQL4
set_property -dict {LOC BD33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[5]}]       ;# U135.H8 DQL5
set_property -dict {LOC BC31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[6]}]       ;# U135.J3 DQL6
set_property -dict {LOC BD31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[7]}]       ;# U135.J7 DQL7
set_property -dict {LOC BA32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[8]}]       ;# U135.A3 DQU0
set_property -dict {LOC BB33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[9]}]       ;# U135.B8 DQU1
set_property -dict {LOC BA30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[10]}]      ;# U135.C3 DQU2
set_property -dict {LOC BA31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[11]}]      ;# U135.C7 DQU3
set_property -dict {LOC AW31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[12]}]      ;# U135.C2 DQU4
set_property -dict {LOC AW32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[13]}]      ;# U135.C8 DQU5
set_property -dict {LOC AY32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[14]}]      ;# U135.D3 DQU6
set_property -dict {LOC AY33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[15]}]      ;# U135.D7 DQU7
set_property -dict {LOC BF30 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[0]}]    ;# U135.G3 DQSL_T
set_property -dict {LOC BF31 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[0]}]    ;# U135.F3 DQSL_C
set_property -dict {LOC AY34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[1]}]    ;# U135.B7 DQSU_T
set_property -dict {LOC BA34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[1]}]    ;# U135.A7 DQSU_C
set_property -dict {LOC BE32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[0]}] ;# U135.E7 DML_B/DBIL_B
set_property -dict {LOC BB31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[1]}] ;# U135.E2 DMU_B/DBIU_B

set_property -dict {LOC AV30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[16]}]      ;# U136.G2 DQL0
set_property -dict {LOC AW30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[17]}]      ;# U136.F7 DQL1
set_property -dict {LOC AU33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[18]}]      ;# U136.H3 DQL2
set_property -dict {LOC AU34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[19]}]      ;# U136.H7 DQL3
set_property -dict {LOC AT31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[20]}]      ;# U136.H2 DQL4
set_property -dict {LOC AU32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[21]}]      ;# U136.H8 DQL5
set_property -dict {LOC AU31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[22]}]      ;# U136.J3 DQL6
set_property -dict {LOC AV31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[23]}]      ;# U136.J7 DQL7
set_property -dict {LOC AR33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[24]}]      ;# U136.A3 DQU0
set_property -dict {LOC AT34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[25]}]      ;# U136.B8 DQU1
set_property -dict {LOC AT29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[26]}]      ;# U136.C3 DQU2
set_property -dict {LOC AT30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[27]}]      ;# U136.C7 DQU3
set_property -dict {LOC AP30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[28]}]      ;# U136.C2 DQU4
set_property -dict {LOC AR30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[29]}]      ;# U136.C8 DQU5
set_property -dict {LOC AN30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[30]}]      ;# U136.D3 DQU6
set_property -dict {LOC AN31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[31]}]      ;# U136.D7 DQU7
set_property -dict {LOC AU29 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[2]}]    ;# U136.G3 DQSL_T
set_property -dict {LOC AV29 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[2]}]    ;# U136.F3 DQSL_C
set_property -dict {LOC AP31 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[3]}]    ;# U136.B7 DQSU_T
set_property -dict {LOC AP32 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[3]}]    ;# U136.A7 DQSU_C
set_property -dict {LOC AV33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[2]}] ;# U136.E7 DML_B/DBIL_B
set_property -dict {LOC AR32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[3]}] ;# U136.E2 DMU_B/DBIU_B

set_property -dict {LOC BE34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[32]}]      ;# U137.G2 DQL0
set_property -dict {LOC BF34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[33]}]      ;# U137.F7 DQL1
set_property -dict {LOC BC35 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[34]}]      ;# U137.H3 DQL2
set_property -dict {LOC BC36 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[35]}]      ;# U137.H7 DQL3
set_property -dict {LOC BD36 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[36]}]      ;# U137.H2 DQL4
set_property -dict {LOC BE37 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[37]}]      ;# U137.H8 DQL5
set_property -dict {LOC BF36 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[38]}]      ;# U137.J3 DQL6
set_property -dict {LOC BF37 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[39]}]      ;# U137.J7 DQL7
set_property -dict {LOC BD37 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[40]}]      ;# U137.A3 DQU0
set_property -dict {LOC BE38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[41]}]      ;# U137.B8 DQU1
set_property -dict {LOC BC39 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[42]}]      ;# U137.C3 DQU2
set_property -dict {LOC BD40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[43]}]      ;# U137.C7 DQU3
set_property -dict {LOC BB38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[44]}]      ;# U137.C2 DQU4
set_property -dict {LOC BB39 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[45]}]      ;# U137.C8 DQU5
set_property -dict {LOC BC38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[46]}]      ;# U137.D3 DQU6
set_property -dict {LOC BD38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[47]}]      ;# U137.D7 DQU7
set_property -dict {LOC BE35 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[4]}]    ;# U137.G3 DQSL_T
set_property -dict {LOC BF35 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[4]}]    ;# U137.F3 DQSL_C
set_property -dict {LOC BE39 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[5]}]    ;# U137.B7 DQSU_T
set_property -dict {LOC BF39 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[5]}]    ;# U137.A7 DQSU_C
set_property -dict {LOC BC34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[4]}] ;# U137.E7 DML_B/DBIL_B
set_property -dict {LOC BE40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[5]}] ;# U137.E2 DMU_B/DBIU_B

set_property -dict {LOC BB36 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[48]}]      ;# U138.G2 DQL0
set_property -dict {LOC BB37 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[49]}]      ;# U138.F7 DQL1
set_property -dict {LOC BA39 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[50]}]      ;# U138.H3 DQL2
set_property -dict {LOC BA40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[51]}]      ;# U138.H7 DQL3
set_property -dict {LOC AW40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[52]}]      ;# U138.H2 DQL4
set_property -dict {LOC AY40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[53]}]      ;# U138.H8 DQL5
set_property -dict {LOC AY38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[54]}]      ;# U138.J3 DQL6
set_property -dict {LOC AY39 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[55]}]      ;# U138.J7 DQL7
set_property -dict {LOC AW35 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[56]}]      ;# U138.A3 DQU0
set_property -dict {LOC AW36 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[57]}]      ;# U138.B8 DQU1
set_property -dict {LOC AU40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[58]}]      ;# U138.C3 DQU2
set_property -dict {LOC AV40 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[59]}]      ;# U138.C7 DQU3
set_property -dict {LOC AU38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[60]}]      ;# U138.C2 DQU4
set_property -dict {LOC AU39 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[61]}]      ;# U138.C8 DQU5
set_property -dict {LOC AV38 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[62]}]      ;# U138.D3 DQU6
set_property -dict {LOC AV39 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[63]}]      ;# U138.D7 DQU7
set_property -dict {LOC BA35 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[6]}]    ;# U138.G3 DQSL_T
set_property -dict {LOC BA36 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[6]}]    ;# U138.F3 DQSL_C
set_property -dict {LOC AW37 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[7]}]    ;# U138.B7 DQSU_T
set_property -dict {LOC AW38 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[7]}]    ;# U138.A7 DQSU_C
set_property -dict {LOC AY37 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[6]}] ;# U138.E7 DML_B/DBIL_B
set_property -dict {LOC AV35 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[7]}] ;# U138.E2 DMU_B/DBIU_B

set_property -dict {LOC BF26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[64]}]      ;# U139.G2 DQL0
set_property -dict {LOC BF27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[65]}]      ;# U139.F7 DQL1
set_property -dict {LOC BD28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[66]}]      ;# U139.H3 DQL2
set_property -dict {LOC BE28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[67]}]      ;# U139.H7 DQL3
set_property -dict {LOC BD27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[68]}]      ;# U139.H2 DQL4
set_property -dict {LOC BE27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[69]}]      ;# U139.H8 DQL5
set_property -dict {LOC BD25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[70]}]      ;# U139.J3 DQL6
set_property -dict {LOC BD26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[71]}]      ;# U139.J7 DQL7
set_property -dict {LOC BC25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[72]}]      ;# U139.A3 DQU0
set_property -dict {LOC BC26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[73]}]      ;# U139.B8 DQU1
set_property -dict {LOC BB28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[74]}]      ;# U139.C3 DQU2
set_property -dict {LOC BC28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[75]}]      ;# U139.C7 DQU3
set_property -dict {LOC AY27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[76]}]      ;# U139.C2 DQU4
set_property -dict {LOC AY28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[77]}]      ;# U139.C8 DQU5
set_property -dict {LOC BA27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[78]}]      ;# U139.D3 DQU6
set_property -dict {LOC BB27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dq[79]}]      ;# U139.D7 DQU7
set_property -dict {LOC BE25 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[8]}]    ;# U139.G3 DQSL_T
set_property -dict {LOC BF25 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[8]}]    ;# U139.F3 DQSL_C
set_property -dict {LOC BA26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_t[9]}]    ;# U139.B7 DQSU_T
set_property -dict {LOC BB26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c2_dqs_c[9]}]    ;# U139.A7 DQSU_C
set_property -dict {LOC BE29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[8]}] ;# U139.E7 DML_B/DBIL_B
set_property -dict {LOC BA29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c2_dm_dbi_n[9]}] ;# U139.E2 DMU_B/DBIU_B
