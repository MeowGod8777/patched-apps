#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - capture exactly one finalized session, then exit.
# Design: no long-lived full-sync state machine, no queue relocation, no recovery loop.
# Start from Scene -> 耗电统计 or 历史记录. The script normalizes to a fresh History view,
# scans at most a few recent pages, taps the first uncaptured >=30 min finalized row in-place,
# captures its full detail list, records success, returns once, and exits.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
MANIFEST="$BASE/sync_manifest.csv"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$BASE/worker_tmp/$RUN_ID"
mkdir -p "$OUTDIR" "$TMP"

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_PAGES=${SCENE_BATTERY_WORKER_HISTORY_PAGES:-3}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}

cleanup() { rm -rf "$TMP" 2>/dev/null; }
trap cleanup EXIT HUP INT TERM

echo '# iQOO 12 Pro Scene capture-next worker v1.0'
echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds...'
sleep 7

# ---------- Normalize to a fresh History page ----------
STATE="$TMP/state.xml"
rm -f "$STATE"
uiautomator dump "$STATE" >/dev/null 2>&1 || { echo 'ERROR initial_ui_dump'; exit 10; }
[ -s "$STATE" ] || { echo 'ERROR initial_ui_empty'; exit 11; }
grep -q 'package="com.omarea.vtools"' "$STATE" || { echo 'ERROR scene_not_foreground'; exit 12; }

# If History is already open, close it first. Reopening is more deterministic than trying to
# reverse-scroll an unknown list position.
if grep -q 'text="历史记录"' "$STATE"; then
  input keyevent 4 >/dev/null 2>&1
  sleep 1
  rm -f "$STATE"
  uiautomator dump "$STATE" >/dev/null 2>&1 || { echo 'ERROR dump_after_history_back'; exit 13; }
fi

# If this is an old detail page rather than the battery main page, back out once more.
if ! grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$STATE"; then
  input keyevent 4 >/dev/null 2>&1
  sleep 1
  rm -f "$STATE"
  uiautomator dump "$STATE" >/dev/null 2>&1 || { echo 'ERROR dump_after_detail_back'; exit 14; }
fi

grep -q 'package="com.omarea.vtools"' "$STATE" || { echo 'ERROR scene_lost_during_normalize'; exit 15; }
grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$STATE" || { echo 'ERROR battery_main_not_reached'; exit 16; }

input tap 1125 256 >/dev/null 2>&1
sleep 2
rm -f "$STATE"
uiautomator dump "$STATE" >/dev/null 2>&1 || { echo 'ERROR dump_after_open_history'; exit 17; }
grep -q 'text="历史记录"' "$STATE" || { echo 'ERROR history_not_open'; exit 18; }

# Freshly opened History must expose the top/live marker. Fail quickly rather than silently
# starting from a stale mid-list position.
if ! grep -q 'resource-id="com.omarea.vtools:id/NewTag"[^>]*text="today"\|text="today"[^>]*resource-id="com.omarea.vtools:id/NewTag"' "$STATE"; then
  echo 'ERROR history_not_at_top'
  exit 19
fi

echo 'History top verified.'

# ---------- Scan recent pages and tap the first uncaptured eligible row in-place ----------
FOUND=0
TARGET=''
TARGET_USED=''
TARGET_Y=''
HP=0

while [ "$HP" -lt "$MAX_HISTORY_PAGES" ]; do
  HXML="$TMP/history-$HP.xml"
  HNODES="$TMP/history-$HP.nodes"
  if [ "$HP" -eq 0 ]; then
    cp "$STATE" "$HXML"
  else
    rm -f "$HXML"
    uiautomator dump "$HXML" >/dev/null 2>&1 || { echo "ERROR history_dump_page_$HP"; exit 20; }
  fi
  grep -q 'text="历史记录"' "$HXML" || { echo "ERROR left_history_page_$HP"; exit 21; }
  sed 's/></>\n</g' "$HXML" > "$HNODES"

  ROW_TITLE=''
  ROW_BOUNDS=''
  while IFS= read -r LINE; do
    case "$LINE" in
      *'resource-id="com.omarea.vtools:id/ItemTitle"'*)
        ROW_TITLE="$(printf '%s\n' "$LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        ROW_BOUNDS="$(printf '%s\n' "$LINE" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p')"
        ;;
      *'resource-id="com.omarea.vtools:id/ItemCenter"'*)
        [ -n "$ROW_TITLE" ] || continue
        case "$ROW_TITLE" in
          ????-??-??\ ??:??) ;;
          *) ROW_TITLE=''; ROW_BOUNDS=''; continue;;
        esac

        CENTER="$(printf '%s\n' "$LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        USED_H="$(printf '%s' "$CENTER" | sed -n 's/^\([0-9][0-9.]*\)h.*/\1/p')"
        [ -n "$USED_H" ] || { ROW_TITLE=''; ROW_BOUNDS=''; continue; }
        USED_MIN="$(awk -v h="$USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
        [ "$USED_MIN" -ge "$MIN_MINUTES" ] || { ROW_TITLE=''; ROW_BOUNDS=''; continue; }

        if [ -f "$MANIFEST" ] && grep -Fq "\"$ROW_TITLE\",captured" "$MANIFEST"; then
          ROW_TITLE=''; ROW_BOUNDS=''; continue
        fi

        Y1="$(printf '%s' "$ROW_BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
        Y2="$(printf '%s' "$ROW_BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
        [ -n "$Y1" ] && [ -n "$Y2" ] || { echo "ERROR bad_bounds_$ROW_TITLE"; exit 22; }

        TARGET="$ROW_TITLE"
        TARGET_USED="$USED_H"
        TARGET_Y=$(( (Y1 + Y2) / 2 ))
        FOUND=1
        break
        ;;
    esac
  done < "$HNODES"

  [ "$FOUND" -eq 1 ] && break
  HP=$((HP+1))
  [ "$HP" -ge "$MAX_HISTORY_PAGES" ] && break
  input swipe 720 2750 720 850 700 >/dev/null 2>&1
  sleep 1

