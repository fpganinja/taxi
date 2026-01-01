// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

static int cndm_open(struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);

	cndm_refill_rx_buffers(priv);

	priv->tx_queue = netdev_get_tx_queue(ndev, 0);

	netif_napi_add_tx(ndev, &priv->tx_napi, cndm_poll_tx_cq);
	napi_enable(&priv->tx_napi);
	netif_napi_add(ndev, &priv->rx_napi, cndm_poll_rx_cq);
	napi_enable(&priv->rx_napi);

	netif_tx_start_all_queues(ndev);
	netif_carrier_on(ndev);
	netif_device_attach(ndev);

	priv->port_up = 1;

	return 0;
}

static int cndm_close(struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);

	priv->port_up = 0;

	napi_disable(&priv->tx_napi);
	netif_napi_del(&priv->tx_napi);
	napi_disable(&priv->rx_napi);
	netif_napi_del(&priv->rx_napi);

	netif_tx_stop_all_queues(ndev);
	netif_carrier_off(ndev);
	netif_tx_disable(ndev);

	return 0;
}

static const struct net_device_ops cndm_netdev_ops = {
	.ndo_open = cndm_open,
	.ndo_stop = cndm_close,
	.ndo_start_xmit = cndm_start_xmit,
};

static int cndm_netdev_irq(struct notifier_block *nb, unsigned long action, void *data)
{
	struct cndm_priv *priv = container_of(nb, struct cndm_priv, irq_nb);

	netdev_dbg(priv->ndev, "Interrupt");

	if (priv->port_up) {
		napi_schedule_irqoff(&priv->tx_napi);
		napi_schedule_irqoff(&priv->rx_napi);
	}

	return NOTIFY_DONE;
}

struct net_device *cndm_create_netdev(struct cndm_dev *cdev, int port, void __iomem *hw_addr)
{
	struct device *dev = cdev->dev;
	struct net_device *ndev;
	struct cndm_priv *priv;
	int ret = 0;

	ndev = alloc_etherdev_mqs(sizeof(*priv), 1, 1);
	if (!ndev) {
		dev_err(dev, "Failed to allocate net_device");
		return ERR_PTR(-ENOMEM);
	}

	SET_NETDEV_DEV(ndev, dev);
	ndev->dev_port = port;

	priv = netdev_priv(ndev);
	memset(priv, 0, sizeof(*priv));

	priv->dev = dev;
	priv->ndev = ndev;
	priv->cdev = cdev;

	priv->hw_addr = hw_addr;

	netif_set_real_num_tx_queues(ndev, 1);
	netif_set_real_num_rx_queues(ndev, 1);

	ndev->addr_len = ETH_ALEN;

	eth_hw_addr_random(ndev);

	ndev->netdev_ops = &cndm_netdev_ops;
	ndev->ethtool_ops = &cndm_ethtool_ops;

	ndev->hw_features = 0;
	ndev->features = 0;

	ndev->min_mtu = ETH_MIN_MTU;
	ndev->max_mtu = 1500;

	priv->rxq_log_size = ilog2(256);
	priv->rxq_size = 1 << priv->rxq_log_size;
	priv->rxq_mask = priv->rxq_size-1;
	priv->rxq_prod = 0;
	priv->rxq_cons = 0;

	priv->txq_log_size = ilog2(256);
	priv->txq_size = 1 << priv->txq_log_size;
	priv->txq_mask = priv->txq_size-1;
	priv->txq_prod = 0;
	priv->txq_cons = 0;

	priv->rxcq_log_size = ilog2(256);
	priv->rxcq_size = 1 << priv->rxcq_log_size;
	priv->rxcq_mask = priv->rxcq_size-1;
	priv->rxcq_prod = 0;
	priv->rxcq_cons = 0;

	priv->txcq_log_size = ilog2(256);
	priv->txcq_size = 1 << priv->txcq_log_size;
	priv->txcq_mask = priv->txcq_size-1;
	priv->txcq_prod = 0;
	priv->txcq_cons = 0;

	// allocate DMA buffers
	priv->txq_region_len = priv->txq_size*16;
	priv->txq_region = dma_alloc_coherent(dev, priv->txq_region_len, &priv->txq_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!priv->txq_region) {
		ret = -ENOMEM;
		goto fail;
	}

	priv->rxq_region_len = priv->rxq_size*16;
	priv->rxq_region = dma_alloc_coherent(dev, priv->rxq_region_len, &priv->rxq_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!priv->rxq_region) {
		ret = -ENOMEM;
		goto fail;
	}

	priv->txcq_region_len = priv->txcq_size*16;
	priv->txcq_region = dma_alloc_coherent(dev, priv->txcq_region_len, &priv->txcq_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!priv->txcq_region) {
		ret = -ENOMEM;
		goto fail;
	}

