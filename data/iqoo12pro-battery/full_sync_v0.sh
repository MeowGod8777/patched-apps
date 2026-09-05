#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger full local sync v0.7-serial
# - Prevent concurrent full-sync instances from racing on UI/tmp files.
# - Uses a per-run tmp directory.
# - Verifies History is really at the top before indexing/locating.
# - Compact output: no giant Eligible list.
# - Builds a bounded queue before touching detail rows.
# - Uses a verified BACK from detail to History, then falls back to toolbar recovery.
# GitHub upload intentionally not included yet.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
TMPROOT="$BASE/sync_tmp"
MANIFEST="$BASE/sync_manifest.csv"
LOCKDIR="$BASE/.full_sync_lock"
mkdir -p "$OUTDIR" "$TMPROOT"

MIN_FINAL_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_PAGES=${SCENE_BATTERY_MAX_HISTORY_PAGES:-12}
INCREMENTAL_HISTORY_PAGES=${SCENE_BATTERY_INCREMENTAL_HISTORY_PAGES:-4}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}
MAX_NEW_SESSIONS=${SCENE_BATTERY_MAX_NEW_SESSIONS:-0}
RECOVERY_WAIT_SECONDS=${SCENE_BATTERY_RECOVERY_WAIT_SECONDS:-60}
UI_RETRIES=${SCENE_BATTERY_UI_RETRIES:-3}
PAGE_ROW_RETRIES=${SCENE_BATTERY_PAGE_ROW_RETRIES:-4}
TOP_MAX_SWIPES=${SCENE_BATTERY_TOP_MAX_SWIPES:-18}
TAB="$(printf '\t')"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$TMPROOT/$RUN_ID"
mkdir -p "$TMP"

cleanup() {
  rm -rf "$TMP" >/dev/null 2>&1
  if [ -f "$LOCKDIR/pid" ] && [ "$(cat "$LOCKDIR/pid" 2>/dev/null)" = "$$" ]; then
    rm -rf "$LOCKDIR" >/dev/null 2>&1
  fi
}
trap cleanup 0 1 2 15

acquire_lock() {
  if mkdir "$LOCKDIR" 2>/dev/null; then
    echo "$$" > "$LOCKDIR/pid"
    return 0
  fi
  OLD_PID="$(cat "$LOCKDIR/pid" 2>/dev/null)"
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "ERROR: another full_sync_v0.sh is already running (pid=$OLD_PID)"
    return 1
  fi
  rm -rf "$LOCKDIR" >/dev/null 2>&1
  if mkdir "$LOCKDIR" 2>/dev/null; then
    echo "$$" > "$LOCKDIR/pid"
    return 0
  fi
  echo 'ERROR: could not acquire full-sync lock'
  return 1
}

now_iso() { date '+%Y-%m-%dT%H:%M:%S%z'; }

dump_ui() {
  DUMP_PATH="$1"
  DUMP_I=0
  while [ "$DUMP_I" -lt "$UI_RETRIES" ]; do
    rm -f "$DUMP_PATH"
    if uiautomator dump "$DUMP_PATH" >/dev/null 2>&1 && [ -s "$DUMP_PATH" ]; then return 0; fi
    DUMP_I=$((DUMP_I+1))
    sleep 1
  done
  return 1
}

screen_kind() {
  STATE_XML="$TMP/state.xml"
  if ! dump_ui "$STATE_XML"; then echo unknown; return; fi
  if grep -q 'package="com.omarea.vtools"' "$STATE_XML"; then
    if grep -q 'text="历史记录"' "$STATE_XML"; then echo history
    elif grep -q 'text="耗电统计"' "$STATE_XML" || grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$STATE_XML"; then echo battery
    else echo scene_other; fi
  else echo other_app; fi
}

wait_for_scene() {
  WAIT_KIND="$(screen_kind)"
  case "$WAIT_KIND" in battery|history) return 0;; esac
  echo "WAIT: Scene is not on 耗电统计/历史记录. Reopen Scene -> 耗电统计; waiting up to ${RECOVERY_WAIT_SECONDS}s..."
  WAIT_ELAPSED=0
  while [ "$WAIT_ELAPSED" -lt "$RECOVERY_WAIT_SECONDS" ]; do
    sleep 2
    WAIT_ELAPSED=$((WAIT_ELAPSED+2))
    WAIT_KIND="$(screen_kind)"
    case "$WAIT_KIND" in battery|history) echo "RECOVERED: Scene detected ($WAIT_KIND)."; return 0;; esac
  done
  echo 'ERROR: Scene recovery timeout.'
  return 1
}

