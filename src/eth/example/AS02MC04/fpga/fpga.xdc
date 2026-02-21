# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the Alibaba AS02MC04
# part: xcku3p-ffvb676-1-e

# General configuration
set_property CFGBVS GND                                      [current_design]
set_property CONFIG_VOLTAGE 1.8                              [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true                 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup               [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 72.9                [current_design]
set_property CONFIG_MODE SPIx4                               [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4                 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE Yes              [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable        [current_design]

# 100 MHz system clock (Y2)
set_property -dict {LOC E18  IOSTANDARD LVDS} [get_ports {clk_100mhz_p}]
set_property -dict {LOC D18  IOSTANDARD LVDS} [get_ports {clk_100mhz_n}]
create_clock -period 10 -name clk_100mhz [get_ports {clk_100mhz_p}]

# LEDs
set_property -dict {LOC B12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {sfp_led[0]}] ;# DS3
set_property -dict {LOC C12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {sfp_led[1]}] ;# DS2
set_property -dict {LOC B11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[0]}] ;# DS6
set_property -dict {LOC C11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[1]}] ;# DS7
set_property -dict {LOC A10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[2]}] ;# DS8
set_property -dict {LOC B10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led[3]}] ;# DS9
set_property -dict {LOC A13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led_r}] ;# C1
set_property -dict {LOC A12  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led_g}] ;# C1
set_property -dict {LOC B9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12} [get_ports {led_hb}] ;# DS5

set_false_path -to [get_ports {sfp_led[*] led[*] led_r led_g led_hb}]
set_output_delay 0 [get_ports {sfp_led[*] led[*] led_r led_g led_hb}]

# Reset button
set_property -dict {LOC F12  IOSTANDARD LVCMOS33} [get_ports reset] ;# SW1

set_false_path -from [get_ports {reset}]
set_input_delay 0 [get_ports {reset}]

# GPIO
#set_property -dict {LOC A14 IOSTANDARD LVCMOS33} [get_ports {gpio[0]}] ;# J5.3,4
#set_property -dict {LOC E12 IOSTANDARD LVCMOS33} [get_ports {gpio[1]}] ;# J5.5,6
#set_property -dict {LOC E13 IOSTANDARD LVCMOS33} [get_ports {gpio[2]}] ;# J5.7,8
#set_property -dict {LOC F10 IOSTANDARD LVCMOS33} [get_ports {gpio[3]}] ;# J5.9,10
#set_property -dict {LOC C9  IOSTANDARD LVCMOS33} [get_ports {gpio[4]}] ;# J5.11,12
#set_property -dict {LOC D9  IOSTANDARD LVCMOS33} [get_ports {gpio[5]}] ;# J5.13,14

# SFP28 Interfaces
set_property -dict {LOC A4  } [get_ports {sfp_rx_p[0]}] ;# MGTYRXP3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC A3  } [get_ports {sfp_rx_n[0]}] ;# MGTYRXN3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B2  } [get_ports {sfp_rx_p[1]}] ;# MGTYRXP2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B1  } [get_ports {sfp_rx_n[1]}] ;# MGTYRXN2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B7  } [get_ports {sfp_tx_p[0]}] ;# MGTYTXP3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC B6  } [get_ports {sfp_tx_n[0]}] ;# MGTYTXN3_227 GTYE4_CHANNEL_X0Y15 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D7  } [get_ports {sfp_tx_p[1]}] ;# MGTYTXP2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC D6  } [get_ports {sfp_tx_n[1]}] ;# MGTYTXN2_227 GTYE4_CHANNEL_X0Y14 / GTYE4_COMMON_X0Y3
set_property -dict {LOC K7  } [get_ports {sfp_mgt_refclk_p}] ;# MGTREFCLK0P_227 from Y1
set_property -dict {LOC K6  } [get_ports {sfp_mgt_refclk_n}] ;# MGTREFCLK0N_227 from Y1
set_property -dict {LOC D14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_npres[0]}]
set_property -dict {LOC E11  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_npres[1]}]
set_property -dict {LOC B14  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_tx_fault[0]}]
set_property -dict {LOC F9   IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_tx_fault[1]}]
set_property -dict {LOC D13  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_los[0]}]
set_property -dict {LOC E10  IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sfp_los[1]}]
#set_property -dict {LOC C13  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[0]}]
#set_property -dict {LOC D10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_scl[1]}]
#set_property -dict {LOC C14  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[0]}]
#set_property -dict {LOC D11  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {sfp_i2c_sda[1]}]

# 156.25 MHz MGT reference clock
create_clock -period 6.4 -name sfp_mgt_refclk [get_ports {sfp_mgt_refclk_p}]

# set_false_path -to [get_ports {sfp_tx_disable[*] sfp_rs[*]}]
# set_output_delay 0 [get_ports {sfp_tx_disable[*] sfp_rs[*]}]
set_false_path -from [get_ports {sfp_npres[*] sfp_tx_fault[*] sfp_los[*]}]
set_input_delay 0 [get_ports {sfp_npres[*] sfp_tx_fault[*] sfp_los[*]}]

