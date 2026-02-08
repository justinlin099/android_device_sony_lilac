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
    $(DEVICE_PATH)

# Device uses high-density artwork where available
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREBUILT_DPI := xhdpi hdpi
PRODUCT_AAPT_PREF_CONFIG := xhdpi
PRODUCT_SHIPPING_API_LEVEL := 26

# 復活 ConfigStore 服務
PRODUCT_PACKAGES += \
    android.hardware.configstore@1.1-service\
    android.hardware.graphics.allocator@2.0-service \
    android.hardware.graphics.composer@2.1-service \
    android.hardware.graphics.mapper@2.0-impl-2.1 \

DEVICE_PACKAGE_OVERLAYS += \
    $(DEVICE_PATH)/overlay

### POWER
TARGET_USE_CUSTOM_POWERHINT := true

include $(DEVICE_PATH)/device/*.mk
