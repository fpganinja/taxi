# SPDX-License-Identifier: MIT
#
# Copyright (c) 2020-2025 FPGA Ninja, LLC
#
# Authors:
# - Alex Forencich

TOPLEVEL_LANG = verilog

SIM ?= verilator
WAVES ?= 0

COCOTB_HDL_TIMEUNIT = 1ns
COCOTB_HDL_TIMEPRECISION = 1ps

RTL_DIR = ../../rtl
LIB_DIR = ../../lib
TAXI_SRC_DIR = $(LIB_DIR)/taxi/src

DUT      = fpga_core
COCOTB_TEST_MODULES = test_$(DUT)
COCOTB_TOPLEVEL     = $(DUT)
MODULE   = $(COCOTB_TEST_MODULES)
TOPLEVEL = $(COCOTB_TOPLEVEL)
VERILOG_SOURCES += $(RTL_DIR)/$(DUT).sv
VERILOG_SOURCES += $(TAXI_SRC_DIR)/eth/rtl/taxi_eth_mac_1g_fifo.f
VERILOG_SOURCES += $(TAXI_SRC_DIR)/eth/rtl/us/taxi_eth_mac_25g_us.f
VERILOG_SOURCES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_if_uart.f
VERILOG_SOURCES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_switch.sv
VERILOG_SOURCES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_mod_apb.f
VERILOG_SOURCES += $(TAXI_SRC_DIR)/xfcp/rtl/taxi_xfcp_mod_stats.f
VERILOG_SOURCES += $(TAXI_SRC_DIR)/sync/rtl/taxi_sync_reset.sv
VERILOG_SOURCES += $(TAXI_SRC_DIR)/sync/rtl/taxi_sync_signal.sv
VERILOG_SOURCES += $(TAXI_SRC_DIR)/io/rtl/taxi_debounce_switch.sv

# handle file list files
process_f_file = $(call process_f_files,$(addprefix $(dir $1),$(shell cat $1)))
process_f_files = $(foreach f,$1,$(if $(filter %.f,$f),$(call process_f_file,$f),$f))
uniq_base = $(if $1,$(call uniq_base,$(foreach f,$1,$(if $(filter-out $(notdir $(lastword $1)),$(notdir $f)),$f,))) $(lastword $1))
VERILOG_SOURCES := $(call uniq_base,$(call process_f_files,$(VERILOG_SOURCES)))

# module parameters
export PARAM_SIM := "1'b1"
export PARAM_VENDOR := "\"XILINX\""
export PARAM_FAMILY := "\"virtexu\""
export PARAM_CFG_LOW_LATENCY := "1'b1"
export PARAM_COMBINED_MAC_PCS := "1'b1"
export PARAM_MAC_DATA_W := "64"

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-P $(COCOTB_TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))
else ifeq ($(SIM), verilator)
	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-G$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
		VERILATOR_TRACE = 1
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
