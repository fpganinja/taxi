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
from scapy.layers.inet import IPOption_MTU_Probe
from scapy.layers.inet6 import IPv6, ICMPv6ND_NS
from scapy.layers.inet6 import IPv6ExtHdrFragment, IPv6ExtHdrHopByHop, RouterAlert

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
    FLG_FRAG = 2**5
    FLG_ARP = 2**6
    FLG_ICMP = 2**7
    FLG_TCP = 2**8
    FLG_UDP = 2**9
    FLG_AH = 2**10
    FLG_ESP = 2**11
    FLG_IP_OPT_PRSNT = 2**16
    FLG_TCP_OPT_PRSNT = 2**17
    FLG_L3_BAD_CKSUM = 2**24
    FLG_L4_BAD_LEN = 2**25
    FLG_PARSE_DONE = 2**31


class TB:
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk, 3.2, units="ns").start())

        self.source = AxiStreamSource(AxiStreamBus.from_entity(dut.s_axis_pkt), dut.clk, dut.rst)
        self.sink = AxiStreamSink(AxiStreamBus.from_entity(dut.m_axis_meta), dut.clk, dut.rst)

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

        # IPv4 (fragmented)
        ip = IP(src='10.1.0.1', dst='10.2.0.1', flags=1, id=ip_id)
        l3hdrs.append(ip)

        # IPv4 with options
        ip = IP(src='10.1.0.1', dst='10.2.0.1', id=ip_id, options=[IPOption_MTU_Probe()])
        l3hdrs.append(ip)

        # IPv6
        ip6 = IPv6(src='fd12:3456:789a:1::1', dst='fd12:3456:789a:2::1', fl=ip_id)
        l3hdrs.append(ip6)

        # IPv6 with extensions (fragmented)
        ip6 = IPv6(src='fd12:3456:789a:1::1', dst='fd12:3456:789a:2::1', fl=ip_id)
        frag = IPv6ExtHdrFragment()
        l3hdrs.append(ip6 / frag)

        # IPv6 with extensions
        ip6 = IPv6(src='fd12:3456:789a:1::1', dst='fd12:3456:789a:2::1', fl=ip_id)
        hbh = IPv6ExtHdrHopByHop(options=[RouterAlert()])
        l3hdrs.append(ip6 / hbh)

        # IPv6 with extensions 2
        ip6 = IPv6(src='fd12:3456:789a:1::1', dst='fd12:3456:789a:2::1', fl=ip_id)
        hbh = IPv6ExtHdrHopByHop(options=[RouterAlert(), RouterAlert(), RouterAlert(), RouterAlert()])
        l3hdrs.append(ip6 / hbh)

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

            # TCP with options (empty)
            tcp = TCP(sport=ip_id, dport=0x1000+ip_id, seq=54321, ack=12345, window=8192, options=[('Timestamp',(0,0))])
            test_pkts.append(l2hdr / l3hdr / tcp)

            # TCP
            tcp = TCP(sport=ip_id, dport=0x1000+ip_id, seq=54321, ack=12345, window=8192)
            test_pkts.append(l2hdr / l3hdr / tcp / payload)

            # TCP with options
            tcp = TCP(sport=ip_id, dport=0x1000+ip_id, seq=54321, ack=12345, window=8192, options=[('Timestamp',(0,0))])
            test_pkts.append(l2hdr / l3hdr / tcp / payload)

            ip_id += 1

    for pkt in test_pkts:
        tb.log.info("Packet: %r", pkt)

        pkt_b = pkt.build()
        hdr = pkt_b[0:128]

        rx_csum = ~scapy.utils.checksum(bytes(pkt_b[14:])) & 0xffff

        await tb.source.send(AxiStreamFrame(hdr))

        meta = await tb.sink.recv()

        tb.log.info("Metadata: %r", meta)

        flags, payload_len, pkt_sum = struct.unpack_from('<LHH', meta.tdata, 0)
        flags = ParserFlags(flags)

        tb.log.info("Flags: 0x%08x (%r)", flags, flags)
        tb.log.info("Payload length: %d", payload_len)
        tb.log.info("Packet checksum: 0x%04x", pkt_sum)

        rss_hash, l3_offset, l4_offset, payload_offset = struct.unpack_from('<LBBxB', meta.tdata, 8)

        tb.log.info("RSS hash: 0x%08x", rss_hash)
        tb.log.info("L3 offset: %d (%d)", l3_offset*4+2, l3_offset)
        tb.log.info("L4 offset: %d (%d)", l4_offset*4+2, l4_offset)
        tb.log.info("Payload offset: %d (%d)", payload_offset*4+2, payload_offset)

        s_tag, c_tag = struct.unpack_from('>HH', meta.tdata, 16)

        tb.log.info("VLAN S-tag: 0x%04x", s_tag)
        tb.log.info("VLAN C-tag: 0x%04x", c_tag)

        eth_dst = meta.tdata[24:30]
        eth_src = meta.tdata[32:38]
        eth_type = struct.unpack_from('>H', meta.tdata, 38)[0]

        tb.log.info("Eth dest: %s (%r)", scapy.utils.str2mac(eth_dst), eth_dst)
        tb.log.info("Eth src: %s (%r)", scapy.utils.str2mac(eth_src), eth_src)
        tb.log.info("Eth type: 0x%04x", eth_type)

        assert scapy.utils.mac2str(pkt[Ether].dst) == eth_dst
        assert scapy.utils.mac2str(pkt[Ether].src) == eth_src

        ref_type = pkt[Ether].type

        # VLAN tags
        if Dot1AD in pkt:
            tag = struct.unpack_from('>H', meta.tdata, 16)[0]
            tb.log.info("VLAN S-tag: 0x%04x", tag)
            ref_type = pkt[Dot1AD].type

            assert ParserFlags.FLG_VLAN_S in flags
            assert pkt[Dot1AD].vlan == tag & 0x3ff
        else:
            assert ParserFlags.FLG_VLAN_S not in flags

        if Dot1Q in pkt:
            tag = struct.unpack_from('>H', meta.tdata, 18)[0]
            tb.log.info("VLAN C-tag: 0x%04x", tag)
            ref_type = pkt[Dot1Q].type

            assert ParserFlags.FLG_VLAN_C in flags
            assert pkt[Dot1Q].vlan == tag & 0x3ff
        else:
            assert ParserFlags.FLG_VLAN_C not in flags

        assert ref_type == eth_type

        # IPv4
        if IP in pkt:
            ip_dst = meta.tdata[64:68]
            ip_src = meta.tdata[80:84]

            tb.log.info("IPv4 dest: %s (%r)", scapy.utils.inet_ntoa(ip_dst), ip_dst)
            tb.log.info("IPv4 src: %s (%r)", scapy.utils.inet_ntoa(ip_src), ip_src)

            assert ParserFlags.FLG_IPV4 in flags
            assert ParserFlags.FLG_L3_BAD_CKSUM not in flags

            assert scapy.utils.inet_aton(pkt[IP].src) == ip_src
            assert scapy.utils.inet_aton(pkt[IP].dst) == ip_dst

            if TCP in pkt and not (pkt[IP].flags & 1 or pkt[IP].frag):
                hash_val = hash_toep(tuple_pack(pkt[IP].src, pkt[IP].dst, pkt[TCP].sport, pkt[TCP].dport), hash_key)
                assert hash_val == rss_hash
            elif UDP in pkt and not (pkt[IP].flags & 1 or pkt[IP].frag):
                hash_val = hash_toep(tuple_pack(pkt[IP].src, pkt[IP].dst, pkt[UDP].sport, pkt[UDP].dport), hash_key)
                assert hash_val == rss_hash
            else:
                hash_val = hash_toep(tuple_pack(pkt[IP].src, pkt[IP].dst), hash_key)
                assert hash_val == rss_hash
        else:
            assert ParserFlags.FLG_IPV4 not in flags
            assert ParserFlags.FLG_L3_BAD_CKSUM not in flags

        # IPv6
        if IPv6 in pkt:
            ip_dst = meta.tdata[64:80]
            ip_src = meta.tdata[80:96]

            tb.log.info("IPv6 dest: %s (%r)", scapy.pton_ntop.inet_ntop(socket.AF_INET6, ip_dst), ip_dst)
            tb.log.info("IPv6 src: %s (%r)", scapy.pton_ntop.inet_ntop(socket.AF_INET6, ip_src), ip_src)

            assert ParserFlags.FLG_IPV6 in flags
            assert ParserFlags.FLG_L3_BAD_CKSUM not in flags

            assert scapy.pton_ntop.inet_pton(socket.AF_INET6, pkt[IPv6].src) == ip_src
            assert scapy.pton_ntop.inet_pton(socket.AF_INET6, pkt[IPv6].dst) == ip_dst

            if TCP in pkt and IPv6ExtHdrFragment not in pkt:
                hash_val = hash_toep(tuple_pack(pkt[IPv6].src, pkt[IPv6].dst, pkt[TCP].sport, pkt[TCP].dport), hash_key)
                assert hash_val == rss_hash
            elif UDP in pkt and IPv6ExtHdrFragment not in pkt:
                hash_val = hash_toep(tuple_pack(pkt[IPv6].src, pkt[IPv6].dst, pkt[UDP].sport, pkt[UDP].dport), hash_key)
                assert hash_val == rss_hash
            else:
                hash_val = hash_toep(tuple_pack(pkt[IPv6].src, pkt[IPv6].dst), hash_key)
                assert hash_val == rss_hash
        else:
            assert ParserFlags.FLG_IPV6 not in flags
            assert ParserFlags.FLG_L3_BAD_CKSUM not in flags

        # ARP
        if ARP in pkt:
            assert ParserFlags.FLG_ARP in flags
        else:
            assert ParserFlags.FLG_ARP not in flags

        if ParserFlags.FLG_FRAG not in flags:
            # TCP
            if TCP in pkt:
                dp, sp, tcp_flags = struct.unpack_from('<HHB', meta.tdata, 96)
                tb.log.info("TCP source port %d, dest port %d", sp, dp)
                tb.log.info("TCP flags 0x%x", tcp_flags)

                wnd, urg = struct.unpack_from('<HH', meta.tdata, 104)

                tb.log.info("TCP window %d", wnd)
                tb.log.info("TCP urgent pointer %d", urg)

                seq, ack = struct.unpack_from('<LL', meta.tdata, 112)

                tb.log.info("TCP seq %d", seq)
                tb.log.info("TCP ack %d", ack)

                assert ParserFlags.FLG_TCP in flags
                assert ParserFlags.FLG_L4_BAD_LEN not in flags
                assert pkt[TCP].dport == dp
                assert pkt[TCP].sport == sp
                assert pkt[TCP].flags == tcp_flags
                assert pkt[TCP].window == wnd
                assert pkt[TCP].urgptr == urg
                assert pkt[TCP].ack == ack
                assert pkt[TCP].seq == seq

                tb.log.info("Payload len %d, actual %d", payload_len, len(pkt[TCP].payload))
                tb.log.info("Packet sum 0x%04x, actual 0x%04x", rx_csum, pkt_sum)

                assert payload_len == len(pkt[TCP].payload)
                assert rx_csum == pkt_sum
            else:
                assert ParserFlags.FLG_TCP not in flags
                assert ParserFlags.FLG_L4_BAD_LEN not in flags

            # UDP
            if UDP in pkt:
                dp, sp = struct.unpack_from('<HH', meta.tdata, 96)
                tb.log.info("UDP source port %d, dest port %d", sp, dp)

                assert ParserFlags.FLG_UDP in flags
                assert ParserFlags.FLG_L4_BAD_LEN not in flags
                assert pkt[UDP].dport == dp
                assert pkt[UDP].sport == sp

                tb.log.info("Payload len %d, actual %d", payload_len, len(pkt[UDP].payload))
                tb.log.info("Packet sum 0x%04x, actual 0x%04x", rx_csum, pkt_sum)

                assert payload_len == len(pkt[UDP].payload)
                assert rx_csum == pkt_sum
            else:
                assert ParserFlags.FLG_UDP not in flags
                assert ParserFlags.FLG_L4_BAD_LEN not in flags
        else:
            assert ParserFlags.FLG_TCP not in flags
            assert ParserFlags.FLG_UDP not in flags
            assert ParserFlags.FLG_L4_BAD_LEN not in flags

        # check offsets
        layer = pkt
        offset = 0

        while layer:
            if isinstance(layer, IP) or isinstance(layer, IPv6):
                assert offset == l3_offset*4+2

            if ParserFlags.FLG_FRAG not in flags:
                if isinstance(layer, TCP) or isinstance(layer, UDP):
                    assert offset == l4_offset*4+2
                    assert offset+len(layer)-len(layer.payload) == payload_offset*4+2

            if not layer.payload:
                break

            offset += len(layer)-len(layer.payload)
            layer = layer.payload

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


def test_zircon_ip_rx_parse(request):
    dut = "zircon_ip_rx_parse"
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
    parameters['META_W'] = 64
    parameters['IPV6_EN'] = 1
    parameters['HASH_EN'] = 1

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