	priv->rxcq_region_len = priv->rxcq_size*16;
	priv->rxcq_region = dma_alloc_coherent(dev, priv->rxcq_region_len, &priv->rxcq_region_addr, GFP_KERNEL | __GFP_ZERO);
	if (!priv->rxcq_region) {
		ret = -ENOMEM;
		goto fail;
	}

	// allocate info rings
	priv->tx_info = kvzalloc(sizeof(*priv->tx_info) * priv->txq_size, GFP_KERNEL);
	if (!priv->tx_info) {
		ret = -ENOMEM;
		goto fail;
	}

	priv->rx_info = kvzalloc(sizeof(*priv->rx_info) * priv->rxq_size, GFP_KERNEL);
	if (!priv->tx_info) {
		ret = -ENOMEM;
		goto fail;
	}

	iowrite32(0x00000000, priv->hw_addr + 0x200);
	iowrite32(priv->rxq_prod & 0xffff, priv->hw_addr + 0x204);
	iowrite32(priv->rxq_region_addr & 0xffffffff, priv->hw_addr + 0x208);
	iowrite32(priv->rxq_region_addr >> 32, priv->hw_addr + 0x20c);
	iowrite32(0x00000001 | (priv->rxq_log_size << 16), priv->hw_addr + 0x200);

	iowrite32(0x00000000, priv->hw_addr + 0x100);
	iowrite32(priv->txq_prod & 0xffff, priv->hw_addr + 0x104);
	iowrite32(priv->txq_region_addr & 0xffffffff, priv->hw_addr + 0x108);
	iowrite32(priv->txq_region_addr >> 32, priv->hw_addr + 0x10c);
	iowrite32(0x00000001 | (priv->txq_log_size << 16), priv->hw_addr + 0x100);

	iowrite32(0x00000000, priv->hw_addr + 0x400);
	iowrite32(priv->rxcq_region_addr & 0xffffffff, priv->hw_addr + 0x408);
	iowrite32(priv->rxcq_region_addr >> 32, priv->hw_addr + 0x40c);
	iowrite32(0x00000001 | (priv->rxcq_log_size << 16), priv->hw_addr + 0x400);

	iowrite32(0x00000000, priv->hw_addr + 0x300);
	iowrite32(priv->txcq_region_addr & 0xffffffff, priv->hw_addr + 0x308);
	iowrite32(priv->txcq_region_addr >> 32, priv->hw_addr + 0x30c);
	iowrite32(0x00000001 | (priv->txcq_log_size << 16), priv->hw_addr + 0x300);

	netif_carrier_off(ndev);

	ret = register_netdev(ndev);
	if (ret) {
		dev_err(dev, "netdev registration failed");
		goto fail;
	}

	priv->registered = 1;

	priv->irq_nb.notifier_call = cndm_netdev_irq;
	priv->irq = cdev->irq[port % cdev->irq_count];
	ret = atomic_notifier_chain_register(&priv->irq->nh, &priv->irq_nb);
	if (ret) {
		priv->irq = NULL;
		goto fail;
	}


	return ndev;

fail:
	cndm_destroy_netdev(ndev);
	return ERR_PTR(ret);
}

void cndm_destroy_netdev(struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct device *dev = priv->dev;

	iowrite32(0x00000000, priv->hw_addr + 0x200);
	iowrite32(0x00000000, priv->hw_addr + 0x100);
	iowrite32(0x00000000, priv->hw_addr + 0x400);
	iowrite32(0x00000000, priv->hw_addr + 0x300);

	if (priv->irq)
		atomic_notifier_chain_unregister(&priv->irq->nh, &priv->irq_nb);

	priv->irq = NULL;

	if (priv->registered)
		unregister_netdev(ndev);

	if (priv->tx_info) {
		cndm_free_tx_buf(priv);
		kvfree(priv->tx_info);
	}
	if (priv->rx_info) {
		cndm_free_rx_buf(priv);
		kvfree(priv->rx_info);
	}
	if (priv->txq_region)
		dma_free_coherent(dev, priv->txq_region_len, priv->txq_region, priv->txq_region_addr);
	if (priv->rxq_region)
		dma_free_coherent(dev, priv->rxq_region_len, priv->rxq_region, priv->rxq_region_addr);
	if (priv->txcq_region)
		dma_free_coherent(dev, priv->txcq_region_len, priv->txcq_region, priv->txcq_region_addr);
	if (priv->rxcq_region)
		dma_free_coherent(dev, priv->rxcq_region_len, priv->rxcq_region, priv->rxcq_region_addr);

	free_netdev(ndev);
}
