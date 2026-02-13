# SPDX-License-Identifier: CERN-OHL-S-2.0
#
# Copyright (c) 2019-2026 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# PTP time distribution PHC module control registers

foreach inst [get_cells -hier -filter {(ORIG_REF_NAME == taxi_ptp_td_phc_axil || REF_NAME == taxi_ptp_td_phc_axil || ORIG_REF_NAME == taxi_ptp_td_phc_apb || REF_NAME == taxi_ptp_td_phc_apb)}] {
    puts "Inserting timing constraints for taxi_ptp_td_phc_axil instance $inst"

    set src_clk [get_clocks -of_objects [get_cells "$inst/set_ptp_period_req_reg_reg"]]

    set src_clk_period [if {[llength $src_clk]} {get_property -min PERIOD $src_clk} {expr 1.0}]

    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_s_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/ts_tod_s_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/ts_tod_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_req_reg_reg"] -to [get_cells "$inst/set_ptp_ts_tod_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_tod_ack_reg_reg"] -to [get_cells "$inst/set_ptp_ts_tod_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_max_delay -from [get_cells "$inst/offset_ptp_ts_tod_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/adder_b_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_tod_req_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_tod_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_tod_ack_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_tod_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_max_delay -from [get_cells "$inst/set_ptp_ts_rel_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/ts_rel_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_rel_req_reg_reg"] -to [get_cells "$inst/set_ptp_ts_rel_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_ts_rel_ack_reg_reg"] -to [get_cells "$inst/set_ptp_ts_rel_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_max_delay -from [get_cells "$inst/offset_ptp_ts_rel_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/adder_b_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_rel_req_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_rel_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_rel_ack_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_rel_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_max_delay -from [get_cells "$inst/set_ptp_period_ns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/period_ns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/period_fns_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_req_reg_reg"] -to [get_cells "$inst/set_ptp_period_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/set_ptp_period_ack_reg_reg"] -to [get_cells "$inst/set_ptp_period_ack_sync1_reg_reg"] -datapath_only $src_clk_period

    set_max_delay -from [get_cells "$inst/offset_ptp_ts_fns_reg_reg[*]"] -to [get_cells "$inst/ptp_td_phc_inst/adder_b_reg_reg[*]"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_req_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_req_sync1_reg_reg"] -datapath_only $src_clk_period
    set_max_delay -from [get_cells "$inst/offset_ptp_ts_ack_reg_reg"] -to [get_cells "$inst/offset_ptp_ts_ack_sync1_reg_reg"] -datapath_only $src_clk_period
}
