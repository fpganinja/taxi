# SPDX-License-Identifier: MIT
###################################################################
#
# Xilinx Vivado FPGA Makefile
#
# Copyright (c) 2016-2025 Alex Forencich
#
###################################################################
#
# Parameters:
# FPGA_TOP - Top module name
# FPGA_FAMILY - FPGA family (e.g. VirtexUltrascale)
# FPGA_DEVICE - FPGA device (e.g. xcvu095-ffva2104-2-e)
# SYN_FILES - list of source files
# INC_FILES - list of include files
# XDC_FILES - list of timing constraint files
# XCI_FILES - list of IP XCI files
# IP_TCL_FILES - list of IP TCL files (sourced during project creation)
# CONFIG_TCL_FILES - list of config TCL files (sourced before each build)
#
# Note: both SYN_FILES and INC_FILES support file list files.  File list
# files are files with a .f extension that contain a list of additional
# files to include, one path relative to the .f file location per line.
# The .f files are processed recursively, and then the complete file list
# is de-duplicated, with later files in the list taking precedence.
#
# Example:
#
# FPGA_TOP = fpga
# FPGA_FAMILY = VirtexUltrascale
# FPGA_DEVICE = xcvu095-ffva2104-2-e
# SYN_FILES = rtl/fpga.v
# XDC_FILES = fpga.xdc
# XCI_FILES = ip/pcspma.xci
# include ../common/vivado.mk
#
###################################################################

# phony targets
.PHONY: fpga vivado tmpclean clean distclean

# prevent make from deleting intermediate files and reports
.PRECIOUS: %.xpr %.bit %.bin %.ltx %.xsa %.mcs %.prm
.SECONDARY:

CONFIG ?= config.mk
-include $(CONFIG)

FPGA_TOP ?= fpga
PROJECT ?= $(FPGA_TOP)
XDC_FILES ?= $(PROJECT).xdc

# handle file list files
process_f_file = $(call process_f_files,$(addprefix $(dir $1),$(shell cat $1)))
process_f_files = $(foreach f,$1,$(if $(filter %.f,$f),$(call process_f_file,$f),$f))
uniq_base = $(if $1,$(call uniq_base,$(foreach f,$1,$(if $(filter-out $(notdir $(lastword $1)),$(notdir $f)),$f,))) $(lastword $1))
SYN_FILES := $(call uniq_base,$(call process_f_files,$(SYN_FILES)))
INC_FILES := $(call uniq_base,$(call process_f_files,$(INC_FILES)))

###################################################################
# Main Targets
#
# all: build everything (fpga)
# fpga: build FPGA config
# vivado: open project in Vivado
# tmpclean: remove intermediate files
# clean: remove output files and project files
# distclean: remove archived output files
###################################################################

all: fpga

fpga: $(PROJECT).bit

vivado: $(PROJECT).xpr
	vivado $(PROJECT).xpr

tmpclean::
	-rm -rf *.log *.jou *.cache *.gen *.hbs *.hw *.ip_user_files *.runs *.xpr *.html *.xml *.sim *.srcs *.str .Xil defines.v
	-rm -rf create_project.tcl update_config.tcl run_synth.tcl run_impl.tcl generate_bit.tcl

clean:: tmpclean
	-rm -rf *.bit *.bin *.ltx *.xsa program.tcl generate_mcs.tcl *.mcs *.prm flash.tcl
	-rm -rf *_utilization.rpt *_utilization_hierarchical.rpt

distclean:: clean
	-rm -rf rev

###################################################################
# Target implementations
###################################################################

# Vivado project file

# create fresh project if Makefile or IP files have changed
create_project.tcl: Makefile $(XCI_FILES) $(IP_TCL_FILES)
	rm -rf defines.v
	touch defines.v
	for x in $(DEFS); do echo '`define' $$x >> defines.v; done
	echo "create_project -force -part $(FPGA_PART) $(PROJECT)" > $@
	echo "add_files -fileset sources_1 defines.v $(SYN_FILES)" >> $@
	echo "set_property top $(FPGA_TOP) [current_fileset]" >> $@
	echo "add_files -fileset constrs_1 $(XDC_FILES)" >> $@
	for x in $(XCI_FILES); do echo "import_ip $$x" >> $@; done
	for x in $(IP_TCL_FILES); do echo "source $$x" >> $@; done
	for x in $(CONFIG_TCL_FILES); do echo "source $$x" >> $@; done

