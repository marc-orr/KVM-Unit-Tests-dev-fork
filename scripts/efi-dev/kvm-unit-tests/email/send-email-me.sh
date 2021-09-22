#!/bin/bash

patch_dir="patches/v2-public"

if [ ! -d "${patch_dir}" ]; then
    echo "Cannot find ${patch_dir}"
    exit 1
fi

echo "All patches"
ls -1 "${patch_dir}"

send_email() {
    git send-email \
        --to "zxwang42@gmail.com" \
        --suppress-cc=all \
        --cover-letter \
        --validate \
        $* \
        "${patch_dir}"
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