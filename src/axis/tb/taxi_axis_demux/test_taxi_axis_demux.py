#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2021-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import itertools
import logging
import os

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis), dut.clk, dut.rst)
        self.sink = [AxiStreamSink(AxiStreamBus.from_entity(bus), dut.clk, dut.rst) for bus in dut.m_axis]

        dut.enable.setimmediatevalue(0)
        dut.drop.setimmediatevalue(0)
        dut.select.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            for sink in self.sink:
                sink.set_pause_generator(generator())

    async def reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


async def run_test(dut, payload_lengths=None, payload_data=None, idle_inserter=None, backpressure_inserter=None, port=0):

    tb = TB(dut)

    id_width = len(tb.sink[0].bus.tid)
    id_count = 2**id_width
    id_mask = id_count-1

    dest_width = len(tb.sink[0].bus.tdest)
    dest_count = 2**dest_width
    dest_mask = dest_count-1

    cur_id = 1

    await tb.reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    test_frames = []

    dut.enable.setimmediatevalue(1)
    dut.drop.setimmediatevalue(0)
    dut.select.setimmediatevalue(port)

    for test_data in [payload_data(x) for x in payload_lengths()]:
        test_frame = AxiStreamFrame(test_data)
        test_frame.tid = cur_id
        test_frame.tdest = cur_id | (port << dest_width)

        test_frames.append(test_frame)
        await tb.source.send(test_frame)

        cur_id = (cur_id + 1) % id_count

    for test_frame in test_frames:
        rx_frame = await tb.sink[port].recv()

        assert rx_frame.tdata == test_frame.tdata
        assert rx_frame.tid == test_frame.tid
        assert rx_frame.tdest == (test_frame.tdest & dest_mask)
        assert not rx_frame.tuser

    assert tb.sink[port].empty()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


def size_list():
    data_width = len(cocotb.top.s_axis.tdata)
    byte_width = data_width // 8
    return list(range(1, byte_width*4+1))+[512]+[1]*64


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if getattr(cocotb, 'top', None) is not None:

    ports = len(cocotb.top.m_axis)

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.add_option("port", list(range(ports)))
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.dirname(__file__)
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


@pytest.mark.parametrize("tdest_route", [0, 1])
@pytest.mark.parametrize("data_w", [8, 16, 32])
@pytest.mark.parametrize("m_count", [4])
def test_taxi_axis_demux(request, m_count, data_w, tdest_route):
    dut = "taxi_axis_demux"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(rtl_dir, "taxi_axis_if.sv"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['M_COUNT'] = m_count
    parameters['DATA_W'] = data_w
    parameters['KEEP_EN'] = int(parameters['DATA_W'] > 8)
    parameters['KEEP_W'] = (parameters['DATA_W'] + 7) // 8
    parameters['STRB_EN'] = 0
    parameters['LAST_EN'] = 1
    parameters['ID_EN'] = 1
    parameters['M_ID_W'] = 8
    parameters['S_ID_W'] = parameters['M_ID_W'] + (m_count-1).bit_length()
    parameters['DEST_EN'] = 1
    parameters['M_DEST_W'] = 8
    parameters['S_DEST_W'] = parameters['M_DEST_W'] + (m_count-1).bit_length()
    parameters['USER_EN'] = 1
    parameters['USER_W'] = 1
    parameters['TID_ROUTE'] = 0
    parameters['TDEST_ROUTE'] = tdest_route

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
