#!/system/bin/sh
# Scene History -> detail capture probe for iQOO 12 Pro / Shizuku Runner.
# Purpose: verify that a finalized >=30 min history row can be clicked automatically,
# and that its detailed Scene page (summary + app list) can be captured.

BASE=/sdcard/SceneBattery
TMP="$BASE/detail_probe_tmp"
OUTDIR="$BASE/detail_raw"
mkdir -p "$TMP" "$OUTDIR"

CAPTURE_ID="$(date '+%Y%m%d-%H%M%S')"
HXML="$TMP/history.xml"
HNODES="$TMP/history.nodes"
DXML="$TMP/detail.xml"
DNODES="$TMP/detail.nodes"

extract_text() {
  printf '%s\n' "$1" | sed -n 's/.*text="\([^"]*\)".*/\1/p'
}

extract_bounds() {
  printf '%s\n' "$1" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p'
}

open_or_verify_history() {
  rm -f "$HXML"
  uiautomator dump "$HXML" >/dev/null 2>&1 || return 1
  sed 's/></>\n</g' "$HXML" > "$HNODES"

  if grep -q 'text="历史记录"' "$HNODES"; then
    return 0
  fi

  if grep -q 'text="耗电统计"' "$HNODES"; then
    # Tap History action in the top-right toolbar. Resource-id exists but input tap is
    # more reliable than trying to invoke accessibility action from shell.
    input tap 1125 250 >/dev/null 2>&1
    sleep 1
    rm -f "$HXML"
    uiautomator dump "$HXML" >/dev/null 2>&1 || return 1
    sed 's/></>\n</g' "$HXML" > "$HNODES"
    grep -q 'text="历史记录"' "$HNODES" && return 0
  fi

  return 1
}

echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds...'
sleep 7

if ! open_or_verify_history; then
  echo 'ERROR: History page not detected.'
  exit 1
fi

echo 'History detected. Looking for first finalized >=30 min row on the visible page...'

TITLE=''
BOUNDS=''
LIVE_FIRST=0
NEXT_IS_LIVE=0
FOUND=0
USED=''

while IFS= read -r LINE; do
  case "$LINE" in
    *'resource-id="com.omarea.vtools:id/NewTag"'*)
      TAG="$(extract_text "$LINE")"
      [ "$TAG" = 'today' ] && NEXT_IS_LIVE=1
      ;;
    *'resource-id="com.omarea.vtools:id/ItemTitle"'*)
      TITLE="$(extract_text "$LINE")"
      BOUNDS="$(extract_bounds "$LINE")"
      if [ "$NEXT_IS_LIVE" = 1 ]; then
        LIVE_FIRST=1
        NEXT_IS_LIVE=0
      else
        LIVE_FIRST=0
      fi
      ;;
    *'resource-id="com.omarea.vtools:id/ItemCenter"'*)
      [ -n "$TITLE" ] || continue
      CENTER="$(extract_text "$LINE")"
      USED="$(printf '%s' "$CENTER" | sed -n 's/^\([0-9][0-9.]*\)h.*/\1/p')"
      [ -n "$USED" ] || continue

      # Skip the current live row even if it is long enough; only probe a finalized row.
      if [ "$LIVE_FIRST" = 1 ]; then
        TITLE=''
        BOUNDS=''
        LIVE_FIRST=0
        continue
      fi

      if awk "BEGIN { exit !( $USED >= 0.5 ) }"; then
        FOUND=1
        break
      fi

      TITLE=''
      BOUNDS=''
      LIVE_FIRST=0
      ;;
  esac
done < "$HNODES"

if [ "$FOUND" != 1 ]; then
  echo 'ERROR: No finalized >=30 min row found on the visible History page.'
  echo 'Try scrolling History so an eligible row is visible, then rerun.'
  exit 2
fi

Y1="$(printf '%s' "$BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
Y2="$(printf '%s' "$BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
if [ -z "$Y1" ] || [ -z "$Y2" ]; then
  echo "ERROR: Could not parse row bounds: $BOUNDS"
  exit 3
fi
Y=$(( (Y1 + Y2) / 2 ))

SAFE_TITLE="$(printf '%s' "$TITLE" | sed 's/[^0-9A-Za-z_-]/-/g; s/--*/-/g')"
OUT="$OUTDIR/detail-${SAFE_TITLE}-${CAPTURE_ID}.txt"

echo "Selected: $TITLE  used=${USED}h  tap_y=$Y"
input tap 700 "$Y" >/dev/null 2>&1
sleep 2

rm -f "$DXML"
uiautomator dump "$DXML" >/dev/null 2>&1 || {
  echo 'ERROR: Detail dump failed.'
  exit 4
}
sed 's/></>\n</g' "$DXML" > "$DNODES"

if ! grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$DNODES"; then
  echo 'ERROR: Click did not open a Scene detail page.'
  echo 'Current top texts:'
  grep -E 'text="[^"]+"' "$DNODES" | head -n 20
  exit 5
fi

{
  printf '# Scene finalized history detail capture\n'
  printf 'history_title=%s\n' "$TITLE"
  printf 'history_used_hours=%s\n' "$USED"
  printf 'captured_at=%s\n\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
  cat "$DNODES"
} > "$OUT"

echo 'DETAIL CAPTURE OK'
echo "file=$OUT"
echo '----- SUMMARY -----'
grep -E 'resource-id="com.omarea.vtools:id/(avg_power|screen_on_duration|predict_time|battery_capacity|battery_temperature|itemTitle|itemCounts|itemAvgIO)"' "$DNODES" | head -n 80

# Return to History so the UI is not left inside an old detail session.
input keyevent 4 >/dev/null 2>&1
