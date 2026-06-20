/*
 * Copyright (C) 2026 BlissLabs
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <android-base/strings.h>
#include <sys/mount.h>
#include <unistd.h>
#include <fstream>

#include "libinit_bliss.h"

using android::base::GetProperty;

static bool HasCmdlineFlag(const std::string& flag) {
    std::string cmdline;
    if (android::base::ReadFileToString("/proc/cmdline", &cmdline)) {
        for (const auto& token : android::base::Split(cmdline, " ")) {
            if (android::base::StartsWith(token, flag + "=")) {
                std::string value = token.substr(flag.length() + 1);
                if (value == "1" || value == "true" || value == "on") {
                    return true;
                }
                return false;
            } else if (token == flag) {
                return true;
            }
        }
    }
    return false;
}

static bool CheckFeature(const std::string& prop_name, const std::string& cmdline_flag) {
    if (GetProperty("ro.boot." + prop_name, "") == "1" ||
        GetProperty("ro.boot." + prop_name, "") == "true" ||
        HasCmdlineFlag(cmdline_flag)) {
        return true;
    }
    return false;
}

static void BindMount(const std::string& source_name, const std::string& target_rel_path) {
    std::string source_vendor = "/vendor/etc/hidden_xml/" + source_name;
    std::string source_system_vendor = "/system/vendor/etc/hidden_xml/" + source_name;
    
    std::string source;
    if (access(source_vendor.c_str(), F_OK) == 0) {
        source = source_vendor;
    } else if (access(source_system_vendor.c_str(), F_OK) == 0) {
        source = source_system_vendor;
    } else {
        LOG(INFO) << "Bliss Feature: Source file for " << source_name << " not found, skipping.";
        return;
    }

    std::string target_vendor = "/vendor" + target_rel_path;
    std::string target_system_vendor = "/system/vendor" + target_rel_path;
    
    std::string target;
    if (access(target_vendor.c_str(), F_OK) == 0) {
        target = target_vendor;
    } else if (access(target_system_vendor.c_str(), F_OK) == 0) {
        target = target_system_vendor;
    } else {
        LOG(INFO) << "Bliss Feature: Target file " << target_rel_path << " not found, skipping.";
        return;
    }

    if (mount(source.c_str(), target.c_str(), "", MS_BIND, nullptr) != 0) {
        PLOG(ERROR) << "Bliss Feature: Failed to bind mount " << source << " to " << target;
    } else {
        LOG(INFO) << "Bliss Feature: Successfully bind mounted " << source << " to " << target;
    }
}

void set_bliss_features() {
#ifndef __ANDROID_RECOVERY__
    LOG(INFO) << "Initializing BlissOS Features";

    // PC Mode
    if (CheckFeature("pc_mode", "PC_MODE")) {
        LOG(INFO) << "Bliss Feature: PC_MODE enabled";
        BindMount("pc.xml", "/etc/permissions/pc.xml");
    }

    // HPE
    if (CheckFeature("hpe", "HPE")) {
        LOG(INFO) << "Bliss Feature: HPE enabled";
        BindMount("hpe.xml", "/etc/sysconfig/hpe.xml");
    }

    // Virtual A/B missing (fakeboot)
    if (GetProperty("ro.boot.slot_suffix", "").empty()) {
        LOG(INFO) << "Bliss Feature: Missing Virtual A/B, masking bootctrl";
        BindMount("fakeboot.xml", "/etc/vintf/manifest/android.hardware.boot@1.2.xml");
    }

    // BLE Disable
    if (CheckFeature("bt_ble_disable", "BT_BLE_DISABLE")) {
        LOG(INFO) << "Bliss Feature: BLE Disabled";
        BindMount("noble.xml", "/etc/permissions/android.hardware.bluetooth_le.xml");
    }
#else
    LOG(INFO) << "Bliss Feature: Skipping in Recovery Mode";
#endif
}
