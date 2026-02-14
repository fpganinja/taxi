// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"
#include <linux/version.h>

ktime_t cndm_read_cpl_ts(struct cndm_priv *priv, const struct cndm_cpl *cpl)
{
	struct cndm_dev *cdev = priv->cdev;

	// u64 ts_s = le16_to_cpu(cpl->ts_s);
	u64 ts_s = cpl->ts_s;
	u32 ts_ns = le32_to_cpu(cpl->ts_ns);

	if (unlikely(!priv->ts_valid || (priv->ts_s ^ ts_s) & 0xf0)) {
		// seconds MSBs do not match, update cached timestamp
		if (cdev->phc_regs) {
			priv->ts_s = ioread32(cdev->phc_regs + 0x18);
			priv->ts_s |= (u64) ioread32(cdev->phc_regs + 0x1C) << 32;
			priv->ts_valid = 1;
		}
	}

	ts_s |= priv->ts_s & 0xfffffffffffffff0;

	return ktime_set(ts_s, ts_ns);
}

static int cndm_phc_adjfine(struct ptp_clock_info *ptp, long scaled_ppm)
{
	struct cndm_dev *cdev = container_of(ptp, struct cndm_dev, ptp_clock_info);

	bool neg = false;
	u64 nom_per_fns, adj;

	dev_dbg(cdev->dev, "%s: scaled_ppm: %ld", __func__, scaled_ppm);

	if (scaled_ppm < 0) {
		neg = true;
		scaled_ppm = -scaled_ppm;
	}

	nom_per_fns = ioread32(cdev->phc_regs + 0x70);
	nom_per_fns |= (u64) ioread32(cdev->phc_regs + 0x74) << 32;

	if (nom_per_fns == 0)
		nom_per_fns = 0x4ULL << 32;

	adj = div_u64(((nom_per_fns >> 16) * scaled_ppm) + 500000, 1000000);

	if (neg)
		adj = nom_per_fns - adj;
	else
		adj = nom_per_fns + adj;

	iowrite32(adj & 0xffffffff, cdev->phc_regs + 0x78);
	iowrite32(adj >> 32, cdev->phc_regs + 0x7C);

	dev_dbg(cdev->dev, "%s adj: 0x%llx", __func__, adj);

	return 0;
}

static int cndm_phc_gettime(struct ptp_clock_info *ptp, struct timespec64 *ts)
{
	struct cndm_dev *cdev = container_of(ptp, struct cndm_dev, ptp_clock_info);

	ioread32(cdev->phc_regs + 0x30);
	ts->tv_nsec = ioread32(cdev->phc_regs + 0x34);
	ts->tv_sec = ioread32(cdev->phc_regs + 0x38);
	ts->tv_sec |= (u64) ioread32(cdev->phc_regs + 0x3C) << 32;

	return 0;
}

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 0, 0)
static int cndm_phc_gettimex(struct ptp_clock_info *ptp, struct timespec64 *ts, struct ptp_system_timestamp *sts)
{
	struct cndm_dev *cdev = container_of(ptp, struct cndm_dev, ptp_clock_info);

	ptp_read_system_prets(sts);
	ioread32(cdev->phc_regs + 0x30);
	ptp_read_system_postts(sts);
	ts->tv_nsec = ioread32(cdev->phc_regs + 0x34);
	ts->tv_sec = ioread32(cdev->phc_regs + 0x38);
	ts->tv_sec |= (u64) ioread32(cdev->phc_regs + 0x3C) << 32;

	return 0;
}
#endif

static int cndm_phc_settime(struct ptp_clock_info *ptp, const struct timespec64 *ts)
{
	struct cndm_dev *cdev = container_of(ptp, struct cndm_dev, ptp_clock_info);

	iowrite32(ts->tv_nsec, cdev->phc_regs + 0x54);
	iowrite32(ts->tv_sec & 0xffffffff, cdev->phc_regs + 0x58);
	iowrite32(ts->tv_sec >> 32, cdev->phc_regs + 0x5C);

	return 0;
}

static int cndm_phc_adjtime(struct ptp_clock_info *ptp, s64 delta)
{
	struct cndm_dev *cdev = container_of(ptp, struct cndm_dev, ptp_clock_info);
	struct timespec64 ts;

	dev_dbg(cdev->dev, "%s: delta: %lld", __func__, delta);

	if (delta > 536000000 || delta < -536000000) {
		// for a large delta, perform a non-precision step
		cndm_phc_gettime(ptp, &ts);
		ts = timespec64_add(ts, ns_to_timespec64(delta));
		cndm_phc_settime(ptp, &ts);
	} else {
		// for a small delta, perform a precision atomic offset
		iowrite32(delta & 0xffffffff, cdev->phc_regs + 0x50);
	}

	return 0;
}

static void cndm_phc_set_from_system_clock(struct ptp_clock_info *ptp)
{
	struct timespec64 ts;

#ifdef ktime_get_clocktai_ts64
	ktime_get_clocktai_ts64(&ts);
#else
	ts = ktime_to_timespec64(ktime_get_clocktai());
#endif

	cndm_phc_settime(ptp, &ts);
}

void cndm_register_phc(struct cndm_dev *cdev)
{
	if (cdev->ptp_clock) {
		dev_warn(cdev->dev, "PTP clock already registered");
		return;
	}

	// TODO
	if (cdev->port_offset == 0x10000) {
		dev_info(cdev->dev, "PTP clock not present");
		return;
	}

	cdev->phc_regs = cdev->hw_addr + 0x10000; // TODO

	cdev->ptp_clock_info.owner = THIS_MODULE;
	snprintf(cdev->ptp_clock_info.name, sizeof(cdev->ptp_clock_info.name), "%s_phc", cdev->name);
	cdev->ptp_clock_info.max_adj = 1000000000;
	cdev->ptp_clock_info.n_alarm = 0;
	cdev->ptp_clock_info.n_ext_ts = 0;
	cdev->ptp_clock_info.n_per_out = 0;
	cdev->ptp_clock_info.n_pins = 0;
	cdev->ptp_clock_info.pps = 0;
	cdev->ptp_clock_info.adjfine = cndm_phc_adjfine;
	cdev->ptp_clock_info.adjtime = cndm_phc_adjtime;
	cdev->ptp_clock_info.gettime64 = cndm_phc_gettime;
	cdev->ptp_clock_info.gettimex64 = cndm_phc_gettimex;
	cdev->ptp_clock_info.settime64 = cndm_phc_settime;

	cdev->ptp_clock = ptp_clock_register(&cdev->ptp_clock_info, cdev->dev);

	if (IS_ERR(cdev->ptp_clock)) {
		dev_err(cdev->dev, "failed to register PHC");
		cdev->ptp_clock = NULL;
		return;
	}

	dev_info(cdev->dev, "registered PHC (index %d)", ptp_clock_index(cdev->ptp_clock));

	cndm_phc_set_from_system_clock(&cdev->ptp_clock_info);
}

void cndm_unregister_phc(struct cndm_dev *cdev)
{
	if (cdev->ptp_clock) {
		ptp_clock_unregister(cdev->ptp_clock);
		cdev->ptp_clock = NULL;
		dev_info(cdev->dev, "unregistered PHC");
	}
}
