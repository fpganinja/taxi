# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

create_ip -name gig_ethernet_pcs_pma -vendor xilinx.com -library ip -module_name sgmii_pcs_pma_0

set_property -dict [list \
    CONFIG.Standard {SGMII} \
    CONFIG.Physical_Interface {LVDS} \
    CONFIG.Management_Interface {false} \
    CONFIG.SupportLevel {Include_Shared_Logic_in_Core} \
    CONFIG.LvdsRefClk {625} \
] [get_ips sgmii_pcs_pma_0]
