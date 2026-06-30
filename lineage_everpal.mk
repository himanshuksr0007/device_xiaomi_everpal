#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/xiaomi/everpal/device.mk)

# Dolby Audio
# Set to false to disable Dolby Audio support at build time
INCLUDE_DOLBY_AUDIO := true

# BCR
# Set to false to disable BCR support at build time
WITH_GOKU_BCR := true

# InstallerX
# Set to false to disable InstallerX and keep the default AOSP PackageInstaller
WITH_INSTALLER_X := true


TARGET_ENABLE_BLUR := false
TARGET_FACE_UNLOCK_SUPPORTED := true
SYSTEM_OPTIMIZE_JAVA := true
TARGET_BOOT_ANIMATION_RES := 1080
SYSTEMUI_OPTIMIZE_JAVA := true
TARGET_SUPPORTS_QUICK_TAP := true

# Inherit some common Lineage stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Device identifier. This must come after all inclusions
PRODUCT_NAME := lineage_everpal
PRODUCT_DEVICE := everpal
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := everpal

# Build info
PRODUCT_GMS_CLIENTID_BASE := android-xiaomi