done

if [ "$FOUND" -ne 1 ]; then
  echo "NO_NEW_ELIGIBLE_SESSION scanned_pages=$((HP+1))"
  exit 0
fi

echo "Selected: $TARGET used=${TARGET_USED}h history_page=$HP tap_y=$TARGET_Y"
input tap 700 "$TARGET_Y" >/dev/null 2>&1
sleep 2

# ---------- Verify detail ----------
VERIFY="$TMP/detail-verify.xml"
rm -f "$VERIFY"
uiautomator dump "$VERIFY" >/dev/null 2>&1 || { echo 'ERROR detail_verify_dump'; exit 30; }
grep -q 'package="com.omarea.vtools"' "$VERIFY" || { echo 'ERROR detail_scene_lost'; exit 31; }
grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$VERIFY" || { echo 'ERROR detail_not_open'; exit 32; }
grep -q 'text="历史记录"' "$VERIFY" && { echo 'ERROR still_on_history'; exit 33; }

# ---------- Capture full detail, in this worker only ----------
SAFE="$(printf '%s' "$TARGET" | tr ' :' '--')"
DEST="$OUTDIR/detail-$SAFE.txt"
PART="$DEST.partial"
: > "$PART"
printf 'session_title=%s\ncapture_at=%s\n' "$TARGET" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$PART"

DP=0
PREV=''
while [ "$DP" -lt "$MAX_DETAIL_PAGES" ]; do
  DXML="$TMP/detail-$DP.xml"
  DNODES="$TMP/detail-$DP.nodes"
  if [ "$DP" -eq 0 ]; then
    cp "$VERIFY" "$DXML"
  else
    rm -f "$DXML"
    uiautomator dump "$DXML" >/dev/null 2>&1 || { rm -f "$PART"; echo "ERROR detail_dump_page_$DP"; exit 34; }
  fi

  grep -q 'package="com.omarea.vtools"' "$DXML" || { rm -f "$PART"; echo 'ERROR detail_scene_lost_during_capture'; exit 35; }
  grep -q 'text="历史记录"' "$DXML" && { rm -f "$PART"; echo 'ERROR detail_returned_to_history_early'; exit 36; }

  sed 's/></>\n</g' "$DXML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$DNODES" || :
  HASH="$(cksum "$DNODES" 2>/dev/null | awk '{print $1":"$2}')"
  if [ -n "$PREV" ] && [ "$HASH" = "$PREV" ]; then break; fi

  printf '\n===== DETAIL PAGE %02d =====\n' "$DP" >> "$PART"
  cat "$DNODES" >> "$PART"
  PREV="$HASH"
  DP=$((DP+1))
  [ "$DP" -ge "$MAX_DETAIL_PAGES" ] && break
  input swipe 720 2800 720 900 650 >/dev/null 2>&1
  sleep 1
done

# Formal-metric integrity check before committing the raw detail file / manifest state.
grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$PART" || { rm -f "$PART"; echo 'ERROR missing_avg_power'; exit 40; }
grep -q 'resource-id="com.omarea.vtools:id/screen_on_duration"' "$PART" || { rm -f "$PART"; echo 'ERROR missing_screen_on_duration'; exit 41; }
grep -q 'resource-id="com.omarea.vtools:id/predict_time"' "$PART" || { rm -f "$PART"; echo 'ERROR missing_predict_time'; exit 42; }

mv "$PART" "$DEST"
[ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
printf '"%s",captured,"%s",%s\n' "$TARGET" "$DEST" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"

# Return once, do not continue into another session in the same process.
input keyevent 4 >/dev/null 2>&1

echo "CAPTURED session=$TARGET pages=$DP"
echo "file=$DEST"
echo 'DONE worker_exit=0'
