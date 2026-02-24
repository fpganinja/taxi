# Corundum for ADM-PCIE-9V3

## Introduction

This design targets the Alpha Data ADM-PCIE-9V3 FPGA board.

*  QSFP28
    *  10GBASE-R or 25GBASE-R MACs via GTY transceivers

## Board details

*  FPGA: xcvu3p-ffvc1517-2-i
*  PCIe: gen 3 x16 (~128 Gbps)
*  Reference oscillator: 161.1328125 MHz from Si5338
*  25GBASE-R PHY: Soft PCS with GTY transceivers

## Licensing

*  Toolchain
    *  Vivado Enterprise (requires license)
*  IP
    *  No licensed vendor IP or 3rd party IP

## How to build

Run `make` in the appropriate `fpga*` subdirectory to build the bitstream.  Ensure that the Xilinx Vivado toolchain components are in PATH.

On the host system, run `make` in `modules/cndm` to build the driver.  Ensure that the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the board with Vivado.  Then, reboot the machine to re-enumerate the PCIe bus.  Finally, load the driver on the host system with `insmod cndm.ko`.  Check `dmesg` for output from driver initialization.  Run `cndm_ddcmd.sh =p` to enable all debug messages.
