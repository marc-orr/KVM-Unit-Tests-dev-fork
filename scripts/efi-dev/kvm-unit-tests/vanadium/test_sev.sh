#!/bin/bash

set -e

HOST=${HOST}
TEST_PATH=${TEST_PATH:-/export/hda3/kvm-unit-tests/test/}
SRC_PATH=${SRC_PATH:-~/code/kvm-unit-tests}

if test "${HOST}" == ""; then
  echo "ERROR: please specify the 'HOST' env variable"
  exit 1
fi

function scp-inbn() {
  scp "$1" root@${HOST}:"${TEST_PATH}"
}

function fcp-inbn() {
  scp root@${HOST}:"${TEST_PATH}/${1}" .
}

function ssh-inbn() {
  ssh root@${HOST} $@
}

# $1 test case name, without suffix
test="${1}"
shift 1

pushd "${SRC_PATH}"
echo "Build x86/${test}.img"
if make -j x86/${test}.img; then
  mkdir -p logs

  # Disassembly the target for debugging purpose
  # echo "Disasm to logs/${test}.so.S"
  # objdump -r -d -t x86/${test}.so > logs/${test}.so.S

  echo "Send x86/${test}.img"
  scp-inbn x86/${test}.img

  echo "Run ${test} on dev machine"
  ssh-inbn "cd ${TEST_PATH} && ./run.sh --sev ${@} -d ${test}.img" 2>&1 | tee logs/${test}.${HOST}.log
  cat logs/${test}.${HOST}.log | grep -i "kernel_ttys0" > logs/${test}.${HOST}.kernel_ttys0.log

  echo ""
  echo "Output"
  echo ""
  cat logs/${test}.${HOST}.kernel_ttys0.log
fi
popd

