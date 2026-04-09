# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Alibaba AS02MC04
# part: xcku3p-ffvb676-1-e

# PCIe Interface
set_property -dict {LOC P2  } [get_ports {pcie_rx_p[0]}] ;# MGTYRXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P1  } [get_ports {pcie_rx_n[0]}] ;# MGTYRXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R5  } [get_ports {pcie_tx_p[0]}] ;# MGTYTXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R4  } [get_ports {pcie_tx_n[0]}] ;# MGTYTXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T2  } [get_ports {pcie_rx_p[1]}] ;# MGTYRXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC T1  } [get_ports {pcie_rx_n[1]}] ;# MGTYRXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U5  } [get_ports {pcie_tx_p[1]}] ;# MGTYTXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC U4  } [get_ports {pcie_tx_n[1]}] ;# MGTYTXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V2  } [get_ports {pcie_rx_p[2]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC V1  } [get_ports {pcie_rx_n[2]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W5  } [get_ports {pcie_tx_p[2]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC W4  } [get_ports {pcie_tx_n[2]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC Y2  } [get_ports {pcie_rx_p[3]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC Y1  } [get_ports {pcie_rx_n[3]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA5 } [get_ports {pcie_tx_p[3]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AA4 } [get_ports {pcie_tx_n[3]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[4]}] ;# MGTYRXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[4]}] ;# MGTYRXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AC5 } [get_ports {pcie_tx_p[4]}] ;# MGTYTXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AC4 } [get_ports {pcie_tx_n[4]}] ;# MGTYTXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[5]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[5]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD7 } [get_ports {pcie_tx_p[5]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AD6 } [get_ports {pcie_tx_n[5]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE4 } [get_ports {pcie_rx_p[6]}] ;# MGTYRXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE3 } [get_ports {pcie_rx_n[6]}] ;# MGTYRXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE9 } [get_ports {pcie_tx_p[6]}] ;# MGTYTXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AE8 } [get_ports {pcie_tx_n[6]}] ;# MGTYTXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[7]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[7]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[7]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[7]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC T7  } [get_ports pcie_refclk_p] ;# MGTREFCLK1P_225
set_property -dict {LOC T6  } [get_ports pcie_refclk_n] ;# MGTREFCLK1N_225
set_property -dict {LOC A9 IOSTANDARD LVCMOS33 PULLUP true} [get_ports pcie_reset_n]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]

# 100 MHz MGT reference clock
create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_p]
