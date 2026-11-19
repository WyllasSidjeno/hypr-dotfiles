#!/usr/bin/env python3
# Waybar module: Keychron keyboard (Link receiver) connection status.
# No battery reading here - Keychron Launcher exposes no battery view for this
# keyboard/receiver pair (confirmed via USB capture), so this just reports
# whether the receiver is currently enumerated.

import json
import os
import sys

VENDOR_ID = "00003434"
PRODUCT_ID = "0000D030"

HIDRAW_ROOT = "/sys/class/hidraw"


def is_connected():
    for name in os.listdir(HIDRAW_ROOT):
        uevent_path = os.path.join(HIDRAW_ROOT, name, "device", "uevent")
        try:
            with open(uevent_path) as f:
                uevent = f.read()
        except OSError:
            continue
        if f"HID_ID=0003:{VENDOR_ID}:{PRODUCT_ID}" in uevent:
            return True
    return False


def emit(text, tooltip, cls=""):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}), flush=True)


def main():
    if is_connected():
        emit("", "Keychron keyboard connected", "")
    else:
        emit("", "Keychron keyboard not connected", "disconnected")


if __name__ == "__main__":
    sys.exit(main())
