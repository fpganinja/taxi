#!/usr/bin/env python
# SPDX-License-Identifier: CERN-OHL-S-2.0
"""

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

"""

import ipaddress
import logging
import os
import socket
import struct

from enum import IntFlag

import scapy.config
import scapy.utils
import scapy.pton_ntop
from scapy.layers.l2 import Ether, Dot1Q, Dot1AD, ARP
from scapy.layers.inet import IP, ICMP, UDP, TCP
from scapy.layers.inet6 import IPv6, ICMPv6ND_NS

import cocotb_test.simulator

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.regression import TestFactory

from cocotbext.axi import AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamFrame


# don't hide ports
scapy.config.conf.noenum.add(TCP.sport, TCP.dport)
scapy.config.conf.noenum.add(UDP.sport, UDP.dport)


hash_key = [
    0x6d, 0x5a, 0x56, 0xda, 0x25, 0x5b, 0x0e, 0xc2,
    0x41, 0x67, 0x25, 0x3d, 0x43, 0xa3, 0x8f, 0xb0,
    0xd0, 0xca, 0x2b, 0xcb, 0xae, 0x7b, 0x30, 0xb4,
    0x77, 0xcb, 0x2d, 0xa3, 0x80, 0x30, 0xf2, 0x0c,
    0x6a, 0x42, 0xb7, 0x3b, 0xbe, 0xac, 0x01, 0xfa
]


def hash_toep(data, key=hash_key):
    k = len(key)*8-32
    key = int.from_bytes(key, 'big')

    h = 0

    for b in data:
        for i in range(8):
            if b & 0x80 >> i:
                h ^= (key >> k) & 0xffffffff
            k -= 1

    return h


def tuple_pack(src_ip, dest_ip, src_port=None, dest_port=None):
    src_ip = ipaddress.ip_address(src_ip)
    dest_ip = ipaddress.ip_address(dest_ip)
    data = b''
    if src_ip.version == 6 or dest_ip.version == 6:
        data += src_ip.packed
        data += dest_ip.packed
    else:
        data += src_ip.packed
        data += dest_ip.packed
    if src_port is not None and dest_port is not None:
        data += src_port.to_bytes(2, 'big') + dest_port.to_bytes(2, 'big')
    return data


class ParserFlags(IntFlag):
    FLG_VLAN_S = 2**1
    FLG_VLAN_C = 2**2
    FLG_IPV4 = 2**3
    FLG_IPV6 = 2**4
    FLG_ARP = 2**6
    FLG_ICMP = 2**7
    FLG_TCP = 2**8
    FLG_UDP = 2**9
    FLG_AH = 2**10
    FLG_ESP = 2**11
    FLG_EN = 2**31


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 3.2, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_meta), dut.clk, dut.rst)
        self.sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_pkt), dut.clk, dut.rst)

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


