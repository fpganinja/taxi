// SPDX-License-Identifier: GPL
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

#include <ctype.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/pci_regs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <linux/pci.h>

#include "fpga_id.h"
#include "reg_block.h"
#include "reg_if.h"
#include "bitfile.h"
#include "flash.h"

#define MAX_SEGMENTS 8

uint32_t reverse_bits_32(uint32_t x)
{
	x = ((x & 0x55555555) <<  1) | ((x & 0xAAAAAAAA) >>  1);
	x = ((x & 0x33333333) <<  2) | ((x & 0xCCCCCCCC) >>  2);
	x = ((x & 0x0F0F0F0F) <<  4) | ((x & 0xF0F0F0F0) >>  4);
	x = ((x & 0x00FF00FF) <<  8) | ((x & 0xFF00FF00) >>  8);
	x = ((x & 0x0000FFFF) << 16) | ((x & 0xFFFF0000) >> 16);
	return x;
}

uint16_t reverse_bits_16(uint16_t x)
{
	x = ((x & 0x5555) << 1) | ((x & 0xAAAA) >> 1);
	x = ((x & 0x3333) << 2) | ((x & 0xCCCC) >> 2);
	x = ((x & 0x0F0F) << 4) | ((x & 0xF0F0) >> 4);
	x = ((x & 0x00FF) << 8) | ((x & 0xFF00) >> 8);
	return x;
}

uint8_t reverse_bits_8(uint8_t x)
{
	x = ((x & 0x55) << 1) | ((x & 0xAA) >> 1);
	x = ((x & 0x33) << 2) | ((x & 0xCC) >> 2);
	x = ((x & 0x0F) << 4) | ((x & 0xF0) >> 4);
	return x;
}

char* stristr(const char *str1, const char *str2)
{
	const char* p1 = str1;
	const char* p2 = str2;
	const char* r = *p2 == 0 ? str1 : 0;

	while (*p1 != 0 && *p2 != 0) {
		if (tolower(*p1) == tolower(*p2)) {
			if (r == 0) {
				r = p1;
			}

			p2++;
		} else {
			p2 = str2;
			if (r != 0) {
				p1 = r + 1;
			}

			if (tolower(*p1) == tolower(*p2)) {
				r = p1;
				p2++;
			} else {
				r = 0;
			}
		}

		p1++;
	}

	return *p2 == 0 ? (char *)r : 0;
}

static void usage(char *name)
{
	fprintf(stderr,
		"usage: %s [options]\n"
		" -s domain:bus:dev.func  select device\n"
		" -p part    select flash partition\n"
		" -r file    read flash to file\n"
		" -w file    write and verify flash from file\n"
		" -e         erase flash\n"
		" -b         boot FPGA from flash\n"
		" -t         hot reset FPGA\n"
		" -y         no interactive confirm\n",
		name);
}

int flash_read_progress(struct flash_device *fdev, size_t addr, size_t len, void *dest)
{
	int ret = 0;
	size_t remain = len;
	size_t seg;
	int step = 0x10000;

	printf("Start address: 0x%08lx\n", addr);
	printf("Length: 0x%08lx\n", len);

	while (remain > 0) {
		if (remain > step) {
			// longer than step, trim
			if ((addr + step) & (step-1)) {
				// align to step size
				seg = step - ((addr + step) & (step-1));
			} else {
				// already aligned
				seg = step;
			}
		} else {
			// shorter than step
			seg = remain;
		}

		printf("Read address 0x%08lx, length 0x%08lx (%ld%%)\r", addr, seg, (100*(len-remain))/len);
		fflush(stdout);

		ret = flash_read(fdev, addr, seg, dest);

		if (ret) {
			fprintf(stderr, "\nRead failed\n");
			goto err;
		}

		addr += seg;
		remain -= seg;
		dest += seg;
	}

	printf("\n");

err:
	return ret;
}

int flash_write_progress(struct flash_device *fdev, size_t addr, size_t len, const void *src)
{
	int ret = 0;
	size_t remain = len;
	size_t seg;
	int step = 0x1000;

	printf("Start address: 0x%08lx\n", addr);
	printf("Length: 0x%08lx\n", len);

	step = fdev->write_buffer_size > step ? fdev->write_buffer_size : step;

	while (remain > 0) {
		if (remain > step) {
			// longer than step, trim
			if ((addr + step) & (step-1)) {
				// align to step size
				seg = step - ((addr + step) & (step-1));
			} else {
				// already aligned
				seg = step;
			}
		} else {
			// shorter than step
			seg = remain;
		}

		printf("Write address 0x%08lx, length 0x%08lx (%ld%%)\r", addr, seg, (100*(len-remain))/len);
		fflush(stdout);

		ret = flash_write(fdev, addr, seg, src);

		if (ret) {
			fprintf(stderr, "\nWrite failed\n");
			goto err;
		}

		addr += seg;
		remain -= seg;
		src += seg;
	}

	printf("\n");

err:
	return ret;
}

