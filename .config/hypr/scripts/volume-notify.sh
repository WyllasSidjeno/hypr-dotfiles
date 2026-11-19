#!/usr/bin/env bash
# Adjusts volume via wpctl, then pings the circular OSD daemon.
set -euo pipefail

SINK="@DEFAULT_AUDIO_SINK@"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
    raise) wpctl set-volume -l 1 "$SINK" 1%+ ;;
    lower) wpctl set-volume "$SINK" 1%- ;;
    mute)  wpctl set-mute "$SINK" toggle ;;
    *) echo "usage: $0 raise|lower|mute" >&2; exit 1 ;;
esac

vol_info="$(wpctl get-volume "$SINK")"
pct="$(awk '{print $2}' <<<"$vol_info")"
pct_int="$(awk -v v="$pct" 'BEGIN{printf "%d", (v*100)+0.5}')"
muted=0
grep -q MUTED <<<"$vol_info" && muted=1

python3 "$SCRIPT_DIR/volume-osd.py" --notify "$pct_int" "$muted"
