// SPDX-License-Identifier: GPL
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include "cndm.h"

static int cndm_eq_int(struct notifier_block *nb, unsigned long action, void *data);

struct cndm_eq *cndm_create_eq(struct cndm_priv *priv)
{
	struct cndm_eq *eq;

	eq = kzalloc(sizeof(*eq), GFP_KERNEL);
	if (!eq)
		return ERR_PTR(-ENOMEM);

	eq->cdev = priv->cdev;
	eq->dev = priv->dev;
	eq->priv = priv;

	eq->eqn = -1;
	eq->enabled = 0;

	eq->irq_nb.notifier_call = cndm_eq_int;

	eq->cons_ptr = 0;

	eq->db_offset = 0;
	eq->db_addr = NULL;

	spin_lock_init(&eq->table_lock);
	INIT_RADIX_TREE(&eq->cq_table, GFP_KERNEL);

	return eq;
}

void cndm_destroy_eq(struct cndm_eq *eq)
{
	cndm_close_eq(eq);

	kfree(eq);
}

int cndm_open_eq(struct cndm_eq *eq, struct cndm_irq *irq, int size)
{
	int ret = 0;

	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	if (eq->enabled || eq->buf)
		return -EINVAL;

	eq->size = roundup_pow_of_two(size);
	eq->size_mask = eq->size - 1;
	eq->stride = 16;

	eq->buf_size = eq->size * eq->stride;
	eq->buf = dma_alloc_coherent(eq->dev, eq->buf_size, &eq->buf_dma_addr, GFP_KERNEL);
	if (!eq->buf)
		return -ENOMEM;

	ret = atomic_notifier_chain_register(&irq->nh, &eq->irq_nb);
	if (ret)
		goto fail;

	eq->irq = irq;

	eq->cons_ptr = 0;

	// clear all phase tag bits
	memset(eq->buf, 0, eq->buf_size);

	cmd.opcode = CNDM_CMD_OP_CREATE_EQ;
	cmd.flags = 0x00000000;
	cmd.port = eq->priv->ndev->dev_port;
	cmd.qn = 0;
	cmd.qn2 = irq->index;
	cmd.pd = 0;
	cmd.size = ilog2(eq->size);
	cmd.dboffs = 0;
	cmd.ptr1 = eq->buf_dma_addr;
	cmd.ptr2 = 0;

	ret = cndm_exec_cmd(eq->cdev, &cmd, &rsp);
	if (ret) {
		dev_err(eq->dev, "Failed to execute command");
		goto fail;
	}

	if (rsp.status || rsp.dboffs == 0) {
		dev_err(eq->dev, "Failed to allocate EQ");
		ret = rsp.status;
		goto fail;
	}

	eq->eqn = rsp.qn;
	eq->db_offset = rsp.dboffs;
	eq->db_addr = eq->cdev->hw_addr + rsp.dboffs;

	eq->enabled = 1;

	cndm_eq_write_cons_ptr_arm(eq);

	dev_dbg(eq->dev, "Opened EQ %d", eq->eqn);

	return 0;

fail:
	cndm_close_eq(eq);
	return ret;
}

void cndm_close_eq(struct cndm_eq *eq)
{
	struct cndm_dev *cdev = eq->cdev;
	struct cndm_cmd_queue cmd;
	struct cndm_cmd_queue rsp;

	eq->enabled = 0;

	if (eq->eqn != -1) {
		cmd.opcode = CNDM_CMD_OP_DESTROY_EQ;
		cmd.flags = 0x00000000;
		cmd.port = eq->priv->ndev->dev_port;
		cmd.qn = eq->eqn;

		cndm_exec_cmd(cdev, &cmd, &rsp);

		eq->eqn = -1;
		eq->db_offset = 0;
		eq->db_addr = NULL;
	}

	if (eq->irq) {
		atomic_notifier_chain_unregister(&eq->irq->nh, &eq->irq_nb);
		eq->irq = NULL;
	}

	if (eq->buf) {
		dma_free_coherent(eq->dev, eq->buf_size, eq->buf, eq->buf_dma_addr);
		eq->buf = NULL;
		eq->buf_dma_addr = 0;
	}
}

