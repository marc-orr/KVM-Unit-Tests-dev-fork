#!/bin/bash

set -x
set -e

export PATCH_VERSION="v2"

pushd ~/code/kvm-unit-tests-for-upstreaming
rm -rf "patches/${PATCH_VERSION}-need*"
rm -rf "patches/${PATCH_VERSION}-internal"
popd

pushd ~/code/kvm-unit-tests
bash $exp_dir/scripts/kvm-unit-tests/gen-patches-for-upstream.sh
popd

pushd ~/code/kvm-unit-tests-for-upstreaming
bash $exp_dir/scripts/kvm-unit-tests/gen-patches-for-upstream.sh
popd