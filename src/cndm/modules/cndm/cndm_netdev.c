// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"
#include "cndm_hw.h"

#include <linux/version.h>

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

static int cndm_hwtstamp_set(struct net_device *ndev, struct ifreq *ifr)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct hwtstamp_config hwts_config;

	if (copy_from_user(&hwts_config, ifr->ifr_data, sizeof(hwts_config)))
		return -EFAULT;

	if (hwts_config.flags)
		return -EINVAL;

	switch (hwts_config.tx_type) {
	case HWTSTAMP_TX_OFF:
	case HWTSTAMP_TX_ON:
		break;
	default:
		return -ERANGE;
	}

	switch (hwts_config.rx_filter) {
	case HWTSTAMP_FILTER_NONE:
		break;
	case HWTSTAMP_FILTER_ALL:
	case HWTSTAMP_FILTER_SOME:
	case HWTSTAMP_FILTER_PTP_V1_L4_EVENT:
	case HWTSTAMP_FILTER_PTP_V1_L4_SYNC:
	case HWTSTAMP_FILTER_PTP_V1_L4_DELAY_REQ:
	case HWTSTAMP_FILTER_PTP_V2_L4_EVENT:
	case HWTSTAMP_FILTER_PTP_V2_L4_SYNC:
	case HWTSTAMP_FILTER_PTP_V2_L4_DELAY_REQ:
	case HWTSTAMP_FILTER_PTP_V2_L2_EVENT:
	case HWTSTAMP_FILTER_PTP_V2_L2_SYNC:
	case HWTSTAMP_FILTER_PTP_V2_L2_DELAY_REQ:
	case HWTSTAMP_FILTER_PTP_V2_EVENT:
	case HWTSTAMP_FILTER_PTP_V2_SYNC:
	case HWTSTAMP_FILTER_PTP_V2_DELAY_REQ:
	case HWTSTAMP_FILTER_NTP_ALL:
		hwts_config.rx_filter = HWTSTAMP_FILTER_ALL;
		break;
	default:
		return -ERANGE;
	}

	memcpy(&priv->hwts_config, &hwts_config, sizeof(hwts_config));

	if (copy_to_user(ifr->ifr_data, &hwts_config, sizeof(hwts_config)))
		return -EFAULT;

	return 0;
}

static int cndm_hwtstamp_get(struct net_device *ndev, struct ifreq *ifr)
{
	struct cndm_priv *priv = netdev_priv(ndev);

	if (copy_to_user(ifr->ifr_data, &priv->hwts_config, sizeof(priv->hwts_config)))
		return -EFAULT;

	return 0;
}

static int cndm_set_mac(struct net_device *ndev, void *addr)
{
	struct sockaddr *saddr = addr;

	if (!is_valid_ether_addr(saddr->sa_data))
		return -EADDRNOTAVAIL;

	netif_addr_lock_bh(ndev);
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
	eth_hw_addr_set(ndev, saddr->sa_data);
#else
	memcpy(ndev->dev_addr, saddr->sa_data, ETH_ALEN);
#endif
	netif_addr_unlock_bh(ndev);

	return 0;
}

static int cndm_ioctl(struct net_device *ndev, struct ifreq *ifr, int cmd)
{
	switch (cmd) {
	case SIOCSHWTSTAMP:
		return cndm_hwtstamp_set(ndev, ifr);
	case SIOCGHWTSTAMP:
		return cndm_hwtstamp_get(ndev, ifr);
	default:
		return -EOPNOTSUPP;
	}
}

