// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

static irqreturn_t cndm_irq_handler(int irqn, void *data)
{
	struct cndm_irq *irq = data;

	atomic_notifier_call_chain(&irq->nh, 0, NULL);

	return IRQ_HANDLED;
}

int cndm_irq_init_pcie(struct cndm_dev *cdev)
{
	struct pci_dev *pdev = cdev->pdev;
	struct device *dev = cdev->dev;
	int ret = 0;
	int k;

	cdev->irq_count = pci_alloc_irq_vectors(pdev, 1, CNDM_MAX_IRQ, PCI_IRQ_MSI | PCI_IRQ_MSIX);
	if (cdev->irq_count < 0) {
		dev_err(dev, "Failed to allocate IRQs");
		return -ENOMEM;
	}

	for (k = 0; k < cdev->irq_count; k++) {
		struct cndm_irq *irq;

		irq = kzalloc(sizeof(*irq), GFP_KERNEL);
		if (!irq) {
			ret = -ENOMEM;
			goto fail;
		}

		ATOMIC_INIT_NOTIFIER_HEAD(&irq->nh);

		ret = pci_request_irq(pdev, k, cndm_irq_handler, NULL,
				irq, "%s-%d", cdev->name, k);
		if (ret < 0) {
			kfree(irq);
			ret = -ENOMEM;
			dev_err(dev, "Failed to request IRQ %d", k);
			goto fail;
		}

		irq->index = k;
		irq->irqn = pci_irq_vector(pdev, k);
		cdev->irq[k] = irq;
	}

	dev_info(dev, "Configured %d IRQs", cdev->irq_count);

	return 0;
fail:
	cndm_irq_deinit_pcie(cdev);
	return ret;
}

void cndm_irq_deinit_pcie(struct cndm_dev *cdev)
{
	struct pci_dev *pdev = cdev->pdev;
	int k;

	for (k = 0; k < CNDM_MAX_IRQ; k++)
	{
		if (cdev->irq[k]) {
			pci_free_irq(pdev, k, cdev->irq[k]);
			kfree(cdev->irq[k]);
			cdev->irq[k] = NULL;
		}
	}

	pci_free_irq_vectors(pdev);
}
