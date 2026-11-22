#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Keep the Sony fingerprint authentication worker eligible at screen-off."""

import hashlib
import sys
from pathlib import Path

SHIM_LINKED_SHA256 = "ef10da0b5af155c70df2499d5d5a262b7c1b2be47e19bec5da6e1edc21bcdf47"
TOUCH_SHA256 = "ab886bc9c2c7857af269c3f1fe235cee1219b540ca0b49d0c127481db8f8b02d"
# The HAL clears bit 0 after allocating its "authenticate" worker. Retain
# task_alloc's default bit so this task can wait for its IRQ at screen-off.
CALL_OFFSET = 0x680C
CALL = bytes.fromhex("f1f8ff97")
NOP = bytes.fromhex("1f2003d5")


def patch_auth_worker(path):
    with path.open("r+b") as service:
        data = service.read()
        digest = hashlib.sha256(data).hexdigest()
        if digest == TOUCH_SHA256:
            return
        end = CALL_OFFSET + len(CALL)
        if digest != SHIM_LINKED_SHA256 or data[CALL_OFFSET:end] != CALL:
            raise ValueError(f"Unsupported lilac fingerprint HAL: {digest}")
        if hashlib.sha256(data[:CALL_OFFSET] + NOP + data[end:]).hexdigest() != TOUCH_SHA256:
            raise ValueError("Unexpected fingerprint HAL patch output")
        service.seek(CALL_OFFSET)
        service.write(NOP)


if __name__ == "__main__":
    patch_auth_worker(Path(sys.argv[1]))
