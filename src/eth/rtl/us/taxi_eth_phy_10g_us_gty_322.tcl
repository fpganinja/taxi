# SPDX-License-Identifier: CERN-OHL-S-2.0
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

set base_name {taxi_eth_phy_10g_us_gty}

set preset {GTY-10GBASE-R}

set freerun_freq {125}
set line_rate {10.3125}
set refclk_freq {322.265625}
set sec_line_rate {0}
set sec_refclk_freq $refclk_freq
set qpll_fracn [expr {int(fmod($line_rate*1000/2 / $refclk_freq, 1)*pow(2, 24))}]
set sec_qpll_fracn [expr {int(fmod($sec_line_rate*1000/2 / $sec_refclk_freq, 1)*pow(2, 24))}]
set user_data_width {32}
set int_data_width $user_data_width
set rx_eq_mode {DFE}
set extra_ports [list]
set extra_pll_ports [list]
# PLL reset and power down
lappend extra_pll_ports qpll0reset_in qpll1reset_in
lappend extra_pll_ports qpll0pd_in qpll1pd_in
# PLL clocking
lappend extra_pll_ports gtrefclk00_in qpll0lock_out qpll0outclk_out qpll0outrefclk_out
lappend extra_pll_ports gtrefclk01_in qpll1lock_out qpll1outclk_out qpll1outrefclk_out
# PCIe
if {[string first uplus [get_property FAMILY [get_property PART [current_project]]]] != -1} {
    lappend extra_pll_ports pcierateqpll0_in pcierateqpll1_in
} else {
    lappend extra_pll_ports qpllrsvd2_in qpllrsvd3_in
}
# channel reset
lappend extra_ports gttxreset_in txuserrdy_in txpmareset_in txpcsreset_in txprogdivreset_in txresetdone_out txpmaresetdone_out txprgdivresetdone_out
lappend extra_ports gtrxreset_in rxuserrdy_in rxpmareset_in rxdfelpmreset_in eyescanreset_in rxpcsreset_in rxprogdivreset_in rxresetdone_out rxpmaresetdone_out rxprgdivresetdone_out
# channel power down
lappend extra_ports txpd_in txpdelecidlemode_in rxpd_in
# channel clock selection
lappend extra_ports txsysclksel_in txpllclksel_in rxsysclksel_in rxpllclksel_in
# channel polarity
lappend extra_ports txpolarity_in rxpolarity_in
# channel TX driver
lappend extra_ports txelecidle_in txinhibit_in txdiffctrl_in txmaincursor_in txprecursor_in txpostcursor_in
# channel CDR
lappend extra_ports rxcdrlock_out rxcdrhold_in rxcdrovrden_in
# channel EQ
lappend extra_ports rxlpmen_in

set config [dict create]

dict set config TX_LINE_RATE $line_rate
dict set config TX_REFCLK_FREQUENCY $refclk_freq
dict set config TX_QPLL_FRACN_NUMERATOR $qpll_fracn
dict set config TX_USER_DATA_WIDTH $user_data_width
dict set config TX_INT_DATA_WIDTH $int_data_width
dict set config RX_LINE_RATE $line_rate
dict set config RX_REFCLK_FREQUENCY $refclk_freq
dict set config RX_QPLL_FRACN_NUMERATOR $qpll_fracn
dict set config RX_USER_DATA_WIDTH $user_data_width
dict set config RX_INT_DATA_WIDTH $int_data_width
dict set config RX_EQ_MODE $rx_eq_mode
if {$sec_line_rate != 0} {
    dict set config SECONDARY_QPLL_ENABLE true
    dict set config SECONDARY_QPLL_FRACN_NUMERATOR $sec_qpll_fracn
    dict set config SECONDARY_QPLL_LINE_RATE $sec_line_rate
    dict set config SECONDARY_QPLL_REFCLK_FREQUENCY $sec_refclk_freq
} else {
    dict set config SECONDARY_QPLL_ENABLE false
}
dict set config ENABLE_OPTIONAL_PORTS $extra_ports
dict set config LOCATE_COMMON {CORE}
dict set config LOCATE_RESET_CONTROLLER {EXAMPLE_DESIGN}
dict set config LOCATE_TX_USER_CLOCKING {CORE}
dict set config LOCATE_RX_USER_CLOCKING {CORE}
dict set config LOCATE_USER_DATA_WIDTH_SIZING {CORE}
dict set config FREERUN_FREQUENCY $freerun_freq
dict set config DISABLE_LOC_XDC {1}

proc create_gtwizard_ip {name preset config} {
    create_ip -name gtwizard_ultrascale -vendor xilinx.com -library ip -module_name $name
    set ip [get_ips $name]
    set_property CONFIG.preset $preset $ip
    set config_list {}
    dict for {name value} $config {
        lappend config_list "CONFIG.${name}" $value
    }
    set_property -dict $config_list $ip
}

# normal latency (async gearbox)
dict set config TX_DATA_ENCODING {64B66B_ASYNC}
dict set config TX_BUFFER_MODE {1}
dict set config TX_OUTCLK_SOURCE {TXPROGDIVCLK}
dict set config RX_DATA_DECODING {64B66B_ASYNC}
dict set config RX_BUFFER_MODE {1}
dict set config RX_OUTCLK_SOURCE {RXPROGDIVCLK}

# variant with channel and common
dict set config ENABLE_OPTIONAL_PORTS [concat $extra_pll_ports $extra_ports]
dict set config LOCATE_COMMON {CORE}

create_gtwizard_ip "${base_name}_full" $preset $config

# variant with channel only
dict set config ENABLE_OPTIONAL_PORTS $extra_ports
dict set config LOCATE_COMMON {EXAMPLE_DESIGN}

create_gtwizard_ip "${base_name}_ch" $preset $config

# low latency (async gearbox with buffer bypass)
dict set config TX_DATA_ENCODING {64B66B}
dict set config TX_BUFFER_MODE {0}
dict set config TX_OUTCLK_SOURCE {TXPROGDIVCLK}
dict set config RX_DATA_DECODING {64B66B}
dict set config RX_BUFFER_MODE {0}
dict set config RX_OUTCLK_SOURCE {RXOUTCLKPMA}

# variant with channel and common
dict set config ENABLE_OPTIONAL_PORTS [concat $extra_pll_ports $extra_ports]
dict set config LOCATE_COMMON {CORE}

create_gtwizard_ip "${base_name}_ll_full" $preset $config

# variant with channel only
dict set config ENABLE_OPTIONAL_PORTS $extra_ports
dict set config LOCATE_COMMON {EXAMPLE_DESIGN}

create_gtwizard_ip "${base_name}_ll_ch" $preset $config