# source config TCL scripts if any source file has changed
update_config.tcl: $(CONFIG_TCL_FILES) $(SYN_FILES) $(INC_FILES) $(XDC_FILES)
	echo "open_project -quiet $(PROJECT).xpr" > $@
	for x in $(CONFIG_TCL_FILES); do echo "source $$x" >> $@; done

$(PROJECT).xpr: create_project.tcl update_config.tcl
	vivado -nojournal -nolog -mode batch $(foreach x,$?,-source $x)

# synthesis run
$(PROJECT).runs/synth_1/$(PROJECT).dcp: create_project.tcl update_config.tcl $(SYN_FILES) $(INC_FILES) $(XDC_FILES) | $(PROJECT).xpr
	echo "open_project $(PROJECT).xpr" > run_synth.tcl
	echo "reset_run synth_1" >> run_synth.tcl
	echo "launch_runs -jobs 4 synth_1" >> run_synth.tcl
	echo "wait_on_run synth_1" >> run_synth.tcl
	vivado -nojournal -nolog -mode batch -source run_synth.tcl

# implementation run
$(PROJECT).runs/impl_1/$(PROJECT)_routed.dcp: $(PROJECT).runs/synth_1/$(PROJECT).dcp
	echo "open_project $(PROJECT).xpr" > run_impl.tcl
	echo "reset_run impl_1" >> run_impl.tcl
	echo "launch_runs -jobs 4 impl_1" >> run_impl.tcl
	echo "wait_on_run impl_1" >> run_impl.tcl
	echo "open_run impl_1" >> run_impl.tcl
	echo "report_utilization -file $(PROJECT)_utilization.rpt" >> run_impl.tcl
	echo "report_utilization -hierarchical -file $(PROJECT)_utilization_hierarchical.rpt" >> run_impl.tcl
	vivado -nojournal -nolog -mode batch -source run_impl.tcl

# output files (including potentially bit, bin, ltx, and xsa)
$(PROJECT).bit $(PROJECT).bin $(PROJECT).ltx $(PROJECT).xsa: $(PROJECT).runs/impl_1/$(PROJECT)_routed.dcp
	echo "open_project $(PROJECT).xpr" > generate_bit.tcl
	echo "open_run impl_1" >> generate_bit.tcl
	echo "write_bitstream -force -bin_file $(PROJECT).runs/impl_1/$(PROJECT).bit" >> generate_bit.tcl
	echo "write_debug_probes -force $(PROJECT).runs/impl_1/$(PROJECT).ltx" >> generate_bit.tcl
	echo "write_hw_platform -fixed -force -include_bit $(PROJECT).xsa" >> generate_bit.tcl
	vivado -nojournal -nolog -mode batch -source generate_bit.tcl
	ln -f -s $(PROJECT).runs/impl_1/$(PROJECT).bit .
	ln -f -s $(PROJECT).runs/impl_1/$(PROJECT).bin .
	if [ -e $(PROJECT).runs/impl_1/$(PROJECT).ltx ]; then ln -f -s $(PROJECT).runs/impl_1/$(PROJECT).ltx .; fi
	mkdir -p rev
	COUNT=100; \
	while [ -e rev/$(PROJECT)_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	cp -pv $(PROJECT).runs/impl_1/$(PROJECT).bit rev/$(PROJECT)_rev$$COUNT.bit; \
	cp -pv $(PROJECT).runs/impl_1/$(PROJECT).bin rev/$(PROJECT)_rev$$COUNT.bin; \
	if [ -e $(PROJECT).runs/impl_1/$(PROJECT).ltx ]; then cp -pv $(PROJECT).runs/impl_1/$(PROJECT).ltx rev/$(PROJECT)_rev$$COUNT.ltx; fi; \
	if [ -e $(PROJECT).xsa ]; then cp -pv $(PROJECT).xsa rev/$(PROJECT)_rev$$COUNT.xsa; fi
