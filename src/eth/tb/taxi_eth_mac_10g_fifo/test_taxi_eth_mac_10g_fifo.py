#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
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
from cocotb.triggers import RisingEdge
from cocotb.utils import get_time_from_sim_steps
from cocotb.regression import TestFactory

from cocotbext.eth import XgmiiFrame, XgmiiSource, XgmiiSink, PtpClockSimTime
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame

try:
    from ptp_td import PtpTdSource
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from ptp_td import PtpTdSource
    finally:
        del sys.path[0]


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        if len(dut.xgmii_txd) == 64:
            self.clk_period = 6.4
        else:
            self.clk_period = 3.2

        cocotb.start_soon(Clock(dut.logic_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.rx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.stat_clk, self.clk_period, units="ns").start())

        self.xgmii_source = XgmiiSource(dut.xgmii_rxd, dut.xgmii_rxc, dut.rx_clk, dut.rx_rst)
        self.xgmii_sink = XgmiiSink(dut.xgmii_txd, dut.xgmii_txc, dut.tx_clk, dut.tx_rst)

        self.axis_source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_tx), dut.logic_clk, dut.logic_rst)
        self.tx_cpl_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_tx_cpl), dut.logic_clk, dut.logic_rst)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_rx), dut.logic_clk, dut.logic_rst)

        self.stat_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_stat), dut.stat_clk, dut.stat_rst)

        self.ptp_clock = PtpClockSimTime(ts_tod=dut.ptp_ts_in, clock=dut.logic_clk)
        dut.ptp_ts_step_in.setimmediatevalue(0)

        self.ptp_clk_period = self.clk_period

        cocotb.start_soon(Clock(dut.ptp_clk, self.ptp_clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.ptp_sample_clk, 8, units="ns").start())

        self.ptp_td_source = PtpTdSource(
            data=dut.ptp_td_sdi,
            clock=dut.ptp_clk,
            reset=dut.ptp_rst,
            period_ns=self.ptp_clk_period
        )

        dut.cfg_tx_pad_en.setimmediatevalue(0)
        dut.cfg_tx_min_pkt_len.setimmediatevalue(0)
        dut.cfg_tx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_tx_ifg.setimmediatevalue(0)
        dut.cfg_tx_enable.setimmediatevalue(0)
        dut.cfg_rx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_rx_enable.setimmediatevalue(0)

    async def reset(self):
        self.dut.logic_rst.setimmediatevalue(0)
        self.dut.rx_rst.setimmediatevalue(0)
        self.dut.tx_rst.setimmediatevalue(0)
        self.dut.ptp_rst.setimmediatevalue(0)
        self.dut.stat_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.logic_clk)
        await RisingEdge(self.dut.logic_clk)
        self.dut.logic_rst.value = 1
        self.dut.rx_rst.value = 1
        self.dut.tx_rst.value = 1
        self.dut.ptp_rst.value = 1
        self.dut.stat_rst.value = 1
        await RisingEdge(self.dut.logic_clk)
        await RisingEdge(self.dut.logic_clk)
        self.dut.logic_rst.value = 0
        self.dut.rx_rst.value = 0
        self.dut.tx_rst.value = 0
        self.dut.ptp_rst.value = 0
        self.dut.stat_rst.value = 0
        await RisingEdge(self.dut.logic_clk)
        await RisingEdge(self.dut.logic_clk)

        self.ptp_td_source.set_ts_tod_sim_time()
        self.ptp_td_source.set_ts_rel_sim_time()


async def run_test_rx(dut, payload_lengths=None, payload_data=None, ifg=12):

    tb = TB(dut)

    tb.xgmii_source.ifg = ifg
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 9218-1
    tb.dut.cfg_rx_enable.value = 1

    await tb.reset()

    tb.log.info("Wait for PTP CDC lock")
    while not int(dut.rx_ptp_locked.value):
        await RisingEdge(dut.rx_clk)
    for k in range(4000):
        await RisingEdge(dut.rx_clk)

    test_frames = [payload_data(x) for x in payload_lengths()]
    tx_frames = []

    for test_data in test_frames:
        test_frame = XgmiiFrame.from_payload(test_data, tx_complete=tx_frames.append)
        await tb.xgmii_source.send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.axis_sink.recv()
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
        if dut.PTP_TD_EN.value:
            assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period) < tb.clk_period*4
        else:
            assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period) < tb.clk_period*2

    assert tb.axis_sink.empty()

    await RisingEdge(dut.logic_clk)
    await RisingEdge(dut.logic_clk)


async def run_test_tx(dut, payload_lengths=None, payload_data=None, ifg=12):

    tb = TB(dut)

    tb.xgmii_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_tx_enable.value = 1

    await tb.reset()

    tb.log.info("Wait for PTP CDC lock")
    while not int(dut.tx_ptp_locked.value):
        await RisingEdge(dut.tx_clk)
    for k in range(4000):
        await RisingEdge(dut.tx_clk)

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        await tb.axis_source.send(AxiStreamFrame(test_data, tid=0, tuser=0))

    for test_data in test_frames:
        rx_frame = await tb.xgmii_sink.recv()
        tx_cpl = await tb.tx_cpl_sink.recv()

        ptp_ts_ns = int(tx_cpl.tdata[0]) / 2**16

        rx_frame_sfd_ns = get_time_from_sim_steps(rx_frame.sim_time_sfd, "ns")

        tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.ctrl is None
        if dut.PTP_TD_EN.value:
            assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period) < tb.clk_period*4
        else:
            assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period) < tb.clk_period*2

    assert tb.xgmii_sink.empty()

    await RisingEdge(dut.logic_clk)
    await RisingEdge(dut.logic_clk)


