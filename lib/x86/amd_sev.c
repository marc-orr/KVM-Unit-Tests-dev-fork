/*
 * AMD SEV support in KVM-Unit-Tests
 *
 * Copyright (c) 2021, Google Inc
 *
 * Authors:
 *   Zixuan Wang <zixuanwang@google.com>
 *
 * SPDX-License-Identifier: LGPL-2.0-or-later
 */

#include "amd_sev.h"
#include "x86/processor.h"
#include "x86/vm.h"

static unsigned long long amd_sev_c_bit_pos;

EFI_STATUS setup_amd_sev(void)
{
	struct cpuid cpuid_out;

	/* Test if we can query SEV features */
	cpuid_out = cpuid(CPUID_FN_LARGEST_EXT_FUNC_NUM);
	if (cpuid_out.a < CPUID_FN_ENCRYPT_MEM_CAPAB) {
		return EFI_UNSUPPORTED;
	}

	/* Test if SEV is supported */
	cpuid_out = cpuid(CPUID_FN_ENCRYPT_MEM_CAPAB);
	if (!(cpuid_out.a & SEV_SUPPORT_MASK)) {
		return EFI_UNSUPPORTED;
	}

	/* Test if SEV is enabled */
	if (!(rdmsr(MSR_SEV_STATUS) & SEV_ENABLED_MASK)) {
		return EFI_NOT_READY;
	}

	/* Extract C-Bit position from ebx[5:0]
	 * AMD64 Architecture Programmer's Manual Volume 3
	 *   - Section " Function 8000_001Fh - Encrypted Memory Capabilities"
	 */
	amd_sev_c_bit_pos = (unsigned long long)(cpuid_out.b & 0x3f);

	return EFI_SUCCESS;
}

#ifdef CONFIG_AMD_SEV_ES
EFI_STATUS setup_amd_sev_es(void){
	struct descriptor_table_ptr idtr;
	idt_entry_t *idt;

	/* Test if SEV-ES is enabled */
	if (!(rdmsr(MSR_SEV_STATUS) & SEV_ES_ENABLED_MASK)) {
		return EFI_UNSUPPORTED;
	}

	/* Copy UEFI's #VC IDT entry, so KVM-Unit-Tests can reuse it and does
	 * not have to re-implement a #VC handler
	 */
	sidt(&idtr);
	idt = (idt_entry_t *)idtr.base;
	boot_idt[SEV_ES_VC_HANDLER_VECTOR] = idt[SEV_ES_VC_HANDLER_VECTOR];

	return EFI_SUCCESS;
}

void setup_ghcb_pte(pgd_t *page_table)
{
	/* SEV-ES guest uses GHCB page to communicate with host. This page must
	 * be unencrypted, i.e. its c-bit should be unset.
	 */
	phys_addr_t ghcb_addr, ghcb_base_addr;
	pteval_t *pte;

	/* Read the current GHCB page addr */
	ghcb_addr = rdmsr(SEV_ES_GHCB_MSR_INDEX);

	/* Find Level 1 page table entry for GHCB page */
	pte = get_pte_level(page_table, (void *)ghcb_addr, 1);

	/* Create Level 1 pte for GHCB page if not found */
	if (pte == NULL) {
		/* Find Level 2 page base address */
		ghcb_base_addr = ghcb_addr & ~(LARGE_PAGE_SIZE-1);
		/* Install Level 1 ptes */
		install_pages(page_table, ghcb_base_addr, LARGE_PAGE_SIZE,
			      (void *)ghcb_base_addr);
		/* Find Level 2 pte, set as 4KB pages */
		pte = get_pte_level(page_table, (void *)ghcb_addr, 2);
		assert(pte);
		*pte &= ~(PT_PAGE_SIZE_MASK);
		/* Find Level 1 GHCB pte */
		pte = get_pte_level(page_table, (void *)ghcb_addr, 1);
		assert(pte);
	}

	/* Unset c-bit in Level 1 GHCB pte */
	*pte &= ~(get_amd_sev_c_bit_mask());
}

static void copy_gdt_entry(gdt_entry_t *dst, gdt_entry_t *src, unsigned segment)
{
	unsigned index;

	index = segment / sizeof(gdt_entry_t);
	dst[index] = src[index];
}

/* Defined in x86/efi/efistart64.S */
extern gdt_entry_t gdt64[];

/* Copy UEFI's code and data segments to KVM-Unit-Tests GDT.
 *
 * This is because KVM-Unit-Tests reuses UEFI #VC handler that requires UEFI
 * code and data segments to run. The UEFI #VC handler crashes the guest VM if
 * these segments are not available. So we need to copy these two UEFI segments
 * into KVM-Unit-Tests GDT.
 *
 * UEFI uses 0x30 as code segment and 0x38 as data segment. Fortunately, these
 * segments can be safely overridden in KVM-Unit-Tests as they are used as
 * protected mode and real mode segments (see x86/efi/efistart64.S for more
 * details), which are not used in EFI set up process.
 */
void copy_uefi_segments(void)
{
	/* GDT and GDTR in current UEFI */
	gdt_entry_t *gdt_curr;
	struct descriptor_table_ptr gdtr_curr;

	/* Copy code and data segments from UEFI */
	sgdt(&gdtr_curr);
	gdt_curr = (gdt_entry_t *)gdtr_curr.base;
	copy_gdt_entry(gdt64, gdt_curr, read_cs());
	copy_gdt_entry(gdt64, gdt_curr, read_ds());
}
#endif /* CONFIG_AMD_SEV_ES */

unsigned long long get_amd_sev_c_bit_mask(void)
{
	return 1ull << amd_sev_c_bit_pos;
}

unsigned long long get_amd_sev_c_bit_pos(void)
{
	return amd_sev_c_bit_pos;
}
