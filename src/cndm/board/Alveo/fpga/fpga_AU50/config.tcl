# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

set params [dict create]

# collect build information
set build_date [clock seconds]
set git_hash 00000000
set git_tag ""

if { [catch {set git_hash [exec git rev-parse --short=8 HEAD]}] } {
    puts "Error running git or project not under version control"
}

if { [catch {set git_tag [exec git describe --tags HEAD]}] } {
    puts "Error running git, project not under version control, or no tag found"
}

puts "Build date: ${build_date}"
puts "Git hash: ${git_hash}"
puts "Git tag: ${git_tag}"

if { ! [regsub {^.*(\d+\.\d+\.\d+([\.-]\d+)?).*$} $git_tag {\1} tag_ver ] } {
    puts "Failed to extract version from git tag"
    set tag_ver 0.0.1
}

puts "Tag version: ${tag_ver}"

# FW and board IDs
set fpga_id [expr 0x4B77093]
set fw_id [expr 0x0000C001]
set fw_ver $tag_ver
set board_vendor_id [expr 0x10ee]
set board_device_id [expr 0x9032]
set board_ver 1.0
set release_info [expr 0x00000000]

# PCIe IDs
set pcie_vendor_id [expr 0x1234]
set pcie_device_id [expr 0xC001]
set pcie_class_code [expr 0x020000]
set pcie_revision_id [expr 0x00]
set pcie_subsystem_device_id $board_device_id
set pcie_subsystem_vendor_id $board_vendor_id

# FW ID
dict set params FPGA_ID [format "32'h%08x" $fpga_id]
dict set params FW_ID [format "32'h%08x" $fw_id]
dict set params FW_VER [format "32'h%03x%02x%03x" {*}[split $fw_ver .-] 0 0 0]
dict set params BOARD_ID [format "32'h%04x%04x" $board_vendor_id $board_device_id]
dict set params BOARD_VER [format "32'h%03x%02x%03x" {*}[split $board_ver .-] 0 0 0]
dict set params BUILD_DATE "32'd${build_date}"
dict set params GIT_HASH "32'h${git_hash}"
dict set params RELEASE_INFO [format "32'h%08x" $release_info]

# PTP configuration
dict set params PTP_TS_EN "1"

# AXI lite interface configuration (control)
dict set params AXIL_CTRL_DATA_W "32"
dict set params AXIL_CTRL_ADDR_W "24"

# MAC configuration
dict set params CFG_LOW_LATENCY "1"
dict set params COMBINED_MAC_PCS "1"
dict set params MAC_DATA_W "64"

# PCIe IP core settings
set pcie [get_ips pcie4c_uscale_plus_0]

# configure BAR settings
proc configure_bar {pcie pf bar aperture} {
    set size_list {Bytes Kilobytes Megabytes Gigabytes Terabytes Petabytes Exabytes}
    for { set i 0 } { $i < [llength $size_list] } { incr i } {
        set scale [lindex $size_list $i]

        if {$aperture > 0 && $aperture < ($i+1)*10} {
            set size [expr 1 << $aperture - ($i*10)]

            puts "${pcie} PF${pf} BAR${bar}: aperture ${aperture} bits ($size $scale)"

            set pcie_config [dict create]

            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_enabled" {true}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_type" {Memory}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_64bit" {true}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_prefetchable" {true}
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_scale" $scale
            dict set pcie_config "CONFIG.pf${pf}_bar${bar}_size" $size

            set_property -dict $pcie_config $pcie

            return
        }
    }
    puts "${pcie} PF${pf} BAR${bar}: disabled"
    set_property "CONFIG.pf${pf}_bar${bar}_enabled" {false} $pcie
}

# Control BAR (BAR 0)
configure_bar $pcie 0 0 [dict get $params AXIL_CTRL_ADDR_W]

# PCIe IP core configuration
set pcie_config [dict create]

# PCIe IDs
dict set pcie_config "CONFIG.vendor_id" [format "%04x" $pcie_vendor_id]
dict set pcie_config "CONFIG.PF0_DEVICE_ID" [format "%04x" $pcie_device_id]
dict set pcie_config "CONFIG.PF0_CLASS_CODE" [format "%06x" $pcie_class_code]
dict set pcie_config "CONFIG.PF0_REVISION_ID" [format "%02x" $pcie_revision_id]
dict set pcie_config "CONFIG.PF0_SUBSYSTEM_VENDOR_ID" [format "%04x" $pcie_subsystem_vendor_id]
dict set pcie_config "CONFIG.PF0_SUBSYSTEM_ID" [format "%04x" $pcie_subsystem_device_id]

# MSI
dict set pcie_config "CONFIG.pf0_msi_enabled" {true}

set_property -dict $pcie_config $pcie

# apply parameters to top-level
set param_list {}
dict for {name value} $params {
    lappend param_list $name=$value
}

set_property generic $param_list [get_filesets sources_1]