open_history() {
  OPEN_ATTEMPT=1
  while [ "$OPEN_ATTEMPT" -le 3 ]; do
    wait_for_scene || return 1
    OPEN_KIND="$(screen_kind)"
    [ "$OPEN_KIND" = history ] && return 0
    input tap 1125 255 >/dev/null 2>&1
    OPEN_P=0
    while [ "$OPEN_P" -lt 6 ]; do
      sleep 1
      OPEN_KIND="$(screen_kind)"
      [ "$OPEN_KIND" = history ] && return 0
      [ "$OPEN_KIND" = other_app ] && break
      OPEN_P=$((OPEN_P+1))
    done
    echo "WARN: History open attempt $OPEN_ATTEMPT failed; retrying..."
    OPEN_ATTEMPT=$((OPEN_ATTEMPT+1))
  done
  return 1
}

history_at_top() {
  TOP_XML="$TMP/top-check.xml"
  dump_ui "$TOP_XML" || return 1
  grep -q 'text="历史记录"' "$TOP_XML" || return 1
  if grep -q 'resource-id="com.omarea.vtools:id/NewTag"' "$TOP_XML" || grep -q 'text="today"' "$TOP_XML"; then return 0; fi
  return 1
}

history_to_top() {
  open_history || return 1
  TOP_I=0
  while [ "$TOP_I" -le "$TOP_MAX_SWIPES" ]; do
    if history_at_top; then return 0; fi
    input swipe 720 850 720 2850 420 >/dev/null 2>&1
    sleep 1
    TOP_I=$((TOP_I+1))
  done
  echo 'ERROR: History could not be verified at top'
  return 1
}

extract_history_nodes() {
  EH_XML="$1"
  EH_NODES="$2"
  sed 's/></>\n</g' "$EH_XML" | grep -E 'ItemTitle|ItemStart|ItemCenter|ItemEnd|NewTag|dialogTitle' > "$EH_NODES" || :
  grep -qE 'ItemTitle|ItemStart|ItemCenter|ItemEnd' "$EH_NODES"
}

capture_history_pages() {
  CH_DEST="$1"
  : > "$CH_DEST"
  CH_PREV=''
  CH_PAGE=0
  history_to_top || return 1

  CH_LIMIT="$MAX_HISTORY_PAGES"
  if [ "$MAX_NEW_SESSIONS" -gt 0 ] && [ "$INCREMENTAL_HISTORY_PAGES" -lt "$CH_LIMIT" ]; then
    CH_LIMIT="$INCREMENTAL_HISTORY_PAGES"
  fi

  while [ "$CH_PAGE" -lt "$CH_LIMIT" ]; do
    CH_XML="$TMP/h-$CH_PAGE.xml"
    CH_NODES="$TMP/h-$CH_PAGE.nodes"
    CH_ROWTRY=1
    CH_GOT_ROWS=0
    while [ "$CH_ROWTRY" -le "$PAGE_ROW_RETRIES" ]; do
      if ! dump_ui "$CH_XML"; then
        CH_ROWTRY=$((CH_ROWTRY+1)); sleep 1; continue
      fi
      [ -s "$CH_XML" ] || { CH_ROWTRY=$((CH_ROWTRY+1)); sleep 1; continue; }
      grep -q 'package="com.omarea.vtools"' "$CH_XML" || return 1
      grep -q 'text="历史记录"' "$CH_XML" || return 1
      if extract_history_nodes "$CH_XML" "$CH_NODES"; then CH_GOT_ROWS=1; break; fi
      echo "WARN: History page $CH_PAGE exposed no rows (try $CH_ROWTRY/$PAGE_ROW_RETRIES); waiting..."
      CH_ROWTRY=$((CH_ROWTRY+1))
      sleep 1
    done
    [ "$CH_GOT_ROWS" -eq 1 ] || { echo "ERROR: History page $CH_PAGE remained row-empty"; return 1; }

    CH_HASH="$(cksum "$CH_NODES" 2>/dev/null | awk '{print $1":"$2}')"
    [ -n "$CH_PREV" ] && [ "$CH_HASH" = "$CH_PREV" ] && break
    printf '\n===== PAGE %02d =====\n' "$CH_PAGE" >> "$CH_DEST"
    cat "$CH_NODES" >> "$CH_DEST"
    CH_PREV="$CH_HASH"
    CH_PAGE=$((CH_PAGE+1))
    [ "$CH_PAGE" -ge "$CH_LIMIT" ] && break
    input swipe 720 2750 720 800 650 >/dev/null 2>&1
    sleep 1
  done
  HISTORY_PAGES="$CH_PAGE"
  return 0
}

