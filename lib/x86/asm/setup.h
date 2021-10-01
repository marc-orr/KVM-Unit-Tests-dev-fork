#ifndef _X86_ASM_SETUP_H_
#define _X86_ASM_SETUP_H_

#ifdef __x86_64__
unsigned long setup_tss(void);
#endif /* __x86_64__ */

#endif /* _X86_ASM_SETUP_H_ */
