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

	InitializeLib(image_handle, systab);

	setup_efi();
	ret = main(__argc, __argv, __environ);

	/* Shutdown the Guest VM */
	uefi_call_wrapper(RT->ResetSystem, 4, EfiResetShutdown, ret, 0, NULL);

	/* Unreachable */
	return EFI_UNSUPPORTED;
}
