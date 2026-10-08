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
# Correct evergo targets are lk_a + lk_b (A/B bootloader slots,
# same as fogorow). Do NOT use bare lk/lk2 names.
# Flash via prebuilts/kaeru/flash-kaeru.sh (guarded, lk_a/lk_b only):
#   ./flash-kaeru.sh
# First install without fastboot needs BROM mode (mtkclient/SP Flash).
# Requires seccfg unlocked first, otherwise risk of brick.
# See R0rt1z2/kaeru wiki for seccfg/unlock background.
#
# Features (DT level):
# - prebuilt in every build + ro.kaeru.version/target props
# - guarded flash script: sha256/size check, unlocked-state preflight,
#   variant check, YES confirm,
#   writes only lk_a/lk_b (never preloader/seccfg/nvram/tee)
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
