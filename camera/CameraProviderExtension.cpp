/*
 * Copyright (C) 2024 LibreMobileOS Foundation
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "CameraProviderExtension.h"

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <fstream>
#include <string>

#define LOG_TAG "TorchExtEverpal"
#include <log/log.h>

// ---------------------------------------------------------------------------

static const std::string kSysfsTorch = "/sys/devices/platform/flashlights_mt6360/torch_brightness";
static const char* kFlashDev = "/dev/flashlight";

static const int32_t kMaxLevel = 13;
static const int32_t kDefaultLevel = 6;

// ---------------------------------------------------------------------------

struct flashlight_user_arg {
    int type_id;
    int ct_id;
    int arg;
};

#ifndef FLASHLIGHT_MAGIC
#define FLASHLIGHT_MAGIC 'S'
#endif

#define FLASH_IOC_SET_TIME_OUT_TIME_MS _IOR(FLASHLIGHT_MAGIC, 100, int)
#define FLASH_IOC_SET_DUTY _IOR(FLASHLIGHT_MAGIC, 110, int)
#define FLASH_IOC_SET_ONOFF _IOR(FLASHLIGHT_MAGIC, 115, int)
#define FLASH_IOC_GET_MAX_TORCH_DUTY _IOWR(FLASHLIGHT_MAGIC, 230, int)
#define FLASH_IOC_GET_CURRENT_TORCH_DUTY _IOR(FLASHLIGHT_MAGIC, 232, int)

// ---------------------------------------------------------------------------

template <typename T>
static bool setNode(const std::string& path, const T& value) {
    std::ofstream file(path);
    if (!file.is_open()) {
        ALOGW("setNode: open %s failed: %s", path.c_str(), strerror(errno));
        return false;
    }
    file << value << std::endl;
    if (file.fail()) {
        ALOGW("setNode: write %s failed", path.c_str());
        return false;
    }
    return true;
}

template <typename T>
static T getNode(const std::string& path, const T& def) {
    std::ifstream file(path);
    if (!file.is_open()) {
        return def;
    }
    T result;
    file >> result;
    return file.fail() ? def : result;
}

// ---------------------------------------------------------------------------

static int torchIoctl(unsigned int cmd, int32_t* inout, int typeId, int ctId) {
    int fd = TEMP_FAILURE_RETRY(open(kFlashDev, O_RDWR | O_CLOEXEC));
    if (fd < 0) {
        return -errno;
    }
    flashlight_user_arg arg{};
    arg.type_id = typeId;
    arg.ct_id = ctId;
    arg.arg = (inout != nullptr) ? *inout : 0;
    int ret = TEMP_FAILURE_RETRY(ioctl(fd, cmd, &arg));
    int savedErrno = errno;
    close(fd);
    if (ret < 0) {
        return -savedErrno;
    }
    if (inout != nullptr) {
        *inout = arg.arg;
    }
    return 0;
}

static int32_t clampLevel(int32_t level) {
    if (level < 1) return 1;
    if (level > kMaxLevel) return kMaxLevel;
    return level;
}

// ---------------------------------------------------------------------------

static int validKeysMask() {
    static int mask = -1;
    if (mask >= 0) {
        return mask;
    }
    mask = 0;
    for (int typeId = 1; typeId <= 2; typeId++) {
        for (int ctId = 1; ctId <= 2; ctId++) {
            int32_t max = 0;
            if (torchIoctl(FLASH_IOC_GET_MAX_TORCH_DUTY, &max, typeId, ctId) == 0 && max >= 1) {
                mask |= 1 << ((typeId - 1) * 2 + (ctId - 1));
                ALOGI("valid torch key type=%d ct=%d max=%d", typeId, ctId, max);
            }
        }
    }
    if (mask == 0) {
        mask = 1;
        ALOGW("no torch key responded, falling back to type=1 ct=1");
    }
    return mask;
}

static void forEachKey(void (*fn)(int typeId, int ctId, int32_t value, bool* ok), int32_t value,
        bool* ok) {
    int mask = validKeysMask();
    for (int typeId = 1; typeId <= 2; typeId++) {
        for (int ctId = 1; ctId <= 2; ctId++) {
            if (mask & (1 << ((typeId - 1) * 2 + (ctId - 1)))) {
                fn(typeId, ctId, value, ok);
            }
        }
    }
}

static void ioctlSetDuty(int typeId, int ctId, int32_t value, bool* ok) {
    int32_t v = value;
    if (torchIoctl(FLASH_IOC_SET_DUTY, &v, typeId, ctId) != 0 && ok != nullptr) {
        *ok = false;
    }
}

static void ioctlSetTimeout(int typeId, int ctId, int32_t value, bool* ok) {
    int32_t v = value;
    if (torchIoctl(FLASH_IOC_SET_TIME_OUT_TIME_MS, &v, typeId, ctId) != 0 && ok != nullptr) {
        *ok = false;
    }
}

static void ioctlSetOnOff(int typeId, int ctId, int32_t value, bool* ok) {
    int32_t v = value;
    if (torchIoctl(FLASH_IOC_SET_ONOFF, &v, typeId, ctId) != 0 && ok != nullptr) {
        *ok = false;
    }
}

// ---------------------------------------------------------------------------

bool supportsTorchStrengthControlExt() {
    ALOGI("supportsTorchStrengthControlExt: true (max=%d default=%d)", kMaxLevel, kDefaultLevel);
    return true;
}

int32_t getTorchDefaultStrengthLevelExt() {
    return kDefaultLevel;
}

int32_t getTorchMaxStrengthLevelExt() {
    return kMaxLevel;
}

int32_t getTorchStrengthLevelExt() {
    int32_t val = getNode(kSysfsTorch, -1);
    if (val >= 1 && val <= kMaxLevel) {
        return val;
    }
    int mask = validKeysMask();
    for (int typeId = 1; typeId <= 2; typeId++) {
        for (int ctId = 1; ctId <= 2; ctId++) {
            if (mask & (1 << ((typeId - 1) * 2 + (ctId - 1)))) {
                int32_t cur = 0;
                if (torchIoctl(FLASH_IOC_GET_CURRENT_TORCH_DUTY, &cur, typeId, ctId) == 0 &&
                        cur >= 1) {
                    return clampLevel(cur + 1);
                }
            }
        }
    }
    return kDefaultLevel;
}

void setTorchStrengthLevelExt(int32_t torchStrength, bool enabled) {
    ALOGI("setTorchStrengthLevelExt: strength=%d enabled=%d", torchStrength, enabled);
    if (!enabled || torchStrength <= 0) {
        bool ok = true;
        forEachKey(ioctlSetOnOff, 0, &ok);
        bool sysfsOk = setNode(kSysfsTorch, 0);
        ALOGI("setTorchStrengthLevelExt: off (ioctlOk=%d sysfsOk=%d)", ok, sysfsOk);
        return;
    }
    int32_t level = clampLevel(torchStrength);
    int32_t duty = level - 1;
    bool ok = true;
    forEachKey(ioctlSetDuty, duty, &ok);
    forEachKey(ioctlSetTimeout, 0, &ok);
    forEachKey(ioctlSetOnOff, 1, &ok);
    bool sysfsOk = setNode(kSysfsTorch, level);
    ALOGI("setTorchStrengthLevelExt: level=%d duty=%d (ioctlOk=%d sysfsOk=%d)", level, duty, ok,
            sysfsOk);
}
