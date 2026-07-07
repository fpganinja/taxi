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
from cocotb.triggers import RisingEdge, Timer
from cocotb.regression import TestFactory

from cocotbext.eth import GmiiSource, GmiiSink, GmiiFrame

try:
    from basex import BaseXSerdesSource, BaseXSerdesSink
except ImportError:
    # attempt import from current directory
    sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
    try:
        from basex import BaseXSerdesSource, BaseXSerdesSink
    finally:
        del sys.path[0]


class TB:
    def __init__(self, dut, gbx_cfg=None):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        if len(dut.gmii_txd) == 16:
            self.clk_period = 16
        else:
            self.clk_period = 8

        cocotb.start_soon(Clock(dut.tx_clk, self.clk_period, units="ns").start())
        cocotb.start_soon(Clock(dut.rx_clk, self.clk_period, units="ns").start())

        self.gmii_source = GmiiSource(dut.gmii_txd, dut.gmii_tx_er, dut.gmii_tx_en,
            dut.tx_clk, dut.tx_rst)
        self.gmii_sink = GmiiSink(dut.gmii_rxd, dut.gmii_rx_er, dut.gmii_rx_dv,
            dut.rx_clk, dut.rx_rst)

        self.serdes_source = BaseXSerdesSource(
            data=dut.serdes_rx_data,
            data_k=dut.serdes_rx_data_k,
            data_valid=dut.serdes_rx_data_valid,
            clock=dut.rx_clk,
            enc_8b10b=False,
            gbx_cfg=gbx_cfg
        )
        self.serdes_sink = BaseXSerdesSink(
            data=dut.serdes_tx_data,
            data_k=dut.serdes_tx_data_k,
            data_valid=dut.serdes_tx_data_valid,
            gbx_req_sync=dut.serdes_tx_gbx_req_sync,
            gbx_req_stall=dut.serdes_tx_gbx_req_stall,
            gbx_sync=dut.serdes_tx_gbx_sync,
            clock=dut.tx_clk,
            dec_8b10b=False,
            gbx_cfg=gbx_cfg
        )

        dut.an_en.setimmediatevalue(0)
        dut.an_restart.setimmediatevalue(0)
        dut.an_speedup.setimmediatevalue(1)
        dut.an_timeout_en.setimmediatevalue(1)
        dut.an_sgmii_en.setimmediatevalue(0)
        dut.an_sgmii_auto.setimmediatevalue(1)
        dut.an_adv_ability_basex.setimmediatevalue(0x0020)
        dut.an_adv_ability_sgmii.setimmediatevalue(0x0001)

        dut.cfg_tx_prbs31_enable.setimmediatevalue(0)
        dut.cfg_rx_prbs31_enable.setimmediatevalue(0)

    async def reset(self):
        self.dut.tx_rst.setimmediatevalue(0)
        self.dut.rx_rst.setimmediatevalue(0)
        await RisingEdge(self.dut.tx_clk)
        await RisingEdge(self.dut.tx_clk)
        self.dut.tx_rst.value = 1
        self.dut.rx_rst.value = 1
        await RisingEdge(self.dut.tx_clk)
        await RisingEdge(self.dut.tx_clk)
        self.dut.tx_rst.value = 0
        self.dut.rx_rst.value = 0
        await RisingEdge(self.dut.tx_clk)
        await RisingEdge(self.dut.tx_clk)


async def run_test_rx(dut, payload_lengths=None, payload_data=None, ifg=12):

    tb = TB(dut)

    tb.gmii_source.ifg = ifg
    tb.serdes_source.ifg = ifg

    await tb.reset()

    tb.log.info("Wait for block lock")
    while not int(dut.rx_block_lock.value):
        await RisingEdge(dut.rx_clk)

    # clear out sink buffer
    tb.gmii_sink.clear()

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data)
        await tb.serdes_source.send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.gmii_sink.recv()

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()

    assert tb.gmii_sink.empty()

    await RisingEdge(dut.rx_clk)
    await RisingEdge(dut.rx_clk)