parse_history_candidates() {
  PH_SRC="$1"
  PH_DEST="$2"
  PH_ALL="$TMP/candidates-all.tsv"
  awk '
    function textval(line,  x){ x=line; sub(/^.*text="/,"",x); sub(/" resource-id=.*$/,"",x); return x }
    /id\/ItemTitle"/ { title=textval($0); next }
    /id\/ItemStart"/ {
      v=textval($0); split(v,a,"W"); avg=a[1]; gsub(/^ +| +$/,"",avg);
      pct=v; sub(/^.*W +/,"",pct); sub(/%\/h.*$/,"",pct); gsub(/^-/,"",pct); next
    }
    /id\/ItemCenter"/ {
      v=textval($0); split(v,a,"/"); used=a[1]; elapsed=a[2];
      gsub(/[ h]/,"",used); gsub(/[ h]/,"",elapsed); next
    }
    /id\/ItemEnd"/ {
      v=textval($0); p=v; sub(/^.*: /,"",p); sub(/h$/,"",p);
      if (title != "") print title "\t" used "\t" elapsed "\t" avg "\t" pct "\t" p;
      title=""; used=""; elapsed=""; avg=""; pct=""; p=""; next
    }
  ' "$PH_SRC" | awk -F '\t' '!seen[$1]++' > "$PH_ALL"
  grep -E '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9][[:space:]]' "$PH_ALL" > "$PH_DEST" || :
}

is_already_done() {
  IAD_TITLE="$1"
  [ -f "$MANIFEST" ] && grep -Fq "\"$IAD_TITLE\",captured" "$MANIFEST"
}

mark_manifest() {
  MM_TITLE="$1"
  MM_STATE="$2"
  MM_FILE="$3"
  [ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
  printf '"%s",%s,"%s",%s\n' "$MM_TITLE" "$MM_STATE" "$MM_FILE" "$(now_iso)" >> "$MANIFEST"
}

build_queue() {
  BQ_SRC="$1"
  BQ_DEST="$2"
  : > "$BQ_DEST"
  BQ_COUNT=0
  while IFS="$TAB" read -r BQ_TITLE BQ_USED BQ_ELAPSED BQ_AVG BQ_PCT BQ_PRED; do
    [ -n "$BQ_TITLE" ] || continue
    BQ_MIN="$(awk -v h="$BQ_USED" 'BEGIN{printf "%d", h*60+0.5}')"
    [ "$BQ_MIN" -ge "$MIN_FINAL_MINUTES" ] || continue
    is_already_done "$BQ_TITLE" && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$BQ_TITLE" "$BQ_USED" "$BQ_ELAPSED" "$BQ_AVG" "$BQ_PCT" "$BQ_PRED" >> "$BQ_DEST"
    BQ_COUNT=$((BQ_COUNT+1))
    if [ "$MAX_NEW_SESSIONS" -gt 0 ] && [ "$BQ_COUNT" -ge "$MAX_NEW_SESSIONS" ]; then break; fi
  done < "$BQ_SRC"
  QUEUE_COUNT="$BQ_COUNT"
}

find_row_on_screen() {
  FR_TARGET="$1"
  FR_XML="$TMP/find.xml"
  FR_NODES="$TMP/find.nodes"
  dump_ui "$FR_XML" || return 2
  grep -q 'package="com.omarea.vtools"' "$FR_XML" || return 2
  grep -q 'text="历史记录"' "$FR_XML" || return 2
  sed 's/></>\n</g' "$FR_XML" | grep -E 'ItemTitle|ItemStart|ItemCenter|ItemEnd|NewTag|dialogTitle' > "$FR_NODES" || :
  FR_LINE="$(grep -F "text=\"$FR_TARGET\"" "$FR_NODES" | head -n1)"
  [ -n "$FR_LINE" ] || return 1
  FR_BOUNDS="$(printf '%s' "$FR_LINE" | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p')"
  set -- $FR_BOUNDS
  [ "$#" -eq 4 ] || return 1
  TAP_Y=$((($2+$4)/2))
  return 0
}

