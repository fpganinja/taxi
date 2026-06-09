# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

set params [dict create]

# SFP+ rate
# 0 for 1G, 1 for 10G
dict set params SFP_RATE "0"

# 10G MAC configuration
dict set params CFG_LOW_LATENCY "1"
dict set params COMBINED_MAC_PCS "1"
dict set params MAC_DATA_W "16"

# apply parameters to top-level
set param_list {}
dict for {name value} $params {
    lappend param_list $name=$value
}

set_property generic $param_list [get_filesets sources_1]
