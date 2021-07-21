# EFI Startup Code and Linker Script

This dir contains a linker script copied from
[GNU-EFI](https://sourceforge.net/projects/gnu-efi/):
   - elf_x86_64_efi.lds: linker script to build an EFI application

The following pre-compiled object files ship with GNU-EFI library, and are used
to build KVM-Unit-Tests with GNU-EFI:
   - crt0-efi-x86_64.o: startup code of an EFI application
   - libgnuefi.a: position independent x86_64 ELF shared object relocator

EFI application binaries should be relocatable as UEFI loads binaries to dynamic
runtime addresses. To build such relocatable binaries, GNU-EFI utilizes the
above-mentioned files in its build process:

   1. build an ELF shared object and link it using linker script
      `elf_x86_64_efi.lds` to organize the sections in a way UEFI recognizes
   2. link the shared object with self-relocator `libgnuefi.a` that applies
      dynamic relocations that may be present in the shared object
   3. link the entry point code `crt0-efi-x86_64.o` that invokes self-relocator
      and then jumps to EFI application's `efi_main()` function
   4. convert the shared object to an EFI binary

More details can be found in `GNU-EFI/README.gnuefi`, section "Building
Relocatable Binaries".