int flash_write_verify_progress(struct flash_device *fdev, size_t addr, size_t len, const void *src)
{
	int ret = 0;
	size_t remain = len;
	size_t seg;
	int step = 0x1000;
	const uint8_t *ptr = src;
	uint8_t *check_buf;

	printf("Start address: 0x%08lx\n", addr);
	printf("Length: 0x%08lx\n", len);

	step = fdev->write_buffer_size > step ? fdev->write_buffer_size : step;

	check_buf = calloc(step, 1);

	if (!check_buf)
		return -1;

	while (remain > 0) {
		if (remain > step) {
			// longer than step, trim
			if ((addr + step) & (step-1)) {
				// align to step size
				seg = step - ((addr + step) & (step-1));
			} else {
				// already aligned
				seg = step;
			}
		} else {
			// shorter than step
			seg = remain;
		}

		printf("Write/verify address 0x%08lx, length 0x%08lx (%ld%%)\r", addr, seg, (100*(len-remain))/len);
		fflush(stdout);

		ret = flash_write(fdev, addr, seg, ptr);

		if (ret) {
			fprintf(stderr, "\nWrite failed\n");
			goto err;
		}

		for (int read_attempts = 3; read_attempts >= 0; read_attempts--) {
			ret = flash_read(fdev, addr, seg, check_buf);

			if (ret) {
				fprintf(stderr, "\nRead failed\n");
				goto err;
			}

			if (memcmp(ptr, check_buf, seg)) {
				fprintf(stderr, "\nVerify failed (%d more attempts)\n", read_attempts);

				for (size_t k = 0; k < seg; k++) {
					if (ptr[k] != check_buf[k]) {
						fprintf(stderr, "flash offset 0x%08lx: expected 0x%02x, read 0x%02x\n",
						addr+k, ptr[k], check_buf[k]);
					}
				}

				if (read_attempts > 0)
					continue;

				ret = -1;
				goto err;
			}
		}

		addr += seg;
		remain -= seg;
		ptr += seg;
	}

	printf("\n");

err:
	free(check_buf);
	return ret;
}

int flash_erase_progress(struct flash_device *fdev, size_t addr, size_t len)
{
	int ret;
	size_t remain = len;
	size_t seg;
	int step = 0x10000;

	printf("Start address: 0x%08lx\n", addr);
	printf("Length: 0x%08lx\n", len);

	step = fdev->erase_block_size > step ? fdev->erase_block_size : step;

	while (remain > 0) {
		if (remain > step) {
			// longer than step, trim
			if ((addr + step) & (step-1)) {
				// align to step size
				seg = step - ((addr + step) & (step-1));
			} else {
				// already aligned
				seg = step;
			}
		} else {
			// shorter than step
			seg = remain;
		}

		printf("Erase address 0x%08lx, length 0x%08lx (%ld%%)\r", addr, seg, ((100*(len-remain))/len));
		fflush(stdout);

		ret = flash_erase(fdev, addr, seg);

		if (ret)
			return ret;

		addr += seg;
		remain -= seg;
	}

	printf("\n");

	return 0;
}

int write_str_to_file(const char *file_name, const char *str)
{
	int ret = 0;
	FILE *fp = fopen(file_name, "w");

	if (!fp) {
		perror("failed to open file");
		return -1;
	}

	if (fputs(str, fp) == EOF) {
		perror("failed to write to file");
		ret = -1;
	}

	fclose(fp);
	return ret;
}

int write_1_to_file(const char *file_name)
{
	return write_str_to_file(file_name, "1");
}

#define FILE_TYPE_BIN 0
#define FILE_TYPE_HEX 1
#define FILE_TYPE_BIT 2

int file_type_from_ext(const char *file_name)
{
	const char *ptr;
	char buffer[32];

	ptr = strrchr(file_name, '.');

	if (!ptr) {
		return FILE_TYPE_BIN;
	}

	ptr++;

	for (int i = 0; i < sizeof(buffer)-1 && *ptr; i++) {
		buffer[i] = tolower(*ptr++);
		buffer[i+1] = 0;
	}

	if (strcmp(buffer, "hex") == 0 || strcmp(buffer, "mcs") == 0) {
		return FILE_TYPE_HEX;
	}

	if (strcmp(buffer, "bit") == 0) {
		return FILE_TYPE_BIT;
	}

	return FILE_TYPE_BIN;
}

int pcie_hot_reset(const char *pci_port_path)
{
	int fd;
	char path[PATH_MAX+32];
	char buf[32];

	snprintf(path, sizeof(path), "%s/config", pci_port_path);

	fd = open(path, O_RDWR);

	if (fd < 0) {
		perror("Failed to open config region of port");
		return -1;
	}

	// set and then clear secondary bus reset bit (mask 0x0040)
	// in the bridge control register (offset 0x3e)
	pread(fd, buf, 2, PCI_BRIDGE_CONTROL);

	buf[2] = buf[0] | PCI_BRIDGE_CTL_BUS_RESET;
	buf[3] = buf[1];

	pwrite(fd, buf+2, 2, PCI_BRIDGE_CONTROL);

	usleep(10000);

	pwrite(fd, buf, 2, PCI_BRIDGE_CONTROL);

	close(fd);

	return 0;
}

