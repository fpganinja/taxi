# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import array
import datetime
import logging
import struct
from collections import deque

from cocotb.queue import Queue


# Command opcodes
CNDM_CMD_OP_NOP = 0x0000

CNDM_CMD_OP_CFG        = 0x0100

CNDM_CMD_OP_ACCESS_REG = 0x0180
CNDM_CMD_OP_PTP        = 0x0190

CNDM_CMD_OP_CREATE_EQ  = 0x0200
CNDM_CMD_OP_MODIFY_EQ  = 0x0201
CNDM_CMD_OP_QUERY_EQ   = 0x0202
CNDM_CMD_OP_DESTROY_EQ = 0x0203

CNDM_CMD_OP_CREATE_CQ  = 0x0210
CNDM_CMD_OP_MODIFY_CQ  = 0x0211
CNDM_CMD_OP_QUERY_CQ   = 0x0212
CNDM_CMD_OP_DESTROY_CQ = 0x0213

CNDM_CMD_OP_CREATE_SQ  = 0x0220
CNDM_CMD_OP_MODIFY_SQ  = 0x0221
CNDM_CMD_OP_QUERY_SQ   = 0x0222
CNDM_CMD_OP_DESTROY_SQ = 0x0223

CNDM_CMD_OP_CREATE_RQ  = 0x0230
CNDM_CMD_OP_MODIFY_RQ  = 0x0231
CNDM_CMD_OP_QUERY_RQ   = 0x0232
CNDM_CMD_OP_DESTROY_RQ = 0x0233

CNDM_CMD_OP_CREATE_QP  = 0x0240
CNDM_CMD_OP_MODIFY_QP  = 0x0241
CNDM_CMD_OP_QUERY_QP   = 0x0242
CNDM_CMD_OP_DESTROY_QP = 0x0243

CNDM_CMD_REG_FLG_WRITE  = 0x00000001
CNDM_CMD_REG_FLG_RAW    = 0x00000100

CNDM_CMD_PTP_FLG_SET_TOD    = 0x00000001
CNDM_CMD_PTP_FLG_OFFSET_TOD = 0x00000002
CNDM_CMD_PTP_FLG_SET_REL    = 0x00000004
CNDM_CMD_PTP_FLG_OFFSET_REL = 0x00000008
CNDM_CMD_PTP_FLG_OFFSET_FNS = 0x00000010
CNDM_CMD_PTP_FLG_SET_PERIOD = 0x00000080


class Cq:
    def __init__(self, driver, port):
        self.driver = driver
        self.log = driver.log

        self.port = port
        self.irqn = None

        self.log_size = 0
        self.size = 0
        self.size_mask = 0
        self.stride = 0
        self.cqn = None
        self.enabled = False

        self.buf_size = 0
        self.buf_region = None
        self.buf_dma = 0
        self.buf = None

        self.eq = None

        self.src_ring = None
        self.handler = None

        self.cons_ptr = None

        self.db_offset = None
        self.hw_regs = self.driver.hw_regs

    async def open(self, irqn, size):
        if self.cqn is not None:
            raise Exception("Already open")

        self.irqn = irqn

        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
        self.size_mask = self.size-1
        self.stride = 16

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        self.buf[0:self.buf_size] = b'\x00'*self.buf_size

        self.cons_ptr = 0

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_CQ, # opcode
            0x00000000, # flags
            self.port.index, # port
            0, # cqn
            self.irqn, # eqn
            0, # pd
            self.log_size, # size
            0, # dboffs
            self.buf_dma, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))

        rsp_unpacked = struct.unpack("<HHLLLLLLLQQLLLL", rsp)
        print(rsp_unpacked)
        self.cqn = rsp_unpacked[4]
        self.db_offset = rsp_unpacked[8]

        if self.db_offset == 0:
            self.cqn = None
            self.db_offset = None
            self.log.error("Failed to allocate CQ")
            return

        await self.write_cons_ptr_arm()

        self.log.info("Opened CQ %d", self.cqn)
        self.log.info("Using doorbell at offset 0x%08x", self.db_offset)

        self.enabled = True

    async def close(self):
        if self.cqn is None:
            return

        self.enabled = False

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_DESTROY_CQ, # opcode
            0x00000000, # flags
            self.port.index, # port
            self.cqn, # cqn
            0, # eqn
            0, # pd
            0, # size
            0, # dboffs
            0, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))

        self.cqn = None

        # TODO free buffer

    async def write_cons_ptr(self):
        await self.hw_regs.write_dword(self.db_offset, self.cons_ptr & 0xffff)

    async def write_cons_ptr_arm(self):
        await self.hw_regs.write_dword(self.db_offset, (self.cons_ptr & 0xffff) | 0x80000000)


