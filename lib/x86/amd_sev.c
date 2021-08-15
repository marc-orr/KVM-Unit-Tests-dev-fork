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

unsigned long long get_amd_sev_c_bit_mask(void)
{
	return 1ull << amd_sev_c_bit_pos;
}