#set_false_path -to [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
#set_output_delay 0 [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
#set_false_path -from [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]
#set_input_delay 0 [get_ports {sfp_i2c_sda[*] sfp_i2c_scl[*]}]

# I2C interface
#set_property -dict {LOC G9   IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {i2c_scl[0]}]
#set_property -dict {LOC G10  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {i2c_sda[0]}]
#set_property -dict {LOC J14  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {i2c_scl[1]}]
#set_property -dict {LOC J15  IOSTANDARD LVCMOS33 SLEW SLOW DRIVE 12 PULLUP true} [get_ports {i2c_sda[1]}]

#set_false_path -to [get_ports {i2c_sda[*] i2c_scl[*]}]
#set_output_delay 0 [get_ports {i2c_sda[*] i2c_scl[*]}]
#set_false_path -from [get_ports {i2c_sda[*] i2c_scl[*]}]
#set_input_delay 0 [get_ports {i2c_sda[*] i2c_scl[*]}]

# PCIe Interface
#set_property -dict {LOC P2  } [get_ports {pcie_rx_p[0]}] ;# MGTYRXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC P1  } [get_ports {pcie_rx_n[0]}] ;# MGTYRXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC R5  } [get_ports {pcie_tx_p[0]}] ;# MGTYTXP3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC R4  } [get_ports {pcie_tx_n[0]}] ;# MGTYTXN3_225 GTYE4_CHANNEL_X0Y7 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC T2  } [get_ports {pcie_rx_p[1]}] ;# MGTYRXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC T1  } [get_ports {pcie_rx_n[1]}] ;# MGTYRXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC U5  } [get_ports {pcie_tx_p[1]}] ;# MGTYTXP2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC U4  } [get_ports {pcie_tx_n[1]}] ;# MGTYTXN2_225 GTYE4_CHANNEL_X0Y6 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC V2  } [get_ports {pcie_rx_p[2]}] ;# MGTYRXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC V1  } [get_ports {pcie_rx_n[2]}] ;# MGTYRXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC W5  } [get_ports {pcie_tx_p[2]}] ;# MGTYTXP1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC W4  } [get_ports {pcie_tx_n[2]}] ;# MGTYTXN1_225 GTYE4_CHANNEL_X0Y5 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC Y2  } [get_ports {pcie_rx_p[3]}] ;# MGTYRXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC Y1  } [get_ports {pcie_rx_n[3]}] ;# MGTYRXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC AA5 } [get_ports {pcie_tx_p[3]}] ;# MGTYTXP0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC AA4 } [get_ports {pcie_tx_n[3]}] ;# MGTYTXN0_225 GTYE4_CHANNEL_X0Y4 / GTYE4_COMMON_X0Y1
#set_property -dict {LOC AB2 } [get_ports {pcie_rx_p[4]}] ;# MGTYRXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AB1 } [get_ports {pcie_rx_n[4]}] ;# MGTYRXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AC5 } [get_ports {pcie_tx_p[4]}] ;# MGTYTXP3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AC4 } [get_ports {pcie_tx_n[4]}] ;# MGTYTXN3_224 GTYE4_CHANNEL_X0Y3 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AD2 } [get_ports {pcie_rx_p[5]}] ;# MGTYRXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AD1 } [get_ports {pcie_rx_n[5]}] ;# MGTYRXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AD7 } [get_ports {pcie_tx_p[5]}] ;# MGTYTXP2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AD6 } [get_ports {pcie_tx_n[5]}] ;# MGTYTXN2_224 GTYE4_CHANNEL_X0Y2 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AE4 } [get_ports {pcie_rx_p[6]}] ;# MGTYRXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AE3 } [get_ports {pcie_rx_n[6]}] ;# MGTYRXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AE9 } [get_ports {pcie_tx_p[6]}] ;# MGTYTXP1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AE8 } [get_ports {pcie_tx_n[6]}] ;# MGTYTXN1_224 GTYE4_CHANNEL_X0Y1 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AF2 } [get_ports {pcie_rx_p[7]}] ;# MGTYRXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AF1 } [get_ports {pcie_rx_n[7]}] ;# MGTYRXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AF7 } [get_ports {pcie_tx_p[7]}] ;# MGTYTXP0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC AF6 } [get_ports {pcie_tx_n[7]}] ;# MGTYTXN0_224 GTYE4_CHANNEL_X0Y0 / GTYE4_COMMON_X0Y0
#set_property -dict {LOC T7  } [get_ports pcie_refclk_p] ;# MGTREFCLK1P_225
#set_property -dict {LOC T6  } [get_ports pcie_refclk_n] ;# MGTREFCLK1N_225
#set_property -dict {LOC A9 IOSTANDARD LVCMOS33 PULLUP true} [get_ports pcie_reset_n]

#set_false_path -from [get_ports {pcie_reset_n}]
#set_input_delay 0 [get_ports {pcie_reset_n}]

# 100 MHz MGT reference clock
#create_clock -period 10 -name pcie_mgt_refclk [get_ports pcie_refclk_p]
