# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Napatech NT200A01 board
# part: xcvu095-ffva2104-2-e

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN {DIV-1} [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4           [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP         [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# 50 MHz system clock
set_property -dict {LOC AK34 IOSTANDARD LVCMOS18} [get_ports clk_50mhz] ;# U10
create_clock -period 20.000 -name clk_50mhz [get_ports clk_50mhz]

# 80 MHz EMCCLK
#set_property -dict {LOC AL20 IOSTANDARD LVCMOS18} [get_ports clk_80mhz] ;# U9
#create_clock -period 12.500 -name clk_80mhz [get_ports clk_80mhz]

# 20 MHz reference clock
#set_property -dict {LOC AM33 IOSTANDARD LVCMOS18} [get_ports clk_20mhz] ;# U201/U22
#create_clock -period 12.500 -name clk_20mhz [get_ports clk_20mhz]

# 100 MHz DDR4 C0 clock from Si5340 OUT0 via U167
#set_property -dict {LOC BA19 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c0_p]
#set_property -dict {LOC AY19 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c0_n]
#create_clock -period 10.000 -name clk_ddr_c0 [get_ports clk_ddr_c0_p]

# 100 MHz DDR4 C1 clock from Si5340 OUT0 via U167
#set_property -dict {LOC BB39 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c1_p]
#set_property -dict {LOC BB38 IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c1_n]
#create_clock -period 10.000 -name clk_ddr_c1 [get_ports clk_ddr_c1_p]

# 100 MHz DDR4 C2 clock from Si5340 OUT0 via U167
#set_property -dict {LOC B10  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c2_p]
#set_property -dict {LOC C10  IOSTANDARD DIFF_SSTL12_DCI ODT RTT_48} [get_ports clk_ddr_c2_n]
#create_clock -period 10.000 -name clk_ddr_c2 [get_ports clk_ddr_c2_p]

# LEDs
set_property -dict {LOC R26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[0]}] ;# D5
set_property -dict {LOC M28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[1]}] ;# D6
set_property -dict {LOC R27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[2]}] ;# D7
set_property -dict {LOC T24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led[3]}] ;# D8
set_property -dict {LOC J27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][0]}] ;# D16
set_property -dict {LOC K27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][1]}] ;# D17
set_property -dict {LOC L25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][2]}] ;# D18
set_property -dict {LOC L24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[0][3]}] ;# D29
set_property -dict {LOC B28  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][0]}] ;# D27
set_property -dict {LOC C27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][1]}] ;# D28
set_property -dict {LOC J25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][2]}] ;# D29
set_property -dict {LOC K26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {qsfp_led[1][3]}] ;# D30
set_property -dict {LOC D27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_red}] ;# D52
set_property -dict {LOC D26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_green}] ;# D52
set_property -dict {LOC AN21 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_sync[0]}] ;# D54
set_property -dict {LOC AT24 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {led_sync[1]}] ;# D56
set_property -dict {LOC M15  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {eth_led_yellow}] ;# J28
set_property -dict {LOC M13  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports {eth_led_green}] ;# J28

set_false_path -to [get_ports {led[*] qsfp_led[*][*] led_red led_green led_sync[*] eth_led_yellow eth_led_green}]
set_output_delay 0 [get_ports {led[*] qsfp_led[*][*] led_red led_green led_sync[*] eth_led_yellow eth_led_green}]

# Si5340 U18
set_property -dict {LOC AT36 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports si5340_i2c_scl] ;# U23.14 SCLK
set_property -dict {LOC AT35 IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports si5340_i2c_sda] ;# U23.13 SDA
set_property -dict {LOC AT37 IOSTANDARD LVCMOS18} [get_ports si5340_intr] ;# U18.33 INTR

set_false_path -to [get_ports {si5340_i2c_scl si5340_i2c_sda}]
set_output_delay 0 [get_ports {si5340_i2c_scl si5340_i2c_sda}]
set_false_path -from [get_ports {si5340_i2c_scl si5340_i2c_sda si5340_intr}]
set_input_delay 0 [get_ports {si5340_i2c_scl si5340_i2c_sda si5340_intr}]

