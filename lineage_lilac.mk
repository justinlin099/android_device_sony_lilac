$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# Pick the lilac effect bundle before inheriting the common vendor configuration.
PRODUCT_COPY_FILES += device/sony/lilac/audiofx/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml

# Inherit device configuration
$(call inherit-product, device/sony/lilac/device.mk)

# Product API level
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_o.mk)

### BOOTANIMATION
# vendor/lineage/config/common_full_phone.mk
TARGET_SCREEN_HEIGHT := 1280
TARGET_SCREEN_WIDTH := 720
# vendor/lineage/config/common.mk
TARGET_BOOTANIMATION_HALF_RES := true

### LINEAGE
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

## Device identifier. This must come after all inclusions
PRODUCT_NAME := lineage_lilac
PRODUCT_DEVICE := lilac
PRODUCT_BRAND := Sony
PRODUCT_MODEL := G8441

# Optionally trust the local test host in the recovery ramdisk only.
ifeq ($(TARGET_PRODUCT):$(TARGET_BUILD_VARIANT):$(WITH_LILAC_RECOVERY_HOST_ADB),lineage_lilac:userdebug:true)
    lilac_recovery_adb_key := vendor/lilac-local/recovery-adb.pub
    ifeq ($(wildcard $(lilac_recovery_adb_key)),)
        $(error Missing local lilac Recovery ADB public key)
    endif
    PRODUCT_COPY_FILES += $(lilac_recovery_adb_key):$(TARGET_COPY_OUT_RECOVERY)/root/system/product/etc/security/adb_keys
endif

# Keep all cores eligible for top-app scheduling on G8441.
PRODUCT_VENDOR_PROPERTIES += ro.vendor.yoshino.top_app_cpus=0-7
PRODUCT_MANUFACTURER := Sony

# Expose WPA3-SAE hotspot support on the G8441 product.
PRODUCT_PACKAGES += LilacWifiSaeTest

# Use the device EQ transition for the legacy audio effects bundle.
PRODUCT_PACKAGES += libbundlewrapper_lilac

# Use the AIDL health service for battery state of health.
PRODUCT_PACKAGES += android.hardware.health-service.lilac

# Codec2 uses the standard system heap for linear buffers on the 4.4 kernel.
PRODUCT_SYSTEM_PROPERTIES += debug.c2.use_dmabufheaps=1

# Keep CPU-readable Main10 HEVC output in the requested linear format.
PRODUCT_VENDOR_PROPERTIES += vendor.vidc.dec.dither_linear=true

#PRODUCT_BUILD_PROP_OVERRIDES += \
#    PRODUCT_NAME=lilac \
#    PRIVATE_BUILD_DESC="G8441-user 9 47.2.A.11.228 3311891731 release-keys"

BUILD_FINGERPRINT := Sony/G8441/G8441:9/47.2.A.11.228/3311891731:user/release-keys

# Change build version according to KSU or non-KSU build
ifeq ($(WITH_KSU),true)
	LINEAGE_VERSION_APPEND := -KSU
endif

