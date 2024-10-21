# Graphics HAL
PRODUCT_PACKAGES += \
    android.hardware.graphics.mapper@2.0-impl-2.1 \
    android.hardware.graphics.mapper@4.0-impl.minigbm \
    android.hardware.graphics.mapper@4.0-impl.minigbm_arcvm\
    android.hardware.graphics.mapper@4.0-impl.minigbm_gbm_mesa \
    android.hardware.graphics.allocator@2.0-impl \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.allocator@4.0-service.minigbm \
    android.hardware.graphics.allocator@4.0-service.minigbm_arcvm \
    android.hardware.graphics.allocator@4.0-service.minigbm_gbm_mesa

# HWComposer HAL
PRODUCT_PACKAGES += \
    android.hardware.graphics.composer@2.1-drmfb-service \
    android.hardware.graphics.composer@2.1-service-clone \
    android.hardware.graphics.composer@2.4-service

# Audio HAL
PRODUCT_PACKAGES += \
    android.hardware.audio.service \
    android.hardware.audio@7.1-impl \
    android.hardware.audio.effect@7.0-impl \
    android.hardware.soundtrigger@2.3-impl

# Bluetooth HAL
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.1-service.vbt \
    android.hardware.bluetooth@1.1-service.btlinux \
    android.hardware.bluetooth.audio-impl

# Media codec
PRODUCT_PACKAGES += \
    android.hardware.media.c2@1.2-ffmpeg-service

ifneq ($(TARGET_SUPPORTS_32_BIT_APPS),false)
PRODUCT_PACKAGES += android.hardware.media.omx@1.0-service
endif

# DumpState HAL
PRODUCT_PACKAGES += \
    com.android.hardware.dumpstate

# Gatekeeper HAL
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper-service.nonsecure

# Health HAL
PRODUCT_PACKAGES += \
    android.hardware.health-service.example \
    android.hardware.health-service.example_recovery

# Keymaster HAL
PRODUCT_PACKAGES += \
    android.hardware.keymaster@4.1-service

# Light HAL
PRODUCT_PACKAGES += \
    android.hardware.light-service.x86

# Memtrack HAL
PRODUCT_PACKAGES += \
    com.android.hardware.memtrack

# Power HAL
PRODUCT_PACKAGES += \
    power.x86 \
    android.hardware.power-service.example

# RenderScript HAL
PRODUCT_PACKAGES += \
    android.hardware.renderscript@1.0-impl

# Sensors HAL
PRODUCT_PACKAGES += \
    android.hardware.sensors@1.0-impl

# USB HAL
PRODUCT_PACKAGES += \
    android.hardware.usb-service.example

# Drm HAL
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

# GPS HAL
PRODUCT_PACKAGES += \
    android.hardware.gnss@1.0-impl \
    android.hardware.gnss@1.0-service

# Thermal HAL
PRODUCT_PACKAGES += \
    android.hardware.thermal@aidl-service.intel

# Bootctrl HAL
PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-x86impl \
    android.hardware.boot@1.2-x86impl.recovery \
    android.hardware.boot@1.2-service

# HIDL Allocator
PRODUCT_PACKAGES += android.hidl.allocator@1.0-service

# vndservice & vndservicemanager & hwservicemanager
PRODUCT_PACKAGES += vndservice vndservicemanager hwservicemanager
