# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# DDR4 C0
# 4x MT40A256M16GE-075E
set_property -dict {LOC AE17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[0]}]
set_property -dict {LOC AH17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[1]}]
set_property -dict {LOC AE18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[2]}]
set_property -dict {LOC AJ15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[3]}]
set_property -dict {LOC AG16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[4]}]
set_property -dict {LOC AL17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[5]}]
set_property -dict {LOC AK18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[6]}]
set_property -dict {LOC AG17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[7]}]
set_property -dict {LOC AF18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[8]}]
set_property -dict {LOC AH19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[9]}]
set_property -dict {LOC AF15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[10]}]
set_property -dict {LOC AD19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[11]}]
set_property -dict {LOC AJ14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[12]}]
set_property -dict {LOC AG19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[13]}]
set_property -dict {LOC AD16 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[14]}]
set_property -dict {LOC AG14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[15]}]
set_property -dict {LOC AF14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_adr[16]}]
set_property -dict {LOC AF17 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_ba[0]}]
set_property -dict {LOC AL15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_ba[1]}]
set_property -dict {LOC AG15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_bg[0]}]
set_property -dict {LOC AE16 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c0_ck_t}]
set_property -dict {LOC AE15 IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_c0_ck_c}]
set_property -dict {LOC AD15 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_cke}]
set_property -dict {LOC AL19 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_cs_n}]
set_property -dict {LOC AH14 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_act_n}]
set_property -dict {LOC AJ18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_odt}]
set_property -dict {LOC AD18 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_c0_par}]
set_property -dict {LOC AL18 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c0_reset_n}]
set_property -dict {LOC AJ16 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c0_alert_n}]
set_property -dict {LOC AH16 IOSTANDARD LVCMOS12       } [get_ports {ddr4_c0_ten}]

set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[0]}]       ;# U60.G2 DQL0
set_property -dict {LOC AG20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[1]}]       ;# U60.F7 DQL1
set_property -dict {LOC AF22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[2]}]       ;# U60.H3 DQL2
set_property -dict {LOC AF20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[3]}]       ;# U60.H7 DQL3
set_property -dict {LOC AE22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[4]}]       ;# U60.H2 DQL4
set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[5]}]       ;# U60.H8 DQL5
set_property -dict {LOC AG22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[6]}]       ;# U60.J3 DQL6
set_property -dict {LOC AE20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[7]}]       ;# U60.J7 DQL7
set_property -dict {LOC AJ24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[8]}]       ;# U60.A3 DQU0
set_property -dict {LOC AG24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[9]}]       ;# U60.B8 DQU1
set_property -dict {LOC AJ23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[10]}]      ;# U60.C3 DQU2
set_property -dict {LOC AF23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[11]}]      ;# U60.C7 DQU3
set_property -dict {LOC AH23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[12]}]      ;# U60.C2 DQU4
set_property -dict {LOC AF24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[13]}]      ;# U60.C8 DQU5
set_property -dict {LOC AH22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[14]}]      ;# U60.D3 DQU6
set_property -dict {LOC AG25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[15]}]      ;# U60.D7 DQU7
set_property -dict {LOC AG21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[0]}]    ;# U60.G3 DQSL_T
set_property -dict {LOC AH21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[0]}]    ;# U60.F3 DQSL_C
set_property -dict {LOC AH24 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[1]}]    ;# U60.B7 DQSU_T
set_property -dict {LOC AJ25 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[1]}]    ;# U60.A7 DQSU_C
set_property -dict {LOC AD21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[0]}] ;# U60.E7 DML_B/DBIL_B
set_property -dict {LOC AE25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[1]}] ;# U60.E2 DMU_B/DBIU_B

set_property -dict {LOC AL22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[16]}]      ;# U61.G2 DQL0
set_property -dict {LOC AL25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[17]}]      ;# U61.F7 DQL1
set_property -dict {LOC AM20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[18]}]      ;# U61.H3 DQL2
set_property -dict {LOC AK23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[19]}]      ;# U61.H7 DQL3
set_property -dict {LOC AK22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[20]}]      ;# U61.H2 DQL4
set_property -dict {LOC AL24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[21]}]      ;# U61.H8 DQL5
set_property -dict {LOC AL20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[22]}]      ;# U61.J3 DQL6
set_property -dict {LOC AL23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[23]}]      ;# U61.J7 DQL7
set_property -dict {LOC AM24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[24]}]      ;# U61.A3 DQU0
set_property -dict {LOC AN23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[25]}]      ;# U61.B8 DQU1
set_property -dict {LOC AN24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[26]}]      ;# U61.C3 DQU2
set_property -dict {LOC AP23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[27]}]      ;# U61.C7 DQU3
set_property -dict {LOC AP25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[28]}]      ;# U61.C2 DQU4
set_property -dict {LOC AN22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[29]}]      ;# U61.C8 DQU5
set_property -dict {LOC AP24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[30]}]      ;# U61.D3 DQU6
set_property -dict {LOC AM22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[31]}]      ;# U61.D7 DQU7
set_property -dict {LOC AJ20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[2]}]    ;# U61.G3 DQSL_T
set_property -dict {LOC AK20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[2]}]    ;# U61.F3 DQSL_C
set_property -dict {LOC AP20 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[3]}]    ;# U61.B7 DQSU_T
set_property -dict {LOC AP21 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[3]}]    ;# U61.A7 DQSU_C
set_property -dict {LOC AJ21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[2]}] ;# U61.E7 DML_B/DBIL_B
set_property -dict {LOC AM21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[3]}] ;# U61.E2 DMU_B/DBIU_B

