#!/bin/bash

filter_uefi_output() {
    # $1 test case base name (no suffix)

    origin_log="${1}.uefi.log"
    output_log="${1}.uefi.filtered.log"

    cat "${origin_log}"                         \
        | grep -v "EFI Internal Shell"          \
        | grep -v "UEFI Interactive Shell"      \
        | grep -v "EDK II"                      \
        | grep -v "Mapping table"               \
        | grep -v "Alias(s)"                    \
        | grep -v "PciRoot"                     \
        | grep -v "Press "                      \
        | grep -v "cr3 = "                      \
        | grep -v "cr4 = "                      \
        > "${output_log}"
}

filter_seabios_output() {
    # $1 test case base name (no suffix)

    origin_log="${1}.seabios.log"
    output_log="${1}.seabios.filtered.log"

    cat "${origin_log}"                         \
        | tr -d '\r'                            \
        | grep -v "cr3 = "                      \
        | grep -v "cr4 = "                      \
        > "${output_log}"
 }

compare_case() {
    # $1 test case base name (no suffix)

    case="${1}"
    filter_uefi_output "${case}"
    filter_seabios_output "${case}"

    seabios_log="${case}.seabios.filtered.log"
    uefi_log="${case}.uefi.filtered.log"

    mkdir -p diff_log
    diff -w "${seabios_log}" "${uefi_log}" > "diff_log/${case}.diff"
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
log_path=${log_path:="test_log/x86"}
log_path="${repo_path}/${log_path}"

pushd "${log_path}" || exit 2

{
for tc in "${test_cases[@]}"; do
    printf "Comparing %20s: " "${tc}"
    compare_case "${tc}"
done
} > >(tee compare_report.txt)

popd || exit 2