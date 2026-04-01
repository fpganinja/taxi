// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

static void cndm_rq_cq_handler(struct cndm_cq *cq);

struct cndm_ring *cndm_create_rq(struct cndm_priv *priv)
{
	struct cndm_ring *rq;

	rq = kzalloc(sizeof(*rq), GFP_KERNEL);
	if (!rq)
		return ERR_PTR(-ENOMEM);

	rq->cdev = priv->cdev;
	rq->dev = priv->dev;
	rq->priv = priv;

	rq->index = -1;
	rq->enabled = 0;

	rq->prod_ptr = 0;
	rq->cons_ptr = 0;

	rq->db_offset = 0;
	rq->db_addr = NULL;

	return rq;
}

void cndm_destroy_rq(struct cndm_ring *rq)
{
	cndm_close_rq(rq);

	kfree(rq);
}

int cndm_open_rq(struct cndm_ring *rq, struct cndm_priv *priv, struct cndm_cq *cq, int size)
{
	int ret = 0;

	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	if (rq->enabled || rq->buf || !priv || !cq)
		return -EINVAL;

	rq->size = roundup_pow_of_two(size);
	rq->size_mask = rq->size - 1;
	rq->stride = 16;

	rq->rx_info = kvzalloc(sizeof(*rq->rx_info) * rq->size, GFP_KERNEL);
	if (!rq->rx_info)
		return -ENOMEM;

	rq->buf_size = rq->size * rq->stride;
	rq->buf = dma_alloc_coherent(rq->dev, rq->buf_size, &rq->buf_dma_addr, GFP_KERNEL);
	if (!rq->buf) {
		ret = -ENOMEM;
		goto fail;
	}

	rq->priv = priv;
	rq->cq = cq;
	cq->src_ring = rq;
	cq->handler = cndm_rq_cq_handler;

	rq->prod_ptr = 0;
	rq->cons_ptr = 0;

	cmd.opcode = CNDM_CMD_OP_CREATE_RQ;
	cmd.flags = 0x00000000;
	cmd.port = rq->priv->ndev->dev_port;
	cmd.qn = 0;
	cmd.qn2 = cq->cqn;
	cmd.pd = 0;
	cmd.size = ilog2(rq->size);
	cmd.dboffs = 0;
	cmd.ptr1 = rq->buf_dma_addr;
	cmd.ptr2 = 0;

	ret = cndm_exec_cmd(rq->cdev, &cmd, &rsp);
	if (ret) {
		netdev_err(rq->priv->ndev, "Failed to execute command");
		goto fail;
	}

	if (rsp.status || rsp.dboffs == 0) {
		netdev_err(rq->priv->ndev, "Failed to allocate RQ");
		ret = rsp.status;
		goto fail;
	}

	rq->index = rsp.qn;
	rq->db_offset = rsp.dboffs;
	rq->db_addr = rq->cdev->hw_addr + rsp.dboffs;

	rq->enabled = 1;

	netdev_dbg(cq->priv->ndev, "Opened RQ %d (CQ %d)", rq->index, cq->cqn);

	ret = cndm_refill_rx_buffers(rq);
	if (ret) {
		netdev_err(priv->ndev, "failed to allocate RX buffer for RX queue index %d (of %u total) entry index %u (of %u total)",
				rq->index, priv->rxq_count, rq->prod_ptr, rq->size);
		if (ret == -ENOMEM)
			netdev_err(priv->ndev, "machine might not have enough DMA-capable RAM; try to decrease number of RX channels (currently %u) and/or RX ring parameters (entries; currently %u)",
					priv->rxq_count, rq->size);

		goto fail;
	}

	return 0;

fail:
	cndm_close_rq(rq);
	return ret;
}

void cndm_close_rq(struct cndm_ring *rq)
{
	struct cndm_dev *cdev = rq->cdev;
	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	rq->enabled = 0;

	if (rq->cq) {
		rq->cq->src_ring = NULL;
		rq->cq->handler = NULL;
	}

	rq->cq = NULL;

	if (rq->index != -1) {
		cmd.opcode = CNDM_CMD_OP_DESTROY_RQ;
		cmd.flags = 0x00000000;
		cmd.port = rq->priv->ndev->dev_port;
		cmd.qn = rq->index;

		cndm_exec_cmd(cdev, &cmd, &rsp);

		rq->index = -1;
		rq->db_offset = 0;
		rq->db_addr = NULL;
	}

	if (rq->buf) {
		cndm_free_rx_buf(rq);

		dma_free_coherent(rq->dev, rq->buf_size, rq->buf, rq->buf_dma_addr);
		rq->buf = NULL;
		rq->buf_dma_addr = 0;
	}

	if (rq->rx_info) {
		kvfree(rq->rx_info);
		rq->rx_info = NULL;
	}

	rq->priv = NULL;
}

bool cndm_is_rq_ring_empty(const struct cndm_ring *rq)
{
	return rq->prod_ptr == rq->cons_ptr;
}

bool cndm_is_rq_ring_full(const struct cndm_ring *rq)
{
	return (rq->prod_ptr - rq->cons_ptr) >= rq->size;
}

void cndm_rq_write_prod_ptr(const struct cndm_ring *rq)
{
	iowrite32(rq->prod_ptr & 0xffff, rq->db_addr);
}