set_property -dict {LOC AH28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[32]}]      ;# U62.G2 DQL0
set_property -dict {LOC AK26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[33]}]      ;# U62.F7 DQL1
set_property -dict {LOC AK28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[34]}]      ;# U62.H3 DQL2
set_property -dict {LOC AM27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[35]}]      ;# U62.H7 DQL3
set_property -dict {LOC AJ28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[36]}]      ;# U62.H2 DQL4
set_property -dict {LOC AH27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[37]}]      ;# U62.H8 DQL5
set_property -dict {LOC AK27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[38]}]      ;# U62.J3 DQL6
set_property -dict {LOC AM26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[39]}]      ;# U62.J7 DQL7
set_property -dict {LOC AL30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[40]}]      ;# U62.A3 DQU0
set_property -dict {LOC AP29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[41]}]      ;# U62.B8 DQU1
set_property -dict {LOC AM30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[42]}]      ;# U62.C3 DQU2
set_property -dict {LOC AN28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[43]}]      ;# U62.C7 DQU3
set_property -dict {LOC AL29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[44]}]      ;# U62.C2 DQU4
set_property -dict {LOC AP28 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[45]}]      ;# U62.C8 DQU5
set_property -dict {LOC AM29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[46]}]      ;# U62.D3 DQU6
set_property -dict {LOC AN27 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[47]}]      ;# U62.D7 DQU7
set_property -dict {LOC AL27 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[4]}]    ;# U62.G3 DQSL_T
set_property -dict {LOC AL28 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[4]}]    ;# U62.F3 DQSL_C
set_property -dict {LOC AN29 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[5]}]    ;# U62.B7 DQSU_T
set_property -dict {LOC AP30 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[5]}]    ;# U62.A7 DQSU_C
set_property -dict {LOC AH26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[4]}] ;# U62.E7 DML_B/DBIL_B
set_property -dict {LOC AN26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[5]}] ;# U62.E2 DMU_B/DBIU_B

set_property -dict {LOC AH31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[48]}]      ;# U63.G2 DQL0
set_property -dict {LOC AH32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[49]}]      ;# U63.F7 DQL1
set_property -dict {LOC AJ34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[50]}]      ;# U63.H3 DQL2
set_property -dict {LOC AK31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[51]}]      ;# U63.H7 DQL3
set_property -dict {LOC AJ31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[52]}]      ;# U63.H2 DQL4
set_property -dict {LOC AJ30 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[53]}]      ;# U63.H8 DQL5
set_property -dict {LOC AH34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[54]}]      ;# U63.J3 DQL6
set_property -dict {LOC AK32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[55]}]      ;# U63.J7 DQL7
set_property -dict {LOC AN33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[56]}]      ;# U63.A3 DQU0
set_property -dict {LOC AP33 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[57]}]      ;# U63.B8 DQU1
set_property -dict {LOC AM34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[58]}]      ;# U63.C3 DQU2
set_property -dict {LOC AP31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[59]}]      ;# U63.C7 DQU3
set_property -dict {LOC AM32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[60]}]      ;# U63.C2 DQU4
set_property -dict {LOC AN31 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[61]}]      ;# U63.C8 DQU5
set_property -dict {LOC AL34 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[62]}]      ;# U63.D3 DQU6
set_property -dict {LOC AN32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dq[63]}]      ;# U63.D7 DQU7
set_property -dict {LOC AH33 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[6]}]    ;# U63.G3 DQSL_T
set_property -dict {LOC AJ33 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[6]}]    ;# U63.F3 DQSL_C
set_property -dict {LOC AN34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_t[7]}]    ;# U63.B7 DQSU_T
set_property -dict {LOC AP34 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_c0_dqs_c[7]}]    ;# U63.A7 DQSU_C
set_property -dict {LOC AJ29 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[6]}] ;# U63.E7 DML_B/DBIL_B
set_property -dict {LOC AL32 IOSTANDARD POD12_DCI      } [get_ports {ddr4_c0_dm_dbi_n[7]}] ;# U63.E2 DMU_B/DBIU_B
