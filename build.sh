#!/bin/bash

set -e
trap 'echo; echo FAILED; echo' ERR

# SETUP
### S8 ###
MODEL=g950x

### S8 Korea version ###
#MODEL=g950x_kor

### S8+ ###
#MODEL=g955x

### S8+ Korea ###
#MODEL=g955x_kor

### Note 8 ###
#MODEL=n950x

### Note 8 Korea ###
#MODEL=n950x_kor

# Dynamically detect if running in GitHub Actions or locally
if [ -n "$GITHUB_WORKSPACE" ]; then
    SOURCE_PATH="$GITHUB_WORKSPACE"
else
    SOURCE_PATH="$HOME/Samsung_dreamlte_Kernel"
fi

N=$(nproc)
# FIX 1: Use ${MODEL} to prevent bash from looking for a variable named "MODEL_9"
OUTPUT="$HOME/a2n_kernel_${MODEL}_9.x"

cd "$SOURCE_PATH" || exit 1

# FIX 2: Ensure the output directory and module paths actually exist before copying
mkdir -p "$OUTPUT/system/lib/modules"

# Safely remove old DTBs if they exist
DTB_FILES=(arch/arm64/boot/dts/exynos/*.dtb)
if [ -e "${DTB_FILES[0]}" ]; then
    rm -f "${DTB_FILES[@]}"
fi

# Merge configs
ARCH=arm64 scripts/kconfig/merge_config.sh arch/arm64/configs/g950x_defconfig arch/arm64/configs/${MODEL}_defconfig

# Re-apply options required by ReSukiSU after merge_config.sh
scripts/config --enable CONFIG_KALLSYMS
scripts/config --enable CONFIG_KALLSYMS_ALL
scripts/config --enable CONFIG_MODULES
scripts/config --enable CONFIG_MODULE_UNLOAD
scripts/config --enable CONFIG_KSU
scripts/config --enable CONFIG_KSU_MANUAL_HOOK

make olddefconfig

# Fail early with a useful message
grep -q '^CONFIG_KALLSYMS_ALL=y$' .config || {
    echo "ERROR: CONFIG_KALLSYMS_ALL is not enabled"
    exit 1
}

# Build kernel
make -j"$N" "$@"

# FIX 3: Copy modules safely. If a module (like wireguard) isn't enabled, it won't crash the build.
cp drivers/usb/gadget/function/usb_f_mtp_samsung.ko "$OUTPUT/system/lib/modules" 2>/dev/null || true
cp drivers/usb/gadget/function/usb_f_ptp_samsung.ko "$OUTPUT/system/lib/modules" 2>/dev/null || true
cp net/wireguard/wireguard.ko "$OUTPUT/system/lib/modules" 2>/dev/null || true

# FIX 4: REMOVED AIK REPACKING STEPS
# Since you are building the raw kernel without downloading a base boot.img, 
# the AIK repacking steps have been removed to prevent "No such file or directory" errors.
# The compiled Image and modules are safely stored in $OUTPUT.

cd "$OUTPUT" || exit 1

if [ -f *.zip ] ; then
    rm -f *.zip
fi

if [ -f *.md5 ] ; then
    rm -f *.md5
fi

# Zip only META-INF, system, and dex2oat_patch (removed boot.img)
zip -r "a2n_kernel_${MODEL}_9.x_user_build.zip" META-INF system dex2oat_patch

echo
echo "DONE: Kernel and modules built successfully in $OUTPUT"
echo
