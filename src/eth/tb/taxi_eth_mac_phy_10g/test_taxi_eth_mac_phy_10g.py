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
import struct
import sys

from scapy.layers.l2 import Ether

import pytest
import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.utils import get_time_from_sim_steps
from cocotb.regression import TestFactory

from cocotbext.eth import XgmiiFrame, PtpClockSimTime
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame

try:
    from baser import BaseRSerdesSource, BaseRSerdesSink
    from ptp_td import PtpTdSource
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from baser import BaseRSerdesSource, BaseRSerdesSink
        from ptp_td import PtpTdSource
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

        cocotb.start_soon(Clock(dut.rx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.stat_clk, self.clk_period, units="ns").start())

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

        self.axis_source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_tx), dut.tx_clk, dut.tx_rst)
        self.tx_cpl_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_tx_cpl), dut.tx_clk, dut.tx_rst)
        self.axis_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_rx), dut.rx_clk, dut.rx_rst)

        self.stat_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_stat), dut.stat_clk, dut.stat_rst)

        self.rx_ptp_clock = PtpClockSimTime(ts_tod=dut.rx_ptp_ts_in, clock=dut.rx_clk)
        self.tx_ptp_clock = PtpClockSimTime(ts_tod=dut.tx_ptp_ts_in, clock=dut.tx_clk)

        self.ptp_clk_period = self.clk_period

        cocotb.start_soon(Clock(dut.ptp_clk, self.ptp_clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.ptp_sample_clk, 8, units="ns").start())

        self.ptp_td_source = PtpTdSource(
            data=dut.ptp_td_sdi,
            clock=dut.ptp_clk,
            reset=dut.ptp_rst,
            period_ns=self.ptp_clk_period
        )

        dut.an_en.setimmediatevalue(0)
        dut.an_restart.setimmediatevalue(0)
        dut.an_speedup.setimmediatevalue(1)
        dut.an_timeout_en.setimmediatevalue(1)
        dut.an_usxgmii_en.setimmediatevalue(0)
        dut.an_usxgmii_auto.setimmediatevalue(1)
        dut.an_usxgmii_5g.setimmediatevalue(0)
        dut.an_adv_ability_usxgmii.setimmediatevalue(0x1601)

        dut.stat_rx_fifo_drop.setimmediatevalue(0)

        dut.cfg_tx_pad_en.setimmediatevalue(0)
        dut.cfg_tx_min_pkt_len.setimmediatevalue(0)
        dut.cfg_tx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_tx_ifg.setimmediatevalue(0)
        dut.cfg_tx_enable.setimmediatevalue(0)
        dut.cfg_rx_max_pkt_len.setimmediatevalue(0)
        dut.cfg_rx_enable.setimmediatevalue(0)
        dut.cfg_tx_prbs31_enable.setimmediatevalue(0)
        dut.cfg_rx_prbs31_enable.setimmediatevalue(0)
        dut.cfg_mcf_rx_eth_dst_mcast.setimmediatevalue(0)
        dut.cfg_mcf_rx_check_eth_dst_mcast.setimmediatevalue(0)
        dut.cfg_mcf_rx_eth_dst_ucast.setimmediatevalue(0)
        dut.cfg_mcf_rx_check_eth_dst_ucast.setimmediatevalue(0)
        dut.cfg_mcf_rx_eth_src.setimmediatevalue(0)
        dut.cfg_mcf_rx_check_eth_src.setimmediatevalue(0)
        dut.cfg_mcf_rx_eth_type.setimmediatevalue(0)
        dut.cfg_mcf_rx_opcode_lfc.setimmediatevalue(0)
        dut.cfg_mcf_rx_check_opcode_lfc.setimmediatevalue(0)
        dut.cfg_mcf_rx_opcode_pfc.setimmediatevalue(0)
        dut.cfg_mcf_rx_check_opcode_pfc.setimmediatevalue(0)
        dut.cfg_mcf_rx_forward.setimmediatevalue(0)
        dut.cfg_mcf_rx_enable.setimmediatevalue(0)
        dut.cfg_tx_lfc_eth_dst.setimmediatevalue(0)
        dut.cfg_tx_lfc_eth_src.setimmediatevalue(0)
        dut.cfg_tx_lfc_eth_type.setimmediatevalue(0)
        dut.cfg_tx_lfc_opcode.setimmediatevalue(0)
        dut.cfg_tx_lfc_en.setimmediatevalue(0)
        dut.cfg_tx_lfc_quanta.setimmediatevalue(0)
        dut.cfg_tx_lfc_refresh.setimmediatevalue(0)
        dut.cfg_tx_pfc_eth_dst.setimmediatevalue(0)
        dut.cfg_tx_pfc_eth_src.setimmediatevalue(0)
        dut.cfg_tx_pfc_eth_type.setimmediatevalue(0)
        dut.cfg_tx_pfc_opcode.setimmediatevalue(0)
        dut.cfg_tx_pfc_en.setimmediatevalue(0)
        dut.cfg_tx_pfc_quanta.setimmediatevalue([0]*8)
        dut.cfg_tx_pfc_refresh.setimmediatevalue([0]*8)
        dut.cfg_rx_lfc_opcode.setimmediatevalue(0)
        dut.cfg_rx_lfc_en.setimmediatevalue(0)
        dut.cfg_rx_pfc_opcode.setimmediatevalue(0)
        dut.cfg_rx_pfc_en.setimmediatevalue(0)

    async def reset(self):
        self.dut.rx_rst.setimmediatevalue(0)
        self.dut.tx_rst.setimmediatevalue(0)
        self.dut.ptp_rst.setimmediatevalue(0)
        self.dut.stat_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.rx_clk)
        await RisingEdge(self.dut.rx_clk)
        self.dut.rx_rst.value = 1
        self.dut.tx_rst.value = 1
        self.dut.ptp_rst.value = 1
        self.dut.stat_rst.value = 1
        await RisingEdge(self.dut.rx_clk)
        await RisingEdge(self.dut.rx_clk)
        self.dut.rx_rst.value = 0
        self.dut.tx_rst.value = 0
        self.dut.ptp_rst.value = 0
        self.dut.stat_rst.value = 0
        await RisingEdge(self.dut.rx_clk)
        await RisingEdge(self.dut.rx_clk)

        self.ptp_td_source.set_ts_tod_sim_time()
        self.ptp_td_source.set_ts_rel_sim_time()


