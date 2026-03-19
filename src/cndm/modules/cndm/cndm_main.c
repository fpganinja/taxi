// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"
#include <linux/delay.h>
#include <linux/module.h>
#include <linux/rtc.h>
#include <linux/version.h>

MODULE_DESCRIPTION("Corundum device driver");
MODULE_AUTHOR("FPGA Ninja");
MODULE_LICENSE("GPL");
MODULE_VERSION(DRIVER_VERSION);

static DEFINE_IDA(cndm_instance_ida);

static int cndm_assign_id(struct cndm_dev *cdev)
{
	int ret = ida_alloc(&cndm_instance_ida, GFP_KERNEL);
	if (ret < 0)
		return ret;

	cdev->id = ret;
	snprintf(cdev->name, sizeof(cdev->name), KBUILD_MODNAME "%d", cdev->id);

	return 0;
}

static void cndm_free_id(struct cndm_dev *cdev)
{
	ida_free(&cndm_instance_ida, cdev->id);
}

static void cndm_common_remove(struct cndm_dev *cdev);

static int cndm_common_probe(struct cndm_dev *cdev)
{
	struct devlink *devlink = priv_to_devlink(cdev);
	struct device *dev = cdev->dev;
	struct rtc_time tm;
	int ret = 0;
	int k;

	struct cndm_cmd_cfg cmd;
	struct cndm_cmd_cfg rsp;

	mutex_init(&cdev->mbox_lock);

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
	devlink_register(devlink);
#else
	devlink_register(devlink, dev);
#endif

	// Read config page 0
	cmd.opcode = CNDM_CMD_OP_CFG;
	cmd.flags = 0x00000000;
	cmd.cfg_page = 0;

	ret = cndm_exec_cmd(cdev, &cmd, &rsp);
	if (ret) {
		dev_info(dev, "Failed to execute command");
		goto fail;
	}

	if (rsp.status) {
		dev_info(dev, "Command failed");
		ret = rsp.status;
		goto fail;
	}

	cdev->cfg_page_max = rsp.cfg_page_max;
	cdev->cmd_ver = rsp.cmd_ver;

	dev_info(dev, "Config pages: %d", cdev->cfg_page_max+1);
	dev_info(dev, "Command version: %d.%d.%d", cdev->cmd_ver >> 20,
		(cdev->cmd_ver >> 12) & 0xff,
		cdev->cmd_ver & 0xfff);

	// FW ID
	cdev->fpga_id = rsp.p0.fpga_id;
	cdev->fw_id = rsp.p0.fw_id;
	cdev->fw_ver = rsp.p0.fw_ver;
	cdev->board_id = rsp.p0.board_id;
	cdev->board_ver = rsp.p0.board_ver;
	cdev->build_date = rsp.p0.build_date;
	cdev->git_hash = rsp.p0.git_hash;
	cdev->release_info = rsp.p0.release_info;

	rtc_time64_to_tm(cdev->build_date, &tm);

	dev_info(dev, "FPGA ID: 0x%08x", cdev->fpga_id);
	dev_info(dev, "FW ID: 0x%08x", cdev->fw_id);
	dev_info(dev, "FW version: %d.%d.%d", cdev->fw_ver >> 20,
		(cdev->fw_ver >> 12) & 0xff,
		cdev->fw_ver & 0xfff);
	dev_info(dev, "Board ID: 0x%08x", cdev->board_id);
	dev_info(dev, "Board version: %d.%d.%d", cdev->board_ver >> 20,
		(cdev->board_ver >> 12) & 0xff,
		cdev->board_ver & 0xfff);
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)
	snprintf(cdev->build_date_str, sizeof(cdev->build_date_str), "%ptRd %ptRt", &tm, &tm);
#else
	snprintf(cdev->build_date_str, sizeof(cdev->build_date_str), "%04d-%02d-%02d %02d:%02d:%02d",
			tm.tm_year+1900, tm.tm_mon+1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);
