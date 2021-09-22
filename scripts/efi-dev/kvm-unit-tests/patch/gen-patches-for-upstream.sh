#!/bin/bash

set -e
set -x

PATCH_VERSION="${PATCH_VERSION:-v1}"

curr_path=$(basename "$PWD")
upstream_path="kvm-unit-tests-for-upstreaming"
local_path="kvm-unit-tests"

if test "${curr_path}" == "${upstream_path}"; then
    git reset --hard origin/master
    # Remove cover letter
    rm -f patches/"${PATCH_VERSION}"-needs-to-remove-change-id/*0000*.patch
    # List all patches to be applied
    ls -1 patches/"${PATCH_VERSION}"-needs-to-remove-change-id/*.patch
    read -p "OK to proceed? Ctrl-C to cancel"
    # Apply patches from Google internal Git repo
    git am patches/"${PATCH_VERSION}"-needs-to-remove-change-id/*.patch
    # Remove 'Change-Id line from every commit message'
    git filter-branch -f --msg-filter \
        "sed -e 's/Change-Id.*//g' | cat -s" -- origin/master..HEAD
    # Sign-off only if it's not already signed-off
    # Not working, use manual sign-off for now
    # git filter-branch -f ---msg-filter \
    #     'grep "Signed-off-by" || git commit --amend -S' -- origin/master..HEAD
    # Regenerate all patches
    # $exp_dir is a CitC path pointing to experimental/users/zixuanwang
    bash "${exp_dir}/scripts/kvm-unit-tests/gen-patches.sh"
    exit 0
elif test "${curr_path}" == "${local_path}"; then
    bash "${exp_dir}/scripts/kvm-unit-tests/gen-patches.sh"
    exit 0
else
    echo "Error: you should run this script under ${upstream_path}"
    exit 1
fi

