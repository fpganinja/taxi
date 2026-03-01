# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import array
import logging
import struct
from collections import deque

from cocotb.queue import Queue


# Command opcodes
CNDM_CMD_OP_NOP = 0x0000

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


class Port:
    def __init__(self, driver, index):
        self.driver = driver
        self.log = driver.log
        self.index = index
        self.hw_regs = driver.hw_regs

        self.rxq_log_size = (256).bit_length()-1
        self.rxq_size = 2**self.rxq_log_size
        self.rxq_mask = self.rxq_size-1
        self.rxq = None
        self.rxq_prod = 0
        self.rxq_cons = 0
        self.rx_rqn = 0
        self.rxq_db_offs = 0

        self.rx_info = [None] * self.rxq_size

        self.rxcq_log_size = (256).bit_length()-1
        self.rxcq_size = 2**self.rxcq_log_size
        self.rxcq_mask = self.rxcq_size-1
        self.rxcq = None
        self.rxcq_prod = 0
        self.rxcq_cons = 0
        self.rx_cqn = 0

        self.txq_log_size = (256).bit_length()-1
        self.txq_size = 2**self.txq_log_size
        self.txq_mask = self.txq_size-1
        self.txq = None
        self.txq_prod = 0
        self.txq_cons = 0
        self.tx_sqn = 0
        self.txq_db_offs = 0

        self.tx_info = [None] * self.txq_size

        self.txcq_log_size = (256).bit_length()-1
        self.txcq_size = 2**self.txcq_log_size
        self.txcq_mask = self.txcq_size-1
        self.txcq = None
        self.txcq_prod = 0
        self.txcq_cons = 0
        self.tx_cqn = 0

        self.rx_queue = Queue()

    async def init(self):

        self.rxcq = self.driver.pool.alloc_region(self.rxcq_size*16)
        addr = self.rxcq.get_absolute_address(0)

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_CQ, # opcode
            0x00000000, # flags
            self.index, # port
            0, # cqn
            0, # eqn
            0, # pd
            self.rxcq_log_size, # size
            0, # dboffs
            addr, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))
        print(rsp)

        self.rxq = self.driver.pool.alloc_region(self.rxq_size*16)
        addr = self.rxq.get_absolute_address(0)

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_RQ, # opcode
            0x00000000, # flags
            self.index, # port
            0, # rqn
            0, # cqn
            0, # pd
            self.rxq_log_size, # size
            0, # dboffs
            addr, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))
        print(rsp)

        self.rxq_db_offs = struct.unpack_from("<L", rsp, 7*4)[0]

        self.txcq = self.driver.pool.alloc_region(self.txcq_size*16)
        addr = self.txcq.get_absolute_address(0)

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_CQ, # opcode
            0x00000000, # flags
            self.index, # port
            1, # cqn
            0, # eqn
            0, # pd
            self.txcq_log_size, # size
            0, # dboffs
            addr, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))
        print(rsp)

        self.txq = self.driver.pool.alloc_region(self.txq_size*16)
        addr = self.txq.get_absolute_address(0)

        rsp = await self.driver.exec_cmd(struct.pack("<HHLLLLLLLLLLLLL",
            0, # rsvd
            CNDM_CMD_OP_CREATE_SQ, # opcode
            0x00000000, # flags
            self.index, # port
            0, # sqn
            1, # cqn
            0, # pd
            self.txq_log_size, # size
            0, # dboffs
            addr, # base addr
            0, # ptr2
            0, # prod_ptr
            0, # cons_ptr
            0, # rsvd
            0, # rsvd
        ))
        print(rsp)

        self.txq_db_offs = struct.unpack_from("<L", rsp, 7*4)[0]

        await self.refill_rx_buffers()

    async def start_xmit(self, data):
        headroom = 10
        tx_buf = self.driver.alloc_pkt()
        await tx_buf.write(headroom, data)
        index = self.txq_prod & self.txq_mask
        ptr = tx_buf.get_absolute_address(0)
        struct.pack_into('<xxxxLQ', self.txq.mem, 16*index, len(data), ptr+headroom)
        self.tx_info[index] = tx_buf
        self.txq_prod += 1
        await self.hw_regs.write_dword(self.txq_db_offs, self.txq_prod & 0xffff)

    async def recv(self):
        return await self.rx_queue.get()

    async def recv_nowait(self):
        return self.rx_queue.get_nowait()

    def free_tx_desc(self, index):
        pkt = self.tx_info[index]
        self.driver.free_pkt(pkt)
        self.tx_info[index] = None

    def free_tx_buf(self):
        while self.txq_cons != self.txq_prod:
            index = self.txq_cons & self.txq_mask
            self.free_tx_desc(index)
            self.txq_cons += 1

    async def process_tx_cq(self):

        cq_cons_ptr = self.txcq_cons
        cons_ptr = self.txq_cons

        while True:
            cq_index = cq_cons_ptr & self.txcq_mask
            index = cons_ptr & self.txq_mask

            cpl_data = struct.unpack_from("<LLLL", self.txcq.mem, cq_index*16)

            self.log.info("TX CQ index %d data %s", cq_index, cpl_data)

            if bool(cpl_data[-1] & 0x80000000) == bool(cq_cons_ptr & self.txcq_size):
                self.log.info("CQ empty")
                break

            pkt = self.tx_info[index]

            self.free_tx_desc(index)

            cq_cons_ptr += 1
            cons_ptr += 1

        self.txcq_cons = cq_cons_ptr
        self.txq_cons = cons_ptr

    def free_rx_desc(self, index):
        pkt = self.rx_info[index]
        self.driver.free_pkt(pkt)
        self.rx_info[index] = None

    def free_rx_buf(self):
        while self.rxq_cons != self.rxq_prod:
            index = self.rxq_cons & self.rxq_mask
            self.free_rx_desc(index)
            self.rxq_cons += 1

    def prepare_rx_desc(self, index):
        pkt = self.driver.alloc_pkt()
        self.rx_info[index] = pkt

        length = pkt.size
        ptr = pkt.get_absolute_address(0)

        struct.pack_into('<xxxxLQ', self.rxq.mem, 16*index, length, ptr)

    async def refill_rx_buffers(self):
        missing = self.rxq_size - (self.rxq_prod - self.rxq_cons)

        if missing < 8:
            return

        for k in range(missing):
            self.prepare_rx_desc(self.rxq_prod & self.rxq_mask)
            self.rxq_prod += 1

        await self.hw_regs.write_dword(self.rxq_db_offs, self.rxq_prod & 0xffff)

    async def process_rx_cq(self):

        cq_cons_ptr = self.rxcq_cons
        cons_ptr = self.rxq_cons

        while True:
            cq_index = cq_cons_ptr & self.rxcq_mask
            index = cons_ptr & self.rxq_mask

            cpl_data = struct.unpack_from("<LLLL", self.rxcq.mem, cq_index*16)

            self.log.info("RX CQ index %d data %s", cq_index, cpl_data)

            if bool(cpl_data[-1] & 0x80000000) == bool(cq_cons_ptr & self.rxcq_size):
                self.log.info("CQ empty")
                break

            pkt = self.rx_info[index]
            length = cpl_data[1]

            data = pkt[:length]

            self.log.info("Packet: %s", data)

            self.rx_queue.put_nowait(data)

            self.free_rx_desc(index)

            cq_cons_ptr += 1
            cons_ptr += 1

        self.rxcq_cons = cq_cons_ptr
        self.rxq_cons = cons_ptr

        await self.refill_rx_buffers()

    async def interrupt_handler(self):
        self.log.info("Interrupt")
        await self.process_rx_cq()
        await self.process_tx_cq()


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

    async def init_pcie_dev(self, dev):
        self.dev = dev
        self.pool = dev.rc.mem_pool

        await dev.enable_device()
        await dev.set_master()
        await dev.alloc_irq_vectors(32, 32)

        self.hw_regs = dev.bar_window[0]

        await self.init_common()

    async def init_common(self):
        self.port_count = await self.hw_regs.read_dword(0x0100)
        self.port_offset = await self.hw_regs.read_dword(0x0104)
        self.port_stride = await self.hw_regs.read_dword(0x0108)

        self.log.info("Port count: %d", self.port_count)
        self.log.info("Port offset: 0x%x", self.port_offset)
        self.log.info("Port stride: 0x%x", self.port_stride)

        for k in range(self.port_count):
            port = Port(self, k)
            await port.init()
            self.dev.request_irq(k, port.interrupt_handler)

            self.ports.append(port)

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
