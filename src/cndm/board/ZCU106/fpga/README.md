# Corundum for ZCU106

## Introduction

This design targets the Xilinx ZCU106 FPGA board.

*  USB UART
    *  XFCP (2 Mbaud)
*  SFP+
    *  10GBASE-R MACs via GTH transceivers

## Board details

*  FPGA: xczu7ev-ffvc1156-2-e
*  USB UART: Silicon Labs CP2108
*  PCIe: gen 3 x4 (~32 Gbps)
*  Reference oscillator: 156.25 MHz from Si570
*  10GBASE-R PHY: Soft PCS with GTH transceivers

## Licensing

*  Toolchain
    *  Vivado Standard (enterprise license not required)
*  IP
    *  No licensed vendor IP or 3rd party IP

## How to build

Run `make` in the appropriate `fpga*` subdirectory to build the bitstream.  Ensure that the Xilinx Vivado toolchain components are in PATH.

On the host system, run `make` in `modules/cndm` to build the driver.  Ensure that the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the board with Vivado.  Then, reboot the machine to re-enumerate the PCIe bus.  Finally, load the driver on the host system with `insmod cndm.ko`.  Check `dmesg` for output from driver initialization.  Run `cndm_ddcmd.sh =p` to enable all debug messages.
