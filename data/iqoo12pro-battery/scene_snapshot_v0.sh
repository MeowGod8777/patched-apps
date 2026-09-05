#!/system/bin/sh
# v0 validation collector for Shizuku Runner.
# Run this from Runner, then switch to Scene -> 耗电统计 before the delay expires.

OUT=/sdcard/SceneBattery
XML="$OUT/last.xml"
mkdir -p "$OUT"
rm -f "$XML"

echo "Switch to Scene -> 耗电统计 within 7 seconds..."
sleep 7
uiautomator dump "$XML" >/dev/null 2>&1 || {
  echo "ERROR: uiautomator dump failed"
  exit 1
}

NODES="$OUT/last.nodes"
sed 's/></>\n</g' "$XML" > "$NODES"

get_text() {
  grep -m1 "resource-id=\"com.omarea.vtools:id/$1\"" "$NODES" | sed -n 's/.*text="\([^"]*\)".*/\1/p'
}

CAPTURE_AT=$(date '+%Y-%m-%dT%H:%M:%S%z')
AVG_POWER=$(get_text avg_power)
USED=$(get_text screen_on_duration)
PREDICT=$(get_text predict_time)
BATTERY=$(get_text battery_capacity)
TEMP=$(get_text battery_temperature)
VOLTAGE=$(get_text battery_voltage)
STATUS=$(get_text battery_status)

APP_NAMES=$(grep 'resource-id="com.omarea.vtools:id/itemTitle"' "$NODES" | sed -n 's/.*text="\([^"]*\)".*/\1/p' | paste -sd '|' -)
APP_COUNTS=$(grep 'resource-id="com.omarea.vtools:id/itemCounts"' "$NODES" | sed -n 's/.*text="\([^"]*\)".*/\1/p' | paste -sd '|' -)
APP_AVG=$(grep 'resource-id="com.omarea.vtools:id/itemAvgIO"' "$NODES" | sed -n 's/.*text="\([^"]*\)".*/\1/p' | paste -sd '|' -)

WIFI_STATUS=$(cmd wifi status 2>&1)

printf '%s\n' '===== SCENE SNAPSHOT ====='
printf 'capture_at=%s\n' "$CAPTURE_AT"
printf 'avg_power=%s\n' "$AVG_POWER"
printf 'used=%s\n' "$USED"
printf 'theoretical_runtime=%s\n' "$PREDICT"
printf 'battery=%s\n' "$BATTERY"
printf 'battery_temp=%s\n' "$TEMP"
printf 'battery_voltage=%s\n' "$VOLTAGE"
printf 'battery_status=%s\n' "$STATUS"
printf 'apps=%s\n' "$APP_NAMES"
printf 'app_durations=%s\n' "$APP_COUNTS"
printf 'app_avg=%s\n' "$APP_AVG"
printf '%s\n' '===== WIFI STATUS ====='
printf '%s\n' "$WIFI_STATUS"
printf '%s\n' '===== CONNECTIVITY HINT ====='
dumpsys connectivity 2>/dev/null | grep -E 'Active default network|NetworkAgentInfo.*(WIFI|CELLULAR|MOBILE)' | head -n 12
