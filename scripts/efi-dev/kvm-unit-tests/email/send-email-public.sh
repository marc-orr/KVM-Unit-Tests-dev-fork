#!/bin/bash

set -x
set -e

patch_path="patches/v2-public"
internal_patch_path="patches/v2-internal"

if (($# != 0)); then
    echo "Error: do not provide any argument!"
    exit 1
fi

if [ ! -d "${patch_path}" ]; then
    echo "Cannot find ${patch_path}"
    exit 1
fi

if [ ! -d "${internal_patch_path}" ]; then
    echo "Cannot find ${internal_patch_path}"
    exit 1
fi

if ! diff ${patch_path} ${internal_patch_path}; then
    echo "Patches not match, maybe public patches are stale"
    exit 1
fi

echo "All patches"
ls -1 "${patch_path}"

echo "Patch dir: ${patch_path}"

echo "You are not ready for PUBLIC emailing, trust me!"
# exit 2

echo "Are you serious to send it publically (Ctrl-C to cancel)?"
read

echo "Consider '--suppress-cc=all' !"
# exit 2

echo "Check patch version, is it correct?"
# exit 2

## Emails suggested by Marc
## KVM:
## - kvm@vger.kernel.org
## - pbonzini@redhat.com
## - drjones@redhat.com
#
## Google
## - marcorr@google.com
## - baekhw@google.com
## - tmroeder@google.com
## - erdemaktas@google.com
## - rientjes@google.com
## - seanjc@google.com
#
## AMD
## - brijesh.singh@amd.com
## - Thomas.Lendacky@amd.com
#
## cc's on Varad's email thread (out of politeness):
## - varad.gautam@suse.com
## - jroedel@suse.de
## - bp@suse.de

send_email() {
    git send-email \
        --to "kvm@vger.kernel.org" \
        --to "pbonzini@redhat.com" \
        --to "drjones@redhat.com" \
        --cc "marcorr@google.com" \
        --cc "baekhw@google.com" \
        --cc "tmroeder@google.com" \
        --cc "erdemaktas@google.com" \
        --cc "rientjes@google.com" \
        --cc "seanjc@google.com" \
        --cc "brijesh.singh@amd.com" \
        --cc "Thomas.Lendacky@amd.com" \
        --cc "varad.gautam@suse.com" \
        --cc "jroedel@suse.de" \
        --cc "bp@suse.de" \
        --cover-letter \
        --suppress-cc=all \
        --validate \
        $* \
        "${patch_path}"
}

echo "Dry-run (verbose):"
send_email --dry-run

echo ""
read -p "Dry-run looks good? Ctrl-C to cancel"

echo ""
read -p "Ready to really send it? Ctrl-C to cancel"

echo ""
read -p "One more check, send it? Ctrl-C to cancel"

echo "Sending email:"
send_email
