# Corundum for VCU118

## Introduction

This design targets the Xilinx VCU118 FPGA board.

*  USB UART
    *  XFCP (921600 baud)
*  RJ-45 Ethernet port with TI DP83867ISRGZ PHY
    *  Looped-back MAC via SGMII via Xilinx PCS/PMA core and LVDS IOSERDES
*  QSFP28
    *  10GBASE-R or 25GBASE-R MACs via GTY transceivers

## Board details

*  FPGA: xcvu9p-flga2104-2L-e
*  USB UART: Silicon Labs CP2105 SCI
*  PCIe: gen 3 x16 (~128 Gbps)
*  Reference oscillator: 156.26 MHz from Si570
*  1000BASE-T PHY: TI DP83867ISRGZ via SGMII
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