# Gigabit PHY (DP83867)
#set_property -dict {LOC P12  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports phy_gtx_clk] ;# U198.29 GTX_CLK via ?
#set_property -dict {LOC P15  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports phy_tx_ctl] ;# U198.37 TX_CTRL via ?
#set_property -dict {LOC R11  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[0]}] ;# U198.28 TX_D0/SGMII_SIN via ?
#set_property -dict {LOC R12  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[1]}] ;# U198.27 TX_D1/SGMII_SIP via ?
#set_property -dict {LOC P11  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[2]}] ;# U198.26 TX_D2 via ?
#set_property -dict {LOC N12  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports {phy_txd[3]}] ;# U198.25 TX_D3 via ?
#set_property -dict {LOC U13  IOSTANDARD LVCMOS18} [get_ports phy_rx_clk] ;# U198.32 RX_CLK via ?
#set_property -dict {LOC U16  IOSTANDARD LVCMOS18} [get_ports phy_rx_ctl] ;# U198.38 RX_CTRL via ?
#set_property -dict {LOC T11  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[0]}] ;# U198.33 RX_D0/SGMII_COP via ?
#set_property -dict {LOC U11  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[1]}] ;# U198.34 RX_D1/SGMII_CON via ?
#set_property -dict {LOC R13  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[2]}] ;# U198.35 RX_D2/SGMII_SOP via ?
#set_property -dict {LOC V15  IOSTANDARD LVCMOS18} [get_ports {phy_rxd[3]}] ;# U198.36 RX_D3/SGMII_SON via ?
#set_property -dict {LOC J11  IOSTANDARD LVCMOS18 SLEW FAST DRIVE 12} [get_ports phy_refclk] ;# U198.15 XI 25 MHz
#set_property -dict {LOC T14  IOSTANDARD LVCMOS18} [get_ports phy_clk_out] ;# U198.18 CLK_OUT
#set_property -dict {LOC M11  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_reset_n] ;# U198.43 RESET_N
#set_property -dict {LOC V16  IOSTANDARD LVCMOS18} [get_ports phy_int_n] ;# U198.44 PWRDOWN/INTN
#set_property -dict {LOC U12  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_mdc] ;# U198.16 MDC
#set_property -dict {LOC J12  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 12} [get_ports phy_mdio] ;# U198.17 MDIO
#set_property -dict {LOC L14  IOSTANDARD LVCMOS18} [get_ports phy_gpio0] ;# U198.39 GPIO_0
#set_property -dict {LOC M12  IOSTANDARD LVCMOS18} [get_ports phy_gpio1] ;# U198.40 GPIO_1
#set_property -dict {LOC L15  IOSTANDARD LVCMOS18} [get_ports phy_led0] ;# U198.47 LED_0
#set_property -dict {LOC W14  IOSTANDARD LVCMOS18} [get_ports phy_led1] ;# U198.46 LED_1
#set_property -dict {LOC K14  IOSTANDARD LVCMOS18} [get_ports phy_led2] ;# U198.45 LED_2

# QSFP28 Interfaces
set_property -dict {LOC R45 } [get_ports {qsfp0_rx_p[0]}] ;# MGTYRXP2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC R46 } [get_ports {qsfp0_rx_n[0]}] ;# MGTYRXN2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC M42 } [get_ports {qsfp0_tx_p[0]}] ;# MGTYTXP2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC M43 } [get_ports {qsfp0_tx_n[0]}] ;# MGTYTXN2_129 GTYE3_CHANNEL_X0Y22 / GTYE3_COMMON_X0Y5
set_property -dict {LOC U45 } [get_ports {qsfp0_rx_p[1]}] ;# MGTYRXP1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC U46 } [get_ports {qsfp0_rx_n[1]}] ;# MGTYRXN1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC P42 } [get_ports {qsfp0_tx_p[1]}] ;# MGTYTXP1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC P43 } [get_ports {qsfp0_tx_n[1]}] ;# MGTYTXN1_129 GTYE3_CHANNEL_X0Y21 / GTYE3_COMMON_X0Y5
set_property -dict {LOC N45 } [get_ports {qsfp0_rx_p[2]}] ;# MGTYRXP3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC N46 } [get_ports {qsfp0_rx_n[2]}] ;# MGTYRXN3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC K42 } [get_ports {qsfp0_tx_p[2]}] ;# MGTYTXP3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC K43 } [get_ports {qsfp0_tx_n[2]}] ;# MGTYTXN3_129 GTYE3_CHANNEL_X0Y23 / GTYE3_COMMON_X0Y5
set_property -dict {LOC W45 } [get_ports {qsfp0_rx_p[3]}] ;# MGTYRXP0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC W46 } [get_ports {qsfp0_rx_n[3]}] ;# MGTYRXN0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC T42 } [get_ports {qsfp0_tx_p[3]}] ;# MGTYTXP0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC T43 } [get_ports {qsfp0_tx_n[3]}] ;# MGTYTXN0_129 GTYE3_CHANNEL_X0Y20 / GTYE3_COMMON_X0Y5
set_property -dict {LOC V38 } [get_ports qsfp0_mgt_refclk_p] ;# MGTREFCLK0P_129 from Si5340 U23 OUT1
set_property -dict {LOC V39 } [get_ports qsfp0_mgt_refclk_n] ;# MGTREFCLK0N_129 from Si5340 U23 OUT1
set_property -dict {LOC A26  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_resetl]
set_property -dict {LOC C25  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_modprsl]
set_property -dict {LOC B26  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp0_intl]
set_property -dict {LOC G25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp0_lpmode]
set_property -dict {LOC B25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_scl]
set_property -dict {LOC F25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp0_i2c_sda]

