// SPDX-License-Identifier: GPL
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

#include <linux/ctype.h>

int cndm_exec_mbox_cmd(struct cndm_dev *cdev, void *cmd, void *rsp)
{
	bool done = false;
	int ret = 0;
	int k;

	if (!cmd || !rsp)
		return -EINVAL;

	mutex_lock(&cdev->mbox_lock);

	// write command to mailbox
	for (k = 0; k < 16; k++) {
		iowrite32(*((u32 *)(cmd + k*4)), cdev->hw_addr + 0x10000 + k*4);
	}

	// ensure the command is completely written
	wmb();

	// execute it
	iowrite32(0x00000001, cdev->hw_addr + 0x0200);

	// wait for completion
	for (k = 0; k < 100; k++) {
		done = (ioread32(cdev->hw_addr + 0x0200) & 0x00000001) == 0;
		if (done)
			break;

		udelay(100);
	}

	if (done) {
		// read response from mailbox
		for (k = 0; k < 16; k++) {
			*((u32 *)(rsp + k*4)) = ioread32(cdev->hw_addr + 0x10000 + 0x40 + k*4);
		}
	} else {
		dev_err(cdev->dev, "Command timed out");
		print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
				cmd, sizeof(struct cndm_cmd_cfg), true);
		ret = -ETIMEDOUT;
	}

	mutex_unlock(&cdev->mbox_lock);
	return ret;
}

int cndm_exec_cmd(struct cndm_dev *cdev, void *cmd, void *rsp)
{
	return cndm_exec_mbox_cmd(cdev, cmd, rsp);
}

int cndm_access_reg(struct cndm_dev *cdev, u32 reg, int raw, int write, u64 *data)
{
	struct cndm_cmd_reg cmd;
	struct cndm_cmd_reg rsp;
	int ret = 0;

	cmd.opcode = CNDM_CMD_OP_ACCESS_REG;
	cmd.flags = 0x00000000;
	cmd.reg_addr = reg;
	cmd.write_val = *data;
	cmd.read_val = 0;

	if (write)
		cmd.flags |= CNDM_CMD_REG_FLG_WRITE;
	if (raw)
		cmd.flags |= CNDM_CMD_REG_FLG_RAW;

	ret = cndm_exec_cmd(cdev, &cmd, &rsp);
	if (ret)
		return ret;

	if (rsp.status)
		return rsp.status;

	if (!write)
		*data = rsp.read_val;

	return 0;
}

int cndm_hwid_sn_rd(struct cndm_dev *cdev, int *len, void *data)
{
	struct cndm_cmd_hwid cmd;
	struct cndm_cmd_hwid rsp;
	int k = 0;
	int ret = 0;
	char buf[64];
	char *ptr;

	cmd.opcode = CNDM_CMD_OP_HWID;
	cmd.flags = 0x00000000;
	cmd.index = 0;
	cmd.brd_opcode = CNDM_CMD_BRD_OP_HWID_SN_RD;
	cmd.brd_flags = 0x00000000;

	ret = cndm_exec_cmd(cdev, &cmd, &rsp);
	if (ret)
		return ret;

	if (rsp.status || rsp.brd_status)
		return rsp.status ? rsp.status : rsp.brd_status;

	// memcpy(&buf, ((void *)&rsp.data), min(cmd.len, 32)); // TODO
	memcpy(&buf, ((void *)&rsp.data), 32);
	buf[32] = 0;

	for (k = 0; k < 32; k++) {
		if (!isascii(buf[k]) || !isprint(buf[k])) {
			buf[k] = 0;
			break;
		}
	}

	ptr = strim(buf);

	if (len)
		*len = strlen(ptr);
	if (data)
		strscpy(data, ptr, 32);

	return 0;
}

int cndm_hwid_mac_rd(struct cndm_dev *cdev, u16 index, int *cnt, void *data)
{
	struct cndm_cmd_hwid cmd;
	struct cndm_cmd_hwid rsp;
	int ret = 0;

	cmd.opcode = CNDM_CMD_OP_HWID;
	cmd.flags = 0x00000000;
	cmd.index = index;
	cmd.brd_opcode = CNDM_CMD_BRD_OP_HWID_MAC_RD;
	cmd.brd_flags = 0x00000000;

	ret = cndm_exec_cmd(cdev, &cmd, &rsp);
	if (ret)
		return ret;

	if (rsp.status || rsp.brd_status)
		return rsp.status ? rsp.status : rsp.brd_status;

	if (cnt)
		*cnt = 1; // *((u16 *)&rsp.data); // TODO
	if (data)
		memcpy(data, ((void *)&rsp.data)+2, ETH_ALEN);

	return 0;
}
