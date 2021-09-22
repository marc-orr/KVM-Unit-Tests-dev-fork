#!/bin/bash

set -e
set -x

if (( $# > 2 )); then
    echo "Usage: $0 [since_commit] [output_dir]"
    exit 1
fi

PATCH_VERSION="${PATCH_VERSION:-v1}"

curr_path=$(basename "$PWD")
upstream_path="kvm-unit-tests-for-upstreaming"
local_path="kvm-unit-tests"

if test "${curr_path}" == "${upstream_path}"; then
	patch_path="patches/${PATCH_VERSION}-internal"
	since_commit="origin/master"
    signoff=""
elif test "${curr_path}" == "${local_path}"; then
	patch_path="patches/${PATCH_VERSION}-needs-to-remove-change-id"
	since_commit="upstream/master"
    # Sign-off is done in 'gen-patches-for-upstream.sh' through 'git filter-branch'
    # Update: now sign-off is done manually
    # signoff="--signoff"
    signoff=""
fi

if test "${patch_path}" == ""; then
	echo "Wrong current path ${curr_path}, must be under ${upstream_path} or ${local_path}"
	exit 1
fi

since_commit="${1:-$since_commit}"
output_dir="${2:-$patch_path}"

mkdir -p "${output_dir}"
rm -f "${output_dir}/*.patch"

git format-patch \
    --subject-prefix="kvm-unit-tests PATCH" \
    --cover-letter \
    -${PATCH_VERSION} \
    ${signoff} \
    -o "${output_dir}" \
    "${since_commit}"