/* Startup code and pre-defined data structures */

#include "crt0-efi-x86_64.S"

.globl boot_idt
.globl idt_descr

.data

boot_idt:
	.rept 256
	.quad 0
	.quad 0
	.endr
end_boot_idt:

idt_descr:
	.word end_boot_idt - boot_idt - 1
	.quad 0 /* To be filled with runtime addr of boot_idt(%rip) */

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
