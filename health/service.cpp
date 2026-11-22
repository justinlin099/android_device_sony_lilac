/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <algorithm>

#include <android-base/logging.h>
#include <android/binder_interface_utils.h>
#include <health-impl/Health.h>
#include <health/utils.h>

#ifndef CHARGER_FORCE_NO_UI
#define CHARGER_FORCE_NO_UI 0
#endif

#if !CHARGER_FORCE_NO_UI
#include <health-impl/ChargerUtils.h>
#endif

using aidl::android::hardware::health::BatteryHealthData;
using aidl::android::hardware::health::HalHealthLoop;
using aidl::android::hardware::health::Health;
using aidl::android::hardware::health::HealthInfo;

#if !CHARGER_FORCE_NO_UI
using aidl::android::hardware::health::charger::ChargerCallback;
using aidl::android::hardware::health::charger::ChargerModeMain;
#endif

static constexpr const char* gInstanceName = "default";
static constexpr std::string_view gChargerArg{"--charger"};

namespace {

class LilacHealth final : public Health {
  public:
    using Health::Health;

    ndk::ScopedAStatus getBatteryHealthData(BatteryHealthData* out) override {
        auto status = Health::getBatteryHealthData(out);
        if (!status.isOk() || out->batteryStateOfHealth > 0) {
            return status;
        }

        HealthInfo info;
        auto infoStatus = getHealthInfo(&info);
        if (infoStatus.isOk() && info.batteryPresent && info.batteryFullChargeUah > 0 &&
            info.batteryFullChargeDesignCapacityUah > 0) {
            const int64_t learned = info.batteryFullChargeUah;
            const int64_t design = info.batteryFullChargeDesignCapacityUah;
            out->batteryStateOfHealth = std::min<int64_t>(100, (learned * 100 + design / 2) / design);
        }
        return status;
    }
};

}  // namespace

int main(int argc, char** argv) {
#ifdef __ANDROID_RECOVERY__
    android::base::InitLogging(argv, android::base::KernelLogger);
#endif

    auto config = std::make_unique<healthd_config>();
    ::android::hardware::health::InitHealthdConfig(config.get());
    auto binder = ndk::SharedRefBase::make<LilacHealth>(gInstanceName, std::move(config));

    if (argc >= 2 && argv[1] == gChargerArg) {
#if !CHARGER_FORCE_NO_UI
        // If charger shouldn't have UI for your device, simply drop the line below
        // for your service implementation. This corresponds to
        // ro.charger.no_ui=true
        return ChargerModeMain(binder, std::make_shared<ChargerCallback>(binder));
#endif

        LOG(INFO) << "Starting charger mode without UI.";
    } else {
        LOG(INFO) << "Starting health HAL.";
    }

    auto hal_health_loop = std::make_shared<HalHealthLoop>(binder, binder);
    return hal_health_loop->StartLoop();
}
