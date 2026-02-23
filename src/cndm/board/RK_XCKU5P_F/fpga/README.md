# Corundum for RK-XCKU5P-F

## Introduction

This design targets the RK-XCKU5P-F FPGA board.

*  USB UART
  *  XFCP (3 Mbaud)
* QSFP28 cage
  * 10GBASE-R or 25GBASE-R MAC via GTY transceiver

## Board details

* FPGA: xcku5p-ffvb676-2-e
* USB UART: FTDI FT2232
* PCIe: gen 3 x4 (~32 Gbps)
* Reference oscillator: Fixed 156.25 MHz
* 25GBASE-R PHY: Soft PCS with GTY transceiver

## Licensing

* Toolchain
  * Vivado Standard (enterprise license not required)
* IP
  * No licensed vendor IP or 3rd party IP

## How to build

Run `make` in the appropriate `fpga*` subdirectory to build the bitstream.  Ensure that the Xilinx Vivado toolchain components are in PATH.

On the host system, run `make` in `modules/cndm` to build the driver.  Ensure that the headers for the running kernel are installed, otherwise the driver cannot be compiled.

## How to test

Run `make program` to program the board with Vivado.  Then, reboot the machine to re-enumerate the PCIe bus.  Finally, load the driver on the host system with `insmod cndm.ko`.  Check `dmesg` for output from driver initialization.  Run `cndm_ddcmd.sh =p` to enable all debug messages.
