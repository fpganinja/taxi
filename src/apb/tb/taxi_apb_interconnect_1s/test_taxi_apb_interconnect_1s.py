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
import random

import cocotb
import cocotb_test.simulator
import pytest
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import ApbBus, ApbMaster, ApbRam


class TB(object):
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

        self.apb_master = ApbMaster(ApbBus.from_entity(dut.s_apb), dut.clk, dut.rst)
        self.apb_ram = [
            ApbRam(ApbBus.from_entity(ch), dut.clk, dut.rst, size=2**16)
            for ch in dut.m_apb
        ]

    def set_idle_generator(self, generator=None):
        if generator:
            self.apb_master.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            for ram in self.apb_ram:
                ram.set_pause_generator(generator())

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


async def run_test_write(
    dut, data_in=None, idle_inserter=None, backpressure_inserter=None, m=0
):
    tb = TB(dut)

    byte_lanes = tb.apb_master.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes * 2):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            ram_addr = offset + 0x1000
            addr = ram_addr + m * 0x1000000
            test_data = bytearray([x % 256 for x in range(length)])

            tb.apb_ram[m].write(ram_addr - 128, b"\xaa" * (length + 256))

            await tb.apb_master.write(addr, test_data)

            tb.log.debug(
                "%s",
                tb.apb_ram[m].hexdump_str(
                    (ram_addr & ~0xF) - 16,
                    (((ram_addr & 0xF) + length - 1) & ~0xF) + 48,
                ),
            )

            assert tb.apb_ram[m].read(ram_addr, length) == test_data
            assert tb.apb_ram[m].read(ram_addr - 1, 1) == b"\xaa"
            assert tb.apb_ram[m].read(ram_addr + length, 1) == b"\xaa"

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_test_read(
    dut, data_in=None, idle_inserter=None, backpressure_inserter=None, m=0
):
    tb = TB(dut)

    byte_lanes = tb.apb_master.byte_lanes

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    for length in range(1, byte_lanes * 2):
        for offset in range(byte_lanes):
            tb.log.info("length %d, offset %d", length, offset)
            ram_addr = offset + 0x1000
            addr = ram_addr + m * 0x1000000
            test_data = bytearray([x % 256 for x in range(length)])

            tb.apb_ram[m].write(ram_addr, test_data)

            data = await tb.apb_master.read(addr, length)

            assert data.data == test_data

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


async def run_stress_test(dut, idle_inserter=None, backpressure_inserter=None):
    tb = TB(dut)

    await tb.cycle_reset()

    tb.set_idle_generator(idle_inserter)
    tb.set_backpressure_generator(backpressure_inserter)

    async def worker(master, offset, aperture, count=16):
        for k in range(count):
            m = random.randrange(len(tb.apb_ram))
            length = random.randint(1, min(32, aperture))
            addr = offset + random.randint(0, aperture - length) + m * 0x1000000
            test_data = bytearray([x % 256 for x in range(length)])

            await Timer(random.randint(1, 100), "ns")

            await master.write(addr, test_data)

            await Timer(random.randint(1, 100), "ns")

            data = await master.read(addr, length)
            assert data.data == test_data

    workers = []

    for k in range(16):
        workers.append(
            cocotb.start_soon(
                worker(
                    tb.apb_master,
                    k * 0x1000,
                    0x1000,
                    count=16,
                )
            )
        )

    while workers:
        await workers.pop(0).join()

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


def cycle_pause():
    return itertools.cycle([1, 1, 1, 0])


if getattr(cocotb, "top", None) is not None:
    m_cnt = len(cocotb.top.m_apb)

    for test in [run_test_write, run_test_read]:
        factory = TestFactory(test)
        factory.add_option("idle_inserter", [None, cycle_pause])
        factory.add_option("backpressure_inserter", [None, cycle_pause])
        factory.add_option("m", range(min(m_cnt, 2)))
        factory.generate_tests()

    factory = TestFactory(run_stress_test)
    factory.add_option("idle_inserter", [None, cycle_pause])
    factory.add_option("backpressure_inserter", [None, cycle_pause])
    factory.generate_tests()


# cocotb-test

tests_dir = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_dir, "..", "..", "rtl"))
lib_dir = os.path.abspath(os.path.join(tests_dir, "..", "..", "lib"))
taxi_src_dir = os.path.abspath(os.path.join(lib_dir, "taxi", "src"))


def process_f_files(files):
    lst = {}
    for f in files:
        if f[-2:].lower() == ".f":
            with open(f, "r") as fp:
                l = fp.read().split()
            for f in process_f_files([os.path.join(os.path.dirname(f), x) for x in l]):
                lst[os.path.basename(f)] = f
        else:
            lst[os.path.basename(f)] = f
    return list(lst.values())


@pytest.mark.parametrize("data_w", [8, 16, 32])
@pytest.mark.parametrize("m_cnt", [1, 4])
def test_taxi_apb_interconnect_1s(request, m_cnt, data_w):
    dut = "taxi_apb_interconnect_1s"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(rtl_dir, "taxi_apb_if.sv"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters["M_CNT"] = m_cnt
    parameters["DATA_W"] = data_w
    parameters["ADDR_W"] = 32
    parameters["STRB_W"] = parameters["DATA_W"] // 8
    parameters["PAUSER_EN"] = 0
    parameters["PAUSER_W"] = 1
    parameters["PWUSER_EN"] = 0
    parameters["PWUSER_W"] = 1
    parameters["PRUSER_EN"] = 0
    parameters["PRUSER_W"] = 1
    parameters["PBUSER_EN"] = 0
    parameters["PBUSER_W"] = 1

    extra_env = {f"PARAM_{k}": str(v) for k, v in parameters.items()}

    sim_build = os.path.join(
        tests_dir, "sim_build", request.node.name.replace("[", "-").replace("]", "")
    )

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
