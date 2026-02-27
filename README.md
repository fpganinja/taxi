# Taxi Transport Library

[![Regression Tests](https://github.com/fpganinja/taxi/actions/workflows/regression-tests.yml/badge.svg)](https://github.com/fpganinja/taxi/actions/workflows/regression-tests.yml)

The home of Corundum, Zircon, and XFCP, plus AXI, AXI stream, Ethernet, and PCIe components in System Verilog.

GitHub repository: https://github.com/fpganinja/taxi

Documentation: https://docs.fpga.taxi/

## Introduction

The goal of the Taxi transport library is to provide a set of performant, easy-to-use building blocks in modern System Verilog facilitating data transport and interfacing, both internally via AXI, AXI stream, and APB, and externally via Ethernet, PCI express, UART, and I2C.  This project is also the home of the next-generation version of the Corundum open-souce NIC and platform for in-network compute, as well as the Zircon open-source IP stack.  The building blocks are accompanied by testbenches and simulation models utilizing Cocotb and Verilator.

This library is currently under development; more components will be added over time as they are developed.

## License

Taxi is provided by FPGA Ninja, LLC under either the CERN Open Hardware Licence Version 2 - Strongly Reciprocal (CERN-OHL-S 2.0), or a paid commercial license.  Contact info@fpga.ninja for commercial use.  Note that some components may be provided under less restrictive licenses (e.g. example designs).

Under the strongly-reciprocal CERN OHL, you must provide the source code of the entire digital design upon request, including all modifications, extensions, and customizations, such that the design can be rebuilt.  If this is not an acceptable restriction for your product, please contact info@fpga.ninja to inquire about a commercial license without this requirement.  License fees support the continued development and maintenance of this project and related projects.

To facilitate the dual-license model, contributions to the project can only be accepted under a contributor license agreement.

## Corundum NIC

Corundum is an open-source, high-performance FPGA-based NIC and platform for in-network compute.  Features include a high performance datapath, 10G/25G/100G Ethernet, PCI express gen 3+, a custom, high performance, tightly-integrated PCIe DMA engine, many (1000+) transmit, receive, completion, and event queues, scatter/gather DMA, MSI/MSI-X interrupts, per-port transmit scheduling, flow hashing, RSS, checksum offloading, and native IEEE 1588 PTP timestamping.  A Linux driver is included that integrates with the Linux networking stack.  Development and debugging is facilitated by an extensive simulation framework that covers the entire system from a simulation model of the driver and PCI express interface on the host side and Ethernet interfaces on the network side.

Several variants of Corundum are planned, sharing the same host interface and device driver but targeting different optimization points:

*  corundum-micro: size-optimized for applications like SoCs and low-bandwidth NICs, supporting several ports at 1 Gbps up to 10-25 Gbps
*  corundum-lite: middle of the road design, supporting multiple ports at 10G/25G or one port at 100G, up to around 100 Gbps aggregate
*  corundum-ng: intended for high-performance packet processing with deep pipelines and segmented internal interfaces, supporting operation at up to 400 Gbps aggregate
*  corundum-proto: simplified design with simplified driver, intended for educational purposes only

Planned features include a DPDK driver, SR-IOV, AF_XDP, white rabbit/IEEE 1588 HA, and Zircon stack integration.

Note that Corundum is still under active development and may not ready for production use; additional functionality and improvements to performance and flexibility will be made over time.

## Zircon IP stack

The Zircon IP stack implements IPv4, IPv6, and UDP support from 1 Gbps to 100 Gbps.  It handles parsing and deparsing the packet headers, inserting and removing VLAN tags, computing and verifying header and payload checksums, matching RX packet fields against configured rules, and multiplexing between multiple internal application interfaces.  The stack can be configured to pass packets to application logic either umodified, with VLAN tags stripped, with simplified headers, or with only the payloads.

Planned features include support for TCP, RDMA, and integration with Corundum.

Note that Zircon is still under active development and may not ready for production use; additional functionality and improvements to performance and flexibility will be made over time.

## Ethernet MAC and PHY

The Taxi transport library contains several Ethernet MAC and PCS variants, covering link rates from 10 Mbps to 25 Gbps.  The MAC modules support LFC and PFC pause frames, PTP timestamping, frame length enforcement, FCS computation and verification, and statistics reporting.  PTP TD leaf clocks and statistics collection components are also integrated, configurable via instance parameters.  Wrappers for low-speed operation support MII, GMII, and RGMII PHY-attach protocols for use with an external PHY chip.  Wrappers for 10G/25G include device-specific transceiver instances for a fully-integrated solution.  Logic is available for a 10G/25G MAC, 10G/25G PCS, and 10G/25G "fused" MAC+PCS, with reduced latency and resource consumption.

The 10G/25G MAC/PHY/GT wrapper for 7-series/UltraScale/UltraScale+ supports GTX, GTH, and GTY transceivers.  On UltraScale and UltraScale+ devices, it can be configured for either a 32-bit or 64-bit datapath via the DATA_W parameter.  The 32-bit datapath supports 10G only, while the 64-bit datapath can be used for either 10G or 25G.  TCL scripts for generating the GT cores are provided for both 10G and 25G and for several common reference clocks.  The core supports operation in either a normal latency mode or a low latency mode via the CFG_LOW_LATENCY paremter, which affects the clock frequency and transceiver configuration (async gearbox vs. sync gearbox and buffer bypass).  The low latency mode has a slightly higher clock frequency and resource consumption, so it is not recommended unless you really need to shave off a new nanoseconds of latency, or you need highest possible time sync precision.  On 7-series, the core only supports 32-bit low-latency mode.  The wrapper also provides an APB interface for configuring the transceivers and QPLLs.

The 10G/25G MAC and PCS logic is also highly optimized for both size and timing performance, with 60 instances fitting comfortably on an XCVU9P -2 on the HTG9200 board, fully utilizing 15 QSFP28 (9 on the board plus 6 via FMC+, 60 lanes total).  With the low-latency MACs, statistics collection, loopback FIFOs, and XFCP, the footprint is about 15% of the device LUTs at 25G (about 3000 LUTs and 2500 FFs per channel) and about 10% of the device LUTs at 10G (about 2000 LUTs and 2100 FFs per channel).  The 10G configuration closes timing on the KC705 (single SFP+, 1 lane total) with an XC7K325T -2 at 322.265625 MHz, and the 25G configuration closes timing on the XUSP3S (quad QSFP38, 16 lanes total) with an XCVU095 -2 at 402.83203125 MHz.

Planned features include 1000BASE-X, SGMII, USXGMII, dynamic rate switching, AN, better integration of the PTP TD subsystem, and white rabbit/IEEE 1588 HA support.

## Statistics collection subsystem

The statistics collection subsystem provides a mechanism for aggregating statistical information from multiple components in a design.  The statistics collector module accepts inputs in the form of increment values, accumulates those in an internal RAM, and periodically dumps the counter values via AXI stream where they can be merged and easily passed between clock domains.  The statistics counter module accepts the counter values and accumulates them in a larger RAM (BRAM or URAM), providing an AXI-lite register interface to read the counters.  The statistics collection subsystem can also distribute and collect informational strings along with the counter values, which can facilitate debugging and automatic discovery of implemented statistics channels.  Statistics collector modules are integrated into several library components, like the Ethernet MACs, for ease of integration.

## PTP time distribution subsystem

The PTP time distribution subsystem provides a low-overhead method for precisely distributing and synchronizing a central PTP hardware clock (PHC) into multiple destination clock domains, potentially spread out across the target device.  The PTP TD subsystem derives the 96-bit ToD clock from the 64-bit relative clock, enabling timestamp capture and manipulation to be done efficiently with a trucated relative timestamp which can be expanded to a full 96-bit ToD timestamp where the full resolution is needed.  The PTP TD PHC module supports non-precision setting as well as precision atomic ofsetting of the clock, and uses a 32-bit extended fractional ns accumulator with an additional rational remainder to eliminate round-off error for common reference clock periods.  The PTP TD PHC is connected to the leaf clocks through a single wire that carries serial data used to synchronize the leaf clocks, as well as a common reference clock.  The leaf clocks can insert a configurable number pipeline registers and automatically compensate for the resulting delay.  The leaf clock modules reconstruct the PTP time from the PHC locally in the PTP reference clock domain, then use a digital PLL to synthesize and deskew a new PTP time source in the destination clock domain.

Planned features include better integration into the MAC and PCS logic for ease of use and to compensate for transceiver gearbox delay variance, DDMTD for picosecond-level precision, and white rabbit/IEEE 1588 HA support.

## XFCP

The Extensible FPGA control platform (XFCP) is a framework that enables simple interfacing between an FPGA design in verilog and control software.  XFCP uses a source-routed packet switched bus over AXI stream to interconnect components in an FPGA design, eliminating the need to assign and manage addresses, enabling simple bus enumeration, and vastly reducing dependencies between the FPGA design and the control software.  XFCP currently supports operation over UART.  XFCP includes an interface modules for UART, a parametrizable arbiter to enable simultaneous use of multiple interfaces, a parametrizable switch to connect multiple on-FPGA components, bridges for interfacing with various devices including AXI, AXI-lite, APB, and I2C, and a Python framework for enumerating XFCP buses and controlling connected devices.

Planned features include support for UDP via the Zircon stack.

## List of library components

The Taxi transport library contains many smaller components that can be composed to build larger designs.

*  APB
    *  SV interface for APB
    *  APB to AXI lite adapter
    *  Interconnect
    *  Width converter
    *  Single-port RAM
    *  Dual-port RAM
*  AXI
    *  SV interface for AXI
    *  AXI to AXI lite adapter
    *  Crossbar
    *  Interconnect
    *  Register slice
    *  Width converter
    *  Synchronous FIFO
    *  Single-port RAM
*  AXI lite
    *  SV interface for AXI lite
    *  AXI lite to AXI adapter
    *  AXI lite to APB adapter
    *  Crossbar
    *  Interconnect
    *  Register slice
    *  Width converter
    *  Single-port RAM
    *  Dual-port RAM
*  AXI stream
    *  SV interface for AXI stream
    *  Register slice
    *  Width converter
    *  Synchronous FIFO
    *  Asynchronous FIFO
    *  Combined FIFO + width converter
    *  Combined async FIFO + width converter
    *  Multiplexer
    *  Demultiplexer
    *  Broadcaster
    *  Concatenator
    *  Switch
    *  COBS encoder
    *  COBS decoder
    *  Pipeline register
    *  Pipeline FIFO
*  Direct Memory Access
    *  SV interface for segmented RAM
    *  SV interface for DMA descriptors
    *  AXI central DMA
    *  AXI streaming DMA
    *  DMA client for AXI stream
    *  DMA interface for AXI
    *  DMA interface for UltraScale PCIe
    *  DMA descriptor mux
    *  DMA RAM demux
    *  DMA interface mux
    *  Segmented SDP RAM
    *  Segmented dual-clock SDP RAM
*  Ethernet
    *  10/100 MII MAC
    *  10/100 MII MAC + FIFO
    *  10/100/1000 GMII MAC
    *  10/100/1000 GMII MAC + FIFO
    *  10/100/1000 RGMII MAC
    *  10/100/1000 RGMII MAC + FIFO
    *  1G MAC
    *  1G MAC + FIFO
    *  10G/25G MAC
    *  10G/25G MAC + FIFO
    *  10G/25G MAC/PHY
    *  10G/25G MAC/PHY + FIFO
    *  10G/25G PHY
    *  MII PHY interface
    *  GMII PHY interface
    *  RGMII PHY interface
    *  10G/25G MAC/PHY/GT wrapper for 7-series/UltraScale/UltraScale+
*  General input/output
    *  Switch debouncer
    *  LED shift register driver
    *  Generic IDDR
    *  Generic ODDR
    *  Source-synchronous DDR input
    *  Source-synchronous DDR differential input
    *  Source-synchronous DDR output
    *  Source-synchronous DDR differential output
    *  Source-synchronous SDR input
    *  Source-synchronous SDR differential input
    *  Source-synchronous SDR output
    *  Source-synchronous SDR differential output
*  Linear-feedback shift register
    *  Parametrizable combinatorial LFSR/CRC module
    *  CRC computation module
    *  PRBS generator
    *  PRBS checker
    *  LFSR self-synchronizing scrambler
    *  LFSR self-synchronizing descrambler
*  Low-speed serial
    *  I2C master
    *  I2C single register
    *  I2C slave
    *  I2C slave APB master
    *  I2C slave AXI lite master
    *  MDIO master
    *  UART
*  Math
    *  MT19937/MT19937-64 Mersenne Twister PRNG
*  PCI Express
    *  PCIe AXI lite master
    *  PCIe AXI lite master for Xilinx UltraScale
    *  MSI shim for Xilinx UltraScale
    *  MSI-X with AXI lite control interface
    *  MSI-X with APB control interface
*  Primitives
    *  Arbiter
    *  Priority encoder
*  Precision Time Protocol (PTP)
    *  PTP clock
    *  PTP CDC
    *  PTP period output
    *  PTP TD leaf clock
    *  PTP TD PHC
    *  PTP TD PHC wrapper with APB register interface
    *  PTP TD PHC wrapper with AXI lite register interface
    *  PTP TD relative-to-ToD converter
*  Statistics collection subsystem
    *  Statistics collector
    *  Statistics counter
*  Synchronization primitives
    *  Reset synchronizer
    *  Signal synchronizer
*  Extensible FPGA control protocol (XFCP)
    *  XFCP UART interface
    *  XFCP APB module
    *  XFCP AXI module
    *  XFCP AXI lite module
    *  XFCP I2C master module
    *  XFCP switch

## Example designs

Example designs are provided for several different FPGA boards, showcasing many of the capabilities of this library.  Building the example designs will require the appropriate vendor toolchain and may also require tool and IP licenses.

*  Alpha Data ADM-PCIE-9V3 (Xilinx Virtex UltraScale+ XCVU3P)
*  BittWare XUSP3S (Xilinx Virtex UltraScale XCVU095)
*  BittWare XUP-P3R (Xilinx Virtex UltraScale+ XCVU9P)
*  Cisco Nexus K35-S/ExaNIC X10 (Xilinx Kintex UltraScale XCKU035)
*  Cisco Nexus K3P-S/ExaNIC X25 (Xilinx Kintex UltraScale+ XCKU3P)
*  Cisco Nexus K3P-Q/ExaNIC X100 (Xilinx Kintex UltraScale+ XCKU3P)
*  Alibaba AS02MC04 (Xilinx Kintex UltraScale+ XCKU3P)
*  RK-XCKU5P-F (Xilinx Kintex UltraScale+ XCKU5P)
*  Digilent Arty A7 (Xilinx Artix 7 XC7A35T)
*  Digilent NetFPGA SUME (Xilinx Virtex 7 XC7V690T)
*  HiTech Global HTG-940 (Xilinx Virtex UltraScale+ XCVU9P/XCVU13P)
*  HiTech Global HTG-9200 (Xilinx Virtex UltraScale+ XCVU9P/XCVU13P)
*  HiTech Global HTG-ZRF8-R2 (Xilinx Zynq UltraScale+ RFSoC XCZU28DR/XCZU48DR)
*  HiTech Global HTG-ZRF8-EM (Xilinx Zynq UltraScale+ RFSoC XCZU28DR/XCZU48DR)
*  Opal Kelley XEM8320 (Xilinx Artix UltraScale+ XCAU25P)
*  Silicom fb2CG@KU15P (Xilinx Kintex UltraScale+ XCKU15P)
*  Xilinx Alveo U45N/SN1000 (Xilinx Virtex UltraScale+ XCU26)
*  Xilinx Alveo U50 (Xilinx Virtex UltraScale+ XCU50)
*  Xilinx Alveo U55C (Xilinx Virtex UltraScale+ XCU55C)
*  Xilinx Alveo U55N/Varium C1100 (Xilinx Virtex UltraScale+ XCU55N)
*  Xilinx Alveo U200 (Xilinx Virtex UltraScale+ XCU200)
*  Xilinx Alveo U250 (Xilinx Virtex UltraScale+ XCU250)
*  Xilinx Alveo U280 (Xilinx Virtex UltraScale+ XCU280)
*  Xilinx Alveo X3/X3522 (Xilinx Virtex UltraScale+ XCUX35)
*  Xilinx KC705 (Xilinx Kintex 7 XC7K325T)
*  Xilinx KCU105 (Xilinx Kintex UltraScale XCKU040)
*  Xilinx Kria KR260 (Xilinx Kria K26 SoM / Zynq UltraScale+ XCK26)
*  Xilinx VC709 (Xilinx Virtex 7 XC7V690T)
*  Xilinx VCU108 (Xilinx Virtex UltraScale XCVU095)
*  Xilinx VCU118 (Xilinx Virtex UltraScale+ XCVU9P)
*  Xilinx VCU1525 (Xilinx Virtex UltraScale+ XCVU9P)
*  Xilinx ZCU102 (Xilinx Zynq UltraScale+ XCZU9EG)
*  Xilinx ZCU106 (Xilinx Zynq UltraScale+ XCZU7EV)
*  Xilinx ZCU111 (Xilinx Zynq UltraScale+ RFSoC XCZU28DR)

## Testing

Running the included testbenches requires the following packages:

*  [cocotb](https://github.com/cocotb/cocotb)
*  [cocotbext-axi](https://github.com/alexforencich/cocotbext-axi)
*  [cocotbext-eth](https://github.com/alexforencich/cocotbext-eth)
*  [cocotbext-uart](https://github.com/alexforencich/cocotbext-uart)
*  [cocotbext-pcie](https://github.com/alexforencich/cocotbext-pcie)
*  [Verilator](https://www.veripool.org/verilator/)

The testbenches can be run with pytest directly (requires [cocotb-test](https://github.com/themperek/cocotb-test)), pytest via tox, or via cocotb makefiles.
