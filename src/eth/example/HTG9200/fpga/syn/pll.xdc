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

# PLL control
set_property -dict {LOC L24  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {clk_gty2_fdec}]
set_property -dict {LOC K25  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {clk_gty2_finc}]
set_property -dict {LOC K23  IOSTANDARD LVCMOS18} [get_ports {clk_gty2_intr_n}]
set_property -dict {LOC L25  IOSTANDARD LVCMOS18} [get_ports {clk_gty2_lol_n}]
set_property -dict {LOC L23  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {clk_gty2_oe_n}]
set_property -dict {LOC L22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {clk_gty2_sync_n}]
set_property -dict {LOC K22  IOSTANDARD LVCMOS18 SLEW SLOW DRIVE 8} [get_ports {clk_gty2_rst_n}]

#set_property -dict {LOC BE20 IOSTANDARD LVCMOS18} [get_ports {clk_gth_sd_oe}]
#set_property -dict {LOC BD20 IOSTANDARD LVCMOS18} [get_ports {clk_gth_out0_sel_i2cb}]

set_false_path -to [get_ports {clk_gty2_fdec clk_gty2_finc clk_gty2_oe_n clk_gty2_sync_n clk_gty2_rst_n}]
set_output_delay 0 [get_ports {clk_gty2_fdec clk_gty2_finc clk_gty2_oe_n clk_gty2_sync_n clk_gty2_rst_n}]
set_false_path -from [get_ports {clk_gty2_intr_n clk_gty2_lol_n}]
set_input_delay 0 [get_ports {clk_gty2_intr_n clk_gty2_lol_n}]
