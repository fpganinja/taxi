#!/usr/bin/env python
# SPDX-License-Identifier: MIT
"""

Copyright (c) 2020-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import itertools
import logging
import os
import sys

import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Combine

from cocotbext.eth import XgmiiFrame

try:
    from baser import BaseRSerdesSource, BaseRSerdesSink
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from baser import BaseRSerdesSource, BaseRSerdesSink
    finally:
        del sys.path[0]


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk_125mhz, 8, units="ns").start())
        cocotb.start_soon(Clock(dut.qsfp_0_mgt_refclk_p, 6.206, units="ns").start())

        self.qsfp_sources = []
        self.qsfp_sinks = []

        for ch in itertools.chain.from_iterable([inst.mac_inst.ch for inst in dut.gt_quad]):
            gt_inst = ch.ch_inst.gt.gt_inst

            if ch.ch_inst.DATA_W.value == 64:
                if ch.ch_inst.CFG_LOW_LATENCY.value:
                    clk = 2.482
                    gbx_cfg = (66, [64, 65])
                else:
                    clk = 2.56
                    gbx_cfg = None
            else:
                if ch.ch_inst.CFG_LOW_LATENCY.value:
                    clk = 3.102
                    gbx_cfg = (66, [64, 65])
                else:
                    clk = 3.2
                    gbx_cfg = None

            cocotb.start_soon(Clock(gt_inst.tx_clk, clk, units="ns").start())
            cocotb.start_soon(Clock(gt_inst.rx_clk, clk, units="ns").start())

            self.qsfp_sources.append(BaseRSerdesSource(
                data=gt_inst.serdes_rx_data,
                data_valid=gt_inst.serdes_rx_data_valid,
                hdr=gt_inst.serdes_rx_hdr,
                hdr_valid=gt_inst.serdes_rx_hdr_valid,
                clock=gt_inst.rx_clk,
                slip=gt_inst.serdes_rx_bitslip,
                reverse=True,
                gbx_cfg=gbx_cfg
            ))
            self.qsfp_sinks.append(BaseRSerdesSink(
                data=gt_inst.serdes_tx_data,
                data_valid=gt_inst.serdes_tx_data_valid,
                hdr=gt_inst.serdes_tx_hdr,
                hdr_valid=gt_inst.serdes_tx_hdr_valid,
                gbx_sync=gt_inst.serdes_tx_gbx_sync,
                clock=gt_inst.tx_clk,
                reverse=True,
                gbx_cfg=gbx_cfg
            ))

        dut.user_sw.setimmediatevalue(0)

    async def init(self):

        self.dut.rst_125mhz.setimmediatevalue(0)

        for k in range(10):
            await RisingEdge(self.dut.clk_125mhz)

        self.dut.rst_125mhz.value = 1

        for k in range(10):
            await RisingEdge(self.dut.clk_125mhz)

        self.dut.rst_125mhz.value = 0

        for k in range(10):
            await RisingEdge(self.dut.clk_125mhz)


async def mac_test(tb, source, sink):
    tb.log.info("Test MAC")

    tb.log.info("Wait for block lock")
    for k in range(1200):
        await RisingEdge(tb.dut.clk_125mhz)

    sink.clear()

    tb.log.info("Multiple small packets")

    count = 64

    pkts = [bytearray([(x+k) % 256 for x in range(60)]) for k in range(count)]

    for p in pkts:
        await source.send(XgmiiFrame.from_payload(p))

    for k in range(count):
        rx_frame = await sink.recv()

        tb.log.info("RX frame: %s", rx_frame)

        assert rx_frame.get_payload() == pkts[k]
        assert rx_frame.check_fcs()

    tb.log.info("Multiple large packets")

    count = 32

    pkts = [bytearray([(x+k) % 256 for x in range(1514)]) for k in range(count)]

    for p in pkts:
        await source.send(XgmiiFrame.from_payload(p))

    for k in range(count):
        rx_frame = await sink.recv()

        tb.log.info("RX frame: %s", rx_frame)

        assert rx_frame.get_payload() == pkts[k]
        assert rx_frame.check_fcs()

    tb.log.info("MAC test done")


@cocotb.test()
async def run_test(dut):

    tb = TB(dut)

    await tb.init()

    tests = []

    for k in range(len(tb.qsfp_sources)):
        tb.log.info("Start QSFP %d MAC loopback test", k)

        tests.append(cocotb.start_soon(mac_test(tb, tb.qsfp_sources[k], tb.qsfp_sinks[k])))

    await Combine(*tests)

    await RisingEdge(dut.clk_125mhz)
    await RisingEdge(dut.clk_125mhz)


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'rtl'))
lib_dir = os.path.abspath(os.path.join(tests_dir, '..', '..', 'lib'))
taxi_src_dir = os.path.abspath(os.path.join(lib_dir, 'taxi', 'src'))


def process_f_files(files):
    lst = {}
    for f in files:
        if f[-2:].lower() == '.f':
            with open(f, 'r') as fp:
                l = fp.read().split()
            for f in process_f_files([os.path.join(os.path.dirname(f), x) for x in l]):
                lst[os.path.basename(f)] = f
        else:
            lst[os.path.basename(f)] = f
    return list(lst.values())


@pytest.mark.parametrize("mac_data_w", [32, 64])
def test_fpga_core(request, mac_data_w):
    dut = "fpga_core"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(taxi_src_dir, "eth", "rtl", "us", "taxi_eth_mac_25g_us.f"),
        os.path.join(taxi_src_dir, "axis", "rtl", "taxi_axis_async_fifo.f"),
        os.path.join(taxi_src_dir, "sync", "rtl", "taxi_sync_reset.sv"),
        os.path.join(taxi_src_dir, "sync", "rtl", "taxi_sync_signal.sv"),
        os.path.join(taxi_src_dir, "io", "rtl", "taxi_debounce_switch.sv"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['SIM'] = "1'b1"
    parameters['VENDOR'] = "\"XILINX\""
    parameters['FAMILY'] = "\"virtexuplus\""
    parameters['CFG_LOW_LATENCY'] = "1'b1"
    parameters['COMBINED_MAC_PCS'] = "1'b1"
    parameters['MAC_DATA_W'] = mac_data_w

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    sim_build = os.path.join(tests_dir, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        simulator="verilator",
        python_search=[tests_dir],
        verilog_sources=verilog_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
    )
