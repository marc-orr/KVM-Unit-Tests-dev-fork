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

void setup_efi_bootinfo(efi_bootinfo_t *efi_bootinfo)
{
	efi_bootinfo->free_mem_size = 0;
	efi_bootinfo->free_mem_start = 0;
	efi_bootinfo->rsdp = NULL;
}

static EFI_STATUS setup_pre_boot_memory(UINTN *mapkey, efi_bootinfo_t *efi_bootinfo)
{
	UINTN total_entries, desc_size;
	UINT32 desc_version;
	char *buffer;
	int i;
	UINT64 free_mem_total_pages = 0;

	/* Although buffer entries are later converted to EFI_MEMORY_DESCRIPTOR,
	 * we cannot simply define buffer as 'EFI_MEMORY_DESCRIPTOR *buffer'.
	 * Because the actual buffer entry size 'desc_size' is bigger than
	 * 'sizeof(EFI_MEMORY_DESCRIPTOR)', i.e. there are padding data after
	 * each EFI_MEMORY_DESCRIPTOR. So defining 'EFI_MEMORY_DESCRIPTOR
	 * *buffer' leads to wrong buffer entries fetched.
	 */
	buffer = (char *)LibMemoryMap(&total_entries, mapkey, &desc_size, &desc_version);
	if (desc_version != 1) {
		return EFI_INCOMPATIBLE_VERSION;
	}

	/* The 'buffer' contains multiple descriptors that describe memory
	 * regions maintained by UEFI. This code records the largest free
	 * EfiConventionalMemory region which will be used to set up the memory
	 * allocator, so that the memory allocator can work in the largest free
	 * continuous memory region.
	 */
	for (i = 0; i < total_entries * desc_size; i += desc_size) {
		EFI_MEMORY_DESCRIPTOR *d = (EFI_MEMORY_DESCRIPTOR *)&buffer[i];

		if (d->Type == EfiConventionalMemory) {
			if (free_mem_total_pages < d->NumberOfPages) {
				free_mem_total_pages = d->NumberOfPages;
				efi_bootinfo->free_mem_size = free_mem_total_pages * EFI_PAGE_SIZE;
				efi_bootinfo->free_mem_start = d->PhysicalStart;
			}
		}
	}

	if (efi_bootinfo->free_mem_size == 0) {
		return EFI_OUT_OF_RESOURCES;
	}

	return EFI_SUCCESS;
}

static EFI_STATUS setup_pre_boot_rsdp(efi_bootinfo_t *efi_bootinfo)
{
	return LibGetSystemConfigurationTable(&AcpiTableGuid, (VOID **)&efi_bootinfo->rsdp);
}

EFI_STATUS setup_efi_pre_boot(UINTN *mapkey, efi_bootinfo_t *efi_bootinfo)
{
	EFI_STATUS status;

	status = setup_pre_boot_memory(mapkey, efi_bootinfo);
	if (EFI_ERROR(status)) {
		printf("setup_pre_boot_memory() failed: ");
		switch (status) {
		case EFI_INCOMPATIBLE_VERSION:
			printf("Unsupported descriptor version\n");
			break;
		case EFI_OUT_OF_RESOURCES:
			printf("No free memory region\n");
			break;
		default:
			printf("Unknown error\n");
			break;
		}
		return status;
	}

	status = setup_pre_boot_rsdp(efi_bootinfo);
	if (EFI_ERROR(status)) {
		printf("Cannot find RSDP in EFI system table\n");
		return status;
	}

#ifdef CONFIG_AMD_SEV
	status = setup_amd_sev();
	if (EFI_ERROR(status)) {
		printf("setup_amd_sev() failed: ");
		switch (status) {
		case EFI_UNSUPPORTED:
			printf("SEV is not supported\n");
			break;
		case EFI_NOT_READY:
			printf("SEV is not enabled\n");
			break;
		default:
			printf("Unknown error\n");
			break;
		}
		return status;
	}
#endif /* CONFIG_AMD_SEV */

	return EFI_SUCCESS;
}

/* Defined in cstart64.S or efistart64.S */
extern phys_addr_t ptl5;
extern phys_addr_t ptl4;
extern phys_addr_t ptl3;
extern phys_addr_t ptl2;

static void setup_page_table(void)
{
	pgd_t *curr_pt;
	phys_addr_t flags;
	int i;

	/* Set default flags */
	flags = PT_PRESENT_MASK | PT_WRITABLE_MASK | PT_USER_MASK;

#ifdef CONFIG_AMD_SEV
	/* Set AMD SEV C-Bit for page table entries */
	flags |= get_amd_sev_c_bit_mask();
#endif /* CONFIG_AMD_SEV */

	/* Level 5 */
	curr_pt = (pgd_t *)&ptl5;
	curr_pt[0] = ((phys_addr_t)&ptl4) | flags;
	/* Level 4 */
	curr_pt = (pgd_t *)&ptl4;
	curr_pt[0] = ((phys_addr_t)&ptl3) | flags;
	/* Level 3 */
	curr_pt = (pgd_t *)&ptl3;
	for (i = 0; i < 4; i++) {
		curr_pt[i] = (((phys_addr_t)&ptl2) + i * PAGE_SIZE) | flags;
	}
	/* Level 2 */
	curr_pt = (pgd_t *)&ptl2;
	flags |= PT_ACCESSED_MASK | PT_DIRTY_MASK | PT_PAGE_SIZE_MASK | PT_GLOBAL_MASK;
	for (i = 0; i < 4 * 512; i++)	{
		curr_pt[i] = ((phys_addr_t)(i << 21)) | flags;
	}

	/* Load 4-level page table */
	write_cr3((ulong)&ptl4);
}

void setup_5level_page_table(void)
{
	/*  Check if 5-level page table is already enabled */
	if (read_cr4() & X86_CR4_LA57) {
		return;
	}

	/* Disable CR4.PCIDE */
	write_cr4(read_cr4() & ~(X86_CR4_PCIDE));
	/* Disable CR0.PG */
	write_cr0(read_cr0() & ~(X86_CR0_PG));

	/* Load new page table */
	write_cr3((ulong)&ptl5);

	/* Enable CR4.LA57 */
	write_cr4(read_cr4() | X86_CR4_LA57);
}

static void setup_gdt_tss(void)
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

void setup_efi(efi_bootinfo_t *efi_bootinfo)
{
	reset_apic();
	setup_gdt_tss();
	setup_idt();
	load_idt();
	mask_pic_interrupts();
	enable_apic();
	enable_x2apic();
	smp_init();
	phys_alloc_init(efi_bootinfo->free_mem_start,
			efi_bootinfo->free_mem_size);
	setup_efi_rsdp(efi_bootinfo->rsdp);
	setup_page_table();
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
