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
from cocotb.utils import get_time_from_sim_steps
from cocotb.regression import TestFactory

from cocotbext.eth import GmiiFrame, PtpClockSimTime
from cocotbext.axi import AxiStreamBus, AxiStreamSink

try:
    from basex import BaseXSerdesSource
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from basex import BaseXSerdesSource
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

        self.source = BaseXSerdesSource(
            data=dut.encoded_rx_data,
            data_k=dut.encoded_rx_data_k,
            data_valid=dut.encoded_rx_data_valid,
            clock=dut.clk,
            enc_8b10b=False,
            gbx_cfg=gbx_cfg
        )
        self.sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_rx), dut.clk, dut.rst)

        self.ptp_clock = PtpClockSimTime(ts_tod=dut.ptp_ts, clock=dut.clk)

        dut.cfg_rx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_rx_enable.setimmediatevalue(0)

        self.stats = {}
        self.stats["stat_rx_byte"] = 0
        self.stats["stat_rx_pkt_len"] = 0
        self.stats["stat_rx_pkt_fragment"] = 0
        self.stats["stat_rx_pkt_jabber"] = 0
        self.stats["stat_rx_pkt_ucast"] = 0
        self.stats["stat_rx_pkt_mcast"] = 0
        self.stats["stat_rx_pkt_bcast"] = 0
        self.stats["stat_rx_pkt_vlan"] = 0
        self.stats["stat_rx_pkt_good"] = 0
        self.stats["stat_rx_pkt_bad"] = 0
        self.stats["stat_rx_err_oversize"] = 0
        self.stats["stat_rx_err_bad_fcs"] = 0
        self.stats["stat_rx_err_bad_block"] = 0
        self.stats["stat_rx_err_framing"] = 0
        self.stats["stat_rx_err_preamble"] = 0

        cocotb.start_soon(self._run_stats_counters())

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

        self.stats_reset()

    def stats_reset(self):
        for stat in self.stats:
            self.stats[stat] = 0

    async def _run_stats_counters(self):
        while True:
            await RisingEdge(self.dut.clk)
            for stat in self.stats:
                self.stats[stat] += int(getattr(self.dut, stat).value)


async def run_test(dut, gbx_cfg=None, payload_lengths=None, payload_data=None, ifg=12, pre_len=8):

    tb = TB(dut, gbx_cfg)

    tb.source.ifg = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 9218-1
    tb.dut.cfg_rx_enable.value = 1

    await tb.reset()

    test_frames = [payload_data(x) for x in payload_lengths()]
    tx_frames = []

    total_bytes = 0
    total_pkts = 0

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data, tx_complete=tx_frames.append)
        test_frame.data = test_frame.data[8-pre_len:]
        await tb.source.send(test_frame)
        total_bytes += len(test_data)+4
        total_pkts += 1

    for test_data in test_frames:
        rx_frame = await tb.sink.recv()
        tx_frame = tx_frames.pop(0)

        frame_error = rx_frame.tuser & 1
        ptp_ts = rx_frame.tuser >> 1
        ptp_ts_ns = ptp_ts / 2**16

        tx_frame_sfd_ns = get_time_from_sim_steps(tx_frame.sim_time_sfd, "ns")

        tb.log.info("RX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("TX frame SFD sim time: %f ns", tx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(ptp_ts_ns - tx_frame_sfd_ns))

        assert rx_frame.tdata == test_data
        assert frame_error == 0
        if gbx_cfg is None:
            assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period*0) < 0.01

    assert tb.sink.empty()

    for stat, val in tb.stats.items():
        tb.log.info("%s: %d", stat, val)

    assert tb.stats["stat_rx_byte"] == total_bytes
    assert tb.stats["stat_rx_pkt_len"] == total_bytes
    assert tb.stats["stat_rx_pkt_fragment"] == 0
    assert tb.stats["stat_rx_pkt_jabber"] == 0
    assert tb.stats["stat_rx_pkt_ucast"] == total_pkts
    assert tb.stats["stat_rx_pkt_mcast"] == 0
    assert tb.stats["stat_rx_pkt_bcast"] == 0
    assert tb.stats["stat_rx_pkt_vlan"] == 0
    assert tb.stats["stat_rx_pkt_good"] == total_pkts
    assert tb.stats["stat_rx_pkt_bad"] == 0
    assert tb.stats["stat_rx_err_oversize"] == 0
    assert tb.stats["stat_rx_err_bad_fcs"] == 0
    assert tb.stats["stat_rx_err_bad_block"] == 0
    assert tb.stats["stat_rx_err_framing"] == 0
    assert tb.stats["stat_rx_err_preamble"] == 0

    for k in range(10):
        await RisingEdge(dut.clk)


