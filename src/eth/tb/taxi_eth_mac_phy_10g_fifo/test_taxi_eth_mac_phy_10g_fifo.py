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
import sys

import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.utils import get_time_from_sim_steps
from cocotb.regression import TestFactory

from cocotbext.eth import XgmiiFrame, PtpClockSimTime
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame

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
    def __init__(self, dut, gbx_cfg=None):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        if len(dut.serdes_tx_data) == 64:
            if gbx_cfg:
                self.clk_period = 6.206
            else:
                self.clk_period = 6.4
        else:
            if gbx_cfg:
                self.clk_period = 3.102
            else:
                self.clk_period = 3.2

        cocotb.start_soon(Clock(dut.logic_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.rx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.stat_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.ptp_sample_clk, 9.9, units="ns").start())

        self.serdes_source = BaseRSerdesSource(
            data=dut.serdes_rx_data,
            data_valid=dut.serdes_rx_data_valid,
            hdr=dut.serdes_rx_hdr,
            hdr_valid=dut.serdes_rx_hdr_valid,
            clock=dut.rx_clk,
            slip=dut.serdes_rx_bitslip,
            gbx_cfg=gbx_cfg
        )
        self.serdes_sink = BaseRSerdesSink(
            data=dut.serdes_tx_data,
            data_valid=dut.serdes_tx_data_valid,
            hdr=dut.serdes_tx_hdr,
            hdr_valid=dut.serdes_tx_hdr_valid,
            gbx_req_sync=dut.serdes_tx_gbx_req_sync,
            gbx_req_stall=dut.serdes_tx_gbx_req_stall,
            gbx_sync=dut.serdes_tx_gbx_sync,
            clock=dut.tx_clk,
            gbx_cfg=gbx_cfg
        )

        self.axis_source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_tx), dut.logic_clk, dut.logic_rst)
        self.tx_cpl_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_tx_cpl), dut.logic_clk, dut.logic_rst)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_rx), dut.logic_clk, dut.logic_rst)

        self.stat_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_stat), dut.stat_clk, dut.stat_rst)

        self.ptp_clock = PtpClockSimTime(ts_tod=dut.ptp_ts, clock=dut.logic_clk)

        dut.ptp_ts_step.setimmediatevalue(0)

        dut.cfg_tx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_tx_ifg.setimmediatevalue(0)
        dut.cfg_tx_enable.setimmediatevalue(0)
        dut.cfg_rx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_rx_enable.setimmediatevalue(0)
        dut.cfg_tx_prbs31_enable.setimmediatevalue(0)
        dut.cfg_rx_prbs31_enable.setimmediatevalue(0)

    async def reset(self):
        self.dut.logic_rst.setimmediatevalue(0)
        self.dut.rx_rst.setimmediatevalue(0)
        self.dut.tx_rst.setimmediatevalue(0)
        self.dut.stat_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.logic_clk)
        await RisingEdge(self.dut.logic_clk)
        self.dut.logic_rst.value = 1
        self.dut.rx_rst.value = 1
        self.dut.tx_rst.value = 1
        self.dut.stat_rst.value = 1
        await RisingEdge(self.dut.logic_clk)
        await RisingEdge(self.dut.logic_clk)
        self.dut.logic_rst.value = 0
        self.dut.rx_rst.value = 0
        self.dut.tx_rst.value = 0
        self.dut.stat_rst.value = 0
        await RisingEdge(self.dut.logic_clk)
        await RisingEdge(self.dut.logic_clk)


