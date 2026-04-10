# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the ADM-PCIE-9V3
# part: xcvu3p-ffvc1517-2-i

# QSFP28 Interfaces
set_property -dict {LOC G38  } [get_ports {qsfp_0_rx_p[0]}] ;# MGTYRXP0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC G39  } [get_ports {qsfp_0_rx_n[0]}] ;# MGTYRXN0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC F35  } [get_ports {qsfp_0_tx_p[0]}] ;# MGTYTXP0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC F36  } [get_ports {qsfp_0_tx_n[0]}] ;# MGTYTXN0_128 GTYE4_CHANNEL_X0Y16 / GTYE4_COMMON_X0Y4
set_property -dict {LOC E38  } [get_ports {qsfp_0_rx_p[1]}] ;# MGTYRXP1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC E39  } [get_ports {qsfp_0_rx_n[1]}] ;# MGTYRXN1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC D35  } [get_ports {qsfp_0_tx_p[1]}] ;# MGTYTXP1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC D36  } [get_ports {qsfp_0_tx_n[1]}] ;# MGTYTXN1_128 GTYE4_CHANNEL_X0Y17 / GTYE4_COMMON_X0Y4
set_property -dict {LOC C38  } [get_ports {qsfp_0_rx_p[2]}] ;# MGTYRXP2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC C39  } [get_ports {qsfp_0_rx_n[2]}] ;# MGTYRXN2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC C33  } [get_ports {qsfp_0_tx_p[2]}] ;# MGTYTXP2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC C34  } [get_ports {qsfp_0_tx_n[2]}] ;# MGTYTXN2_128 GTYE4_CHANNEL_X0Y18 / GTYE4_COMMON_X0Y4
set_property -dict {LOC B36  } [get_ports {qsfp_0_rx_p[3]}] ;# MGTYRXP3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC B37  } [get_ports {qsfp_0_rx_n[3]}] ;# MGTYRXN3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC A33  } [get_ports {qsfp_0_tx_p[3]}] ;# MGTYTXP3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC A34  } [get_ports {qsfp_0_tx_n[3]}] ;# MGTYTXN3_128 GTYE4_CHANNEL_X0Y19 / GTYE4_COMMON_X0Y4
set_property -dict {LOC N33  } [get_ports qsfp_0_mgt_refclk_p] ;# MGTREFCLK0P_128 from ?
set_property -dict {LOC N34  } [get_ports qsfp_0_mgt_refclk_n] ;# MGTREFCLK0N_128 from ?
set_property -dict {LOC F29  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_0_modprs_l]
set_property -dict {LOC D31  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports qsfp_0_sel_l]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name qsfp_0_mgt_refclk [get_ports qsfp_0_mgt_refclk_p]

set_property -dict {LOC R38  } [get_ports {qsfp_1_rx_p[0]}] ;# MGTYRXP0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC R39  } [get_ports {qsfp_1_rx_n[0]}] ;# MGTYRXN0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC P35  } [get_ports {qsfp_1_tx_p[0]}] ;# MGTYTXP0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC P36  } [get_ports {qsfp_1_tx_n[0]}] ;# MGTYTXN0_127 GTYE4_CHANNEL_X0Y12 / GTYE4_COMMON_X0Y3
set_property -dict {LOC N38  } [get_ports {qsfp_1_rx_p[1]}] ;# MGTYRXP1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC N39  } [get_ports {qsfp_1_rx_n[1]}] ;# MGTYRXN1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC M35  } [get_ports {qsfp_1_tx_p[1]}] ;# MGTYTXP1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC M36  } [get_ports {qsfp_1_tx_n[1]}] ;# MGTYTXN1_127 GTYE4_CHANNEL_X0Y13 / GTYE4_COMMON_X0Y3
set_property -dict {LOC L38  } [get_ports {qsfp_1_rx_p[2]}] ;# MGTYRXP2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC L39  } [get_ports {qsfp_1_rx_n[2]}] ;# MGTYRXN2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC K35  } [get_ports {qsfp_1_tx_p[2]}] ;# MGTYTXP2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC K36  } [get_ports {qsfp_1_tx_n[2]}] ;# MGTYTXN2_127 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC J38  } [get_ports {qsfp_1_rx_p[3]}] ;# MGTYRXP3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC J39  } [get_ports {qsfp_1_rx_n[3]}] ;# MGTYRXN3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC H35  } [get_ports {qsfp_1_tx_p[3]}] ;# MGTYTXP3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC H36  } [get_ports {qsfp_1_tx_n[3]}] ;# MGTYTXN3_127 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
#set_property -dict {LOC U33  } [get_ports qsfp_1_mgt_refclk_p] ;# MGTREFCLK0P_127 from ?
#set_property -dict {LOC U34  } [get_ports qsfp_1_mgt_refclk_n] ;# MGTREFCLK0N_127 from ?
set_property -dict {LOC F33  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_1_modprs_l]
set_property -dict {LOC D30  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports qsfp_1_sel_l]

# 161.1328125 MHz MGT reference clock
#create_clock -period 6.206 -name qsfp_1_mgt_refclk [get_ports qsfp_1_mgt_refclk_p]

set_property -dict {LOC B29  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports qsfp_reset_l]
set_property -dict {LOC C29  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp_int_l]
#set_property -dict {LOC A28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp_i2c_scl]
#set_property -dict {LOC A29  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12 PULLUP true} [get_ports qsfp_i2c_sda]

set_false_path -to [get_ports {qsfp_0_sel_l qsfp_1_sel_l qsfp_reset_l}]
set_output_delay 0 [get_ports {qsfp_0_sel_l qsfp_1_sel_l qsfp_reset_l}]
set_false_path -from [get_ports {qsfp_0_modprs_l qsfp_1_modprs_l qsfp_int_l}]
set_input_delay 0 [get_ports {qsfp_0_modprs_l qsfp_1_modprs_l qsfp_int_l}]

#set_false_path -to [get_ports {qsfp_i2c_sda qsfp_i2c_scl}]
#set_output_delay 0 [get_ports {qsfp_i2c_sda qsfp_i2c_scl}]
#set_false_path -from [get_ports {qsfp_i2c_sda qsfp_i2c_scl}]
#set_input_delay 0 [get_ports {qsfp_i2c_sda qsfp_i2c_scl}]