static void cndm_free_rx_desc(struct cndm_ring *rq, int index)
{
	struct cndm_priv *priv = rq->priv;
	struct device *dev = priv->dev;
	struct cndm_rx_info *rx_info = &rq->rx_info[index];

	netdev_dbg(priv->ndev, "Free RX desc index %d", index);

	if (!rx_info->page)
		return;

	dma_unmap_page(dev, rx_info->dma_addr, rx_info->len, DMA_FROM_DEVICE);
	rx_info->dma_addr = 0;
	__free_pages(rx_info->page, 0);
	rx_info->page = NULL;
}

int cndm_free_rx_buf(struct cndm_ring *rq)
{
	u32 index;
	int cnt = 0;

	while (!cndm_is_rq_ring_empty(rq)) {
		index = rq->cons_ptr & rq->size_mask;
		cndm_free_rx_desc(rq, index);
		rq->cons_ptr++;
		cnt++;
	}

	return cnt;
}

static int cndm_prepare_rx_desc(struct cndm_ring *rq, int index)
{
	struct cndm_priv *priv = rq->priv;
	struct device *dev = rq->dev;
	struct cndm_rx_info *rx_info = &rq->rx_info[index];
	struct cndm_desc *rx_desc = (struct cndm_desc *)(rq->buf + index*16);
	struct page *page;
	u32 len = PAGE_SIZE;
	dma_addr_t dma_addr;

	netdev_dbg(priv->ndev, "Prepare RX desc index %d", index);

	page = dev_alloc_pages(0);
	if (unlikely(!page)) {
		netdev_err(priv->ndev, "Failed to allocate page");
		return -ENOMEM;
	}

	dma_addr = dma_map_page(dev, page, 0, len, DMA_FROM_DEVICE);

	if (unlikely(dma_mapping_error(dev, dma_addr))) {
		netdev_err(priv->ndev, "Mapping failed");
		__free_pages(page, 0);
		return -1;
	}

	rx_desc->len = cpu_to_le32(len);
	rx_desc->addr = cpu_to_le64(dma_addr);

	rx_info->page = page;
	rx_info->len = len;
	rx_info->dma_addr = dma_addr;

	return 0;
}

int cndm_refill_rx_buffers(struct cndm_ring *rq)
{
	u32 missing = 128 - (rq->prod_ptr - rq->cons_ptr); // TODO
	int ret = 0;

	if (missing < 8)
		return 0;

	for (; missing-- > 0;) {
		ret = cndm_prepare_rx_desc(rq, rq->prod_ptr & rq->size_mask);
		if (ret)
			break;
		rq->prod_ptr++;
	}

	dma_wmb();
	cndm_rq_write_prod_ptr(rq);

	return ret;
}

static int cndm_process_rx_cq(struct cndm_cq *cq, int napi_budget)
{
	struct cndm_priv *priv = cq->priv;
	struct cndm_ring *rq = cq->src_ring;
	struct cndm_cpl *cpl;
	struct cndm_rx_info *rx_info;
	struct sk_buff *skb;
	struct page *page;
	int done = 0;
	u32 len;

	u32 cq_cons_ptr;
	u32 cq_index;
	u32 cons_ptr;
	u32 index;

	cq_cons_ptr = cq->cons_ptr;
	cons_ptr = rq->cons_ptr;

	while (done < napi_budget) {
		cq_index = cq_cons_ptr & cq->size_mask;
		cpl = (struct cndm_cpl *)(cq->buf + cq_index * 16);

		if (!!(cpl->phase & 0x80) == !!(cq_cons_ptr & cq->size))
			break;

		dma_rmb();

		index = cons_ptr & rq->size_mask;

		rx_info = &rq->rx_info[index];
		page = rx_info->page;
		len = min_t(u32, le16_to_cpu(cpl->len), rx_info->len);

		netdev_dbg(priv->ndev, "Process RX cpl index %d", index);

		if (!page) {
			netdev_err(priv->ndev, "Null page at index %d", index);
			break;
		}

		dma_unmap_page(priv->dev, rx_info->dma_addr, rx_info->len, DMA_FROM_DEVICE);
		rx_info->dma_addr = 0;
		rx_info->page = NULL;

		if (len < ETH_HLEN) {
			netdev_warn(priv->ndev, "Dropping short frame (len %d)", len);
			__free_pages(page, 0);
			goto rx_drop;
		}

		skb = napi_get_frags(&cq->napi);
		if (!skb) {
			netdev_err(priv->ndev, "Failed to allocate skb %d", index);
			__free_pages(page, 0);
			goto rx_drop;
		}

		// RX hardware timestamp
		skb_hwtstamps(skb)->hwtstamp = cndm_read_cpl_ts(rq, cpl);

		__skb_fill_page_desc(skb, 0, page, 0, len);

		skb_shinfo(skb)->nr_frags = 1;
		skb->len = len;
		skb->data_len = len;
		skb->truesize = rx_info->len;

		napi_gro_frags(&cq->napi);

rx_drop:
		done++;
		cq_cons_ptr++;
		cons_ptr++;
	}

	cq->cons_ptr = cq_cons_ptr;
	rq->cons_ptr = cons_ptr;

	cndm_refill_rx_buffers(rq);
	cndm_cq_write_cons_ptr(cq);

	return done;
}

static void cndm_rq_cq_handler(struct cndm_cq *cq)
{
	napi_schedule_irqoff(&cq->napi);
}

int cndm_poll_rx_cq(struct napi_struct *napi, int budget)
{
	struct cndm_cq *cq = container_of(napi, struct cndm_cq, napi);
	int done;

	done = cndm_process_rx_cq(cq, budget);

	if (done == budget)
		return done;

	napi_complete(napi);

	cndm_cq_write_cons_ptr_arm(cq);

	return done;
}
