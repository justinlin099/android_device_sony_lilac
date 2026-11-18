#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=lilac
VENDOR=sony

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi


# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
extract "${MY_DIR}/proprietary-files-vendor.txt" "${SRC}" "${KANG}" --section "${SECTION}"

#
# Blobs fixup start
#

DEVICE_ROOT="${ANDROID_ROOT}"/vendor/"${VENDOR}"/"${DEVICE}"/proprietary

# Secure init ignores the provider's former LD_PRELOAD environment.
CAMERA_PROVIDER="${DEVICE_ROOT}/vendor/bin/hw/vendor.somc.hardware.camera.provider@1.0-service"
if [ -f "${CAMERA_PROVIDER}" ]; then
    for library in libsensorfix.so libui.so; do
        if ! "${PATCHELF}" --print-needed "${CAMERA_PROVIDER}" | grep -Fxq "${library}"; then
            "${PATCHELF}" --add-needed "${library}" "${CAMERA_PROVIDER}"
        fi
    done
    # Resolve the current C++ runtime before the older camera graphics libraries.
    if "${PATCHELF}" --print-needed "${CAMERA_PROVIDER}" | grep -Fxq libc++.so; then
        "${PATCHELF}" --remove-needed libc++.so "${CAMERA_PROVIDER}"
    fi
    if ! "${PATCHELF}" --print-needed "${CAMERA_PROVIDER}" | grep -Fxq /vendor/lib/libc++.so; then
        "${PATCHELF}" --add-needed /vendor/lib/libc++.so "${CAMERA_PROVIDER}"
    fi
    "${PATCHELF}" --set-rpath /vendor/lib/cama15 "${CAMERA_PROVIDER}"
    for library in libui.so libutils.so; do
        path="${DEVICE_ROOT}/vendor/lib/cama15/${library}"
        if [ -f "${path}" ]; then
            "${PATCHELF}" --set-rpath /vendor/lib/cama15 "${path}"
        fi
    done
fi

# Route only the Adreno blob's open imports through the lilac compatibility library.
GSL_PATCHELF="${ANDROID_ROOT}/prebuilts/extract-tools/linux-x86/bin/patchelf-0_18"
for abi in lib lib64; do
    gsl="${DEVICE_ROOT}/vendor/${abi}/libgsl.so"
    if [ -f "${gsl}" ] &&
            ! "${GSL_PATCHELF}" --print-needed "${gsl}" | grep -Fxq liblilac_ion_import.so; then
        if readelf -SW "${gsl}" 2>/dev/null | grep -qE ' \.gnu\.version +VERSYM'; then
            "${GSL_PATCHELF}" --clear-symbol-version open --clear-symbol-version __open_2 "${gsl}"
        fi
        "${GSL_PATCHELF}" --rename-dynamic-symbols "${MY_DIR}/ion_import/gsl-open-symbols.txt" "${gsl}"
        "${GSL_PATCHELF}" --add-needed liblilac_ion_import.so "${gsl}"
    fi
done

# Fix referenced set_sched_policy for stock audio hal
"${PATCHELF}" --replace-needed "libcutils.so" "libprocessgroup.so" "${DEVICE_ROOT}"/vendor/lib/hw/audio.primary.msm8998.so

# Replace libstdc++.so with libstdc++_vendor.so
"${PATCHELF_0_17_2}" --replace-needed "libstdc++.so" "libstdc++_vendor.so" "${DEVICE_ROOT}"/vendor/bin/qns

# Use libhidlbase-v32 for select Android P blobs
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/com.qualcomm.qti.ant@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.qti.voiceprint@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.semc.hardware.light@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.semc.system.idd@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.somc.hardware.camera.cacao@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.somc.hardware.camera.cacao@2.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.somc.hardware.camera.cacao@3.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.somc.hardware.camera.cacao@3.1.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.somc.hardware.camera.device@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib/vendor.somc.hardware.camera.provider@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/com.fingerprints.extension@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/com.qualcomm.qti.ant@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.display.color@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.display.color@1.1.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.display.postproc@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.qti.esepowermanager@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.qti.hardware.qdutils_disp@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.qti.hardware.qteeconnector@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.qti.hardware.tui_comm@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.semc.hardware.light@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.semc.hardware.thermal@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.semc.system.idd@1.0.so
"${PATCHELF}" --replace-needed "libhidlbase.so" "libhidlbase-v32.so" "${DEVICE_ROOT}"/vendor/lib64/vendor.somc.hardware.security.secd@1.0.so

#
# Blobs fixup end
#


sed -i 's/\x42\xf2\x80\x42/\x40\xf6\x00\x02/' "${DEVICE_ROOT}"/vendor/lib/camera/libexcal_focus_stats_conv_plugin.so


sed -i 's/\x00\x08\x01\x00/\x00\x40\x01\x00/' "${DEVICE_ROOT}"/vendor/lib/libexcal_core.so


sed -i 's/\x90\x20/\xa8\x20/' "${DEVICE_ROOT}"/vendor/lib/libsomc_chokoballpal.so


sed -i 's/\x4f\xf0\x00\x5e/\x4f\xf0\x00\x0e/' "${DEVICE_ROOT}"/vendor/lib/libcammw_util.so
sed -i 's/\x03\xf0\xd4\xfa/\x00\xbf\x00\xbf/' "${DEVICE_ROOT}"/vendor/lib/libcammw_util.so

"${MY_DIR}"/setup-makefiles.sh
