// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"
#include <linux/module.h>
#include <linux/delay.h>
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
	int ret = 0;
	int k;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 15, 0)
	devlink_register(devlink);
#else
	devlink_register(devlink, dev);
#endif

	cdev->port_count = ioread32(cdev->hw_addr + 0x0100);
	cdev->port_offset = ioread32(cdev->hw_addr + 0x0104);
	cdev->port_stride = ioread32(cdev->hw_addr + 0x0108);

	dev_info(dev, "Port count: %d", cdev->port_count);
	dev_info(dev, "Port offset: 0x%x", cdev->port_offset);
	dev_info(dev, "Port stride: 0x%x", cdev->port_stride);

	if (cdev->port_count > ARRAY_SIZE(cdev->ndev))
		cdev->port_count = ARRAY_SIZE(cdev->ndev);

	cndm_register_phc(cdev);

	for (k = 0; k < cdev->port_count; k++) {
		struct net_device *ndev;

		ndev = cndm_create_netdev(cdev, k, cdev->hw_addr + cdev->port_offset + (cdev->port_stride*k));
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
