# SPDX-License-Identifier: MIT
#
# Copyright (c) 2014-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx VCU118 board
# part: xcvu9p-flga2104-2L-e

# Gigabit Ethernet SGMII PHY
set_property -dict {LOC AU24 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {phy_sgmii_rx_p}]
set_property -dict {LOC AV24 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {phy_sgmii_rx_n}]
set_property -dict {LOC AU21 IOSTANDARD LVDS} [get_ports {phy_sgmii_tx_p}]
set_property -dict {LOC AV21 IOSTANDARD LVDS} [get_ports {phy_sgmii_tx_n}]
set_property -dict {LOC AT22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {phy_sgmii_clk_p}]
set_property -dict {LOC AU22 IOSTANDARD LVDS DIFF_TERM_ADV TERM_100} [get_ports {phy_sgmii_clk_n}]
set_property -dict {LOC BA21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {phy_reset_n}]
set_property -dict {LOC AR24 IOSTANDARD LVCMOS18} [get_ports {phy_int_n}]
set_property -dict {LOC AR23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {phy_mdio}]
set_property -dict {LOC AV23 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {phy_mdc}]

# 625 MHz ref clock from SGMII PHY
#create_clock -period 1.600 -name phy_sgmii_clk [get_ports phy_sgmii_clk_p]

set_false_path -to [get_ports {phy_reset_n phy_mdio phy_mdc}]
set_output_delay 0 [get_ports {phy_reset_n phy_mdio phy_mdc}]
set_false_path -from [get_ports {phy_int_n phy_mdio}]
set_input_delay 0 [get_ports {phy_int_n phy_mdio}]