int pcie_disable_fatal_err(const char *pci_port_path)
{
	int fd;
	char path[PATH_MAX+32];
	char buf[32];
	int offset;

	snprintf(path, sizeof(path), "%s/config", pci_port_path);

	fd = open(path, O_RDWR);

	if (fd < 0) {
		perror("Failed to open config region of port");
		return -1;
	}

	// clear SERR bit (mask 0x0100) in command register (offset 0x04)
	pread(fd, buf, 2, PCI_COMMAND);

	buf[1] &= ~(PCI_COMMAND_SERR >> 8);

	pwrite(fd, buf, 2, PCI_COMMAND);

	// clear fatal error reporting bit (mask 0x0004) in
	// PCIe capability device control register (offset 0x08)

	// find PCIe capability (ID 0x10)
	pread(fd, buf, 1, PCI_CAPABILITY_LIST);

	offset = buf[0] & 0xfc;

	while (offset > 0) {
		pread(fd, buf, 2, offset);

		if (buf[0] == PCI_CAP_ID_EXP)
			break;

		offset = buf[1] & 0xfc;
	}

	// clear bit
	if (offset) {
		pread(fd, buf, 2, offset+PCI_EXP_DEVCTL);

		buf[0] &= ~PCI_EXP_DEVCTL_FERE;

		pwrite(fd, buf, 2, offset+PCI_EXP_DEVCTL);
	}

	close(fd);

	return 0;
}

struct vpd_reg_priv {
	int fd;
	int offset;
};

static int reg_if_vpd_read32(const struct reg_if *reg, size_t offset, uint32_t *value)
{
	const struct vpd_reg_priv *priv = reg->priv;
	uint16_t offs = offset & 0x7fff; // clear F
	pwrite(priv->fd, &offs, 2, priv->offset+PCI_VPD_ADDR);
	pread(priv->fd, value, 4, priv->offset+PCI_VPD_DATA);
	return 0;
}

static int reg_if_vpd_write32(const struct reg_if *reg, size_t offset, uint32_t value)
{
	const struct vpd_reg_priv *priv = reg->priv;
	uint16_t offs = offset | 0x8000; // set F
	pwrite(priv->fd, &value, 4, priv->offset+PCI_VPD_DATA);
	pwrite(priv->fd, &offs, 2, priv->offset+PCI_VPD_ADDR);
	return 0;
}

static void reg_if_vpd_close(const struct reg_if *reg)
{
	free(reg->priv);
}

static const struct reg_if_ops reg_if_vpd_ops = {
	.read32 = reg_if_vpd_read32,
	.write32 = reg_if_vpd_write32,
	.close = reg_if_vpd_close,
};

struct reg_if *reg_if_open_vpd(int fd)
{
	char buf[32];
	int offset;

	struct reg_if *reg = calloc(sizeof(struct reg_if), 1);

	if (!reg)
		return NULL;

	struct vpd_reg_priv *priv = calloc(sizeof(struct vpd_reg_priv), 1);

	if (!priv) {
		free(reg);
		return NULL;
	}

	reg->priv = priv;
	reg->ops = &reg_if_vpd_ops;

	// find VPD capability (ID 0x03)
	pread(fd, buf, 1, PCI_CAPABILITY_LIST);

	offset = buf[0] & 0xfc;

	while (offset > 0) {
		pread(fd, buf, 2, offset);

		if (buf[0] == PCI_CAP_ID_VPD)
			break;

		offset = buf[1] & 0xfc;
	}

	if (!offset || buf[0] != PCI_CAP_ID_VPD) {
		perror("Failed to locate VPD capability");
		reg_if_close(reg);
		return NULL;
	}

	priv->fd = fd;
	priv->offset = offset;

	return reg;
}

