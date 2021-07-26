/*
 * efi_main() and supporting functions to wrap tests into EFI apps
 *
 * Copyright (c) 2021, Google Inc, Zixuan Wang
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <libcflat.h>
#include <asm/setup.h>

#ifdef ALIGN
#undef ALIGN
#endif
#include <efi.h>
#include <efilib.h>

/* From lib/argv.c */
extern int __argc, __envc;
extern char *__argv[100];
extern char *__environ[200];

extern int main(int argc, char **argv, char **envp);

EFI_STATUS efi_main(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *systab);

EFI_STATUS efi_main(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *systab)
{
	int ret;
	EFI_STATUS status;
	UINTN mapkey = 0;
	efi_bootinfo_t efi_bootinfo;

	InitializeLib(image_handle, systab);

	setup_efi_bootinfo(&efi_bootinfo);
	status = setup_efi_pre_boot(&mapkey, &efi_bootinfo);
	if (EFI_ERROR(status)) {
		printf("Failed to set up before ExitBootServices, exiting.\n");
		return status;
	}

	status = uefi_call_wrapper(BS->ExitBootServices, 2, image_handle, mapkey);
	if (EFI_ERROR(status)) {
		printf("Failed to exit boot services\n");
		return status;
	}

	setup_efi(&efi_bootinfo);
	ret = main(__argc, __argv, __environ);

	/* Shutdown the Guest VM */
	uefi_call_wrapper(RT->ResetSystem, 4, EfiResetShutdown, ret, 0, NULL);

	/* Unreachable */
	return EFI_UNSUPPORTED;
}
