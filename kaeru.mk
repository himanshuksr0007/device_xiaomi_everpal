#
# SPDX-FileCopyrightText: The Everpal Project
# SPDX-License-Identifier: Apache-2.0
#
# Kaeru bootloader for evergo
#
# Ships the prebuilt Kaeru LK image in the ROM
# (/system/etc/kaeru/Kaeru.bin) for convenience. It does NOT
# flash the bootloader (TARGET_NO_BOOTLOADER := true, lk is not in
# AB_OTA_PARTITIONS), so manual flashing is still required.
#
# Correct everpal targets are lk + lk2 (raw, see init/fstab.mt6833).
# Do NOT use lk_a/lk_b here (that is fogorow-style A/B slots).
# Flash via prebuilts/kaeru/flash-kaeru.sh (guarded, lk/lk2 only):
#   ./flash-kaeru.sh
# First install without fastboot needs BROM mode (mtkclient/SP Flash).
# Requires seccfg unlocked first, otherwise risk of brick.
# See prebuilts/kaeru/README.md and R0rt1z2/kaeru wiki.
#
# Features (DT level):
# - prebuilt in every build + ro.kaeru.version/target props
# - guarded flash script: sha256/size check, variant check,
#   YES confirm, writes only lk/lk2 (never preloader/seccfg/nvram/tee)
# - docs for install/upgrade/rollback in prebuilts/kaeru/README.md
#
# Kaeru fixed4 targets: evergo-6eb0c11d1-20230516102240
# Prebuilt claim: all 4 MTK bypasses, bit-exact Stage1, stock certs intact.
# No payload-level behavior is claimed – anti-brick here covers the flash
# process only (script gates). Source port remains future work.
# NOTE: evergo only for now. evergreen/opal variants to be added later.
#

# Copy Kaeru binary to build output
PRODUCT_COPY_FILES += \
    device/xiaomi/everpal/prebuilts/kaeru/Kaeru.bin:$(TARGET_COPY_OUT_SYSTEM)/etc/kaeru/Kaeru.bin

# Kaeru version info for build fingerprint
PRODUCT_SYSTEM_PROPERTIES += \
    ro.kaeru.version=fixed4 \
    ro.kaeru.target=evergo-6eb0c11d1-20230516102240