async def run_test_rx(dut, gbx_cfg=None, payload_lengths=None, payload_data=None, ifg=12):

    if len(dut.serdes_tx_data) == 64:
        pipe_delay = 4
    else:
        pipe_delay = 5

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 9218-1

    await tb.reset()

    tb.dut.cfg_rx_enable.value = 0

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock.value):
        await RisingEdge(dut.rx_clk)

    if dut.PTP_TD_EN.value:
        tb.log.info("Wait for PTP CDC lock")
        while not int(dut.rx_ptp_locked.value):
            await RisingEdge(dut.rx_clk)
        for k in range(2000):
            await RisingEdge(dut.rx_clk)

    tb.dut.cfg_rx_enable.value = 1

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

        print(tx_frame)

        tx_frame_sfd_ns = get_time_from_sim_steps(tx_frame.sim_time_sfd, "ns")

        tb.log.info("RX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("TX frame SFD sim time: %f ns", tx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(ptp_ts_ns - tx_frame_sfd_ns))
        tb.log.info("Error: %f ns", abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period*pipe_delay))

        assert rx_frame.tdata == test_data
        assert frame_error == 0
        if gbx_cfg is None:
            if dut.PTP_TD_EN.value:
                assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period*pipe_delay) < tb.clk_period*5
            else:
                assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period*pipe_delay) < 0.01

    assert tb.axis_sink.empty()

    for k in range(10):
        await RisingEdge(dut.rx_clk)


async def run_test_tx(dut, gbx_cfg=None, payload_lengths=None, payload_data=None, ifg=12):

    if len(dut.serdes_tx_data) == 64:
        pipe_delay = 5
    else:
        pipe_delay = 5

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg

    await tb.reset()

    if dut.PTP_TD_EN.value:
        tb.log.info("Wait for PTP CDC lock")
        while not int(dut.tx_ptp_locked.value):
            await RisingEdge(dut.tx_clk)
        for k in range(2000):
            await RisingEdge(dut.tx_clk)
    else:
        for k in range(100):
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

        tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))
        tb.log.info("Error: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay))

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.ctrl is None
        if gbx_cfg is None:
            if dut.PTP_TD_EN.value:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay) < tb.clk_period*5
            else:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay) < 0.01

    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.tx_clk)


