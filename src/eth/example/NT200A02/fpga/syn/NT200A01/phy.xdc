# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A01 board
# part: xcvu095-ffva2104-2-e

# Gigabit PHY (DP83867)
set_property -dict {LOC P12  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports phy_gtx_clk] ;# U198.29 GTX_CLK via ?
set_property -dict {LOC P15  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports phy_tx_ctl] ;# U198.37 TX_CTRL via ?
set_property -dict {LOC R11  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[0]}] ;# U198.28 TX_D0/SGMII_SIN via ?
set_property -dict {LOC R12  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[1]}] ;# U198.27 TX_D1/SGMII_SIP via ?
set_property -dict {LOC P11  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[2]}] ;# U198.26 TX_D2 via ?
set_property -dict {LOC N12  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[3]}] ;# U198.25 TX_D3 via ?
set_property -dict {LOC U13  IOSTANDARD LVCMOS18} [get_ports phy_rx_clk] ;# U198.32 RX_CLK via ?
set_property -dict {LOC U16  IOSTANDARD LVCMOS18} [get_ports phy_rx_ctl] ;# U198.38 RX_CTRL via ?
set_property -dict {LOC T11  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[0]}] ;# U198.33 RX_D0/SGMII_COP via ?
set_property -dict {LOC U11  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[1]}] ;# U198.34 RX_D1/SGMII_CON via ?
set_property -dict {LOC R13  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[2]}] ;# U198.35 RX_D2/SGMII_SOP via ?
set_property -dict {LOC V15  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[3]}] ;# U198.36 RX_D3/SGMII_SON via ?
set_property -dict {LOC J11  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports phy_refclk] ;# U198.15 XI 25 MHz
set_property -dict {LOC T14  IOSTANDARD LVCMOS18} [get_ports phy_clk_out] ;# U198.18 CLK_OUT
set_property -dict {LOC M11  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_reset_n] ;# U198.43 RESET_N
set_property -dict {LOC V16  IOSTANDARD LVCMOS18} [get_ports phy_int_n] ;# U198.44 PWRDOWN/INTN
set_property -dict {LOC U12  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_mdc] ;# U198.16 MDC
set_property -dict {LOC J12  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_mdio] ;# U198.17 MDIO
set_property -dict {LOC L14  IOSTANDARD LVCMOS18} [get_ports phy_gpio0] ;# U198.39 GPIO_0
set_property -dict {LOC M12  IOSTANDARD LVCMOS18} [get_ports phy_gpio1] ;# U198.40 GPIO_1
set_property -dict {LOC L15  IOSTANDARD LVCMOS18} [get_ports phy_led0] ;# U198.47 LED_0
set_property -dict {LOC W14  IOSTANDARD LVCMOS18} [get_ports phy_led1] ;# U198.46 LED_1
set_property -dict {LOC K14  IOSTANDARD LVCMOS18} [get_ports phy_led2] ;# U198.45 LED_2
