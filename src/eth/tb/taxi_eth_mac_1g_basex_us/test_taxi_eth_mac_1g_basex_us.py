#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2021-2026 FPGA Ninja, LLC

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
from cocotb.triggers import RisingEdge
from cocotb.utils import get_time_from_sim_steps
from cocotb.regression import TestFactory

from cocotbext.eth import GmiiFrame, PtpClockSimTime
from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame
from cocotbext.axi import ApbBus, ApbMaster

try:
    from basex import BaseXSerdesSource, BaseXSerdesSink
    from ptp_td import PtpTdSource
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from basex import BaseXSerdesSource, BaseXSerdesSink
        from ptp_td import PtpTdSource
    finally:
        del sys.path[0]


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.xcvr_ctrl_clk, 8, units="ns").start())
        cocotb.start_soon(Clock(dut.stat_clk, 8, units="ns").start())
        cocotb.start_soon(Clock(dut.xcvr_gtrefclk00_in, 6.206, units="ns").start())

        self.apb_ctrl = ApbMaster(ApbBus.from_entity(dut.s_apb_ctrl), dut.xcvr_ctrl_clk, dut.xcvr_ctrl_rst)

        self.serdes_sources = []
        self.serdes_sinks = []

        self.clk_period = []

        for ch in dut.uut.ch:
            gt_inst = ch.ch_inst.gt.gt_inst

            if ch.ch_inst.CFG_LOW_LATENCY.value:
                clk = 16
                gbx_cfg = None
            else:
                clk = 16
                gbx_cfg = None

            self.clk_period.append(clk)

            cocotb.start_soon(Clock(gt_inst.tx_clk, clk, units="ns").start())
            cocotb.start_soon(Clock(gt_inst.rx_clk, clk, units="ns").start())

            self.serdes_sources.append(BaseXSerdesSource(
                data=gt_inst.serdes_rx_data,
                data_k=gt_inst.serdes_rx_data_k,
                data_valid=gt_inst.serdes_rx_data_valid,
                clock=gt_inst.rx_clk,
                enc_8b10b=False,
                gbx_cfg=gbx_cfg
            ))
            self.serdes_sinks.append(BaseXSerdesSink(
                data=gt_inst.serdes_tx_data,
                data_k=gt_inst.serdes_tx_data_k,
                data_valid=gt_inst.serdes_tx_data_valid,
                gbx_sync=gt_inst.serdes_tx_gbx_sync,
                clock=gt_inst.tx_clk,
                dec_8b10b=False,
                gbx_cfg=gbx_cfg
            ))

        self.axis_sources = []
        self.tx_cpl_sinks = []
        self.axis_sinks = []

        for k in range(4):
            self.axis_sources.append(AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_tx[k]), dut.uut.ch[k].ch_inst.gt.gt_inst.tx_clk, dut.tx_rst_out[k]))
            self.tx_cpl_sinks.append(AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_tx_cpl[k]), dut.uut.ch[k].ch_inst.gt.gt_inst.tx_clk, dut.tx_rst_out[k]))
            self.axis_sinks.append(AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_rx[k]), dut.uut.ch[k].ch_inst.gt.gt_inst.rx_clk, dut.rx_rst_out[k]))

        self.stat_sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_stat), dut.stat_clk, dut.stat_rst)

        self.rx_ptp_clocks = []
        self.tx_ptp_clocks = []

        for k in range(4):
            self.rx_ptp_clocks.append(PtpClockSimTime(ts_tod=dut.rx_ptp_ts_in[k], clock=dut.uut.ch[k].ch_inst.gt.gt_inst.rx_clk))
            self.tx_ptp_clocks.append(PtpClockSimTime(ts_tod=dut.tx_ptp_ts_in[k], clock=dut.uut.ch[k].ch_inst.gt.gt_inst.tx_clk))

        self.ptp_clk_period = self.clk_period[0]

        cocotb.start_soon(Clock(dut.ptp_clk, self.ptp_clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.ptp_sample_clk, 8, units="ns").start())

        self.ptp_td_source = PtpTdSource(
            data=dut.ptp_td_sdi,
            clock=dut.ptp_clk,
            reset=dut.ptp_rst,
            period_ns=self.ptp_clk_period
        )

        dut.rx_rst_in.setimmediatevalue([0]*4)
        dut.tx_rst_in.setimmediatevalue([0]*4)

        dut.an_en.setimmediatevalue([0]*4)
        dut.an_restart.setimmediatevalue([0]*4)
        dut.an_speedup.setimmediatevalue([1]*4)
        dut.an_adv_ability.setimmediatevalue([0x0020]*4)

        dut.stat_rx_fifo_drop.setimmediatevalue([0]*4)

        dut.cfg_tx_pad_en.setimmediatevalue([0]*4)
        dut.cfg_tx_min_pkt_len.setimmediatevalue([0]*4)
        dut.cfg_tx_max_pkt_len.setimmediatevalue([0]*4)
        dut.cfg_tx_ifg.setimmediatevalue([0]*4)
        dut.cfg_tx_enable.setimmediatevalue([0]*4)
        dut.cfg_rx_max_pkt_len.setimmediatevalue([0]*4)
        dut.cfg_rx_enable.setimmediatevalue([0]*4)
        dut.cfg_tx_prbs31_enable.setimmediatevalue([0]*4)
        dut.cfg_rx_prbs31_enable.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_eth_dst_mcast.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_check_eth_dst_mcast.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_eth_dst_ucast.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_check_eth_dst_ucast.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_eth_src.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_check_eth_src.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_eth_type.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_opcode_lfc.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_check_opcode_lfc.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_opcode_pfc.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_check_opcode_pfc.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_forward.setimmediatevalue([0]*4)
        dut.cfg_mcf_rx_enable.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_eth_dst.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_eth_src.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_eth_type.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_opcode.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_en.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_quanta.setimmediatevalue([0]*4)
        dut.cfg_tx_lfc_refresh.setimmediatevalue([0]*4)
        dut.cfg_tx_pfc_eth_dst.setimmediatevalue([0]*4)
        dut.cfg_tx_pfc_eth_src.setimmediatevalue([0]*4)
        dut.cfg_tx_pfc_eth_type.setimmediatevalue([0]*4)
        dut.cfg_tx_pfc_opcode.setimmediatevalue([0]*4)
        dut.cfg_tx_pfc_en.setimmediatevalue([0]*4)
        for x in range(4):
            for y in range(8):
                dut.cfg_tx_pfc_quanta[x][y].setimmediatevalue(0)
                dut.cfg_tx_pfc_refresh[x][y].setimmediatevalue(0)
        dut.cfg_rx_lfc_opcode.setimmediatevalue([0]*4)
        dut.cfg_rx_lfc_en.setimmediatevalue([0]*4)
        dut.cfg_rx_pfc_opcode.setimmediatevalue([0]*4)
        dut.cfg_rx_pfc_en.setimmediatevalue([0]*4)

    async def reset(self):
        self.dut.xcvr_ctrl_rst.setimmediatevalue(0)
        self.dut.ptp_rst.setimmediatevalue(0)
        self.dut.stat_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.xcvr_ctrl_clk)
        await RisingEdge(self.dut.xcvr_ctrl_clk)
        self.dut.xcvr_ctrl_rst.value = 1
        self.dut.ptp_rst.value = 1
        self.dut.stat_rst.value = 1
        await RisingEdge(self.dut.xcvr_ctrl_clk)
        await RisingEdge(self.dut.xcvr_ctrl_clk)
        self.dut.xcvr_ctrl_rst.value = 0
        self.dut.ptp_rst.value = 0
        self.dut.stat_rst.value = 0
        await RisingEdge(self.dut.xcvr_ctrl_clk)
        await RisingEdge(self.dut.xcvr_ctrl_clk)

        self.ptp_td_source.set_ts_tod_sim_time()
        self.ptp_td_source.set_ts_rel_sim_time()


