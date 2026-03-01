/* SPDX-License-Identifier: GPL */
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#ifndef CNDM_HW_H
#define CNDM_HW_H

#include <linux/types.h>

#define CNDM_CMD_OP_NOP 0x0000

#define CNDM_CMD_OP_CREATE_EQ  0x0200
#define CNDM_CMD_OP_MODIFY_EQ  0x0201
#define CNDM_CMD_OP_QUERY_EQ   0x0202
#define CNDM_CMD_OP_DESTROY_EQ 0x0203

#define CNDM_CMD_OP_CREATE_CQ  0x0210
#define CNDM_CMD_OP_MODIFY_CQ  0x0211
#define CNDM_CMD_OP_QUERY_CQ   0x0212
#define CNDM_CMD_OP_DESTROY_CQ 0x0213

#define CNDM_CMD_OP_CREATE_SQ  0x0220
#define CNDM_CMD_OP_MODIFY_SQ  0x0221
#define CNDM_CMD_OP_QUERY_SQ   0x0222
#define CNDM_CMD_OP_DESTROY_SQ 0x0223

#define CNDM_CMD_OP_CREATE_RQ  0x0230
#define CNDM_CMD_OP_MODIFY_RQ  0x0231
#define CNDM_CMD_OP_QUERY_RQ   0x0232
#define CNDM_CMD_OP_DESTROY_RQ 0x0233

#define CNDM_CMD_OP_CREATE_QP  0x0240
#define CNDM_CMD_OP_MODIFY_QP  0x0241
#define CNDM_CMD_OP_QUERY_QP   0x0242
#define CNDM_CMD_OP_DESTROY_QP 0x0243

struct cndm_cmd {
	__le16 rsvd;
	union {
		__le16 opcode;
		__le16 status;
	};
	__le32 flags;
	__le32 port;
	__le32 qn;

	__le32 qn2;
	__le32 pd;
	__le32 size;
	__le32 dboffs;

	__le64 ptr1;
	__le64 ptr2;

	__le32 dw12;
	__le32 dw13;
	__le32 dw14;
	__le32 dw15;
};

struct cndm_desc {
	__le16 rsvd0;
	union {
		struct {
			__le16 csum_cmd;
		} tx;
		struct {
			__le16 rsvd0;
		} rx;
	};

	__le32 len;
	__le64 addr;
};

struct cndm_cpl {
	__u8 rsvd[4];
	__le32 len;
	__le32 ts_ns;
	__le16 ts_fns;
	__u8 ts_s;
	__u8 phase;
};

struct cndm_event {
	__le16 type;
	__le16 source;
	__le32 rsvd0;
	__le32 rsvd1;
	__le32 rsvd2;
	__le32 rsvd3;
	__le32 rsvd4;
	__le32 rsvd5;
	__le32 phase;
};

#endif
