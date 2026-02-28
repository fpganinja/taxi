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
 * Zircon IP stack - TX deparser
 */
module zircon_ip_tx_deparse #
(
    parameter logic IPV6_EN = 1'b1
)
(
    input  wire logic  clk,
    input  wire logic  rst,

    /*
     * Packet metadata input
     */
    taxi_axis_if.snk   s_axis_meta,

    /*
     * Packet header output
     */
    taxi_axis_if.src   m_axis_pkt
);

// workaround for verilator bug causing spurious UNOPTFLAT warnings
// verilator lint_off UNOPTFLAT

// Metadata input (64 bit blocks):
// 00: flags / payload len, payload sum
// 01: 
// 02: vlan tags / dscp, ecn
// 03: eth dst
// 04: eth src, ethtype
// 05: 
// 06: 
// 07: ip id/fl / protocol, ttl/hl
// 08: ipv6 dst
// 09: ipv6 dst
// 10: ipv6 src
// 11: ipv6 src
// 12: l4 ports / tcp flags
// 13: tcp wnd/urg
// 14: tcp seq/ack
// 15: 

localparam DATA_W = m_axis_pkt.DATA_W;
localparam KEEP_W = m_axis_pkt.KEEP_W;
localparam META_W = s_axis_meta.DATA_W;

// check configuration
if (META_W != 64)
    $fatal(0, "Error: Interface width must be 64 (instance %m)");

