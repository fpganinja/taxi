// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

static void cndm_free_tx_desc(struct cndm_priv *priv, int index, int napi_budget)
{
	struct device *dev = priv->dev;
	struct cndm_tx_info *tx_info = &priv->tx_info[index];
	struct sk_buff *skb = tx_info->skb;

	netdev_dbg(priv->ndev, "Free TX desc index %d", index);

	dma_unmap_single(dev, tx_info->dma_addr, tx_info->len, DMA_TO_DEVICE);
	tx_info->dma_addr = 0;

	napi_consume_skb(skb, napi_budget);
	tx_info->skb = NULL;
}

int cndm_free_tx_buf(struct cndm_priv *priv)
{
	u32 index;
	int cnt = 0;

	while (priv->txq_prod != priv->txq_cons) {
		index = priv->txq_cons & priv->txq_mask;
		cndm_free_tx_desc(priv, index, 0);
		priv->txq_cons++;
		cnt++;
	}

	return cnt;
}

static int cndm_process_tx_cq(struct net_device *ndev, int napi_budget)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_cpl *cpl;
	int done = 0;

	u32 cq_cons_ptr;
	u32 cq_index;
	u32 cons_ptr;
	u32 index;

	cq_cons_ptr = priv->txcq_cons;
	cons_ptr = priv->txq_cons;

	while (done < napi_budget) {
		cq_index = cq_cons_ptr & priv->txcq_mask;
		cpl = (struct cndm_cpl *)(priv->txcq_region + cq_index * 16);

		if (!!(cpl->phase & 0x80) == !!(cq_cons_ptr & priv->txcq_size))
			break;

		dma_rmb();

		index = cons_ptr & priv->txq_mask;

		cndm_free_tx_desc(priv, index, napi_budget);

		done++;
		cq_cons_ptr++;
		cons_ptr++;
	}

	priv->txcq_cons = cq_cons_ptr;
	priv->txq_cons = cons_ptr;

	if (netif_tx_queue_stopped(priv->tx_queue) && (done != 0 || priv->txq_prod == priv->txq_cons))
		netif_tx_wake_queue(priv->tx_queue);

	return done;
}

int cndm_poll_tx_cq(struct napi_struct *napi, int budget)
{
	struct cndm_priv *priv = container_of(napi, struct cndm_priv, tx_napi);
	int done;

	done = cndm_process_tx_cq(priv->ndev, budget);

	if (done == budget)
		return done;

	napi_complete(napi);

	// TODO re-enable interrupts

	return done;
}

int cndm_start_xmit(struct sk_buff *skb, struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);
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

	cons_ptr = READ_ONCE(priv->txq_cons);

	index = priv->txq_prod & priv->txq_mask;

	tx_desc = (struct cndm_desc *)(priv->txq_region + index*16);
	tx_info = &priv->tx_info[index];

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

	priv->txq_prod++;

	if (priv->txq_prod - priv->txq_cons >= 128) {
		netdev_dbg(ndev, "TX ring full");
		netif_tx_stop_queue(priv->tx_queue);
	}

	dma_wmb();
	iowrite32(priv->txq_prod & 0xffff, priv->hw_addr + 0x104);

	return NETDEV_TX_OK;

tx_drop:
	dev_kfree_skb_any(skb);
	return NETDEV_TX_OK;
}
