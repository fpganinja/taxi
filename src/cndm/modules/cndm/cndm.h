/* SPDX-License-Identifier: GPL */
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#ifndef CNDM_H
#define CNDM_H

#include <linux/kernel.h>
#include <linux/pci.h>
#include <linux/miscdevice.h>
#include <linux/net_tstamp.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/ptp_clock_kernel.h>
#include <net/devlink.h>

#define DRIVER_VERSION "0.1"

#define CNDM_MAX_IRQ 256

struct cndm_irq {
	int index;
	int irqn;
	char name[16+3];
	struct atomic_notifier_head nh;
};

struct cndm_dev {
	struct pci_dev *pdev;
	struct device *dev;

	unsigned int id;
	char name[16];

	struct miscdevice misc_dev;

	int irq_count;
	struct cndm_irq *irq;

	struct net_device *ndev[32];

	resource_size_t hw_regs_size;
	phys_addr_t hw_regs_phys;
	void __iomem *hw_addr;

	u32 port_count;
	u32 port_offset;
	u32 port_stride;

	void __iomem *phc_regs;
	struct ptp_clock *ptp_clock;
	struct ptp_clock_info ptp_clock_info;
};

struct cndm_tx_info {
	struct sk_buff *skb;
	dma_addr_t dma_addr;
	u32 len;
	int ts_requested;
};

struct cndm_rx_info {
	struct page *page;
	dma_addr_t dma_addr;
	u32 len;
};

struct cndm_priv {
	struct device *dev;
	struct net_device *ndev;
	struct cndm_dev *cdev;

	bool registered;
	bool port_up;

	void __iomem *hw_addr;

	size_t txq_region_len;
	void *txq_region;
	dma_addr_t txq_region_addr;

	struct cndm_irq *irq;
	struct notifier_block irq_nb;

	struct hwtstamp_config hwts_config;
	u64 ts_s;
	u8 ts_valid;

	struct cndm_tx_info *tx_info;
	struct cndm_rx_info *rx_info;

	struct netdev_queue *tx_queue;

	struct napi_struct tx_napi;
	struct napi_struct rx_napi;

	u32 txq_log_size;
	u32 txq_size;
	u32 txq_mask;
	u32 txq_prod;
	u32 txq_cons;

	size_t rxq_region_len;
	void *rxq_region;
	dma_addr_t rxq_region_addr;

	u32 rxq_log_size;
	u32 rxq_size;
	u32 rxq_mask;
	u32 rxq_prod;
	u32 rxq_cons;

	size_t txcq_region_len;
	void *txcq_region;
	dma_addr_t txcq_region_addr;

	u32 txcq_log_size;
	u32 txcq_size;
	u32 txcq_mask;
	u32 txcq_prod;
	u32 txcq_cons;

	size_t rxcq_region_len;
	void *rxcq_region;
	dma_addr_t rxcq_region_addr;

	u32 rxcq_log_size;
	u32 rxcq_size;
	u32 rxcq_mask;
	u32 rxcq_prod;
	u32 rxcq_cons;
};

struct cndm_desc {
	__u8 rsvd[4];
	__le32 len;
	__le64 addr;
};

struct cndm_cpl {
	__u8 rsvd[4];
	__le32 len;
	__le32 ts_ns;
	__le16 ts_fns;
	__u8 ts_s;
	__u8 phase;
};

// cndm_devlink.c
struct devlink *cndm_devlink_alloc(struct device *dev);
void cndm_devlink_free(struct devlink *devlink);

// cndm_irq.c
int cndm_irq_init_pcie(struct cndm_dev *cdev);
void cndm_irq_deinit_pcie(struct cndm_dev *cdev);

// cndm_netdev.c
struct net_device *cndm_create_netdev(struct cndm_dev *cdev, int port, void __iomem *hw_addr);
void cndm_destroy_netdev(struct net_device *ndev);

// cndm_dev.c
extern const struct file_operations cndm_fops;

// cndm_ethtool.c
extern const struct ethtool_ops cndm_ethtool_ops;

// cndm_ptp.c
ktime_t cndm_read_cpl_ts(struct cndm_priv *priv, const struct cndm_cpl *cpl);
void cndm_register_phc(struct cndm_dev *cdev);
void cndm_unregister_phc(struct cndm_dev *cdev);

// cndm_tx.c
int cndm_free_tx_buf(struct cndm_priv *priv);
int cndm_poll_tx_cq(struct napi_struct *napi, int budget);
int cndm_start_xmit(struct sk_buff *skb, struct net_device *ndev);

// cndm_rx.c
int cndm_free_rx_buf(struct cndm_priv *priv);
int cndm_refill_rx_buffers(struct cndm_priv *priv);
int cndm_poll_rx_cq(struct napi_struct *napi, int budget);

#endif
