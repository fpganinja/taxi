# Corundum for Alveo

## Introduction

This design targets the Xilinx Alveo series.

*  USB UART
    *  XFCP (3 Mbaud)
*  DSFP/QSFP28
    *  10GBASE-R or 25GBASE-R MACs via GTY transceivers

## Board details

*  AU45N/SN1000
    *  FPGA: xcu26-vsva1365-2LV-e
    *  USB UART: FTDI FT4232H (DMB-2)
    *  PCIe: gen 3 x16 (~128 Gbps) or dual bifurcated gen 4 x8 (~256 Gbps)
    *  Reference oscillator: 161.1328125 MHz from Si5394
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU55C
    *  FPGA: xcu55c-fsvh2892-2L-e
    *  USB UART: FTDI FT4232H (2 onboard, all 3 via DMB-1)
    *  PCIe: gen 3 x16 (~128 Gbps) or dual bifurcated gen 4 x8 (~256 Gbps)
    *  Reference oscillator: 161.1328125 MHz from Si5394
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU55N/C1100
    *  FPGA: xcu55n-fsvh2892-2L-e
    *  USB UART: FTDI FT4232H (2 onboard, all 3 via DMB-1)
    *  PCIe: gen 3 x16 (~128 Gbps) or dual bifurcated gen 4 x8 (~256 Gbps)
    *  Reference oscillator: 161.1328125 MHz from Si5394
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU200
    *  FPGA: xcu200-fsgd2104-2-e
    *  USB UART: FTDI FT4232H
    *  PCIe: gen 3 x16 (~128 Gbps)
    *  Reference oscillator: 156.25 MHz from Si570
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU250
    *  FPGA: xcu250-fsgd2104-2-e
    *  USB UART: FTDI FT4232H
    *  PCIe: gen 3 x16 (~128 Gbps)
    *  Reference oscillator: 156.25 MHz from Si570
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  VCU1525
    *  FPGA: xcvu9p-fsgd2104-2L-e
    *  USB UART: FTDI FT4232H
    *  PCIe: gen 3 x16 (~128 Gbps)
    *  Reference oscillator: 156.25 MHz from Si570
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  X3/X3522
    *  FPGA: xcux35-vsva1365-3-e
    *  USB UART: FTDI FT4232H (DMB-2)
    *  PCIe: gen 4 x8 (~128 Gbps)
    *  Reference oscillator: 161.1328125 MHz from Si5394
    *  25GBASE-R PHY: Soft PCS with GTY transceivers

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