async def run_test_oversize(dut, gbx_cfg=None, ifg=12):

    tb = TB(dut, gbx_cfg)

    tb.source.ifg = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 1518-1
    tb.dut.cfg_rx_enable.value = 1

    await tb.reset()

    for max_len in range(128-4-8, 128-4+9):

        tb.stats_reset()

        total_bytes = 0
        total_pkts = 0
        good_bytes = 0
        oversz_pkts = 0
        oversz_bytes_in = 0
        oversz_bytes_out = 0

        for test_pkt_len in range(max_len-8, max_len+9):

            tb.log.info("max len %d (without FCS), test len %d (without FCS)", max_len, test_pkt_len)

            tb.dut.cfg_rx_max_pkt_len.value = max_len+4-1

            test_data_1 = bytes(x for x in range(60))
            test_data_2 = bytes(x for x in range(test_pkt_len))

            for k in range(3):
                if k == 1:
                    test_data = test_data_2
                else:
                    test_data = test_data_1
                test_frame = GmiiFrame.from_payload(test_data)
                await tb.source.send(test_frame)
                total_bytes += len(test_data)+4
                total_pkts += 1
                if len(test_data) > max_len:
                    oversz_pkts += 1
                    oversz_bytes_in += len(test_data)+4
                    oversz_bytes_out += max_len
                else:
                    good_bytes += len(test_data)+4

            for k in range(3):
                rx_frame = await tb.sink.recv()

                if k == 1:
                    if test_pkt_len > max_len:
                        frame_error = rx_frame.tuser[-1] & 1
                        assert frame_error
                    else:
                        frame_error = rx_frame.tuser & 1
                        assert rx_frame.tdata == test_data_2
                        assert frame_error == 0
                else:
                    frame_error = rx_frame.tuser & 1
                    assert rx_frame.tdata == test_data_1
                    assert frame_error == 0

        assert tb.sink.empty()

        for stat, val in tb.stats.items():
            tb.log.info("%s: %d", stat, val)

        assert tb.stats["stat_rx_byte"] >= good_bytes+oversz_bytes_out
        assert tb.stats["stat_rx_byte"] <= good_bytes+oversz_bytes_in
        assert tb.stats["stat_rx_pkt_len"] >= good_bytes+oversz_bytes_out
        assert tb.stats["stat_rx_pkt_len"] <= good_bytes+oversz_bytes_in
        assert tb.stats["stat_rx_pkt_fragment"] == 0
        assert tb.stats["stat_rx_pkt_jabber"] == 0
        assert tb.stats["stat_rx_pkt_ucast"] == total_pkts
        assert tb.stats["stat_rx_pkt_mcast"] == 0
        assert tb.stats["stat_rx_pkt_bcast"] == 0
        assert tb.stats["stat_rx_pkt_vlan"] == 0
        assert tb.stats["stat_rx_pkt_good"] == total_pkts-oversz_pkts
        assert tb.stats["stat_rx_pkt_bad"] == oversz_pkts
        assert tb.stats["stat_rx_err_oversize"] == oversz_pkts
        assert tb.stats["stat_rx_err_bad_fcs"] == 0
        assert tb.stats["stat_rx_err_bad_block"] == 0
        assert tb.stats["stat_rx_err_framing"] == 0
        assert tb.stats["stat_rx_err_preamble"] == 0

    for k in range(10):
        await RisingEdge(dut.clk)


def size_list():
    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10 + [i for i in range(64, 73) for k in range(8)]


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])


if getattr(cocotb, 'top', None) is not None:

    gbx_cfgs = [None]

    if cocotb.top.GBX_IF_EN.value:
        gbx_cfgs.append((5, [4]))

    factory = TestFactory(run_test)
    factory.add_option("payload_lengths", [size_list])
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("ifg", list(range(0, 13)))
    factory.add_option("pre_len", [8, 7])
    factory.add_option("gbx_cfg", gbx_cfgs)
    factory.generate_tests()

    factory = TestFactory(run_test_oversize)
    factory.add_option("ifg", list(range(0, 13)))
    factory.add_option("gbx_cfg", gbx_cfgs)
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


@pytest.mark.parametrize("gbx_en", [1, 0])
def test_taxi_axis_basex_rx_16(request, gbx_en):
    dut = "taxi_axis_basex_rx_16"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(taxi_src_dir, "lfsr", "rtl", "taxi_lfsr.sv"),
        os.path.join(taxi_src_dir, "axis", "rtl", "taxi_axis_if.sv"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['DATA_W'] = 16
    parameters['GBX_IF_EN'] = gbx_en
    parameters['PTP_TS_EN'] = 1
    parameters['PTP_TS_FMT_TOD'] = 1
    parameters['PTP_TS_W'] = 96 if parameters['PTP_TS_FMT_TOD'] else 64

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
