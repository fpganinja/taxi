// SPDX-License-Identifier: MIT
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

interface taxi_dma_desc_if #(
    parameter SRC_ADDR_W = 64,
    parameter logic SRC_SEL_EN = 1'b0,
    parameter SRC_SEL_W = 2,
    parameter logic SRC_ASID_EN = 1'b0,
    parameter SRC_ASID_W = 4,
    parameter DST_ADDR_W = 64,
    parameter logic DST_SEL_EN = 1'b0,
    parameter DST_SEL_W = 2,
    parameter logic DST_ASID_EN = 1'b0,
    parameter DST_ASID_W = 4,
    parameter logic IMM_EN = 1'b0,
    parameter IMM_W = 32,
    parameter LEN_W = 16,
    parameter TAG_W = 8,
    parameter logic ID_EN = 1'b0,
    parameter ID_W = 1,
    parameter logic DEST_EN = 1'b0,
    parameter DEST_W = 1,
    parameter logic USER_EN = 1'b0,
    parameter USER_W = 1
)
();
    // DMA request
    logic [SRC_ADDR_W-1:0]  req_src_addr;
    logic [SRC_SEL_W-1:0]   req_src_sel;
    logic [SRC_ASID_W-1:0]  req_src_asid;
    logic [DST_ADDR_W-1:0]  req_dst_addr;
    logic [DST_SEL_W-1:0]   req_dst_sel;
    logic [DST_ASID_W-1:0]  req_dst_asid;
    logic [IMM_W-1:0]       req_imm;
    logic                   req_imm_en;
    logic [LEN_W-1:0]       req_len;
    logic [TAG_W-1:0]       req_tag;
    logic [ID_W-1:0]        req_id;
    logic [DEST_W-1:0]      req_dest;
    logic [USER_W-1:0]      req_user;
    logic                   req_valid;
    logic                   req_ready;

    // DMA request status
    logic [LEN_W-1:0]       sts_len;
    logic [TAG_W-1:0]       sts_tag;
    logic [ID_W-1:0]        sts_id;
    logic [DEST_W-1:0]      sts_dest;
    logic [USER_W-1:0]      sts_user;
    logic [3:0]             sts_error;
    logic                   sts_valid;

    modport req_src (
        output req_src_addr,
        output req_src_sel,
        output req_src_asid,
        output req_dst_addr,
        output req_dst_sel,
        output req_dst_asid,
        output req_imm,
        output req_imm_en,
        output req_len,
        output req_tag,
        output req_id,
        output req_dest,
        output req_user,
        output req_valid,
        input  req_ready
    );

    modport req_snk (
        input  req_src_addr,
        input  req_src_sel,
        input  req_src_asid,
        input  req_dst_addr,
        input  req_dst_sel,
        input  req_dst_asid,
        input  req_imm,
        input  req_imm_en,
        input  req_len,
        input  req_tag,
        input  req_id,
        input  req_dest,
        input  req_user,
        input  req_valid,
        output req_ready
    );

    modport sts_src (
        output sts_len,
        output sts_tag,
        output sts_id,
        output sts_dest,
        output sts_user,
        output sts_error,
        output sts_valid
    );

    modport sts_snk (
        input  sts_len,
        input  sts_tag,
        input  sts_id,
        input  sts_dest,
        input  sts_user,
        input  sts_error,
        input  sts_valid
    );

endinterface
