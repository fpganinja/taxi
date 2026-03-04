# SPDX-License-Identifier: CERN-OHL-S-2.0
#
# Copyright (c) 2021-2025 FPGA Ninja, LLC
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

DUT      = taxi_axis_demux
COCOTB_TEST_MODULES = test_$(DUT)
COCOTB_TOPLEVEL     = test_$(DUT)
MODULE   = $(COCOTB_TEST_MODULES)
TOPLEVEL = $(COCOTB_TOPLEVEL)
VERILOG_SOURCES += $(COCOTB_TOPLEVEL).sv
VERILOG_SOURCES += $(RTL_DIR)/$(DUT).sv
VERILOG_SOURCES += $(RTL_DIR)/taxi_axis_if.sv

# handle file list files
process_f_file = $(call process_f_files,$(addprefix $(dir $1),$(shell cat $1)))
process_f_files = $(foreach f,$1,$(if $(filter %.f,$f),$(call process_f_file,$f),$f))
uniq_base = $(if $1,$(call uniq_base,$(foreach f,$1,$(if $(filter-out $(notdir $(lastword $1)),$(notdir $f)),$f,))) $(lastword $1))
VERILOG_SOURCES := $(call uniq_base,$(call process_f_files,$(VERILOG_SOURCES)))

# module parameters
export PARAM_M_COUNT := 4
export PARAM_DATA_W := 8
export PARAM_KEEP_EN := $(shell expr $(PARAM_DATA_W) \> 8 )
export PARAM_KEEP_W := $(shell expr \( $(PARAM_DATA_W) + 7 \) / 8 )
export PARAM_STRB_EN := 0
export PARAM_LAST_EN := 1
export PARAM_ID_EN := 1
export PARAM_M_ID_W := 8
export PARAM_S_ID_W := $(shell python -c "print($(PARAM_M_ID_W) + ($(PARAM_M_COUNT)-1).bit_length())")
export PARAM_DEST_EN := 1
export PARAM_M_DEST_W := 8
export PARAM_S_DEST_W := $(shell python -c "print($(PARAM_M_DEST_W) + ($(PARAM_M_COUNT)-1).bit_length())")
export PARAM_USER_EN := 1
export PARAM_USER_W := 1
export PARAM_TID_ROUTE := 0
export PARAM_TDEST_ROUTE := 1

ifeq ($(SIM), icarus)
	PLUSARGS += -fst

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-P $(COCOTB_TOPLEVEL).$(subst PARAM_,,$(v))=$($(v)))
else ifeq ($(SIM), verilator)
# 	COMPILE_ARGS += -Wno-SELRANGE -Wno-WIDTH

	COMPILE_ARGS += $(foreach v,$(filter PARAM_%,$(.VARIABLES)),-G$(subst PARAM_,,$(v))=$($(v)))

	ifeq ($(WAVES), 1)
		COMPILE_ARGS += --trace-fst
		VERILATOR_TRACE = 1
	endif
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
