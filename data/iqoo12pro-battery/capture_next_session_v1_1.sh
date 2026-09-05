#!/system/bin/sh
# iQOO 12 Pro Scene capture-next worker v1.1.1
# One finalized session per process. No long-lived queue/recovery state.
# v1.1.1 keeps the proven manual handoff path, adds overlapping History pagination
# so rows cannot fall between pages, and makes raw detail captures immutable.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
MANIFEST="$BASE/sync_manifest.csv"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$BASE/worker_tmp/$RUN_ID"
mkdir -p "$OUTDIR" "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_PAGES=${SCENE_BATTERY_WORKER_HISTORY_PAGES:-12}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}
HISTORY_SWIPE_START=${SCENE_BATTERY_HISTORY_SWIPE_START:-2600}
HISTORY_SWIPE_END=${SCENE_BATTERY_HISTORY_SWIPE_END:-1700}

nodes() { sed 's/></>\n</g' "$1"; }
dump() { rm -f "$1"; uiautomator dump "$1" >/dev/null 2>&1 && [ -s "$1" ]; }

is_history() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'text="历史记录"' "$1"; }
is_battery() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$1"; }

open_fresh_history() {
  S="$TMP/state.xml"
  dump "$S" || return 1
  grep -q 'package="com.omarea.vtools"' "$S" || return 1

  if is_history "$S"; then
    input keyevent 4 >/dev/null 2>&1
    sleep 1
    dump "$S" || return 1
  fi

  if ! is_battery "$S"; then
    input keyevent 4 >/dev/null 2>&1
    sleep 1
    dump "$S" || return 1
  fi

  is_battery "$S" || return 1
  input tap 1125 256 >/dev/null 2>&1
  sleep 2
  dump "$S" || return 1
  is_history "$S" || return 1

  # Robust top check: inspect split UI nodes instead of relying on BRE alternation.
  N="$TMP/top.nodes"
  nodes "$S" > "$N"
  grep 'resource-id="com.omarea.vtools:id/NewTag"' "$N" | grep -q 'text="today"' || return 2
  FIRST="$(grep 'resource-id="com.omarea.vtools:id/ItemTitle"' "$N" | head -n1 | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
  case "$FIRST" in
    ??:??:??) ;;
    *) return 2;;
  esac
  cp "$S" "$TMP/history-0.xml"
  return 0
}

echo '# iQOO 12 Pro Scene capture-next worker v1.1.1'
echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds...'
sleep 7
open_fresh_history
RC=$?
[ "$RC" -eq 0 ] || {
  [ "$RC" -eq 2 ] && echo 'ERROR history_top_validation_failed' || echo 'ERROR could_not_open_fresh_history'
  exit 10
}
echo 'History top verified.'

FOUND=0
TARGET=''
TARGET_USED=''
TARGET_Y=''
HP=0
PREV_HISTORY_SIG=''

while [ "$HP" -lt "$MAX_HISTORY_PAGES" ]; do
  HXML="$TMP/history-$HP.xml"
  HN="$TMP/history-$HP.nodes"
  if [ "$HP" -gt 0 ]; then dump "$HXML" || { echo "ERROR history_dump_page_$HP"; exit 20; }; fi
  is_history "$HXML" || { echo "ERROR left_history_page_$HP"; exit 21; }
  nodes "$HXML" > "$HN"

  HISTORY_SIG="$(cksum "$HN" 2>/dev/null | awk '{print $1":"$2}')"
  if [ "$HP" -gt 0 ] && [ -n "$PREV_HISTORY_SIG" ] && [ "$HISTORY_SIG" = "$PREV_HISTORY_SIG" ]; then
    break
  fi
  PREV_HISTORY_SIG="$HISTORY_SIG"

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
        case "$ROW_TITLE" in ????-??-??\ ??:??) ;; *) ROW_TITLE=''; ROW_BOUNDS=''; continue;; esac
        CENTER="$(printf '%s\n' "$LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        USED_H="$(printf '%s' "$CENTER" | sed -n 's/^\([0-9][0-9.]*\)h.*/\1/p')"
        [ -n "$USED_H" ] || { ROW_TITLE=''; ROW_BOUNDS=''; continue; }
        USED_MIN="$(awk -v h="$USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
        [ "$USED_MIN" -ge "$MIN_MINUTES" ] || { ROW_TITLE=''; ROW_BOUNDS=''; continue; }
        if [ -f "$MANIFEST" ] && grep -Fq "\"$ROW_TITLE\",captured" "$MANIFEST"; then ROW_TITLE=''; ROW_BOUNDS=''; continue; fi
        Y1="$(printf '%s' "$ROW_BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
        Y2="$(printf '%s' "$ROW_BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
        [ -n "$Y1" ] && [ -n "$Y2" ] || { echo "ERROR bad_bounds_$ROW_TITLE"; exit 22; }
        TARGET="$ROW_TITLE"; TARGET_USED="$USED_H"; TARGET_Y=$(( (Y1 + Y2) / 2 )); FOUND=1; break
        ;;
    esac
  done < "$HN"

  [ "$FOUND" -eq 1 ] && break
  HP=$((HP+1))
  [ "$HP" -ge "$MAX_HISTORY_PAGES" ] && break
  # Deliberately small overlapping scroll. The old 2750->850 jump could skip
  # entire rows at a page boundary; 2600->1700 retains a large overlap.
  input swipe 720 "$HISTORY_SWIPE_START" 720 "$HISTORY_SWIPE_END" 550 >/dev/null 2>&1
  sleep 1
