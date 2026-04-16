# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the RK-XCKU5P-F
# part: xcku5p-ffvb676-2-e

# Gigabit Ethernet RGMII PHY
set_property -dict {LOC K22  IOSTANDARD LVCMOS18} [get_ports {phy_rx_clk}] ;# from U16.28 RXC
set_property -dict {LOC L24  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[0]}] ;# from U16.26 RXD0
set_property -dict {LOC L25  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[1]}] ;# from U16.25 RXD1
set_property -dict {LOC K25  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[2]}] ;# from U16.24 RXD2
set_property -dict {LOC K26  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[3]}] ;# from U16.23 RXD3
set_property -dict {LOC K23  IOSTANDARD LVCMOS18} [get_ports {phy_rx_ctl}] ;# from U16.27 RXCTL
set_property -dict {LOC M25  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_tx_clk}] ;# from U16.21 TXC
set_property -dict {LOC L23  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[0]}] ;# from U16.19 TXD0
set_property -dict {LOC L22  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[1]}] ;# from U16.18 TXD1
set_property -dict {LOC L20  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[2]}] ;# from U16.17 TXD2
set_property -dict {LOC K20  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[3]}] ;# from U16.16 TXD3
set_property -dict {LOC M26  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_tx_ctl}] ;# from U16.20 TXCTL
set_property -dict {LOC M19  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {phy_mdio}] ;# from U16.14 MDIO
set_property -dict {LOC L19  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {phy_mdc}] ;# from U16.13 MDC

create_clock -period 8.000 -name {phy_rx_clk} [get_ports {phy_rx_clk}]
