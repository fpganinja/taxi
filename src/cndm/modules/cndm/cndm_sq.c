// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

struct cndm_ring *cndm_create_sq(struct cndm_priv *priv)
{
	struct cndm_ring *sq;

	sq = kzalloc(sizeof(*sq), GFP_KERNEL);
	if (!sq)
		return ERR_PTR(-ENOMEM);

	sq->cdev = priv->cdev;
	sq->dev = priv->dev;
	sq->priv = priv;

	sq->index = -1;
	sq->enabled = 0;

	sq->prod_ptr = 0;
	sq->cons_ptr = 0;

	sq->db_offset = 0;
	sq->db_addr = NULL;

	return sq;
}

void cndm_destroy_sq(struct cndm_ring *sq)
{
	cndm_close_sq(sq);

	kfree(sq);
}

int cndm_open_sq(struct cndm_ring *sq, struct cndm_priv *priv, struct cndm_cq *cq, int size)
{
	int ret = 0;

	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	if (sq->enabled || sq->buf || !priv || !cq)
		return -EINVAL;

	sq->size = roundup_pow_of_two(size);
	sq->size_mask = sq->size - 1;
	sq->stride = 16;

	sq->tx_info = kvzalloc(sizeof(*sq->tx_info) * sq->size, GFP_KERNEL);
	if (!sq->tx_info)
		ret = -ENOMEM;

	sq->buf_size = sq->size * sq->stride;
	sq->buf = dma_alloc_coherent(sq->dev, sq->buf_size, &sq->buf_dma_addr, GFP_KERNEL);
	if (!sq->buf) {
		return -ENOMEM;
		goto fail;
	}

	sq->priv = priv;
	sq->cq = cq;
	cq->src_ring = sq;
	// cq->handler = cndm_tx_irq;

	sq->prod_ptr = 0;
	sq->cons_ptr = 0;

	cmd.opcode = CNDM_CMD_OP_CREATE_SQ;
	cmd.flags = 0x00000000;
	cmd.port = sq->priv->ndev->dev_port;
	cmd.qn = 0;
	cmd.qn2 = cq->cqn;
	cmd.pd = 0;
	cmd.size = ilog2(sq->size);
	cmd.dboffs = 0;
	cmd.ptr1 = sq->buf_dma_addr;
	cmd.ptr2 = 0;

	cndm_exec_cmd(sq->cdev, &cmd, &rsp);

	if (rsp.dboffs == 0) {
		netdev_err(sq->priv->ndev, "Failed to allocate SQ");
		ret = -1;
		goto fail;
	}

	sq->index = rsp.qn;
	sq->db_offset = rsp.dboffs;
	sq->db_addr = sq->cdev->hw_addr + rsp.dboffs;

	sq->enabled = 1;

	netdev_dbg(cq->priv->ndev, "Opened SQ %d (CQ %d)", sq->index, cq->cqn);

	return 0;

fail:
	cndm_close_sq(sq);
	return ret;
}

void cndm_close_sq(struct cndm_ring *sq)
{
	struct cndm_dev *cdev = sq->cdev;
	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	sq->enabled = 0;

	if (sq->cq) {
		sq->cq->src_ring = NULL;
		sq->cq->handler = NULL;
	}

	sq->cq = NULL;

	if (sq->index != -1) {
		cmd.opcode = CNDM_CMD_OP_DESTROY_SQ;
		cmd.flags = 0x00000000;
		cmd.port = sq->priv->ndev->dev_port;
		cmd.qn = sq->index;

		cndm_exec_cmd(cdev, &cmd, &rsp);

		sq->index = -1;
		sq->db_offset = 0;
		sq->db_addr = NULL;
	}

	if (sq->buf) {
		cndm_free_tx_buf(sq);

		dma_free_coherent(sq->dev, sq->buf_size, sq->buf, sq->buf_dma_addr);
		sq->buf = NULL;
		sq->buf_dma_addr = 0;
	}

	if (sq->tx_info) {
		kvfree(sq->tx_info);
		sq->tx_info = NULL;
	}

	sq->priv = NULL;
}

bool cndm_is_sq_ring_empty(const struct cndm_ring *sq)
{
	return sq->prod_ptr == sq->cons_ptr;
}

bool cndm_is_sq_ring_full(const struct cndm_ring *sq)
{
	return (sq->prod_ptr - sq->cons_ptr) >= sq->size;
}

void cndm_sq_write_prod_ptr(const struct cndm_ring *sq)
{
	iowrite32(sq->prod_ptr & 0xffff, sq->db_addr);
}

static void cndm_free_tx_desc(struct cndm_ring *sq, int index, int napi_budget)
{
	struct cndm_priv *priv = sq->priv;
	struct device *dev = priv->dev;
	struct cndm_tx_info *tx_info = &sq->tx_info[index];
	struct sk_buff *skb = tx_info->skb;

	netdev_dbg(priv->ndev, "Free TX desc index %d", index);

	dma_unmap_single(dev, tx_info->dma_addr, tx_info->len, DMA_TO_DEVICE);
	tx_info->dma_addr = 0;

	napi_consume_skb(skb, napi_budget);
	tx_info->skb = NULL;
}

