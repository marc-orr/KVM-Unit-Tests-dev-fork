#!/bin/bash

# set -x
set -e

repo_path=${repo_path:-"${HOME}/code/kvm-unit-tests"}

test_run() {
    # $1 [seabios|uefi]
    # $2 test target file name (with suffix, e.g., msr.flat, or msr.efi)
    # $@ test args
    target="${1}"
    case="${2}"
    shift 2
    args=${*}
    log_path="logs/x86"

    pushd "${repo_path}" > /dev/null || exit 1

    make clean > /dev/null 2>&1 || true
    make distclean > /dev/null 2>&1 || true

    if test "${target}" == "uefi"; then
        ./configure --target-efi
        runner_script="./x86/efi/run"
    elif test "${target}" == "seabios"; then
        ./configure
        runner_script="./x86/run"
    else
        echo "    Unknown target: ${target}"
        exit 2
    fi

    mkdir -p "${log_path}"

    echo "    Building ${case}"
    make -j 40 x86/"${case}" > "${log_path}/${case}.make.${target}.log" 2>&1

    echo "    Running ${case} ${args}"
    "${runner_script}" ./x86/"${case}" ${args} > "${log_path}/${case}.${target}.log" 2>&1

    popd > /dev/null || exit 1
}

test_seabios() {
    case="${1}"
    shift 1
    case="${case}.flat"
    test_run seabios "${case}" ${*}
}

test_uefi() {
    case="${1}"
    shift 1
    case="${case}.efi"
    test_run uefi "${case}" ${*}
}

## apic and eventinj should be tested manually, because they report unexpected
## exception in both Seabios and UEFI, and halt the guest VM, thus halting this
## script
##
## realmode, svm and vmx are not tested because they are not yet converted to PIC
test_cases=(
    "access"
    # "apic -cpu qemu64,+x2apic,+tsc-deadline"
    "asyncpf -m 2048"
    "cet -enable-kvm -m 2048 -cpu host"
    "debug"
    "emulator"
    # "eventinj"
    "hypercall"
    "hyperv_clock -cpu kvm64,hv_time"
    "hyperv_connections -cpu kvm64,hv_vpindex,hv_synic -device hyperv-testdev"
    "hyperv_stimer -cpu kvm64,hv_vpindex,hv_time,hv_synic,hv_stimer -device hyperv-testdev"
    "hyperv_synic -cpu kvm64,hv_vpindex,hv_synic -device hyperv-testdev"
    "idt_test"
    "init"
    "intel-iommu -M q35,kernel-irqchip=split -device intel-iommu,intremap=on,eim=off -device edu"
    "ioapic -cpu qemu64 -machine kernel_irqchip=split"
    "kvmclock_test"
    "memory -cpu max"
    "msr"
    "pcid -cpu qemu64,+pcid,+invpcid"
    "pks -cpu max"
    "pku -cpu max"
    "pmu -cpu max"
    "pmu_lbr -cpu host,migratable=no"
    "rdpru -cpu max"
    # "realmode"
    "rmap_chain"
    "s3"
    "setjmp"
    "sieve"
    "smap -cpu max"
    "smptest"
    # "svm"
    "syscall -cpu Opteron_G1,vendor=AuthenticAMD"
    "tsc -cpu kvm64,+rdtscp"
    "tsc_adjust -cpu max"
    "tsx-ctrl -cpu max"
    "umip -cpu qemu64,+umip"
    "vmexit"
    "vmware_backdoors -machine vmport=on -cpu max"
    # "vmx"
    "xsave -cpu max"
)


preserve_logs() {
    sed -i 's/\$(RM) -r tests logs logs.old efi-tests/\$(RM) -r tests logs.old efi-tests/g' $repo_path/Makefile
}

restore_makefile() {
    pushd "${repo_path}" || exit 1
    git checkout . Makefile
    popd || exit 1
}

{
echo "Preserve 'logs' dir when 'make distclean'"
preserve_logs || true

for tc in "${test_cases[@]}"; do
    echo "Testing ${tc}"
    test_seabios ${tc} || true
    test_uefi ${tc} || true
done

echo "Restore Makefile"
restore_makefile || trues
} > >(ts '[%Y-%m-%d %H:%M:%S]')