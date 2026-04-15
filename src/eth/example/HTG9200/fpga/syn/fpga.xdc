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

# General configuration
set_property CFGBVS GND                                [current_design]
set_property CONFIG_VOLTAGE 1.8                        [current_design]
set_property BITSTREAM.GENERAL.COMPRESS true           [current_design]
set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN {DIV-1} [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES       [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 8           [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES        [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN Enable  [current_design]

# System clocks
# DDR4 clocks from U5 (200 MHz)
#set_property -dict {LOC C36  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_a_p]
#set_property -dict {LOC C37  IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_a_n]
#create_clock -period 5.000 -name sys_clk_ddr4_a [get_ports sys_clk_ddr4_a_p]

#set_property -dict {LOC BA34 IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_b_p]
#set_property -dict {LOC BB34 IOSTANDARD DIFF_SSTL12} [get_ports sys_clk_ddr4_b_n]
#create_clock -period 5.000 -name sys_clk_ddr4_b [get_ports sys_clk_ddr4_b_p]

# refclk from U24 (200 MHz)
set_property -dict {LOC AV26 IOSTANDARD LVDS} [get_ports ref_clk_p]
set_property -dict {LOC AW26 IOSTANDARD LVDS} [get_ports ref_clk_n]
create_clock -period 5.000 -name ref_clk [get_ports ref_clk_p]

# 80 MHz EMCCLK
#set_property -dict {LOC AL27 IOSTANDARD LVCMOS18} [get_ports emc_clk]
#create_clock -period 12.5 -name emc_clk [get_ports emc_clk]

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
