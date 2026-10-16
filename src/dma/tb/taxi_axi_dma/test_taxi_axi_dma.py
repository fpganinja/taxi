#!/usr/bin/env python3
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2020-2025 FPGA Ninja, LLC

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
from cocotb.triggers import RisingEdge, with_timeout

from cocotbext.axi import AxiBus, AxiRam
from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink
from cocotbext.axi.stream import define_stream

DescBus, DescTransaction, DescSource, DescSink, DescMonitor = define_stream("Desc",
    signals=["req_src_addr", "req_dst_addr", "req_len", "req_tag", "req_valid", "req_ready"],
    optional_signals=["req_id", "req_dest", "req_user"]
)

DescStatusBus, DescStatusTransaction, DescStatusSource, DescStatusSink, DescStatusMonitor = define_stream("DescStatus",
    signals=["sts_tag", "sts_error", "sts_valid"],
    optional_signals=["sts_len", "sts_id", "sts_dest", "sts_user"]
)


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        # read interface
        self.read_desc_source = DescSource(DescBus.from_entity(dut.rd_desc), dut.clk, dut.rst)
        self.read_desc_status_sink = DescStatusSink(DescStatusBus.from_entity(dut.rd_desc), dut.clk, dut.rst)
        self.read_data_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_rd_data), dut.clk, dut.rst)

        # write interface
        self.write_desc_source = DescSource(DescBus.from_entity(dut.wr_desc), dut.clk, dut.rst)
        self.write_desc_status_sink = DescStatusSink(DescStatusBus.from_entity(dut.wr_desc), dut.clk, dut.rst)
        self.write_data_source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_wr_data), dut.clk, dut.rst)

        # AXI interface
        self.axi_ram = AxiRam(AxiBus.from_entity(dut.m_axi), dut.clk, dut.rst, size=2**16)

        dut.read_enable.setimmediatevalue(0)
        dut.write_enable.setimmediatevalue(0)
        dut.write_abort.setimmediatevalue(0)

    def set_idle_generator(self, generator=None):
        if generator:
            self.write_desc_source.set_pause_generator(generator())
            self.write_data_source.set_pause_generator(generator())
            self.read_desc_source.set_pause_generator(generator())
            self.axi_ram.write_if.b_channel.set_pause_generator(generator())
            self.axi_ram.read_if.r_channel.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.read_data_sink.set_pause_generator(generator())
            self.axi_ram.write_if.aw_channel.set_pause_generator(generator())
            self.axi_ram.write_if.w_channel.set_pause_generator(generator())
            self.axi_ram.read_if.ar_channel.set_pause_generator(generator())

    async def cycle_reset(self):
        self.dut.rst.setimmediatevalue(0)
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 1
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        await RisingEdge(self.dut.clk)
        await RisingEdge(self.dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


@cocotb.test()
@cocotb.parametrize(
    ("idle_inserter", [None, cycle_pause]),
    ("backpressure_inserter", [None, cycle_pause]),
)
async def run_test_write(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.write_if.byte_lanes
    step_size = 1 if int(dut.UNALIGNED_EN.value) else byte_lanes
    tag_count = 2**len(tb.write_desc_source.bus.req_tag)

    cur_tag = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.write_enable.value = 1

    for length in list(range(1, byte_lanes*4+1))+[128]:
        for offset in list(range(0, byte_lanes*2, step_size))+list(range(4096-byte_lanes*2, 4096, step_size)):
            for diff in [-8, -2, -1, 0, 1, 2, 8]:
                if length+diff < 1:
                    continue

                tb.log.info("length %d, offset %d, diff %d", length, offset, diff)
                addr = offset+0x1000
                test_data = bytearray([x % 256 for x in range(length)])
                test_data2 = bytearray([x % 256 for x in range(length+diff)])

                tb.axi_ram.write(addr-128, b'\xaa'*(len(test_data)+256))

                desc = DescTransaction(req_dst_addr=addr, req_len=len(test_data), req_tag=cur_tag)
                await tb.write_desc_source.send(desc)

                await tb.write_data_source.send(AxiStreamFrame(test_data2, tid=cur_tag))

                status = await tb.write_desc_status_sink.recv()

                tb.log.info("status: %s", status)
                assert int(status.sts_len) == min(len(test_data), len(test_data2))
                assert int(status.sts_tag) == cur_tag
                assert int(status.sts_id) == cur_tag
                assert int(status.sts_error) == 0

                tb.log.debug("%s", tb.axi_ram.hexdump_str((addr & ~0xf)-16, (((addr & 0xf)+length-1) & ~0xf)+48))

                if len(test_data) <= len(test_data2):
                    assert tb.axi_ram.read(addr-8, len(test_data)+16) == b'\xaa'*8+test_data+b'\xaa'*8
                else:
                    assert tb.axi_ram.read(addr-8, len(test_data2)+16) == b'\xaa'*8+test_data2+b'\xaa'*8

                cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


@cocotb.test()
@cocotb.parametrize(
    ("idle_inserter", [None, cycle_pause]),
    ("backpressure_inserter", [None, cycle_pause]),
)
async def run_test_read(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.read_if.byte_lanes
    step_size = 1 if int(dut.UNALIGNED_EN.value) else byte_lanes
    tag_count = 2**len(tb.read_desc_source.bus.req_tag)

    cur_tag = 1

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.read_enable.value = 1

    for length in list(range(1, byte_lanes*4+1))+[128]:
        for offset in list(range(0, byte_lanes*2, step_size))+list(range(4096-byte_lanes*2, 4096, step_size)):
            tb.log.info("length %d, offset %d", length, offset)
            addr = offset+0x1000
            test_data = bytearray([x % 256 for x in range(length)])

            tb.axi_ram.write(addr-128, b'\xaa'*(len(test_data)+256))
            tb.axi_ram.write(addr, test_data)

            tb.log.debug("%s", tb.axi_ram.hexdump_str((addr & ~0xf)-16, (((addr & 0xf)+length-1) & ~0xf)+48))

            desc = DescTransaction(req_src_addr=addr, req_len=len(test_data), req_tag=cur_tag, req_id=cur_tag)
            await tb.read_desc_source.send(desc)

            status = await tb.read_desc_status_sink.recv()

            read_data = await tb.read_data_sink.recv()

            tb.log.info("status: %s", status)
            tb.log.info("read_data: %s", read_data)

            assert int(status.sts_tag) == cur_tag
            assert int(status.sts_error) == 0
            assert read_data.tdata == test_data
            assert read_data.tid == cur_tag

            cur_tag = (cur_tag + 1) % tag_count

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


@cocotb.test()
@cocotb.parametrize(
    ("idle_inserter", [None, cycle_pause]),
    ("backpressure_inserter", [None, cycle_pause]),
)
async def run_test_read_long(dut, idle_inserter=None, backpressure_inserter=None):

    tb = TB(dut)

    byte_lanes = tb.axi_ram.read_if.byte_lanes
    max_length = (1 << len(tb.read_desc_source.bus.req_len)) - 1
    lengths = [8191, 8192, 8193, 8192+byte_lanes, 16384]
    # Exercise the descriptor length limit when it fits in the test RAM.
    if max_length < 32768:
        lengths.append(max_length)
    lengths = sorted(set(length for length in lengths if length <= max_length))
    offsets = [0, byte_lanes, 4096-byte_lanes]
    if int(dut.UNALIGNED_EN.value):
        offsets.extend([1, byte_lanes-1, 4095])

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    dut.read_enable.value = 1

    cur_tag = 1

    for length in lengths:
        for offset in sorted(set(offsets)):
            tb.log.info("length %d, offset %d", length, offset)
            addr = 0x1000+offset
            test_data = bytearray((x ^ (x >> 8) ^ cur_tag) & 0xff for x in range(length))
            tb.axi_ram.write(addr, test_data)

            desc = DescTransaction(req_src_addr=addr, req_len=length, req_tag=cur_tag, req_id=cur_tag)
            await tb.read_desc_source.send(desc)

            status = await with_timeout(tb.read_desc_status_sink.recv(), 5, "ms")
            read_data = await with_timeout(tb.read_data_sink.recv(), 5, "ms")

            assert int(status.sts_tag) == cur_tag
            assert int(status.sts_error) == 0
            assert len(read_data.tdata) == length
            assert read_data.tdata == test_data
            assert read_data.tid == cur_tag
            assert tb.read_desc_status_sink.empty()
            assert tb.read_data_sink.empty()

            cur_tag = (cur_tag + 1) % (1 << len(tb.read_desc_source.bus.req_tag))

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


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


@pytest.mark.parametrize("axi_data_w", [8, 16, 32])
@pytest.mark.parametrize("unaligned", [0, 1])
def test_taxi_axi_dma(request, axi_data_w, unaligned):
    run_sim(request, axi_data_w, unaligned)


@pytest.mark.parametrize("axi_data_w", [8, 32, 128])
@pytest.mark.parametrize("unaligned", [0, 1])
@pytest.mark.parametrize("len_w", [14, 20])
def test_taxi_axi_dma_long(request, axi_data_w, unaligned, len_w):
    run_sim(request, axi_data_w, unaligned, len_w, "run_test_read_long")


def run_sim(request, axi_data_w, unaligned, len_w=20, test_filter=None):
    dut = "taxi_axi_dma"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.f"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    axis_data_w = axi_data_w

    parameters['AXI_DATA_W'] = axi_data_w
    parameters['AXI_ADDR_W'] = 16
    parameters['AXI_STRB_W'] = parameters['AXI_DATA_W'] // 8
    parameters['AXI_ID_W'] = 8
    parameters['AXI_MAX_BURST_LEN'] = 16
    parameters['AXIS_DATA_W'] = axis_data_w
    parameters['AXIS_KEEP_EN'] = int(parameters['AXIS_DATA_W'] > 8)
    parameters['AXIS_KEEP_W'] = parameters['AXIS_DATA_W'] // 8
    parameters['AXIS_LAST_EN'] = 1
    parameters['AXIS_ID_EN'] = 1
    parameters['AXIS_ID_W'] = 8
    parameters['AXIS_DEST_EN'] = 0
    parameters['AXIS_DEST_W'] = 8
    parameters['AXIS_USER_EN'] = 1
    parameters['AXIS_USER_W'] = 1
    parameters['LEN_W'] = len_w
    parameters['TAG_W'] = 8
    parameters['UNALIGNED_EN'] = unaligned

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}
    if test_filter:
        extra_env['COCOTB_TEST_FILTER'] = test_filter

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
