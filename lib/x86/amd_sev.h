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

#ifndef _X86_AMD_SEV_H_
#define _X86_AMD_SEV_H_

#include "libcflat.h"
#include "desc.h"
#include "asm/page.h"

#ifdef ALIGN
#undef ALIGN
#endif
#include <efi.h>

/* AMD Programmer's Manual Volume 3
 *   - Section "Function 8000_0000h - Maximum Extended Function Number and Vendor String"
 *   - Section "Function 8000_001Fh - Encrypted Memory Capabilities"
 */
#define CPUID_FN_LARGEST_EXT_FUNC_NUM 0x80000000
#define CPUID_FN_ENCRYPT_MEM_CAPAB    0x8000001f
#define SEV_SUPPORT_MASK              0b10

/* AMD Programmer's Manual Volume 2
 *   - Section "SEV_STATUS MSR"
 */
#define MSR_SEV_STATUS      0xc0010131
#define SEV_ENABLED_MASK    0b1
#define SEV_ES_ENABLED_MASK 0b10

/* AMD Programmer's Manual Volume 2
 *   - Section "#VC Exception"
 */
#define SEV_ES_VC_HANDLER_VECTOR 29

/* AMD Programmer's Manual Volume 2
 *   - Section "GHCB"
 */
#define SEV_ES_GHCB_MSR_INDEX 0xc0010130

EFI_STATUS setup_amd_sev(void);
#ifdef CONFIG_AMD_SEV_ES
EFI_STATUS setup_amd_sev_es(void);
void setup_ghcb_pte(pgd_t *page_table);
void copy_uefi_segments(void);
#endif /* CONFIG_AMD_SEV_ES */

unsigned long long get_amd_sev_c_bit_mask(void);
unsigned long long get_amd_sev_c_bit_pos(void);

#endif /* _X86_AMD_SEV_H_ */
