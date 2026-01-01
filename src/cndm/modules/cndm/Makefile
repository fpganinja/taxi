# SPDX-License-Identifier: GPL
# Copyright (c) 2025 FPGA Ninja

ifneq ($(KERNELRELEASE),)

obj-m += cndm.o
cndm-y += cndm_main.o
cndm-y += cndm_devlink.o
cndm-y += cndm_dev.o
cndm-y += cndm_netdev.o
cndm-y += cndm_tx.o
cndm-y += cndm_rx.o

ifneq ($(DEBUG),)
ccflags-y += -DDEBUG
endif

else

ifneq ($(KERNEL_SRC),)
KDIR ?= $(KERNEL_SRC)
endif

KDIR ?= /lib/modules/$(shell uname -r)/build

all: modules

help modules modules_install clean:
	$(MAKE) -C $(KDIR) M=$(shell pwd) $@

install: modules_install

endif
