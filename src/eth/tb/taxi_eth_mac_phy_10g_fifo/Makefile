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

DUT      = taxi_eth_mac_phy_10g_fifo
COCOTB_TEST_MODULES = test_$(DUT)
COCOTB_TOPLEVEL     = test_$(DUT)
MODULE   = $(COCOTB_TEST_MODULES)
TOPLEVEL = $(COCOTB_TOPLEVEL)
VERILOG_SOURCES += $(COCOTB_TOPLEVEL).sv
VERILOG_SOURCES += $(RTL_DIR)/$(DUT).f

# handle file list files
process_f_file = $(call process_f_files,$(addprefix $(dir $1),$(shell cat $1)))
process_f_files = $(foreach f,$1,$(if $(filter %.f,$f),$(call process_f_file,$f),$f))
uniq_base = $(if $1,$(call uniq_base,$(foreach f,$1,$(if $(filter-out $(notdir $(lastword $1)),$(notdir $f)),$f,))) $(lastword $1))
VERILOG_SOURCES := $(call uniq_base,$(call process_f_files,$(VERILOG_SOURCES)))

# module parameters
export PARAM_DATA_W := 64
export PARAM_HDR_W := 2
export PARAM_TX_GBX_IF_EN := 1
export PARAM_RX_GBX_IF_EN := $(PARAM_TX_GBX_IF_EN)
export PARAM_USXGMII_EN := 0
export PARAM_AXIS_DATA_W := $(PARAM_DATA_W)
export PARAM_DIC_EN := 1
export PARAM_PTP_TS_EN := 1
export PARAM_PTP_TD_EN := $(PARAM_PTP_TS_EN)
export PARAM_PTP_TS_FMT_TOD := 1
export PARAM_PTP_TS_W := $(if $(filter-out 1,$(PARAM_PTP_TS_FMT_TOD)),64,96)
export PARAM_PTP_TD_SDI_PIPELINE := 2
export PARAM_TX_TAG_W := 16
export PARAM_BIT_REVERSE := 0
export PARAM_SCRAMBLER_DISABLE := 0
export PARAM_PRBS31_EN := 1
export PARAM_TX_SERDES_PIPELINE := 2
export PARAM_RX_SERDES_PIPELINE := 2
export PARAM_BITSLIP_HIGH_CYCLES := 0
export PARAM_BITSLIP_LOW_CYCLES := 7
export PARAM_COUNT_125US := 195
export PARAM_STAT_EN := 1
export PARAM_STAT_TX_LEVEL := 2
export PARAM_STAT_RX_LEVEL := $(PARAM_STAT_TX_LEVEL)
export PARAM_STAT_ID_BASE := 0
export PARAM_STAT_UPDATE_PERIOD := 1024
export PARAM_STAT_STR_EN := 1
export PARAM_STAT_PREFIX_STR := "\"MAC\""
export PARAM_TX_FIFO_DEPTH := 16384
export PARAM_TX_FIFO_RAM_PIPELINE := 1
export PARAM_TX_FRAME_FIFO := 1
export PARAM_TX_DROP_OVERSIZE_FRAME := $(PARAM_TX_FRAME_FIFO)
export PARAM_TX_DROP_BAD_FRAME := $(PARAM_TX_DROP_OVERSIZE_FRAME)
export PARAM_TX_DROP_WHEN_FULL := 0
export PARAM_TX_CPL_FIFO_DEPTH := 64
export PARAM_RX_FIFO_DEPTH := 16384
export PARAM_RX_FIFO_RAM_PIPELINE := 1
export PARAM_RX_FRAME_FIFO := 1
export PARAM_RX_DROP_OVERSIZE_FRAME := $(PARAM_RX_FRAME_FIFO)
export PARAM_RX_DROP_BAD_FRAME := $(PARAM_RX_DROP_OVERSIZE_FRAME)
export PARAM_RX_DROP_WHEN_FULL := $(PARAM_RX_DROP_OVERSIZE_FRAME)

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
