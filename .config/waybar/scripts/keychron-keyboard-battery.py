#!/usr/bin/env python3
# Waybar module: Keychron V6 Max keyboard battery level, over Bluetooth via UPower.

import json
import subprocess
import sys
from pathlib import Path

DEVICE_PATH = "/org/freedesktop/UPower/devices/keyboard_dev_DD_97_CE_6E_6D_E2"
LOW_BATTERY_THRESHOLD = 25
NOTIFIED_FLAG = Path("/tmp/keychron-keyboard-low-battery-notified")
LAST_PERCENTAGE_FILE = Path("/tmp/keychron-keyboard-last-percentage")


def get_percentage():
    try:
        out = subprocess.run(
            ["upower", "-i", DEVICE_PATH],
            capture_output=True, text=True, timeout=2, check=True,
        ).stdout
    except (subprocess.SubprocessError, OSError):
        return None

    for line in out.splitlines():
        line = line.strip()
        if line.startswith("percentage:"):
            try:
                return int(line.split(":", 1)[1].strip().rstrip("%"))
            except ValueError:
                return None
    return None


def emit(text, tooltip, cls=""):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": cls}), flush=True)


def is_charging(battery):
    # UPower reports state: unknown for this device, so detect charging by
    # trend: a rising percentage since the last poll means it's on a cable.
    try:
        last = int(LAST_PERCENTAGE_FILE.read_text().strip())
    except (OSError, ValueError):
        return False
    return battery > last


def notify_if_low(battery, charging):
    if battery <= LOW_BATTERY_THRESHOLD and not charging:
        if not NOTIFIED_FLAG.exists():
            subprocess.run(
                ["notify-send", "-u", "critical", "-i", "input-keyboard",
                 "Keychron keyboard battery low", f"{battery}% remaining"],
                check=False,
            )
            NOTIFIED_FLAG.touch()
    else:
        NOTIFIED_FLAG.unlink(missing_ok=True)


def main():
    battery = get_percentage()
    if battery is None:
        emit("", "Keychron keyboard not connected", "disconnected")
        return

    charging = is_charging(battery)
    notify_if_low(battery, charging)
    LAST_PERCENTAGE_FILE.write_text(str(battery))

    cls = "critical" if battery <= 15 else ("warning" if battery <= 30 else "")
    emit(f"{battery:>2}%", f"Keychron keyboard battery: {battery}%", cls)


if __name__ == "__main__":
    sys.exit(main())
