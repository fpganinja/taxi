// SPDX-License-Identifier: GPL
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

struct cndm_cq *cndm_create_cq(struct cndm_priv *priv)
{
	struct cndm_cq *cq;

	cq = kzalloc(sizeof(*cq), GFP_KERNEL);
	if (!cq)
		return ERR_PTR(-ENOMEM);

	cq->cdev = priv->cdev;
	cq->dev = priv->dev;
	cq->priv = priv;

	cq->cqn = -1;
	cq->enabled = 0;

	cq->cons_ptr = 0;

	cq->db_offset = 0;
	cq->db_addr = NULL;

	return cq;
}

void cndm_destroy_cq(struct cndm_cq *cq)
{
	cndm_close_cq(cq);

	kfree(cq);
}

int cndm_open_cq(struct cndm_cq *cq, int irqn, int size)
{
	int ret = 0;

	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	if (cq->enabled || cq->buf)
		return -EINVAL;

	cq->size = roundup_pow_of_two(size);
	cq->size_mask = cq->size - 1;
	cq->stride = 16;

	cq->buf_size = cq->size * cq->stride;
	cq->buf = dma_alloc_coherent(cq->dev, cq->buf_size, &cq->buf_dma_addr, GFP_KERNEL);
	if (!cq->buf)
		return -ENOMEM;

	cq->cons_ptr = 0;

	// clear all phase tag bits
	memset(cq->buf, 0, cq->buf_size);

	cmd.opcode = CNDM_CMD_OP_CREATE_CQ;
	cmd.flags = 0x00000000;
	cmd.port = cq->priv->ndev->dev_port;
	cmd.qn = 0;
	cmd.qn2 = irqn; // TODO
	cmd.pd = 0;
	cmd.size = ilog2(cq->size);
	cmd.dboffs = 0;
	cmd.ptr1 = cq->buf_dma_addr;
	cmd.ptr2 = 0;

	cndm_exec_cmd(cq->cdev, &cmd, &rsp);

	if (rsp.dboffs == 0) {
		netdev_err(cq->priv->ndev, "Failed to allocate CQ");
		ret = -1;
		goto fail;
	}

	cq->cqn = rsp.qn;
	cq->db_offset = rsp.dboffs;
	cq->db_addr = cq->cdev->hw_addr + rsp.dboffs;

	cq->enabled = 1;

	netdev_dbg(cq->priv->ndev, "Opened CQ %d", cq->cqn);

	return 0;

fail:
	cndm_close_cq(cq);
	return ret;
}

void cndm_close_cq(struct cndm_cq *cq)
{
	struct cndm_dev *cdev = cq->cdev;
	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	cq->enabled = 0;

	if (cq->cqn != -1) {
		cmd.opcode = CNDM_CMD_OP_DESTROY_CQ;
		cmd.flags = 0x00000000;
		cmd.port = cq->priv->ndev->dev_port;
		cmd.qn = cq->cqn;

		cndm_exec_cmd(cdev, &cmd, &rsp);

		cq->cqn = -1;
		cq->db_offset = 0;
		cq->db_addr = NULL;
	}

	if (cq->buf) {
		dma_free_coherent(cq->dev, cq->buf_size, cq->buf, cq->buf_dma_addr);
		cq->buf = NULL;
		cq->buf_dma_addr = 0;
	}
}
