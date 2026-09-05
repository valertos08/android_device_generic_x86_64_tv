LOCAL_PATH := $(call my-dir)

# Magisk daemon binary
include $(CLEAR_VARS)
LOCAL_MODULE := magisk
LOCAL_SRC_FILES := magisk
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# Magisk policy tool (for sepolicy patching)
include $(CLEAR_VARS)
LOCAL_MODULE := magiskpolicy
LOCAL_SRC_FILES := magiskpolicy
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

# Magisk bundled busybox (topjohnwu build) and helper binaries.
# Needed so module install works out of the box (no manual /data dodge).
include $(CLEAR_VARS)
LOCAL_MODULE := magisk-busybox
LOCAL_MODULE_STEM := busybox
LOCAL_SRC_FILES := busybox
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := magiskinit
LOCAL_SRC_FILES := magiskinit
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := magiskboot
LOCAL_SRC_FILES := magiskboot
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := magisk-util-functions
LOCAL_MODULE_STEM := util_functions.sh
LOCAL_SRC_FILES := util_functions.sh
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/magisk
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)

# init.rc snippet to start the magisk daemon (async service)
include $(CLEAR_VARS)
LOCAL_MODULE := magisk.rc
LOCAL_SRC_FILES := magisk.rc
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/init
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)

# su is NOT shipped as a file: /system/xbin/su exists only as a symlink to the
# systemless su applet in the /sbin (tmpfs) ramdisk, created on every boot by
# init.magisk.sh (ln -sf /sbin/su /system/xbin/su). No setuid script in /system.

# Stage runner: builds /sbin tmpfs, installs stub (trusted_cert), runs daemon stages
include $(CLEAR_VARS)
LOCAL_MODULE := init.magisk.sh
LOCAL_SRC_FILES := init.magisk.sh
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)

# Stub apk: provides trusted_cert in-tree so the daemon recognizes the manager
# from the very first boot (before /data/adb/magisk/stub.apk exists).
# SAME signing (v2/v3, CN=John Wu) as the manager in user_app/Magisk.apk.
include $(CLEAR_VARS)
LOCAL_MODULE := magisk-stub
LOCAL_MODULE_STEM := stub.apk
LOCAL_SRC_FILES := stub.apk
LOCAL_MODULE_CLASS := ETC
LOCAL_MODULE_PATH := $(TARGET_OUT_ETC)/magisk
LOCAL_MODULE_TAGS := optional
include $(BUILD_PREBUILT)