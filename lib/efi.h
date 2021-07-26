#ifndef _EFI_H_
#define _EFI_H_

/*
 * EFI-related functions in KVM-Unit-Tests. This file's name "efi.h" is in
 * conflict with GNU-EFI library's "efi.h", but KVM-Unit-Tests does not include
 * GNU-EFI headers or links against GNU-EFI.
 */
#include "linux/uefi.h"
#include <elf.h>

efi_status_t _relocate(long ldbase, Elf64_Dyn *dyn, efi_handle_t handle, efi_system_table_t *sys_tab);
efi_status_t efi_get_memory_map(struct efi_boot_memmap *map);
efi_status_t efi_exit_boot_services(void *handle, unsigned long mapkey);
efi_status_t efi_main(efi_handle_t handle, efi_system_table_t *sys_tab);

#endif /* _EFI_H_ */