async def run_test_tx(dut, payload_lengths=None, payload_data=None, ifg=12):

    tb = TB(dut)

    tb.gmii_source.ifg = ifg
    tb.serdes_source.ifg = ifg

    await tb.reset()

    test_frames = [payload_data(x) for x in payload_lengths()]

    for test_data in test_frames:
        test_frame = GmiiFrame.from_payload(test_data)
        await tb.gmii_source.send(test_frame)

    for test_data in test_frames:
        rx_frame = await tb.serdes_sink.recv()

        assert rx_frame.get_payload() == test_data
        assert rx_frame.check_fcs()

    assert tb.serdes_sink.empty()

    await RisingEdge(dut.tx_clk)
    await RisingEdge(dut.tx_clk)


async def run_basex_an(tb, cfg, sgmii=False):
    # link timer scaled by 1000x for faster simulation
    link_timer = Timer(10, 'us')

    if sgmii:
        link_timer = Timer(1.6, 'us')

    dut = tb.dut

    for k in range(10):
        tb.log.info("AN_RESTART")
        tb.serdes_source.set_an_cfg(0x0000)

        await link_timer

        tb.log.info("ABILITY_DETECT")
        tb.serdes_source.set_an_cfg(cfg & ~0x4000)
        tb.serdes_sink.get_an_cfg()

        lp_cfg = None
        while True:
            await RisingEdge(dut.tx_clk)
            lp_cfg = tb.serdes_sink.get_an_cfg()
            if tb.serdes_sink.get_an_ability_match() and lp_cfg is not None and lp_cfg != 0:
                break

        tb.log.info("ACKNOWLEDGE_DETECT")
        tb.serdes_source.set_an_cfg(cfg | 0x4000)
        tb.serdes_sink.get_an_cfg()

        lp_cfg_ack = None
        while True:
            await RisingEdge(dut.tx_clk)
            lp_cfg_ack = tb.serdes_sink.get_an_cfg()
            if tb.serdes_sink.get_an_ack_match() and lp_cfg_ack is not None:
                break
            elif tb.serdes_sink.get_an_ability_match() and lp_cfg_ack is not None and lp_cfg_ack == 0:
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
        tb.serdes_source.set_an_cfg(None)

        await link_timer

        while True:
            await RisingEdge(dut.tx_clk)
            lp_cfg_ack2 = tb.serdes_sink.get_an_cfg()
            if tb.serdes_sink.get_an_idle_match():
                break
            elif tb.serdes_sink.get_an_ability_match() and lp_cfg_ack2 is not None and (lp_cfg_ack2 == 0 or lp_cfg_ack != lp_cfg_ack2):
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
    tb.serdes_source.set_an_cfg(None)
    return None


