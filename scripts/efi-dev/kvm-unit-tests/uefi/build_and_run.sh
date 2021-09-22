#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Usage: $0 test_case [args]"
    echo "Example: $0 syscall -cpu Opteron_G1,vendor=AuthenticAMD"
    exit 1
fi

SRC_PATH=${SRC_PATH:-~/code/kvm-unit-tests}

tn="$1"
shift 1

pushd "${SRC_PATH}" || exit 2
make -j x86/"${tn}".efi
mkdir -p logs/x86
objdump -r -d -t x86/"${tn}".so >logs/x86/"${tn}".so.S
./x86/efi/run x86/"${tn}".efi "$@"
popd || exit 2