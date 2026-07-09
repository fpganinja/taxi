# SPDX-License-Identifier: CERN-OHL-S-2.0
#
# Copyright (c) 2026 FPGA Ninja, LLC
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

DUT      = taxi_axis_basex_tx_8
COCOTB_TEST_MODULES = test_$(DUT)
COCOTB_TOPLEVEL     = test_$(DUT)
MODULE   = $(COCOTB_TEST_MODULES)
TOPLEVEL = $(COCOTB_TOPLEVEL)
VERILOG_SOURCES += $(COCOTB_TOPLEVEL).sv
VERILOG_SOURCES += $(RTL_DIR)/$(DUT).sv
VERILOG_SOURCES += $(TAXI_SRC_DIR)/lfsr/rtl/taxi_lfsr.sv
VERILOG_SOURCES += $(TAXI_SRC_DIR)/axis/rtl/taxi_axis_if.sv

# handle file list files
process_f_file = $(call process_f_files,$(addprefix $(dir $1),$(shell cat $1)))
process_f_files = $(foreach f,$1,$(if $(filter %.f,$f),$(call process_f_file,$f),$f))
uniq_base = $(if $1,$(call uniq_base,$(foreach f,$1,$(if $(filter-out $(notdir $(lastword $1)),$(notdir $f)),$f,))) $(lastword $1))
VERILOG_SOURCES := $(call uniq_base,$(call process_f_files,$(VERILOG_SOURCES)))

# module parameters
export PARAM_DATA_W := 8
export PARAM_PADDING_EN := 1
export PARAM_MIN_FRAME_LEN := 64
export PARAM_GBX_IF_EN := 0
export PARAM_GBX_CNT := 1
export PARAM_SGMII_EN := 1
export PARAM_AN_EN := $(PARAM_SGMII_EN)
export PARAM_DIC_EN := 1
export PARAM_PTP_TS_EN := 1
export PARAM_PTP_TS_FMT_TOD := 1
export PARAM_PTP_TS_W := $(if $(filter-out 1,$(PARAM_PTP_TS_FMT_TOD)),64,96)
export PARAM_TX_TAG_W := 16
export PARAM_TX_CPL_CTRL_IN_TUSER := 1

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
