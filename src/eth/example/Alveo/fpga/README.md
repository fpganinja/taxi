# Taxi Example Design for Alveo

## Introduction

This example design targets the Xilinx Alveo series.

The design places looped-back MACs on the Ethernet ports, as well as XFCP on the USB UART for monitoring and control.

*  USB UART
    *  XFCP (3 Mbaud)
*  DSFP/QSFP28
    *  Looped-back 10GBASE-R or 25GBASE-R MACs via GTY transceivers

## Board details

*  AU45N/SN1000
    *  FPGA: xcu26-vsva1365-2LV-e
    *  USB UART: FTDI FT4232H (DMB-2)
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU50
    *  FPGA: xcu50-fsvh2104-2-e
    *  USB UART: FTDI FT4232H (3 via DMB-1)
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU55C
    *  FPGA: xcu55c-fsvh2892-2L-e
    *  USB UART: FTDI FT4232H (2 onboard, all 3 via DMB-1)
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU55N/C1100
    *  FPGA: xcu55n-fsvh2892-2L-e
    *  USB UART: FTDI FT4232H (2 onboard, all 3 via DMB-1)
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU200
    *  FPGA: xcu200-fsgd2104-2-e
    *  USB UART: FTDI FT4232H
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU250
    *  FPGA: xcu250-fsgd2104-2-e
    *  USB UART: FTDI FT4232H
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  AU280
    *  FPGA: xcu280-fsvh2892-2L-e
    *  USB UART: FTDI FT4232H
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  VCU1525
    *  FPGA: xcvu9p-fsgd2104-2L-e
    *  USB UART: FTDI FT4232H
    *  25GBASE-R PHY: Soft PCS with GTY transceivers
*  X3/X3522
    *  FPGA: xcux35-vsva1365-3-e
    *  USB UART: FTDI FT4232H (DMB-2)
    *  25GBASE-R PHY: Soft PCS with GTY transceivers

## Licensing

*  Toolchain
    *  Vivado Standard (enterprise license not required)
*  IP
    *  No licensed vendor IP or 3rd party IP

## How to build

Run `make` in the appropriate `fpga*` subdirectory to build the bitstream.  Ensure that the Xilinx Vivado toolchain components are in PATH.

## How to test

Run `make program` to program the board with Vivado.

To test the looped-back MAC, it is recommended to use a network tester like the Viavi T-BERD 5800 that supports basic layer 2 tests with a loopback.  Do not connect the looped-back MAC to a network as the reflected packets may cause problems.