#endif
	dev_info(dev, "Build date: %s UTC (raw: 0x%08x)", cdev->build_date_str, cdev->build_date);
	dev_info(dev, "Git hash: %08x", cdev->git_hash);
	dev_info(dev, "Release info: %08x", cdev->release_info);

	// Read config page 1
	cmd.opcode = CNDM_CMD_OP_CFG;
	cmd.flags = 0x00000000;
	cmd.cfg_page = 1;

	ret = cndm_exec_cmd(cdev, &cmd, &rsp);
	if (ret) {
		dev_info(dev, "Failed to execute command");
		goto fail;
	}

	if (rsp.status) {
		dev_info(dev, "Command failed");
		ret = rsp.status;
		goto fail;
	}

	// HW config
	cdev->port_count = rsp.p1.port_count;
	cdev->sys_clk_per_ns_num = rsp.p1.sys_clk_per_ns_num;
	cdev->sys_clk_per_ns_den = rsp.p1.sys_clk_per_ns_den;
	cdev->ptp_clk_per_ns_num = rsp.p1.ptp_clk_per_ns_num;
	cdev->ptp_clk_per_ns_den = rsp.p1.ptp_clk_per_ns_den;

	dev_info(dev, "Port count: %d", cdev->port_count);
	if (cdev->sys_clk_per_ns_num != 0) {
		u64 a, b, c;
		a = (u64)cdev->sys_clk_per_ns_den * 1000;
		b = a / cdev->sys_clk_per_ns_num;
		c = a - (b * cdev->sys_clk_per_ns_num);
		c = (c * 1000000000) / cdev->sys_clk_per_ns_num;
		dev_info(dev, "Sys clock freq: %lld.%09lld MHz (raw %d/%d ns)", b, c, cdev->sys_clk_per_ns_num, cdev->sys_clk_per_ns_den);
	}
	if (cdev->ptp_clk_per_ns_num != 0) {
		u64 a, b, c;
		a = (u64)cdev->ptp_clk_per_ns_den * 1000;
		b = a / cdev->ptp_clk_per_ns_num;
		c = a - (b * cdev->ptp_clk_per_ns_num);
		c = (c * 1000000000) / cdev->ptp_clk_per_ns_num;
		dev_info(dev, "PTP clock freq: %lld.%09lld MHz (raw %d/%d ns)", b, c, cdev->ptp_clk_per_ns_num, cdev->ptp_clk_per_ns_den);
	}

	// Read config page 2
	cmd.opcode = CNDM_CMD_OP_CFG;
	cmd.flags = 0x00000000;
	cmd.cfg_page = 2;

	ret = cndm_exec_cmd(cdev, &cmd, &rsp);
	if (ret) {
		dev_info(dev, "Failed to execute command");
		goto fail;
	}

	if (rsp.status) {
		dev_info(dev, "Command failed");
		ret = rsp.status;
		goto fail;
	}

	// Resources
	cdev->log_max_eq = rsp.p2.log_max_eq;
	cdev->log_max_eq_sz = rsp.p2.log_max_eq_sz;
	cdev->eq_pool = rsp.p2.eq_pool;
	cdev->eqe_ver = rsp.p2.eqe_ver;
	cdev->log_max_cq = rsp.p2.log_max_cq;
	cdev->log_max_cq_sz = rsp.p2.log_max_cq_sz;
	cdev->cq_pool = rsp.p2.cq_pool;
	cdev->cqe_ver = rsp.p2.cqe_ver;
	cdev->log_max_sq = rsp.p2.log_max_sq;
	cdev->log_max_sq_sz = rsp.p2.log_max_sq_sz;
	cdev->sq_pool = rsp.p2.sq_pool;
	cdev->sqe_ver = rsp.p2.sqe_ver;
	cdev->log_max_rq = rsp.p2.log_max_rq;
	cdev->log_max_rq_sz = rsp.p2.log_max_rq_sz;
	cdev->rq_pool = rsp.p2.rq_pool;
	cdev->rqe_ver = rsp.p2.rqe_ver;

	dev_info(dev, "Max EQ count: %d (log %d)", 1 << cdev->log_max_eq, cdev->log_max_eq);
	dev_info(dev, "Max EQ size: %d (log %d)", 1 << cdev->log_max_eq_sz, cdev->log_max_eq_sz);
	dev_info(dev, "EQ pool: %d", cdev->eq_pool);
	dev_info(dev, "EQE version: %d", cdev->eqe_ver);
	dev_info(dev, "Max CQ count: %d (log %d)", 1 << cdev->log_max_cq, cdev->log_max_cq);
	dev_info(dev, "Max CQ size: %d (log %d)", 1 << cdev->log_max_cq_sz, cdev->log_max_cq_sz);
	dev_info(dev, "CQ pool: %d", cdev->cq_pool);
	dev_info(dev, "CQE version: %d", cdev->cqe_ver);
	dev_info(dev, "Max SQ count: %d (log %d)", 1 << cdev->log_max_sq, cdev->log_max_sq);
	dev_info(dev, "Max SQ size: %d (log %d)", 1 << cdev->log_max_sq_sz, cdev->log_max_sq_sz);
	dev_info(dev, "SQ pool: %d", cdev->sq_pool);
	dev_info(dev, "SQE version: %d", cdev->sqe_ver);
	dev_info(dev, "Max RQ count: %d (log %d)", 1 << cdev->log_max_rq, cdev->log_max_rq);
	dev_info(dev, "Max RQ size: %d (log %d)", 1 << cdev->log_max_rq_sz, cdev->log_max_rq_sz);
	dev_info(dev, "RQ pool: %d", cdev->rq_pool);
	dev_info(dev, "RQE version: %d", cdev->rqe_ver);

	dev_info(dev, "Read HW IDs");

	ret = cndm_hwid_sn_rd(cdev, NULL, &cdev->sn_str);
	if (ret || !strlen(cdev->sn_str)) {
		dev_info(dev, "No readable serial number");
	} else {
		dev_info(dev, "SN: %s", cdev->sn_str);
	}

	ret = cndm_hwid_mac_rd(cdev, 0, &cdev->mac_cnt, &cdev->base_mac);
	if (ret) {
		dev_info(dev, "No readable MACs");
		cdev->mac_cnt = 0;
	} else if (!is_valid_ether_addr(cdev->base_mac)) {
		dev_warn(dev, "Base MAC is invalid");
		cdev->mac_cnt = 0;
	} else {
		dev_info(dev, "MAC count: %d", cdev->mac_cnt);
		dev_info(dev, "Base MAC: %pM", cdev->base_mac);
	}

	if (cdev->port_count > ARRAY_SIZE(cdev->ndev))
		cdev->port_count = ARRAY_SIZE(cdev->ndev);

	cndm_register_phc(cdev);

	for (k = 0; k < cdev->port_count; k++) {
		struct net_device *ndev;

		ndev = cndm_create_netdev(cdev, k);
		if (IS_ERR_OR_NULL(ndev)) {
			ret = PTR_ERR(ndev);
			goto fail_netdev;
		}

		cdev->ndev[k] = ndev;
	}

