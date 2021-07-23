/* Startup code and pre-defined data structures */

#include "apic-defs.h"
#include "asm-generic/page.h"
#include "crt0-efi-x86_64.S"

.globl boot_idt
.globl idt_descr
.globl tss_descr
.globl gdt64_desc
.globl ring0stacksize

max_cpus = MAX_TEST_CPUS
ring0stacksize = PAGE_SIZE

.bss

.globl ring0stacktop
	. = . + ring0stacksize * max_cpus
	.align 16
ring0stacktop:

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

gdt64_desc:
	.word gdt64_end - gdt64 - 1
	.quad 0 /* To be filled with runtime addr of gdt64(%rip) */

.globl gdt64
gdt64:
	.quad 0
	.quad 0x00af9b000000ffff /* 64-bit code segment */
	.quad 0x00cf93000000ffff /* 32/64-bit data segment */
	.quad 0x00af1b000000ffff /* 64-bit code segment, not present */
	.quad 0x00cf9b000000ffff /* 32-bit code segment */
	.quad 0x008f9b000000FFFF /* 16-bit code segment */
	.quad 0x008f93000000FFFF /* 16-bit data segment */
	.quad 0x00cffb000000ffff /* 32-bit code segment (user) */
	.quad 0x00cff3000000ffff /* 32/64-bit data segment (user) */
	.quad 0x00affb000000ffff /* 64-bit code segment (user) */

	.quad 0			 /* 6 spare selectors */
	.quad 0
	.quad 0
	.quad 0
	.quad 0
	.quad 0

tss_descr:
	.rept max_cpus
	.quad 0x000089000000ffff /* 64-bit avail tss */
	.quad 0                  /* tss high addr */
	.endr
gdt64_end:

.globl tss
tss:
	.rept max_cpus
	.long 0
	.quad 0
	.quad 0, 0
	.quad 0, 0, 0, 0, 0, 0, 0, 0
	.long 0, 0, 0
	.endr
tss_end:

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

.globl load_gdt_tss
load_gdt_tss:
	/* Set GDT runtime address */
	lea gdt64(%rip), %rax
	mov %rax, gdt64_desc+2(%rip)

	/* Load GDT */
	lgdt gdt64_desc(%rip)

	/* Load TSS */
	mov %rdi, %rax
	ltr %ax

	/* Update data segments */
	mov $0x10, %ax /* 3rd entry in gdt64: 32/64-bit data segment */
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs
	mov %ax, %ss

	/*
	 * Update the code segment by putting it on the stack before the return
	 * address, then doing a far return: this will use the new code segment
	 * along with the address.
	 */
	popq %rdi
	pushq $0x08 /* 2nd entry in gdt64: 64-bit code segment */
	pushq %rdi
	lretq