async def run_test_tx_alignment(dut, gbx_cfg=None, payload_data=None, ifg=12):

    if len(dut.serdes_tx_data) == 64:
        pipe_delay = 5
    else:
        pipe_delay = 6

    dic_en = int(cocotb.top.DIC_EN.value)

    tb = TB(dut, gbx_cfg)

    byte_width = tb.axis_source.width // 8

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg

    await tb.reset()

    if dut.PTP_TD_EN.value:
        tb.log.info("Wait for PTP CDC lock")
        while not int(dut.tx_ptp_locked.value):
            await RisingEdge(dut.tx_clk)
        for k in range(2000):
            await RisingEdge(dut.tx_clk)
    else:
        for k in range(100):
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

            tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
            tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
            tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))

            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.ctrl is None
            if gbx_cfg is None:
                if dut.PTP_TD_EN.value:
                    assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay) < tb.clk_period*5
                else:
                    assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period*pipe_delay) < 0.01

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

        await RisingEdge(dut.tx_clk)

    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.tx_clk)


async def run_test_tx_underrun(dut, gbx_cfg=None, ifg=12):

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    tb.dut.cfg_tx_enable.value = 1
    tb.serdes_sink.clear()

    test_data = bytes(x for x in range(60))

    for k in range(3):
        test_frame = AxiStreamFrame(test_data)
        await tb.axis_source.send(test_frame)

    for k in range(64*16 // tb.axis_source.width):
        await RisingEdge(dut.tx_clk)

    tb.axis_source.pause = True

    for k in range(4):
        await RisingEdge(dut.tx_clk)

    tb.axis_source.pause = False

    for k in range(3):
        rx_frame = await tb.serdes_sink.recv()

        if k == 1:
            assert rx_frame.data[-1] == 0xFE
            assert rx_frame.ctrl[-1] == 1
        else:
            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.ctrl is None

    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.tx_clk)


async def run_test_tx_error(dut, gbx_cfg=None, ifg=12):

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    tb.dut.cfg_tx_enable.value = 1
    tb.serdes_sink.clear()

    test_data = bytes(x for x in range(60))

    for k in range(3):
        test_frame = AxiStreamFrame(test_data)
        if k == 1:
            test_frame.tuser = 1
        await tb.axis_source.send(test_frame)

    for k in range(3):
        rx_frame = await tb.serdes_sink.recv()

        if k == 1:
            assert rx_frame.data[-1] == 0xFE
            assert rx_frame.ctrl[-1] == 1
        else:
            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.ctrl is None

    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.tx_clk)


async def run_test_rx_frame_sync(dut, gbx_cfg=None):

    tb = TB(dut, gbx_cfg)

    await tb.reset()

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock.value):
        await RisingEdge(dut.rx_clk)

    assert int(dut.rx_block_lock.value)

    tb.log.info("Change offset")
    tb.serdes_source.bit_offset = 33

    for k in range(100):
        await RisingEdge(dut.rx_clk)

    tb.log.info("Check for lock lost")
    assert not int(dut.rx_block_lock.value)
    assert int(dut.rx_high_ber.value)

    for k in range(800):
        await RisingEdge(dut.rx_clk)

    tb.log.info("Check for block lock")
    assert int(dut.rx_block_lock.value)

    for k in range(300):
        await RisingEdge(dut.rx_clk)

    tb.log.info("Check for high BER deassert")
    assert not int(dut.rx_high_ber.value)

    for k in range(10):
        await RisingEdge(dut.rx_clk)