fail_netdev:
	cdev->misc_dev.minor = MISC_DYNAMIC_MINOR;
	cdev->misc_dev.name = cdev->name;
	cdev->misc_dev.fops = &cndm_fops;
	cdev->misc_dev.parent = dev;

	ret = misc_register(&cdev->misc_dev);
	if (ret) {
		cdev->misc_dev.this_device = NULL;
		dev_err(dev, "misc_register failed: %d", ret);
		goto fail;

	}

	dev_info(dev, "Registered device %s", cdev->name);

	return 0;

fail:
	cndm_common_remove(cdev);
	return ret;
}

static void cndm_common_remove(struct cndm_dev *cdev)
{
	struct devlink *devlink = priv_to_devlink(cdev);
	int k;

	if (cdev->misc_dev.this_device)
		misc_deregister(&cdev->misc_dev);

	for (k = 0; k < ARRAY_SIZE(cdev->ndev); k++) {
		if (cdev->ndev[k]) {
			cndm_destroy_netdev(cdev->ndev[k]);
			cdev->ndev[k] = NULL;
		}
	}

	cndm_unregister_phc(cdev);

	devlink_unregister(devlink);
}

static int cndm_pci_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
	struct device *dev = &pdev->dev;
	struct devlink *devlink;
	struct cndm_dev *cdev;
	struct pci_dev *bridge = pci_upstream_bridge(pdev);
	int ret = 0;

	dev_info(dev, KBUILD_MODNAME " PCI probe");
	dev_info(dev, "Corundum device driver");
	dev_info(dev, "Version " DRIVER_VERSION);
	dev_info(dev, "Copyright (c) 2025 FPGA Ninja, LLC");
	dev_info(dev, "https://fpga.ninja/");
	dev_info(dev, "PCIe configuration summary:");

	if (pdev->pcie_cap) {
		u16 devctl;
		u32 lnkcap;
		u16 lnkctl;
		u16 lnksta;

		pci_read_config_word(pdev, pdev->pcie_cap + PCI_EXP_DEVCTL, &devctl);
		pci_read_config_dword(pdev, pdev->pcie_cap + PCI_EXP_LNKCAP, &lnkcap);
		pci_read_config_word(pdev, pdev->pcie_cap + PCI_EXP_LNKCTL, &lnkctl);
		pci_read_config_word(pdev, pdev->pcie_cap + PCI_EXP_LNKSTA, &lnksta);

		dev_info(dev, "  Max payload size: %d bytes",
				128 << ((devctl & PCI_EXP_DEVCTL_PAYLOAD) >> 5));
		dev_info(dev, "  Max read request size: %d bytes",
				128 << ((devctl & PCI_EXP_DEVCTL_READRQ) >> 12));
		dev_info(dev, "  Read completion boundary: %d bytes",
				lnkctl & PCI_EXP_LNKCTL_RCB ? 128 : 64);
		dev_info(dev, "  Link capability: gen %d x%d",
				lnkcap & PCI_EXP_LNKCAP_SLS, (lnkcap & PCI_EXP_LNKCAP_MLW) >> 4);
		dev_info(dev, "  Link status: gen %d x%d",
				lnksta & PCI_EXP_LNKSTA_CLS, (lnksta & PCI_EXP_LNKSTA_NLW) >> 4);
		dev_info(dev, "  Relaxed ordering: %s",
				devctl & PCI_EXP_DEVCTL_RELAX_EN ? "enabled" : "disabled");
		dev_info(dev, "  Phantom functions: %s",
				devctl & PCI_EXP_DEVCTL_PHANTOM ? "enabled" : "disabled");
		dev_info(dev, "  Extended tags: %s",
				devctl & PCI_EXP_DEVCTL_EXT_TAG ? "enabled" : "disabled");
		dev_info(dev, "  No snoop: %s",
				devctl & PCI_EXP_DEVCTL_NOSNOOP_EN ? "enabled" : "disabled");
	}

