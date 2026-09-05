#!/system/bin/sh
# Scene History raw capture v0.2 for iQOO 12 Pro / Shizuku Runner.
# User only needs to switch to Scene -> 耗电统计 main page within 7 seconds.
# Script verifies the page, opens History itself, verifies "历史记录", then captures/scrolls.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/history_raw"
TMP="$BASE/history_tmp"
mkdir -p "$OUTDIR" "$TMP"

CAPTURE_ID="$(date '+%Y%m%d-%H%M%S')"
OUT="$OUTDIR/history-${CAPTURE_ID}.txt"
DEBUG="$TMP/entry-${CAPTURE_ID}.xml"
MAX_PAGES=${SCENE_HISTORY_MAX_PAGES:-12}

rm -f "$OUT" "$DEBUG"
printf '# Scene history raw capture\n' > "$OUT"
printf 'capture_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$OUT"
printf 'format=v0.2-ui-node-lines\n\n' >> "$OUT"

page_dump() {
  TARGET="$1"
  rm -f "$TARGET"
  uiautomator dump "$TARGET" >/dev/null 2>&1
}

is_history() {
  grep -q 'package="com.omarea.vtools"' "$1" 2>/dev/null && \
  grep -q 'text="历史记录"' "$1" 2>/dev/null
}

is_battery_main() {
  grep -q 'package="com.omarea.vtools"' "$1" 2>/dev/null && \
  grep -q 'text="耗电统计"' "$1" 2>/dev/null
}

echo "Switch to Scene -> 耗电统计 within 7 seconds..."
sleep 7

page_dump "$DEBUG" || {
  echo "ERROR: initial uiautomator dump failed"
  exit 1
}

if is_history "$DEBUG"; then
  echo "History page already open."
elif is_battery_main "$DEBUG"; then
  echo "Battery page detected; opening History..."
  # action_history was verified at bounds [1020,166][1230,346] on this 1440x3200 device.
  input tap 1125 256 >/dev/null 2>&1
  sleep 2
  page_dump "$DEBUG" || {
    echo "ERROR: dump failed after opening History"
    exit 1
  }
  if ! is_history "$DEBUG"; then
    echo "ERROR: History did not open; refusing to capture wrong page."
    echo "debug=$DEBUG"
    exit 2
  fi
else
  echo "ERROR: Scene 耗电统计 page not detected; refusing to capture wrong app/page."
  echo "debug=$DEBUG"
  exit 3
fi

echo "History verified. Capturing..."

PREV_HASH=''
PAGE=0
while [ "$PAGE" -lt "$MAX_PAGES" ]; do
  XML="$TMP/page-${PAGE}.xml"
  NODES="$TMP/page-${PAGE}.nodes"

  page_dump "$XML" || {
    echo "ERROR: uiautomator dump failed on page $PAGE"
    break
  }

  if ! is_history "$XML"; then
    printf '\n# STOP left_history_page=%s\n' "$PAGE" >> "$OUT"
    echo "ERROR: left History page during capture at page $PAGE"
    break
  fi

  sed 's/></>\n</g' "$XML" | grep -E 'text="[^"]+"' > "$NODES"
  HASH="$(sha256sum "$NODES" 2>/dev/null | awk '{print $1}')"

  if [ -n "$PREV_HASH" ] && [ "$HASH" = "$PREV_HASH" ]; then
    printf '\n# STOP repeated_page=%s hash=%s\n' "$PAGE" "$HASH" >> "$OUT"
    break
  fi

  printf '\n===== PAGE %02d =====\n' "$PAGE" >> "$OUT"
  cat "$NODES" >> "$OUT"
  PREV_HASH="$HASH"

  PAGE=$((PAGE + 1))
  [ "$PAGE" -ge "$MAX_PAGES" ] && break

  input swipe 720 2750 720 850 700 >/dev/null 2>&1
  sleep 1

done

printf '\n# pages_captured=%s\n' "$PAGE" >> "$OUT"
printf '# finished_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$OUT"

echo "DONE"
echo "file=$OUT"
echo "pages=$PAGE"
echo "----- QUICK VIEW -----"
grep -E 'text="(历史记录|today|20[0-9]{2}-|[0-9]+\.[0-9]+W[^\"]*|理论续航[^\"]*|理論續航[^\"]*|[0-9]+\.?[0-9]*h / [0-9]+\.?[0-9]*h)' "$OUT" | head -n 120
