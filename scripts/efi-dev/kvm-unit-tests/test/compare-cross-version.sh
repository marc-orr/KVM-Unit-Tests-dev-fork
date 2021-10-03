#! /bin/bash

usage() {
    echo "${0} log_dir1 log_dir2 out_dir"
}

if [ $# -ne 3 ]; then
    usage
    exit 1
fi

log_dir1="${1}/x86"
log_dir2="${2}/x86"
out_dir="${3}"

mkdir -p "${out_dir}"

tests=$(ls "${log_dir1}" -1 | grep "\.log" | grep "filtered" | grep -v "make" | tr '\n' '\0' | xargs -0 -n 1 basename)
tests=(${tests})

{
for ts in "${tests[@]}"; do
    printf "Comparing: %40s" "$ts"
    diff -w "${log_dir1}/${ts}" "${log_dir2}/${ts}" > "${out_dir}/${ts}.diff"
    echo ": diff result $?"
done
} > >(tee "${out_dir}/compare-report.txt")