DEVICE_PACKAGE_OVERLAYS := \
    device/softwinner/common/overlay

PRODUCT_COPY_FILES += \
    device/softwinner/common/init.common.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.common.rc \

#media
$(call inherit-product-if-exists, frameworks/av/media/libcedarc/libcdclist.mk)
$(call inherit-product-if-exists, frameworks/av/media/libcedarx/libcdxlist.mk)

# ota tools
PRODUCT_PACKAGES += brotli

# tools
PRODUCT_PACKAGES += \
    mtop \
    preinstall \

# build file_contexts.bin for dragonface
PRODUCT_PACKAGES += file_contexts.bin

# Audio
PRODUCT_PACKAGES += \
    audio.a2dp.default \
    audio.usb.default \
    audio.r_submix.default

# f2fs format tool for recovery
PRODUCT_PACKAGES += mkfs.f2fs

PRODUCT_COPY_FILES += \
    frameworks/av/services/audiopolicy/config/a2dp_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/a2dp_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    frameworks/av/services/audiopolicy/config/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml

# gms express required property
PRODUCT_PROPERTY_OVERRIDES += \
    ro.base_build=noah

# scense_control
PRODUCT_PROPERTY_OVERRIDES += \
    persist.vendor.p_bootcomplete= true \
    persist.vendor.p_debug= false \
    persist.vendor.p_benchmark= true \
    persist.vendor.p_music= true

# sf control
PRODUCT_PROPERTY_OVERRIDES += \
    debug.sf.disable_backpressure= 1

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.sys.strictmode.disable=1

# for debug
ifneq (,$(filter true,$(PRODUCT_DEBUG)))
PRODUCT_PACKAGES += kmsgd

PRODUCT_PROPERTY_OVERRIDES += \
    ro.logd.size= 524288 \
    ro.logd.size.main=4194304 \
    ro.logd.size.system=1048576 \
    ro.logd.size.crash=4194304 \

PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    persist.logd.logpersistd=logcatd
endif


PRODUCT_PROPERTY_OVERRIDES += \
    ro.sys.sdcardfs = force_on

# OEM Unlock reporting
PRODUCT_DEFAULT_PROPERTY_OVERRIDES += \
    ro.oem_unlock_supported= 1 

# not support boots directly in VR mode
PRODUCT_PROPERTY_OVERRIDES += \
    ro.boot.vr= false

# bin: busybox and cpu_monitor
$(call inherit-product-if-exists, vendor/aw/public/tool.mk)
