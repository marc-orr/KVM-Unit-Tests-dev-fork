#!/bin/bash

# set -x
set -e

repo_path=${repo_path:-"${HOME}/code/kvm-unit-tests"}
repo_path="$(realpath "${repo_path}")"
curr_path=$(realpath "$(dirname "$0")")
ovmf_path=${ovmf_path:-"/usr/share/edk2-ovmf/x64/OVMF.fd"}

## apic and eventinj should be tested manually, because they report unexpected
## exception in both Seabios and UEFI, and halt the guest VM, thus halting this
## script
##
## realmode, svm and vmx are not tested because they are not yet converted to PIC
declare -A test_cases=(
    [access]=""
    [apic]="-cpu qemu64,+x2apic,+tsc-deadline"
    [asyncpf]="-m 2048"
    [cet]="-enable-kvm -m 2048 -cpu host"
    [debug]=""
    [emulator]=""
    # [eventinj=""
    [hypercall]=""
    [hyperv_clock]="-cpu kvm64,hv_time"
    [hyperv_connections]="-cpu kvm64,hv_vpindex,hv_synic -device hyperv-testdev"
    [hyperv_stimer]="-cpu kvm64,hv_vpindex,hv_time,hv_synic,hv_stimer -device hyperv-testdev"
    [hyperv_synic]="-cpu kvm64,hv_vpindex,hv_synic -device hyperv-testdev"
    [idt_test]=""
    [init]=""
    [intel-iommu]="-M q35,kernel-irqchip=split -device intel-iommu,intremap=on,eim=off -device edu"
    [ioapic]="-cpu qemu64 -machine kernel_irqchip=split"
    [kvmclock_test]=""
    [memory]="-cpu max"
    [msr]=""
    [pcid]="-cpu qemu64,+pcid,+invpcid"
    [pks]="-cpu max"
    [pku]="-cpu max"
    [pmu]="-cpu max"
    [pmu_lbr]="-cpu host,migratable=no"
    [rdpru]="-cpu max"
    # [realmode]=""
    [rmap_chain]=""
    [s3]=""
    [setjmp]=""
    [sieve]=""
    [smap]="-cpu max"
    [smptest]=""
    # [svm]=""
    [syscall]="-cpu Opteron_G1,vendor=AuthenticAMD"
    [tsc]="-cpu kvm64,+rdtscp"
    [tsc_adjust]="-cpu max"
    [tsx-ctrl]="-cpu max"
    [umip]="-cpu qemu64,+umip"
    [vmexit]=""
    [vmware_backdoors]="-machine vmport=on -cpu max"
    # [vmx]=""
    [xsave]="-cpu max"
)

pushd "${repo_path}" || exit 1

echo "Generating Makefile to run all test cases"
log_root_path="test_logs"
mkdir -p "${log_root_path}"

pushd "${log_root_path}" || exit 1

rm -f Makefile
runner_script="${curr_path}/test-one-case.sh"

# Default log path under '$repo_path/logs'
log_case_path="x86"
mkdir -p "${log_case_path}"

cat << EOF >>Makefile
.DEFAULT_GOAL:=all

runner_script="${runner_script}"
repo_path="${repo_path}"
ovmf_path="${ovmf_path}"

all: all_uefi all_seabios

.PHONY: all_uefi
all_uefi:
	\$(MAKE) configure_uefi
	\$(MAKE) test_all_uefi

.PHONY: all_seabios
all_seabios:
	\$(MAKE) configure_seabios
	\$(MAKE) test_all_seabios

.PHONY: configure_uefi
configure_uefi:
	@ echo "Configuring all UEFI test cases"
	@ cd .. && (make distclean || true)
	@ cd .. && ./configure --target-efi && make -j 10
	@ mkdir -p "${log_case_path}"

.PHONY: configure_seabios
configure_seabios:
	@ echo "Configuring all SeaBIOS test cases"
	@ cd .. && (make distclean || true)
	@ cd .. && ./configure && make -j 10
	@ mkdir -p "${log_case_path}"

../x86/%:
	@ echo "Making $@"
	@ cd .. && make x86/\$*
EOF

# Generate tests
declare -A target=(
	[uefi]="efi"
	[seabios]="flat"
)
for platform in "${!target[@]}"; do
    all_cases=""
    for tc in "${!test_cases[@]}"; do
        target_log="${log_case_path}/${tc}.${platform}.log"
        all_cases+=" ${target_log}"

cat <<EOF >>Makefile

${target_log}: ../x86/${tc}.${target[${platform}]}
	EFI_UEFI=\${ovmf_path} repo_path=\${repo_path} \\
	bash \${runner_script} ${platform} ${tc} ${log_root_path}/\$@ ${test_cases[${tc}]}
EOF

    done

cat <<EOF >>Makefile

test_all_${platform}: ${all_cases}
EOF

done

cat <<EOF >>Makefile

.PHONY: clean
clean:
	rm -rf "${log_case_path}"
EOF

# Test all cases, pmu requires single thread to be stable
make all_uefi -j 4
rm -f x86/pmu.uefi.*
make test_all_uefi -j 1

make all_seabios -j 4
rm -f x86/pmu.seabios.*
make test_all_seabios -j 1


popd || exit 1

popd || exit 1