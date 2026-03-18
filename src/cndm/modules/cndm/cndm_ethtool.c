// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

#include <linux/ethtool.h>
#include <linux/version.h>

#define SFF_MODULE_ID_SFP        0x03
#define SFF_MODULE_ID_QSFP       0x0c
#define SFF_MODULE_ID_QSFP_PLUS  0x0d
#define SFF_MODULE_ID_QSFP28     0x11

static void cndm_get_drvinfo(struct net_device *ndev,
	struct ethtool_drvinfo *drvinfo)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	struct cndm_dev *cdev = priv->cdev;

	strscpy(drvinfo->driver, KBUILD_MODNAME, sizeof(drvinfo->driver));
	strscpy(drvinfo->version, DRIVER_VERSION, sizeof(drvinfo->version));
	snprintf(drvinfo->fw_version, sizeof(drvinfo->fw_version),
		"%d.%d.%d", cdev->fw_ver >> 20,
		(cdev->fw_ver >> 12) & 0xff,
		cdev->fw_ver & 0xfff);
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

	if (!cdev->ptp_clock)
		return 0;

	info->so_timestamping |= SOF_TIMESTAMPING_TX_HARDWARE |
		SOF_TIMESTAMPING_RX_HARDWARE | SOF_TIMESTAMPING_RAW_HARDWARE;

	info->tx_types = BIT(HWTSTAMP_TX_OFF) | BIT(HWTSTAMP_TX_ON);

	info->rx_filters = BIT(HWTSTAMP_FILTER_NONE) | BIT(HWTSTAMP_FILTER_ALL);

	return 0;
}

static int cndm_read_eeprom(struct net_device *ndev, u16 offset, u16 len, u8 *data)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	int ret = 0;

	struct cndm_cmd_hwid cmd;
	struct cndm_cmd_hwid rsp;

	if (len > 32)
		len = 32;

	cmd.opcode = CNDM_CMD_OP_HWMON;
	cmd.flags = 0x00000000;
	cmd.index = 0;
	cmd.brd_opcode = CNDM_CMD_BRD_OP_EEPROM_RD;
	cmd.brd_flags = 0x00000000;
	cmd.dev_addr_offset = 0;
	cmd.page = 0;
	cmd.bank = 0;
	cmd.addr = offset;
	cmd.len = len;

	ret = cndm_exec_cmd(priv->cdev, &cmd, &rsp);
	if (ret) {
		netdev_err(ndev, "Failed to execute command");
		return -ret;
	}

	if (rsp.status || rsp.brd_status) {
		netdev_warn(ndev, "Failed to read EEPROM");
		return rsp.status ? -rsp.status : -rsp.brd_status;
	}

	if (data)
		memcpy(data, ((void *)&rsp.data), len);

	return len;
}

static int cndm_read_module_eeprom(struct net_device *ndev,
		unsigned short i2c_addr, u16 page, u16 bank, u16 offset, u16 len, u8 *data)
{
	struct cndm_priv *priv = netdev_priv(ndev);
	int ret = 0;

	struct cndm_cmd_hwid cmd;
	struct cndm_cmd_hwid rsp;

	if (len > 32)
		len = 32;

	cmd.opcode = CNDM_CMD_OP_HWMON;
	cmd.flags = 0x00000000;
	cmd.index = 0; // TODO
	cmd.brd_opcode = CNDM_CMD_BRD_OP_OPTIC_RD;
	cmd.brd_flags = 0x00000000;
	cmd.dev_addr_offset = i2c_addr - 0x50;
	cmd.page = page;
	cmd.bank = bank;
	cmd.addr = offset;
	cmd.len = len;

	ret = cndm_exec_cmd(priv->cdev, &cmd, &rsp);
	if (ret) {
		netdev_err(ndev, "Failed to execute command");
		return -ret;
	}

	if (rsp.status || rsp.brd_status) {
		netdev_warn(ndev, "Failed to read module EEPROM");
		return rsp.status ? -rsp.status : -rsp.brd_status;
	}

	if (data)
		memcpy(data, ((void *)&rsp.data), len);

	return len;
}

static int cndm_query_module_id(struct net_device *ndev)
{
	int ret;
	u8 data;

	ret = cndm_read_module_eeprom(ndev, 0x50, 0, 0, 0, 1, &data);

	if (ret < 0)
		return ret;

	return data;
}

static int cndm_query_module_eeprom_by_page(struct net_device *ndev,
		unsigned short i2c_addr, u16 page, u16 bank, u16 offset, u16 len, u8 *data)
{
	int module_id;
	int ret;

	module_id = cndm_query_module_id(ndev);

	if (module_id < 0) {
		netdev_err(ndev, "%s: Failed to read module ID (%d)", __func__, module_id);
		return module_id;
	}

	switch (module_id) {
	case SFF_MODULE_ID_SFP:
		if (page > 0 || bank > 0)
			return -EINVAL;
		if (i2c_addr != 0x50 && i2c_addr != 0x51)
			return -EINVAL;
		break;
	case SFF_MODULE_ID_QSFP:
	case SFF_MODULE_ID_QSFP_PLUS:
	case SFF_MODULE_ID_QSFP28:
		if (page > 3 || bank > 0)
			return -EINVAL;
		if (i2c_addr != 0x50)
			return -EINVAL;
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, module_id);
		return -EINVAL;
	}

	// read data
	ret = cndm_read_module_eeprom(ndev, i2c_addr, page, bank, offset, len, data);

	return ret;
}