class Sq:
    def __init__(self, driver, port):
        self.driver = driver
        self.log = driver.log

        self.port = port

        self.log_size = 0
        self.size = 0
        self.size_mask = 0
        self.full_size = 0
        self.stride = 0
        self.sqn = None
        self.enabled = False

        self.buf_size = 0
        self.buf_region = None
        self.buf_dma = 0
        self.buf = None

        self.cq = None

        self.prod_ptr = None
        self.cons_ptr = None

        self.packets = 0
        self.bytes = 0

        self.db_offset = None
        self.hw_regs = self.driver.hw_regs

    async def open(self, cq, size):
        if self.sqn is not None:
            raise Exception("Already open")

        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
        self.size_mask = self.size-1
        self.stride = 16

        self.tx_info = [None]*self.size

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        self.buf[0:self.buf_size] = b'\x00'*self.buf_size

        self.prod_ptr = 0
        self.cons_ptr = 0

        self.cq = cq
        self.cq.src_ring = self
        self.cq.handler = Sq.process_tx_cq

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_SQ, # opcode
            0x00000000, # flags
            self.port.index, # port
            0, # sqn
            self.cq.cqn, # cqn
            0, # pd
            self.log_size, # size
            0, # dboffs
            self.buf_dma, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))

        rsp_unpacked = struct.unpack("<HHLLLLLLLQQLLLL", rsp)
        print(rsp_unpacked)
        self.sqn = rsp_unpacked[4]
        self.db_offset = rsp_unpacked[8]

        if self.db_offset == 0:
            self.sqn = None
            self.db_offset = None
            self.log.error("Failed to allocate SQ")
            return

        self.log.info("Opened SQ %d (CQ %d)", self.sqn, cq.cqn)
        self.log.info("Using doorbell at offset 0x%08x", self.db_offset)

        self.enabled = True

    async def close(self):
        if self.sqn is None:
            return

        self.enabled = False

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_DESTROY_SQ, # opcode
            0x00000000, # flags
            self.port.index, # port
            self.sqn, # sqn
            0, # eqn
            0, # pd
            0, # size
            0, # dboffs
            0, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))

        self.sqn = None

        # TODO free buffer

    def is_ring_empty(self):
        return self.prod_ptr == self.cons_ptr

    def is_ring_full(self):
        return ((self.prod_ptr - self.cons_ptr) & 0xffffffff) > self.size

    async def write_prod_ptr(self):
        await self.hw_regs.write_dword(self.db_offset, self.prod_ptr & 0xffff)

    async def start_xmit(self, data):
        headroom = 10
        tx_buf = self.driver.alloc_pkt()
        await tx_buf.write(headroom, data)
        index = self.prod_ptr & self.size_mask
        ptr = tx_buf.get_absolute_address(0)
        struct.pack_into('<xxxxLQ', self.buf, 16*index, len(data), ptr+headroom)
        self.tx_info[index] = tx_buf
        self.prod_ptr += 1
        await self.write_prod_ptr()

    def free_tx_desc(self, index):
        pkt = self.tx_info[index]
        self.driver.free_pkt(pkt)
        self.tx_info[index] = None

    def free_tx_buf(self):
        while not self.is_ring_empty():
            index = self.cons_ptr & self.size_mask
            self.free_tx_desc(index)
            self.cons_ptr += 1

    @staticmethod
    async def process_tx_cq(cq):
        sq = cq.src_ring

        cq.log.info("Process CQ %d for SQ %d", cq.cqn, sq.sqn)

        cq_cons_ptr = cq.cons_ptr
        cons_ptr = sq.cons_ptr

        while True:
            cq_index = cq_cons_ptr & cq.size_mask
            index = cons_ptr & sq.size_mask

            cpl_data = struct.unpack_from("<LLLL", cq.buf, cq_index*16)

            cq.log.info("TX CQ index %d data %s", cq_index, cpl_data)

            if bool(cpl_data[-1] & 0x80000000) == bool(cq_cons_ptr & cq.size):
                cq.log.info("CQ empty")
                break

            pkt = sq.tx_info[index]

            sq.free_tx_desc(index)

            cq_cons_ptr += 1
            cons_ptr += 1

        cq.cons_ptr = cq_cons_ptr
        sq.cons_ptr = cons_ptr

        await cq.write_cons_ptr_arm()