int main(int argc, char *argv[])
{
	char *name;
	int opt;
	int ret = 0;

	struct reg_if *vpd_regs;

	char dev_name[32] = "";
	char *read_file_name = NULL;
	FILE *read_file = NULL;
	char *write_file_name = NULL;
	FILE *write_file = NULL;

	int config_fd;

	char path[PATH_MAX+32] = "";
	char pci_device_path[PATH_MAX] = "";
	char pci_port_path[PATH_MAX] = "";
	char *ptr;

	int slot = -1;

	char action_read = 0;
	char action_write = 0;
	char action_erase = 0;
	char action_boot = 0;
	char action_reset = 0;
	char no_confirm = 0;

	struct reg_block *rb_list = NULL;
	struct reg_block *fw_id_rb = NULL;
	struct reg_block *flash_rb = NULL;

	uint32_t fpga_id;
	uint32_t fw_id;
	uint32_t fw_ver;
	uint32_t board_id;
	uint32_t board_ver;
	uint32_t build_date;
	uint32_t git_hash;
	uint32_t rel_info;
	const char *fpga_part;

	char build_date_str[32];

	struct flash_device *pri_flash = NULL;
	struct flash_device *sec_flash = NULL;

	int flash_segment_count = 0;
	size_t flash_segment_start[MAX_SEGMENTS];
	size_t flash_segment_length[MAX_SEGMENTS];

	printf("Pyrite flashing utility\n");
	printf("Version: 0.0.1\n");
	printf("Copyright (c) 2026 FPGA Ninja, LLC\n");
	printf("https://fpga.ninja/\n");

	name = strrchr(argv[0], '/');
	name = name ? 1+name : argv[0];

	while ((opt = getopt(argc, argv, "s:p:r:w:ebtyh?")) != EOF) {
		switch (opt) {
		case 's':
			{
				int domain;
				int bus;
				int dev;
				int func;

				if (sscanf(optarg, "%x:%x:%x.%x", &domain, &bus, &dev, &func) == 4) {

				} else if (sscanf(optarg, "%x:%x.%x", &bus, &dev, &func) == 3) {
					domain = 0;
				} else {
					fprintf(stderr, "Failed to parse PCIe device ID\n");
					usage(name);
					return -1;
				}

				snprintf(dev_name, sizeof(dev_name), "%04x:%02x:%02x.%x", domain, bus, dev, func);
			}

			break;
		case 'p':
			slot = atoi(optarg);
			break;
		case 'r':
			action_read = 1;
			read_file_name = optarg;
			break;
		case 'w':
			action_write = 1;
			write_file_name = optarg;
			break;
		case 'e':
			action_erase = 1;
			break;
		case 'b':
			action_boot = 1;
			action_reset = 1;
			break;
		case 't':
			action_reset = 1;
			break;
		case 'y':
			no_confirm = 1;
			break;
		case 'h':
		case '?':
			usage(name);
			return 0;
		default:
			usage(name);
			return -1;
		}
	}

	if (strlen(dev_name) == 0) {
		fprintf(stderr, "Device not specified\n");
		usage(name);
		return -1;
	}

	snprintf(pci_device_path, sizeof(pci_device_path), "/sys/bus/pci/devices/%s", dev_name);

	snprintf(path, sizeof(path), "%s/config", pci_device_path);

	config_fd = open(path, O_RDWR);

	if (config_fd < 0) {
		perror("Failed to open config region");
		return -1;
	}

	vpd_regs = reg_if_open_vpd(config_fd);
	if (!vpd_regs) {
		perror("Failed to initialize VPD capability");
		ret = -1;
		goto err;
	}

	// determine sysfs path of upstream port
	realpath(pci_device_path, pci_port_path);
	ptr = strrchr(pci_port_path, '/');
	if (ptr)
		*ptr = 0;

	printf("PCIe ID (device): %s\n", strrchr(pci_device_path, '/')+1);
	printf("PCIe ID (upstream port): %s\n", strrchr(pci_port_path, '/')+1);

	rb_list = enumerate_reg_block_list(vpd_regs, 0x4000, 0, 0x4000);

	printf("Register blocks:\n");
	for (struct reg_block *rb = rb_list; rb->regs; rb++)
		printf(" type 0x%08x (v %d.%d.%d)\n", rb->type, rb->version >> 20,
				(rb->version >> 12) & 0xff, rb->version & 0xfff);

	fw_id_rb = find_reg_block(rb_list, 0xffffffff, 0, 0);
	if (!fw_id_rb) {
		perror("Failed to find firmware ID block");
		ret = -1;
		goto err;
	}

	reg_if_read32(fw_id_rb->regs, 0x0C, &fpga_id);
	reg_if_read32(fw_id_rb->regs, 0x10, &fw_id);
	reg_if_read32(fw_id_rb->regs, 0x14, &fw_ver);
	reg_if_read32(fw_id_rb->regs, 0x18, &board_id);
	reg_if_read32(fw_id_rb->regs, 0x1C, &board_ver);
	reg_if_read32(fw_id_rb->regs, 0x20, &build_date);
	reg_if_read32(fw_id_rb->regs, 0x24, &git_hash);
	reg_if_read32(fw_id_rb->regs, 0x28, &rel_info);

	fpga_part = get_fpga_part(fpga_id);

	time_t build_date_time = build_date;
	struct tm *tm_info = gmtime(&build_date_time);
	strftime(build_date_str, sizeof(build_date_str), "%F %T", tm_info);

	printf("FPGA ID: 0x%08x\n", fpga_id);
	printf("FPGA part: %s\n", fpga_part);
	printf("FW ID: 0x%08x\n", fw_id);
	printf("FW version: %d.%d.%d\n", fw_ver >> 20,
			(fw_ver >> 12) & 0xff,
			fw_ver & 0xfff);
	printf("Board ID: 0x%08x\n", board_id);
	printf("Board version: %d.%d.%d\n", board_ver >> 20,
			(board_ver >> 12) & 0xff,
			board_ver & 0xfff);
	printf("Build date: %s UTC (raw 0x%08x)\n", build_date_str, build_date);
	printf("Git hash: %08x\n", git_hash);
	printf("Release info: %08x\n", rel_info);

	if (fpga_id == 0 || fpga_id == 0xffffffff) {
		fprintf(stderr, "Invalid FPGA ID\n");
		ret = -1;
		goto skip_flash;
	}

	uint32_t flash_format = 0;

	uint8_t flash_configuration = 0;
	uint8_t flash_data_width = 0;
	uint8_t flash_default_segment = 0;
	uint8_t flash_fallback_segment = 0;
	uint32_t flash_segment0_length = 0;

	int bitswap = 0;
	int word_size = 8;
	int dual_qspi = 0;

	size_t flash_size = 0;
	size_t segment_size = 0;
	size_t segment_offset = 0;

	if ((flash_rb = find_reg_block(rb_list, 0x0000c120, 0, 0))) {
		uint32_t reg_val;

		// SPI flash
		reg_if_read32(flash_rb->regs, 0x0C, &flash_format);

		printf("Flash type: SPI\n");
		printf("Flash format: 0x%08x\n", flash_format);

		switch (flash_rb->version) {
		case 0x00000100:
		case 0x00001000:
			flash_configuration = flash_format & 0xf;
			flash_default_segment = (flash_format >> 4) & 0xf;
			flash_fallback_segment = (flash_format >> 8) & 0xf;
			flash_segment0_length = flash_format & 0xfffff000;
			break;
		default:
			fprintf(stderr, "Unknown SPI flash block version\n");
			ret = -1;
			goto skip_flash;
		}

		// determine data width
		flash_data_width = 0;

		reg_if_write32(flash_rb->regs, 0x10, 0x00020f0f);
		reg_if_read32(flash_rb->regs, 0x10, &reg_val);
		reg_if_write32(flash_rb->regs, 0x10, 0x00020000);

		reg_val &= 0xf;

		while (reg_val) {
			reg_val >>= 1;
			flash_data_width++;
		}

		reg_if_write32(flash_rb->regs, 0x14, 0x00020f0f);
		reg_if_read32(flash_rb->regs, 0x14, &reg_val);
		reg_if_write32(flash_rb->regs, 0x14, 0x00020000);

		reg_val &= 0xf;

		while (reg_val) {
			reg_val >>= 1;
			flash_data_width++;
		}

		printf("Data width: %d\n", flash_data_width);

		if (flash_data_width > 4) {
			dual_qspi = 1;
			pri_flash = flash_open_spi(4, flash_rb->regs, 0x10);
			sec_flash = flash_open_spi(4, flash_rb->regs, 0x14);

			if (!pri_flash || !sec_flash) {
				fprintf(stderr, "Failed to connect to flash device\n");
				ret = -1;
				goto skip_flash;
			}

			flash_size = pri_flash->size+sec_flash->size;
		} else {
			pri_flash = flash_open_spi(4, flash_rb->regs, 0x10);

			if (!pri_flash) {
				fprintf(stderr, "Failed to connect to flash device\n");
				ret = -1;
				goto skip_flash;
			}

			flash_size = pri_flash->size;
		}
	} else if ((flash_rb = find_reg_block(rb_list, 0x0000c121, 0, 0))) {
		uint32_t reg_val;

		// BPI flash
		reg_if_read32(flash_rb->regs, 0x0C, &flash_format);

		printf("Flash type: BPI\n");
		printf("Flash format: 0x%08x\n", flash_format);

		switch (flash_rb->version) {
		case 0x00000100:
		case 0x00001000:
			flash_configuration = flash_format & 0xf;
			flash_default_segment = (flash_format >> 4) & 0xf;
			flash_fallback_segment = (flash_format >> 8) & 0xf;
			flash_segment0_length = flash_format & 0xfffff000;
			break;
		default:
			fprintf(stderr, "Unknown BPI flash block version\n");
			ret = -1;
			goto skip_flash;
		}

		// determine data width
		reg_if_write32(flash_rb->regs, 0x10, 0x0001010f);
		reg_if_write32(flash_rb->regs, 0x18, 0xffffffff);
		reg_if_read32(flash_rb->regs, 0x18, &reg_val);
		reg_if_write32(flash_rb->regs, 0x10, 0x0000000f);
		reg_if_write32(flash_rb->regs, 0x18, 0x00000000);

		flash_data_width = 0;
		while (reg_val) {
			reg_val >>= 1;
			flash_data_width++;
		}

		printf("Data width: %d\n", flash_data_width);

		bitswap = 1;

		if (flash_data_width == 16) {
			word_size = 16;
		}

		pri_flash = flash_open_bpi(flash_data_width,
				flash_rb->regs, 0x10, 0x14, 0x18);

		if (!pri_flash) {
			fprintf(stderr, "Failed to connect to flash device\n");
			ret = -1;
			goto skip_flash;
		}

		flash_size = pri_flash->size;
	} else {
		fprintf(stderr, "Failed to detect flash\n");
		ret = -1;
		goto skip_flash;
	}

	switch (flash_configuration) {
	case 0:
	case 1:
		flash_segment_count = 1;
		flash_segment_start[0] = 0;
		flash_segment_length[0] = flash_size;
		break;
	case 2:
		if (flash_segment0_length == 0) {
			flash_segment0_length = flash_size >> 1;
		} else if (flash_size < flash_segment0_length) {
			fprintf(stderr, "Invalid flash configuration\n");
			ret = -1;
			goto skip_flash;
		}

		flash_segment_count = 2;
		flash_segment_start[0] = 0;
		flash_segment_length[0] = flash_segment0_length;
		flash_segment_start[1] = flash_segment_start[0]+flash_segment_length[0];
		flash_segment_length[1] = flash_size-flash_segment_start[1];
		break;
	case 4:
		flash_segment_count = 4;
		flash_segment_start[0] = 0;
		flash_segment_length[0] = flash_size >> 2;
		for (int k = 1; k < 4; k++) {
			flash_segment_start[k] = flash_segment_start[k-1]+flash_segment_length[k-1];
			flash_segment_length[k] = flash_size >> 2;
		}
		break;
	case 8:
		flash_segment_count = 8;
		flash_segment_start[0] = 0;
		flash_segment_length[0] = flash_size >> 3;
		for (int k = 1; k < 8; k++) {
			flash_segment_start[k] = flash_segment_start[k-1]+flash_segment_length[k-1];
			flash_segment_length[k] = flash_size >> 3;
		}
		break;
	default:
		fprintf(stderr, "Unknown flash configuration (0x%02x)\n", flash_configuration);
		ret = -1;
		goto skip_flash;
	}

	for (int k = 0; k < flash_segment_count; k++) {
		printf("Flash segment %d: start 0x%08lx length 0x%08lx\n", k, flash_segment_start[k], flash_segment_length[k]);
	}

	printf("Default segment: %d\n", flash_default_segment);
	if (flash_fallback_segment == flash_default_segment || flash_fallback_segment >= flash_segment_count) {
		printf("Fallback segment: none\n");
	} else {
		printf("Fallback segment: %d\n", flash_fallback_segment);
	}

	if (slot < 0) {
		slot = flash_default_segment;
	}

	if ((action_read || action_write) && (slot < 0 || slot >= flash_segment_count)) {
		fprintf(stderr, "Requested slot is not valid (%d)\n", slot);
		ret = -1;
		goto err;
	}

	segment_offset = flash_segment_start[slot];
	segment_size = flash_segment_length[slot];

	printf("Selected: segment %d start 0x%08lx length 0x%08lx\n", slot, segment_offset, segment_size);

	if (action_erase) {
		if (!no_confirm) {
			char str[32];

			printf("Are you sure you want to erase the selected segment?\n");
			printf("[y/N]: ");

			fgets(str, sizeof(str), stdin);

			if (str[0] != 'y' && str[0] != 'Y')
			goto err;
		}

		if (dual_qspi) {
			// Dual QSPI flash
			printf("Erasing primary flash...\n");
			if (flash_erase_progress(pri_flash, segment_offset/2, segment_size/2)) {
				fprintf(stderr, "Erase failed!\n");
				ret = -1;
				goto err;
			}

			printf("Erasing secondary flash...\n");
			if (flash_erase_progress(sec_flash, segment_offset/2, segment_size/2)) {
				fprintf(stderr, "Erase failed!\n");
				ret = -1;
				goto err;
			}

			printf("Erase complete!\n");
		} else {
			// SPI or BPI flash
			printf("Erasing flash...\n");
			if (flash_erase_progress(pri_flash, segment_offset, segment_size)) {
				fprintf(stderr, "Erase failed!\n");
				ret = -1;
				goto err;
			}

			printf("Erase complete!\n");
		}
	}

	if (action_write) {
		char *segment = calloc(segment_size, 1);
		memset(segment, 0xff, segment_size);
		size_t len;

		int file_type = file_type_from_ext(write_file_name);

		if (file_type == FILE_TYPE_BIN) {
			// read binary file
			printf("Reading binary file \"%s\"...\n", write_file_name);
			write_file = fopen(write_file_name, "rb");

			if (!write_file) {
				fprintf(stderr, "Failed to open file\n");
				free(segment);
				ret = -1;
				goto err;
			}

			fseek(write_file, 0, SEEK_END);
			len = ftell(write_file);
			rewind(write_file);

			if (len > segment_size) {
				fprintf(stderr, "File larger than segment (%ld > %ld)\n", len, segment_size);
				fclose(write_file);
				free(segment);
				ret = -1;
				goto err;
			}

			if (fread(segment, 1, len, write_file) < len) {
				fprintf(stderr, "Error reading file\n");
				fclose(write_file);
				free(segment);
				ret = -1;
				goto err;
			}

			fclose(write_file);
		} else if (file_type == FILE_TYPE_BIT) {
			// read bit file
			struct bitfile *bf;
			char part[128];
			char *ptr1, *ptr2;
			int match = 0;

			printf("Reading bit file \"%s\"...\n", write_file_name);
			bf = bitfile_create_from_file(write_file_name);

			if (!bf) {
				fprintf(stderr, "Error reading bit file\n");
				free(segment);
				ret = -1;
				goto err;
			}

			printf("Part: %s\n", bf->part);
			printf("Date: %s %s\n", bf->date, bf->time);

			// check device type
			// fpga_part may contain multiple possible device types, separated by underscores
			strcpy(part, fpga_part);
			ptr1 = ptr2 = part;

			while (ptr2)
			{
				ptr2 = strchr(ptr1, '_');

				if (ptr2)
					*ptr2 = 0;

				if (stristr(bf->part, ptr1) == bf->part)
					match = 1;

				if (ptr2)
				ptr1 = ptr2+1;
			}

			if (!match) {
				fprintf(stderr, "Device mismatch (target is %s, file is %s)\n", fpga_part, bf->part);
				bitfile_close(bf);
				free(segment);
				ret = -1;
				goto err;
			}

			// check for available space
			if (bf->data_len > segment_size) {
				fprintf(stderr, "File larger than segment (%ld > %ld)\n", bf->data_len, segment_size);
				bitfile_close(bf);
				free(segment);
				ret = -1;
				goto err;
			}

			len = bf->data_len;
			memcpy(segment, bf->data, bf->data_len);

			bitfile_close(bf);
		} else if (file_type == FILE_TYPE_HEX) {
			fprintf(stderr, "Hex files are not currently supported\n");
			free(segment);
			ret = -1;
			goto err;
		} else {
			fprintf(stderr, "Unsupported file type\n");
			free(segment);
			ret = -1;
			goto err;
		}

		// check sync word
		if (memcmp(segment+0x50, "\xAA\x99\x55\x66", 4)) {
			fprintf(stderr, "Bitstream sync word not found\n");
			free(segment);
			ret = -1;
			goto err;
		}

		// TODO check for and confirm FPGA ID

		if (bitswap)
		{
			if (word_size == 16)
			{
				uint16_t *p = (uint16_t *)segment;

				for (size_t k = 0; k < segment_size; k += 2) {
					*p = reverse_bits_16(*p);
					p++;
				}
			} else {
				uint8_t *p = (uint8_t *)segment;

				for (size_t k = 0; k < segment_size; k++) {
					*p = reverse_bits_8(*p);
					p++;
				}
			}
		}

		if (dual_qspi) {
			// Dual QSPI flash

			// check sync word for dual QSPI re-sync
			if (memcmp(segment+0x70, "\xAA\x99\x55\x66", 4)) {
				fprintf(stderr, "Bitstream sync word not found for dual QSPI re-sync\n");
				free(segment);
				ret = -1;
				goto err;
			}

			char *pri_buf = calloc(segment_size/2, 1);
			char *sec_buf = calloc(segment_size/2, 1);
			memset(pri_buf, 0xff, segment_size/2);
			memset(sec_buf, 0xff, segment_size/2);

			int offset = 0x68;

			size_t len_int = (len - offset) / 2 + offset;

			if (len_int > segment_size/2)
				len_int = segment_size/2;

			memcpy(pri_buf, segment, offset);

			char *c1 = pri_buf+offset;
			char *c2 = sec_buf+offset;

			for (size_t k = offset; k < segment_size-offset; k += 2) {
				*c1 = (segment[k+1] & 0x0f) | ((segment[k] << 4) & 0xf0);
				*c2 = ((segment[k+1] >> 4) & 0x0f) | (segment[k] & 0xf0);
				c1++;
				c2++;
			}

			// round up length to block size
			if ((segment_offset/2 + len_int) & (pri_flash->erase_block_size-1)) {
				len_int += pri_flash->erase_block_size - ((segment_offset/2 + len_int) & (pri_flash->erase_block_size-1));
			}

			if (!no_confirm) {
				char str[32];

				printf("Are you sure you want to write the selected segment?\n");
				printf("[y/N]: ");

				fgets(str, sizeof(str), stdin);

				if (str[0] != 'y' && str[0] != 'Y')
				goto err;
			}

			printf("Erasing primary flash...\n");
			if (flash_erase_progress(pri_flash, segment_offset/2, len_int)) {
				fprintf(stderr, "Erase failed!\n");
				ret = -1;
				free(segment);
				free(pri_buf);
				free(sec_buf);
				goto err;
			}

			printf("Erasing secondary flash...\n");
			if (flash_erase_progress(sec_flash, segment_offset/2, len_int)) {
				fprintf(stderr, "Erase failed!\n");
				ret = -1;
				free(segment);
				free(pri_buf);
				free(sec_buf);
				goto err;
			}

			printf("Writing and verifying primary flash...\n");
			if (flash_write_verify_progress(pri_flash, segment_offset/2, len_int, pri_buf)) {
				fprintf(stderr, "Write/verify failed!\n");
				ret = -1;
				free(segment);
				free(pri_buf);
				free(sec_buf);
				goto err;
			}

			printf("Writing and verifying secondary flash...\n");
			if (flash_write_verify_progress(sec_flash, segment_offset/2, len_int, sec_buf)) {
				fprintf(stderr, "Write/verify failed!\n");
				ret = -1;
				free(segment);
				free(pri_buf);
				free(sec_buf);
				goto err;
			}

			printf("Programming succeeded!\n");

			free(pri_buf);
			free(sec_buf);
		} else {
			// SPI or BPI flash

			// round up length to block size
			if ((segment_offset + len) & (pri_flash->erase_block_size-1)) {
				len += pri_flash->erase_block_size - ((segment_offset + len) & (pri_flash->erase_block_size-1));
			}

			if (!no_confirm) {
				char str[32];

				printf("Are you sure you want to write the selected segment?\n");
				printf("[y/N]: ");

				fgets(str, sizeof(str), stdin);

				if (str[0] != 'y' && str[0] != 'Y')
				goto err;
			}

			printf("Erasing flash...\n");
			if (flash_erase_progress(pri_flash, segment_offset, len)) {
				fprintf(stderr, "Erase failed!\n");
				ret = -1;
				free(segment);
				goto err;
			}

			printf("Writing and verifying flash...\n");
			if (flash_write_verify_progress(pri_flash, segment_offset, len, segment)) {
				fprintf(stderr, "Write/verify failed!\n");
				ret = -1;
				free(segment);
				goto err;
			}

			printf("Programming succeeded!\n");
		}

		free(segment);
	}

	if (action_read) {
		char *segment = calloc(segment_size, 1);
		memset(segment, 0xff, segment_size);

		if (dual_qspi) {
			char *pri_buf = calloc(segment_size/2, 1);
			char *sec_buf = calloc(segment_size/2, 1);

			printf("Reading primary flash...\n");
			flash_read_progress(pri_flash, segment_offset/2, segment_size/2, pri_buf);
			printf("Reading secondary flash...\n");
			flash_read_progress(sec_flash, segment_offset/2, segment_size/2, sec_buf);

			int offset = 0x68;

			memcpy(segment, pri_buf, offset);

			char *c1 = pri_buf+offset;
			char *c2 = sec_buf+offset;

			for (size_t k = offset; k < segment_size-offset; k += 2) {
				segment[k] = ((*c1 >> 4) & 0x0f) | (*c2 & 0xf0);
				segment[k+1] = (*c1 & 0x0f) | ((*c2 << 4) & 0xf0);
				c1++;
				c2++;
			}

			free(pri_buf);
			free(sec_buf);
		} else {
			printf("Reading flash...\n");
			flash_read_progress(pri_flash, segment_offset, segment_size, segment);
		}

		if (bitswap) {
			if (word_size == 16) {
				uint16_t *p = (uint16_t *)segment;

				for (size_t k = 0; k < segment_size; k += 2) {
					*p = reverse_bits_16(*p);
					p++;
				}
			} else {
				uint8_t *p = (uint8_t *)segment;

				for (size_t k = 0; k < segment_size; k++) {
					*p = reverse_bits_8(*p);
					p++;
				}
			}
		}

		int file_type = file_type_from_ext(read_file_name);

		if (file_type == FILE_TYPE_BIN) {
			// write binary file
			printf("Writing binary file \"%s\"...\n", read_file_name);
			read_file = fopen(read_file_name, "wb");
			fwrite(segment, 1, segment_size, read_file);
			fclose(read_file);
		} else if (file_type == FILE_TYPE_HEX) {
			fprintf(stderr, "Hex files are not currently supported\n");
			free(segment);
			ret = -1;
			goto err;
		} else {
			fprintf(stderr, "Unsupported file type\n");
			free(segment);
			ret = -1;
			goto err;
		}

		free(segment);
	}

skip_flash:
	if (ret && (action_read || action_write)) {
		goto err;
	} else {
		ret = 0;
	}

	flash_release(pri_flash);
	pri_flash = NULL;
	flash_release(sec_flash);
	sec_flash = NULL;

	if (action_boot || action_reset) {
		if (!no_confirm) {
			char str[32];

			if (action_boot)
				printf("Are you sure you want to boot from flash?\n");
			else
				printf("Are you sure you want to perform a reset?\n");
			printf("[y/N]: ");

			fgets(str, sizeof(str), stdin);

			if (str[0] != 'y' && str[0] != 'Y')
				goto err;
		}

		printf("Preparing to reset device...\n");

		// disable fatal error reporting on port (to prevent IPMI-triggered reboot)
		printf("Disabling PCIe fatal error reporting on port...\n");
		pcie_disable_fatal_err(pci_port_path);

		// attempt to disconnect driver
		snprintf(path, sizeof(path), "%s/driver/unbind", pci_device_path);

		if (access(path, F_OK) == 0) {
			printf("Unbinding driver...\n");
			write_str_to_file(path, ptr+1);
		} else {
			printf("No driver bound\n");
		}

		sleep(1);

		// trigger FPGA reload
		if (action_boot) {
			// reload FPGA
			printf("Triggering IPROG to reload FPGA...\n");
			if (flash_rb)
				reg_if_write32(flash_rb->regs, 0x0C, 0xFEE1DEAD);
			reg_if_write32(fw_id_rb->regs, 0x0C, 0xFEE1DEAD);

			// disconnect
			reg_if_close(vpd_regs);
			vpd_regs = NULL;
			close(config_fd);
		}

		// remove PCIe device
		printf("Removing device...\n");

		snprintf(path, sizeof(path), "%s/remove", pci_device_path);

		if (write_1_to_file(path)) {
			fprintf(stderr, "Failed to remove device!\n");
			ret = -1;
			goto err;
		}

		if (action_boot) {
			// give FPGA some time to boot from flash
			sleep(4);
		}

		sleep(1);

		for (int tries = 5; tries > 0; tries--) {
			printf("Performing hot reset on upstream port...\n");
			pcie_hot_reset(pci_port_path);

			sleep(2);

			printf("Rescanning on upstream port...\n");

			snprintf(path, sizeof(path), "%s/rescan", pci_port_path);

			if (write_1_to_file(path)) {
				fprintf(stderr, "Rescan failed!\n");
				ret = -1;
				goto err;
			}

			// PCIe device will have a config space, so check for that
			snprintf(path, sizeof(path), "%s/config", pci_device_path);

			if (access(path, F_OK) == 0) {
				printf("Success, device is online!\n");
				break;
			} else {
				if (tries > 0) {
					printf("Rescan failed, attempting another reset (up to %d more)\n", tries);
				} else {
					fprintf(stderr, "Rescan failed, device is offline!\n");
					ret = -1;
					goto err;
				}
			}
		}

	}

err:
	flash_release(pri_flash);
	flash_release(sec_flash);

	reg_if_close(vpd_regs);
	close(config_fd);

	return ret;
}
