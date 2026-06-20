/*
 * Copyright (C) 2021 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <android-base/file.h>
#include <android-base/logging.h>
#include <android-base/properties.h>
#include <sys/stat.h>
#include <sys/sysinfo.h>

#include <libinit_dalvik_heap.h>
#include <libinit_utils.h>

#include "vendor_init.h"

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

extern "C" {
#include <smbios.h>
}

using android::base::GetProperty;
using android::base::ReadFileToString;

// Sentinel values found in DMI tables that should be treated as empty/invalid.
// These are placeholder strings left by BIOS vendors when the field is not
// properly populated (common on DIY motherboards and some OEM systems).
static const std::vector<std::string> kSentinelValues = {
    "To Be Filled By O.E.M.",
    "To be filled by O.E.M.",
    "Default string",
    "System Product Name",
    "System manufacturer",
    "Not Specified",
    "Not Available",
    "Type1ProductConfigId",
    "Undefined",
    "empty",
    "None",
    "No Enclosure",
    "O.E.M.",
};

static bool is_valid_dmi_value(const char *str) {
    if (!str || str[0] == '\0') return false;
    for (const auto& sentinel : kSentinelValues) {
        if (sentinel == str) return false;
    }
    return true;
}

static const std::string kDmiTablesPath = "/sys/firmware/dmi/tables";
static const std::string kDmiIdPath = "/sys/devices/virtual/dmi/id/";

// Load raw SMBIOS tables from sysfs.
// Returns true on success, with *buffer and *size populated.
// The caller must free(*buffer) when done.
static bool load_smbios_tables(uint8_t **buffer, size_t *size) {
    std::string dmi_path = kDmiTablesPath + "/DMI";
    std::string entry_path = kDmiTablesPath + "/smbios_entry_point";

    // Get the size of the DMI table
    struct stat info;
    if (stat(dmi_path.c_str(), &info) != 0) {
        LOG(WARNING) << "init_x86: Cannot stat " << dmi_path;
        return false;
    }

    *size = (size_t)info.st_size + 32;
    *buffer = (uint8_t *)malloc(*size);
    if (!*buffer) return false;

    // Read SMBIOS structures (at offset 32)
    FILE *input = fopen(dmi_path.c_str(), "rb");
    if (!input) {
        LOG(WARNING) << "init_x86: Cannot open " << dmi_path;
        free(*buffer);
        return false;
    }
    fread((char *)*buffer + 32, (size_t)info.st_size, 1, input);
    fclose(input);

    // Read SMBIOS entry point (first 32 bytes)
    input = fopen(entry_path.c_str(), "rb");
    if (!input) {
        LOG(WARNING) << "init_x86: Cannot open " << entry_path;
        free(*buffer);
        return false;
    }
    fread((char *)*buffer, 32, 1, input);
    fclose(input);

    return true;
}

// Fallback: read a single DMI field from /sys/devices/virtual/dmi/id/
// Used when SMBIOS table parsing fails.
static std::string read_dmi_id_file(const std::string& field) {
    std::string value;
    if (!ReadFileToString(kDmiIdPath + field, &value) || value.empty())
        return "";
    // Strip trailing newline
    if (value.back() == '\n') value.pop_back();
    return is_valid_dmi_value(value.c_str()) ? value : "";
}

// Check if the system vendor string indicates a Lenovo device.
// Lenovo uses machine type model (MTM) codes in product_name, so we need
// to use product_family or product_version for the human-readable name.
static bool is_lenovo(const char *manufacturer) {
    if (!manufacturer) return false;
    return strcmp(manufacturer, "LENOVO") == 0 ||
           strcmp(manufacturer, "Lenovo") == 0;
}

// Check if the system vendor string indicates a Samsung device.
// Samsung puts slash-separated model codes in product_name
// (e.g., "950XCJ/951XCJ/950XCR") instead of a clean model name.
static bool is_samsung(const char *manufacturer) {
    if (!manufacturer) return false;
    return strncmp(manufacturer, "SAMSUNG", 7) == 0;
}

// Check if the system vendor string is a placeholder value,
// indicating a DIY/custom-built system where board_vendor and
// board_name are more reliable than sys_vendor and product_name.
static bool is_diy_system(const char *manufacturer) {
    return !is_valid_dmi_value(manufacturer);
}

static void set_misc_properties() {
    if (GetProperty("ro.boot.insecure_adb", "") == "1") {
        property_override("ro.adb.secure", "0");
        property_override("ro.secure", "0");
    }
}

static void set_properties_from_smbios() {
    uint8_t *data = nullptr;
    size_t size = 0;

    if (!load_smbios_tables(&data, &size)) {
        LOG(WARNING) << "init_x86: Failed to load SMBIOS tables, falling back to sysfs";
        // Fallback to basic sysfs reading
        std::string bios_version = read_dmi_id_file("bios_version");
        std::string product_serial = read_dmi_id_file("product_serial");
        std::string board_name = read_dmi_id_file("board_name");
        std::string sys_vendor = read_dmi_id_file("sys_vendor");
        std::string product_name = read_dmi_id_file("product_name");
        std::string product_family = read_dmi_id_file("product_family");

        if (!bios_version.empty())
            property_override("ro.boot.bootloader", bios_version);
        if (!product_serial.empty())
            property_override("ro.bliss.serialnumber", product_serial);
        if (!board_name.empty())
            property_override("ro.product.board", board_name);
        if (!sys_vendor.empty()) {
            set_ro_build_prop("brand", sys_vendor, true);
            set_ro_build_prop("manufacturer", sys_vendor, true);
        }
        if (!product_name.empty()) {
            set_ro_build_prop("name", product_name, true);
            set_ro_build_prop("model", product_name, true);
        }
        return;
    }

    struct ParserContext ctx;
    if (smbios_initialize(&ctx, data, size, SMBIOS_3_0) != SMBERR_OK) {
        LOG(ERROR) << "init_x86: Failed to initialize SMBIOS parser";
        free(data);
        return;
    }

    // Collected SMBIOS data
    const char *bios_version = nullptr;       // BiosInfo.BIOSVersion
    const char *sys_manufacturer = nullptr;   // SystemInfo.Manufacturer
    const char *product_name = nullptr;       // SystemInfo.ProductName
    const char *product_version = nullptr;    // SystemInfo.Version
    const char *product_serial = nullptr;     // SystemInfo.SerialNumber
    const char *product_family = nullptr;     // SystemInfo.Family
    const char *board_vendor = nullptr;       // BaseboardInfo.Manufacturer
    const char *board_product = nullptr;      // BaseboardInfo.Product
    uint8_t chassis_type = 0;                 // SystemEnclosure.Type

    // Parse all relevant SMBIOS entries in a single pass
    const struct Entry *entry = nullptr;
    while (smbios_next(&ctx, &entry) == SMBERR_OK) {
        switch (entry->type) {
            case TYPE_BIOS_INFO:
                bios_version = entry->data.bios_info.BIOSVersion;
                break;
            case TYPE_SYSTEM_INFO:
                sys_manufacturer = entry->data.system_info.Manufacturer;
                product_name = entry->data.system_info.ProductName;
                product_version = entry->data.system_info.Version;
                product_serial = entry->data.system_info.SerialNumber;
                product_family = entry->data.system_info.Family;
                break;
            case TYPE_BASEBOARD_INFO:
                board_vendor = entry->data.baseboard_info.Manufacturer;
                board_product = entry->data.baseboard_info.Product;
                break;
            case TYPE_SYSTEM_ENCLOSURE:
                // Mask off the "chassis lock present" bit (bit 7)
                chassis_type = entry->data.system_enclosure.Type & 0x7F;
                break;
            default:
                break;
        }
    }

    // --- Direct property mappings ---

    // BIOS version → bootloader version
    if (is_valid_dmi_value(bios_version))
        property_override("ro.boot.bootloader", bios_version);

    // System serial number
    if (is_valid_dmi_value(product_serial))
        property_override("ro.bliss.serialnumber", product_serial);

    // Board name (always from baseboard, this is semantically correct)
    if (is_valid_dmi_value(board_product))
        property_override("ro.product.board", board_product);

    // --- Vendor-aware ro.product.* mapping ---
    //
    // The key insight from our research is that different vendors populate
    // SMBIOS fields very differently:
    //
    // - Most OEMs (Dell, HP, ASUS, Acer, etc.): product_name IS the
    //   user-visible model name (e.g., "Latitude 5520", "HP EliteBook 840 G8")
    //
    // - Lenovo: product_name contains an internal MTM code (e.g., "20XW005JUS"),
    //   while product_family/product_version has the human-readable name
    //   (e.g., "ThinkPad X1 Carbon Gen 9")
    //
    // - Samsung: product_name contains slash-separated model codes
    //   (e.g., "950XCJ/951XCJ/950XCR"), while product_family may have
    //   a better name (e.g., "Galaxy Book")
    //
    // - DIY boards (ASRock, Biostar, EVGA): sys_vendor and product_name are
    //   often "To Be Filled By O.E.M." — board_vendor and board_name are
    //   the reliable identifiers
    //

    const char *model_source = nullptr;
    const char *name_source = nullptr;
    const char *brand_source = nullptr;
    const char *mfr_source = nullptr;

    if (is_lenovo(sys_manufacturer)) {
        // Lenovo: Use product_family for model/name
        // Fallback chain: product_family → product_version → product_name
        if (is_valid_dmi_value(product_family)) {
            model_source = product_family;
        } else if (is_valid_dmi_value(product_version)) {
            model_source = product_version;
        } else {
            model_source = product_name;
        }
        name_source = model_source;
        brand_source = sys_manufacturer;
        mfr_source = sys_manufacturer;
    } else if (is_samsung(sys_manufacturer)) {
        // Samsung: Prefer product_family over product_name
        // product_name often has slash-separated codes
        if (is_valid_dmi_value(product_family)) {
            model_source = product_family;
        } else {
            model_source = product_name;
        }
        name_source = model_source;
        brand_source = sys_manufacturer;
        mfr_source = sys_manufacturer;
    } else if (is_diy_system(sys_manufacturer)) {
        // DIY systems: Fall back to baseboard info
        model_source = board_product;
        name_source = board_product;
        brand_source = board_vendor;
        mfr_source = board_vendor;
    } else {
        // Default: Dell, HP, ASUS, Acer, MSI, Valve, Intel NUC,
        // gaming handhelds, mini PCs, Surface, Chromebooks, etc.
        // product_name IS the user-visible model name.
        model_source = product_name;
        name_source = product_name;
        brand_source = sys_manufacturer;
        mfr_source = sys_manufacturer;
    }

    // Set the ro.product.* properties across all partitions
    if (is_valid_dmi_value(name_source))
        set_ro_build_prop("name", name_source, true);
    if (is_valid_dmi_value(model_source))
        set_ro_build_prop("model", model_source, true);
    if (is_valid_dmi_value(brand_source))
        set_ro_build_prop("brand", brand_source, true);
    if (is_valid_dmi_value(mfr_source))
        set_ro_build_prop("manufacturer", mfr_source, true);

    free(data);
}

void vendor_load_properties() {
    set_dalvik_heap();
    set_misc_properties();
    set_properties_from_smbios();
}