class Rq:
    def __init__(self, driver, port):
        self.driver = driver
        self.log = driver.log

        self.port = port

        self.log_size = 0
        self.size = 0
        self.size_mask = 0
        self.full_size = 0
        self.stride = 0
        self.rqn = None
        self.enabled = False

        self.buf_size = 0
        self.buf_region = None
        self.buf_dma = 0
        self.buf = None

        self.cq = None

        self.prod_ptr = None
        self.cons_ptr = None

        self.packets = 0
        self.bytes = 0

        self.db_offset = None
        self.hw_regs = self.driver.hw_regs

    async def open(self, cq, size):
        if self.rqn is not None:
            raise Exception("Already open")

        self.log_size = size.bit_length() - 1
        self.size = 2**self.log_size
        self.size_mask = self.size-1
        self.stride = 16

        self.rx_info = [None]*self.size

        self.buf_size = self.size*self.stride
        self.buf_region = self.driver.pool.alloc_region(self.buf_size)
        self.buf_dma = self.buf_region.get_absolute_address(0)
        self.buf = self.buf_region.mem

        self.buf[0:self.buf_size] = b'\x00'*self.buf_size

        self.prod_ptr = 0
        self.cons_ptr = 0

        self.cq = cq
        self.cq.src_ring = self
        self.cq.handler = Rq.process_rx_cq

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_RQ, # opcode
            0x00000000, # flags
            self.port.index, # port
            0, # rqn
            self.cq.cqn, # cqn
            0, # pd
            self.log_size, # size
            0, # dboffs
            self.buf_dma, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))

        rsp_unpacked = struct.unpack("<HHLLLLLLLQQLLLL", rsp)
        print(rsp_unpacked)
        self.rqn = rsp_unpacked[4]
        self.db_offset = rsp_unpacked[8]

        if self.db_offset == 0:
            self.rqn = None
            self.db_offset = None
            self.log.error("Failed to allocate RQ")
            return

        self.log.info("Opened RQ %d (CQ %d)", self.rqn, cq.cqn)
        self.log.info("Using doorbell at offset 0x%08x", self.db_offset)

        self.enabled = True

        await self.refill_rx_buffers()

    async def close(self):
        if self.rqn is None:
            return

        self.enabled = False

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_DESTROY_RQ, # opcode
            0x00000000, # flags
            self.port.index, # port
            self.rqn, # rqn
            0, # eqn
            0, # pd
            0, # size
            0, # dboffs
            0, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))

        self.rqn = None

        # TODO free buffer

    def is_ring_empty(self):
        return self.prod_ptr == self.cons_ptr

    def is_ring_full(self):
        return ((self.prod_ptr - self.cons_ptr) & 0xffffffff) > self.size

    async def write_prod_ptr(self):
        await self.hw_regs.write_dword(self.db_offset, self.prod_ptr & 0xffff)

    def free_rx_desc(self, index):
        pkt = self.rx_info[index]
        self.driver.free_pkt(pkt)
        self.rx_info[index] = None

    def free_rx_buf(self):
        while not self.is_ring_empty():
            index = self.cons_ptr & self.size_mask
            self.free_rx_desc(index)
            self.cons_ptr += 1

    def prepare_rx_desc(self, index):
        pkt = self.driver.alloc_pkt()
        self.rx_info[index] = pkt

        length = pkt.size
        ptr = pkt.get_absolute_address(0)

        struct.pack_into('<xxxxLQ', self.buf, 16*index, length, ptr)

    async def refill_rx_buffers(self):
        missing = self.size - (self.prod_ptr - self.cons_ptr)

        if missing < 8:
            return

        for k in range(missing):
            self.prepare_rx_desc(self.prod_ptr & self.size_mask)
            self.prod_ptr += 1

        await self.write_prod_ptr()

    @staticmethod
    async def process_rx_cq(cq):
        rq = cq.src_ring

        cq.log.info("Process CQ %d for RQ %d", cq.cqn, rq.rqn)

        cq_cons_ptr = cq.cons_ptr
        cons_ptr = rq.cons_ptr

        while True:
            cq_index = cq_cons_ptr & cq.size_mask
            index = cons_ptr & rq.size_mask

            cpl_data = struct.unpack_from("<LLLL", cq.buf, cq_index*16)

            rq.log.info("RX CQ index %d data %s", cq_index, cpl_data)

            if bool(cpl_data[-1] & 0x80000000) == bool(cq_cons_ptr & cq.size):
                rq.log.info("CQ empty")
                break

            pkt = rq.rx_info[index]
            length = cpl_data[1]

            data = pkt[:length]

            rq.log.info("Packet: %s", data)

            rq.port.rx_queue.put_nowait(data)

            rq.free_rx_desc(index)

            cq_cons_ptr += 1
            cons_ptr += 1

        cq.cons_ptr = cq_cons_ptr
        rq.cons_ptr = cons_ptr

        await rq.refill_rx_buffers()
        await cq.write_cons_ptr_arm()


