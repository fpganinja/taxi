# Corundum for DNPCIe-40G-KU-LL-2QSFP

## Introduction

This design targets the Dini Group DNPCIe-40G-KU-LL-2QSFP FPGA board.

*  USB UART
    *  XFCP (3 Mbaud)
*  QSFP+
    *  10GBASE-R MACs via GTH transceivers

## Board details

*  FPGA: xcku040-ffva1156-2-e or xcku060-ffva1156-2-e
*  USB UART: FTDI FT2232HQ
*  PCIe: gen 3 x8 (~64 Gbps)
*  Reference oscillator: Fixed 156.25 MHz from Si534
*  10GBASE-R PHY: Soft PCS with GTH transceivers

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