int cndm_free_tx_buf(struct cndm_ring *sq)
{
	u32 index;
	int cnt = 0;

	while (!cndm_is_sq_ring_empty(sq)) {
		index = sq->cons_ptr & sq->size_mask;
		cndm_free_tx_desc(sq, index, 0);
		sq->cons_ptr++;
		cnt++;
	}

	return cnt;
}

static int cndm_process_tx_cq(struct cndm_cq *cq, int napi_budget)
{
	struct cndm_priv *priv = cq->priv;
	struct cndm_ring *sq = cq->src_ring;
	struct cndm_tx_info *tx_info;
	struct cndm_cpl *cpl;
	struct skb_shared_hwtstamps hwts;
	int done = 0;

	u32 cq_cons_ptr;
	u32 cq_index;
	u32 cons_ptr;
	u32 index;

	cq_cons_ptr = cq->cons_ptr;
	cons_ptr = sq->cons_ptr;

	while (done < napi_budget) {
		cq_index = cq_cons_ptr & cq->size_mask;
		cpl = (struct cndm_cpl *)(cq->buf + cq_index * 16);

		if (!!(cpl->phase & 0x80) == !!(cq_cons_ptr & cq->size))
			break;

		dma_rmb();

		index = cons_ptr & sq->size_mask;
		tx_info = &sq->tx_info[index];

		// TX hardware timestamp
		if (unlikely(tx_info->ts_requested)) {
			netdev_dbg(priv->ndev, "%s: TX TS requested", __func__);
			hwts.hwtstamp = cndm_read_cpl_ts(sq, cpl);
			skb_tstamp_tx(tx_info->skb, &hwts);
		}

		cndm_free_tx_desc(sq, index, napi_budget);

		done++;
		cq_cons_ptr++;
		cons_ptr++;
	}

	cq->cons_ptr = cq_cons_ptr;
	sq->cons_ptr = cons_ptr;

	cndm_cq_write_cons_ptr(cq);

	if (netif_tx_queue_stopped(sq->tx_queue) && (done != 0 || sq->prod_ptr == sq->cons_ptr))
		netif_tx_wake_queue(sq->tx_queue);

	return done;
}

int cndm_poll_tx_cq(struct napi_struct *napi, int budget)
{
	struct cndm_cq *cq = container_of(napi, struct cndm_cq, napi);
	int done;

	done = cndm_process_tx_cq(cq, budget);

	if (done == budget)
		return done;

	napi_complete(napi);

	// TODO re-enable interrupts
	cndm_cq_write_cons_ptr_arm(cq);

	return done;
}

int cndm_start_xmit(struct sk_buff *skb, struct net_device *ndev)
{
	struct skb_shared_info *shinfo = skb_shinfo(skb);
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_ring *sq = priv->txq;
	struct device *dev = priv->dev;
	u32 index;
	u32 cons_ptr;
	u32 len;
	dma_addr_t dma_addr;
	struct cndm_desc *tx_desc;
	struct cndm_tx_info *tx_info;

	netdev_dbg(ndev, "Got packet for TX");

	if (skb->len < ETH_HLEN) {
		netdev_warn(ndev, "Dropping short frame");
		goto tx_drop;
	}

	cons_ptr = READ_ONCE(sq->cons_ptr);

	index = sq->prod_ptr & sq->size_mask;

	tx_desc = (struct cndm_desc *)(sq->buf + index*16);
	tx_info = &sq->tx_info[index];

	// TX hardware timestamp
	tx_info->ts_requested = 0;
	if (unlikely(shinfo->tx_flags & SKBTX_HW_TSTAMP)) {
		netdev_dbg(ndev, "%s: TX TS requested", __func__);
		shinfo->tx_flags |= SKBTX_IN_PROGRESS;
		tx_info->ts_requested = 1;
	}

	len = skb_headlen(skb);

	dma_addr = dma_map_single(dev, skb->data, len, DMA_TO_DEVICE);

	if (unlikely(dma_mapping_error(dev, dma_addr))) {
		netdev_err(ndev, "Mapping failed");
		goto tx_drop;
	}

	tx_desc->len = cpu_to_le32(len);
	tx_desc->addr = cpu_to_le64(dma_addr);

	tx_info->skb = skb;
	tx_info->len = len;
	tx_info->dma_addr = dma_addr;

	netdev_dbg(ndev, "Write desc index %d len %d", index, len);

	sq->prod_ptr++;

	skb_tx_timestamp(skb);

	if (sq->prod_ptr - sq->cons_ptr >= 128) {
		netdev_dbg(ndev, "TX ring full");
		netif_tx_stop_queue(sq->tx_queue);
	}

	dma_wmb();
	cndm_sq_write_prod_ptr(sq);

	return NETDEV_TX_OK;

tx_drop:
	dev_kfree_skb_any(skb);
	return NETDEV_TX_OK;
}
