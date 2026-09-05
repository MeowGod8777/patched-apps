#!/system/bin/sh
# iQOO 12 Pro Scene capture-next worker v1.2
# One finalized session per process.
# v1.2 keeps an already-open, already-top History page instead of needlessly
# backing to the battery page and reopening History between batch children.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
MANIFEST="$BASE/sync_manifest.csv"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$BASE/worker_tmp/$RUN_ID"
mkdir -p "$OUTDIR" "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_PAGES=${SCENE_BATTERY_WORKER_HISTORY_PAGES:-3}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}

nodes() { sed 's/></>\n</g' "$1"; }
dump() { rm -f "$1"; uiautomator dump "$1" >/dev/null 2>&1 && [ -s "$1" ]; }
is_history() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'text="历史记录"' "$1"; }
is_battery() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$1"; }
is_detail() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$1" && ! grep -q 'text="历史记录"' "$1"; }

top_history_ready() {
  TH_FILE="$1"
  is_history "$TH_FILE" || return 1
  TH_N="$TMP/topcheck.nodes"
  nodes "$TH_FILE" > "$TH_N"
  grep 'resource-id="com.omarea.vtools:id/NewTag"' "$TH_N" | grep -q 'text="today"' || return 1
  TH_FIRST="$(grep 'resource-id="com.omarea.vtools:id/ItemTitle"' "$TH_N" | head -n1 | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
  case "$TH_FIRST" in ??:??:??) return 0;; *) return 1;; esac
}

prepare_top_history() {
  S="$TMP/state.xml"
  dump "$S" || { PREP_ERR=initial_dump; return 1; }
  grep -q 'package="com.omarea.vtools"' "$S" || { PREP_ERR=scene_not_foreground; return 1; }

  # Best path for batch mode: the previous worker already returned to History top.
  # Keep it. Do not bounce through the battery page unless the History list is stale/mid-list.
  if is_history "$S" && top_history_ready "$S"; then
    cp "$S" "$TMP/history-0.xml"
    PREP_MODE=reuse_top_history
    return 0
  fi

  # If we start in a detail page, return once to History first.
  if is_detail "$S"; then
    input keyevent 4 >/dev/null 2>&1
    sleep 1
    dump "$S" || { PREP_ERR=dump_after_detail_back; return 1; }
    if is_history "$S" && top_history_ready "$S"; then
      cp "$S" "$TMP/history-0.xml"
      PREP_MODE=detail_back_to_top_history
      return 0
    fi
  fi

  # A History page that is not at the top must be closed before reopening it.
  if is_history "$S"; then
    input keyevent 4 >/dev/null 2>&1
    sleep 1
    dump "$S" || { PREP_ERR=dump_after_history_back; return 1; }
  fi

  is_battery "$S" || { PREP_ERR=battery_main_not_reached; return 1; }
  input tap 1125 256 >/dev/null 2>&1
  sleep 2
  dump "$S" || { PREP_ERR=dump_after_open_history; return 1; }
  is_history "$S" || { PREP_ERR=history_not_open; return 1; }
  top_history_ready "$S" || { PREP_ERR=reopened_history_not_top; return 1; }
  cp "$S" "$TMP/history-0.xml"
  PREP_MODE=reopened_history
  return 0
}

echo '# iQOO 12 Pro Scene capture-next worker v1.2'
echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds...'
sleep 7
PREP_ERR=''
PREP_MODE=''
prepare_top_history || { echo "ERROR prepare_top_history reason=${PREP_ERR:-unknown}"; exit 10; }
echo "History top verified. mode=$PREP_MODE"

FOUND=0
TARGET=''
TARGET_USED=''
TARGET_Y=''
HP=0

while [ "$HP" -lt "$MAX_HISTORY_PAGES" ]; do
  HXML="$TMP/history-$HP.xml"
  HN="$TMP/history-$HP.nodes"
  if [ "$HP" -gt 0 ]; then dump "$HXML" || { echo "ERROR history_dump_page_$HP"; exit 20; }; fi
  is_history "$HXML" || { echo "ERROR left_history_page_$HP"; exit 21; }
  nodes "$HXML" > "$HN"

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
  input swipe 720 2750 720 850 700 >/dev/null 2>&1
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
DEST="$OUTDIR/detail-$SAFE.txt"
PART="$DEST.partial"
: > "$PART"
printf 'session_title=%s\ncapture_at=%s\n' "$TARGET" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$PART"

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

# Return to History and allow the transition to finish before the process exits.
input keyevent 4 >/dev/null 2>&1
sleep 1

echo "CAPTURED session=$TARGET pages=$DP"
echo "file=$DEST"
echo 'DONE worker_exit=0'
