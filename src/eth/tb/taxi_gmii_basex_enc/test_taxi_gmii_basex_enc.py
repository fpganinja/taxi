#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import itertools
import logging
import os
import sys

import cocotb_test.simulator
import pytest

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.eth import GmiiFrame, GmiiSource

try:
    from basex import BaseXSerdesSink
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from basex import BaseXSerdesSink
    finally:
        del sys.path[0]


class TB:
    def __init__(self, dut, gbx_cfg=None):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        if gbx_cfg:
            self.clk_period = 16
        else:
            self.clk_period = 16

        cocotb.start_soon(Clock(dut.clk, self.clk_period, units="ns").start())

        self.source = GmiiSource(dut.gmii_txd, dut.gmii_tx_er, dut.gmii_tx_en,
            dut.clk, dut.rst)
        self.sink = BaseXSerdesSink(
            data=dut.encoded_tx_data,
            data_k=dut.encoded_tx_data_k,
            data_valid=dut.encoded_tx_data_valid,
            # gbx_req_sync=dut.tx_gbx_req_sync,
            # gbx_req_stall=dut.tx_gbx_req_stall,
            # gbx_sync=dut.tx_gbx_sync,
            clock=dut.clk,
            dec_8b10b=False,
            gbx_cfg=gbx_cfg
        )

        dut.tx_an_cfg.setimmediatevalue(0)
        dut.tx_an_cfg_valid.setimmediatevalue(0)

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


async def run_test(dut, gbx_cfg=None, payload_lengths=None, payload_data=None, ifg=12, pre_len=8):

    tb = TB(dut, gbx_cfg)

    tb.source.ifg = ifg

    await tb.reset()

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data)
        test_frame.data = test_frame.data[8-pre_len:]
        await tb.source.send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.sink.recv()

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.error is None

    assert tb.sink.empty()

    for k in range(10):
        await RisingEdge(dut.clk)


async def run_test_an(dut, gbx_cfg=None):

    tb = TB(dut, gbx_cfg)

    await tb.reset()

    for k in range(16):
        an_cfg = 1 << k

        dut.tx_an_cfg.value = an_cfg
        dut.tx_an_cfg_valid.value = 1

        for k in range(20):
            await RisingEdge(dut.clk)

        assert tb.sink.get_an_cfg() == an_cfg
        assert tb.sink.get_an_ability_match()
        assert tb.sink.get_an_ack_match() == bool(an_cfg & 0x4000)
        assert not tb.sink.get_an_idle_match()

        dut.tx_an_cfg_valid.value = 0

        for k in range(20):
            await RisingEdge(dut.clk)

        assert not tb.sink.get_an_ability_match()
        assert not tb.sink.get_an_ack_match()
        assert tb.sink.get_an_idle_match()

    for k in range(10):
        await RisingEdge(dut.clk)


def size_list():
    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10 + [i for i in range(64, 73) for k in range(8)]


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


if getattr(cocotb, 'top', None) is not None:

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("ifg", list(range(0, 13)))
    factory.add_option("pre_len", [8, 7])
    factory.generate_tests()

    factory = TestFactory(run_test_an)
    factory.generate_tests()


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


@pytest.mark.parametrize("data_w", [8, 16])
def test_taxi_gmii_basex_enc(request, data_w):
    dut = "taxi_gmii_basex_enc"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(rtl_dir, f"{dut}.sv"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['DATA_W'] = data_w
    parameters['GBX_IF_EN'] = 0
    parameters['AN_EN'] = "1'b1"

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
