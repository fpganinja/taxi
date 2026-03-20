// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

#include <linux/version.h>

static int cndm_close(struct net_device *ndev);

static int cndm_open(struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_ring *q;
	struct cndm_cq *cq;
	int k;
	int ret = 0;

	netdev_info(ndev, "Open port");

	netif_set_real_num_tx_queues(ndev, priv->txq_count);
	netif_set_real_num_rx_queues(ndev, priv->rxq_count);

	// set up RX queues
	for (k = 0; k < priv->rxq_count; k++) {
		if (priv->rxq)
			break;

		cq = cndm_create_cq(priv);
		if (IS_ERR_OR_NULL(cq)) {
			ret = PTR_ERR(cq);
			goto fail;
		}

		ret = cndm_open_cq(cq, priv->eq, &priv->cdev->irq[0], 256);
		if (ret) {
			cndm_destroy_cq(cq);
			goto fail;
		}

		q = cndm_create_rq(priv);
		if (IS_ERR_OR_NULL(q)) {
			ret = PTR_ERR(q);
			cndm_destroy_cq(cq);
			goto fail;
		}

		ret = cndm_open_rq(q, priv, cq, 256);
		if (ret) {
			cndm_destroy_rq(q);
			cndm_destroy_cq(cq);
			goto fail;
		}

		priv->rxq = q;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 19, 0)
		netif_napi_add(ndev, &cq->napi, cndm_poll_rx_cq);
#else
		netif_napi_add(ndev, &cq->napi, cndm_poll_rx_cq, NAPI_POLL_WEIGHT);
#endif
		napi_enable(&cq->napi);
	}

	// set up TX queues
	for (k = 0; k < priv->txq_count; k++) {
		if (priv->txq)
			break;

		cq = cndm_create_cq(priv);
		if (IS_ERR_OR_NULL(cq)) {
			ret = PTR_ERR(cq);
			goto fail;
		}

		ret = cndm_open_cq(cq, priv->eq, &priv->cdev->irq[0], 256);
		if (ret) {
			cndm_destroy_cq(cq);
			goto fail;
		}

		q = cndm_create_sq(priv);
		if (IS_ERR_OR_NULL(q)) {
			ret = PTR_ERR(q);
			cndm_destroy_cq(cq);
			goto fail;
		}

		q->tx_queue = netdev_get_tx_queue(ndev, k);

		ret = cndm_open_sq(q, priv, cq, 256);
		if (ret) {
			cndm_destroy_sq(q);
			cndm_destroy_cq(cq);
			goto fail;
		}

		priv->txq = q;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 19, 0)
		netif_napi_add_tx(ndev, &cq->napi, cndm_poll_tx_cq);
#else
		netif_tx_napi_add(ndev, &cq->napi, cndm_poll_tx_cq, NAPI_POLL_WEIGHT);
#endif
		napi_enable(&cq->napi);
	}

	netif_tx_start_all_queues(ndev);
	netif_device_attach(ndev);
	netif_carrier_on(ndev);

	priv->port_up = 1;

	return 0;

fail:
	cndm_close(ndev);
	return ret;
}

static int cndm_close(struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_ring *q;
	struct cndm_cq *cq;
	int k;

	netdev_info(ndev, "Close port");

	if (!priv->port_up)
		return 0;

	netif_tx_lock_bh(ndev);
	netif_tx_stop_all_queues(ndev);
	netif_tx_unlock_bh(ndev);

	netif_carrier_off(ndev);
	netif_tx_disable(ndev);

	priv->port_up = 0;

	// clean up TX queues
	for (k = 0; k < priv->txq_count; k++) {
		if (!priv->txq)
			break;

		q = priv->txq;
		cq = q->cq;

		napi_disable(&cq->napi);
		netif_napi_del(&cq->napi);

		cndm_destroy_sq(q);
		cndm_destroy_cq(cq);

		priv->txq = NULL;
	}

	// clean up RX queues
	for (k = 0; k < priv->rxq_count; k++) {
		if (!priv->rxq)
			break;

		q = priv->rxq;
		cq = q->cq;

		napi_disable(&cq->napi);
		netif_napi_del(&cq->napi);

		cndm_destroy_rq(q);
		cndm_destroy_cq(cq);

		priv->rxq = NULL;
	}

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

struct net_device *cndm_create_netdev(struct cndm_dev *cdev, int port)
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

	priv->hw_addr = cdev->hw_addr;

	priv->rxq_count = 1;
	priv->txq_count = 1;

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

	priv->eq = cndm_create_eq(priv);
	if (IS_ERR_OR_NULL(priv->eq)) {
		ret = PTR_ERR(priv->eq);
		priv->eq = NULL;
		goto fail;
	}

	ret = cndm_open_eq(priv->eq, &priv->cdev->irq[0], 256);
	if (ret) {
		cndm_destroy_eq(priv->eq);
		goto fail;
	}

	netif_carrier_off(ndev);

	ret = register_netdev(ndev);
	if (ret) {
		dev_err(dev, "netdev registration failed");
		goto fail;
	}

	priv->registered = 1;

	return ndev;

fail:
	cndm_destroy_netdev(ndev);
	return ERR_PTR(ret);
}

void cndm_destroy_netdev(struct net_device *ndev)
{
	struct cndm_priv *priv = netdev_priv(ndev);

	if (priv->registered)
		unregister_netdev(ndev);

	if (priv->eq)
		cndm_destroy_eq(priv->eq);

	free_netdev(ndev);
}
