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
	snprintf(cdev->name, sizeof(cdev->name), DRIVER_NAME "%d", cdev->id);

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

	cdev->port_count = ioread32(cdev->bar + 0x0100);
	cdev->port_offset = ioread32(cdev->bar + 0x0104);
	cdev->port_stride = ioread32(cdev->bar + 0x0108);

	dev_info(dev, "Port count: %d", cdev->port_count);
	dev_info(dev, "Port offset: 0x%x", cdev->port_offset);
	dev_info(dev, "Port stride: 0x%x", cdev->port_stride);

	for (k = 0; k < cdev->port_count; k++) {
		struct net_device *ndev;

		ndev = cndm_create_netdev(cdev, k, cdev->bar + cdev->port_offset + (cdev->port_stride*k));
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

	for (k = 0; k < 32; k++) {
		if (cdev->ndev[k]) {
			cndm_destroy_netdev(cdev->ndev[k]);
			cdev->ndev[k] = NULL;
		}
	}

	devlink_unregister(devlink);
}

static int cndm_pci_probe(struct pci_dev *pdev, const struct pci_device_id *ent)
{
	struct device *dev = &pdev->dev;
	struct devlink *devlink;
	struct cndm_dev *cdev;
	int ret = 0;

	dev_info(dev, DRIVER_NAME " PCI probe");
	dev_info(dev, "Corundum device driver");
	dev_info(dev, "Version " DRIVER_VERSION);
	dev_info(dev, "Copyright (c) 2025 FPGA Ninja");
	dev_info(dev, "https://fpga.ninja/");

	pcie_print_link_status(pdev);

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

	ret = pci_request_regions(pdev, DRIVER_NAME);
	if (ret) {
		dev_err(dev, "Failed to reserve regions");
		goto fail_regions;
	}

	cdev->bar_len = pci_resource_len(pdev, 0);

	dev_info(dev, "BAR size: %llu", cdev->bar_len);
	cdev->bar = pci_ioremap_bar(pdev, 0);
	if (!cdev->bar) {
		ret = -ENOMEM;
		dev_err(dev, "Failed to map BAR 0");
		goto fail_map_bars;
	}

	if (ioread32(cdev->bar + 0x0000) == 0xffffffff) {
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
	if (cdev->bar)
		pci_iounmap(pdev, cdev->bar);
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

	dev_info(dev, DRIVER_NAME " PCI remove");

	cndm_common_remove(cdev);

	cndm_irq_deinit_pcie(cdev);
	if (cdev->bar)
		pci_iounmap(pdev, cdev->bar);
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
	.name = DRIVER_NAME,
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
}

module_init(cndm_init);
module_exit(cndm_exit);