async def run_test_lfc(dut, gbx_cfg=None, ifg=12):

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 9218-1

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock.value):
        await RisingEdge(dut.rx_clk)

    tb.dut.cfg_tx_enable.value = 1
    tb.dut.cfg_rx_enable.value = 1
    tb.serdes_sink.clear()

    dut.tx_lfc_req.value = 0
    dut.tx_lfc_resend.value = 0
    dut.rx_lfc_en.value = 1
    dut.rx_lfc_ack.value = 0

    dut.tx_lfc_pause_en.value = 1
    dut.tx_pause_req.value = 0

    dut.cfg_mcf_rx_eth_dst_mcast.value = 0x0180C2000001
    dut.cfg_mcf_rx_check_eth_dst_mcast.value = 1
    dut.cfg_mcf_rx_eth_dst_ucast.value = 0xDAD1D2D3D4D5
    dut.cfg_mcf_rx_check_eth_dst_ucast.value = 0
    dut.cfg_mcf_rx_eth_src.value = 0x5A5152535455
    dut.cfg_mcf_rx_check_eth_src.value = 0
    dut.cfg_mcf_rx_eth_type.value = 0x8808
    dut.cfg_mcf_rx_opcode_lfc.value = 0x0001
    dut.cfg_mcf_rx_check_opcode_lfc.value = 1
    dut.cfg_mcf_rx_opcode_pfc.value = 0x0101
    dut.cfg_mcf_rx_check_opcode_pfc.value = 1

    dut.cfg_mcf_rx_forward.value = 0
    dut.cfg_mcf_rx_enable.value = 1

    dut.cfg_tx_lfc_eth_dst.value = 0x0180C2000001
    dut.cfg_tx_lfc_eth_src.value = 0x5A5152535455
    dut.cfg_tx_lfc_eth_type.value = 0x8808
    dut.cfg_tx_lfc_opcode.value = 0x0001
    dut.cfg_tx_lfc_en.value = 1
    dut.cfg_tx_lfc_quanta.value = 0xFFFF
    dut.cfg_tx_lfc_refresh.value = 0x7F00

    dut.cfg_rx_lfc_opcode.value = 0x0001
    dut.cfg_rx_lfc_en.value = 1

    test_tx_pkts = []
    test_rx_pkts = []

    for k in range(32):
        length = 512
        payload = bytearray(itertools.islice(itertools.cycle(range(256)), length))

        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5', type=0x8000)
        test_pkt = eth / payload
        test_tx_pkts.append(test_pkt.copy())

        await tb.axis_source.send(bytes(test_pkt))

        eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='5A:51:52:53:54:55', type=0x8000)
        test_pkt = eth / payload
        test_rx_pkts.append(test_pkt.copy())

        test_frame = XgmiiFrame.from_payload(bytes(test_pkt))
        await tb.serdes_source.send(test_frame)

        if k == 16:
            eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='01:80:C2:00:00:01', type=0x8808)
            test_pkt = eth / struct.pack('!HH', 0x0001, 100)
            test_rx_pkts.append(test_pkt.copy())

            test_frame = XgmiiFrame.from_payload(bytes(test_pkt))
            await tb.serdes_source.send(test_frame)

    for k in range(200):
        await RisingEdge(dut.tx_clk)

    dut.tx_lfc_req.value = 1

    for k in range(200):
        await RisingEdge(dut.tx_clk)

    dut.tx_lfc_req.value = 0

    while not int(dut.rx_lfc_req.value):
        await RisingEdge(dut.tx_clk)

    for k in range(200):
        await RisingEdge(dut.tx_clk)

    dut.tx_lfc_req.value = 1

    for k in range(200):
        await RisingEdge(dut.tx_clk)

    dut.tx_lfc_req.value = 0

    while test_rx_pkts:
        rx_frame = await tb.axis_sink.recv()

        rx_pkt = Ether(bytes(rx_frame))

        tb.log.info("RX packet: %s", repr(rx_pkt))

        if rx_pkt.type == 0x8808:
            test_pkt = test_rx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(rx_pkt).find(bytes(test_pkt)) == 0
            if isinstance(rx_frame.tuser, list):
                assert rx_frame.tuser[-1] & 1
            else:
                assert rx_frame.tuser & 1
        else:
            test_pkt = test_rx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(rx_pkt).find(bytes(test_pkt)) == 0
            if isinstance(rx_frame.tuser, list):
                assert not rx_frame.tuser[-1] & 1
            else:
                assert not rx_frame.tuser & 1

    tx_lfc_cnt = 0

    while test_tx_pkts:
        tx_frame = await tb.serdes_sink.recv()

        tx_pkt = Ether(bytes(tx_frame.get_payload()))

        tb.log.info("TX packet: %s", repr(tx_pkt))

        if tx_pkt.type == 0x8808:
            tx_lfc_cnt += 1
        else:
            test_pkt = test_tx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(tx_pkt).find(bytes(test_pkt)) == 0

    assert tx_lfc_cnt == 4

    assert tb.axis_sink.empty()
    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.tx_clk)


