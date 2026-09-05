#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - deterministic one-session worker v2.0
# Every process starts from the exported Scene launcher ActivityMain, discovers the
# clickable power-stat entry by resource-id, opens History, captures exactly one
# finalized >=30 min session, commits it to the manifest, then exits.
# No Back-based state recovery and no dependency on the previous worker's UI state.

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

get_bounds_for_id() {
  GB_FILE="$1"
  GB_ID="$2"
  nodes "$GB_FILE" | grep "resource-id=\"$GB_ID\"" | head -n1 | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p'
}

tap_id() {
  TI_FILE="$1"
  TI_ID="$2"
  TI_B="$(get_bounds_for_id "$TI_FILE" "$TI_ID")"
  set -- $TI_B
  [ "$#" -eq 4 ] || return 1
  input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 )) >/dev/null 2>&1
}

top_history_ready() {
  TH_FILE="$1"
  grep -q 'package="com.omarea.vtools"' "$TH_FILE" || return 1
  grep -q 'text="历史记录"' "$TH_FILE" || return 1
  TH_N="$TMP/top.nodes"
  nodes "$TH_FILE" > "$TH_N"
  grep 'resource-id="com.omarea.vtools:id/NewTag"' "$TH_N" | grep -q 'text="today"' || return 1
  TH_FIRST="$(grep 'resource-id="com.omarea.vtools:id/ItemTitle"' "$TH_N" | head -n1 | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
  case "$TH_FIRST" in ??:??:??) return 0;; *) return 1;; esac
}

prepare_history_from_launcher() {
  # ActivityPowerStat itself is non-exported. Start the exported launcher activity,
  # then use the verified clickable nav_power_utilization resource-id.
  am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n com.omarea.vtools/.activities.ActivityMain >/dev/null 2>&1 || {
    PREP_ERR=activity_main_start_failed
    return 1
  }
  sleep 2

  MAIN="$TMP/main.xml"
  dump "$MAIN" || { PREP_ERR=main_dump_failed; return 1; }
  grep -q 'package="com.omarea.vtools"' "$MAIN" || { PREP_ERR=scene_main_not_foreground; return 1; }
  grep -q 'resource-id="com.omarea.vtools:id/nav_power_utilization"' "$MAIN" || { PREP_ERR=power_entry_not_found; return 1; }
  tap_id "$MAIN" 'com.omarea.vtools:id/nav_power_utilization' || { PREP_ERR=power_entry_bad_bounds; return 1; }
  sleep 2

  POWER="$TMP/power.xml"
  dump "$POWER" || { PREP_ERR=power_dump_failed; return 1; }
  grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$POWER" || { PREP_ERR=powerstat_not_open; return 1; }
  tap_id "$POWER" 'com.omarea.vtools:id/action_history' || { PREP_ERR=history_button_bad_bounds; return 1; }
  sleep 2

  HIST="$TMP/history-0.xml"
  dump "$HIST" || { PREP_ERR=history_dump_failed; return 1; }
  top_history_ready "$HIST" || { PREP_ERR=history_top_validation_failed; return 1; }
  return 0
}

echo '# iQOO 12 Pro Scene capture-next worker v2.0'
PREP_ERR=''
prepare_history_from_launcher || {
  echo "ERROR prepare_history reason=${PREP_ERR:-unknown}"
  exit 10
}
echo 'History top verified. mode=launcher_resource_id'

FOUND=0
TARGET=''
TARGET_USED=''
TARGET_Y=''
HP=0

while [ "$HP" -lt "$MAX_HISTORY_PAGES" ]; do
  HXML="$TMP/history-$HP.xml"
  HN="$TMP/history-$HP.nodes"
  if [ "$HP" -gt 0 ]; then
    dump "$HXML" || { echo "ERROR history_dump_page_$HP"; exit 20; }
  fi
  grep -q 'text="历史记录"' "$HXML" || { echo "ERROR left_history_page_$HP"; exit 21; }
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
  done < "$HN"

  [ "$FOUND" -eq 1 ] && break
  HP=$((HP+1))
  [ "$HP" -ge "$MAX_HISTORY_PAGES" ] && break
  input swipe 720 2750 720 850 700 >/dev/null 2>&1
  sleep 1
done

[ "$FOUND" -eq 1 ] || {
  echo "NO_NEW_ELIGIBLE_SESSION scanned_pages=$((HP+1))"
  exit 0
}

echo "Selected: $TARGET used=${TARGET_USED}h history_page=$HP tap_y=$TARGET_Y"
input tap 700 "$TARGET_Y" >/dev/null 2>&1
sleep 2

VERIFY="$TMP/detail-verify.xml"
dump "$VERIFY" || { echo 'ERROR detail_verify_dump'; exit 30; }
grep -q 'package="com.omarea.vtools"' "$VERIFY" || { echo 'ERROR detail_scene_lost'; exit 31; }
grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$VERIFY" || { echo 'ERROR detail_not_open'; exit 32; }
grep -q 'text="历史记录"' "$VERIFY" && { echo 'ERROR still_on_history'; exit 33; }

SAFE="$(printf '%s' "$TARGET" | tr ' :' '--')"
# Raw captures are immutable: every successful acquisition receives a capture-id-qualified path.
DEST="$OUTDIR/detail-$SAFE-$RUN_ID.txt"
PART="$DEST.partial"
: > "$PART"
printf 'session_title=%s\ncapture_id=%s\ncapture_at=%s\n' "$TARGET" "$RUN_ID" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$PART"

DP=0
PREV=''
while [ "$DP" -lt "$MAX_DETAIL_PAGES" ]; do
  DXML="$TMP/detail-$DP.xml"
  DN="$TMP/detail-$DP.nodes"
  if [ "$DP" -eq 0 ]; then
    cp "$VERIFY" "$DXML"
  else
    dump "$DXML" || { rm -f "$PART"; echo "ERROR detail_dump_page_$DP"; exit 34; }
  fi

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

echo "CAPTURED session=$TARGET pages=$DP"
echo "file=$DEST"
echo 'DONE worker_exit=0'
