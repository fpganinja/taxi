#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import logging

import cocotb
from cocotb.queue import Queue, QueueFull
from cocotb.triggers import RisingEdge, Timer, First, Event
from cocotb.utils import get_sim_time

# from cocotbext.eth.constants import (EthPre, XgmiiCtrl, BaseRCtrl, BaseRO,
#     BaseRSync, BaseRBlockType, xgmii_ctrl_to_baser_mapping,
#     baser_ctrl_to_xgmii_mapping, block_type_term_lane_mapping)
from cocotbext.eth.constants import EthPre, XgmiiCtrl
from cocotbext.eth import GmiiFrame


def rd_flip_3b4b(hgf):
    if hgf == 0b000:
        return 1
    if hgf == 0b001:
        return 0
    if hgf == 0b010:
        return 0
    if hgf == 0b011:
        return 0
    if hgf == 0b100:
        return 1
    if hgf == 0b101:
        return 0
    if hgf == 0b110:
        return 0
    if hgf == 0b111:
        return 1

def rd_flip_5b6b(edcba, k):
    if edcba == 0b00000:
        return 1
    if edcba == 0b00001:
        return 1
    if edcba == 0b00010:
        return 1
    if edcba == 0b00011:
        return 0
    if edcba == 0b00100:
        return 1
    if edcba == 0b00101:
        return 0
    if edcba == 0b00110:
        return 0
    if edcba == 0b00111:
        return 0
    if edcba == 0b01000:
        return 1
    if edcba == 0b01001:
        return 0
    if edcba == 0b01010:
        return 0
    if edcba == 0b01011:
        return 0
    if edcba == 0b01100:
        return 0
    if edcba == 0b01101:
        return 0
    if edcba == 0b01110:
        return 0
    if edcba == 0b01111:
        return 1
    if edcba == 0b10000:
        return 1
    if edcba == 0b10001:
        return 0
    if edcba == 0b10010:
        return 0
    if edcba == 0b10011:
        return 0
    if edcba == 0b10100:
        return 0
    if edcba == 0b10101:
        return 0
    if edcba == 0b10110:
        return 0
    if edcba == 0b10111:
        return 1
    if edcba == 0b11000:
        return 1
    if edcba == 0b11001:
        return 0
    if edcba == 0b11010:
        return 0
    if edcba == 0b11011:
        return 1
    if edcba == 0b11100:
        return k # K28
    if edcba == 0b11101:
        return 1
    if edcba == 0b11110:
        return 1
    if edcba == 0b11111:
        return 1

def rd_flip_8b10b(d, k):
    return rd_flip_5b6b(d & 0x1f, k) ^ rd_flip_3b4b(d >> 5)