async def run_test_pfc(dut, gbx_cfg=None, ifg=12):

    tb = TB(dut, gbx_cfg)

    tb.serdes_source.ifg = ifg
    tb.dut.cfg_tx_pad_en.value = 1
    tb.dut.cfg_tx_min_pkt_len.value = 60-1
    tb.dut.cfg_tx_max_pkt_len.value = 9218-1
    tb.dut.cfg_tx_ifg.value = ifg
    tb.dut.cfg_rx_max_pkt_len.value = 9218-1

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock.value):
        await RisingEdge(dut.rx_clk)

    tb.dut.cfg_tx_enable.value = 1
    tb.dut.cfg_rx_enable.value = 1
    tb.serdes_sink.clear()

    dut.tx_pfc_req.value = 0x00
    dut.tx_pfc_resend.value = 0
    dut.rx_pfc_en.value = 0xff
    dut.rx_pfc_ack.value = 0x00

    dut.tx_lfc_pause_en.value = 0
    dut.tx_pause_req.value = 0

    dut.cfg_mcf_rx_eth_dst_mcast.value = 0x0180C2000001
    dut.cfg_mcf_rx_check_eth_dst_mcast.value = 1
    dut.cfg_mcf_rx_eth_dst_ucast.value = 0xDAD1D2D3D4D5
    dut.cfg_mcf_rx_check_eth_dst_ucast.value = 0
    dut.cfg_mcf_rx_eth_src.value = 0x5A5152535455
    dut.cfg_mcf_rx_check_eth_src.value = 0
    dut.cfg_mcf_rx_eth_type.value = 0x8808
    dut.cfg_mcf_rx_opcode_lfc.value = 0x0001
    dut.cfg_mcf_rx_check_opcode_lfc.value = 1
    dut.cfg_mcf_rx_opcode_pfc.value = 0x0101
    dut.cfg_mcf_rx_check_opcode_pfc.value = 1

    dut.cfg_mcf_rx_forward.value = 0
    dut.cfg_mcf_rx_enable.value = 1

    dut.cfg_tx_pfc_eth_dst.value = 0x0180C2000001
    dut.cfg_tx_pfc_eth_src.value = 0x5A5152535455
    dut.cfg_tx_pfc_eth_type.value = 0x8808
    dut.cfg_tx_pfc_opcode.value = 0x0101
    dut.cfg_tx_pfc_en.value = 1
    dut.cfg_tx_pfc_quanta.value = [0xFFFF]*8
    dut.cfg_tx_pfc_refresh.value = [0x7F00]*8

    dut.cfg_rx_pfc_opcode.value = 0x0101
    dut.cfg_rx_pfc_en.value = 1

    test_tx_pkts = []
    test_rx_pkts = []

    for k in range(32):
        length = 512
        payload = bytearray(itertools.islice(itertools.cycle(range(256)), length))

        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5', type=0x8000)
        test_pkt = eth / payload
        test_tx_pkts.append(test_pkt.copy())

        await tb.axis_source.send(bytes(test_pkt))

        eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='5A:51:52:53:54:55', type=0x8000)
        test_pkt = eth / payload
        test_rx_pkts.append(test_pkt.copy())

        test_frame = XgmiiFrame.from_payload(bytes(test_pkt))
        await tb.serdes_source.send(test_frame)

        if k == 16:
            eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='01:80:C2:00:00:01', type=0x8808)
            test_pkt = eth / struct.pack('!HH8H', 0x0101, 0x00FF, 10, 20, 30, 40, 50, 60, 70, 80)
            test_rx_pkts.append(test_pkt.copy())

            test_frame = XgmiiFrame.from_payload(bytes(test_pkt))
            await tb.serdes_source.send(test_frame)

    dut.rx_pfc_ack.value = 0xff

    for i in range(8):
        for k in range(200):
            await RisingEdge(dut.tx_clk)

        dut.tx_pfc_req.value = 0xff >> (7-i)

    for k in range(200):
        await RisingEdge(dut.tx_clk)

    dut.tx_pfc_req.value = 0x00

    while test_rx_pkts:
        rx_frame = await tb.axis_sink.recv()

        rx_pkt = Ether(bytes(rx_frame))

        tb.log.info("RX packet: %s", repr(rx_pkt))

        if rx_pkt.type == 0x8808:
            test_pkt = test_rx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(rx_pkt).find(bytes(test_pkt)) == 0
            if isinstance(rx_frame.tuser, list):
                assert rx_frame.tuser[-1] & 1
            else:
                assert rx_frame.tuser & 1
        else:
            test_pkt = test_rx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(rx_pkt).find(bytes(test_pkt)) == 0
            if isinstance(rx_frame.tuser, list):
                assert not rx_frame.tuser[-1] & 1
            else:
                assert not rx_frame.tuser & 1

    tx_pfc_cnt = 0

    while test_tx_pkts:
        tx_frame = await tb.serdes_sink.recv()

        tx_pkt = Ether(bytes(tx_frame.get_payload()))

        tb.log.info("TX packet: %s", repr(tx_pkt))

        if tx_pkt.type == 0x8808:
            tx_pfc_cnt += 1
        else:
            test_pkt = test_tx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(tx_pkt).find(bytes(test_pkt)) == 0

    assert tx_pfc_cnt == 9

    assert tb.axis_sink.empty()
    assert tb.serdes_sink.empty()

    for k in range(10):
        await RisingEdge(dut.tx_clk)


