/*
 * Copyright (C) 2004-2010 NXP Software
 * Copyright (C) 2010 The Android Open Source Project
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

/****************************************************************************************/
/*                                                                                      */
/*  Includes                                                                            */
/*                                                                                      */
/****************************************************************************************/

#include "LVEQNB.h"
#include "LVEQNB_Private.h"
#include "VectorArithmetic.h"
#include "BIQUAD.h"

#include <algorithm>

#include <log/log.h>

/****************************************************************************************/
/*                                                                                      */
/*  Defines                                                                             */
/*                                                                                      */
/****************************************************************************************/

#define SHIFT 13

static void renderEqualizer(LVEQNB_Instance_t* instance, std::vector<LVEQNB_Filter>& filters,
                            const std::vector<LVM_FLOAT>& gain, const LVM_FLOAT* input,
                            LVM_FLOAT* output, LVM_FLOAT* temp, LVM_UINT16 frames) {
    const auto samples = instance->Params.NrChannels * frames;
    Copy_Float(input, output, samples);
    for (LVM_UINT16 band = 0; band < instance->NBands; ++band) {
        if (instance->pBiquadType[band] != LVEQNB_SinglePrecision_Float || gain[band] == 0) {
            continue;
        }
        filters[band].process(temp, output, frames);
        for (int sample = 0; sample < samples; ++sample) {
            output[sample] += temp[sample] * gain[band];
        }
    }
}

/****************************************************************************************/
/*                                                                                      */
/* FUNCTION:                LVEQNB_Process                                              */
/*                                                                                      */
/* DESCRIPTION:                                                                         */
/*  Process function for the N-Band Equaliser module.                                   */
/*                                                                                      */
/* PARAMETERS:                                                                          */
/*  hInstance               Instance handle                                             */
/*  pInData                 Pointer to the input data                                   */
/*  pOutData                Pointer to the output data                                  */
/*  NumSamples              Number of samples in the input buffer                       */
/*                                                                                      */
/* RETURNS:                                                                             */
/*  LVEQNB_SUCCESS          Succeeded                                                   */
/*  LVEQNB_NULLADDRESS      When hInstance, pInData or pOutData are NULL                */
/*  LVEQNB_ALIGNMENTERROR   When pInData or pOutData are not 32-bit aligned             */
/*  LVEQNB_TOOMANYSAMPLES   NumSamples was larger than the maximum block size           */
/*                                                                                      */
/* NOTES:                                                                               */
/*                                                                                      */
/****************************************************************************************/
LVEQNB_ReturnStatus_en LVEQNB_Process(
        LVEQNB_Handle_t hInstance, const LVM_FLOAT* pInData, LVM_FLOAT* pOutData,
        const LVM_UINT16 NrFrames) {  // updated to use samples = frames * channels.
    LVEQNB_Instance_t* pInstance = (LVEQNB_Instance_t*)hInstance;
    /* Check for NULL pointers */
    if ((hInstance == LVM_NULL) || (pInData == LVM_NULL) || (pOutData == LVM_NULL)) {
        return LVEQNB_NULLADDRESS;
    }

    const LVM_INT32 NrChannels = pInstance->Params.NrChannels;
    const LVM_INT32 NrSamples = NrChannels * NrFrames;

    /* Check if the input and output data buffers are 32-bit aligned */
    if ((((uintptr_t)pInData % 4) != 0) || (((uintptr_t)pOutData % 4) != 0)) {
        return LVEQNB_ALIGNMENTERROR;
    }

    LVM_FLOAT* const pScratch = (LVM_FLOAT*)pInstance->pFastTemporary;

    /*
     * Check the number of frames is not too large
     */
    if (NrFrames > pInstance->Capabilities.MaxBlockSize) {
        return LVEQNB_TOOMANYSAMPLES;
    }

    if (pInstance->Params.OperatingMode == LVEQNB_ON) {
        auto& transition = pInstance->presetTransition;
        if (transition.remainingFrames == 0 && transition.hasPendingPreset) {
            LVEQNB_Params_t next = pInstance->Params;
            next.pBandDefinition = transition.pendingBands.data();
            LVEQNB_StartPresetTransition(pInstance, &next);
            transition.hasPendingPreset = false;
        }
        LVM_FLOAT* const temp = pScratch + NrSamples;
        renderEqualizer(pInstance, pInstance->eqBiquad, pInstance->gain,
                        pInData, pScratch, temp, NrFrames);
        if (transition.remainingFrames != 0) {
            const auto blendFrames = std::min<LVM_UINT32>(NrFrames, transition.remainingFrames);
            auto* const previous = transition.previousOutput.data();
            renderEqualizer(pInstance, transition.previousFilters, transition.previousGains,
                            pInData, previous, temp, blendFrames);
            const auto completed = transition.durationFrames - transition.remainingFrames;
            for (LVM_UINT32 frame = 0; frame < blendFrames; ++frame) {
                const auto weight = static_cast<LVM_FLOAT>(completed + frame) /
                        transition.durationFrames;
                for (int channel = 0; channel < NrChannels; ++channel) {
                    const auto sample = frame * NrChannels + channel;
                    pScratch[sample] = previous[sample] +
                            weight * (pScratch[sample] - previous[sample]);
                }
            }
            transition.remainingFrames -= blendFrames;
        }

        if (pInstance->bInOperatingModeTransition == LVM_TRUE) {
            LVC_MixSoft_2Mc_D16C31_SAT(&pInstance->BypassMixer, pScratch, pInData, pScratch,
                                       (LVM_INT16)NrFrames, (LVM_INT16)NrChannels);
        }
        Copy_Float(pScratch, pOutData, NrSamples);
    } else {
        /*
         * Mode is OFF so copy the data if necessary
         */
        if (pInData != pOutData) {
            Copy_Float(pInData,               /* Source */
                       pOutData,              /* Destination */
                       (LVM_INT16)NrSamples); /* All channel samples */
        }
    }
    return LVEQNB_SUCCESS;
}