#ifdef CONFIG_NUMA
	dev_info(dev, "  NUMA node: %d", pdev->dev.numa_node);
#endif

	if (bridge) {
		dev_info(dev, "  Bridge PCI ID: %04x:%02x:%02x.%d", pci_domain_nr(bridge->bus),
				bridge->bus->number, PCI_SLOT(bridge->devfn), PCI_FUNC(bridge->devfn));
	}

	if (bridge && bridge->pcie_cap) {
		u32 lnkcap;
		u16 lnksta;

		pci_read_config_dword(bridge, bridge->pcie_cap + PCI_EXP_LNKCAP, &lnkcap);
		pci_read_config_word(bridge, bridge->pcie_cap + PCI_EXP_LNKSTA, &lnksta);

		dev_info(dev, "  Bridge link capability: gen %d x%d",
				lnkcap & PCI_EXP_LNKCAP_SLS, (lnkcap & PCI_EXP_LNKCAP_MLW) >> 4);
		dev_info(dev, "  Bridge link status: gen %d x%d",
				lnksta & PCI_EXP_LNKSTA_CLS, (lnksta & PCI_EXP_LNKSTA_NLW) >> 4);
	}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 17, 0)
	pcie_print_link_status(pdev);
#endif

	devlink = cndm_devlink_alloc(dev);
	if (!devlink)
		return -ENOMEM;

	cdev = devlink_priv(devlink);
	cdev->pdev = pdev;
	cdev->dev = dev;
	pci_set_drvdata(pdev, cdev);

	ret = cndm_assign_id(cdev);
	if (ret)
		goto fail_assign_id;

	ret = pci_enable_device_mem(pdev);
	if (ret) {
		dev_err(dev, "Failed to enable device");
		goto fail_enable_device;
	}

	pci_set_master(pdev);

	ret = pci_request_regions(pdev, cdev->name);
	if (ret) {
		dev_err(dev, "Failed to reserve regions");
		goto fail_regions;
	}

	cdev->hw_regs_size = pci_resource_len(pdev, 0);
	cdev->hw_regs_phys = pci_resource_start(pdev, 0);

	dev_info(dev, "Control BAR size: %llu", cdev->hw_regs_size);
	cdev->hw_addr = pci_ioremap_bar(pdev, 0);
	if (!cdev->hw_addr) {
		ret = -ENOMEM;
		dev_err(dev, "Failed to map control BAR");
		goto fail_map_bars;
	}

	if (ioread32(cdev->hw_addr + 0x0000) == 0xffffffff) {
		ret = -EIO;
		dev_err(dev, "Device needs to be reset");
		goto fail_map_bars;
	}

	ret = cndm_irq_init_pcie(cdev);
	if (ret) {
		dev_err(dev, "Failed to set up interrupts");
		goto fail_init_irq;
	}

	ret = cndm_common_probe(cdev);
	if (ret)
		goto fail_common;

	return 0;

