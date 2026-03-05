/* SPDX-License-Identifier: GPL */
/*

Copyright (c) 2025-2026 FPGA Ninja, LLC

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

#include "cndm_hw.h"

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

	struct mutex mbox_lock;

	u32 port_count;

	struct ptp_clock *ptp_clock;
	struct ptp_clock_info ptp_clock_info;
	u64 ptp_nom_period;
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

struct cndm_ring {
	// written on enqueue
	u32 prod_ptr;
	u64 bytes;
	u64 packet;
	u64 dropped_packets;
	struct netdev_queue *tx_queue;

	// written from completion
	u32 cons_ptr ____cacheline_aligned_in_smp;
	u64 ts_s;
	u8 ts_valid;

	// mostly constant
	u32 size;
	u32 full_size;
	u32 size_mask;
	u32 stride;

	u32 mtu;

	size_t buf_size;
	u8 *buf;
	dma_addr_t buf_dma_addr;

	union {
		struct cndm_tx_info *tx_info;
		struct cndm_rx_info *rx_info;
	};

	struct device *dev;
	struct cndm_dev *cdev;
	struct cndm_priv *priv;
	int index;
	int enabled;

	struct cndm_cq *cq;

	u32 db_offset;
	u8 __iomem *db_addr;
} ____cacheline_aligned_in_smp;

struct cndm_cq {
	u32 cons_ptr;

	u32 size;
	u32 size_mask;
	u32 stride;

	size_t buf_size;
	u8 *buf;
	dma_addr_t buf_dma_addr;

	struct device *dev;
	struct cndm_dev *cdev;
	struct cndm_priv *priv;
	struct napi_struct napi;
	int cqn;
	int enabled;

	struct cndm_ring *src_ring;

	void (*handler)(struct cndm_cq *cq);
};

struct cndm_priv {
	struct device *dev;
	struct net_device *ndev;
	struct cndm_dev *cdev;

	bool registered;
	bool port_up;

	void __iomem *hw_addr;

	struct cndm_irq *irq;
	struct notifier_block irq_nb;

	struct hwtstamp_config hwts_config;

	int rxq_count;
	int txq_count;

	struct cndm_ring *txq;
	struct cndm_ring *rxq;
};

// cndm_cmd.c
int cndm_exec_mbox_cmd(struct cndm_dev *cdev, void *cmd, void *rsp);
int cndm_exec_cmd(struct cndm_dev *cdev, void *cmd, void *rsp);
int cndm_access_reg(struct cndm_dev *cdev, u32 reg, int raw, int write, u64 *data);

// cndm_devlink.c
struct devlink *cndm_devlink_alloc(struct device *dev);
void cndm_devlink_free(struct devlink *devlink);

// cndm_irq.c
int cndm_irq_init_pcie(struct cndm_dev *cdev);
void cndm_irq_deinit_pcie(struct cndm_dev *cdev);

// cndm_netdev.c
struct net_device *cndm_create_netdev(struct cndm_dev *cdev, int port);
void cndm_destroy_netdev(struct net_device *ndev);

// cndm_dev.c
extern const struct file_operations cndm_fops;

// cndm_ethtool.c
extern const struct ethtool_ops cndm_ethtool_ops;

// cndm_ptp.c
ktime_t cndm_read_cpl_ts(struct cndm_ring *ring, const struct cndm_cpl *cpl);
void cndm_register_phc(struct cndm_dev *cdev);
void cndm_unregister_phc(struct cndm_dev *cdev);

// cndm_cq.c
struct cndm_cq *cndm_create_cq(struct cndm_priv *priv);
void cndm_destroy_cq(struct cndm_cq *cq);
int cndm_open_cq(struct cndm_cq *cq, int irqn, int size);
void cndm_close_cq(struct cndm_cq *cq);

// cndm_sq.c
struct cndm_ring *cndm_create_sq(struct cndm_priv *priv);
void cndm_destroy_sq(struct cndm_ring *sq);
int cndm_open_sq(struct cndm_ring *sq, struct cndm_priv *priv, struct cndm_cq *cq, int size);
void cndm_close_sq(struct cndm_ring *sq);
int cndm_free_tx_buf(struct cndm_ring *sq);
int cndm_poll_tx_cq(struct napi_struct *napi, int budget);
int cndm_start_xmit(struct sk_buff *skb, struct net_device *ndev);

// cndm_rq.c
struct cndm_ring *cndm_create_rq(struct cndm_priv *priv);
void cndm_destroy_rq(struct cndm_ring *rq);
int cndm_open_rq(struct cndm_ring *rq, struct cndm_priv *priv, struct cndm_cq *cq, int size);
void cndm_close_rq(struct cndm_ring *rq);
int cndm_free_rx_buf(struct cndm_ring *rq);
int cndm_refill_rx_buffers(struct cndm_ring *rq);
int cndm_poll_rx_cq(struct napi_struct *napi, int budget);

#endif