# 322.265625 MHz MGT reference clock
create_clock -period 3.103 -name qsfp0_mgt_refclk [get_ports qsfp0_mgt_refclk_p]

set_false_path -to [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_output_delay 0 [get_ports {qsfp0_resetl qsfp0_lpmode}]
set_false_path -from [get_ports {qsfp0_modprsl qsfp0_intl}]
set_input_delay 0 [get_ports {qsfp0_modprsl qsfp0_intl}]

set_false_path -to [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_output_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_false_path -from [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]
set_input_delay 0 [get_ports {qsfp0_i2c_scl qsfp0_i2c_sda}]

set_property -dict {LOC G45 } [get_ports {qsfp1_rx_p[0]}] ;# MGTYRXP2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC G46 } [get_ports {qsfp1_rx_n[0]}] ;# MGTYRXN2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC D42 } [get_ports {qsfp1_tx_p[0]}] ;# MGTYTXP2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC D43 } [get_ports {qsfp1_tx_n[0]}] ;# MGTYTXN2_130 GTYE3_CHANNEL_X0Y26 / GTYE3_COMMON_X0Y6
set_property -dict {LOC J45 } [get_ports {qsfp1_rx_p[1]}] ;# MGTYRXP1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC J46 } [get_ports {qsfp1_rx_n[1]}] ;# MGTYRXN1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC F42 } [get_ports {qsfp1_tx_p[1]}] ;# MGTYTXP1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC F43 } [get_ports {qsfp1_tx_n[1]}] ;# MGTYTXN1_130 GTYE3_CHANNEL_X0Y25 / GTYE3_COMMON_X0Y6
set_property -dict {LOC E45 } [get_ports {qsfp1_rx_p[2]}] ;# MGTYRXP3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC E46 } [get_ports {qsfp1_rx_n[2]}] ;# MGTYRXN3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC B42 } [get_ports {qsfp1_tx_p[2]}] ;# MGTYTXP3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC B43 } [get_ports {qsfp1_tx_n[2]}] ;# MGTYTXN3_130 GTYE3_CHANNEL_X0Y27 / GTYE3_COMMON_X0Y6
set_property -dict {LOC L45 } [get_ports {qsfp1_rx_p[3]}] ;# MGTYRXP0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC L46 } [get_ports {qsfp1_rx_n[3]}] ;# MGTYRXN0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC H42 } [get_ports {qsfp1_tx_p[3]}] ;# MGTYTXP0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC H43 } [get_ports {qsfp1_tx_n[3]}] ;# MGTYTXN0_130 GTYE3_CHANNEL_X0Y24 / GTYE3_COMMON_X0Y6
set_property -dict {LOC R40 } [get_ports qsfp1_mgt_refclk_p] ;# MGTREFCLK0P_130 from Si5340 U23 OUT2
set_property -dict {LOC R41 } [get_ports qsfp1_mgt_refclk_n] ;# MGTREFCLK0N_130 from Si5340 U23 OUT2
set_property -dict {LOC B27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_resetl]
set_property -dict {LOC H28  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_modprsl]
set_property -dict {LOC N24  IOSTANDARD LVCMOS18 PULLUP true} [get_ports qsfp1_intl]
set_property -dict {LOC H25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports qsfp1_lpmode]
set_property -dict {LOC P27  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_scl]
set_property -dict {LOC R24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8 PULLUP true} [get_ports qsfp1_i2c_sda]

# 322.265625 MHz MGT reference clock
create_clock -period 3.103 -name qsfp1_mgt_refclk [get_ports qsfp1_mgt_refclk_p]

set_false_path -to [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_output_delay 0 [get_ports {qsfp1_resetl qsfp1_lpmode}]
set_false_path -from [get_ports {qsfp1_modprsl qsfp1_intl}]
set_input_delay 0 [get_ports {qsfp1_modprsl qsfp1_intl}]

set_false_path -to [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_output_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_false_path -from [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]
set_input_delay 0 [get_ports {qsfp1_i2c_scl qsfp1_i2c_sda}]

# PCIe Interface
#set_property -dict {LOC U4  } [get_ports {pcie_rx_p[0]}]  ;# MGTHRXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC U3  } [get_ports {pcie_rx_n[0]}]  ;# MGTHRXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC M7  } [get_ports {pcie_tx_p[0]}]  ;# MGTHTXP3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC M6  } [get_ports {pcie_tx_n[0]}]  ;# MGTHTXN3_228 GTHE3_CHANNEL_X0Y19 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC V2  } [get_ports {pcie_rx_p[1]}]  ;# MGTHRXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC V1  } [get_ports {pcie_rx_n[1]}]  ;# MGTHRXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC P7  } [get_ports {pcie_tx_p[1]}]  ;# MGTHTXP2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC P6  } [get_ports {pcie_tx_n[1]}]  ;# MGTHTXN2_228 GTHE3_CHANNEL_X0Y18 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC W4  } [get_ports {pcie_rx_p[2]}]  ;# MGTHRXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC W3  } [get_ports {pcie_rx_n[2]}]  ;# MGTHRXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC T7  } [get_ports {pcie_tx_p[2]}]  ;# MGTHTXP1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC T6  } [get_ports {pcie_tx_n[2]}]  ;# MGTHTXN1_228 GTHE3_CHANNEL_X0Y17 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC Y2  } [get_ports {pcie_rx_p[3]}]  ;# MGTHRXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC Y1  } [get_ports {pcie_rx_n[3]}]  ;# MGTHRXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC V7  } [get_ports {pcie_tx_p[3]}]  ;# MGTHTXP0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC V6  } [get_ports {pcie_tx_n[3]}]  ;# MGTHTXN0_228 GTHE3_CHANNEL_X0Y16 / GTHE3_COMMON_X0Y4
#set_property -dict {LOC AA4 } [get_ports {pcie_rx_p[4]}]  ;# MGTHRXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AA3 } [get_ports {pcie_rx_n[4]}]  ;# MGTHRXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC Y7  } [get_ports {pcie_tx_p[4]}]  ;# MGTHTXP3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC Y6  } [get_ports {pcie_tx_n[4]}]  ;# MGTHTXN3_227 GTHE3_CHANNEL_X0Y15 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[5]}]  ;# MGTHRXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[5]}]  ;# MGTHRXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AB7 } [get_ports {pcie_tx_p[5]}]  ;# MGTHTXP2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AB6 } [get_ports {pcie_tx_n[5]}]  ;# MGTHTXN2_227 GTHE3_CHANNEL_X0Y14 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AC4 } [get_ports {pcie_rx_p[6]}]  ;# MGTHRXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AC3 } [get_ports {pcie_rx_n[6]}]  ;# MGTHRXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AD7 } [get_ports {pcie_tx_p[6]}]  ;# MGTHTXP1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AD6 } [get_ports {pcie_tx_n[6]}]  ;# MGTHTXN1_227 GTHE3_CHANNEL_X0Y13 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[7]}]  ;# MGTHRXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[7]}]  ;# MGTHRXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[7]}]  ;# MGTHTXP0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[7]}]  ;# MGTHTXN0_227 GTHE3_CHANNEL_X0Y12 / GTHE3_COMMON_X0Y3
#set_property -dict {LOC AJ4 } [get_ports {pcie_rx_p[8]}]  ;# MGTHRXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AJ3 } [get_ports {pcie_rx_n[8]}]  ;# MGTHRXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP7 } [get_ports {pcie_tx_p[8]}]  ;# MGTHTXP3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP6 } [get_ports {pcie_tx_n[8]}]  ;# MGTHTXN3_225 GTHE3_CHANNEL_X0Y7 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AK2 } [get_ports {pcie_rx_p[9]}]  ;# MGTHRXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AK1 } [get_ports {pcie_rx_n[9]}]  ;# MGTHRXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AR5 } [get_ports {pcie_tx_p[9]}]  ;# MGTHTXP2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AR4 } [get_ports {pcie_tx_n[9]}]  ;# MGTHTXN2_225 GTHE3_CHANNEL_X0Y6 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AM2 } [get_ports {pcie_rx_p[10]}] ;# MGTHRXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AM1 } [get_ports {pcie_rx_n[10]}] ;# MGTHRXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AT7 } [get_ports {pcie_tx_p[10]}] ;# MGTHTXP1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AT6 } [get_ports {pcie_tx_n[10]}] ;# MGTHTXN1_225 GTHE3_CHANNEL_X0Y5 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP2 } [get_ports {pcie_rx_p[11]}] ;# MGTHRXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AP1 } [get_ports {pcie_rx_n[11]}] ;# MGTHRXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AU5 } [get_ports {pcie_tx_p[11]}] ;# MGTHTXP0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AU4 } [get_ports {pcie_tx_n[11]}] ;# MGTHTXN0_225 GTHE3_CHANNEL_X0Y4 / GTHE3_COMMON_X0Y1
#set_property -dict {LOC AT2 } [get_ports {pcie_rx_p[12]}] ;# MGTHRXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AT1 } [get_ports {pcie_rx_n[12]}] ;# MGTHRXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AW5 } [get_ports {pcie_tx_p[12]}] ;# MGTHTXP3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AW4 } [get_ports {pcie_tx_n[12]}] ;# MGTHTXN3_224 GTHE3_CHANNEL_X0Y3 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AV2 } [get_ports {pcie_rx_p[13]}] ;# MGTHRXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AV1 } [get_ports {pcie_rx_n[13]}] ;# MGTHRXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BA5 } [get_ports {pcie_tx_p[13]}] ;# MGTHTXP2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BA4 } [get_ports {pcie_tx_n[13]}] ;# MGTHTXN2_224 GTHE3_CHANNEL_X0Y2 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AY2 } [get_ports {pcie_rx_p[14]}] ;# MGTHRXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AY1 } [get_ports {pcie_rx_n[14]}] ;# MGTHRXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BC5 } [get_ports {pcie_tx_p[14]}] ;# MGTHTXP1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BC4 } [get_ports {pcie_tx_n[14]}] ;# MGTHTXN1_224 GTHE3_CHANNEL_X0Y1 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BB2 } [get_ports {pcie_rx_p[15]}] ;# MGTHRXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BB1 } [get_ports {pcie_rx_n[15]}] ;# MGTHRXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BE5 } [get_ports {pcie_tx_p[15]}] ;# MGTHTXP0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC BE4 } [get_ports {pcie_tx_n[15]}] ;# MGTHTXN0_224 GTHE3_CHANNEL_X0Y0 / GTHE3_COMMON_X0Y0
#set_property -dict {LOC AR9 } [get_ports pcie_refclk_0_p] ;# MGTREFCLK0P_224
#set_property -dict {LOC AR8 } [get_ports pcie_refclk_0_n] ;# MGTREFCLK0N_224
#set_property -dict {LOC AC9 } [get_ports pcie_refclk_1_p] ;# MGTREFCLK0P_227
#set_property -dict {LOC AC8 } [get_ports pcie_refclk_1_n] ;# MGTREFCLK0N_227
#set_property -dict {LOC AM17 IOSTANDARD LVCMOS12 PULLUP true} [get_ports pcie_reset]

# 100 MHz MGT reference clock
#create_clock -period 10.000 -name pcie_mgt_refclk_0 [get_ports pcie_refclk_0_p]
#create_clock -period 10.000 -name pcie_mgt_refclk_1 [get_ports pcie_refclk_1_p]

#set_false_path -from [get_ports {pcie_reset}]
#set_input_delay 0 [get_ports {pcie_reset}]
