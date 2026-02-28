// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Zircon IP stack - RX parser
 */
module zircon_ip_rx_parse #
(
    parameter logic IPV6_EN = 1'b1,
    parameter logic HASH_EN = 1'b1
)
(
    input  wire logic  clk,
    input  wire logic  rst,

    /*
     * Packet header input
     */
    taxi_axis_if.snk   s_axis_pkt,

    /*
     * Packet metadata output
     */
    taxi_axis_if.src   m_axis_meta
);

// Metadata output (64 bit blocks):
// 00: flags / payload len, pkt sum
// 01: RSS hash / header and payload offsets
// 02: vlan tags / dscp, ecn
// 03: eth dst
// 04: eth src, ethtype
// 05: protos/hdrs with offsets
// 06: protos/hdrs with offsets
// 07: ip id/fl / protocol, ttl/hl
// 08: ipv6 dst
// 09: ipv6 dst
// 10: ipv6 src
// 11: ipv6 src
// 12: l4 ports / tcp flags
// 13: tcp wnd/urg
// 14: tcp seq/ack
// 15: 

localparam DATA_W = s_axis_pkt.DATA_W;
localparam META_W = m_axis_meta.DATA_W;

// check configuration
if (DATA_W != 32)
    $fatal(0, "Error: Interface width must be 32 (instance %m)");