class Port:
    def __init__(self, driver, index):
        self.driver = driver
        self.log = driver.log
        self.index = index
        self.hw_regs = driver.hw_regs

        self.rxq_count = 1
        self.rxq = []

        self.txq_count = 1
        self.txq = []

        self.rx_queue = Queue()

    async def init(self):
        await self.open()

    async def open(self):
        for k in range(self.rxq_count):
            cq = Cq(self.driver, self)
            await cq.open(self.index, 256)

            q = Rq(self.driver, self)
            await q.open(cq, 256)

            self.rxq.append(q)

        for k in range(self.txq_count):
            cq = Cq(self.driver, self)
            await cq.open(self.index, 256)

            q = Sq(self.driver, self)
            await q.open(cq, 256)

            self.txq.append(q)

    async def start_xmit(self, data, tx_ring=0):
        await self.txq[tx_ring].start_xmit(data)

    async def recv(self):
        return await self.rx_queue.get()

    async def recv_nowait(self):
        return self.rx_queue.get_nowait()

    async def interrupt_handler(self):
        self.log.info("Interrupt")
        for q in self.rxq:
            await q.cq.handler(q.cq)
        for q in self.txq:
            await q.cq.handler(q.cq)


class Driver:
    def __init__(self):
        self.log = logging.getLogger("cocotb.cndm")

        self.dev = None
        self.pool = None
        self.hw_regs = None

        self.port_count = None

        self.ports = []

        self.free_packets = deque()
        self.allocated_packets = []

        # config
        self.cfg_page_max = None
        self.cmd_ver = None

        # FW ID
        self.fpga_id = None
        self.fw_id = None
        self.fw_ver = None
        self.board_id = None
        self.board_ver = None
        self.build_date = None
        self.git_hash = None
        self.release_info = None

        # HW config
        self.sys_clk_per_ns_num = None
        self.sys_clk_per_ns_den = None
        self.ptp_clk_per_ns_num = None
        self.ptp_clk_per_ns_den = None

        # Resources
        self.log_max_eq = None
        self.log_max_eq_sz = None
        self.eq_pool = None
        self.eqe_ver = None
        self.log_max_cq = None
        self.log_max_cq_sz = None
        self.cq_pool = None
        self.cqe_ver = None
        self.log_max_sq = None
        self.log_max_sq_sz = None
        self.sq_pool = None
        self.sqe_ver = None
        self.log_max_rq = None
        self.log_max_rq_sz = None
        self.rq_pool = None
        self.rqe_ver = None

    async def init_pcie_dev(self, dev):
        self.dev = dev
        self.pool = dev.rc.mem_pool

        await dev.enable_device()
        await dev.set_master()
        await dev.alloc_irq_vectors(32, 32)

        self.hw_regs = dev.bar_window[0]

        await self.init_common()

    async def init_common(self):

        # Get config information
        rsp = await self.exec_cmd(struct.pack("<HHLHHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CFG, # opcode
            0x00000000, # flags
            0, # cfg_page
            0, # num_cfg_pages
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ))

        rsp_unpacked = struct.unpack("<HHLHHLLLLLLLLLLLLL", rsp)
        print(rsp_unpacked)

        self.cfg_page_max = rsp_unpacked[4]
        self.cmd_ver = rsp_unpacked[5]

        self.log.info("Config pages: %d", self.cfg_page_max+1)
        self.log.info("Command version: %d.%d.%d", self.cmd_ver >> 20, (self.cmd_ver >> 12) & 0xff, self.cmd_ver & 0xfff)

        self.fpga_id = rsp_unpacked[10]
        self.fw_id = rsp_unpacked[11]
        self.fw_ver = rsp_unpacked[12]
        self.board_id = rsp_unpacked[13]
        self.board_ver = rsp_unpacked[14]
        self.build_date = rsp_unpacked[15]
        self.git_hash = rsp_unpacked[16]
        self.release_info = rsp_unpacked[17]

        self.log.info("FPGA JTAG ID: 0x%08x", self.fpga_id)
        self.log.info("FW ID: 0x%08x", self.fw_id)
        self.log.info("FW version: %d.%d.%d", self.fw_ver >> 20, (self.fw_ver >> 12) & 0xff, self.fw_ver & 0xfff)
        self.log.info("Board ID: 0x%08x", self.board_id)
        self.log.info("Board version: %d.%d.%d", self.board_ver >> 20, (self.board_ver >> 12) & 0xff, self.board_ver & 0xfff)
        self.log.info("Build date: %s UTC (raw: 0x%08x)", datetime.datetime.fromtimestamp(self.build_date, datetime.timezone.utc).isoformat(' '), self.build_date)
        self.log.info("Git hash: %08x", self.git_hash)
        self.log.info("Release info: %08x", self.release_info)

        # Get config information
        rsp = await self.exec_cmd(struct.pack("<HHLHHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CFG, # opcode
            0x00000000, # flags
            1, # cfg_page
            0, # num_cfg_pages
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ))

        rsp_unpacked = struct.unpack("<HHLHHLLLLLLLLLLLLL", rsp)
        print(rsp_unpacked)

        self.port_count = rsp_unpacked[10] & 0xff
        self.sys_clk_per_ns_den = rsp_unpacked[14] & 0xffff
        self.sys_clk_per_ns_num = rsp_unpacked[14] >> 16
        self.ptp_clk_per_ns_den = rsp_unpacked[15] & 0xffff
        self.ptp_clk_per_ns_num = rsp_unpacked[15] >> 16

        self.log.info("Port count: %d", self.port_count)

        self.log.info("Sys clock period: %f MHz (raw %d/%d ns)",
            1000/(self.sys_clk_per_ns_num/self.sys_clk_per_ns_den),
            self.sys_clk_per_ns_num, self.sys_clk_per_ns_den)
        self.log.info("PTP clock period: %f MHz (raw %d/%d ns)",
            1000/(self.ptp_clk_per_ns_num/self.ptp_clk_per_ns_den),
            self.ptp_clk_per_ns_num, self.ptp_clk_per_ns_den)

        # Get config information
        rsp = await self.exec_cmd(struct.pack("<HHLHHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CFG, # opcode
            0x00000000, # flags
            2, # cfg_page
            0, # num_cfg_pages
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
        ))

        rsp_unpacked = struct.unpack("<HHLHHLLLLLLLLLLLLL", rsp)
        print(rsp_unpacked)

        # Resources
        self.log_max_eq = rsp_unpacked[10] & 0xff
        self.log_max_eq_sz = (rsp_unpacked[10] >> 8) & 0xff
        self.eq_pool = (rsp_unpacked[10] >> 16) & 0xff
        self.eqe_ver = (rsp_unpacked[10] >> 24) & 0xff
        self.log_max_cq = rsp_unpacked[11] & 0xff
        self.log_max_cq_sz = (rsp_unpacked[11] >> 8) & 0xff
        self.cq_pool = (rsp_unpacked[11] >> 16) & 0xff
        self.cqe_ver = (rsp_unpacked[11] >> 24) & 0xff
        self.log_max_sq = rsp_unpacked[12] & 0xff
        self.log_max_sq_sz = (rsp_unpacked[12] >> 8) & 0xff
        self.sq_pool = (rsp_unpacked[12] >> 16) & 0xff
        self.sqe_ver = (rsp_unpacked[12] >> 24) & 0xff
        self.log_max_rq = rsp_unpacked[13] & 0xff
        self.log_max_rq_sz = (rsp_unpacked[13] >> 8) & 0xff
        self.rq_pool = (rsp_unpacked[13] >> 16) & 0xff
        self.rqe_ver = (rsp_unpacked[13] >> 24) & 0xff

        self.log.info("Max EQ count: %d (log %d)", 2**self.log_max_eq, self.log_max_eq)
        self.log.info("Max EQ size: %d (log %d)", 2**self.log_max_eq_sz, self.log_max_eq_sz)
        self.log.info("EQ pool: %d", self.eq_pool)
        self.log.info("EQE version: %d", self.eqe_ver)
        self.log.info("Max CQ count: %d (log %d)", 2**self.log_max_cq, self.log_max_cq)
        self.log.info("Max CQ size: %d (log %d)", 2**self.log_max_cq_sz, self.log_max_cq_sz)
        self.log.info("CQ pool: %d", self.cq_pool)
        self.log.info("CQE version: %d", self.cqe_ver)
        self.log.info("Max SQ count: %d (log %d)", 2**self.log_max_sq, self.log_max_sq)
        self.log.info("Max SQ size: %d (log %d)", 2**self.log_max_sq_sz, self.log_max_sq_sz)
        self.log.info("SQ pool: %d", self.sq_pool)
        self.log.info("SQE version: %d", self.sqe_ver)
        self.log.info("Max RQ count: %d (log %d)", 2**self.log_max_rq, self.log_max_rq)
        self.log.info("Max RQ size: %d (log %d)", 2**self.log_max_rq_sz, self.log_max_rq_sz)
        self.log.info("RQ pool: %d", self.rq_pool)
        self.log.info("RQE version: %d", self.rqe_ver)

        # Get PTP information
        rsp = await self.exec_cmd(struct.pack("<HHLLLQQQQQLL",
            0, # rsvd
            CNDM_CMD_OP_PTP, # opcode
            0x00000000, # flags
            0, # fns
            0, # tod_ns
            0, # tod_sec
            0, # rel_ns
            0, # ptm
            0, # nom_period
            0, # period
            0, # rsvd
            0, # rsvd
        ))

        rsp_unpacked = struct.unpack("<HHLLLQQQQQLL", rsp)
        print(rsp_unpacked)

        nom_period = rsp_unpacked[8]
        self.log.info("PHC nominal period: %.09f ns (raw 0x%x)", nom_period / 2**32, nom_period)

        # Test setting PTP time
        rsp = await self.exec_cmd(struct.pack("<HHLLLQQQQQLL",
            0, # rsvd
            CNDM_CMD_OP_PTP, # opcode
            CNDM_CMD_PTP_FLG_SET_TOD | CNDM_CMD_PTP_FLG_SET_REL | CNDM_CMD_PTP_FLG_SET_PERIOD, # flags
            0, # fns
            0x12345678, # tod_ns
            0x123456654321, # tod_sec
            0x112233445566, # rel_ns
            0, # ptm
            0, # nom_period
            nom_period, # period
            0, # rsvd
            0, # rsvd
        ))

        rsp_unpacked = struct.unpack("<HHLLLQQQQQLL", rsp)
        print(rsp_unpacked)

        for k in range(self.port_count):
            port = Port(self, k)
            await port.init()
            self.dev.request_irq(k, port.interrupt_handler)

            self.ports.append(port)

    async def access_reg(self, reg, raw, write=False, data=0):
        flags = 0
        if raw:
            flags |= CNDM_CMD_REG_FLG_RAW
        if write:
            flags |= CNDM_CMD_REG_FLG_WRITE

        rsp = await self.exec_cmd(struct.pack("<HHLLLLLLLQQLLLL",
            0, # rsvd
            CNDM_CMD_OP_ACCESS_REG, # opcode
            flags, # flags
            0, # rsvd
            0, # rsvd
            0, # rsvd
            0, # rsvd
            0, # rsvd
            reg, # reg
            data, # write data
            0, # read data
            0, # rsvd
            0, # rsvd
            0, # rsvd
            0, # rsvd
        ))

        return struct.unpack_from("<Q", rsp, 10*4)[0]

    async def exec_cmd(self, cmd):
        return await self.exec_mbox_cmd(cmd)

    async def exec_mbox_cmd(self, cmd):
        cmd = bytes(cmd)
        cmd = cmd.ljust(64, b'\x00')

        if len(cmd) != 64:
            raise ValueError("Invalid command length")

        # write command to mailbox
        a = array.array("I")
        a.frombytes(cmd)
        for k, dw in enumerate(a):
            await self.hw_regs.write_dword(0x10000+k*4, dw)

        # execute it
        await self.hw_regs.write_dword(0x0200, 0x00000001)

        # wait for completion
        while await self.hw_regs.read_dword(0x0200) & 0x00000001:
            pass

        # read response from mailbox
        for k in range(16):
            a[k] = await self.hw_regs.read_dword(0x10040+k*4)
        return a.tobytes()

    def alloc_pkt(self):
        if self.free_packets:
            return self.free_packets.popleft()

        pkt = self.pool.alloc_region(4096)
        self.allocated_packets.append(pkt)
        return pkt

    def free_pkt(self, pkt):
        assert pkt is not None
        assert pkt in self.allocated_packets
        self.free_packets.append(pkt)