async def run_usxgmii_an(tb, cfg):
    # link timer scaled by 1000x for faster simulation
    link_timer = Timer(1.6, 'us')

    dut = tb.dut

    for k in range(10):
        tb.log.info("AN_RESTART")
        tb.serdes_source.set_seq_os((0x0000 << 8) | 0x03)

        await link_timer

        tb.log.info("ABILITY_DETECT")
        tb.serdes_source.set_seq_os(((cfg & ~0x4000) << 8) | 0x03)
        tb.serdes_sink.get_os()

        lp_cfg = None
        while True:
            await RisingEdge(dut.tx_clk)
            lp_cfg = tb.serdes_sink.get_os()[0]
            if lp_cfg is None:
                continue
            if lp_cfg & 0xff != 0x03:
                continue
            lp_cfg = lp_cfg >> 8
            if tb.serdes_sink.get_os_match() and lp_cfg != 0:
                break

        tb.log.info("ACKNOWLEDGE_DETECT")
        tb.serdes_source.set_seq_os(((cfg | 0x4000) << 8) | 0x03)
        tb.serdes_sink.get_os()

        lp_cfg_ack = None
        while True:
            await RisingEdge(dut.tx_clk)
            lp_cfg_ack = tb.serdes_sink.get_os()[0]
            if lp_cfg_ack is None:
                continue
            if lp_cfg_ack & 0xff != 0x03:
                continue
            lp_cfg_ack = lp_cfg_ack >> 8
            if tb.serdes_sink.get_os_match() and lp_cfg_ack & 0x4000:
                break
            elif tb.serdes_sink.get_os_match() and lp_cfg_ack == 0:
                break

        if lp_cfg | 0x4000 != lp_cfg_ack:
            tb.log.warning("AN inconsistent, restarting (0x%04x != 0x%04x)", lp_cfg | 0x4000, lp_cfg_ack)
            continue

        if lp_cfg_ack == 0:
            tb.log.warning("AN restart requested")
            continue

        tb.log.info("COMPLETE_ACKNOWLEDGE")
        await link_timer

        tb.log.info("IDLE_DETECT")
        tb.serdes_source.set_seq_os(None)

        await link_timer

        lp_cfg_ack2 = None
        while True:
            await RisingEdge(dut.tx_clk)
            if tb.serdes_sink.get_idle_match():
                break
            lp_cfg_ack2 = tb.serdes_sink.get_os()[0]
            if lp_cfg_ack2 is None:
                continue
            if lp_cfg_ack2 & 0xff != 0x03:
                continue
            lp_cfg_ack2 = lp_cfg_ack2 >> 8
            if tb.serdes_sink.get_os_match() and (lp_cfg_ack2 == 0 or lp_cfg_ack != lp_cfg_ack2):
                break

        if lp_cfg_ack2 is not None and lp_cfg_ack != lp_cfg_ack2:
            tb.log.warning("AN inconsistent, restarting (0x%04x != 0x%04x)", lp_cfg_ack, lp_cfg_ack2)
            continue

        if lp_cfg_ack2 == 0:
            tb.log.warning("AN restart requested")
            continue

        tb.log.info("AN done")
        return lp_cfg_ack

    tb.log.warning("AN timed out")
    tb.serdes_source.set_seq_os(None)
    return None