async def run_test_an(dut, sgmii_en=False, sgmii_auto=False):

    tb = TB(dut)

    dut.an_en.value = 1
    dut.an_restart.value = 0
    dut.an_speedup.value = 1
    dut.an_timeout_en.value = 1
    dut.an_sgmii_en.value = sgmii_en
    dut.an_sgmii_auto.value = sgmii_auto
    dut.an_adv_ability_basex.value = 0x0020
    dut.an_adv_ability_sgmii.value = 0x0001

    await tb.reset()

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    tb.log.info("Link partner is 1000BASE-X")

    if not sgmii_en:
        for x in range(16):
            cfg1 = 0x000A | ((x & 3) << 5) | ((x & 3) << 7) | ((x & 3) << 12)
            cfg2 = 0x000C | (((x >> 2) & 3) << 5) | (((x >> 2) & 3) << 7) | (((x >> 2) & 3) << 12)
            dut.an_adv_ability_basex.value = cfg2

            lp_cfg = await run_basex_an(tb, cfg1, False)

            for k in range(2000):
                if not dut.an_running.value:
                    break
                await RisingEdge(dut.tx_clk)

            assert lp_cfg == cfg2 | 0x4000
            assert not int(dut.an_running.value)
            assert int(dut.an_complete.value)
            assert not int(dut.an_timeout.value)
            assert not int(dut.an_sgmii_mode.value)
            assert int(dut.an_lp_adv_ability.value) == cfg1 | 0x4000
            assert int(dut.an_lp_remote_fault.value) == (cfg1 >> 12) & 0x3
            assert bool(dut.an_res_full_duplex.value) == ((((cfg1 & cfg2) >> 5) & 0x3) != 0x2)
            if ((cfg1 & cfg2) >> 7) & 0x1 == 0x1:
                # both ends support symmetric pause
                assert bool(dut.an_res_tx_pause.value)
                assert bool(dut.an_res_rx_pause.value)
            elif ((cfg1 >> 7) & 3) == 2 and ((cfg2 >> 7) & 3) == 3:
                # asymmetric towards local
                assert not bool(dut.an_res_tx_pause.value)
                assert bool(dut.an_res_rx_pause.value)
            elif ((cfg1 >> 7) & 3) == 3 and ((cfg2 >> 7) & 3) == 2:
                # asymmetric towards partner
                assert bool(dut.an_res_tx_pause.value)
                assert not bool(dut.an_res_rx_pause.value)
            else:
                assert not bool(dut.an_res_tx_pause.value)
                assert not bool(dut.an_res_rx_pause.value)
    else:
        lp_cfg = await run_basex_an(tb, 0x002A, False)

        for k in range(2000):
            if not dut.an_running.value:
                break
            await RisingEdge(dut.tx_clk)

        assert lp_cfg is None

    for k in range(100):
        await RisingEdge(dut.tx_clk)

    tb.log.info("Link partner is SGMII")

    if sgmii_en or sgmii_auto:
        for x in range(4):
            cfg1 = 0x0001 | (x << 10) | ((x & 1) << 12) | ((x & 2) << 14)
            cfg2 = cfg1
            dut.an_adv_ability_sgmii.value = cfg2

            lp_cfg = await run_basex_an(tb, cfg1, True)

            for k in range(2000):
                if not dut.an_running.value:
                    break
                await RisingEdge(dut.tx_clk)

            assert lp_cfg == cfg2 | 0x4000
            assert not int(dut.an_running.value)
            assert int(dut.an_complete.value)
            assert not int(dut.an_timeout.value)
            assert int(dut.an_sgmii_mode.value)
            assert int(dut.an_lp_adv_ability.value) == cfg1 | 0x4000
            assert bool(dut.an_lp_sgmii_link.value) == bool((cfg1 >> 15) & 1)
            assert int(dut.an_lp_sgmii_speed.value) == (cfg1 >> 10) & 0x3
            assert bool(dut.an_res_full_duplex.value) == bool((cfg1 >> 12) & 1)
    else:
        lp_cfg = await run_basex_an(tb, 0x9801, True)

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

    for test in [run_test_rx, run_test_tx]:

        factory = TestFactory(test)
        factory.add_option("payload_lengths", [size_list])
        factory.add_option("payload_data", [incrementing_payload])
        factory.add_option("ifg", [12])
        factory.generate_tests()

    if cocotb.top.AN_EN.value:
        for test in [run_test_an]:
            factory = TestFactory(test)
            factory.add_option(("sgmii_en", "sgmii_auto"),
                [(False, False), (True, False), (False, True)])
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
def test_taxi_eth_phy_1g_basex(request, data_w):
    dut = "taxi_eth_phy_1g_basex"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.f"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['DATA_W'] = data_w
    parameters['CTRL_W'] = parameters['DATA_W'] // 8
    parameters['TX_GBX_IF_EN'] = 0
    parameters['RX_GBX_IF_EN'] = parameters['TX_GBX_IF_EN']
    parameters['SGMII_EN'] = "1'b1"
    parameters['AN_EN'] = parameters['SGMII_EN']
    parameters['BIT_REVERSE'] = "1'b0"
    parameters['ENC_8B10B_EN'] = "1'b0"
    parameters['DEC_8B10B_EN'] = parameters['ENC_8B10B_EN']
    parameters['PRBS31_EN'] = "1'b1"
    parameters['TX_SERDES_PIPELINE'] = 2
    parameters['RX_SERDES_PIPELINE'] = 2
    parameters['COUNT_125US'] = int(1250/6.4)

    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}

    extra_env['COCOTB_RESOLVE_X'] = 'RANDOM'

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
