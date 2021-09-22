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

echo "You are not ready for INTERNAL emailing, trust me!"
echo "Re-check this script and make sure everything looks fine"
exit 2

send_email() {
    git send-email \
        --to "marcorr@google.com" \
        --to "baekhw@google.com" \
        --to "tmroeder@google.com" \
        --to "erdemaktas@google.com" \
        --cc "zixuanwang@google.com" \
        --cover-letter \
        --suppress-cc=all \
        --validate \
        $* \
        "${patch_path}"
}


echo "Dry-run (quiet):"
send_email --dry-run --quiet

echo "Dry-run (verbose):"
send_email --dry-run

echo ""
read -p "Dry-run looks good? Ctrl-C to cancel"

echo ""
read -p "Ready to really send it? Ctrl-C to cancel"

echo "Sending email:"
send_email