if (s_axis_meta.KEEP_W * 8 != META_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (DATA_W != 32)
    $fatal(0, "Error: Interface width must be 32 (instance %m)");

if (KEEP_W * 8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

function [15:0] swab16(input [15:0] data);
    swab16 = '0;
    for (integer i = 0; i < 2; i = i + 1) begin
        swab16[(1-i)*8 +: 8] = data[i*8 +: 8];
    end
endfunction

function [31:0] swab32(input [31:0] data);
    swab32 = '0;
    for (integer i = 0; i < 4; i = i + 1) begin
        swab32[(3-i)*8 +: 8] = data[i*8 +: 8];
    end
endfunction

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
    FLG_ARP = 6,
    FLG_ICMP = 7,
    FLG_TCP = 8,
    FLG_UDP = 9,
    FLG_AH = 10,
    FLG_ESP = 11,
    FLG_EN = 31;

typedef enum logic [4:0] {
    PKT_STATE_IDLE,
    PKT_STATE_ETH_1,
    PKT_STATE_ETH_2,
    PKT_STATE_ETH_3,
    PKT_STATE_VLAN_1,
    PKT_STATE_VLAN_2,
    PKT_STATE_IPV4_1,
    PKT_STATE_IPV4_2,
    PKT_STATE_IPV4_3,
    PKT_STATE_IPV4_4,
    PKT_STATE_IPV4_5,
    PKT_STATE_IPV4_6,
    PKT_STATE_IPV6_1,
    PKT_STATE_IPV6_2,
    PKT_STATE_IPV6_3,
    PKT_STATE_IPV6_4,
    PKT_STATE_IPV6_5,
    PKT_STATE_IPV6_6,
    PKT_STATE_IPV6_7,
    PKT_STATE_IPV6_8,
    PKT_STATE_IPV6_9,
    PKT_STATE_IPV6_10,
    PKT_STATE_TCP_1,
    PKT_STATE_TCP_2,
    PKT_STATE_TCP_3,
    PKT_STATE_TCP_4,
    PKT_STATE_TCP_5,
    PKT_STATE_UDP_1,
    PKT_STATE_UDP_2,
    PKT_STATE_FINISH_1
} pkt_state_t;

pkt_state_t pkt_state_reg = PKT_STATE_IDLE, pkt_state_next;

logic [31:0] meta_flag_reg = '0, meta_flag_next;
logic [15:0] meta_payload_len_reg = '0, meta_payload_len_next;
logic [20:0] meta_common_cksum_reg = '0, meta_common_cksum_next;
logic [20:0] meta_l3_cksum_reg = '0, meta_l3_cksum_next;
logic [20:0] meta_l4_cksum_reg = '0, meta_l4_cksum_next;
logic meta_valid_reg = 1'b0, meta_valid_next;

logic [31:0] pkt_flag_reg = '0, pkt_flag_next;
logic [15:0] pkt_l3_len_reg = '0, pkt_l3_len_next;
logic [15:0] pkt_l4_len_reg = '0, pkt_l4_len_next;
logic [20:0] pkt_l3_cksum_reg = '0, pkt_l3_cksum_next;
logic [20:0] pkt_l4_cksum_reg = '0, pkt_l4_cksum_next;

logic [31:0] data_reg = '0, data_next;
logic data_valid_reg = 1'b0, data_valid_next;

logic s_axis_meta_tready_reg = 1'b0, s_axis_meta_tready_next;

logic [DATA_W-1:0] m_axis_pkt_tdata_reg = '0, m_axis_pkt_tdata_next;
logic [KEEP_W-1:0] m_axis_pkt_tkeep_reg = '0, m_axis_pkt_tkeep_next;
logic m_axis_pkt_tvalid_reg = 1'b0, m_axis_pkt_tvalid_next;
logic m_axis_pkt_tlast_reg = 1'b0, m_axis_pkt_tlast_next;

// metadata RAM
localparam META_AW = 5;

logic [31:0] meta_ram_a[2**META_AW];
logic [31:0] meta_ram_a_wr_data;
logic [3:0] meta_ram_a_wr_strb;
logic [META_AW-1:0] meta_ram_a_wr_addr;
logic meta_ram_a_wr_en;
logic [31:0] meta_ram_a_rd_data_reg = '0;
logic [META_AW-1:0] meta_ram_a_rd_addr;
wire [31:0] meta_ram_a_rd_data = meta_ram_a[meta_ram_a_rd_addr];
wire [31:0] meta_ram_a_rd_data_be = swab32(meta_ram_a_rd_data);

logic [31:0] meta_ram_b[2**META_AW];
logic [31:0] meta_ram_b_wr_data;
logic [3:0] meta_ram_b_wr_strb;
logic [META_AW-1:0] meta_ram_b_wr_addr;
logic meta_ram_b_wr_en;
logic [31:0] meta_ram_b_rd_data_reg = '0;
logic [META_AW-1:0] meta_ram_b_rd_addr;
wire [31:0] meta_ram_b_rd_data = meta_ram_b[meta_ram_b_rd_addr];
wire [31:0] meta_ram_b_rd_data_be = swab32(meta_ram_b_rd_data);

logic [1:0] meta_wr_slot_reg = '0, meta_wr_slot_next;
logic [1:0] meta_rd_slot_reg = '0, meta_rd_slot_next;
logic [META_AW-1-1:0] meta_wr_ptr_reg = '0, meta_wr_ptr_next;

wire meta_empty = meta_wr_slot_reg == meta_rd_slot_reg;
wire meta_full = meta_wr_slot_reg == (meta_rd_slot_reg ^ 2'b10);

logic [63:0] meta_cksum_in;
logic [16:0] meta_cksum_1_reg = '0, meta_cksum_1_next;
logic [16:0] meta_cksum_2_reg = '0, meta_cksum_2_next;
logic [17:0] meta_cksum_3_reg = '0, meta_cksum_3_next;

assign s_axis_meta.tready = s_axis_meta_tready_reg;

assign m_axis_pkt.tdata = m_axis_pkt_tdata_reg;
assign m_axis_pkt.tkeep = m_axis_pkt_tkeep_reg;
assign m_axis_pkt.tstrb = m_axis_pkt.tkeep;
assign m_axis_pkt.tid = '0;
assign m_axis_pkt.tdest = '0;
assign m_axis_pkt.tuser = '0;
assign m_axis_pkt.tlast = m_axis_pkt_tlast_reg;
assign m_axis_pkt.tvalid = m_axis_pkt_tvalid_reg;

always_comb begin
    pkt_state_next = PKT_STATE_IDLE;

    meta_flag_next = meta_flag_reg;
    meta_payload_len_next = meta_payload_len_reg;
    meta_common_cksum_next = meta_common_cksum_reg;
    meta_l3_cksum_next = meta_l3_cksum_reg;
    meta_l4_cksum_next = meta_l4_cksum_reg;
    meta_valid_next = meta_valid_reg;

    meta_cksum_1_next = meta_cksum_1_reg;
    meta_cksum_2_next = meta_cksum_2_reg;
    meta_cksum_3_next = meta_cksum_3_reg;

    pkt_flag_next = pkt_flag_reg;
    pkt_l3_len_next = pkt_l3_len_reg;
    pkt_l4_len_next = pkt_l4_len_reg;
    pkt_l3_cksum_next = pkt_l3_cksum_reg;
    pkt_l4_cksum_next = pkt_l4_cksum_reg;

    data_next = data_reg;
    data_valid_next = data_valid_reg;

    s_axis_meta_tready_next = s_axis_meta_tready_reg;

    m_axis_pkt_tdata_next = m_axis_pkt_tdata_reg;
    m_axis_pkt_tkeep_next = m_axis_pkt_tkeep_reg;
    m_axis_pkt_tvalid_next = m_axis_pkt_tvalid_reg && !m_axis_pkt.tready;
    m_axis_pkt_tlast_next = m_axis_pkt_tlast_reg;

    meta_ram_a_wr_data = s_axis_meta.tdata[31:0];
    meta_ram_a_wr_strb = '1;
    meta_ram_a_wr_addr = {meta_wr_slot_reg[0], meta_wr_ptr_reg};
    meta_ram_a_wr_en = 1'b0;
    meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd0};

    meta_ram_b_wr_data = s_axis_meta.tdata[63:32];
    meta_ram_b_wr_strb = '1;
    meta_ram_b_wr_addr = {meta_wr_slot_reg[0], meta_wr_ptr_reg};
    meta_ram_b_wr_en = 1'b0;
    meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd0};

    meta_wr_slot_next = meta_wr_slot_reg;
    meta_rd_slot_next = meta_rd_slot_reg;

    meta_wr_ptr_next = meta_wr_ptr_reg;

    meta_cksum_in[31:0] = swab32(s_axis_meta.tdata[31:0]);
    meta_cksum_in[63:32] = swab32(s_axis_meta.tdata[63:32]);

    // store metadata
    s_axis_meta_tready_next = !meta_full && !meta_valid_reg;
    if (s_axis_meta.tready && s_axis_meta.tvalid) begin
        meta_ram_a_wr_data = s_axis_meta.tdata[31:0];
        meta_ram_a_wr_strb = '1;
        meta_ram_a_wr_addr = {meta_wr_slot_reg[0], meta_wr_ptr_reg};
        meta_ram_a_wr_en = 1'b1;

        meta_ram_b_wr_data = s_axis_meta.tdata[63:32];
        meta_ram_b_wr_strb = '1;
        meta_ram_b_wr_addr = {meta_wr_slot_reg[0], meta_wr_ptr_reg};
        meta_ram_b_wr_en = 1'b1;

        meta_wr_ptr_next = meta_wr_ptr_reg+1;
        case (meta_wr_ptr_reg)
            4'd0: begin
                // flags / payload len, payload sum
                meta_flag_next = s_axis_meta.tdata[31:0];

                meta_payload_len_next = s_axis_meta.tdata[47:32];

                meta_l4_cksum_next = 21'(s_axis_meta.tdata[63:48]);
            end
            4'd1: begin
                // nothing

                if (meta_flag_reg[FLG_TCP]) begin
                    meta_payload_len_next = meta_payload_len_reg + 16'd20;
                end else if (meta_flag_reg[FLG_UDP]) begin
                    meta_payload_len_next = meta_payload_len_reg + 16'd8;
                end
            end
            4'd2: begin
                // vlan tags / DSCP, ECN
                meta_l3_cksum_next = 21'({8'h45, s_axis_meta.tdata[47:40]});

                meta_common_cksum_next = 21'(meta_payload_len_reg);
            end
            4'd3: begin
                // eth dst

                meta_l3_cksum_next = meta_l3_cksum_reg + 21'd20;

                if (meta_flag_reg[FLG_UDP]) begin
                    meta_l4_cksum_next = meta_l4_cksum_reg + 21'(meta_payload_len_reg);
                end
            end
            4'd4: begin
                // eth src, ethtype
            end
            4'd5: begin
                // nothing
            end
            4'd6: begin
                // nothing
            end
            4'd7: begin
                // IP ID/FL / protocol, TTL/HL
                meta_cksum_in[31:0] = {16'd0, s_axis_meta.tdata[15:0]};
                meta_cksum_in[63:32] = {16'd0, s_axis_meta.tdata[47:40], 8'd0};

                if (meta_flag_reg[FLG_TCP]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(PROTO_TCP);
                end else if (meta_flag_reg[FLG_UDP]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(PROTO_UDP);
                end else if (meta_flag_reg[FLG_ICMP]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(PROTO_ICMP);
                end else begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(s_axis_meta.tdata[39:32]);
                end
            end
            4'd8: begin
                // IP dst
                meta_cksum_in[31:0] = swab32(s_axis_meta.tdata[31:0]);
                meta_cksum_in[63:32] = swab32(s_axis_meta.tdata[63:32]);

                // FL, TTL/HL
                meta_l3_cksum_next = meta_l3_cksum_reg + 21'(meta_cksum_3_reg);
            end
            4'd9: begin
                // IP dst
                meta_cksum_in[31:0] = swab32(s_axis_meta.tdata[31:0]);
                meta_cksum_in[63:32] = swab32(s_axis_meta.tdata[63:32]);

                // IP dst
                if (meta_flag_reg[FLG_IPV6]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(meta_cksum_3_reg);
                end else begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(meta_cksum_1_reg);
                end
            end
            4'd10: begin
                // IP src
                meta_cksum_in[31:0] = swab32(s_axis_meta.tdata[31:0]);
                meta_cksum_in[63:32] = swab32(s_axis_meta.tdata[63:32]);

                // IP dst
                if (meta_flag_reg[FLG_IPV6]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(meta_cksum_3_reg);
                end
            end
            4'd11: begin
                // IP src
                meta_cksum_in[31:0] = swab32(s_axis_meta.tdata[31:0]);
                meta_cksum_in[63:32] = swab32(s_axis_meta.tdata[63:32]);

                // IP src
                if (meta_flag_reg[FLG_IPV6]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(meta_cksum_3_reg);
                end else begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(meta_cksum_1_reg);
                end
            end
            4'd12: begin
                // L4 ports, TCP flags
                meta_cksum_in[31:0] = s_axis_meta.tdata[31:0];
                meta_cksum_in[63:32] = {16'd0, 4'd5, 4'd0, s_axis_meta.tdata[39:32]};

                // IP dst
                if (meta_flag_reg[FLG_IPV6]) begin
                    meta_common_cksum_next = meta_common_cksum_reg + 21'(meta_cksum_3_reg);
                end
            end
            4'd13: begin
                // TCP wnd/urg
                meta_cksum_in[31:0] = s_axis_meta.tdata[31:0];
                meta_cksum_in[63:32] = 32'(meta_common_cksum_reg);

                // L4 ports, TCP flags
                if (meta_flag_reg[FLG_TCP]) begin
                    meta_l4_cksum_next = meta_l4_cksum_reg + 21'(meta_cksum_3_reg);
                end else begin
                    meta_l4_cksum_next = meta_l4_cksum_reg + 21'(meta_cksum_1_reg);
                end

                // IPv4 header checksum
                meta_l3_cksum_next = meta_l3_cksum_reg + meta_common_cksum_reg;
            end
            4'd14: begin
                // TCP seq/ack
                meta_cksum_in[31:0] = s_axis_meta.tdata[31:0];
                meta_cksum_in[63:32] = s_axis_meta.tdata[63:32];

                // TCP wnd/urg
                if (meta_flag_reg[FLG_TCP]) begin
                    meta_l4_cksum_next = meta_l4_cksum_reg + 21'(meta_cksum_3_reg);
                end else begin
                    meta_l4_cksum_next = meta_l4_cksum_reg + 21'(meta_cksum_2_reg);
                end

                // IPv4 header checksum
                meta_l3_cksum_next = 21'(meta_l3_cksum_reg[15:0]) + 21'(meta_l3_cksum_reg[20:16]);
            end
            4'd15: begin
                // TCP wnd/urg
                if (meta_flag_reg[FLG_TCP]) begin
                    meta_l4_cksum_next = meta_l4_cksum_reg + 21'(meta_cksum_3_reg);
                end

                // IPv4 header checksum
                meta_l3_cksum_next = 21'(meta_l3_cksum_reg[15:0]) + 21'(meta_l3_cksum_reg[20:16]);
            end
            default: begin
                // no op
            end
        endcase

        meta_cksum_1_next = meta_cksum_in[15:0] + meta_cksum_in[31:16];
        meta_cksum_2_next = meta_cksum_in[47:32] + meta_cksum_in[63:48];
        meta_cksum_3_next = meta_cksum_1_next + meta_cksum_2_next;

        if (&meta_wr_ptr_reg || s_axis_meta.tlast) begin
            meta_wr_ptr_next = '0;
            meta_wr_slot_next = meta_wr_slot_reg + 1;
            s_axis_meta_tready_next = 1'b0;
            meta_valid_next = 1'b1;
        end
    end

    if (m_axis_pkt_tvalid_reg && data_valid_reg && !m_axis_pkt.tready) begin
        // hold for backpressure
        pkt_state_next = pkt_state_reg;
    end else begin
        case (pkt_state_reg)
            // Build Ethernet header
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
            // Note: output data is padded with two bytes to align subsequent headers
            PKT_STATE_IDLE: begin
                // dest MAC
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd3};
                data_next[31:16] = meta_ram_a_rd_data[15:0];
                data_valid_next = meta_valid_reg && !meta_empty;

                pkt_flag_next = meta_flag_reg;
                pkt_l3_cksum_next = ~meta_l3_cksum_reg;
                pkt_l4_cksum_next = ~21'(meta_l4_cksum_reg[15:0] + 16'(meta_l4_cksum_reg[20:16]));

                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd0};
                pkt_l4_len_next = meta_ram_b_rd_data[15:0];

                if (meta_valid_reg && !meta_empty) begin
                    if (meta_flag_reg[FLG_EN]) begin
                        pkt_state_next = PKT_STATE_ETH_1;
                    end else begin
                        pkt_state_next = PKT_STATE_FINISH_1;
                    end
                    meta_valid_next = 1'b0;
                end else begin
                    pkt_state_next = PKT_STATE_IDLE;
                end
            end
            PKT_STATE_ETH_1: begin
                // dest MAC
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd3};
                data_next[15:0] = meta_ram_a_rd_data[31:16];
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd3};
                data_next[31:16] = meta_ram_b_rd_data[15:0];
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_TCP]) begin
                    pkt_l4_len_next = pkt_l4_len_reg + 16'd20;
                end else if (pkt_flag_reg[FLG_UDP]) begin
                    pkt_l4_len_next = pkt_l4_len_reg + 16'd8;
                end

                pkt_state_next = PKT_STATE_ETH_2;
            end
            PKT_STATE_ETH_2: begin
                // source MAC
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd4};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_IPV4]) begin
                    pkt_l3_len_next = pkt_l4_len_reg + 16'd20;
                end else if (pkt_flag_reg[FLG_IPV6]) begin
                    pkt_l3_len_next = pkt_l4_len_reg;
                end

                pkt_state_next = PKT_STATE_ETH_3;
            end
            PKT_STATE_ETH_3: begin
                // source MAC and ethertype
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd4};
                data_next[15:0] = meta_ram_b_rd_data[15:0];
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_VLAN_S]) begin
                    data_next[31:16] = swab16(ETHERTYPE_VLAN_S);
                    pkt_state_next = PKT_STATE_VLAN_1;
                end else if (pkt_flag_reg[FLG_VLAN_C]) begin
                    data_next[31:16] = swab16(ETHERTYPE_VLAN_C);
                    pkt_state_next = PKT_STATE_VLAN_2;
                end else if (pkt_flag_reg[FLG_IPV4]) begin
                    data_next[31:16] = swab16(ETHERTYPE_IPV4);
                    pkt_state_next = PKT_STATE_IPV4_1;
                end else if (pkt_flag_reg[FLG_IPV6]) begin
                    data_next[31:16] = swab16(ETHERTYPE_IPV6);
                    pkt_state_next = PKT_STATE_IPV6_1;
                end else if (pkt_flag_reg[FLG_ARP]) begin
                    data_next[31:16] = swab16(ETHERTYPE_ARP);
                    pkt_state_next = PKT_STATE_FINISH_1;
                end else begin
                    data_next[31:16] = meta_ram_b_rd_data[31:16];
                    pkt_state_next = PKT_STATE_FINISH_1;
                end
            end
            // Build VLAN tags
            PKT_STATE_VLAN_1: begin
                // S-TAG
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd2};
                data_next[15:0] = meta_ram_a_rd_data[15:0];
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd4};
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_VLAN_C]) begin
                    data_next[31:16] = swab16(ETHERTYPE_VLAN_C);
                    pkt_state_next = PKT_STATE_VLAN_2;
                end else if (pkt_flag_reg[FLG_IPV4]) begin
                    data_next[31:16] = swab16(ETHERTYPE_IPV4);
                    pkt_state_next = PKT_STATE_IPV4_1;
                end else if (pkt_flag_reg[FLG_IPV6]) begin
                    data_next[31:16] = swab16(ETHERTYPE_IPV6);
                    pkt_state_next = PKT_STATE_IPV6_1;
                end else if (pkt_flag_reg[FLG_ARP]) begin
                    data_next[31:16] = swab16(ETHERTYPE_ARP);
                    pkt_state_next = PKT_STATE_FINISH_1;
                end else begin
                    data_next[31:16] = meta_ram_b_rd_data[31:16];
                    pkt_state_next = PKT_STATE_FINISH_1;
                end
            end
            PKT_STATE_VLAN_2: begin
                // C-TAG
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd2};
                data_next[15:0] = meta_ram_a_rd_data[31:16];
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd4};
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_IPV4]) begin
                    data_next[31:16] = swab16(ETHERTYPE_IPV4);
                    pkt_state_next = PKT_STATE_IPV4_1;
                end else if (pkt_flag_reg[FLG_IPV6]) begin
                    data_next[31:16] = swab16(ETHERTYPE_IPV6);
                    pkt_state_next = PKT_STATE_IPV6_1;
                end else if (pkt_flag_reg[FLG_ARP]) begin
                    data_next[31:16] = swab16(ETHERTYPE_ARP);
                    pkt_state_next = PKT_STATE_FINISH_1;
                end else begin
                    data_next[31:16] = meta_ram_b_rd_data[31:16];
                    pkt_state_next = PKT_STATE_FINISH_1;
                end
            end
            // Build IPv4 header
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
            PKT_STATE_IPV4_1: begin
                data_next[7:4] = 4'd4; // version
                data_next[3:0] = 4'd5; // IHL
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd2};
                data_next[15:8] = meta_ram_b_rd_data[23:16]; // DSCP and ECN
                data_next[31:16] = swab16(pkt_l3_len_reg); // total length
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV4_2;
            end
            PKT_STATE_IPV4_2: begin
                // IP ID
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd7};
                data_next[15:0] = swab16(meta_ram_a_rd_data[15:0]);
                data_next[31:16] = '0; // flags, fragment offset
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV4_3;
            end
            PKT_STATE_IPV4_3: begin
                // TTL, protocol, header checksum
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd7};
                data_next[7:0] = meta_ram_b_rd_data[15:8]; // TTL
                data_next[15:8] = meta_ram_b_rd_data[7:0]; // protocol
                data_next[31:16] = swab16(pkt_l3_cksum_reg[15:0]); // header checksum
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_TCP]) begin
                    data_next[15:8] = PROTO_TCP;
                end else if (pkt_flag_reg[FLG_UDP]) begin
                    data_next[15:8] = PROTO_UDP;
                end else if (pkt_flag_reg[FLG_ICMP]) begin
                    data_next[15:8] = PROTO_ICMP;
                end else begin
                    data_next[15:8] = meta_ram_b_rd_data[7:0];
                end

                pkt_state_next = PKT_STATE_IPV4_4;
            end
            PKT_STATE_IPV4_4: begin
                // source IP
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd10};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV4_5;
            end
            PKT_STATE_IPV4_5: begin
                // dest IP
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd8};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_TCP]) begin
                    pkt_state_next = PKT_STATE_TCP_1;
                end else if (pkt_flag_reg[FLG_UDP]) begin
                    pkt_state_next = PKT_STATE_UDP_1;
                end else begin
                    pkt_state_next = PKT_STATE_FINISH_1;
                end
            end
            // Build IPv6 header
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
            PKT_STATE_IPV6_1: begin
                // flow label
                data_next[7:4] = 4'd6; // version
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd2};
                {data_next[3:0], data_next[15:12]} = meta_ram_b_rd_data[23:16]; // Traffic class
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd7};
                {data_next[11:8], data_next[23:16], data_next[31:24]} = meta_ram_a_rd_data[19:0]; // Flow label
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_2;
            end
            PKT_STATE_IPV6_2: begin
                // hop limit
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd7};
                data_next[31:24] = meta_ram_b_rd_data[15:8]; // hop limit
                data_next[23:16] = meta_ram_b_rd_data[7:0]; // next header
                data_next[15:0] = swab16(pkt_l3_len_reg); // payload length
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_TCP]) begin
                    data_next[23:16] = PROTO_TCP;
                end else if (pkt_flag_reg[FLG_UDP]) begin
                    data_next[23:16] = PROTO_UDP;
                end else if (pkt_flag_reg[FLG_ICMP]) begin
                    data_next[23:16] = PROTO_IPV6_ICMP;
                end else begin
                    data_next[23:16] = meta_ram_b_rd_data[7:0];
                end

                pkt_state_next = PKT_STATE_IPV6_3;
            end
            PKT_STATE_IPV6_3: begin
                // source IP
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd10};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_4;
            end
            PKT_STATE_IPV6_4: begin
                // source IP
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd10};
                data_next = meta_ram_b_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_5;
            end
            PKT_STATE_IPV6_5: begin
                // source IP
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd11};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_6;
            end
            PKT_STATE_IPV6_6: begin
                // source IP
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd11};
                data_next = meta_ram_b_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_7;
            end
            PKT_STATE_IPV6_7: begin
                // dest IP
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd8};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_8;
            end
            PKT_STATE_IPV6_8: begin
                // dest IP
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd8};
                data_next = meta_ram_b_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_9;
            end
            PKT_STATE_IPV6_9: begin
                // dest IP
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd9};
                data_next = meta_ram_a_rd_data;
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_IPV6_10;
            end
            PKT_STATE_IPV6_10: begin
                // dest IP
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd9};
                data_next = meta_ram_b_rd_data;
                data_valid_next = 1'b1;

                if (pkt_flag_reg[FLG_TCP]) begin
                    pkt_state_next = PKT_STATE_TCP_1;
                end else if (pkt_flag_reg[FLG_UDP]) begin
                    pkt_state_next = PKT_STATE_UDP_1;
                end else begin
                    pkt_state_next = PKT_STATE_FINISH_1;
                end
            end
            // Build TCP header
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
            PKT_STATE_TCP_1: begin
                // ports
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd12};
                data_next = swab32(meta_ram_a_rd_data); // source and dest ports
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_TCP_2;
            end
            PKT_STATE_TCP_2: begin
                // sequence number
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd14};
                data_next = swab32(meta_ram_a_rd_data); // seq
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_TCP_3;
            end
            PKT_STATE_TCP_3: begin
                // ack number
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd14};
                data_next = swab32(meta_ram_b_rd_data); // ack
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_TCP_4;
            end
            PKT_STATE_TCP_4: begin
                // flags
                meta_ram_b_rd_addr = {meta_rd_slot_reg[0], 4'd12};
                data_next[7:4] = 4'd5; // data offset
                data_next[3:0] = 4'd0; // reserved
                data_next[15:8] = meta_ram_b_rd_data[7:0]; // flags
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd13};
                data_next[31:16] = swab16(meta_ram_a_rd_data[15:0]); // window
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_TCP_5;
            end
            PKT_STATE_TCP_5: begin
                // urgent pointer
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd13};
                data_next[15:0] = swab16(pkt_l4_cksum_reg[15:0]); // checksum
                data_next[31:16] = swab16(meta_ram_a_rd_data[31:16]); // urgent pointer
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_FINISH_1;
            end
            // Build UDP header
            //  0                   1                   2                   3   
            //  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |          Source Port          |       Destination Port        |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // |            Length             |           Checksum            |
            // +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
            // from https://www.ietf.org/rfc/rfc768.txt
            PKT_STATE_UDP_1: begin
                // ports
                meta_ram_a_rd_addr = {meta_rd_slot_reg[0], 4'd12};
                data_next = swab32(meta_ram_a_rd_data); // source and dest ports
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_UDP_2;
            end
            PKT_STATE_UDP_2: begin
                data_next[15:0] = swab16(pkt_l4_len_reg);
                data_next[31:16] = swab16(pkt_l4_cksum_reg[15:0]); // checksum
                data_valid_next = 1'b1;

                pkt_state_next = PKT_STATE_FINISH_1;
            end
            // Finish packet header generation
            PKT_STATE_FINISH_1: begin
                // last cycle of header

                if (!m_axis_pkt_tvalid_reg || m_axis_pkt.tready) begin
                    data_valid_next = 1'b0;

                    m_axis_pkt_tdata_next = {data_next[15:0], data_reg[31:16]};
                    if (pkt_flag_reg[FLG_EN]) begin
                        m_axis_pkt_tkeep_next = 4'b0011;
                    end else begin
                        m_axis_pkt_tkeep_next = 4'b0000;
                    end
                    m_axis_pkt_tvalid_next = 1'b1;
                    m_axis_pkt_tlast_next = 1'b1;

                    meta_rd_slot_next = meta_rd_slot_reg + 1;

                    pkt_state_next = PKT_STATE_IDLE;
                end else begin
                    pkt_state_next = PKT_STATE_FINISH_1;
                end
            end
            default: begin
                pkt_state_next = PKT_STATE_IDLE;
            end
        endcase

        if (data_valid_next && (!m_axis_pkt_tvalid_reg || m_axis_pkt.tready)) begin
            m_axis_pkt_tdata_next = {data_next[15:0], data_reg[31:16]};
            m_axis_pkt_tkeep_next = 4'b1111;
            m_axis_pkt_tvalid_next = data_valid_next && data_valid_reg;
            m_axis_pkt_tlast_next = 1'b0;
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

    if (meta_ram_b_wr_en) begin
        for (integer i = 0; i < 4; i = i + 1) begin
            if (meta_ram_b_wr_strb[i]) begin
                meta_ram_b[meta_ram_b_wr_addr][i*8 +: 8] = meta_ram_b_wr_data[i*8 +: 8];
            end
        end
    end
end

always_ff @(posedge clk) begin
    pkt_state_reg <= pkt_state_next;

    meta_flag_reg <= meta_flag_next;
    meta_payload_len_reg <= meta_payload_len_next;
    meta_common_cksum_reg <= meta_common_cksum_next;
    meta_l3_cksum_reg <= meta_l3_cksum_next;
    meta_l4_cksum_reg <= meta_l4_cksum_next;
    meta_valid_reg <= meta_valid_next;

    meta_cksum_1_reg <= meta_cksum_1_next;
    meta_cksum_2_reg <= meta_cksum_2_next;
    meta_cksum_3_reg <= meta_cksum_3_next;

    pkt_flag_reg <= pkt_flag_next;
    pkt_l3_len_reg <= pkt_l3_len_next;
    pkt_l4_len_reg <= pkt_l4_len_next;
    pkt_l3_cksum_reg <= pkt_l3_cksum_next;
    pkt_l4_cksum_reg <= pkt_l4_cksum_next;

    data_reg <= data_next;
    data_valid_reg <= data_valid_next;

    s_axis_meta_tready_reg <= s_axis_meta_tready_next;

    m_axis_pkt_tdata_reg <= m_axis_pkt_tdata_next;
    m_axis_pkt_tkeep_reg <= m_axis_pkt_tkeep_next;
    m_axis_pkt_tvalid_reg <= m_axis_pkt_tvalid_next;
    m_axis_pkt_tlast_reg <= m_axis_pkt_tlast_next;

    meta_wr_slot_reg <= meta_wr_slot_next;
    meta_rd_slot_reg <= meta_rd_slot_next;
    meta_wr_ptr_reg <= meta_wr_ptr_next;

    if (rst) begin
        pkt_state_reg <= PKT_STATE_IDLE;

        meta_valid_reg <= 1'b0;

        data_valid_reg <= 1'b0;

        s_axis_meta_tready_reg <= 1'b0;

        m_axis_pkt_tvalid_reg <= 1'b0;

        meta_wr_slot_reg <= '0;
        meta_rd_slot_reg <= '0;
        meta_wr_ptr_reg <= '0;
    end
end

endmodule

`resetall
