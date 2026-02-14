// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

#include <linux/ethtool.h>
#include <linux/version.h>

static void cndm_get_drvinfo(struct net_device *ndev,
	struct ethtool_drvinfo *drvinfo)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_dev *cdev = priv->cdev;

	strscpy(drvinfo->driver, KBUILD_MODNAME, sizeof(drvinfo->driver));
	strscpy(drvinfo->version, DRIVER_VERSION, sizeof(drvinfo->version));
	snprintf(drvinfo->fw_version, sizeof(drvinfo->fw_version), "TODO"); // TODO
	strscpy(drvinfo->bus_info, dev_name(cdev->dev), sizeof(drvinfo->bus_info));
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 11, 0)
static int cndm_get_ts_info(struct net_device *ndev,
		struct kernel_ethtool_ts_info *info)
#else
static int cndm_get_ts_info(struct net_device *ndev,
		struct ethtool_ts_info *info)
#endif
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_dev *cdev = priv->cdev;

	ethtool_op_get_ts_info(ndev, info);

	if (cdev->ptp_clock)
		info->phc_index = ptp_clock_index(cdev->ptp_clock);

	// if (!(priv->if_features & cndm_IF_FEATURE_PTP_TS) || !cdev->ptp_clock)
	// 	return 0;

	info->so_timestamping |= SOF_TIMESTAMPING_TX_HARDWARE |
		SOF_TIMESTAMPING_RX_HARDWARE | SOF_TIMESTAMPING_RAW_HARDWARE;

	info->tx_types = BIT(HWTSTAMP_TX_OFF) | BIT(HWTSTAMP_TX_ON);

	info->rx_filters = BIT(HWTSTAMP_FILTER_NONE) | BIT(HWTSTAMP_FILTER_ALL);

	return 0;
}

const struct ethtool_ops cndm_ethtool_ops = {
	.get_drvinfo = cndm_get_drvinfo,
	.get_link = ethtool_op_get_link,
	.get_ts_info = cndm_get_ts_info,
};
