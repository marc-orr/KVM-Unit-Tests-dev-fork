/* Startup code and pre-defined data structures */

#include "crt0-efi-x86_64.S"

.section .init
.code64
.text

.globl load_idt
load_idt:
	/* Set IDT runtime address */
	lea boot_idt(%rip), %rax
	mov %rax, idt_descr+2(%rip)

	/* Load IDT */
	lidtq idt_descr(%rip)

	retq
