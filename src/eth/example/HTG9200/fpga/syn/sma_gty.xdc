# SPDX-License-Identifier: MIT
#
# Copyright (c) 2021-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# XDC constraints for the HiTech Global HTG-9200 board
# part: xcvu9p-flgb2104-2-e
# part: xcvu13p-fhgb2104-2-e

# SMA (GTY)
set_property -dict {LOC E9  } [get_ports {sma_tx_p[0]}] ;# MGTYTXP0_233 GTYE4_CHANNEL_X1Y56 / GTYE4_COMMON_X1Y14
set_property -dict {LOC E8  } [get_ports {sma_tx_n[0]}] ;# MGTYTXN0_233 GTYE4_CHANNEL_X1Y56 / GTYE4_COMMON_X1Y14
set_property -dict {LOC E4  } [get_ports {sma_rx_p[0]}] ;# MGTYRXP0_233 GTYE4_CHANNEL_X1Y56 / GTYE4_COMMON_X1Y14
set_property -dict {LOC E3  } [get_ports {sma_rx_n[0]}] ;# MGTYRXN0_233 GTYE4_CHANNEL_X1Y56 / GTYE4_COMMON_X1Y14
set_property -dict {LOC D7  } [get_ports {sma_tx_p[1]}] ;# MGTYTXP1_233 GTYE4_CHANNEL_X1Y57 / GTYE4_COMMON_X1Y14
set_property -dict {LOC D6  } [get_ports {sma_tx_n[1]}] ;# MGTYTXN1_233 GTYE4_CHANNEL_X1Y57 / GTYE4_COMMON_X1Y14
set_property -dict {LOC D2  } [get_ports {sma_rx_p[1]}] ;# MGTYRXP1_233 GTYE4_CHANNEL_X1Y57 / GTYE4_COMMON_X1Y14
set_property -dict {LOC D1  } [get_ports {sma_rx_n[1]}] ;# MGTYRXN1_233 GTYE4_CHANNEL_X1Y57 / GTYE4_COMMON_X1Y14
set_property -dict {LOC C9  } [get_ports {sma_tx_p[2]}] ;# MGTYTXP2_233 GTYE4_CHANNEL_X1Y58 / GTYE4_COMMON_X1Y14
set_property -dict {LOC C8  } [get_ports {sma_tx_n[2]}] ;# MGTYTXN2_233 GTYE4_CHANNEL_X1Y58 / GTYE4_COMMON_X1Y14
set_property -dict {LOC C4  } [get_ports {sma_rx_p[2]}] ;# MGTYRXP2_233 GTYE4_CHANNEL_X1Y58 / GTYE4_COMMON_X1Y14
set_property -dict {LOC C3  } [get_ports {sma_rx_n[2]}] ;# MGTYRXN2_233 GTYE4_CHANNEL_X1Y58 / GTYE4_COMMON_X1Y14
set_property -dict {LOC A9  } [get_ports {sma_tx_p[3]}] ;# MGTYTXP3_233 GTYE4_CHANNEL_X1Y59 / GTYE4_COMMON_X1Y14
set_property -dict {LOC A8  } [get_ports {sma_tx_n[3]}] ;# MGTYTXN3_233 GTYE4_CHANNEL_X1Y59 / GTYE4_COMMON_X1Y14
set_property -dict {LOC A5  } [get_ports {sma_rx_p[3]}] ;# MGTYRXP3_233 GTYE4_CHANNEL_X1Y59 / GTYE4_COMMON_X1Y14
set_property -dict {LOC A4  } [get_ports {sma_rx_n[3]}] ;# MGTYRXN3_233 GTYE4_CHANNEL_X1Y59 / GTYE4_COMMON_X1Y14
set_property -dict {LOC D11 } [get_ports sma_mgt_refclk_p] ;# MGTREFCLK0P_233 from X20 SMA CLKP
set_property -dict {LOC D10 } [get_ports sma_mgt_refclk_n] ;# MGTREFCLK0N_233 from X19 SMA CLKN

# 156.25 MHz MGT reference clock
#create_clock -period 6.400 -name sma_mgt_refclk [get_ports sma_mgt_refclk_p]

# 161.1328125 MHz MGT reference clock
create_clock -period 6.206 -name sma_mgt_refclk [get_ports sma_mgt_refclk_p]