async def run_test_usxgmii(dut, gbx_cfg=None):

    tb = TB(dut, gbx_cfg)

    dut.an_en.value = 1
    dut.an_restart.value = 0
    dut.an_speedup.value = 1
    dut.an_timeout_en.value = 1
    dut.an_usxgmii_en.value = 0
    dut.an_usxgmii_auto.value = 1
    dut.an_usxgmii_5g.value = 0
    dut.an_adv_ability_usxgmii.value = 0x1601

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    if 1:
        for x in range(6):
            cfg1 = 0x0001 | (x << 9) | ((x & 1) << 12) | ((x & 2) << 14)
            cfg2 = cfg1
            dut.an_adv_ability_usxgmii.value = cfg2

            lp_cfg = await run_usxgmii_an(tb, cfg1)

            for k in range(2000):
                if not dut.an_running.value:
                    break
                await RisingEdge(dut.tx_clk)

            assert lp_cfg == cfg2 | 0x4000
            assert not int(dut.an_running.value)
            assert int(dut.an_complete.value)
            assert not int(dut.an_timeout.value)
            assert int(dut.an_usxgmii_mode.value)
            assert int(dut.an_lp_adv_ability.value) == cfg1 | 0x4000
            assert bool(dut.an_lp_usxgmii_link.value) == bool((cfg1 >> 15) & 1)
            assert int(dut.an_lp_usxgmii_speed.value) == (cfg1 >> 9) & 0x7
            assert bool(dut.an_res_full_duplex.value) == bool((cfg1 >> 12) & 1)
    else:
        lp_cfg = await run_usxgmii_an(tb, 0x9801)

        for k in range(2000):
            if not dut.an_running.value:
                break
            await RisingEdge(dut.tx_clk)

        assert lp_cfg is None

    for k in range(10):
        await RisingEdge(dut.tx_clk)


def size_list():
    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])


if getattr(cocotb, 'top', None) is not None:

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

    for test in [run_test_tx_underrun, run_test_tx_error]:

        factory = TestFactory(test)
        factory.add_option("ifg", [12])
        factory.add_option("gbx_cfg", gbx_cfgs)
        factory.generate_tests()

    factory = TestFactory(run_test_rx_frame_sync)
    factory.add_option("gbx_cfg", gbx_cfgs)
    factory.generate_tests()

    if cocotb.top.PFC_EN.value:
        for test in [run_test_lfc, run_test_pfc]:
            factory = TestFactory(test)
            factory.add_option("ifg", [12])
            factory.add_option("gbx_cfg", gbx_cfgs)
            factory.generate_tests()

    if cocotb.top.USXGMII_EN.value:
        for test in [run_test_usxgmii]:
            factory = TestFactory(test)
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


@pytest.mark.parametrize(("dic_en", "pfc_en"), [(1, 1), (1, 0), (0, 0)])
@pytest.mark.parametrize("gbx_en", [1, 0])
@pytest.mark.parametrize("ptp_td_en", [1, 0])
@pytest.mark.parametrize("data_w", [32, 64])
def test_taxi_eth_mac_phy_10g(request, data_w, ptp_td_en, gbx_en, dic_en, pfc_en):
    dut = "taxi_eth_mac_phy_10g"
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
    parameters['USXGMII_EN'] = int(data_w == 32)
    parameters['DIC_EN'] = dic_en
    parameters['PTP_TS_EN'] = 1
    parameters['PTP_TD_EN'] = ptp_td_en
    parameters['PTP_TS_FMT_TOD'] = 1
    parameters['PTP_TS_W'] = 96 if parameters['PTP_TS_FMT_TOD'] else 64
    parameters['PTP_TD_SDI_PIPELINE'] = 2
    parameters['TX_TAG_W'] = 16
    parameters['BIT_REVERSE'] = 0
    parameters['SCRAMBLER_DISABLE'] = 0
    parameters['PRBS31_EN'] = 1
    parameters['TX_SERDES_PIPELINE'] = 2
    parameters['RX_SERDES_PIPELINE'] = 2
    parameters['BITSLIP_HIGH_CYCLES'] = 0
    parameters['BITSLIP_LOW_CYCLES'] = 7
    parameters['COUNT_125US'] = int(1250/6.4)
    parameters['PFC_EN'] = pfc_en
    parameters['PAUSE_EN'] = parameters['PFC_EN']
    parameters['STAT_EN'] = 1
    parameters['STAT_TX_LEVEL'] = 2
    parameters['STAT_RX_LEVEL'] = parameters['STAT_TX_LEVEL']
    parameters['STAT_ID_BASE'] = 0
    parameters['STAT_UPDATE_PERIOD'] = 1024
    parameters['STAT_STR_EN'] = 1
    parameters['STAT_PREFIX_STR'] = "\"MAC\""

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