done

[ "$FOUND" -eq 1 ] || { echo "NO_NEW_ELIGIBLE_SESSION scanned_pages=$((HP+1))"; exit 0; }
echo "Selected: $TARGET used=${TARGET_USED}h history_page=$HP tap_y=$TARGET_Y"
input tap 700 "$TARGET_Y" >/dev/null 2>&1
sleep 2

VERIFY="$TMP/detail-verify.xml"
dump "$VERIFY" || { echo 'ERROR detail_verify_dump'; exit 30; }
grep -q 'package="com.omarea.vtools"' "$VERIFY" || { echo 'ERROR detail_scene_lost'; exit 31; }
grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$VERIFY" || { echo 'ERROR detail_not_open'; exit 32; }
grep -q 'text="历史记录"' "$VERIFY" && { echo 'ERROR still_on_history'; exit 33; }

SAFE="$(printf '%s' "$TARGET" | tr ' :' '--')"
# Raw captures are immutable. A rerun can never overwrite a previous acquisition.
DEST="$OUTDIR/detail-$SAFE-$RUN_ID.txt"
PART="$DEST.partial"
: > "$PART"
printf 'session_title=%s\ncapture_id=%s\ncapture_at=%s\n' "$TARGET" "$RUN_ID" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$PART"

DP=0
PREV=''
while [ "$DP" -lt "$MAX_DETAIL_PAGES" ]; do
  DXML="$TMP/detail-$DP.xml"
  DN="$TMP/detail-$DP.nodes"
  if [ "$DP" -eq 0 ]; then cp "$VERIFY" "$DXML"; else dump "$DXML" || { rm -f "$PART"; echo "ERROR detail_dump_page_$DP"; exit 34; }; fi
  grep -q 'package="com.omarea.vtools"' "$DXML" || { rm -f "$PART"; echo 'ERROR detail_scene_lost_during_capture'; exit 35; }
  grep -q 'text="历史记录"' "$DXML" && { rm -f "$PART"; echo 'ERROR detail_returned_to_history_early'; exit 36; }
  nodes "$DXML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$DN" || :
  HASH="$(cksum "$DN" 2>/dev/null | awk '{print $1":"$2}')"
  [ -n "$PREV" ] && [ "$HASH" = "$PREV" ] && break
  printf '\n===== DETAIL PAGE %02d =====\n' "$DP" >> "$PART"
  cat "$DN" >> "$PART"
  PREV="$HASH"
  DP=$((DP+1))
  [ "$DP" -ge "$MAX_DETAIL_PAGES" ] && break
  input swipe 720 2800 720 900 650 >/dev/null 2>&1
  sleep 1
done

grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$PART" || { rm -f "$PART"; echo 'ERROR missing_avg_power'; exit 40; }
grep -q 'resource-id="com.omarea.vtools:id/screen_on_duration"' "$PART" || { rm -f "$PART"; echo 'ERROR missing_screen_on_duration'; exit 41; }
grep -q 'resource-id="com.omarea.vtools:id/predict_time"' "$PART" || { rm -f "$PART"; echo 'ERROR missing_predict_time'; exit 42; }

mv "$PART" "$DEST"
[ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
printf '"%s",captured,"%s",%s\n' "$TARGET" "$DEST" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
input keyevent 4 >/dev/null 2>&1

echo "CAPTURED session=$TARGET pages=$DP"
echo "file=$DEST"
echo 'DONE worker_exit=0'