async def run_test_tx_alignment(dut, payload_data=None, ifg=12):

    dic_en = int(cocotb.top.DIC_EN.value)

    tb = TB(dut)

    byte_width = tb.axis_source.width // 8

    tb.xgmii_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_tx_enable.value = 1

    await tb.reset()

    tb.log.info("Wait for PTP CDC lock")
    while not int(dut.tx_ptp_locked.value):
        await RisingEdge(dut.tx_clk)
    for k in range(4000):
        await RisingEdge(dut.tx_clk)

    for length in range(60, 92):

        for k in range(10):
            await RisingEdge(dut.tx_clk)

        test_frames = [payload_data(length) for k in range(10)]
        start_lane = []

        for test_data in test_frames:
            await tb.axis_source.send(AxiStreamFrame(test_data, tid=0, tuser=0))

        for test_data in test_frames:
            rx_frame = await tb.xgmii_sink.recv()
            tx_cpl = await tb.tx_cpl_sink.recv()

            ptp_ts_ns = int(tx_cpl.tdata[0]) / 2**16

            rx_frame_sfd_ns = get_time_from_sim_steps(rx_frame.sim_time_sfd, "ns")

            tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
            tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
            tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))

            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.ctrl is None
            if dut.PTP_TD_EN.value:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period) < tb.clk_period*4
            else:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period) < tb.clk_period*2

            start_lane.append(rx_frame.start_lane)

        tb.log.info("length: %d", length)
        tb.log.info("start_lane: %s", start_lane)

        start_lane_ref = []

        # compute expected starting lanes
        lane = 0
        deficit_idle_count = 0

        for test_data in test_frames:
            if ifg == 0:
                lane = 0

            start_lane_ref.append(lane)
            lane = (lane + len(test_data)+4+ifg) % byte_width

            if dic_en:
                offset = lane % 4
                if deficit_idle_count+offset >= 4:
                    offset += 4
                lane = (lane - offset) % byte_width
                deficit_idle_count = (deficit_idle_count + offset) % 4
            else:
                offset = lane % 4
                if offset > 0:
                    offset += 4
                lane = (lane - offset) % byte_width

        tb.log.info("start_lane_ref: %s", start_lane_ref)

        assert start_lane_ref == start_lane

        await RisingEdge(dut.logic_clk)

    assert tb.xgmii_sink.empty()

    await RisingEdge(dut.logic_clk)
    await RisingEdge(dut.logic_clk)


def size_list():
    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])


if getattr(cocotb, 'top', None) is not None:

    for test in [run_test_rx, run_test_tx]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("ifg", [12, 0])
        factory.generate_tests()

    factory = TestFactory(run_test_tx_alignment)
    factory.add_option("payload_data", [incrementing_payload])
    factory.add_option("ifg", [12])
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


@pytest.mark.parametrize("dic_en", [1, 0])
@pytest.mark.parametrize("data_w", [32, 64])
def test_taxi_eth_mac_10g_fifo(request, data_w, dic_en):
    dut = "taxi_eth_mac_10g_fifo"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.f"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['DATA_W'] = data_w
    parameters['AXIS_DATA_W'] = parameters['DATA_W']
    parameters['TX_GBX_IF_EN'] = 0
    parameters['RX_GBX_IF_EN'] = parameters['TX_GBX_IF_EN']
    parameters['GBX_CNT'] = 1
    parameters['DIC_EN'] = dic_en
    parameters['PTP_TS_EN'] = 1
    parameters['PTP_TD_EN'] = parameters['PTP_TS_EN']
    parameters['PTP_TS_FMT_TOD'] = 1
    parameters['PTP_TS_W'] = 96 if parameters['PTP_TS_FMT_TOD'] else 64
    parameters['PTP_TD_SDI_PIPELINE'] = 2
    parameters['TX_TAG_W'] = 16
    parameters['STAT_EN'] = 1
    parameters['STAT_TX_LEVEL'] = 2
    parameters['STAT_RX_LEVEL'] = parameters['STAT_TX_LEVEL']
    parameters['STAT_ID_BASE'] = 0
    parameters['STAT_UPDATE_PERIOD'] = 1024
    parameters['STAT_STR_EN'] = 1
    parameters['STAT_PREFIX_STR'] = "\"MAC\""
    parameters['TX_FIFO_DEPTH'] = 16384
    parameters['TX_FIFO_RAM_PIPELINE'] = 1
    parameters['TX_FRAME_FIFO'] = 1
    parameters['TX_DROP_OVERSIZE_FRAME'] = parameters['TX_FRAME_FIFO']
    parameters['TX_DROP_BAD_FRAME'] = parameters['TX_DROP_OVERSIZE_FRAME']
    parameters['TX_DROP_WHEN_FULL'] = 0
    parameters['TX_CPL_FIFO_DEPTH'] = 64
    parameters['RX_FIFO_DEPTH'] = 16384
    parameters['RX_FIFO_RAM_PIPELINE'] = 1
    parameters['RX_FRAME_FIFO'] = 1
    parameters['RX_DROP_OVERSIZE_FRAME'] = parameters['RX_FRAME_FIFO']
    parameters['RX_DROP_BAD_FRAME'] = parameters['RX_DROP_OVERSIZE_FRAME']
    parameters['RX_DROP_WHEN_FULL'] = parameters['RX_DROP_OVERSIZE_FRAME']

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
