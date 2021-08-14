#! /bin/bash

set -e

if [ $# -ne 1 ]; then
	echo "Usage: $0 TEST_CASE"
	echo "Exsmple: $0 msr.efi"
	exit 1
fi

MTOOLS="${MTOOLS:-mtools}"
MTOOLS="$(readlink -f "$(which "${MTOOLS}")")"

if ! test -f "${MTOOLS}"; then
	echo "Cannot find ${MTOOLS}, Please install 'mtools' package first"
	exit 1
fi

MTOOLS_PATH="$(dirname "${MTOOLS}")"
MFORMAT="${MTOOLS_PATH}/mformat"
MMD="${MTOOLS_PATH}/mmd"
MCOPY="${MTOOLS_PATH}/mcopy"

efi="${1}"
# Base name without suffix
base="${efi%.*}"
img="${base}.img"

mkdir -p "${base}"
cp "${efi}" "${base}/BOOTX64.EFI"

dd if=/dev/zero of="${img}" bs=1k count=1440
"${MFORMAT}" -i "${img}" -f 1440 ::
"${MMD}" -i "${img}" ::/EFI
"${MMD}" -i "${img}" ::/EFI/BOOT
"${MCOPY}" -i "${img}" "${base}/BOOTX64.EFI" ::/EFI/BOOT

rm -rf "${base}"

echo "Disk image generated: ${img}"
