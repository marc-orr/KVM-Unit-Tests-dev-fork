#ifndef _X86_ASM_SETUP_H_
#define _X86_ASM_SETUP_H_

#ifdef TARGET_EFI
#include "x86/apic.h"
#include "x86/smp.h"

void setup_efi(void);
#endif /* TARGET_EFI */

#endif /* _X86_ASM_SETUP_H_ */