int cndm_eq_attach_cq(struct cndm_eq *eq, struct cndm_cq *cq)
{
	int ret;

	spin_lock_irq(&eq->table_lock);
	ret = radix_tree_insert(&eq->cq_table, cq->cqn, cq);
	spin_unlock_irq(&eq->table_lock);
	return ret;
}

void cndm_eq_detach_cq(struct cndm_eq *eq, struct cndm_cq *cq)
{
	struct cndm_cq *item;

	spin_lock_irq(&eq->table_lock);
	item = radix_tree_delete(&eq->cq_table, cq->cqn);
	spin_unlock_irq(&eq->table_lock);

	if (IS_ERR(item)) {
		dev_err(eq->dev, "%s on EQ %d: radix_tree_delete failed: %ld",
				__func__, eq->eqn, PTR_ERR(item));
	} else if (!item) {
		dev_err(eq->dev, "%s on EQ %d: CQ %d not in table",
				__func__, eq->eqn, cq->cqn);
	} else if (item != cq) {
		dev_err(eq->dev, "%s on EQ %d: entry mismatch when removing CQ %d",
				__func__, eq->eqn, cq->cqn);
	}
}

void cndm_eq_write_cons_ptr(const struct cndm_eq *eq)
{
	iowrite32(eq->cons_ptr & 0xffff, eq->db_addr);
}

void cndm_eq_write_cons_ptr_arm(const struct cndm_eq *eq)
{
	iowrite32((eq->cons_ptr & 0xffff) | 0x80000000, eq->db_addr);
}

static void cndm_process_eq(struct cndm_eq *eq)
{
	struct cndm_event *event;
	struct cndm_cq *cq;
	u32 eq_index;
	u32 eq_cons_ptr;
	int done = 0;

	eq_cons_ptr = eq->cons_ptr;
	eq_index = eq_cons_ptr & eq->size_mask;

	while (1) {
		event = (struct cndm_event *)(eq->buf + eq_index * eq->stride);

		if (!!(event->phase & cpu_to_le32(0x80000000)) == !!(eq_cons_ptr & eq->size))
			break;

		dma_rmb();

		if (event->type == 0x0000) {
			// completion event
			rcu_read_lock();
			cq = radix_tree_lookup(&eq->cq_table, le16_to_cpu(event->source));
			rcu_read_unlock();

			if (likely(cq)) {
				if (likely(cq->handler))
					cq->handler(cq);
			} else {
				dev_err(eq->dev, "%s on EQ %d: unknown event source %d (index %d, type %d)",
						__func__, eq->eqn, le16_to_cpu(event->source),
						eq_index, le16_to_cpu(event->type));
				print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
						event, 16, true);
			}
		} else {
			dev_err(eq->dev, "%s on EQ %d: unknown event type %d (index %d, source %d)",
					__func__, eq->eqn, le16_to_cpu(event->type),
					eq_index, le16_to_cpu(event->source));
			print_hex_dump(KERN_ERR, "", DUMP_PREFIX_NONE, 16, 1,
					event, 16, true);
		}

		done++;

		eq_cons_ptr++;
		eq_index = eq_cons_ptr & eq->size_mask;
	}

	// update EQ consumer pointer
	eq->cons_ptr = eq_cons_ptr;
	cndm_eq_write_cons_ptr_arm(eq);
}

static int cndm_eq_int(struct notifier_block *nb, unsigned long action, void *data)
{
	struct cndm_eq *eq = container_of(nb, struct cndm_eq, irq_nb);

	cndm_process_eq(eq);

	return NOTIFY_DONE;
}