locate_history_row() {
  LH_TARGET="$1"
  echo "Locating: $LH_TARGET"
  LH_TRY=1
  while [ "$LH_TRY" -le 2 ]; do
    history_to_top || { LH_TRY=$((LH_TRY+1)); continue; }
    LH_PAGE=0
    LH_LIMIT="$INCREMENTAL_HISTORY_PAGES"
    [ "$MAX_NEW_SESSIONS" -eq 0 ] && LH_LIMIT="$MAX_HISTORY_PAGES"
    while [ "$LH_PAGE" -lt "$LH_LIMIT" ]; do
      find_row_on_screen "$LH_TARGET"
      LH_RC=$?
      [ "$LH_RC" -eq 0 ] && { echo "Located: $LH_TARGET on history page $LH_PAGE"; return 0; }
      [ "$LH_RC" -eq 2 ] && break
      LH_PAGE=$((LH_PAGE+1))
      [ "$LH_PAGE" -ge "$LH_LIMIT" ] && break
      input swipe 720 2750 720 800 650 >/dev/null 2>&1
      sleep 1
    done
    echo "WARN: locate interrupted/not found for $LH_TARGET; recovery try $LH_TRY..."
    LH_TRY=$((LH_TRY+1))
  done
  return 1
}

wait_for_detail() {
  WD_P=0
  while [ "$WD_P" -lt 8 ]; do
    WD_XML="$TMP/verify-detail.xml"
    if dump_ui "$WD_XML" && grep -q 'package="com.omarea.vtools"' "$WD_XML" && grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$WD_XML" && ! grep -q 'text="历史记录"' "$WD_XML"; then return 0; fi
    sleep 1
    WD_P=$((WD_P+1))
  done
  return 1
}

capture_detail_full() {
  CD_TITLE="$1"
  CD_SAFE="$(printf '%s' "$CD_TITLE" | tr ' :' '--')"
  CD_DEST="$OUTDIR/detail-$CD_SAFE.txt"
  CD_PART="$CD_DEST.partial"
  : > "$CD_PART"
  printf 'session_title=%s\ncapture_at=%s\n' "$CD_TITLE" "$(now_iso)" >> "$CD_PART"
  CD_PREV=''
  CD_PAGE=0
  CD_FIRST_OK=0
  while [ "$CD_PAGE" -lt "$MAX_DETAIL_PAGES" ]; do
    CD_XML="$TMP/d-$CD_PAGE.xml"
    CD_NODES="$TMP/d-$CD_PAGE.nodes"
    dump_ui "$CD_XML" || { rm -f "$CD_PART"; return 1; }
    grep -q 'package="com.omarea.vtools"' "$CD_XML" || { rm -f "$CD_PART"; return 1; }
    grep -q 'text="历史记录"' "$CD_XML" && { rm -f "$CD_PART"; return 1; }
    sed 's/></>\n</g' "$CD_XML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$CD_NODES" || :
    if [ "$CD_PAGE" -eq 0 ]; then
      grep -q 'avg_power' "$CD_NODES" || { rm -f "$CD_PART"; return 1; }
      CD_FIRST_OK=1
    fi
    CD_HASH="$(cksum "$CD_NODES" 2>/dev/null | awk '{print $1":"$2}')"
    [ -n "$CD_PREV" ] && [ "$CD_HASH" = "$CD_PREV" ] && break
    printf '\n===== DETAIL PAGE %02d =====\n' "$CD_PAGE" >> "$CD_PART"
    cat "$CD_NODES" >> "$CD_PART"
    CD_PREV="$CD_HASH"
    CD_PAGE=$((CD_PAGE+1))
    [ "$CD_PAGE" -ge "$MAX_DETAIL_PAGES" ] && break
    input swipe 720 2800 720 900 650 >/dev/null 2>&1
    sleep 1
  done
  [ "$CD_FIRST_OK" -eq 1 ] || { rm -f "$CD_PART"; return 1; }
  mv "$CD_PART" "$CD_DEST"
  DETAIL_FILE="$CD_DEST"
  return 0
}

