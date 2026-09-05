#!/system/bin/sh
# Scene History raw capture for Shizuku Runner.
# Run, then switch to Scene -> 耗电统计 -> 历史记录 within 7 seconds.
# Captures visible history rows, auto-scrolls, and preserves raw UI nodes.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/history_raw"
TMP="$BASE/history_tmp"
mkdir -p "$OUTDIR" "$TMP"

CAPTURE_ID="$(date '+%Y%m%d-%H%M%S')"
OUT="$OUTDIR/history-${CAPTURE_ID}.txt"
MAX_PAGES=${SCENE_HISTORY_MAX_PAGES:-12}

rm -f "$OUT"
printf '# Scene history raw capture\n' > "$OUT"
printf 'capture_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$OUT"
printf 'format=v0-ui-node-lines\n\n' >> "$OUT"

echo "Switch to Scene -> 耗电统计 -> 历史记录 within 7 seconds..."
sleep 7

PREV_HASH=''
PAGE=0
while [ "$PAGE" -lt "$MAX_PAGES" ]; do
  XML="$TMP/page-${PAGE}.xml"
  rm -f "$XML"
  uiautomator dump "$XML" >/dev/null 2>&1 || {
    echo "ERROR: uiautomator dump failed on page $PAGE"
    break
  }

  # Hash only meaningful text-bearing nodes, not the entire hierarchy metadata.
  NODES="$TMP/page-${PAGE}.nodes"
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

  # 1440x3200 device; swipe within the central list area.
  input swipe 720 2750 720 900 650 >/dev/null 2>&1
  sleep 1

done

printf '\n# pages_captured=%s\n' "$PAGE" >> "$OUT"
printf '# finished_at=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$OUT"

echo "DONE"
echo "file=$OUT"
echo "pages=$PAGE"
echo "----- QUICK VIEW -----"
grep -E 'text="(today|20[0-9]{2}-|[0-9]+\.[0-9]+W|理论续航|理論續航|[0-9]+\.?[0-9]*h / [0-9]+\.?[0-9]*h)' "$OUT" | head -n 80
