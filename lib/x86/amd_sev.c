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

static unsigned long long amd_sev_c_bit_pos;

bool amd_sev_enabled(void)
{
	struct cpuid cpuid_out;
	static bool sev_enabled;
	static bool initialized = false;

	/* Check CPUID and MSR for SEV status and store it for future function calls. */
	if (!initialized) {
		sev_enabled = false;
		initialized = true;

		/* Test if we can query SEV features */
		cpuid_out = cpuid(CPUID_FN_LARGEST_EXT_FUNC_NUM);
		if (cpuid_out.a < CPUID_FN_ENCRYPT_MEM_CAPAB) {
			return sev_enabled;
		}

		/* Test if SEV is supported */
		cpuid_out = cpuid(CPUID_FN_ENCRYPT_MEM_CAPAB);
		if (!(cpuid_out.a & SEV_SUPPORT_MASK)) {
			return sev_enabled;
		}

		/* Test if SEV is enabled */
		if (!(rdmsr(MSR_SEV_STATUS) & SEV_ENABLED_MASK)) {
			return sev_enabled;
		}

		sev_enabled = true;
	}

	return sev_enabled;
}

EFI_STATUS setup_amd_sev(void)
{
	struct cpuid cpuid_out;

	if (!amd_sev_enabled()) {
		return EFI_UNSUPPORTED;
	}

	/*
	 * Extract C-Bit position from ebx[5:0]
	 * AMD64 Architecture Programmer's Manual Volume 3
	 *   - Section " Function 8000_001Fh - Encrypted Memory Capabilities"
	 */
	cpuid_out = cpuid(CPUID_FN_ENCRYPT_MEM_CAPAB);
	amd_sev_c_bit_pos = (unsigned long long)(cpuid_out.b & 0x3f);

	return EFI_SUCCESS;
}

bool amd_sev_es_enabled(void)
{
	static bool sev_es_enabled;
	static bool initialized = false;

	if (!initialized) {
		sev_es_enabled = false;
		initialized = true;

		if (!amd_sev_enabled()) {
			return sev_es_enabled;
		}

		/* Test if SEV-ES is enabled */
		if (!(rdmsr(MSR_SEV_STATUS) & SEV_ES_ENABLED_MASK)) {
			return sev_es_enabled;
		}

		sev_es_enabled = true;
	}

	return sev_es_enabled;
}

static void copy_gdt_entry(gdt_entry_t *dst, gdt_entry_t *src, unsigned segment)
{
	unsigned index;

	index = segment / sizeof(gdt_entry_t);
	dst[index] = src[index];
}

/* Defined in x86/efi/efistart64.S */
extern gdt_entry_t gdt64[];

/*
 * Copy UEFI's code and data segments to KVM-Unit-Tests GDT.
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
	if (!amd_sev_es_enabled()) {
		return;
	}

	/* GDT and GDTR in current UEFI */
	gdt_entry_t *gdt_curr;
	struct descriptor_table_ptr gdtr_curr;

	/* Copy code and data segments from UEFI */
	sgdt(&gdtr_curr);
	gdt_curr = (gdt_entry_t *)gdtr_curr.base;
	copy_gdt_entry(gdt64, gdt_curr, read_cs());
	copy_gdt_entry(gdt64, gdt_curr, read_ds());
}

unsigned long long get_amd_sev_c_bit_mask(void)
{
	if (amd_sev_enabled()) {
		return 1ull << amd_sev_c_bit_pos;
	} else {
		return 0;
	}
}

unsigned long long get_amd_sev_addr_upperbound(void)
{
	if (amd_sev_enabled()) {
		return amd_sev_c_bit_pos - 1;
	} else {
		/* Default memory upper bound */
		return PT_ADDR_UPPER_BOUND_DEFAULT;
	}
}
