#!/usr/bin/env bash
# Waybar weather module — Open-Meteo (no API key). Needs: curl, jq.
set -uo pipefail

LAT=45.4591
LON=-73.5673
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather.json"
MAX_AGE=3600 # reuse cached data up to 1 h when offline

URL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON"
URL+="&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
URL+="&timezone=America%2FToronto"

# Font Awesome glyphs as UTF-8 bytes (locale-independent, survive copy/paste)
SUN=$'\xef\x86\x85'           # f185
MOON=$'\xef\x86\x86'          # f186
CLOUD_SUN=$'\xef\x9b\x84'     # f6c4
CLOUD_MOON=$'\xef\x9b\x83'    # f6c3
CLOUD=$'\xef\x83\x82'         # f0c2
SMOG=$'\xef\x9d\x9f'          # f75f
CLOUD_RAIN=$'\xef\x9c\xbd'    # f73d
SHOWERS=$'\xef\x9d\x80'       # f740 cloud-showers-heavy
SNOW=$'\xef\x8b\x9c'          # f2dc
BOLT=$'\xef\x9d\xac'          # f76c cloud-bolt
UNKNOWN=$'\xef\x81\x99'       # f059 circle-question
WIND=$'\xef\x9c\xae'          # f72e wind
HUMIDITY=$'\xef\x81\x83'      # f043 tint
FEELS=$'\xef\x8b\x89'         # f2c9 thermometer-half

fa() { printf "<span font_family='Font Awesome 7 Free' font_weight='bold'>%s</span>" "$1"; }

emit() { # text tooltip class → Waybar JSON
    jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" '{$text, $tooltip, $class}'
}

valid() { jq -e '.current.weather_code != null' <<<"$1" &>/dev/null; }

# --- Fetch (fall back to recent cache) -------------------------------------
class=""
if data=$(curl -sf --max-time 10 --retry 2 "$URL") && valid "$data"; then
    mkdir -p "${CACHE%/*}" && printf '%s' "$data" >"$CACHE"
elif [[ -f $CACHE ]] && (( $(date +%s) - $(stat -c %Y "$CACHE") < MAX_AGE )); then
    data=$(<"$CACHE")
    class="stale"
else
    emit "$(fa "$UNKNOWN")  N/A" "Weather unavailable" "error"
    exit 0
fi

# --- Parse ------------------------------------------------------------------
IFS=$'\t' read -r temp_c temp_f feels code is_day wind hum time < <(
    jq -r 'def r: round + 0;   # "+ 0" turns -0 into 0
        .current | [
        (.temperature_2m | r),
        (.temperature_2m * 9 / 5 + 32 | r),
        (.apparent_temperature | r),
        .weather_code, .is_day,
        (.wind_speed_10m | r),
        .relative_humidity_2m,
        (.time | split("T")[1])
    ] | @tsv' <<<"$data"
)

# --- WMO code → description / day icon / night icon ------------------------
night=""
case $code in
    0)           desc="Clear sky";              icon=$SUN;        night=$MOON ;;
    1)           desc="Mainly clear";           icon=$CLOUD_SUN;  night=$CLOUD_MOON ;;
    2)           desc="Partly cloudy";          icon=$CLOUD_SUN;  night=$CLOUD_MOON ;;
    3)           desc="Overcast";               icon=$CLOUD ;;
    45|48)       desc="Fog";                    icon=$SMOG ;;
    51|53|55)    desc="Drizzle";                icon=$CLOUD_RAIN ;;
    56|57)       desc="Freezing drizzle";       icon=$CLOUD_RAIN ;;
    61|63)       desc="Rain";                   icon=$CLOUD_RAIN ;;
    65)          desc="Heavy rain";             icon=$SHOWERS ;;
    66|67)       desc="Freezing rain";          icon=$SHOWERS ;;
    71|73|75|77) desc="Snow";                   icon=$SNOW ;;
    80)          desc="Rain showers";           icon=$CLOUD_RAIN ;;
    81|82)       desc="Heavy rain showers";     icon=$SHOWERS ;;
    85|86)       desc="Snow showers";           icon=$SNOW ;;
    95)          desc="Thunderstorm";           icon=$BOLT ;;
    96|99)       desc="Thunderstorm with hail"; icon=$BOLT ;;
    *)           desc="Unknown (code $code)";   icon=$CLOUD ;;
esac
[[ $is_day == 0 && -n $night ]] && icon=$night

# --- Output -----------------------------------------------------------------
# Pad numeric fields to a fixed width so the pill doesn't jitter as values change.
printf -v temp_c_p "%3d" "$temp_c"
printf -v temp_f_p "%3d" "$temp_f"
printf -v feels_p "%3d" "$feels"
printf -v wind_p "%3d" "$wind"
printf -v hum_p "%3d" "$hum"

feels_part=""
(( (temp_c - feels >= 2) || (feels - temp_c >= 2) )) && feels_part="  $(fa "$FEELS") ${feels_p}°C"

text="$(fa "$icon")  ${temp_c_p}°C / ${temp_f_p}°F${feels_part}  $(fa "$WIND") ${wind_p} km/h  $(fa "$HUMIDITY")  ${hum_p}%"
tooltip="$desc
Feels like ${feels}°C
Wind ${wind} km/h · Humidity ${hum}%
Updated ${time}${class:+ (offline, cached)}"

emit "$text" "$tooltip" "$class"