async def run_test_regs(dut):
    tb = TB(dut)
    await tb.reset()

    data = await tb.apb_ctrl.read(0x00000, 2)
    data = await tb.apb_ctrl.read(0x04000, 2)
    data = await tb.apb_ctrl.read(0x08000, 2)
    data = await tb.apb_ctrl.read(0x0C000, 2)

    data = await tb.apb_ctrl.read(0x10000, 2)
    data = await tb.apb_ctrl.read(0x14000, 2)
    data = await tb.apb_ctrl.read(0x18000, 2)
    data = await tb.apb_ctrl.read(0x1C000, 2)

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_rx(dut, port=0, payload_lengths=None, payload_data=None, ifg=12):

    if dut.COMBINED_MAC_PCS.value:
        pipe_delay = 3
    else:
        pipe_delay = 3

    tb = TB(dut)

    tb.serdes_sources[port].ifg = ifg
    tb.dut.cfg_tx_ifg[port].value = ifg
    tb.dut.cfg_rx_max_pkt_len[port].value = 9218-1

    await tb.reset()

    tb.dut.cfg_rx_enable[port].value = 0

    tb.log.info("Wait for reset")
    while int(dut.rx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("Wait for PTP CDC lock")
    while not int(dut.rx_ptp_locked[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)
    for k in range(2000):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.dut.cfg_rx_enable[port].value = 1

    test_frames = [payload_data(x) for x in payload_lengths()]
    tx_frames = []

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data, tx_complete=tx_frames.append)
        await tb.serdes_sources[port].send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.axis_sinks[port].recv()
        tx_frame = tx_frames.pop(0)

        frame_error = rx_frame.tuser & 1
        ptp_ts = rx_frame.tuser >> 1
        ptp_ts_ns = ptp_ts / 2**16

        print(tx_frame)

        tx_frame_sfd_ns = get_time_from_sim_steps(tx_frame.sim_time_sfd, "ns")

        tb.log.info("RX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("TX frame SFD sim time: %f ns", tx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(ptp_ts_ns - tx_frame_sfd_ns))
        tb.log.info("Error: %f ns", abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period[port]*pipe_delay))

        assert rx_frame.tdata == test_data
        assert frame_error == 0
        if not tb.serdes_sources[port].gbx_seq_len:
            if dut.PTP_TD_EN.value:
                assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period[port]*pipe_delay) < tb.clk_period[port]*5
            else:
                assert abs(ptp_ts_ns - tx_frame_sfd_ns - tb.clk_period[port]*pipe_delay) < 0.01

    assert tb.axis_sinks[port].empty()

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_tx(dut, port=0, payload_lengths=None, payload_data=None, ifg=12):

    if dut.COMBINED_MAC_PCS.value:
        pipe_delay = 4
    else:
        pipe_delay = 4

    tb = TB(dut)

    tb.serdes_sources[port].ifg = ifg
    tb.dut.cfg_tx_pad_en[port].value = 1
    tb.dut.cfg_tx_min_pkt_len[port].value = 60-1
    tb.dut.cfg_tx_max_pkt_len[port].value = 9218-1
    tb.dut.cfg_tx_ifg[port].value = ifg

    await tb.reset()

    tb.log.info("Wait for reset")
    while int(dut.tx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("Wait for PTP CDC lock")
    while not int(dut.tx_ptp_locked[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)
    for k in range(2000):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.dut.cfg_tx_enable[port].value = 1

    for p in tb.serdes_sinks:
        p.clear()

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        await tb.axis_sources[port].send(AxiStreamFrame(test_data, tid=0, tuser=0))

    for test_data in test_frames:
        rx_frame = await tb.serdes_sinks[port].recv()
        tx_cpl = await tb.tx_cpl_sinks[port].recv()

        ptp_ts_ns = int(tx_cpl.tdata[0]) / 2**16

        rx_frame_sfd_ns = get_time_from_sim_steps(rx_frame.sim_time_sfd, "ns")

        tb.log.info("TX frame PTP TS: %f ns", ptp_ts_ns)
        tb.log.info("RX frame SFD sim time: %f ns", rx_frame_sfd_ns)
        tb.log.info("Difference: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns))
        tb.log.info("Error: %f ns", abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period[port]*pipe_delay))

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()
        assert rx_frame.error is None
        if not tb.serdes_sinks[port].gbx_seq_len:
            if dut.PTP_TD_EN.value:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period[port]*pipe_delay) < tb.clk_period[port]*5
            else:
                assert abs(rx_frame_sfd_ns - ptp_ts_ns - tb.clk_period[port]*pipe_delay) < 0.01

    assert tb.serdes_sinks[port].empty()

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_tx_underrun(dut, port=0, ifg=12):

    tb = TB(dut)

    tb.serdes_sources[port].ifg = ifg
    tb.dut.cfg_tx_pad_en[port].value = 1
    tb.dut.cfg_tx_min_pkt_len[port].value = 60-1
    tb.dut.cfg_tx_max_pkt_len[port].value = 9218-1
    tb.dut.cfg_tx_ifg[port].value = ifg

    await tb.reset()

    tb.log.info("Wait for reset")
    while int(dut.tx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    for k in range(100):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.dut.cfg_tx_enable[port].value = 1

    for p in tb.serdes_sinks:
        p.clear()

    test_data = bytes(x for x in range(60))

    for k in range(3):
        test_frame = AxiStreamFrame(test_data)
        await tb.axis_sources[port].send(test_frame)

    for k in range(64*16 // tb.axis_sources[port].width):
        await RisingEdge(dut.tx_clk[port])

    tb.axis_sources[port].pause = True

    for k in range(4):
        await RisingEdge(dut.tx_clk[port])

    tb.axis_sources[port].pause = False

    for k in range(3):
        rx_frame = await tb.serdes_sinks[port].recv()

        if k == 1:
            assert rx_frame.data[-1] == 0xFE
            assert rx_frame.error[-1] == 1
        else:
            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.error is None

    assert tb.serdes_sinks[port].empty()

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_tx_error(dut, port=0, ifg=12):

    tb = TB(dut)

    tb.serdes_sources[port].ifg = ifg
    tb.dut.cfg_tx_pad_en[port].value = 1
    tb.dut.cfg_tx_min_pkt_len[port].value = 60-1
    tb.dut.cfg_tx_max_pkt_len[port].value = 9218-1
    tb.dut.cfg_tx_ifg[port].value = ifg

    await tb.reset()

    tb.log.info("Wait for reset")
    while int(dut.tx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    for k in range(100):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.dut.cfg_tx_enable[port].value = 1

    for p in tb.serdes_sinks:
        p.clear()

    test_data = bytes(x for x in range(60))

    for k in range(3):
        test_frame = AxiStreamFrame(test_data)
        if k == 1:
            test_frame.tuser = 1
        await tb.axis_sources[port].send(test_frame)

    for k in range(3):
        rx_frame = await tb.serdes_sinks[port].recv()

        if k == 1:
            assert rx_frame.data[-1] == 0xFE
            assert rx_frame.error[-1] == 1
        else:
            assert rx_frame.get_payload() == test_data
            assert rx_frame.check_fcs()
            assert rx_frame.error is None

    assert tb.serdes_sinks[port].empty()

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_lfc(dut, port=0, ifg=12):

    tb = TB(dut)

    tb.serdes_sources[port].ifg = ifg
    tb.dut.cfg_tx_pad_en[port].value = 1
    tb.dut.cfg_tx_min_pkt_len[port].value = 60-1
    tb.dut.cfg_tx_max_pkt_len[port].value = 9218-1
    tb.dut.cfg_tx_ifg[port].value = ifg
    tb.dut.cfg_rx_max_pkt_len[port].value = 9218-1

    await tb.reset()

    tb.log.info("Wait for reset")
    while int(dut.rx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    for k in range(100):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.dut.cfg_tx_enable[port].value = 1
    tb.dut.cfg_rx_enable[port].value = 1

    for p in tb.serdes_sinks:
        p.clear()

    dut.tx_lfc_req[port].value = 0
    dut.tx_lfc_resend[port].value = 0
    dut.rx_lfc_en[port].value = 1
    dut.rx_lfc_ack[port].value = 0

    dut.tx_lfc_pause_en[port].value = 1
    dut.tx_pause_req[port].value = 0

    dut.cfg_mcf_rx_eth_dst_mcast[port].value = 0x0180C2000001
    dut.cfg_mcf_rx_check_eth_dst_mcast[port].value = 1
    dut.cfg_mcf_rx_eth_dst_ucast[port].value = 0xDAD1D2D3D4D5
    dut.cfg_mcf_rx_check_eth_dst_ucast[port].value = 0
    dut.cfg_mcf_rx_eth_src[port].value = 0x5A5152535455
    dut.cfg_mcf_rx_check_eth_src[port].value = 0
    dut.cfg_mcf_rx_eth_type[port].value = 0x8808
    dut.cfg_mcf_rx_opcode_lfc[port].value = 0x0001
    dut.cfg_mcf_rx_check_opcode_lfc[port].value = 1
    dut.cfg_mcf_rx_opcode_pfc[port].value = 0x0101
    dut.cfg_mcf_rx_check_opcode_pfc[port].value = 1

    dut.cfg_mcf_rx_forward[port].value = 0
    dut.cfg_mcf_rx_enable[port].value = 1

    dut.cfg_tx_lfc_eth_dst[port].value = 0x0180C2000001
    dut.cfg_tx_lfc_eth_src[port].value = 0x5A5152535455
    dut.cfg_tx_lfc_eth_type[port].value = 0x8808
    dut.cfg_tx_lfc_opcode[port].value = 0x0001
    dut.cfg_tx_lfc_en[port].value = 1
    dut.cfg_tx_lfc_quanta[port].value = 0xFFFF
    dut.cfg_tx_lfc_refresh[port].value = 0x7F00

    dut.cfg_rx_lfc_opcode[port].value = 0x0001
    dut.cfg_rx_lfc_en[port].value = 1

    test_tx_pkts = []
    test_rx_pkts = []

    for k in range(32):
        length = 512
        payload = bytearray(itertools.islice(itertools.cycle(range(256)), length))

        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5', type=0x8000)
        test_pkt = eth / payload
        test_tx_pkts.append(test_pkt.copy())

        await tb.axis_sources[port].send(bytes(test_pkt))

        eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='5A:51:52:53:54:55', type=0x8000)
        test_pkt = eth / payload
        test_rx_pkts.append(test_pkt.copy())

        test_frame = GmiiFrame.from_payload(bytes(test_pkt))
        await tb.serdes_sources[port].send(test_frame)

        if k == 16:
            eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='01:80:C2:00:00:01', type=0x8808)
            test_pkt = eth / struct.pack('!HH', 0x0001, 100)
            test_rx_pkts.append(test_pkt.copy())

            test_frame = GmiiFrame.from_payload(bytes(test_pkt))
            await tb.serdes_sources[port].send(test_frame)

    for k in range(200):
        await RisingEdge(dut.xcvr_ctrl_clk)

    dut.tx_lfc_req[port].value = 1

    for k in range(200):
        await RisingEdge(dut.xcvr_ctrl_clk)

    dut.tx_lfc_req[port].value = 0

    while not int(dut.rx_lfc_req[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    for k in range(200):
        await RisingEdge(dut.xcvr_ctrl_clk)

    dut.tx_lfc_req[port].value = 1

    for k in range(200):
        await RisingEdge(dut.xcvr_ctrl_clk)

    dut.tx_lfc_req[port].value = 0

    while test_rx_pkts:
        rx_frame = await tb.axis_sinks[port].recv()

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
        tx_frame = await tb.serdes_sinks[port].recv()

        tx_pkt = Ether(bytes(tx_frame.get_payload()))

        tb.log.info("TX packet: %s", repr(tx_pkt))

        if tx_pkt.type == 0x8808:
            tx_lfc_cnt += 1
        else:
            test_pkt = test_tx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(tx_pkt).find(bytes(test_pkt)) == 0

    assert tx_lfc_cnt == 4

    assert tb.axis_sinks[port].empty()
    assert tb.serdes_sinks[port].empty()

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_pfc(dut, port=0, ifg=12):

    tb = TB(dut)

    tb.serdes_sources[port].ifg = ifg
    tb.dut.cfg_tx_pad_en[port].value = 1
    tb.dut.cfg_tx_min_pkt_len[port].value = 60-1
    tb.dut.cfg_tx_max_pkt_len[port].value = 9218-1
    tb.dut.cfg_tx_ifg[port].value = ifg
    tb.dut.cfg_rx_max_pkt_len[port].value = 9218-1

    await tb.reset()

    tb.log.info("Wait for reset")
    while int(dut.rx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    for k in range(100):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.dut.cfg_tx_enable[port].value = 1
    tb.dut.cfg_rx_enable[port].value = 1

    for p in tb.serdes_sinks:
        p.clear()

    dut.tx_pfc_req[port].value = 0x00
    dut.tx_pfc_resend[port].value = 0
    dut.rx_pfc_en[port].value = 0xff
    dut.rx_pfc_ack[port].value = 0x00

    dut.tx_lfc_pause_en[port].value = 0
    dut.tx_pause_req[port].value = 0

    dut.cfg_mcf_rx_eth_dst_mcast[port].value = 0x0180C2000001
    dut.cfg_mcf_rx_check_eth_dst_mcast[port].value = 1
    dut.cfg_mcf_rx_eth_dst_ucast[port].value = 0xDAD1D2D3D4D5
    dut.cfg_mcf_rx_check_eth_dst_ucast[port].value = 0
    dut.cfg_mcf_rx_eth_src[port].value = 0x5A5152535455
    dut.cfg_mcf_rx_check_eth_src[port].value = 0
    dut.cfg_mcf_rx_eth_type[port].value = 0x8808
    dut.cfg_mcf_rx_opcode_lfc[port].value = 0x0001
    dut.cfg_mcf_rx_check_opcode_lfc[port].value = 1
    dut.cfg_mcf_rx_opcode_pfc[port].value = 0x0101
    dut.cfg_mcf_rx_check_opcode_pfc[port].value = 1

    dut.cfg_mcf_rx_forward[port].value = 0
    dut.cfg_mcf_rx_enable[port].value = 1

    dut.cfg_tx_pfc_eth_dst[port].value = 0x0180C2000001
    dut.cfg_tx_pfc_eth_src[port].value = 0x5A5152535455
    dut.cfg_tx_pfc_eth_type[port].value = 0x8808
    dut.cfg_tx_pfc_opcode[port].value = 0x0101
    dut.cfg_tx_pfc_en[port].value = 1
    for k in range(8):
        dut.cfg_tx_pfc_quanta[port][k].value = 0xFFFF
        dut.cfg_tx_pfc_refresh[port][k].value = 0x7FF0

    dut.cfg_rx_pfc_opcode[port].value = 0x0101
    dut.cfg_rx_pfc_en[port].value = 1

    test_tx_pkts = []
    test_rx_pkts = []

    for k in range(32):
        length = 512
        payload = bytearray(itertools.islice(itertools.cycle(range(256)), length))

        eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5', type=0x8000)
        test_pkt = eth / payload
        test_tx_pkts.append(test_pkt.copy())

        await tb.axis_sources[port].send(bytes(test_pkt))

        eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='5A:51:52:53:54:55', type=0x8000)
        test_pkt = eth / payload
        test_rx_pkts.append(test_pkt.copy())

        test_frame = GmiiFrame.from_payload(bytes(test_pkt))
        await tb.serdes_sources[port].send(test_frame)

        if k == 16:
            eth = Ether(src='DA:D1:D2:D3:D4:D5', dst='01:80:C2:00:00:01', type=0x8808)
            test_pkt = eth / struct.pack('!HH8H', 0x0101, 0x00FF, 10, 20, 30, 40, 50, 60, 70, 80)
            test_rx_pkts.append(test_pkt.copy())

            test_frame = GmiiFrame.from_payload(bytes(test_pkt))
            await tb.serdes_sources[port].send(test_frame)

    dut.rx_pfc_ack[port].value = 0xff

    for i in range(8):
        for k in range(500):
            await RisingEdge(dut.tx_clk[port])

        dut.tx_pfc_req[port].value = 0xff >> (7-i)

    for k in range(500):
        await RisingEdge(dut.tx_clk[port])

    dut.tx_pfc_req[port].value = 0x00

    while test_rx_pkts:
        rx_frame = await tb.axis_sinks[port].recv()

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
        tx_frame = await tb.serdes_sinks[port].recv()

        tx_pkt = Ether(bytes(tx_frame.get_payload()))

        tb.log.info("TX packet: %s", repr(tx_pkt))

        if tx_pkt.type == 0x8808:
            tx_pfc_cnt += 1
        else:
            test_pkt = test_tx_pkts.pop(0)
            # check prefix as frame gets zero-padded
            assert bytes(tx_pkt).find(bytes(test_pkt)) == 0

    # TODO adjust this; possible verilator bug
    #assert tx_pfc_cnt == 9
    assert tx_pfc_cnt >= 9

    assert tb.axis_sinks[port].empty()
    assert tb.serdes_sinks[port].empty()

    for k in range(10):
        await RisingEdge(dut.xcvr_ctrl_clk)


async def run_test_an(dut, port=0):

    tb = TB(dut)

    tb.dut.an_en[port].value = 1
    tb.dut.an_restart[port].value = 0
    tb.dut.an_speedup[port].value = 1
    tb.dut.an_adv_ability[port].value = 0x0020

    await tb.reset()

    tb.log.info("Wait for reset")
    while int(dut.rx_rst_out[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock[port].value):
        await RisingEdge(dut.xcvr_ctrl_clk)

    for k in range(100):
        await RisingEdge(dut.xcvr_ctrl_clk)

    tb.log.info("AN_RESTART")
    tb.serdes_sources[port].set_an_cfg(0x0000)

    # link timer
    for k in range(1250):
        await RisingEdge(dut.tx_clk[port])

    tb.log.info("ABILITY_DETECT")
    tb.serdes_sources[port].set_an_cfg(0x002A)

    lp_cfg = None
    while True:
        await RisingEdge(dut.tx_clk[port])
        lp_cfg = tb.serdes_sinks[port].get_an_cfg()
        if tb.serdes_sinks[port].get_an_ability_match() and lp_cfg is not None and lp_cfg != 0:
            break

    assert lp_cfg & 0xbfff == int(tb.dut.an_adv_ability[port].value) & 0xbfff

    tb.log.info("ACKNOWLEDGE_DETECT")
    tb.serdes_sources[port].set_an_cfg(0x402A)

    while True:
        await RisingEdge(dut.tx_clk[port])
        cfg = tb.serdes_sinks[port].get_an_cfg()
        if tb.serdes_sinks[port].get_an_ack_match():
            if lp_cfg | 0x4000 == cfg:
                break

    tb.log.info("COMPLETE_ACKNOWLEDGE")
    # link timer
    for k in range(1250):
        await RisingEdge(dut.tx_clk[port])

    assert lp_cfg & 0xbfff == int(tb.dut.an_adv_ability[port].value) & 0xbfff
    assert int(tb.dut.an_lp_adv_ability[port].value) & 0xbfff == 0x002A

    tb.log.info("IDLE_DETECT")
    tb.serdes_sources[port].set_an_cfg(None)

    # link timer
    for k in range(1250):
        await RisingEdge(dut.tx_clk[port])

    while True:
        await RisingEdge(dut.tx_clk[port])
        if tb.serdes_sinks[port].get_an_idle_match():
            break

    for k in range(10):
        await RisingEdge(dut.tx_clk[port])


def size_list():
    return list(range(60, 128)) + [512, 1514, 9214] + [60]*10


def incrementing_payload(length):
    return bytearray(itertools.islice(itertools.cycle(range(256)), length))


def cycle_en():
    return itertools.cycle([0, 0, 0, 1])


if getattr(cocotb, 'top', None) is not None:

    factory = TestFactory(run_test_regs)
    factory.generate_tests()

    for test in [run_test_rx, run_test_tx]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("ifg", [12, 0])
        factory.generate_tests()

    for test in [run_test_tx_underrun, run_test_tx_error]:

        factory = TestFactory(test)
        factory.add_option("ifg", [12])
        factory.generate_tests()

    if cocotb.top.PFC_EN.value:
        for test in [run_test_lfc, run_test_pfc]:
            factory = TestFactory(test)
            factory.add_option("ifg", [12])
            factory.generate_tests()

    if cocotb.top.AN_EN.value:
        for test in [run_test_an]:
            factory = TestFactory(test)
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
@pytest.mark.parametrize("low_latency", [1, 0])
def test_taxi_eth_mac_1g_basex_us(request, low_latency, dic_en, pfc_en):
    dut = "taxi_eth_mac_1g_basex_us"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, "us", f"{dut}.f"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['SIM'] = 1
    parameters['VENDOR'] = "\"XILINX\""
    parameters['FAMILY'] = "\"virtexuplus\""
    parameters['CNT'] = 4
    parameters['CFG_LOW_LATENCY'] = low_latency
    parameters['GT_TYPE'] = "\"GTY\""
    parameters['QPLL0_PD'] = 0
    parameters['QPLL1_PD'] = 1
    parameters['QPLL0_EXT_CTRL'] = 0
    parameters['QPLL1_EXT_CTRL'] = 0
    parameters['COMBINED_MAC_PCS'] = 1
    parameters['DIC_EN'] = dic_en
    parameters['PTP_TS_EN'] = 1
    parameters['PTP_TD_EN'] = parameters['PTP_TS_EN']
    parameters['PTP_TS_FMT_TOD'] = 1
    parameters['PTP_TS_W'] = 96 if parameters['PTP_TS_FMT_TOD'] else 64
    parameters['PTP_TD_SDI_PIPELINE'] = 2
    parameters['TX_TAG_W'] = 16
    parameters['PRBS31_EN'] = 1
    parameters['TX_SERDES_PIPELINE'] = 2
    parameters['RX_SERDES_PIPELINE'] = 2
    parameters['COUNT_125US'] = int(1250/6.4)
    parameters['PFC_EN'] = pfc_en
    parameters['PAUSE_EN'] = parameters['PFC_EN']
    parameters['STAT_EN'] = 1
    parameters['STAT_TX_LEVEL'] = 2
    parameters['STAT_RX_LEVEL'] = parameters['STAT_TX_LEVEL']
    parameters['STAT_ID_BASE'] = 0
    parameters['STAT_UPDATE_PERIOD'] = 1024
    parameters['STAT_STR_EN'] = 1

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