async def run_test_rx(dut, gbx_cfg=None, payload_lengths=None, payload_data=None, ifg=12):

    if len(dut.serdes_tx_data) == 64:
        pipe_delay = 4
    else:
        pipe_delay = 6

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 9218
    tb.dut.cfg_rx_enable.value = 1

    await tb.reset()

    tb.log.info("Wait for block lock")
    while not dut.rx_block_lock.value.integer:
        await RisingEdge(dut.rx_clk)

    tb.log.info("Wait for PTP CDC lock")
    while not dut.uut.rx_ptp_locked.value.integer:
        await RisingEdge(dut.rx_clk)
    for k in range(1000):
        await RisingEdge(dut.rx_clk)

    # clear out sink buffer
    tb.axis_sink.clear()

    test_frames = [payload_data(x) for x in payload_lengths()]
    tx_frames = []

    for test_data in test_frames:
        test_frame = XgmiiFrame.from_payload(test_data, tx_complete=tx_frames.append)
        await tb.serdes_source.send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.axis_sink.recv()
        tx_frame = tx_frames.pop(0)

        frame_error = rx_frame.tuser & 1
        ptp_ts = rx_frame.tuser >> 1
        ptp_ts_ns = ptp_ts / 2**16

        tx_frame_sfd_ns = get_time_from_sim_steps(tx_frame.sim_time_sfd, "ns")

        if tx_frame.start_lane == 4:
            # start in lane 4 reports 1 full cycle delay, so subtract half clock period
            if len(dut.serdes_tx_data) == 64:
                tx_frame_sfd_ns -= tb.clk_period/2
            else:
                tx_frame_sfd_ns -= tb.clk_period

        tb.log.info("RX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("TX frame SFD sim time: %f ns", tx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(ptp_ts_ns - tx_frame_sfd_ns))

        assert rx_frame.tdata == test_data
        assert frame_error == 0
        if gbx_cfg is None:
            assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period*pipe_delay) < tb.clk_period*2

    assert tb.axis_sink.empty()

    for k in range(10):
        await RisingEdge(dut.logic_clk)


async def run_test_tx(dut, gbx_cfg=None, payload_lengths=None, payload_data=None, ifg=12):

    if len(dut.serdes_tx_data) == 64:
        pipe_delay = 5
    else:
        pipe_delay = 5

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_max_pkt_len.value = 9218
    tb.dut.cfg_tx_ifg.value = ifg

    await tb.reset()

    tb.log.info("Wait for PTP CDC lock")
    while not dut.uut.tx_ptp_locked.value.integer:
        await RisingEdge(dut.tx_clk)
    for k in range(1000):
        await RisingEdge(dut.tx_clk)

    tb.dut.cfg_tx_enable.value = 1
    tb.serdes_sink.clear()

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        await tb.axis_source.send(AxiStreamFrame(test_data, tid=0, tuser=0))

    for test_data in test_frames:
        rx_frame = await tb.serdes_sink.recv()
        tx_cpl = await tb.tx_cpl_sink.recv()

        ptp_ts_ns = int(tx_cpl.tdata[0]) / 2**16

        rx_frame_sfd_ns = get_time_from_sim_steps(rx_frame.sim_time_sfd, "ns")

        if rx_frame.start_lane == 4:
            # start in lane 4 reports 1 full cycle delay, so subtract half clock period
            if len(dut.serdes_tx_data) == 64:
                rx_frame_sfd_ns -= tb.clk_period/2
            else:
                rx_frame_sfd_ns -= tb.clk_period

        tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.ctrl is None
        if gbx_cfg is None:
            assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay) < tb.clk_period*2

    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.logic_clk)


async def run_test_tx_alignment(dut, gbx_cfg=None, payload_data=None, ifg=12):

    if len(dut.serdes_tx_data) == 64:
        pipe_delay = 5
    else:
        pipe_delay = 5

    dic_en = int(cocotb.top.DIC_EN.value)

    tb = TB(dut, gbx_cfg)

    byte_width = tb.axis_source.width // 8

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_max_pkt_len.value = 9218
    tb.dut.cfg_tx_ifg.value = ifg

    await tb.reset()

    tb.log.info("Wait for PTP CDC lock")
    while not dut.uut.tx_ptp_locked.value.integer:
        await RisingEdge(dut.tx_clk)
    for k in range(1000):
        await RisingEdge(dut.tx_clk)

    tb.dut.cfg_tx_enable.value = 1
    tb.serdes_sink.clear()

    for length in range(60, 92):

        for k in range(10):
            await RisingEdge(dut.tx_clk)

        test_frames = [payload_data(length) for k in range(10)]
        start_lane = []

        for test_data in test_frames:
            await tb.axis_source.send(AxiStreamFrame(test_data, tid=0, tuser=0))

        for test_data in test_frames:
            rx_frame = await tb.serdes_sink.recv()
            tx_cpl = await tb.tx_cpl_sink.recv()

            ptp_ts_ns = int(tx_cpl.tdata[0]) / 2**16

            rx_frame_sfd_ns = get_time_from_sim_steps(rx_frame.sim_time_sfd, "ns")

            if rx_frame.start_lane == 4:
                # start in lane 4 reports 1 full cycle delay, so subtract half clock period
                if len(dut.serdes_tx_data) == 64:
                    rx_frame_sfd_ns -= tb.clk_period/2
                else:
                    rx_frame_sfd_ns -= tb.clk_period

            tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
            tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
            tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))

            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.ctrl is None
            if gbx_cfg is None:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay) < tb.clk_period*2

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

    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.logic_clk)