return_to_history() {
  RTH_KIND="$(screen_kind)"
  if [ "$RTH_KIND" = history ]; then return 0; fi
  if [ "$RTH_KIND" = battery ]; then
    input keyevent 4 >/dev/null 2>&1
    RTH_I=0
    while [ "$RTH_I" -lt 5 ]; do
      sleep 1
      RTH_KIND="$(screen_kind)"
      [ "$RTH_KIND" = history ] && return 0
      RTH_I=$((RTH_I+1))
    done
  fi
  open_history
}

acquire_lock || exit 2

echo 'Switch to Scene -> 耗电统计 within 7 seconds...'
sleep 7
open_history || { echo 'ERROR: could not verify/open History after retries'; exit 1; }
echo 'History verified. Capturing recent index...'
HRAW="$OUTDIR/history-index-$(date '+%Y%m%d-%H%M%S').txt"
INDEX_TRY=1
while [ "$INDEX_TRY" -le 2 ]; do
  if capture_history_pages "$HRAW"; then break; fi
  echo "WARN: History capture interrupted; recovery try $INDEX_TRY..."
  open_history || { echo 'ERROR: History recovery failed'; exit 1; }
  INDEX_TRY=$((INDEX_TRY+1))
done
[ "$INDEX_TRY" -le 2 ] || { echo 'ERROR: History capture failed twice'; exit 1; }

CAND="$TMP/candidates.tsv"
QUEUE="$TMP/queue.tsv"
parse_history_candidates "$HRAW" "$CAND"
build_queue "$CAND" "$QUEUE"
CAND_COUNT="$(wc -l < "$CAND" 2>/dev/null | tr -d ' ')"
INDEX_LINES="$(wc -l < "$HRAW" 2>/dev/null | tr -d ' ')"
ELIGIBLE_COUNT="$(awk -F '\t' -v m="$MIN_FINAL_MINUTES" '($2*60)>=m {n++} END{print n+0}' "$CAND")"
echo "history_pages=$HISTORY_PAGES history_index_lines=${INDEX_LINES:-0} candidate_rows=${CAND_COUNT:-0} eligible_rows=${ELIGIBLE_COUNT:-0} queue_rows=${QUEUE_COUNT:-0}"
if [ "${QUEUE_COUNT:-0}" -gt 0 ]; then
  echo 'Queue:'
  awk -F '\t' '{print "  "$1" used="$2"h avg="$4"W predict="$6"h"}' "$QUEUE"
else
  echo 'Queue empty: no uncaptured eligible sessions in scanned recent History pages.'
fi

COUNT=0
while IFS="$TAB" read -r TITLE USED_H ELAPSED_H AVG PCT PRED; do
  [ -n "$TITLE" ] || continue
  if ! locate_history_row "$TITLE"; then
    echo "WARN could not locate after recovery: $TITLE"
    mark_manifest "$TITLE" locate_failed ''
    continue
  fi
  echo "Opening: $TITLE (used=${USED_H}h)"
  input tap 700 "$TAP_Y" >/dev/null 2>&1
  if ! wait_for_detail; then
    echo "WARN detail verify failed/interrupted: $TITLE (left retryable)"
    mark_manifest "$TITLE" detail_interrupted ''
    return_to_history >/dev/null 2>&1 || :
    continue
  fi
  if capture_detail_full "$TITLE"; then
    mark_manifest "$TITLE" captured "$DETAIL_FILE"
    COUNT=$((COUNT+1))
    echo "Captured: $TITLE -> $DETAIL_FILE"
  else
    echo "WARN detail capture interrupted: $TITLE (left retryable)"
    mark_manifest "$TITLE" detail_interrupted ''
  fi
  return_to_history || echo 'WARN: could not restore History after detail; next iteration will recover'
done < "$QUEUE"

echo "DONE captured_new=$COUNT"
echo "history_index=$HRAW"
echo "manifest=$MANIFEST"
echo 'network timeline (MacroDroid) is expected at:'
echo "$BASE/network_timeline_md.csv"
