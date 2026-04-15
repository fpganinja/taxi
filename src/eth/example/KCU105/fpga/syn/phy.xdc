# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Xilinx KCU105 board
# part: xcku040-ffva1156-2-e

# Gigabit Ethernet SGMII PHY
set_property -dict {LOC P24  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_rx_p]
set_property -dict {LOC P25  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_rx_n]
set_property -dict {LOC N24  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_tx_p]
set_property -dict {LOC M24  IOSTANDARD DIFF_HSTL_I_18} [get_ports phy_sgmii_tx_n]
set_property -dict {LOC P26  IOSTANDARD LVDS_25} [get_ports phy_sgmii_clk_p]
set_property -dict {LOC N26  IOSTANDARD LVDS_25} [get_ports phy_sgmii_clk_n]
set_property -dict {LOC J23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports phy_reset_n]
set_property -dict {LOC K25  IOSTANDARD LVCMOS18} [get_ports phy_int_n]
#set_property -dict {LOC H26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports phy_mdio]
#set_property -dict {LOC L25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports phy_mdc]

# 625 MHz ref clock from SGMII PHY
#create_clock -period 1.600 -name phy_sgmii_clk [get_ports phy_sgmii_clk_p]

set_false_path -to [get_ports {phy_reset_n}]
set_output_delay 0 [get_ports {phy_reset_n}]
set_false_path -from [get_ports {phy_int_n}]
set_input_delay 0 [get_ports {phy_int_n}]

#set_false_path -to [get_ports {phy_mdio phy_mdc}]
#set_output_delay 0 [get_ports {phy_mdio phy_mdc}]
#set_false_path -from [get_ports {phy_mdio}]
#set_input_delay 0 [get_ports {phy_mdio}]