async def run_test_rx_frame_sync(dut, gbx_cfg=None):

    tb = TB(dut, gbx_cfg)

    await tb.reset()

    tb.log.info("Wait for block lock")
    while not dut.rx_block_lock.value.integer:
        await RisingEdge(dut.rx_clk)

    assert dut.rx_block_lock.value.integer

    tb.log.info("Change offset")
    tb.serdes_source.bit_offset = 33

    for k in range(100):
        await RisingEdge(dut.rx_clk)

    tb.log.info("Check for lock lost")
    assert not dut.rx_block_lock.value.integer
    assert dut.rx_high_ber.value.integer

    for k in range(800):
        await RisingEdge(dut.rx_clk)

    tb.log.info("Check for block lock")
    assert dut.rx_block_lock.value.integer

    for k in range(300):
        await RisingEdge(dut.rx_clk)

    tb.log.info("Check for high BER deassert")
    assert not dut.rx_high_ber.value.integer

    await RisingEdge(dut.rx_clk)
    await RisingEdge(dut.rx_clk)


def size_list():
    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])


if cocotb.SIM_NAME:

    gbx_cfgs = [None]

    if cocotb.top.RX_GBX_IF_EN.value:
        gbx_cfgs.append((33, [32]))
        gbx_cfgs.append((66, [64, 65]))

    for test in [run_test_rx, run_test_tx]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("ifg", [12, 0])
        factory.add_option("gbx_cfg", gbx_cfgs)
        factory.generate_tests()

    if len(cocotb.top.serdes_tx_data) == 64:
        factory = TestFactory(run_test_tx_alignment)
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("ifg", [12])
        factory.add_option("gbx_cfg", gbx_cfgs)
        factory.generate_tests()

    factory = TestFactory(run_test_rx_frame_sync)
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


@pytest.mark.parametrize("dic_en", [1, 0])
@pytest.mark.parametrize("gbx_en", [1, 0])
@pytest.mark.parametrize("data_w", [32, 64])
def test_taxi_eth_mac_phy_10g_fifo(request, data_w, gbx_en, dic_en):
    dut = "taxi_eth_mac_phy_10g_fifo"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.f"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['DATA_W'] = data_w
    parameters['HDR_W'] = 2
    parameters['TX_GBX_IF_EN'] = gbx_en
    parameters['RX_GBX_IF_EN'] = parameters['TX_GBX_IF_EN']
    parameters['AXIS_DATA_W'] = parameters['DATA_W']
    parameters['PADDING_EN'] = 1
    parameters['DIC_EN'] = dic_en
    parameters['MIN_FRAME_LEN'] = 64
    parameters['PTP_TS_EN'] = 1
    parameters['PTP_TS_FMT_TOD'] = 1
    parameters['PTP_TS_W'] = 96 if parameters['PTP_TS_FMT_TOD'] else 64
    parameters['TX_TAG_W'] = 16
    parameters['BIT_REVERSE'] = 0
    parameters['SCRAMBLER_DISABLE'] = 0
    parameters['PRBS31_EN'] = 1
    parameters['TX_SERDES_PIPELINE'] = 2
    parameters['RX_SERDES_PIPELINE'] = 2
    parameters['BITSLIP_HIGH_CYCLES'] = 0
    parameters['BITSLIP_LOW_CYCLES'] = 7
    parameters['COUNT_125US'] = int(1250/6.4)
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