static int cndm_query_module_eeprom(struct net_device *ndev,
		u16 offset, u16 len, u8 *data)
{
	int module_id;
	unsigned short i2c_addr = 0x50;
	u16 page = 0;
	u16 bank = 0;

	module_id = cndm_query_module_id(ndev);

	if (module_id < 0) {
		netdev_err(ndev, "%s: Failed to read module ID (%d)", __func__, module_id);
		return module_id;
	}

	switch (module_id) {
	case SFF_MODULE_ID_SFP:
		i2c_addr = 0x50;
		page = 0;
		if (offset >= 256) {
			offset -= 256;
			i2c_addr = 0x51;
		}
		break;
	case SFF_MODULE_ID_QSFP:
	case SFF_MODULE_ID_QSFP_PLUS:
	case SFF_MODULE_ID_QSFP28:
		i2c_addr = 0x50;
		if (offset < 256) {
			page = 0;
		} else {
			page = 1 + ((offset - 256) / 128);
			offset -= page * 128;
		}
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, module_id);
		return -EINVAL;
	}

	// clip request to end of page
	if (offset + len > 256)
		len = 256 - offset;

	return cndm_query_module_eeprom_by_page(ndev, i2c_addr,
			page, bank, offset, len, data);
}

static int cndm_get_module_info(struct net_device *ndev,
		struct ethtool_modinfo *modinfo)
{
	int read_len = 0;
	u8 data[16];

	// read module ID and revision
	read_len = cndm_read_module_eeprom(ndev, 0x50, 0, 0, 0, 2, data);

	if (read_len < 0)
		return read_len;

	if (read_len < 2)
		return -EIO;

	// check identifier byte at address 0
	switch (data[0]) {
	case SFF_MODULE_ID_SFP:
		modinfo->type = ETH_MODULE_SFF_8472;
		modinfo->eeprom_len = ETH_MODULE_SFF_8472_LEN;
		break;
	case SFF_MODULE_ID_QSFP:
		modinfo->type = ETH_MODULE_SFF_8436;
		modinfo->eeprom_len = ETH_MODULE_SFF_8436_MAX_LEN;
		break;
	case SFF_MODULE_ID_QSFP_PLUS:
		// check revision at address 1
		if (data[1] >= 0x03) {
			modinfo->type = ETH_MODULE_SFF_8636;
			modinfo->eeprom_len = ETH_MODULE_SFF_8636_MAX_LEN;
		} else {
			modinfo->type = ETH_MODULE_SFF_8436;
			modinfo->eeprom_len = ETH_MODULE_SFF_8436_MAX_LEN;
		}
		break;
	case SFF_MODULE_ID_QSFP28:
		modinfo->type = ETH_MODULE_SFF_8636;
		modinfo->eeprom_len = ETH_MODULE_SFF_8636_MAX_LEN;
		break;
	default:
		netdev_err(ndev, "%s: Unknown module ID (0x%x)", __func__, data[0]);
		return -EINVAL;
	}

	return 0;
}

static int cndm_get_eeprom_len(struct net_device *ndev)
{
	return 256; // TODO
}

static int cndm_get_eeprom(struct net_device *ndev,
		struct ethtool_eeprom *eeprom, u8 *data)
{
	int i = 0;
	int read_len;

	if (eeprom->len == 0)
		return -EINVAL;

	eeprom->magic = 0x4d444e43;

	memset(data, 0, eeprom->len);

	while (i < eeprom->len) {
		read_len = cndm_read_eeprom(ndev, eeprom->offset + i,
				eeprom->len - i, data + i);

		if (read_len == 0)
			return 0;

		if (read_len < 0) {
			netdev_err(ndev, "%s: Failed to read EEPROM (%d)", __func__, read_len);
			return read_len;
		}

		i += read_len;
	}

	return 0;
}

static int cndm_get_module_eeprom(struct net_device *ndev,
		struct ethtool_eeprom *eeprom, u8 *data)
{
	int i = 0;
	int read_len;

	if (eeprom->len == 0)
		return -EINVAL;

	memset(data, 0, eeprom->len);

	while (i < eeprom->len) {
		read_len = cndm_query_module_eeprom(ndev, eeprom->offset + i,
				eeprom->len - i, data + i);

		if (read_len == 0)
			return 0;

		if (read_len < 0) {
			netdev_err(ndev, "%s: Failed to read module EEPROM (%d)", __func__, read_len);
			return read_len;
		}

		i += read_len;
	}

	return 0;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0)
static int cndm_get_module_eeprom_by_page(struct net_device *ndev,
		const struct ethtool_module_eeprom *eeprom,
		struct netlink_ext_ack *extack)
{
	int i = 0;
	int read_len;

	if (eeprom->length == 0)
		return -EINVAL;

	memset(eeprom->data, 0, eeprom->length);

	while (i < eeprom->length) {
		read_len = cndm_query_module_eeprom_by_page(ndev, eeprom->i2c_address,
				eeprom->page, eeprom->bank, eeprom->offset + i,
				eeprom->length - i, eeprom->data + i);

		if (read_len == 0)
			return 0;

		if (read_len < 0) {
			netdev_err(ndev, "%s: Failed to read module EEPROM (%d)", __func__, read_len);
			return read_len;
		}

		i += read_len;
	}

	return i;
}
#endif

const struct ethtool_ops cndm_ethtool_ops = {
	.get_drvinfo = cndm_get_drvinfo,
	.get_link = ethtool_op_get_link,
	.get_eeprom_len = cndm_get_eeprom_len,
	.get_eeprom = cndm_get_eeprom,
	.get_ts_info = cndm_get_ts_info,
	.get_module_info = cndm_get_module_info,
	.get_module_eeprom = cndm_get_module_eeprom,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 13, 0)
	.get_module_eeprom_by_page = cndm_get_module_eeprom_by_page,
#endif
};
