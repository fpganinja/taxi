// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

static void cndm_free_rx_desc(struct cndm_priv *priv, int index)
{
	struct device *dev = priv->dev;
	struct cndm_rx_info *rx_info = &priv->rx_info[index];

	netdev_dbg(priv->ndev, "Free RX desc index %d", index);

	if (!rx_info->page)
		return;

	dma_unmap_page(dev, rx_info->dma_addr, rx_info->len, DMA_FROM_DEVICE);
	rx_info->dma_addr = 0;
	__free_pages(rx_info->page, 0);
	rx_info->page = NULL;
}

int cndm_free_rx_buf(struct cndm_priv *priv)
{
	u32 index;
	int cnt = 0;

	while (priv->rxq_prod != priv->rxq_cons) {
		index = priv->rxq_cons & priv->rxq_mask;
		cndm_free_rx_desc(priv, index);
		priv->rxq_cons++;
		cnt++;
	}

	return cnt;
}

static int cndm_prepare_rx_desc(struct cndm_priv *priv, int index)
{
	struct device *dev = priv->dev;
	struct cndm_rx_info *rx_info = &priv->rx_info[index];
	struct cndm_desc *rx_desc = (struct cndm_desc *)(priv->rxq_region + index*16);
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

int cndm_refill_rx_buffers(struct cndm_priv *priv)
{
	u32 missing = 128 - (priv->rxq_prod - priv->rxq_cons); // TODO
	int ret = 0;

	if (missing < 8)
		return 0;

	for (; missing-- > 0;) {
		ret = cndm_prepare_rx_desc(priv, priv->rxq_prod & priv->rxq_mask);
		if (ret)
			break;
		priv->rxq_prod++;
	}

	dma_wmb();
	iowrite32(priv->rxq_prod & 0xffff, priv->hw_addr + priv->rxq_db_offs);

	return ret;
}

static int cndm_process_rx_cq(struct net_device *ndev, int napi_budget)
{
	struct cndm_priv *priv = netdev_priv(ndev);
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

	cq_cons_ptr = priv->rxcq_cons;
	cons_ptr = priv->rxq_cons;

	while (done < napi_budget) {
		cq_index = cq_cons_ptr & priv->rxcq_mask;
		cpl = (struct cndm_cpl *)(priv->rxcq_region + cq_index * 16);

		if (!!(cpl->phase & 0x80) == !!(cq_cons_ptr & priv->rxcq_size))
			break;

		dma_rmb();

		index = cons_ptr & priv->rxq_mask;

		rx_info = &priv->rx_info[index];
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

		skb = napi_get_frags(&priv->rx_napi);
		if (!skb) {
			netdev_err(priv->ndev, "Failed to allocate skb %d", index);
			__free_pages(page, 0);
			goto rx_drop;
		}

		// RX hardware timestamp
		skb_hwtstamps(skb)->hwtstamp = cndm_read_cpl_ts(priv, cpl);

		__skb_fill_page_desc(skb, 0, page, 0, len);

		skb_shinfo(skb)->nr_frags = 1;
		skb->len = len;
		skb->data_len = len;
		skb->truesize = rx_info->len;

		napi_gro_frags(&priv->rx_napi);

rx_drop:
		done++;
		cq_cons_ptr++;
		cons_ptr++;
	}

	priv->rxcq_cons = cq_cons_ptr;
	priv->rxq_cons = cons_ptr;

	cndm_refill_rx_buffers(priv);

	return done;
}

int cndm_poll_rx_cq(struct napi_struct *napi, int budget)
{
	struct cndm_priv *priv = container_of(napi, struct cndm_priv, rx_napi);
	int done;

	done = cndm_process_rx_cq(priv->ndev, budget);

	if (done == budget)
		return done;

	napi_complete(napi);

	// TODO re-enable interrupts

	return done;
}
