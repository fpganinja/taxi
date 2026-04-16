# SPDX-License-Identifier: MIT
#
# Copyright (c) 2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich
#

# FPGA settings
FPGA_PART = xczu48dr-ffvg1517-2-e
FPGA_TOP = fpga
FPGA_ARCH = zynquplusRFSOC

RTL_DIR = ../rtl
LIB_DIR = ../lib
TAXI_SRC_DIR = $(LIB_DIR)/taxi/src

# Files for synthesis
SYN_FILES = $(RTL_DIR)/fpga_em.sv
SYN_FILES += $(RTL_DIR)/fpga_core.sv
SYN_FILES += $(RTL_DIR)/../pll/pll_i2c_init_em.sv
SYN_FILES += $(TAXI_SRC_DIR)/eth/rtl/us/taxi_eth_mac_25g_us.f
SYN_FILES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_if_uart.f
SYN_FILES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_switch.sv
SYN_FILES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_mod_apb.f
SYN_FILES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_mod_i2c_master.f
SYN_FILES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_mod_stats.f
SYN_FILES += $(TAXI_SRC_DIR)/axis/rtl/taxi_axis_async_fifo.f
SYN_FILES += $(TAXI_SRC_DIR)/sync/rtl/taxi_sync_reset.sv
SYN_FILES += $(TAXI_SRC_DIR)/sync/rtl/taxi_sync_signal.sv
SYN_FILES += $(TAXI_SRC_DIR)/io/rtl/taxi_debounce_switch.sv

# XDC files
XDC_FILES += ../syn/EM/fpga.xdc
XDC_FILES += ../syn/EM/pll.xdc
XDC_FILES += ../syn/EM/lmk.xdc
XDC_FILES += ../syn/EM/gpio.xdc
XDC_FILES += ../syn/EM/i2c.xdc
XDC_FILES += ../syn/EM/fmc_htg_qsfp28_deg90.xdc
XDC_FILES += ../syn/EM/rfdc.xdc
XDC_FILES += ../syn/cfgmclk.xdc
XDC_FILES += $(TAXI_SRC_DIR)/eth/syn/vivado/taxi_eth_mac_fifo.tcl
XDC_FILES += $(TAXI_SRC_DIR)/axis/syn/vivado/taxi_axis_async_fifo.tcl
XDC_FILES += $(TAXI_SRC_DIR)/sync/syn/vivado/taxi_sync_reset.tcl
XDC_FILES += $(TAXI_SRC_DIR)/sync/syn/vivado/taxi_sync_signal.tcl

# IP
IP_TCL_FILES = $(TAXI_SRC_DIR)/eth/rtl/us/taxi_eth_phy_25g_us_gty_25g_161.tcl
IP_TCL_FILES += ../ip/usp_rfdc_1ghz_1gsps.tcl

# Configuration
CONFIG_TCL_FILES = ./config.tcl

include ../common/vivado.mk

program: $(FPGA_TOP).bit
	echo "open_hw" > program.tcl
	echo "connect_hw_server" >> program.tcl
	echo "open_hw_target" >> program.tcl
	echo "current_hw_device [lindex [get_hw_devices] 0]" >> program.tcl
	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program.tcl
	echo "set_property PROGRAM.FILE {$(FPGA_TOP).bit} [current_hw_device]" >> program.tcl
	echo "program_hw_devices [current_hw_device]" >> program.tcl
	echo "exit" >> program.tcl
	vivado -nojournal -nolog -mode batch -source program.tcl
