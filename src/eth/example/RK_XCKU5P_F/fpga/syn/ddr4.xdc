# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# DDR4
# 2x MT40A512M16LY-062E:E U3, U6
set_property -dict {LOC Y22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[0]}]
set_property -dict {LOC Y25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[1]}]
set_property -dict {LOC W23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[2]}]
set_property -dict {LOC V26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[3]}]
set_property -dict {LOC R26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[4]}]
set_property -dict {LOC U26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[5]}]
set_property -dict {LOC R21  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[6]}]
set_property -dict {LOC W25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[7]}]
set_property -dict {LOC R20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[8]}]
set_property -dict {LOC Y26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[9]}]
set_property -dict {LOC R25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[10]}]
set_property -dict {LOC V23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[11]}]
set_property -dict {LOC AA24 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[12]}]
set_property -dict {LOC W26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[13]}]
set_property -dict {LOC P23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[14]}]
set_property -dict {LOC AA25 IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[15]}]
set_property -dict {LOC T25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_adr[16]}]
set_property -dict {LOC P21  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[0]}]
set_property -dict {LOC P26  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_ba[1]}]
set_property -dict {LOC R22  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_bg[0]}]
set_property -dict {LOC V24  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_t}]
set_property -dict {LOC W24  IOSTANDARD DIFF_SSTL12_DCI} [get_ports {ddr4_ck_c}]
set_property -dict {LOC P20  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cke}]
set_property -dict {LOC P25  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_cs_n}]
set_property -dict {LOC P24  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_act_n}]
set_property -dict {LOC R23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_odt}]
set_property -dict {LOC Y23  IOSTANDARD SSTL12_DCI     } [get_ports {ddr4_par}]
set_property -dict {LOC P19  IOSTANDARD LVCMOS12       } [get_ports {ddr4_reset_n}]
set_property -dict {LOC U25  IOSTANDARD LVCMOS12       } [get_ports {ddr4_alert_n}]

set_property -dict {LOC AB26 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[0]}]
set_property -dict {LOC AB25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[1]}]
set_property -dict {LOC AF25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[2]}]
set_property -dict {LOC AF24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[3]}]
set_property -dict {LOC AD25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[4]}]
set_property -dict {LOC AD24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[5]}]
set_property -dict {LOC AC24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[6]}]
set_property -dict {LOC AB24 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[7]}]
set_property -dict {LOC AE23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[8]}]
set_property -dict {LOC AD23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[9]}]
set_property -dict {LOC AC23 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[10]}]
set_property -dict {LOC AC22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[11]}]
set_property -dict {LOC AE21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[12]}]
set_property -dict {LOC AD21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[13]}]
set_property -dict {LOC AC21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[14]}]
set_property -dict {LOC AB21 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[15]}]
set_property -dict {LOC AC26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[0]}]     ;# U3.G3 DQSL_T
set_property -dict {LOC AD26 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[0]}]     ;# U3.F3 DQSL_C
set_property -dict {LOC AA22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[1]}]     ;# U3.B7 DQSU_T
set_property -dict {LOC AB22 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[1]}]     ;# U3.A7 DQSU_C
set_property -dict {LOC AE25 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[0]}]  ;# U3.E7 DML_B/DBIL_B
set_property -dict {LOC AE22 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[1]}]  ;# U3.E2 DMU_B/DBIU_B

set_property -dict {LOC AD19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[16]}]
set_property -dict {LOC AC19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[17]}]
set_property -dict {LOC AF19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[18]}]
set_property -dict {LOC AF18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[19]}]
set_property -dict {LOC AF17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[20]}]
set_property -dict {LOC AE17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[21]}]
set_property -dict {LOC AE16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[22]}]
set_property -dict {LOC AD16 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[23]}]
set_property -dict {LOC AB19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[24]}]
set_property -dict {LOC AA19 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[25]}]
set_property -dict {LOC AB20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[26]}]
set_property -dict {LOC AA20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[27]}]
set_property -dict {LOC AA17 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[28]}]
set_property -dict {LOC Y17  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[29]}]
set_property -dict {LOC AA18 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[30]}]
set_property -dict {LOC Y18  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dq[31]}]
set_property -dict {LOC AC18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[2]}]     ;# U6.G3 DQSL_T
set_property -dict {LOC AD18 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[2]}]     ;# U6.F3 DQSL_C
set_property -dict {LOC AB17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_t[3]}]     ;# U6.B7 DQSU_T
set_property -dict {LOC AC17 IOSTANDARD DIFF_POD12_DCI } [get_ports {ddr4_dqs_c[3]}]     ;# U6.A7 DQSU_C
set_property -dict {LOC AD20 IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[2]}]  ;# U6.E7 DML_B/DBIL_B
set_property -dict {LOC Y20  IOSTANDARD POD12_DCI      } [get_ports {ddr4_dm_dbi_n[3]}]  ;# U6.E2 DMU_B/DBIU_B
