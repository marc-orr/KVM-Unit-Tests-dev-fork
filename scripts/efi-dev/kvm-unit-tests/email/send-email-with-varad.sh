#!/bin/bash

patch_path="patches/v2-public"
internal_patch_path="patches/v2-internal"

if ! diff ${patch_path} ${internal_patch_path}; then
    echo "Patches not match, maybe public patches are stale"
    exit 1
fi

if [ ! -d "${patch_path}" ]; then
    echo "Cannot find ${patch_path}"
    exit 1
fi

echo "All patches"
ls -1 "${patch_path}"

echo "You are not ready for PUBLIC emailing, trust me!"
echo "Re-check this script and make sure everything looks fine"
exit 2

git send-email \
    --to "varad.gautam@suse.com" \
    --cc "marcorr@google.com" \
    --cc "baekhw@google.com" \
    --cc "tmroeder@google.com" \
    --cc "erdemaktas@google.com" \
    --cover-letter \
    --suppress-cc=all \
    --validate \
    "${patch_path}"
