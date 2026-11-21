### PLATFORM
$(call inherit-product, device/sony/yoshino-common/platform.mk)
### PROPRIETARY VENDOR FILES
$(call inherit-product, vendor/sony/lilac/lilac-vendor.mk)

ifeq ($(WITH_FDROID),true)
$(call inherit-product, vendor/fdroid/fdroid-vendor.mk)
endif
ifeq ($(WITH_MICROG),true)
$(call inherit-product, vendor/microg/microg-vendor.mk)
endif

DEVICE_PATH := device/sony/lilac

# Soong
PRODUCT_SOONG_NAMESPACES += \
    $(DEVICE_PATH) \
    hardware/google/pixel/power-libperfmgr

# Device uses high-density artwork where available
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREBUILT_DPI := xhdpi hdpi
PRODUCT_AAPT_PREF_CONFIG := xhdpi
PRODUCT_SHIPPING_API_LEVEL := 26

PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/rootdir/etc/fstab.lilac.first_stage:$(TARGET_COPY_OUT_RAMDISK)/fstab.lilac

PRODUCT_PACKAGES += lilac_framework_compatibility_matrix.5.xml

# Shared libraries required by the existing Sony HAL binaries.
PRODUCT_PACKAGES += \
    android.hardware.light@2.0.vendor \
    libperfmgr.vendor

PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.mapper@2.0-impl-2.1 \

PRODUCT_PACKAGES += \
    com.sony.device \
    com.sonymobile.album \
    com.sonymobile.album.internal \
    com.sony.device.xml \
    com.sonymobile.album.xml \
    com.sonymobile.album.internal.xml \
    privapp-permissions-sony.xml

DEVICE_PACKAGE_OVERLAYS += \
    $(DEVICE_PATH)/overlay

PRODUCT_PACKAGES += LilacSettingsOverlay

PRODUCT_ENFORCE_RRO_EXCLUDED_OVERLAYS += \
    device/sony/lilac/overlay/packages/apps/Settings\
    device/sony/yoshino-common/overlay/frameworks/base/packages/SystemUI\
    device/sony/lilac/overlay/packages/apps/SettingsGoogle

### POWER
TARGET_USE_CUSTOM_POWERHINT := true

include $(DEVICE_PATH)/device/*.mk

PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false
OVERRIDE_ENABLE_UFFD_GC := false

PRODUCT_COPY_FILES += \
    device/sony/lilac/rootdir/etc/init.lilac-secd-override.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.lilac-secd-override.rc \
    device/sony/lilac/rootdir/etc/init.lilac-cpuset.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.lilac-cpuset.rc \
    device/sony/lilac/rootdir/bin/init.lilac-cpuset.sh:$(TARGET_COPY_OUT_VENDOR)/bin/init.lilac-cpuset.sh

PRODUCT_PACKAGES += \
    DeskClockWidgetColorFix

PRODUCT_COPY_FILES += \
    device/sony/lilac/fonts/fonts_customization.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/fonts_customization.xml