if (s_axis_pkt.KEEP_W * 8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (META_W != 64)
    $fatal(0, "Error: Interface width must be 64 (instance %m)");

if (m_axis_meta.KEEP_W * 8 != META_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

typedef enum logic [15:0] {
    ETHERTYPE_IPV4 = 16'h0800,
    ETHERTYPE_ARP = 16'h0806,
    ETHERTYPE_VLAN_C = 16'h8100,
    ETHERTYPE_VLAN_S = 16'h88A8,
    ETHERTYPE_IPV6 = 16'h86DD,
    ETHERTYPE_PBB = 16'h88E7,
    ETHERTYPE_PTP = 16'h88F7,
    ETHERTYPE_ROCE = 16'h8915
} ethertype_t;

typedef enum logic [7:0] {
    PROTO_IPV6_HOPOPT = 8'd0,
    PROTO_ICMP = 8'd1,
    PROTO_IGMP = 8'd2,
    PROTO_IPIP = 8'd4,
    PROTO_TCP = 8'd6,
    PROTO_UDP = 8'd17,
    PROTO_IPV6 = 8'd41,
    PROTO_IPV6_ROUTE = 8'd43,
    PROTO_IPV6_FRAG = 8'd44,
    PROTO_GRE = 8'd47,
    PROTO_ESP = 8'd50,
    PROTO_AH = 8'd51,
    PROTO_IPV6_ICMP = 8'd58,
    PROTO_IPV6_NONXT = 8'd59,
    PROTO_IPV6_OPTS = 8'd60,
    PROTO_HIP = 8'd139,
    PROTO_SHIM6 = 8'd140,
    PROTO_253 = 8'd253,
    PROTO_254 = 8'd254
} proto_t;

localparam
    FLG_VLAN_S = 1,
    FLG_VLAN_C = 2,
    FLG_IPV4 = 3,
    FLG_IPV6 = 4,
    FLG_FRAG = 5,
    FLG_ARP = 6,
    FLG_ICMP = 7,
    FLG_TCP = 8,
    FLG_UDP = 9,
    FLG_AH = 10,
    FLG_ESP = 11,
    FLG_L3_OPT_PRSNT = 16,
    FLG_L4_OPT_PRSNT = 17,
    FLG_L3_BAD_CKSUM = 24,
    FLG_L4_BAD_LEN = 25,
    FLG_PARSE_DONE = 31;

typedef enum logic [4:0] {
    STATE_IDLE,
    STATE_ETH_1,
    STATE_ETH_2,
    STATE_ETH_3,
    STATE_VLAN_1,
    STATE_VLAN_2,
    STATE_IPV4_1,
    STATE_IPV4_2,
    STATE_IPV4_3,
    STATE_IPV4_4,
    STATE_IPV4_5,
    STATE_IPV4_6,
    STATE_IPV6_1,
    STATE_IPV6_2,
    STATE_IPV6_3,
    STATE_IPV6_4,
    STATE_IPV6_5,
    STATE_IPV6_6,
    STATE_IPV6_7,
    STATE_IPV6_8,
    STATE_IPV6_9,
    STATE_IPV6_10,
    STATE_EXT_HDR_1,
    STATE_TCP_1,
    STATE_TCP_2,
    STATE_TCP_3,
    STATE_TCP_4,
    STATE_TCP_5,
    STATE_UDP_1,
    STATE_UDP_2,
    STATE_FINISH_1,
    STATE_FINISH_2
} state_t;

state_t state_reg = STATE_IDLE, state_next;

logic frame_reg = 1'b0, frame_next;
logic run_reg = 1'b0, run_next;
logic [31:0] flag_reg = '0, flag_next;
logic [7:0] next_hdr_reg = '0, next_hdr_next;
logic [8:0] hdr_len_reg = '0, hdr_len_next;
logic [7:0] offset_reg = '0, offset_next;
logic [7:0] l3_offset_reg = '0, l3_offset_next;
logic [7:0] l4_offset_reg = '0, l4_offset_next;
logic [7:0] payload_offset_reg = '0, payload_offset_next;
logic [15:0] payload_len_reg = '0, payload_len_next;

logic [20:0] ip_hdr_cksum_reg = '0, ip_hdr_cksum_next;
logic [23:0] corr_cksum_reg = '0, corr_cksum_next;

logic s_axis_pkt_tready_reg = 1'b0, s_axis_pkt_tready_next;

// metadata RAM
localparam META_AW = 5;

logic [31:0] meta_ram_a[2**META_AW];
logic [31:0] meta_ram_a_wr_data;
logic [3:0] meta_ram_a_wr_strb;
logic [META_AW-1:0] meta_ram_a_wr_addr;
logic meta_ram_a_wr_en;
logic [31:0] meta_ram_a_rd_data_reg = '0;
logic [META_AW-1:0] meta_ram_a_rd_addr;
logic meta_ram_a_rd_en;

logic [31:0] meta_ram_b[2**META_AW];
logic [31:0] meta_ram_b_wr_data;
logic [3:0] meta_ram_b_wr_strb;
logic [META_AW-1:0] meta_ram_b_wr_addr;
logic meta_ram_b_wr_en;
logic [31:0] meta_ram_b_rd_data_reg = '0;
logic [META_AW-1:0] meta_ram_b_rd_addr;
logic meta_ram_b_rd_en;

logic [1:0] meta_wr_slot_reg = '0, meta_wr_slot_next;
logic [1:0] meta_rd_slot_reg = '0, meta_rd_slot_next;
logic [META_AW-1-1:0] meta_rd_ptr_reg = '0, meta_rd_ptr_next;

logic meta_rd_data_valid_reg = 1'b0, meta_rd_data_valid_next;
logic meta_rd_data_last_reg = 1'b0, meta_rd_data_last_next;

wire meta_empty = meta_wr_slot_reg == meta_rd_slot_reg;
wire meta_full = meta_wr_slot_reg == (meta_rd_slot_reg ^ 2'b10);

assign s_axis_pkt.tready = s_axis_pkt_tready_reg;

assign m_axis_meta.tdata = {meta_ram_b_rd_data_reg, meta_ram_a_rd_data_reg};
assign m_axis_meta.tkeep = '1;
assign m_axis_meta.tstrb = m_axis_meta.tkeep;
assign m_axis_meta.tid = '0;
assign m_axis_meta.tdest = '0;
assign m_axis_meta.tuser = '0;
assign m_axis_meta.tlast = meta_rd_data_last_reg;
assign m_axis_meta.tvalid = meta_rd_data_valid_reg;

// offset data for proper 4-byte alignment after Ethernet header
wire [31:0] pkt_data = {s_axis_pkt.tdata[15:0], pkt_data_reg};
wire [31:0] pkt_data_be = {pkt_data[7:0], pkt_data[15:8], pkt_data[23:16], pkt_data[31:24]};
logic [15:0] pkt_data_reg = 0;

// Toeplitz flow hash computation
logic hash_reset;
logic hash_step;
wire [31:0] hash_value;

if (HASH_EN) begin : rss_hash

    logic [31:0] key_rom[10] = '{
        32'h6d5a56da, 32'h255b0ec2, 32'h4167253d, 32'h43a38fb0, 32'hd0ca2bcb,
        32'hae7b30b4, 32'h77cb2da3, 32'h8030f20c, 32'h6a42b73b, 32'hbeac01fa
    };

    logic [3:0] key_ptr_reg = '0;
    logic [63:0] key_reg = '0;
    logic [31:0] hash_reg = '0;
    logic hash_rst_reg = 1'b0;

    assign hash_value = hash_reg;

    function [31:0] hash_toep32(input [31:0] data, input [63:0] key);
        hash_toep32 = '0;
        for (integer i = 0; i < 32; i = i + 1) begin
            if (data[31-i]) begin
                hash_toep32 = hash_toep32 ^ key[32-i +: 32];
            end
        end
    endfunction

    always_ff @(posedge clk) begin
        if (hash_step) begin
            hash_reg <= hash_reg ^ hash_toep32(pkt_data_be, key_reg);
        end

        if (hash_rst_reg || hash_step) begin
            key_reg[63:32] <= key_reg[31:0];
            key_reg[31:0] <= key_rom[key_ptr_reg];
            key_ptr_reg <= key_ptr_reg + 1;
            if (key_ptr_reg != 0) begin
                hash_rst_reg = 1'b0;
            end
        end

        if (hash_reset) begin
            hash_reg <= '0;
            key_ptr_reg <= '0;
            hash_rst_reg = 1'b1;
        end
    end

end else begin

    assign hash_value = '0;

end

// handle ethertype
logic [4:0] eth_type_state;
logic [31:0] eth_type_flags;

always_comb begin
    eth_type_flags = '0;
    if (pkt_data_be[15:0] == ETHERTYPE_VLAN_S) begin
        // S-tag
        eth_type_state = STATE_VLAN_1;
    end else if (pkt_data_be[15:0] == ETHERTYPE_VLAN_C) begin
        // C-tag
        eth_type_state = STATE_VLAN_2;
    end else if (pkt_data_be[15:0] == ETHERTYPE_ARP) begin
        // ARP
        eth_type_flags[FLG_ARP] = 1'b1;
        eth_type_state = STATE_FINISH_1;
    end else if (pkt_data_be[15:0] == ETHERTYPE_IPV4) begin
        // IPv4
        eth_type_state = STATE_IPV4_1;
    end else if (pkt_data_be[15:0] == ETHERTYPE_IPV6) begin
        // IPv6
        eth_type_state = STATE_IPV6_1;
    end else begin
        eth_type_state = STATE_FINISH_1;
    end
end

// handle next header
logic [4:0] next_hdr_state;
logic [31:0] next_hdr_flags;

always_comb begin
    next_hdr_flags = '0;
    case (next_hdr_reg)
        PROTO_IPV6_HOPOPT: begin
            next_hdr_flags[FLG_L3_OPT_PRSNT] = 1'b1;
            next_hdr_state = STATE_EXT_HDR_1;
        end
        PROTO_IPV6_ROUTE: begin
            next_hdr_flags[FLG_L3_OPT_PRSNT] = 1'b1;
            next_hdr_state = STATE_EXT_HDR_1;
        end
        PROTO_IPV6_FRAG: begin
            next_hdr_flags[FLG_FRAG] = 1'b1;
            next_hdr_state = STATE_EXT_HDR_1;
        end
        PROTO_IPV6_OPTS: begin
            next_hdr_flags[FLG_L3_OPT_PRSNT] = 1'b1;
            next_hdr_state = STATE_EXT_HDR_1;
        end
        PROTO_IPV6_NONXT: next_hdr_state = STATE_FINISH_1;
        PROTO_IPV6_ICMP: begin
            next_hdr_flags[FLG_ICMP] = 1'b1;
            next_hdr_state = STATE_FINISH_1;
        end
        PROTO_ICMP: begin
            next_hdr_flags[FLG_ICMP] = 1'b1;
            next_hdr_state = STATE_FINISH_1;
        end
        PROTO_AH: begin
            next_hdr_flags[FLG_AH] = 1'b1;
            next_hdr_state = STATE_EXT_HDR_1;
        end
        PROTO_ESP: begin
            next_hdr_flags[FLG_ESP] = 1'b1;
            next_hdr_state = STATE_FINISH_1;
        end
        PROTO_HIP: next_hdr_state = STATE_EXT_HDR_1;
        PROTO_SHIM6: next_hdr_state = STATE_EXT_HDR_1;
        PROTO_253: next_hdr_state = STATE_EXT_HDR_1;
        PROTO_254: next_hdr_state = STATE_EXT_HDR_1;
        default: begin
            if (flag_reg[FLG_FRAG]) begin
                // fragmented packet, do not parse further
                next_hdr_state = STATE_FINISH_1;
            end else begin
                case (next_hdr_reg)
                    PROTO_TCP: next_hdr_state = STATE_TCP_1;
                    PROTO_UDP: next_hdr_state = STATE_UDP_1;
                    default: next_hdr_state = STATE_FINISH_1;
                endcase
            end
        end
    endcase
end

always_comb begin
    state_next = STATE_IDLE;

    hash_reset = 1'b0;
    hash_step = 1'b0;

    frame_next = frame_reg;
    run_next = run_reg;
    flag_next = flag_reg;
    next_hdr_next = next_hdr_reg;
    hdr_len_next = hdr_len_reg;
    offset_next = offset_reg;
    l3_offset_next = l3_offset_reg;
    l4_offset_next = l4_offset_reg;
    payload_offset_next = payload_offset_reg;
    payload_len_next = payload_len_reg;

    ip_hdr_cksum_next = ip_hdr_cksum_reg;
    corr_cksum_next = corr_cksum_reg;

    s_axis_pkt_tready_next = s_axis_pkt_tready_reg;

    meta_ram_a_wr_data = pkt_data;
    meta_ram_a_wr_strb = '1;
    meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd0};
    meta_ram_a_wr_en = 1'b0;
    meta_ram_a_rd_addr = {meta_rd_slot_reg[0], meta_rd_ptr_reg};
    meta_ram_a_rd_en = 1'b0;

    meta_ram_b_wr_data = pkt_data;
    meta_ram_b_wr_strb = '1;
    meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd0};
    meta_ram_b_wr_en = 1'b0;
    meta_ram_b_rd_addr = {meta_rd_slot_reg[0], meta_rd_ptr_reg};
    meta_ram_b_rd_en = 1'b0;

    meta_wr_slot_next = meta_wr_slot_reg;
    meta_rd_slot_next = meta_rd_slot_reg;

    meta_rd_ptr_next = meta_rd_ptr_reg;
    meta_rd_data_valid_next = meta_rd_data_valid_reg && !m_axis_meta.tready;
    meta_rd_data_last_next = meta_rd_data_last_reg;

    if (s_axis_pkt.tready && s_axis_pkt.tvalid) begin
        if (hdr_len_reg != 0) begin
            hdr_len_next = hdr_len_reg - 1;
        end
        offset_next = offset_reg + 1;
        if (payload_len_reg != 0) begin
            payload_len_next = payload_len_reg - 4;
        end

        ip_hdr_cksum_next = ip_hdr_cksum_reg + 21'(pkt_data_be[15:0] + pkt_data_be[31:16]);
        corr_cksum_next = corr_cksum_reg + 24'(pkt_data_be[15:0] + pkt_data_be[31:16]);

        frame_next = !s_axis_pkt.tlast;
        if (s_axis_pkt.tlast) begin
            s_axis_pkt_tready_next = 1'b0;
        end
    end

    if (run_reg && frame_reg && (!s_axis_pkt.tready || !s_axis_pkt.tvalid)) begin
        // hold
        state_next = state_reg;
    end else begin
        case (state_reg)
            // Ethernet header
            //  0                   1                   2                   3
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                    Destination MAC address                    |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |    Destination MAC address    |      Source MAC address       |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                      Source MAC address                       |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |           Ethertype           |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // Note: input data is shifted by 2 bytes to align subsequent headers
            STATE_IDLE: begin
                // store dest MAC
                meta_ram_a_wr_data = {pkt_data[15:0], pkt_data[31:16]};
                meta_ram_a_wr_strb = 4'b0011;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd3};
                meta_ram_a_wr_en = !meta_full;

                hash_reset = 1'b1;
                flag_next = '0;
                offset_next = 1;
                l3_offset_next = '0;
                l4_offset_next = '0;
                payload_offset_next = '0;
                payload_len_next = '0;

                ip_hdr_cksum_next = '0;
                corr_cksum_next = '0;

                s_axis_pkt_tready_next = frame_next || !meta_full;

                if (s_axis_pkt.tready && s_axis_pkt.tvalid && !frame_reg && !meta_full) begin
                    run_next = 1'b1;
                    state_next = STATE_ETH_1;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_ETH_1: begin
                // store dest MAC
                meta_ram_b_wr_data = {pkt_data[15:0], pkt_data[31:16]};
                meta_ram_b_wr_strb = 4'b0011;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd3};
                meta_ram_b_wr_en = 1'b1;
                meta_ram_a_wr_data = {pkt_data[15:0], pkt_data[31:16]};
                meta_ram_a_wr_strb = 4'b1100;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd3};
                meta_ram_a_wr_en = 1'b1;

                ip_hdr_cksum_next = '0;
                corr_cksum_next = '0;

                state_next = STATE_ETH_2;
            end
            STATE_ETH_2: begin
                // store source MAC
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd4};
                meta_ram_a_wr_en = 1'b1;

                ip_hdr_cksum_next = '0;
                corr_cksum_next = '0;

                state_next = STATE_ETH_3;
            end
            STATE_ETH_3: begin
                // store source MAC and ethertype
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd4};
                meta_ram_b_wr_en = 1'b1;

                l3_offset_next = offset_reg;
                payload_offset_next = offset_reg;

                ip_hdr_cksum_next = '0;
                corr_cksum_next = '0;

                flag_next = flag_reg | eth_type_flags;
                state_next = eth_type_state;
            end
            // VLAN tags
            STATE_VLAN_1: begin
                // store S-TAG
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b0011;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd2};
                meta_ram_a_wr_en = !flag_reg[FLG_VLAN_S];

                // store ethertype
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1100;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd4};
                meta_ram_b_wr_en = 1'b1;

                l3_offset_next = offset_reg;
                payload_offset_next = offset_reg;
                ip_hdr_cksum_next = '0;

                flag_next = flag_reg | eth_type_flags;
                state_next = eth_type_state;

                flag_next[FLG_VLAN_S] = 1'b1;
            end
            STATE_VLAN_2: begin
                // store C-TAG
                meta_ram_a_wr_data = {pkt_data[15:0], pkt_data[31:16]};
                meta_ram_a_wr_strb = 4'b1100;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd2};
                meta_ram_a_wr_en = !flag_reg[FLG_VLAN_C];

                // store ethertype
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1100;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd4};
                meta_ram_b_wr_en = 1'b1;

                l3_offset_next = offset_reg;
                payload_offset_next = offset_reg;
                ip_hdr_cksum_next = '0;

                flag_next = flag_reg | eth_type_flags;
                state_next = eth_type_state;

                flag_next[FLG_VLAN_C] = 1'b1;
            end
            // IPv4 header
            //  0                   1                   2                   3
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |Version|  IHL  |Type of Service|          Total Length         |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |         Identification        |Flags|      Fragment Offset    |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |  Time to Live |    Protocol   |         Header Checksum       |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                       Source Address                          |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                    Destination Address                        |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                    Options                    |    Padding    |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // from https://www.ietf.org/rfc/rfc791.txt
            STATE_IPV4_1: begin
                hdr_len_next = 9'(pkt_data_be[27:24]-1);
                payload_len_next = pkt_data_be[15:0] - 4;

                // store DSCP and ECN
                meta_ram_b_wr_data = {pkt_data_be[15:0], pkt_data_be[31:16]};
                meta_ram_b_wr_strb = 4'b0001;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd2};
                meta_ram_b_wr_en = 1'b1;

                if (pkt_data_be[31:28] == 4'd4) begin
                    flag_next[FLG_IPV4] = 1'b1;
                    state_next = STATE_IPV4_2;
                end else begin
                    state_next = STATE_FINISH_1;
                end
            end
            STATE_IPV4_2: begin
                // store IP ID
                meta_ram_a_wr_data = {pkt_data_be[15:0], pkt_data_be[31:16]};
                meta_ram_a_wr_strb = 4'b0011;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd7};
                meta_ram_a_wr_en = 1'b1;

                if (pkt_data_be[13] || pkt_data_be[12:0] != 0) begin
                    // MF bit set or nonzero fragment offset
                    flag_next[FLG_FRAG] = 1'b1;
                end

                state_next = STATE_IPV4_3;
            end
            STATE_IPV4_3: begin
                // store TTL and protocol
                meta_ram_b_wr_data = {pkt_data_be[15:0], pkt_data_be[31:16]}; // TODO check this
                meta_ram_b_wr_strb = 4'b0011;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd7};
                meta_ram_b_wr_en = 1'b1;

                next_hdr_next = pkt_data_be[23:16];

                state_next = STATE_IPV4_4;
            end
            STATE_IPV4_4: begin
                // store source IP
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd10};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV4_5;
            end
            STATE_IPV4_5: begin
                // store dest IP
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd8};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                corr_cksum_next = corr_cksum_reg;

                flag_next = next_hdr_flags | flag_reg;
                state_next = next_hdr_state;

                flag_next[FLG_L3_BAD_CKSUM] = (ip_hdr_cksum_next[15:0] ^ 16'(ip_hdr_cksum_next[20:16])) != 16'hffff;

                l4_offset_next = offset_reg;
                payload_offset_next = offset_reg;

                if (hdr_len_reg > 1) begin
                    state_next = STATE_IPV4_6;
                end
            end
            STATE_IPV4_6: begin
                flag_next = next_hdr_flags | flag_reg;
                state_next = next_hdr_state;

                flag_next[FLG_L3_OPT_PRSNT] = 1'b1;
                flag_next[FLG_L3_BAD_CKSUM] = (ip_hdr_cksum_next[15:0] ^ 16'(ip_hdr_cksum_next[20:16])) != 16'hffff;

                l4_offset_next = offset_reg;
                payload_offset_next = offset_reg;

                if (hdr_len_reg > 1) begin
                    state_next = STATE_IPV4_6;
                end
            end
            // IPv6 header
            //  0                   1                   2                   3
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |Version| Traffic Class |           Flow Label                  |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |         Payload Length        |  Next Header  |   Hop Limit   |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                                                               |
            // +                                                               +
            // |                                                               |
            // +                         Source Address                        +
            // |                                                               |
            // +                                                               +
            // |                                                               |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                                                               |
            // +                                                               +
            // |                                                               |
            // +                      Destination Address                      +
            // |                                                               |
            // +                                                               +
            // |                                                               |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // from https://www.ietf.org/rfc/rfc2460.txt
            STATE_IPV6_1: begin
                // store flow label
                meta_ram_a_wr_data = pkt_data_be;
                meta_ram_a_wr_strb = 4'b0111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd7};
                meta_ram_a_wr_en = 1'b1;

                // store DSCP and ECN
                meta_ram_b_wr_data = {24'd0, pkt_data_be[27:20]};
                meta_ram_b_wr_strb = 4'b0001;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd2};
                meta_ram_b_wr_en = 1'b1;

                if (pkt_data_be[31:28] == 4'd6) begin
                    flag_next[FLG_IPV6] = 1'b1;
                    state_next = STATE_IPV6_2;
                end else begin
                    state_next = STATE_FINISH_1;
                end
            end
            STATE_IPV6_2: begin
                // store next header, hop limit
                meta_ram_b_wr_data = pkt_data; // TODO check this
                meta_ram_b_wr_strb = 4'b0011;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd7};
                meta_ram_b_wr_en = 1'b1;

                payload_len_next = pkt_data_be[31:16];
                next_hdr_next = pkt_data_be[15:8];

                state_next = STATE_IPV6_3;
            end
            STATE_IPV6_3: begin
                // store source IP
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd10};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_4;
            end
            STATE_IPV6_4: begin
                // store source IP
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd10};
                meta_ram_b_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_5;
            end
            STATE_IPV6_5: begin
                // store source IP
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd11};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_6;
            end
            STATE_IPV6_6: begin
                // store source IP
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd11};
                meta_ram_b_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_7;
            end
            STATE_IPV6_7: begin
                // store dest IP
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd8};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_8;
            end
            STATE_IPV6_8: begin
                // store dest IP
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd8};
                meta_ram_b_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_9;
            end
            STATE_IPV6_9: begin
                // store dest IP
                meta_ram_a_wr_data = pkt_data;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd9};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_IPV6_10;
            end
            STATE_IPV6_10: begin
                // store dest IP
                meta_ram_b_wr_data = pkt_data;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd9};
                meta_ram_b_wr_en = 1'b1;

                hash_step = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = corr_cksum_reg;

                l4_offset_next = offset_reg;
                payload_offset_next = offset_reg;

                flag_next = next_hdr_flags | flag_reg;
                state_next = next_hdr_state;
            end
            // IPv6 extension header
            //  0                   1                   2                   3
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |  Next Header  |  Hdr Ext Len  |                               |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               +
            // |                                                               |
            // .                                                               .
            // .                            Content                            .
            // .                                                               .
            // |                                                               |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // from https://www.ietf.org/rfc/rfc2460.txt
            STATE_EXT_HDR_1: begin
                if (hdr_len_reg <= 1) begin
                    next_hdr_next = pkt_data_be[31:24];
                    hdr_len_next = {pkt_data_be[23:16], 1'b1};
                end

                l4_offset_next = offset_reg;
                payload_offset_next = offset_reg;

                flag_next = next_hdr_flags | flag_reg;
                state_next = next_hdr_state;

                if (hdr_len_reg > 1) begin
                    state_next = STATE_EXT_HDR_1;
                end
            end
            // TCP header
            //  0                   1                   2                   3   
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |          Source Port          |       Destination Port        |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                        Sequence Number                        |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                    Acknowledgment Number                      |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |  Data |           |U|A|P|R|S|F|                               |
            // | Offset| Reserved  |R|C|S|S|Y|I|            Window             |
            // |       |           |G|K|H|T|N|N|                               |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |           Checksum            |         Urgent Pointer        |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                    Options                    |    Padding    |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |                             data                              |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // from https://www.ietf.org/rfc/rfc793.txt
            STATE_TCP_1: begin
                // store ports
                meta_ram_a_wr_data = pkt_data_be;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd12};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                corr_cksum_next = corr_cksum_reg - 24'(payload_len_reg);

                flag_next[FLG_TCP] = 1'b1;

                state_next = STATE_TCP_2;
            end
            STATE_TCP_2: begin
                // store sequence number
                meta_ram_a_wr_data = pkt_data_be;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd14};
                meta_ram_a_wr_en = 1'b1;

                corr_cksum_next = corr_cksum_reg - 24'(PROTO_TCP);

                state_next = STATE_TCP_3;
            end
            STATE_TCP_3: begin
                // store ack number
                meta_ram_b_wr_data = pkt_data_be;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd14};
                meta_ram_b_wr_en = 1'b1;

                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_TCP_4;
            end
            STATE_TCP_4: begin
                // store flags
                meta_ram_b_wr_data = {pkt_data_be[15:0], pkt_data_be[31:16]};
                meta_ram_b_wr_strb = 4'b0001;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd12};
                meta_ram_b_wr_en = 1'b1;

                // store window
                meta_ram_a_wr_data = pkt_data_be;
                meta_ram_a_wr_strb = 4'b0011;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd13};
                meta_ram_a_wr_en = 1'b1;

                hdr_len_next = 9'(pkt_data_be[31:28]);

                corr_cksum_next = corr_cksum_reg;

                state_next = STATE_TCP_5;
            end
            STATE_TCP_5: begin
                // store urgent pointer
                meta_ram_a_wr_data = {pkt_data_be[15:0], pkt_data_be[31:16]};
                meta_ram_a_wr_strb = 4'b1100;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd13};
                meta_ram_a_wr_en = 1'b1; // TODO BROKEN

                payload_offset_next = offset_reg;

                corr_cksum_next = corr_cksum_reg;

                if (hdr_len_reg > 5) begin
                    flag_next[FLG_L4_OPT_PRSNT] = 1'b1;
                    state_next = STATE_TCP_5;
                end else begin
                    state_next = STATE_FINISH_1;
                end
            end
            // UDP header
            //  0                   1                   2                   3   
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |          Source Port          |       Destination Port        |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |            Length             |           Checksum            |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // from https://www.ietf.org/rfc/rfc768.txt
            STATE_UDP_1: begin
                // store ports
                meta_ram_a_wr_data = pkt_data_be;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd12};
                meta_ram_a_wr_en = 1'b1;

                hash_step = 1'b1;

                corr_cksum_next = corr_cksum_reg - 24'(payload_len_reg);

                flag_next[FLG_UDP] = 1'b1;
                flag_next[FLG_L4_BAD_LEN] = {s_axis_pkt.tdata[23:16], s_axis_pkt.tdata[31:24]} != payload_len_reg;

                state_next = STATE_UDP_2;
            end
            STATE_UDP_2: begin
                corr_cksum_next = corr_cksum_reg - 24'(PROTO_UDP);

                payload_offset_next = offset_reg;

                state_next = STATE_FINISH_1;
            end
            // Done parsing
            // Either we got to the payload, an unknown or invalid header, or a fragmented packet
            STATE_FINISH_1: begin
                flag_next[FLG_PARSE_DONE] = run_reg;

                // store flags
                meta_ram_a_wr_data = flag_next;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd0};
                meta_ram_a_wr_en = 1'b1;

                // store offsets
                meta_ram_b_wr_data[7:0] = l3_offset_reg;
                meta_ram_b_wr_data[15:8] = l4_offset_reg;
                meta_ram_b_wr_data[23:16] = '0;
                meta_ram_b_wr_data[31:24] = payload_offset_reg;
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd1};
                meta_ram_b_wr_en = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = 24'({8'd0, corr_cksum_reg[23:16]} + corr_cksum_reg[15:0]);

                run_next = 1'b0;

                state_next = STATE_FINISH_2;
            end
            STATE_FINISH_2: begin
                // store hash
                meta_ram_a_wr_data = hash_value;
                meta_ram_a_wr_strb = 4'b1111;
                meta_ram_a_wr_addr = {meta_wr_slot_reg[0], 4'd1};
                meta_ram_a_wr_en = 1'b1;

                // store payload len and full-packet sum
                meta_ram_b_wr_data[15:0] = payload_len_reg;
                meta_ram_b_wr_data[31:16] = {8'd0, corr_cksum_reg[23:16]} + corr_cksum_reg[15:0];
                meta_ram_b_wr_strb = 4'b1111;
                meta_ram_b_wr_addr = {meta_wr_slot_reg[0], 4'd0};
                meta_ram_b_wr_en = 1'b1;

                payload_len_next = payload_len_reg;
                corr_cksum_next = 24'({8'd0, corr_cksum_reg[23:16]} + corr_cksum_reg[15:0]);

                meta_wr_slot_next = meta_wr_slot_reg + 1;

                state_next = STATE_IDLE;
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

    // force parser into finish state at end of header
    if (run_reg && !frame_reg) begin
        if (state_reg != STATE_FINISH_1) begin
            state_next = STATE_FINISH_1;
        end
    end

    // read out metadata
    if (!meta_empty) begin
        meta_ram_a_rd_addr = {meta_rd_slot_reg[0], meta_rd_ptr_reg};
        meta_ram_b_rd_addr = {meta_rd_slot_reg[0], meta_rd_ptr_reg};
        if (!meta_rd_data_valid_reg || m_axis_meta.tready) begin
            meta_ram_a_rd_en = 1'b1;
            meta_ram_b_rd_en = 1'b1;
            meta_rd_data_valid_next = 1'b1;
            meta_rd_data_last_next = 1'b0;
            meta_rd_ptr_next = meta_rd_ptr_reg + 1;

            if (&meta_rd_ptr_reg) begin
                meta_rd_ptr_next = '0;
                meta_rd_data_last_next = 1'b1;
                meta_rd_slot_next = meta_rd_slot_reg + 1;
            end
        end
    end
end

always_ff @(posedge clk) begin
    if (meta_ram_a_wr_en) begin
        for (integer i = 0; i < 4; i = i + 1) begin
            if (meta_ram_a_wr_strb[i]) begin
                meta_ram_a[meta_ram_a_wr_addr][i*8 +: 8] = meta_ram_a_wr_data[i*8 +: 8];
            end
        end
    end
    if (meta_ram_a_rd_en) begin
        meta_ram_a_rd_data_reg <= meta_ram_a[meta_ram_a_rd_addr];
    end

    if (meta_ram_b_wr_en) begin
        for (integer i = 0; i < 4; i = i + 1) begin
            if (meta_ram_b_wr_strb[i]) begin
                meta_ram_b[meta_ram_b_wr_addr][i*8 +: 8] = meta_ram_b_wr_data[i*8 +: 8];
            end
        end
    end
    if (meta_ram_b_rd_en) begin
        meta_ram_b_rd_data_reg <= meta_ram_b[meta_ram_b_rd_addr];
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    frame_reg <= frame_next;
    run_reg <= run_next;
    flag_reg <= flag_next;
    next_hdr_reg <= next_hdr_next;
    hdr_len_reg <= hdr_len_next;
    offset_reg <= offset_next;
    l3_offset_reg <= l3_offset_next;
    l4_offset_reg <= l4_offset_next;
    payload_offset_reg <= payload_offset_next;
    payload_len_reg <= payload_len_next;

    ip_hdr_cksum_reg <= ip_hdr_cksum_next;
    corr_cksum_reg <= corr_cksum_next;

    s_axis_pkt_tready_reg <= s_axis_pkt_tready_next;

    if (s_axis_pkt.tready && s_axis_pkt.tvalid) begin
        pkt_data_reg <= s_axis_pkt.tdata[31:16];
    end

    meta_wr_slot_reg <= meta_wr_slot_next;
    meta_rd_slot_reg <= meta_rd_slot_next;
    meta_rd_ptr_reg <= meta_rd_ptr_next;

    meta_rd_data_valid_reg <= meta_rd_data_valid_next;
    meta_rd_data_last_reg <= meta_rd_data_last_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        frame_reg <= 1'b0;
        run_reg <= 1'b0;

        s_axis_pkt_tready_reg <= 1'b0;

        meta_wr_slot_reg <= '0;
        meta_rd_slot_reg <= '0;
        meta_rd_ptr_reg <= '0;

        meta_rd_data_valid_reg <= 1'b0;
    end
end

endmodule

`resetall
