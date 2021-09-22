#!/bin/bash

UEFI_SRC_PATH=${UEFI_SRC_PATH:-~/code/kvm-unit-tests}
SEABIOS_SRC_PATH=${SEABIOS_SRC_PATH:-~/code/kvm-unit-tests-upstream}

if [ $# -eq 0 ]; then
    echo "Usage: $0 test_case [args]"
    echo "Example: $0 syscall -cpu Opteron_G1,vendor=AuthenticAMD"
    echo "Env vars:"
    echo "    UEFI_SRC_PATH:    path to a KVM-Unit-Tests repo, configured with UEFI support"
    echo "    SEABIOS_SRC_PATH: path to a KVM-Unit-Tests repo, configured with SeaBIOS support"
    exit 1
fi

# $1 testcase base name, e.g. 'msr', not 'msr.efi'
tn="$1"
shift 1

tmux_session_name=kvm-test-$tn

tmux set-option remain-on-exit on

tmux start-server
tmux new-session -d -s "$tmux_session_name"
# UEFI testing
tmux send-keys -t "$tmux_session_name" "cd ${UEFI_SRC_PATH} && make -j x86/$tn.efi && x86/efi/run $tn $*" Enter
# Seabios testing
tmux splitw -h -p 50
tmux send-keys -t "$tmux_session_name" "cd ${SEABIOS_SRC_PATH} && make -j x86/$tn.flat && ./x86-run x86/$tn.flat $*" Enter
tmux -2 attach-session -d