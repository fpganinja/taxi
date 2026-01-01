// SPDX-License-Identifier: GPL
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

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

const struct file_operations cndm_fops = {
	.owner = THIS_MODULE,
	.open = cndm_open,
	.release = cndm_release,
};
