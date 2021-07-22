# Build KVM-Unit-Tests with GNU-EFI

## Introduction

This dir provides code to build KVM-Unit-Tests with GNU-EFI and run the test
cases with QEMU and UEFI.

### Install dependencies

The following dependencies should be installed:

- [GNU-EFI](https://sourceforge.net/projects/gnu-efi): to build test cases as
  EFI applications
- [UEFI firmware](https://github.com/tianocore/edk2): to run test cases in QEMU

### Build with GNU-EFI

To build with GNU-EFI, do:

    ./configure --target-efi
    make

Building UEFI tests requires the
[GNU-EFI](https://sourceforge.net/projects/gnu-efi) library: the Makefile
searches GNU-EFI headers under `/usr/include/efi` and static libraries under
`/usr/lib/` by default. These paths can be overridden by `./configure` flags
`efi-include-path` and `efi-libs-path`.

### Run test cases with UEFI

To run a test case with UEFI:

    ./x86/efi/run ./x86/msr.efi

By default the runner script loads the UEFI firmware `/usr/share/ovmf/OVMF.fd`;
please install UEFI firmware to this path, or specify the correct path through
the env variable `EFI_UEFI`:

    EFI_UEFI=/path/to/OVMF.fd ./x86/efi/run ./x86/msr.efi

## Code structure

### Code from GNU-EFI

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

### Startup code for KVM-Unit-Tests in UEFI

This dir also contains KVM-Unit-Tests startup code in UEFI:
   - efistart64.S: startup code for KVM-Unit-Tests in UEFI
