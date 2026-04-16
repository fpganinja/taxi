# SPDX-License-Identifier: MIT
#
# Copyright (c) 2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# Ethernet constraints

# IDELAY from PHY chip (RGMII)
set_property DELAY_VALUE 0 [get_cells {phy_rx_ctl_idelay phy_rxd_idelay_bit[*].idelay_inst}]

# MMCM phase (RGMII)
set_property CLKOUT1_PHASE 90 [get_cells clk_mmcm_inst]

# phy_txd[1] is on BITSLICE_0, which is a problem during delay calibration
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports phy_txd[1]]
