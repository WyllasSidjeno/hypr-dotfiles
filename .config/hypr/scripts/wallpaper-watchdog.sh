#!/usr/bin/env bash
# Mitigation for hyprwm/aquamarine#383 / #386: after the TV's HDMI link
# drops and reconnects, hyprpaper's layer surface can go stale (IPC still
# reports the right wallpaper as "active", but nothing actually renders,
# so Hyprland's own default background shows instead). Listening for
# monitor-added events and force-restarting hyprpaper is more reliable
# than polling its reported state, since that state can lie.

SOCK="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"

# 2026-11-11: a single restart right after the reconnect event isn't always
# enough -- the DRM connector can still be settling, so the freshly-started
# hyprpaper instance binds to the output before it's stable and inherits the
# same stale-surface bug. Debounce bursts of events, then do two restarts
# (an initial one, and a safety-net one a few seconds later) instead of one.
LAST_RUN=0
DEBOUNCE_SECS=3

socat -u UNIX-CONNECT:"$SOCK" - | while IFS= read -r line; do
    case "$line" in
        monitoraddedv2\>\>*|monitoradded\>\>*)
            now=$(date +%s)
            if (( now - LAST_RUN < DEBOUNCE_SECS )); then
                continue
            fi
            LAST_RUN=$now
            (
                sleep 1
                systemctl --user restart hyprpaper.service
                sleep 4
                systemctl --user restart hyprpaper.service
            ) &
            ;;
    esac
done