async def run_test(dut):

    tb = TB(dut)

    await tb.reset()

    test_pkts = []

    payload = bytearray(range(64))

    ip_id = 0

    l2hdrs = []

    # Ethernet
    eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
    l2hdrs.append(eth)

    # Ethernet with 802.1Q VLAN
    eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
    vlan = Dot1Q(vlan=123)
    l2hdrs.append(eth / vlan)

    # Ethernet with 802.1Q QinQ
    eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
    vlan = Dot1AD(vlan=456)
    l2hdrs.append(eth / vlan)

    # Ethernet with 802.1Q QinQ and VLAN
    eth = Ether(src='5A:51:52:53:54:55', dst='DA:D1:D2:D3:D4:D5')
    vlan = Dot1AD(vlan=456) / Dot1Q(vlan=123)
    l2hdrs.append(eth / vlan)

    for l2hdr in l2hdrs:

        # Raw ethernet
        test_pkts.append(l2hdr / payload)

        # ARP
        arp = ARP(hwtype=1, ptype=0x0800, hwlen=6, plen=4, op=2,
            hwsrc='5A:51:52:53:54:55', psrc='192.168.1.100',
            hwdst='DA:D1:D2:D3:D4:D5', pdst='192.168.1.101')
        test_pkts.append(l2hdr / arp)

        l3hdrs = []

        # IPv4
        ip = IP(src='10.1.0.1', dst='10.2.0.1', id=ip_id)
        l3hdrs.append(ip)

        # IPv6
        ip6 = IPv6(src='fd12:3456:789a:1::1', dst='fd12:3456:789a:2::1', fl=ip_id)
        l3hdrs.append(ip6)

        for l3hdr in l3hdrs:

            l3hdr = l3hdr.copy()
            if IP in l3hdr:
                l3hdr.id = ip_id
            if IPv6 in l3hdr:
                l3hdr.fl = ip_id

            # IP (empty)
            if IP in l3hdr:
                hdr = l3hdr.copy()
                hdr.proto = 59
                test_pkts.append(l2hdr / hdr)
            else:
                test_pkts.append(l2hdr / l3hdr)

            # IP (unsupported protocol)
            if IP in l3hdr:
                hdr = l3hdr.copy()
                hdr.proto = 59
                test_pkts.append(l2hdr / hdr / payload)
            else:
                test_pkts.append(l2hdr / l3hdr / payload)

            if IP in l3hdr:
                # ICMP
                icmp = ICMP(type=8)
                test_pkts.append(l2hdr / l3hdr / icmp / payload)

            if IPv6 in l3hdr:
                # ICMPv6 / NDP
                ns = ICMPv6ND_NS(tgt='::')
                test_pkts.append(l2hdr / l3hdr / ns)

            # UDP (empty)
            udp = UDP(sport=ip_id, dport=0x1000+ip_id)
            test_pkts.append(l2hdr / l3hdr / udp)

            # UDP
            udp = UDP(sport=ip_id, dport=0x1000+ip_id)
            test_pkts.append(l2hdr / l3hdr / udp / payload)

            # TCP (empty)
            tcp = TCP(sport=ip_id, dport=0x1000+ip_id, seq=54321, ack=12345, window=8192)
            test_pkts.append(l2hdr / l3hdr / tcp)

            # TCP
            tcp = TCP(sport=ip_id, dport=0x1000+ip_id, seq=54321, ack=12345, window=8192)
            test_pkts.append(l2hdr / l3hdr / tcp / payload)

            ip_id += 1

    for pkt in test_pkts:
        tb.log.info("Packet: %r", pkt)

        pkt_b = pkt.build()

        # assemble metadata
        flags = ParserFlags.FLG_EN
        meta = bytearray(8*16)

        eth_type = pkt[Ether].type
        payload = bytes(pkt[Ether].payload)
        hdr_size = len(pkt[Ether]) - len(payload)

        # VLAN tags
        if Dot1AD in pkt:
            flags |= ParserFlags.FLG_VLAN_S
            tag = pkt[Dot1AD].vlan
            struct.pack_into('>H', meta, 16, tag)
            eth_type = pkt[Dot1AD].type
            payload = bytes(pkt[Dot1AD].payload)
            hdr_size += len(pkt[Dot1AD]) - len(payload)

        if Dot1Q in pkt:
            flags |= ParserFlags.FLG_VLAN_C
            tag = pkt[Dot1Q].vlan
            struct.pack_into('>H', meta, 18, tag)
            eth_type = pkt[Dot1Q].type
            payload = bytes(pkt[Dot1Q].payload)
            hdr_size += len(pkt[Dot1Q]) - len(payload)

        # Ethernet header
        meta[24:30] = scapy.utils.mac2str(pkt[Ether].dst)
        meta[32:38] = scapy.utils.mac2str(pkt[Ether].src)
        struct.pack_into('>H', meta, 38, eth_type)

        # IPv4
        if IP in pkt:
            flags |= ParserFlags.FLG_IPV4

            meta[64:68] = scapy.utils.inet_aton(pkt[IP].dst)
            meta[80:84] = scapy.utils.inet_aton(pkt[IP].src)

            struct.pack_into('BB', meta, 56, pkt[IP].proto, pkt[IP].ttl)
            struct.pack_into('<L', meta, 60, pkt[IP].id)

            payload = bytes(pkt[IP].payload)
            hdr_size += len(pkt[IP]) - len(payload)

        # IPv6
        if IPv6 in pkt:
            flags |= ParserFlags.FLG_IPV6

            meta[64:80] = scapy.pton_ntop.inet_pton(socket.AF_INET6, pkt[IPv6].dst)
            meta[80:96] = scapy.pton_ntop.inet_pton(socket.AF_INET6, pkt[IPv6].src)

            struct.pack_into('BB', meta, 56, pkt[IPv6].nh, pkt[IPv6].hlim)
            struct.pack_into('<L', meta, 60, pkt[IPv6].fl)

            payload = bytes(pkt[IPv6].payload)
            hdr_size += len(pkt[IPv6]) - len(payload)

        # TCP
        if TCP in pkt:
            flags |= ParserFlags.FLG_TCP

            struct.pack_into('<HHB', meta, 96, pkt[TCP].dport, pkt[TCP].sport, int(pkt[TCP].flags))
            struct.pack_into('<HH', meta, 104, pkt[TCP].window, pkt[TCP].urgptr)
            struct.pack_into('<LL', meta, 112, pkt[TCP].seq, pkt[TCP].ack)

            payload = bytes(pkt[TCP].payload)
            hdr_size += len(pkt[TCP]) - len(payload)

        # UDP
        if UDP in pkt:
            flags |= ParserFlags.FLG_UDP

            struct.pack_into('<HH', meta, 96, pkt[UDP].dport, pkt[UDP].sport)

            payload = bytes(pkt[UDP].payload)
            hdr_size += len(pkt[UDP]) - len(payload)

        payload_sum = ~scapy.utils.checksum(payload) & 0xffff

        struct.pack_into('<LHH', meta, 0, flags, len(payload), payload_sum)

        tb.log.info("Metadata: %r", meta)

        await tb.source.send(AxiStreamFrame(meta))

        hdr = await tb.sink.recv()

        tb.log.info("Header: %r", hdr)

        rx_pkt = Ether(bytes(hdr))

        tb.log.info("Header (decoded): %r", rx_pkt)
        tb.log.info("Packet (decoded): %r", Ether(bytes(hdr)+payload))
        tb.log.info("Reference (decoded): %r", Ether(pkt_b))

        assert len(hdr) == hdr_size
        assert hdr.tdata == pkt_b[0:hdr_size]

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)


if getattr(cocotb, 'top', None) is not None:

    factory = TestFactory(run_test)
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


def test_zircon_ip_tx_deparse(request):
    dut = "zircon_ip_tx_deparse"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = module

    verilog_sources = [
        os.path.join(tests_dir, f"{toplevel}.sv"),
        os.path.join(rtl_dir, f"{dut}.sv"),
        os.path.join(taxi_src_dir, "axis", "rtl", "taxi_axis_if.sv"),
    ]

    verilog_sources = process_f_files(verilog_sources)

    parameters = {}

    parameters['DATA_W'] = 32

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
