#!/bin/bash

filter_uefi_output() {
    # $1 test case base name (no suffix)

    origin_log="${1}.efi.uefi.log"
    output_log="${1}.efi.uefi.filtered.log"

    cat "${origin_log}"                     \
        | grep -v "EFI Internal Shell"      \
        | grep -v "UEFI Interactive Shell"  \
        | grep -v "EDK II"                  \
        | grep -v "Mapping table"           \
        | grep -v "Alias(s)"                \
        | grep -v "PciRoot"                 \
        | grep -v "Press "                  \
        > "${output_log}"
}

compare_case() {
    # $1 test case base name (no suffix)

    case="${1}"
    filter_uefi_output "${case}"

    seabios_log="${case}.flat.seabios.log"
    uefi_log="${case}.efi.uefi.filtered.log"

    mkdir -p diff_log
    diff "${seabios_log}" "${uefi_log}" > "diff_log/${case}.diff"
    echo "diff result: $?"
}

test_cases=(
    "access"
    # "apic"
    "asyncpf"
    "cet"
    "debug"
    "emulator"
    # "eventinj"
    "hypercall"
    "hyperv_clock"
    "hyperv_connections"
    "hyperv_stimer"
    "hyperv_synic"
    "idt_test"
    "init"
    "intel-iommu"
    "ioapic"
    "kvmclock_test"
    "memory"
    "msr"
    "pcid"
    "pks"
    "pku"
    "pmu"
    "pmu_lbr"
    "rdpru"
    # "realmode"
    "rmap_chain"
    "s3"
    "setjmp"
    "sieve"
    "smap"
    "smptest"
    # "svm"
    "syscall"
    "tsc"
    "tsc_adjust"
    "tsx-ctrl"
    "umip"
    "vmexit"
    "vmware_backdoors"
    # "vmx"
    "xsave"
)

repo_path=${repo_path:-"${HOME}/code/kvm-unit-tests"}
log_path="${repo_path}/logs/x86"

{
pushd "${log_path}" || exit 2

for tc in "${test_cases[@]}"; do
    echo -e -n "Comparing ${tc}:\t"
    compare_case "${tc}"
done

popd || exit 2
} > >(ts '[%Y-%m-%d %H:%M:%S]')