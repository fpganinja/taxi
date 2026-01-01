// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"
#include "cndm_ioctl.h"

#include <linux/uaccess.h>

static int cndm_open(struct inode *inode, struct file *file)
{
	// struct miscdevice *miscdev = file->private_data;
	// struct cndm_dev *cdev = container_of(miscdev, struct cndm_dev, misc_dev);

	return 0;
}

static int cndm_release(struct inode *inode, struct file *file)
{
	// struct miscdevice *miscdev = file->private_data;
	// struct cndm_dev *cdev = container_of(miscdev, struct cndm_dev, misc_dev);

	return 0;
}

static int cndm_mmap(struct file *file, struct vm_area_struct *vma)
{
	struct miscdevice *miscdev = file->private_data;
	struct cndm_dev *cdev = container_of(miscdev, struct cndm_dev, misc_dev);
	int index;
	u64 pgoff, req_len, req_start;

	index = vma->vm_pgoff >> (40 - PAGE_SHIFT);
	req_len = vma->vm_end - vma->vm_start;
	pgoff = vma->vm_pgoff & ((1U << (40 - PAGE_SHIFT)) - 1);
	req_start = pgoff << PAGE_SHIFT;

	if (vma->vm_end < vma->vm_start)
		return -EINVAL;

	if ((vma->vm_flags & VM_SHARED) == 0)
		return -EINVAL;

	switch (index) {
	case 0:
		if (req_start + req_len > cdev->hw_regs_size)
			return -EINVAL;

		return io_remap_pfn_range(vma, vma->vm_start,
			(cdev->hw_regs_phys >> PAGE_SHIFT) + pgoff,
			req_len, pgprot_noncached(vma->vm_page_prot));
	default:
		return -EINVAL;
	}

	return -EINVAL;
}

static long cndm_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
	struct miscdevice *miscdev = file->private_data;
	struct cndm_dev *cdev = container_of(miscdev, struct cndm_dev, misc_dev);
	size_t minsz;

	if (cmd == CNDM_IOCTL_GET_API_VERSION) {
		// Get API version
		return CNDM_IOCTL_API_VERSION;
	} else if (cmd == CNDM_IOCTL_GET_DEVICE_INFO) {
		// Get device information
		struct cndm_ioctl_device_info info;

		minsz = offsetofend(struct cndm_ioctl_device_info, num_irqs);

		if (copy_from_user(&info, (void __user *)arg, minsz))
			return -EFAULT;

		if (info.argsz < minsz)
			return -EINVAL;

		info.flags = 0;
		info.num_regions = 1;
		info.num_irqs = 0;

		return copy_to_user((void __user *)arg, &info, minsz) ? -EFAULT : 0;
	} else if (cmd == CNDM_IOCTL_GET_REGION_INFO) {
		// Get region information
		struct cndm_ioctl_region_info info;

		minsz = offsetofend(struct cndm_ioctl_region_info, name);

		if (copy_from_user(&info, (void __user *)arg, minsz))
			return -EFAULT;

		if (info.argsz < minsz)
			return -EINVAL;

		info.flags = 0;
		info.type = CNDM_REGION_TYPE_UNIMPLEMENTED;
		info.next = 0;
		info.child = 0;
		info.size = 0;
		info.offset = ((u64)info.index) << 40;
		info.name[0] = 0;

		switch (info.index) {
		case 0:
			info.type = CNDM_REGION_TYPE_NIC_CTRL;
			info.next = 0;
			info.child = 0;
			info.size = cdev->hw_regs_size;
			info.offset = ((u64)info.index) << 40;
			strscpy(info.name, "ctrl", sizeof(info.name));
			break;
		default:
			return -EINVAL;
		}

		return copy_to_user((void __user *)arg, &info, minsz) ? -EFAULT : 0;
	}

	return -EINVAL;
}

const struct file_operations cndm_fops = {
	.owner = THIS_MODULE,
	.open = cndm_open,
	.release = cndm_release,
	.mmap = cndm_mmap,
	.unlocked_ioctl = cndm_ioctl,
};
