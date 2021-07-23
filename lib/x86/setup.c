/*
 * Initialize machine setup information
 *
 * Copyright (C) 2017, Red Hat Inc, Andrew Jones <drjones@redhat.com>
 *
 * This work is licensed under the terms of the GNU LGPL, version 2.
 */
#include "libcflat.h"
#include "fwcfg.h"
#include "alloc_phys.h"
#include "argv.h"
#include "x86/desc.h"
#include "asm/setup.h"

extern char edata;

struct mbi_bootinfo {
	u32 flags;
	u32 mem_lower;
	u32 mem_upper;
	u32 boot_device;
	u32 cmdline;
	u32 mods_count;
	u32 mods_addr;
	u32 reserved[4];   /* 28-43 */
	u32 mmap_length;
	u32 mmap_addr;
	u32 reserved0[3];  /* 52-63 */
	u32 bootloader;
	u32 reserved1[5];  /* 68-87 */
	u32 size;
};

struct mbi_module {
	u32 start, end;
	u32 cmdline;
	u32 unused;
};

struct mbi_mem {
	u32 size;
	u64 base_addr;
	u64 length;
	u32 type;
} __attribute__((packed));

#define ENV_SIZE 16384

void setup_env(char *env, int size);
void setup_multiboot(struct mbi_bootinfo *bootinfo);
void setup_libcflat(void);

char *initrd;
u32 initrd_size;

static char env[ENV_SIZE];
static struct mbi_bootinfo *bootinfo;

#define HUGEPAGE_SIZE (1 << 21)

#ifdef __x86_64__
void find_highmem(void)
{
	/* Memory above 4 GB is only supported on 64-bit systems.  */
	if (!(bootinfo->flags & 64))
	    	return;

	u64 upper_end = bootinfo->mem_upper * 1024ull;
	u64 best_start = (uintptr_t) &edata;
	u64 best_end = upper_end;
	u64 max_end = fwcfg_get_u64(FW_CFG_MAX_RAM);
	if (max_end == 0)
		max_end = -1ull;
	bool found = false;

	uintptr_t mmap = bootinfo->mmap_addr;
	while (mmap < bootinfo->mmap_addr + bootinfo->mmap_length) {
		struct mbi_mem *mem = (void *)mmap;
		mmap += mem->size + 4;
		if (mem->type != 1)
			continue;
		if (mem->base_addr <= (uintptr_t) &edata ||
		    (mem->base_addr <= upper_end && mem->base_addr + mem->length <= upper_end))
			continue;
		if (mem->length < best_end - best_start)
			continue;
		if (mem->base_addr >= max_end)
			continue;
		best_start = mem->base_addr;
		best_end = mem->base_addr + mem->length;
		if (best_end > max_end)
			best_end = max_end;
		found = true;
	}

	if (found) {
		best_start = (best_start + HUGEPAGE_SIZE - 1) & -HUGEPAGE_SIZE;
		best_end = best_end & -HUGEPAGE_SIZE;
		phys_alloc_init(best_start, best_end - best_start);
	}
}
#endif

void setup_multiboot(struct mbi_bootinfo *bi)
{
	struct mbi_module *mods;

	bootinfo = bi;

	u64 best_start = (uintptr_t) &edata;
	u64 best_end = bootinfo->mem_upper * 1024ull;
	phys_alloc_init(best_start, best_end - best_start);

	if (bootinfo->mods_count != 1)
		return;

	mods = (struct mbi_module *)(uintptr_t) bootinfo->mods_addr;

	initrd = (char *)(uintptr_t) mods->start;
	initrd_size = mods->end - mods->start;
}

#ifdef TARGET_EFI

/* From x86/efi/efistart64.S */
extern void load_idt(void);
extern void load_gdt_tss(size_t tss_offset);
extern phys_addr_t tss_descr;
extern phys_addr_t ring0stacktop;
extern gdt_entry_t gdt64[];
extern size_t ring0stacksize;

void setup_gdt_tss()
{
	gdt_entry_t *tss_lo, *tss_hi;
	tss64_t *curr_tss;
	phys_addr_t curr_tss_addr;
	u32 id;
	size_t tss_offset;
	size_t pre_tss_entries;

	/* Get APIC ID, see also x86/cstart64.S:load_tss */
	id = apic_id();

	/* Get number of GDT entries before TSS-related GDT entry */
	pre_tss_entries = (size_t)((u8 *)&(tss_descr) - (u8 *)gdt64) / sizeof(gdt_entry_t);

	/* Each TSS descriptor takes up 2 GDT entries */
	tss_offset = (pre_tss_entries + id * 2) * sizeof(gdt_entry_t);
	tss_lo = &(gdt64[pre_tss_entries + id * 2 + 0]);
	tss_hi = &(gdt64[pre_tss_entries + id * 2 + 1]);

	/* Runtime address of current TSS */
	curr_tss_addr = (((phys_addr_t)&tss) + (phys_addr_t)(id * sizeof(tss64_t)));

	/* Use runtime address for ring0stacktop, see also x86/cstart64.S:tss */
	curr_tss = (tss64_t *)curr_tss_addr;
	curr_tss->rsp0 = (u64)((u8*)&ring0stacktop - id * ring0stacksize);

	/* Update TSS descriptors */
	tss_lo->limit_low = sizeof(tss64_t);
	tss_lo->base_low = (u16)(curr_tss_addr & 0xffff);
	tss_lo->base_middle = (u8)((curr_tss_addr >> 16) & 0xff);
	tss_lo->base_high = (u8)((curr_tss_addr >> 24) & 0xff);
	tss_hi->limit_low = (u16)((curr_tss_addr >> 32) & 0xffff);
	tss_hi->base_low = (u16)((curr_tss_addr >> 48) & 0xffff);

	load_gdt_tss(tss_offset);
}

void setup_efi(void)
{
	reset_apic();
	setup_gdt_tss();
	setup_idt();
	load_idt();
	mask_pic_interrupts();
	enable_apic();
	enable_x2apic();
	smp_init();
}

#endif /* TARGET_EFI */

void setup_libcflat(void)
{
	if (initrd) {
		/* environ is currently the only file in the initrd */
		u32 size = MIN(initrd_size, ENV_SIZE);
		const char *str;

		memcpy(env, initrd, size);
		setup_env(env, size);
		if ((str = getenv("BOOTLOADER")) && atol(str) != 0)
			add_setup_arg("bootloader");
	}
}
