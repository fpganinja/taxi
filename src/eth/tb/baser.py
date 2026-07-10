#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2021-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import logging

import cocotb
from cocotb.queue import Queue, QueueFull
from cocotb.triggers import RisingEdge, Timer, First, Event
from cocotb.utils import get_sim_time

from cocotbext.eth.constants import (EthPre, XgmiiCtrl, BaseRCtrl, BaseRO,
    BaseRSync, BaseRBlockType, xgmii_ctrl_to_baser_mapping,
    baser_ctrl_to_xgmii_mapping, block_type_term_lane_mapping)
from cocotbext.eth import XgmiiFrame


class BaseRSerdesSource():

    def __init__(self, data, hdr, clock, enable=None, slip=None, data_valid=None, hdr_valid=None,
            gbx_sync=None, scramble=True, reverse=False, gbx_cfg=None, *args, **kwargs):

        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.data = data
        self.hdr = hdr
        self.clock = clock
        self.enable = enable
        self.slip = slip
        self.data_valid = data_valid
        self.hdr_valid = hdr_valid
        self.gbx_sync = gbx_sync
        self.scramble = scramble
        self.reverse = reverse

        self.log.info("BASE-R serdes source")
        self.log.info("Copyright (c) 2021-2025 FPGA Ninja, LLC")
        self.log.info("https://github.com/fpganinja/taxi")

        super().__init__(*args, **kwargs)

        self.active = False
        self.queue = Queue()
        self.dequeue_event = Event()
        self.current_frame = None
        self.idle_event = Event()
        self.idle_event.set()

        self.enable_dic = True
        self.ifg = 12
        self.force_offset_start = False

        self.bit_offset = 0

        self.gbx_seq = 0
        self.gbx_seq_len = None
        self.gbx_seq_stall = None
        self.gbx_in_bits = 66
        self.gbx_out_bits = 66
        self.gbx_bit_cnt = 0

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        self.queue_occupancy_limit_bytes = -1
        self.queue_occupancy_limit_frames = -1

        self.xgmii_rep_count = 0

        self.os = None
        self.os_sig = False

        self.width = len(self.data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.pack_seq = 0
        self.pack_cnt = 8 // self.byte_lanes
        self.data_mask = (2**self.width)-1

        assert self.byte_lanes in [1, 2, 4, 8]
        assert self.width == self.byte_lanes * self.byte_size

        self.log.info("BASE-R serdes source model configuration")
        self.log.info("  Byte size: %d bits", self.byte_size)
        self.log.info("  Data width: %d bits (%d bytes)", self.width, self.byte_lanes)
        self.log.info("  Enable scrambler: %s", self.scramble)
        self.log.info("  Bit reverse: %s", self.reverse)

        if gbx_cfg:
            self.set_gbx_cfg(*gbx_cfg)

        self.data.setimmediatevalue(0)
        if self.data_valid is not None:
            self.data_valid.setimmediatevalue(0)
        self.hdr.setimmediatevalue(0)
        if self.hdr_valid is not None:
            self.hdr_valid.setimmediatevalue(0)
        if self.gbx_sync is not None:
            self.gbx_sync.setimmediatevalue(0)

        self._run_cr = cocotb.start_soon(self._run())

    def set_gbx_cfg(self, seq_len=None, seq_stall=None):
        self.log.info("Set gearbox configuration")

        if seq_len is None:
            self.log.info("Gearbox disabled")
            self.gbx_bit_cnt = 0
            self.gbx_seq_len = None
            self.gbx_seq_stall = None
            self.gbx_in_bits = 66
            self.gbx_out_bits = 66
            self.gbx_seq = 0

        seq_stall = sorted(list(set(seq_stall)))

        for x in seq_stall:
            assert 0 <= x < seq_len

        self.log.info("  Sequence length: %d cycles", seq_len)
        self.log.info("  Stall cycles: %s", seq_stall)

        out_bits = 66
        in_cycles = seq_len
        out_cycles = in_cycles - len(seq_stall)
        in_bits = (out_bits * out_cycles) // in_cycles

        self.log.info("  Input: %d bits (%d cycles)", in_bits, in_cycles)
        self.log.info("  Output: %d bits (%d cycles)", out_bits, out_cycles)
        self.log.info("  Gearbox ratio: %d:%d", in_bits, out_bits)

        assert in_cycles*in_bits == out_cycles*out_bits

        self.gbx_seq = 0
        self.gbx_seq_len = seq_len
        self.gbx_seq_stall = set(seq_stall)
        self.gbx_in_bits = in_bits
        self.gbx_out_bits = out_bits
        self.gbx_bit_cnt = 0

        for k in range(self.gbx_seq_len):
            self.gbx_bit_cnt += in_bits
            if k in self.gbx_seq_stall:
                continue
            self.gbx_bit_cnt = max(self.gbx_bit_cnt - out_bits, 0)

    async def send(self, frame):
        while self.full():
            self.dequeue_event.clear()
            await self.dequeue_event.wait()
        frame = XgmiiFrame(frame)
        await self.queue.put(frame)
        self.idle_event.clear()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def send_nowait(self, frame):
        if self.full():
            raise QueueFull()
        frame = XgmiiFrame(frame)
        self.queue.put_nowait(frame)
        self.idle_event.clear()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def count(self):
        return self.queue.qsize()

    def empty(self):
        return self.queue.empty()

    def full(self):
        if self.queue_occupancy_limit_bytes > 0 and self.queue_occupancy_bytes > self.queue_occupancy_limit_bytes:
            return True
        elif self.queue_occupancy_limit_frames > 0 and self.queue_occupancy_frames > self.queue_occupancy_limit_frames:
            return True
        else:
            return False

    def idle(self):
        return self.empty() and not self.active

    def clear(self):
        while not self.queue.empty():
            frame = self.queue.get_nowait()
            frame.sim_time_end = None
            frame.handle_tx_complete()
        self.dequeue_event.set()
        self.idle_event.set()
        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0
        self.os = None
        self.os_sig = False

    async def wait(self):
        await self.idle_event.wait()

    def set_xgmii_rep_count(self, rep=0):
        self.xgmii_rep_count = int(rep)

    def get_xgmii_rep_count(self):
        return self.xgmii_rep_count

    def set_seq_os(self, os=None):
        self.set_os(os, False)

    def set_sig_os(self, os=None):
        self.set_os(os, True)

    def set_os(self, os=None, sig=False):
        self.os = os
        self.os_sig = sig

    async def _run(self):
        frame = None
        frame_offset = 0
        sof = False
        in_pre = False
        ifg_cnt = 0
        deficit_idle_cnt = 0
        scrambler_state = 0
        last_d = 0
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        clk_period = 0
        last_clk = 0
        gbx_delay = 0

        data = 0
        hdr = 0

        rep_cnt = 0

        while True:
            await clock_edge_event

            sim_time = get_sim_time()
            if last_clk:
                clk_period = sim_time - last_clk
            last_clk = sim_time

            # clock enable
            if self.enable is not None and not self.enable.value:
                continue

            # gearbox sequence
            if self.gbx_seq_len:
                self.gbx_seq = (self.gbx_seq + 1) % self.gbx_seq_len

                if self.gbx_sync is not None:
                    self.gbx_sync.value = (self.gbx_seq == 0)

                self.gbx_bit_cnt += self.gbx_in_bits

                # stall cycle
                if self.gbx_seq in self.gbx_seq_stall:
                    self.data.value = 0
                    if self.data_valid is not None:
                        self.data_valid.value = 0
                    self.hdr.value = 0
                    if self.hdr_valid is not None:
                        self.hdr_valid.value = 0
                    continue

                self.gbx_bit_cnt = max(self.gbx_bit_cnt - self.gbx_out_bits, 0)
                gbx_delay = (self.gbx_bit_cnt * clk_period) // self.gbx_in_bits
            else:
                self.gbx_seq = 0
                self.gbx_bit_cnt = 0
                gbx_delay = 0

                if self.gbx_sync is not None:
                    self.gbx_sync.value = 0

            if self.pack_seq:
                # output data
                data_out = data >> (self.width*(self.pack_cnt-self.pack_seq))
                self.pack_seq = self.pack_seq-1

                if self.reverse:
                    # bit reverse
                    data_out = sum(1 << (self.width-1-i) for i in range(self.width) if (data_out >> i) & 1)

                self.data.value = data_out & self.data_mask
                if self.data_valid is not None:
                    self.data_valid.value = 1
                self.hdr.value = 0
                if self.hdr_valid is not None:
                    self.hdr_valid.value = 0

                continue

            if ifg_cnt + deficit_idle_cnt > 8-1 or (not self.enable_dic and ifg_cnt > 4) or rep_cnt != 0:
                # in IFG
                ifg_cnt = ifg_cnt - 8
                if ifg_cnt < 0:
                    if self.enable_dic:
                        deficit_idle_cnt = max(deficit_idle_cnt+ifg_cnt, 0)
                    ifg_cnt = 0

            elif frame is None:
                # idle
                if not self.queue.empty():
                    # send frame
                    frame = self.queue.get_nowait()
                    self.dequeue_event.set()
                    self.queue_occupancy_bytes -= len(frame)
                    self.queue_occupancy_frames -= 1
                    self.current_frame = frame
                    frame.sim_time_start = sim_time - gbx_delay
                    frame.sim_time_sfd = None
                    frame.sim_time_end = None
                    self.log.info("TX frame: %s", frame)
                    frame.normalize()
                    frame.start_lane = 0
                    assert frame.data[0] == EthPre.PRE
                    assert frame.ctrl[0] == 0
                    frame.data[0] = XgmiiCtrl.START
                    frame.ctrl[0] = 1
                    frame.data.append(XgmiiCtrl.TERM)
                    frame.ctrl.append(1)

                    # offset start
                    if self.enable_dic:
                        min_ifg = 3 - deficit_idle_cnt
                    else:
                        min_ifg = 0

                    if ifg_cnt > min_ifg or self.force_offset_start:
                        ifg_cnt = ifg_cnt-4
                        frame.start_lane = 4
                        frame.sim_time_start = sim_time + (clk_period // self.byte_lanes * 4) - gbx_delay
                        frame.data = bytearray([XgmiiCtrl.IDLE]*4)+frame.data
                        frame.ctrl = [1]*4+frame.ctrl

                    if self.enable_dic:
                        deficit_idle_cnt = max(deficit_idle_cnt+ifg_cnt, 0)
                    ifg_cnt = 0
                    self.active = True
                    frame_offset = -1
                    sof = True
                    in_pre = True
                else:
                    # clear counters
                    deficit_idle_cnt = 0
                    ifg_cnt = 0
                    self.active = False
                    self.idle_event.set()

            dl = bytearray()
            cl = []

            for k in range(8):
                if frame is not None:
                    frame_offset += 1
                    if rep_cnt == 0:
                        pass
                    elif k == 0 or k == 4:
                        frame_offset = max(0, frame_offset-4)
                    d = frame.data[frame_offset]
                    c = frame.ctrl[frame_offset]
                    if frame.sim_time_sfd is None and not in_pre:
                        frame.sim_time_sfd = sim_time + (clk_period // self.byte_lanes * k) - gbx_delay
                    if d == EthPre.SFD:
                        in_pre = False
                    if c and d == XgmiiCtrl.START:
                        if sof:
                            sof = False
                        else:
                            d = 0xAA
                            c = 0
                    dl.append(d)
                    cl.append(c)

                    if frame_offset >= len(frame.data)-1:
                        ifg_cnt = max(self.ifg - (8-k), 0)
                        frame.sim_time_end = sim_time + (clk_period // self.byte_lanes * k) - gbx_delay
                        frame.handle_tx_complete()
                        frame = None
                        self.current_frame = None
                else:
                    dl.append(XgmiiCtrl.IDLE)
                    cl.append(1)

                if k == 3 or k == 7:
                    if rep_cnt > 0:
                        rep_cnt -= 1
                    elif self.xgmii_rep_count:
                        rep_cnt = self.xgmii_rep_count

            # replace idles with ordered sets
            if self.os is not None:
                for k in [0, 4]:
                    if all(cl[k:k+4]) and all(d == XgmiiCtrl.IDLE for d in dl[k:k+4]):
                        if self.os_sig:
                            self.log.info("TX signal ordered set: 0x%06x", self.os)
                            dl[k] = XgmiiCtrl.SIG_OS
                        else:
                            self.log.info("TX sequence ordered set: 0x%06x", self.os)
                            dl[k] = XgmiiCtrl.SEQ_OS
                        dl[k+1:k+4] = self.os.to_bytes(3, 'big')
                        cl[k+1:k+4] = [0, 0, 0]

            # remap control characters
            ctrl = sum(xgmii_ctrl_to_baser_mapping.get(d, BaseRCtrl.ERROR) << i*7 for i, d in enumerate(dl))

            if not any(cl):
                # data
                hdr = BaseRSync.DATA
                data = int.from_bytes(dl, 'little')
            else:
                # control
                hdr = BaseRSync.CTRL
                if cl[0] and dl[0] == XgmiiCtrl.START and not any(cl[1:]):
                    # start in lane 0
                    data = BaseRBlockType.START_0
                    for i in range(1, 8):
                        data |= dl[i] << i*8
                elif cl[4] and dl[4] == XgmiiCtrl.START and not any(cl[5:]):
                    # start in lane 4
                    if cl[0] and (dl[0] == XgmiiCtrl.SEQ_OS or dl[0] == XgmiiCtrl.SIG_OS) and not any(cl[1:4]):
                        # ordered set in lane 0
                        data = BaseRBlockType.OS_START
                        for i in range(1, 4):
                            data |= dl[i] << i*8
                        if dl[0] == XgmiiCtrl.SIG_OS:
                            # signal ordered set
                            data |= BaseRO.SIG_OS << 32
                    else:
                        # other control
                        data = BaseRBlockType.START_4 | (ctrl & 0xfffffff) << 8

                    for i in range(5, 8):
                        data |= dl[i] << i*8
                elif cl[0] and (dl[0] == XgmiiCtrl.SEQ_OS or dl[0] == XgmiiCtrl.SIG_OS) and not any(cl[1:4]):
                    # ordered set in lane 0
                    if cl[4] and (dl[4] == XgmiiCtrl.SEQ_OS or dl[4] == XgmiiCtrl.SIG_OS) and not any(cl[5:8]):
                        # ordered set in lane 4
                        data = BaseRBlockType.OS_04
                        for i in range(5, 8):
                            data |= dl[i] << i*8
                        if dl[4] == XgmiiCtrl.SIG_OS:
                            # signal ordered set
                            data |= BaseRO.SIG_OS << 36
                    else:
                        data = BaseRBlockType.OS_0 | (ctrl & 0xfffffff) << 40
                    for i in range(1, 4):
                        data |= dl[i] << i*8
                    if dl[0] == XgmiiCtrl.SIG_OS:
                        # signal ordered set
                        data |= BaseRO.SIG_OS << 32
                elif cl[4] and (dl[4] == XgmiiCtrl.SEQ_OS or dl[4] == XgmiiCtrl.SIG_OS) and not any(cl[5:8]):
                    # ordered set in lane 4
                    data = BaseRBlockType.OS_4 | (ctrl & 0xfffffff) << 8
                    for i in range(5, 8):
                        data |= dl[i] << i*8
                    if dl[4] == XgmiiCtrl.SIG_OS:
                        # signal ordered set
                        data |= BaseRO.SIG_OS << 36
                elif cl[0] and dl[0] == XgmiiCtrl.TERM:
                    # terminate in lane 0
                    data = BaseRBlockType.TERM_0 | (ctrl & 0xffffffffffff80) << 8
                elif cl[1] and dl[1] == XgmiiCtrl.TERM and not cl[0]:
                    # terminate in lane 1
                    data = BaseRBlockType.TERM_1 | (ctrl & 0xffffffffffc000) << 8 | dl[0] << 8
                elif cl[2] and dl[2] == XgmiiCtrl.TERM and not any(cl[0:2]):
                    # terminate in lane 2
                    data = BaseRBlockType.TERM_2 | (ctrl & 0xffffffffe00000) << 8
                    for i in range(2):
                        data |= dl[i] << ((i+1)*8)
                elif cl[3] and dl[3] == XgmiiCtrl.TERM and not any(cl[0:3]):
                    # terminate in lane 3
                    data = BaseRBlockType.TERM_3 | (ctrl & 0xfffffff0000000) << 8
                    for i in range(3):
                        data |= dl[i] << ((i+1)*8)
                elif cl[4] and dl[4] == XgmiiCtrl.TERM and not any(cl[0:4]):
                    # terminate in lane 4
                    data = BaseRBlockType.TERM_4 | (ctrl & 0xfffff800000000) << 8
                    for i in range(4):
                        data |= dl[i] << ((i+1)*8)
                elif cl[5] and dl[5] == XgmiiCtrl.TERM and not any(cl[0:5]):
                    # terminate in lane 5
                    data = BaseRBlockType.TERM_5 | (ctrl & 0xfffc0000000000) << 8
                    for i in range(5):
                        data |= dl[i] << ((i+1)*8)
                elif cl[6] and dl[6] == XgmiiCtrl.TERM and not any(cl[0:6]):
                    # terminate in lane 6
                    data = BaseRBlockType.TERM_6 | (ctrl & 0xfe000000000000) << 8
                    for i in range(6):
                        data |= dl[i] << ((i+1)*8)
                elif cl[7] and dl[7] == XgmiiCtrl.TERM and not any(cl[0:7]):
                    # terminate in lane 7
                    data = BaseRBlockType.TERM_7
                    for i in range(7):
                        data |= dl[i] << ((i+1)*8)
                else:
                    # all control
                    data = BaseRBlockType.CTRL | ctrl << 8

            if self.scramble:
                # 64b/66b scrambler
                b = 0
                for i in range(64):
                    if bool(scrambler_state & (1 << 38)) ^ bool(scrambler_state & (1 << 57)) ^ bool(data & (1 << i)):
                        scrambler_state = ((scrambler_state & 0x1ffffffffffffff) << 1) | 1
                        b = b | (1 << i)
                    else:
                        scrambler_state = (scrambler_state & 0x1ffffffffffffff) << 1
                data = b

            if self.slip is not None and self.slip.value:
                self.bit_offset += 1

            self.bit_offset = max(0, self.bit_offset) % 66

            if self.bit_offset != 0:
                d = data << 2 | hdr

                out_d = ((last_d | d << 66) >> 66-self.bit_offset) & 0x3ffffffffffffffff

                last_d = d

                data = out_d >> 2
                hdr = out_d & 3

            data_out = data
            hdr_out = hdr

            self.pack_seq = self.pack_cnt-1

            if self.reverse:
                # bit reverse
                data_out = sum(1 << (self.width-1-i) for i in range(self.width) if (data_out >> i) & 1)
                hdr_out = sum(1 << (1-i) for i in range(2) if (hdr_out >> i) & 1)

            self.data.value = data_out & self.data_mask
            if self.data_valid is not None:
                self.data_valid.value = 1
            self.hdr.value = hdr_out
            if self.hdr_valid is not None:
                self.hdr_valid.value = 1


class BaseRSerdesSink:

    def __init__(self, data, hdr, clock, enable=None, data_valid=None, hdr_valid=None,
            gbx_req_sync=None, gbx_req_stall=None, gbx_sync=None,
            scramble=True, reverse=False, gbx_cfg=None, *args, **kwargs):

        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.data = data
        self.hdr = hdr
        self.clock = clock
        self.enable = enable
        self.data_valid = data_valid
        self.hdr_valid = hdr_valid
        self.gbx_req_sync = gbx_req_sync
        self.gbx_req_stall = gbx_req_stall
        self.gbx_sync = gbx_sync
        self.scramble = scramble
        self.reverse = reverse

        self.log.info("BASE-R serdes sink")
        self.log.info("Copyright (c) 2021-2025 FPGA Ninja, LLC")
        self.log.info("https://github.com/fpganinja/taxi")

        super().__init__(*args, **kwargs)

        self.active = False
        self.queue = Queue()
        self.active_event = Event()

        self.gbx_seq = 0
        self.gbx_seq_gen = 0
        self.gbx_seq_len = None
        self.gbx_seq_stall = None
        self.gbx_in_bits = 66
        self.gbx_out_bits = 66
        self.gbx_bit_cnt = 0

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        self.xgmii_rep_count = 0

        self.os = None
        self.os_sig = False

        self.width = len(self.data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.pack_seq = 0
        self.pack_cnt = 8 // self.byte_lanes

        assert self.byte_lanes in [1, 2, 4, 8]
        assert self.width == self.byte_lanes * self.byte_size

        self.log.info("BASE-R serdes sink model configuration")
        self.log.info("  Byte size: %d bits", self.byte_size)
        self.log.info("  Data width: %d bits (%d bytes)", self.width, self.byte_lanes)
        self.log.info("  Enable scrambler: %s", self.scramble)
        self.log.info("  Bit reverse: %s", self.reverse)

        if gbx_cfg:
            self.set_gbx_cfg(*gbx_cfg)

        if self.gbx_req_sync is not None:
            self.gbx_req_sync.setimmediatevalue(0)
        if self.gbx_req_stall is not None:
            self.gbx_req_stall.setimmediatevalue(0)

        self._run_cr = cocotb.start_soon(self._run())

    def set_gbx_cfg(self, seq_len=None, seq_stall=None):
        self.log.info("Set gearbox configuration")

        if seq_len is None:
            self.log.info("Gearbox disabled")
            self.gbx_seq_len = None
            self.gbx_seq_stall = None

        seq_stall = sorted(list(set(seq_stall)))

        for x in seq_stall:
            assert 0 <= x < seq_len

        self.log.info("  Sequence length: %d cycles", seq_len)
        self.log.info("  Stall cycles: %s", seq_stall)

        in_bits = 66
        out_cycles = seq_len
        in_cycles = out_cycles - len(seq_stall)
        out_bits = (in_bits * in_cycles) // out_cycles

        self.log.info("  Input: %d bits (%d cycles)", in_bits, in_cycles)
        self.log.info("  Output: %d bits (%d cycles)", out_bits, out_cycles)
        self.log.info("  Gearbox ratio: %d:%d", in_bits, out_bits)

        assert in_cycles*in_bits == out_cycles*out_bits

        self.gbx_seq = 0
        self.gbx_seq_gen = 0
        self.gbx_seq_len = seq_len
        self.gbx_seq_stall = set(seq_stall)
        self.gbx_in_bits = in_bits
        self.gbx_out_bits = out_bits
        self.gbx_bit_cnt = 0

        for k in range(self.gbx_seq_len):
            self.gbx_bit_cnt = max(self.gbx_bit_cnt - out_bits, 0)
            if k in self.gbx_seq_stall:
                continue
            self.gbx_bit_cnt += in_bits

    def set_xgmii_rep_count(self, rep=0):
        self.xgmii_rep_count = int(rep)

    def get_xgmii_rep_count(self):
        return self.xgmii_rep_count

    def get_os(self):
        ret = (self.os, self.os_sig)
        self.os = None
        return ret

    def _recv(self, frame, compact=True):
        if self.queue.empty():
            self.active_event.clear()
        self.queue_occupancy_bytes -= len(frame)
        self.queue_occupancy_frames -= 1
        if compact:
            frame.compact()
        return frame

    async def recv(self, compact=True):
        frame = await self.queue.get()
        return self._recv(frame, compact)

    def recv_nowait(self, compact=True):
        frame = self.queue.get_nowait()
        return self._recv(frame, compact)

    def count(self):
        return self.queue.qsize()

    def empty(self):
        return self.queue.empty()

    def idle(self):
        return not self.active

    def clear(self):
        while not self.queue.empty():
            self.queue.get_nowait()
        self.active_event.clear()
        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

    async def wait(self, timeout=0, timeout_unit=None):
        if not self.empty():
            return
        if timeout:
            await First(self.active_event.wait(), Timer(timeout, timeout_unit))
        else:
            await self.active_event.wait()

    async def _run(self):
        frame = None
        scrambler_state = 0
        in_pre = False
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        clk_period = 0
        last_clk = 0
        gbx_delay = 0
        sync_bad = True

        data = 0
        hdr = 0

        skip_cnt = 0

        while True:
            await clock_edge_event

            sim_time = get_sim_time()
            if last_clk:
                clk_period = sim_time - last_clk
            last_clk = sim_time

            # clock enable
            if self.enable is not None and not self.enable.value:
                continue

            # gearbox sequence
            if self.gbx_seq_len:
                # generation
                self.gbx_seq_gen = (self.gbx_seq_gen + 1) % self.gbx_seq_len

                if self.gbx_req_sync is not None:
                    self.gbx_req_sync.value = (self.gbx_seq_gen == 0)

                # stall cycle
                if self.gbx_req_stall is not None:
                    self.gbx_req_stall.value = (self.gbx_seq_gen in self.gbx_seq_stall)

                # sync
                self.gbx_seq = (self.gbx_seq + 1) % self.gbx_seq_len

                if self.gbx_sync is not None:
                    if int(self.gbx_sync.value):
                        self.gbx_seq = 0

                self.gbx_bit_cnt = max(self.gbx_bit_cnt - self.gbx_out_bits, 0)

                if self.gbx_seq in self.gbx_seq_stall:
                    continue

                self.gbx_bit_cnt += self.gbx_in_bits
                gbx_delay = (self.gbx_bit_cnt * clk_period) // self.gbx_out_bits
            else:
                self.gbx_seq = 0
                self.gbx_seq_gen = 0
                self.gbx_bit_cnt = 0
                gbx_delay = 0

                if self.gbx_sync is not None:
                    self.gbx_sync.value = 1

            if self.data_valid is not None:
                if not int(self.data_valid.value):
                    # stall
                    if self.gbx_seq_len and not sync_bad:
                        sync_bad = True
                        self.log.warning("Data not valid outside of gearbox stall cycle")
                    continue

            sync_bad = False

            data_in = int(self.data.value)
            hdr_in = int(self.hdr.value)

            if self.reverse:
                # bit reverse
                data_in = sum(1 << (self.width-1-i) for i in range(self.width) if (data_in >> i) & 1)
                hdr_in = sum(1 << (1-i) for i in range(2) if (hdr_in >> i) & 1)

            if self.pack_cnt > 1:
                # pack input data
                if self.hdr_valid is not None:
                    if self.hdr_valid.value:
                        data = data_in
                        hdr = hdr_in
                        self.pack_seq = 1
                        continue

                data |= data_in << (self.width*self.pack_seq)
                self.pack_seq = self.pack_seq+1

                if self.pack_seq < self.pack_cnt:
                    continue

                self.pack_seq = 0
            else:
                data = data_in
                hdr = hdr_in

            if self.scramble:
                # 64b/66b descrambler
                b = 0
                for i in range(64):
                    if bool(scrambler_state & (1 << 38)) ^ bool(scrambler_state & (1 << 57)) ^ bool(data & (1 << i)):
                        b = b | (1 << i)
                    scrambler_state = (scrambler_state & 0x1ffffffffffffff) << 1 | bool(data & (1 << i))
                data = b

            # 10GBASE-R decoding

            # remap control characters
            ctrl = bytearray(baser_ctrl_to_xgmii_mapping.get((data >> i*7+8) & 0x7f, XgmiiCtrl.ERROR) for i in range(8))

            db = data.to_bytes(8, 'little')

            dl = bytearray()
            cl = []
            os = False
            if hdr == BaseRSync.DATA:
                # data
                dl = db
                cl = [0]*8
            elif hdr == BaseRSync.CTRL:
                if db[0] == BaseRBlockType.CTRL:
                    # C7 C6 C5 C4 C3 C2 C1 C0 BT
                    dl = ctrl
                    cl = [1]*8
                elif db[0] == BaseRBlockType.OS_4:
                    # D7 D6 D5 O4 C3 C2 C1 C0 BT
                    dl = ctrl[0:4]
                    cl = [1]*4
                    os = True
                    if (db[4] >> 4) & 0xf == BaseRO.SEQ_OS:
                        dl.append(XgmiiCtrl.SEQ_OS)
                    elif (db[4] >> 4) & 0xf == BaseRO.SIG_OS:
                        dl.append(XgmiiCtrl.SIG_OS)
                    else:
                        self.log.warning("Invalid O code")
                        dl.append(XgmiiCtrl.ERROR)
                    cl.append(1)
                    dl += db[5:]
                    cl += [0]*3
                elif db[0] == BaseRBlockType.START_4:
                    # D7 D6 D5    C3 C2 C1 C0 BT
                    dl = ctrl[0:4]
                    cl = [1]*4
                    dl.append(XgmiiCtrl.START)
                    cl.append(1)
                    dl += db[5:]
                    cl += [0]*3
                elif db[0] == BaseRBlockType.OS_START:
                    # D7 D6 D5    O0 D3 D2 D1 BT
                    os = True
                    if db[4] & 0xf == BaseRO.SEQ_OS:
                        dl.append(XgmiiCtrl.SEQ_OS)
                    elif db[4] & 0xf == BaseRO.SIG_OS:
                        dl.append(XgmiiCtrl.SIG_OS)
                    else:
                        self.log.warning("Invalid O code")
                        dl.append(XgmiiCtrl.ERROR)
                    cl.append(1)
                    dl += db[1:4]
                    cl += [0]*3
                    dl.append(XgmiiCtrl.START)
                    cl.append(1)
                    dl += db[5:]
                    cl += [0]*3
                elif db[0] == BaseRBlockType.OS_04:
                    # D7 D6 D5 O4 O0 D3 D2 D1 BT
                    os = True
                    if db[4] & 0xf == BaseRO.SEQ_OS:
                        dl.append(XgmiiCtrl.SEQ_OS)
                    elif db[4] & 0xf == BaseRO.SIG_OS:
                        dl.append(XgmiiCtrl.SIG_OS)
                    else:
                        self.log.warning("Invalid O code")
                        dl.append(XgmiiCtrl.ERROR)
                    cl.append(1)
                    dl += db[1:4]
                    cl += [0]*3
                    if (db[4] >> 4) & 0xf == BaseRO.SEQ_OS:
                        dl.append(XgmiiCtrl.SEQ_OS)
                    elif (db[4] >> 4) & 0xf == BaseRO.SIG_OS:
                        dl.append(XgmiiCtrl.SIG_OS)
                    else:
                        self.log.warning("Invalid O code")
                        dl.append(XgmiiCtrl.ERROR)
                    cl.append(1)
                    dl += db[5:]
                    cl += [0]*3
                elif db[0] == BaseRBlockType.START_0:
                    # D7 D6 D5 D4 D3 D2 D1    BT
                    dl.append(XgmiiCtrl.START)
                    cl.append(1)
                    dl += db[1:]
                    cl += [0]*7
                elif db[0] == BaseRBlockType.OS_0:
                    # C7 C6 C5 C4 O0 D3 D2 D1 BT
                    os = True
                    if db[4] & 0xf == BaseRO.SEQ_OS:
                        dl.append(XgmiiCtrl.SEQ_OS)
                    elif db[4] & 0xf == BaseRO.SIG_OS:
                        dl.append(XgmiiCtrl.SIG_OS)
                    else:
                        self.log.warning("Invalid O code")
                        dl.append(XgmiiCtrl.ERROR)
                    cl.append(1)
                    dl += db[1:4]
                    cl += [0]*3
                    dl += ctrl[4:]
                    cl += [1]*4
                elif db[0] in {BaseRBlockType.TERM_0, BaseRBlockType.TERM_1,
                        BaseRBlockType.TERM_2, BaseRBlockType.TERM_3, BaseRBlockType.TERM_4,
                        BaseRBlockType.TERM_5, BaseRBlockType.TERM_6, BaseRBlockType.TERM_7}:
                    # C7 C6 C5 C4 C3 C2 C1    BT
                    # C7 C6 C5 C4 C3 C2    D0 BT
                    # C7 C6 C5 C4 C3    D1 D0 BT
                    # C7 C6 C5 C4    D2 D1 D0 BT
                    # C7 C6 C5    D3 D2 D1 D0 BT
                    # C7 C6    D4 D3 D2 D1 D0 BT
                    # C7    D5 D4 D3 D2 D1 D0 BT
                    #    D6 D5 D4 D3 D2 D1 D0 BT
                    term_lane = block_type_term_lane_mapping[db[0]]
                    dl += db[1:term_lane+1]
                    cl += [0]*term_lane
                    dl.append(XgmiiCtrl.TERM)
                    cl.append(1)
                    dl += ctrl[term_lane+1:]
                    cl += [1]*(7-term_lane)
                else:
                    # invalid block type
                    self.log.warning("Invalid block type")
                    dl = [XgmiiCtrl.ERROR]*8
                    cl = [1]*8
            else:
                # invalid sync header
                self.log.warning("Invalid sync header")
                dl = [XgmiiCtrl.ERROR]*8
                cl = [1]*8

            # extract ordered sets
            if os:
                for k in [0, 4]:
                    if cl[k] and dl[k] == XgmiiCtrl.SEQ_OS:
                        self.os = int.from_bytes(db[k+1:k+4], 'big')
                        self.os_sig = False
                        self.log.info("RX sequence ordered set: 0x%06x", self.os)
                    elif cl[k] and dl[k] == XgmiiCtrl.SIG_OS:
                        self.os = int.from_bytes(db[k+1:k+4], 'big')
                        self.os_sig = True
                        self.log.info("RX signal ordered set: 0x%06x", self.os)

            for k in range(8):
                d_val = dl[k]
                c_val = cl[k]

                # USXGMII sync
                if self.xgmii_rep_count:
                    if c_val and d_val == XgmiiCtrl.START:
                        skip_cnt = 0

                # USXGMII skip
                if skip_cnt > 0:
                    if k == 3 or k == 7:
                        skip_cnt -= 1
                    continue
                elif self.xgmii_rep_count:
                    if k == 3 or k == 7:
                        skip_cnt = self.xgmii_rep_count

                if frame is None:
                    if c_val and d_val == XgmiiCtrl.START:
                        # start
                        frame = XgmiiFrame(bytearray([EthPre.PRE]), [0])
                        frame.sim_time_start = sim_time + (clk_period // self.byte_lanes * k) + gbx_delay
                        frame.start_lane = k
                        in_pre = True
                else:
                    if c_val:
                        # got a control character; terminate frame reception
                        if d_val != XgmiiCtrl.TERM:
                            # store control character if it's not a termination
                            frame.data.append(d_val)
                            frame.ctrl.append(c_val)

                        frame.compact()
                        frame.sim_time_end = sim_time + (clk_period // self.byte_lanes * k) + gbx_delay
                        self.log.info("RX frame: %s", frame)

                        self.queue_occupancy_bytes += len(frame)
                        self.queue_occupancy_frames += 1

                        self.queue.put_nowait(frame)
                        self.active_event.set()

                        frame = None
                    else:
                        if frame.sim_time_sfd is None and not in_pre:
                            frame.sim_time_sfd = sim_time + (clk_period // self.byte_lanes * k) + gbx_delay
                        if d_val == EthPre.SFD:
                            in_pre = False

                        frame.data.append(d_val)
                        frame.ctrl.append(c_val)
