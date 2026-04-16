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

# PCIe Interface
set_property -dict {LOC J33 } [get_ports {pcie_tx_p[0]}] ;# MGTYTXP3_129 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC J34 } [get_ports {pcie_tx_n[0]}] ;# MGTYTXN3_129 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC K36 } [get_ports {pcie_rx_p[0]}] ;# MGTYRXP3_129 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC K37 } [get_ports {pcie_rx_n[0]}] ;# MGTYRXN3_129 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
set_property -dict {LOC L33 } [get_ports {pcie_tx_p[1]}] ;# MGTYTXP2_129 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC L34 } [get_ports {pcie_tx_n[1]}] ;# MGTYTXN2_129 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC L38 } [get_ports {pcie_rx_p[1]}] ;# MGTYRXP2_129 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC L39 } [get_ports {pcie_rx_n[1]}] ;# MGTYRXN2_129 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
set_property -dict {LOC N33 } [get_ports {pcie_tx_p[2]}] ;# MGTYTXP1_129 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC N34 } [get_ports {pcie_tx_n[2]}] ;# MGTYTXN1_129 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC M36 } [get_ports {pcie_rx_p[2]}] ;# MGTYRXP1_129 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC M37 } [get_ports {pcie_rx_n[2]}] ;# MGTYRXN1_129 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P35 } [get_ports {pcie_tx_p[3]}] ;# MGTYTXP0_129 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC P36 } [get_ports {pcie_tx_n[3]}] ;# MGTYTXN0_129 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC N38 } [get_ports {pcie_rx_p[3]}] ;# MGTYRXP0_129 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC N39 } [get_ports {pcie_rx_n[3]}] ;# MGTYRXN0_129 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
set_property -dict {LOC R33 } [get_ports {pcie_tx_p[4]}] ;# MGTYTXP3_128 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC R34 } [get_ports {pcie_tx_n[4]}] ;# MGTYTXN3_128 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC R38 } [get_ports {pcie_rx_p[4]}] ;# MGTYRXP3_128 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC R39 } [get_ports {pcie_rx_n[4]}] ;# MGTYRXN3_128 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
set_property -dict {LOC T35 } [get_ports {pcie_tx_p[5]}] ;# MGTYTXP2_128 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC T36 } [get_ports {pcie_tx_n[5]}] ;# MGTYTXN2_128 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC U38 } [get_ports {pcie_rx_p[5]}] ;# MGTYRXP2_128 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC U39 } [get_ports {pcie_rx_n[5]}] ;# MGTYRXN2_128 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
set_property -dict {LOC V35 } [get_ports {pcie_tx_p[6]}] ;# MGTYTXP1_128 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC V36 } [get_ports {pcie_tx_n[6]}] ;# MGTYTXN1_128 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC W38 } [get_ports {pcie_rx_p[6]}] ;# MGTYRXP1_128 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC W39 } [get_ports {pcie_rx_n[6]}] ;# MGTYRXN1_128 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
set_property -dict {LOC Y35 } [get_ports {pcie_tx_p[7]}] ;# MGTYTXP0_128 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC Y36 } [get_ports {pcie_tx_n[7]}] ;# MGTYTXN0_128 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AA38} [get_ports {pcie_rx_p[7]}] ;# MGTYRXP0_128 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AA39} [get_ports {pcie_rx_n[7]}] ;# MGTYRXN0_128 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
set_property -dict {LOC AA33} [get_ports pcie_refclk_p] ;# MGTREFCLK0P_128
set_property -dict {LOC AA34} [get_ports pcie_refclk_n] ;# MGTREFCLK0N_128
set_property -dict {LOC AJ13 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset_n]

# 100 MHz MGT reference clock
create_clock -period 10.000 -name pcie_mgt_refclk [get_ports pcie_refclk_p]

set_false_path -from [get_ports {pcie_reset_n}]
set_input_delay 0 [get_ports {pcie_reset_n}]
