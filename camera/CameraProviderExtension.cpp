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
static void setNode(const std::string& path, const T& value) {
    std::ofstream file(path);
    if (!file.is_open()) {
        return;
    }
    file << value << std::endl;
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

bool supportsTorchStrengthControlExt() {
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
    int32_t cur = 0;
    if (torchIoctl(FLASH_IOC_GET_CURRENT_TORCH_DUTY, &cur, 1, 1) == 0 && cur >= 1) {
        return clampLevel(cur + 1);
    }
    return kDefaultLevel;
}

void setTorchStrengthLevelExt(int32_t torchStrength, bool enabled) {
    if (!enabled || torchStrength <= 0) {
        int32_t off = 0;
        (void)torchIoctl(FLASH_IOC_SET_ONOFF, &off, 1, 1);
        setNode(kSysfsTorch, 0);
        return;
    }
    int32_t level = clampLevel(torchStrength);
    int32_t duty = level - 1;
    (void)torchIoctl(FLASH_IOC_SET_DUTY, &duty, 1, 1);
    int32_t timeoutMs = 0;
    (void)torchIoctl(FLASH_IOC_SET_TIME_OUT_TIME_MS, &timeoutMs, 1, 1);
    int32_t on = 1;
    (void)torchIoctl(FLASH_IOC_SET_ONOFF, &on, 1, 1);
    setNode(kSysfsTorch, level);
}
