#!/bin/bash

# set -x
set -e

repo_path=${repo_path:-"${HOME}/code/kvm-unit-tests"}

usage() {
    echo "${0}: seabios|uefi test_executable log_file [test_args...]"
}

if ! [ $# -ge 3 ]; then
    usage
    exit 1
fi

test_run() {
    # $1 seabios|uefi
    # $2 test executable file name (with suffix, e.g., msr.flat, or msr.efi)
    # $3 log file
    # $@ test args
    platform="${1}"
    case="${2}"
    log_file="${3}"
    shift 3
    args=${*}

    pushd "${repo_path}" > /dev/null || exit 1

    if test "${platform}" == "uefi"; then
        runner_script="./x86/efi/run"
    elif test "${platform}" == "seabios"; then
        runner_script="./x86/run"
    else
        echo "    Unknown platform: ${platform}"
        exit 2
    fi

    echo "    Running ${case} ${args} >${log_file}"
    "${runner_script}" ./x86/"${case}" ${args} >"${log_file}" 2>&1 || true

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

case "${1}" in
    uefi)
        shift 1
        test_uefi ${*}
        ;;
    seabios)
        shift 1
        test_seabios ${*}
        ;;
    *)
        usage
        exit 1
        ;;
esac