fail_common:
	cndm_irq_deinit_pcie(cdev);
fail_init_irq:
fail_map_bars:
	if (cdev->hw_addr)
		pci_iounmap(pdev, cdev->hw_addr);
	pci_release_regions(pdev);
fail_regions:
	pci_clear_master(pdev);
	pci_disable_device(pdev);
fail_enable_device:
	cndm_free_id(cdev);
fail_assign_id:
	cndm_devlink_free(devlink);
	return ret;
}

static void cndm_pci_remove(struct pci_dev *pdev)
{
	struct device *dev = &pdev->dev;
	struct cndm_dev *cdev = pci_get_drvdata(pdev);
	struct devlink *devlink = priv_to_devlink(cdev);

	dev_info(dev, KBUILD_MODNAME " PCI remove");

	cndm_common_remove(cdev);

	cndm_irq_deinit_pcie(cdev);
	if (cdev->hw_addr)
		pci_iounmap(pdev, cdev->hw_addr);
	pci_release_regions(pdev);
	pci_clear_master(pdev);
	pci_disable_device(pdev);
	cndm_free_id(cdev);
	cndm_devlink_free(devlink);
}

static const struct pci_device_id cndm_pci_id_table[] = {
	{PCI_DEVICE(0x1234, 0xC001)},
	{0}
};

static struct pci_driver cndm_driver = {
	.name = KBUILD_MODNAME,
	.id_table = cndm_pci_id_table,
	.probe = cndm_pci_probe,
	.remove = cndm_pci_remove
};

static int __init cndm_init(void)
{
	return pci_register_driver(&cndm_driver);
}

static void __exit cndm_exit(void)
{
	pci_unregister_driver(&cndm_driver);

	ida_destroy(&cndm_instance_ida);
}

module_init(cndm_init);
module_exit(cndm_exit);
