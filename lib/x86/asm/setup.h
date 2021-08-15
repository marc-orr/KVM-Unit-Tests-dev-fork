#ifndef _X86_ASM_SETUP_H_
#define _X86_ASM_SETUP_H_

#ifdef TARGET_EFI
#include "x86/acpi.h"
#include "x86/apic.h"
#include "x86/processor.h"
#include "x86/smp.h"
#include "asm/page.h"
#ifdef CONFIG_AMD_SEV
#include "x86/amd_sev.h"
#endif /* CONFIG_AMD_SEV */

#ifdef ALIGN
#undef ALIGN
#endif
#include <efi.h>
#include <efilib.h>

/* efi_bootinfo_t: stores EFI-related machine info retrieved by
 * setup_efi_pre_boot(), and is then used by setup_efi(). setup_efi() cannot
 * retrieve this info as it is called after ExitBootServices and thus some EFI
 * resources are not available.
 */
typedef struct {
	phys_addr_t free_mem_start;
	phys_addr_t free_mem_size;
	struct rsdp_descriptor *rsdp;
} efi_bootinfo_t;

void setup_efi_bootinfo(efi_bootinfo_t *efi_bootinfo);
void setup_efi(efi_bootinfo_t *efi_bootinfo);
EFI_STATUS setup_efi_pre_boot(UINTN *mapkey, efi_bootinfo_t *efi_bootinfo);
void setup_5level_page_table(void);
#endif /* TARGET_EFI */

#endif /* _X86_ASM_SETUP_H_ */
