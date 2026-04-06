# Taxi Example Design for NT200A01/NT200A02

## Introduction

This example design targets the Napatech NT200A01/NT200A02 FPGA board.

The design places looped-back MACs on the QSFP28 ports.

* QSFP28
  * Looped-back 10GBASE-R or 25GBASE-R MACs via GTY transceivers

## Board details

* FPGA
  * NT200A01: xcvu095-ffva2104-2-e
  * NT200A02: xcvu5p-flva2104-2-e
* 25GBASE-R PHY: Soft PCS with GTY transceivers

## Licensing

* Toolchain
  * Vivado Enterprise (requires license)
* IP
  * No licensed vendor IP or 3rd party IP

## How to build

Run `make` in the appropriate `fpga*` subdirectory to build the bitstream.  Ensure that the Xilinx Vivado toolchain components are in PATH.

## How to test

Run `make program` to program the board with Vivado.

To test the looped-back MAC, it is recommended to use a network tester like the Viavi T-BERD 5800 that supports basic layer 2 tests with a loopback.  Do not connect the looped-back MAC to a network as the reflected packets may cause problems.

## JTAG pinout

Napatech boards use a non-standard connector for JTAG.  There are three debug connectors, and one of them carries the JTAG signals for the FPGA.

        J16             J22
        FPGA            AVR
    TDI 7 8 GND     TDI 7 8 GND
    TMS 5 6 HALT    TMS 5 6
    TDO 3 4 Vref    TDO 3 4 Vref
    TCK 1 2 GND     TCK 1 2 GND

            J17
        GND 2 1
            4 3
            6 5

Note: J18.6 HALT must be driven low to access the JTAG chain.  So, either tie to to ground, or connect it to the HALT signal on DLC9/DLC10 cables.