class BaseXSerdesSource():

    def __init__(self, data, clock, data_k=None, enable=None, slip=None, data_valid=None,
            gbx_sync=None, enc_8b10b=True, reverse=False, gbx_cfg=None, *args, **kwargs):

        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.data = data
        self.clock = clock
        self.data_k = data_k
        self.enable = enable
        self.slip = slip
        self.data_valid = data_valid
        self.gbx_sync = gbx_sync
        self.enc_8b10b = enc_8b10b
        self.reverse = reverse

        self.log.info("BASE-X serdes source")
        self.log.info("Copyright (c) 2026 FPGA Ninja, LLC")
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

        self.bit_offset = 0

        self.gbx_seq = 0
        self.gbx_seq_len = None
        self.gbx_seq_stall = None
        self.gbx_in_bits = 10
        self.gbx_out_bits = 10
        self.gbx_bit_cnt = 0

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        self.queue_occupancy_limit_bytes = -1
        self.queue_occupancy_limit_frames = -1

        self.an_cfg = None

        self.width = len(self.data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        self.data_mask = (2**self.width)-1

        assert self.byte_lanes in [1, 2, 4, 8]
        assert self.width == self.byte_lanes * self.byte_size

        self.log.info("BASE-X serdes source model configuration")
        self.log.info("  Byte size: %d bits", self.byte_size)
        self.log.info("  Data width: %d bits (%d bytes)", self.width, self.byte_lanes)
        self.log.info("  Enable 8b10b encoder: %s", self.enc_8b10b)
        self.log.info("  Bit reverse: %s", self.reverse)

        if gbx_cfg:
            self.set_gbx_cfg(*gbx_cfg)

        self.data.setimmediatevalue(0)
        if self.data_k is not None:
            self.data_k.setimmediatevalue(0)
        if self.data_valid is not None:
            self.data_valid.setimmediatevalue(0)
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
            self.gbx_in_bits = 10
            self.gbx_out_bits = 10
            self.gbx_seq = 0

        seq_stall = sorted(list(set(seq_stall)))

        for x in seq_stall:
            assert 0 <= x < seq_len

        self.log.info("  Sequence length: %d cycles", seq_len)
        self.log.info("  Stall cycles: %s", seq_stall)

        out_bits = 10
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
        frame = GmiiFrame(frame)
        await self.queue.put(frame)
        self.idle_event.clear()
        self.queue_occupancy_bytes += len(frame)
        self.queue_occupancy_frames += 1

    def send_nowait(self, frame):
        if self.full():
            raise QueueFull()
        frame = GmiiFrame(frame)
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
        self.an_cfg = None

    async def wait(self):
        await self.idle_event.wait()

    def set_an_cfg(self, cfg=None):
        self.an_cfg = cfg

    async def _run(self):
        frame = None
        frame_offset = 0
        rd = False
        odd = False
        carrier_extend = False
        in_pre = False
        ifg_cnt = 0
        deficit_idle_cnt = 0
        last_d = 0
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        clk_period = 0
        last_clk = 0
        gbx_delay = 0

        data = 0
        data_k = 0

        an_cfg = []
        an_phase = False

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
                    if self.data_k is not None:
                        self.data_k.value = 0
                    if self.data_valid is not None:
                        self.data_valid.value = 0
                    continue

                self.gbx_bit_cnt = max(self.gbx_bit_cnt - self.gbx_out_bits, 0)
                gbx_delay = (self.gbx_bit_cnt * clk_period) // self.gbx_in_bits
            else:
                self.gbx_seq = 0
                self.gbx_bit_cnt = 0
                gbx_delay = 0

                if self.gbx_sync is not None:
                    self.gbx_sync.value = 0

            data = 0
            data_k = 0

            for k in range(self.byte_lanes):
                # idle
                if not odd:
                    d_val = 0xBC # /K28.5/
                    k_val = True
                elif rd:
                    # /I1/
                    d_val = 0xC5 # /D5.6/
                    k_val = False
                else:
                    # /I2/
                    d_val = 0x50 # /D16.2/
                    k_val = False

                if carrier_extend:
                    # /R/
                    d_val = 0xF7 # (/K23.7/)
                    k_val = True

                    if odd:
                        carrier_extend = False

                if frame is None:
                    if ifg_cnt > 1 or (not self.enable_dic and ifg_cnt > 0) or odd:
                        # in IFG
                        pass

                    else:
                        # eligible to start
                        if not self.queue.empty():
                            # send frame
                            frame = self.queue.get_nowait()
                            self.dequeue_event.set()
                            self.queue_occupancy_bytes -= len(frame)
                            self.queue_occupancy_frames -= 1
                            self.current_frame = frame
                            frame.sim_time_start = sim_time + (clk_period // self.byte_lanes * k) - gbx_delay
                            frame.sim_time_sfd = None
                            frame.sim_time_end = None
                            self.log.info("TX frame: %s", frame)
                            frame.normalize()
                            assert frame.data[0] == EthPre.PRE

                            if self.enable_dic:
                                deficit_idle_cnt = ifg_cnt
                            ifg_cnt = 0
                            self.active = True
                            frame_offset = 0
                            in_pre = True
                        else:
                            # nothing to send
                            self.active = False
                            self.idle_event.set()

                    if frame is None:
                        # idle
                        if ifg_cnt > 0:
                            ifg_cnt -= 1
                        elif deficit_idle_cnt > 0:
                            deficit_idle_cnt -= 1

                if an_cfg:
                    d_val = an_cfg.pop(0)
                    k_val = False
                elif frame is not None:
                    if frame_offset == 0:
                        # /S/
                        d_val = XgmiiCtrl.START # /K27.7/
                        k_val = True
                    elif frame_offset >= len(frame.data):
                        # /T/
                        d_val = XgmiiCtrl.TERM # /K29.7/
                        k_val = True
                        carrier_extend = True

                        ifg_cnt = max(self.ifg + deficit_idle_cnt - 1, 0)
                        frame.sim_time_end = sim_time + (clk_period // self.byte_lanes * k) - gbx_delay
                        frame.handle_tx_complete()
                        frame = None
                        self.current_frame = None
                    else:
                        d = frame.data[frame_offset]
                        if frame.sim_time_sfd is None and not in_pre:
                            frame.sim_time_sfd = sim_time + (clk_period // self.byte_lanes * k) - gbx_delay
                        if d == EthPre.SFD:
                            in_pre = False
                        if frame.error[frame_offset]:
                            # /V/
                            d_val = XgmiiCtrl.ERROR # /K30.7/
                            k_val = True
                        else:
                            d_val = d # /Dx.y/
                            k_val = False
                    frame_offset += 1
                elif self.an_cfg is not None and odd:
                    self.log.info("TX config reg: 0x%04x", self.an_cfg)
                    an_cfg = [self.an_cfg & 0xff, (self.an_cfg >> 8) & 0xff]
                    if an_phase:
                        d_val = 0x42
                    else:
                        d_val = 0xb5
                    k_val = False
                    an_phase = not an_phase

                if self.enc_8b10b:
                    # 8b/10b encode
                    self.log.error("8b/10b decoder not yet implemented")
                    data |= (d_val << (k*8))
                    data_k |= (k_val << k)
                else:
                    data |= (d_val << (k*8))
                    data_k |= (k_val << k)

                odd = not odd
                rd = rd ^ rd_flip_8b10b(d_val, k_val)

            # if self.slip is not None and self.slip.value:
            #     self.bit_offset += 1

            # self.bit_offset = max(0, self.bit_offset) % 10

            # if self.bit_offset != 0:
            #     d = data

            #     out_d = ((last_d | d << 66) >> 66-self.bit_offset) & 0xffffffffffffffff

            #     last_d = d

            #     data = out_d

            data_out = data
            data_k_out = data_k

            if self.reverse:
                # bit reverse
                data_out = sum(1 << (self.width-1-i) for i in range(self.width) if (data_out >> i) & 1)
                data_k_out = sum(1 << (1-i) for i in range(self.byte_lanes) if (data_k_out >> i) & 1)

            self.data.value = data_out & self.data_mask
            if self.data_k is not None:
                self.data_k.value = data_k_out
            if self.data_valid is not None:
                self.data_valid.value = 1


class BaseXSerdesSink:

    def __init__(self, data, clock, data_k=None, enable=None, data_valid=None,
            gbx_req_sync=None, gbx_req_stall=None, gbx_sync=None,
            dec_8b10b=True, reverse=False, gbx_cfg=None, *args, **kwargs):

        self.log = logging.getLogger(f"cocotb.{data._path}")
        self.data = data
        self.clock = clock
        self.data_k = data_k
        self.enable = enable
        self.data_valid = data_valid
        self.gbx_req_sync = gbx_req_sync
        self.gbx_req_stall = gbx_req_stall
        self.gbx_sync = gbx_sync
        self.dec_8b10b = dec_8b10b
        self.reverse = reverse

        self.log.info("BASE-X serdes sink")
        self.log.info("Copyright (c) 2026 FPGA Ninja, LLC")
        self.log.info("https://github.com/fpganinja/taxi")

        super().__init__(*args, **kwargs)

        self.active = False
        self.queue = Queue()
        self.active_event = Event()

        self.gbx_seq = 0
        self.gbx_seq_gen = 0
        self.gbx_seq_len = None
        self.gbx_seq_stall = None
        self.gbx_in_bits = 10
        self.gbx_out_bits = 10
        self.gbx_bit_cnt = 0

        self.queue_occupancy_bytes = 0
        self.queue_occupancy_frames = 0

        self.an_cfg = None
        self.an_ability_match_cnt = 0
        self.an_ack_match_cnt = 0
        self.an_idle_match_cnt = 0

        self.width = len(self.data)
        self.byte_size = 8
        self.byte_lanes = self.width // self.byte_size

        assert self.byte_lanes in [1, 2, 4, 8]
        assert self.width == self.byte_lanes * self.byte_size

        self.log.info("BASE-X serdes sink model configuration")
        self.log.info("  Byte size: %d bits", self.byte_size)
        self.log.info("  Data width: %d bits (%d bytes)", self.width, self.byte_lanes)
        self.log.info("  Enable 8b10b decoder: %s", self.dec_8b10b)
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

        in_bits = 10
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

    def get_an_cfg(self):
        an_cfg = self.an_cfg
        self.an_cfg = None
        return an_cfg

    def get_an_ability_match(self):
        return self.an_ability_match_cnt > 2

    def get_an_ack_match(self):
        return self.an_ack_match_cnt > 2

    def get_an_idle_match(self):
        return self.an_idle_match_cnt > 2

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
        rd = False
        odd = False
        in_pre = False
        self.active = False

        clock_edge_event = RisingEdge(self.clock)

        clk_period = 0
        last_clk = 0
        gbx_delay = 0
        sync_bad = True

        data = 0
        data_k = 0

        an_cfg = None
        last_an_cfg = 0

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
            data_k_in = 0
            if self.data_k is not None:
                data_k_in = int(self.data_k.value)

            if self.reverse:
                # bit reverse
                data_in = sum(1 << (self.width-1-i) for i in range(self.width) if (data_in >> i) & 1)
                data_k_in = sum(1 << (1-i) for i in range(self.byte_lanes) if (data_k_in >> i) & 1)

            data = data_in
            data_k = data_k_in

            for k in range(self.byte_lanes):
                if self.dec_8b10b:
                    # 8b/10b decode
                    self.log.error("8b/10b decoder not yet implemented")
                    d_val = (data >> (k*8)) & 0xff
                    k_val = bool((data_k >> k) & 0x1)
                else:
                    d_val = (data >> (k*8)) & 0xff
                    k_val = bool((data_k >> k) & 0x1)

                # 1000BASE-X decoding

                an_cnt_reset = True

                if frame is not None:
                    # in a frame
                    if k_val:
                        # got a control character; terminate frame reception
                        if d_val != XgmiiCtrl.TERM:
                            # store control character if it's not a termination
                            frame.data.append(d_val)
                            frame.error.append(True)

                        frame.compact()
                        frame.sim_time_end = sim_time + (clk_period // self.byte_lanes * k) + gbx_delay
                        self.log.info("RX frame: %s", frame)

                        self.queue_occupancy_bytes += len(frame)
                        self.queue_occupancy_frames += 1

                        self.queue.put_nowait(frame)
                        self.active_event.set()

                        frame = None
                    else:
                        # normal frame data
                        if frame.sim_time_sfd is None and not in_pre:
                            frame.sim_time_sfd = sim_time + (clk_period // self.byte_lanes * k) + gbx_delay
                        if d_val == EthPre.SFD:
                            in_pre = False

                        frame.data.append(d_val)
                        frame.error.append(False)
                elif an_cfg is not None:
                    # config register
                    an_cnt_reset = False
                    self.an_idle_match_cnt = 0

                    if k_val:
                        # got a control character; abort
                        an_cfg = None
                    else:
                        an_cfg.append(d_val)

                        if len(an_cfg) == 2:
                            an_cfg = an_cfg[0] | (an_cfg[1] << 8)
                            self.log.info("RX config reg: 0x%04x", an_cfg)
                            if (last_an_cfg ^ an_cfg) & ~0x4000 == 0:
                                self.an_ability_match_cnt += 1
                            else:
                                self.an_ability_match_cnt = 0
                            if last_an_cfg == an_cfg and an_cfg & 0x4000:
                                self.an_ack_match_cnt += 1
                            else:
                                self.an_ack_match_cnt = 0
                            last_an_cfg = an_cfg
                            self.an_cfg = an_cfg
                            an_cfg = None
                else:
                    # idle
                    if k_val:
                        # control character
                        if d_val == 0xBC:
                            # K28.5
                            # sync
                            odd = False
                            an_cnt_reset = False
                        elif d_val == XgmiiCtrl.START:
                            # start
                            if not odd:
                                frame = GmiiFrame(bytearray([EthPre.PRE]), [False])
                                frame.sim_time_start = sim_time + (clk_period // self.byte_lanes * k) + gbx_delay
                                in_pre = True
                            else:
                                self.log.warning("Ignoring unaligned start")
                        elif d_val == XgmiiCtrl.ERROR:
                            # error propagation
                            pass
                        elif d_val == XgmiiCtrl.TERM:
                            # termination
                            pass
                        elif d_val == 0xf7:
                            # carrier extend
                            pass
                        else:
                            self.log.warning("Unknown control character 0x%02x (K%d.%d)", d_val, d_val & 0x1f, d_val >> 5)
                    else:
                        # data
                        if d_val == 0xb5 or d_val == 0x42:
                            # config reg
                            an_cfg = []
                            an_cnt_reset = False
                        else:
                            # idle
                            an_cnt_reset = False
                            self.an_ability_match_cnt = 0
                            self.an_ack_match_cnt = 0
                            self.an_idle_match_cnt += 1

                if an_cnt_reset:
                    self.an_ability_match_cnt = 0
                    self.an_ack_match_cnt = 0
                    self.an_idle_match_cnt = 0

                odd = not odd
