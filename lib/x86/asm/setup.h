#ifndef _X86_ASM_SETUP_H_
#define _X86_ASM_SETUP_H_

#ifdef __x86_64__
unsigned long setup_tss(void);
#endif /* __x86_64__ */

#ifdef TARGET_EFI
#include "x86/apic.h"
#include "x86/smp.h"
#include "efi.h"

efi_status_t setup_efi(efi_bootinfo_t *efi_bootinfo);
#endif /* TARGET_EFI */

#endif /* _X86_ASM_SETUP_H_ */