static const struct net_device_ops cndm_netdev_ops = {
	.ndo_open = cndm_open,
	.ndo_stop = cndm_close,
	.ndo_start_xmit = cndm_start_xmit,
	.ndo_validate_addr = eth_validate_addr,
	.ndo_set_mac_address = cndm_set_mac,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
	.ndo_eth_ioctl = cndm_ioctl,
#else
	.ndo_do_ioctl = cndm_ioctl,
#endif
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

struct net_device *cndm_create_netdev(struct cndm_dev *cdev, int port)
{
	struct device *dev = cdev->dev;
	struct net_device *ndev;
	struct cndm_priv *priv;
	int ret = 0;

	struct cndm_cmd cmd;
	struct cndm_cmd rsp;

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

	priv->hw_addr = cdev->hw_addr;

	netif_set_real_num_tx_queues(ndev, 1);
	netif_set_real_num_rx_queues(ndev, 1);

	ndev->addr_len = ETH_ALEN;

	eth_hw_addr_random(ndev);

	priv->hwts_config.flags = 0;
	priv->hwts_config.tx_type = HWTSTAMP_TX_OFF;
	priv->hwts_config.rx_filter = HWTSTAMP_FILTER_NONE;

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

	cmd.opcode = CNDM_CMD_OP_CREATE_CQ;
	cmd.flags = 0x00000000;
	cmd.port = port;
	cmd.qn = 0;
	cmd.qn2 = 0;
	cmd.pd = 0;
	cmd.size = priv->rxcq_log_size;
	cmd.dboffs = 0;
	cmd.ptr1 = priv->rxcq_region_addr;
	cmd.ptr2 = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	cmd.opcode = CNDM_CMD_OP_CREATE_RQ;
	cmd.flags = 0x00000000;
	cmd.port = port;
	cmd.qn = 0;
	cmd.qn2 = 0;
	cmd.pd = 0;
	cmd.size = priv->rxq_log_size;
	cmd.dboffs = 0;
	cmd.ptr1 = priv->rxq_region_addr;
	cmd.ptr2 = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	priv->rxq_db_offs = rsp.dboffs;

	cmd.opcode = CNDM_CMD_OP_CREATE_CQ;
	cmd.flags = 0x00000000;
	cmd.port = port;
	cmd.qn = 1;
	cmd.qn2 = 0;
	cmd.pd = 0;
	cmd.size = priv->txcq_log_size;
	cmd.dboffs = 0;
	cmd.ptr1 = priv->txcq_region_addr;
	cmd.ptr2 = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	cmd.opcode = CNDM_CMD_OP_CREATE_SQ;
	cmd.flags = 0x00000000;
	cmd.port = port;
	cmd.qn = 0;
	cmd.qn2 = 0;
	cmd.pd = 0;
	cmd.size = priv->txq_log_size;
	cmd.dboffs = 0;
	cmd.ptr1 = priv->txq_region_addr;
	cmd.ptr2 = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	priv->txq_db_offs = rsp.dboffs;

	netif_carrier_off(ndev);

	ret = register_netdev(ndev);
	if (ret) {
		dev_err(dev, "netdev registration failed");
		goto fail;
	}

	priv->registered = 1;

	priv->irq_nb.notifier_call = cndm_netdev_irq;
	priv->irq = &cdev->irq[port % cdev->irq_count];
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
	struct cndm_dev *cdev = priv->cdev;
	struct device *dev = priv->dev;

	struct cndm_cmd cmd;
	struct cndm_cmd rsp;

	cmd.opcode = CNDM_CMD_OP_DESTROY_CQ;
	cmd.flags = 0x00000000;
	cmd.port = ndev->dev_port;
	cmd.qn = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	cmd.opcode = CNDM_CMD_OP_DESTROY_RQ;
	cmd.flags = 0x00000000;
	cmd.port = ndev->dev_port;
	cmd.qn = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	priv->rxq_db_offs = rsp.dboffs;

	cmd.opcode = CNDM_CMD_OP_DESTROY_CQ;
	cmd.flags = 0x00000000;
	cmd.port = ndev->dev_port;
	cmd.qn = 1;

	cndm_exec_cmd(cdev, &cmd, &rsp);

	cmd.opcode = CNDM_CMD_OP_DESTROY_SQ;
	cmd.flags = 0x00000000;
	cmd.port = ndev->dev_port;
	cmd.qn = 0;

	cndm_exec_cmd(cdev, &cmd, &rsp);

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
