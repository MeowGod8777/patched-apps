#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger full local sync v0.6-resilient
# Fixes nested-function variable clobbering under Android /system/bin/sh.
# GitHub upload intentionally not included yet.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
TMP="$BASE/sync_tmp"
MANIFEST="$BASE/sync_manifest.csv"
mkdir -p "$OUTDIR" "$TMP"

MIN_FINAL_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_PAGES=${SCENE_BATTERY_MAX_HISTORY_PAGES:-12}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}
MAX_NEW_SESSIONS=${SCENE_BATTERY_MAX_NEW_SESSIONS:-0}
RECOVERY_WAIT_SECONDS=${SCENE_BATTERY_RECOVERY_WAIT_SECONDS:-60}
UI_RETRIES=${SCENE_BATTERY_UI_RETRIES:-3}
PAGE_ROW_RETRIES=${SCENE_BATTERY_PAGE_ROW_RETRIES:-4}
TAB="$(printf '\t')"

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

history_to_top() {
  open_history || return 1
  TOP_I=0
  while [ "$TOP_I" -lt 10 ]; do
    input swipe 720 650 720 2900 320 >/dev/null 2>&1
    TOP_I=$((TOP_I+1))
  done
  sleep 2
  return 0
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
  while [ "$CH_PAGE" -lt "$MAX_HISTORY_PAGES" ]; do
    CH_XML="$TMP/h-$CH_PAGE.xml"
    CH_NODES="$TMP/h-$CH_PAGE.nodes"
    CH_ROWTRY=1
    CH_GOT_ROWS=0
    while [ "$CH_ROWTRY" -le "$PAGE_ROW_RETRIES" ]; do
      dump_ui "$CH_XML" || { CH_ROWTRY=$((CH_ROWTRY+1)); sleep 1; continue; }
      grep -q 'package="com.omarea.vtools"' "$CH_XML" || return 1
      grep -q 'text="历史记录"' "$CH_XML" || return 1
      if extract_history_nodes "$CH_XML" "$CH_NODES"; then
        CH_GOT_ROWS=1
        break
      fi
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
    [ "$CH_PAGE" -ge "$MAX_HISTORY_PAGES" ] && break
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
    history_to_top || return 1
    LH_PAGE=0
    while [ "$LH_PAGE" -lt "$MAX_HISTORY_PAGES" ]; do
      find_row_on_screen "$LH_TARGET"
      LH_RC=$?
      [ "$LH_RC" -eq 0 ] && { echo "Located: $LH_TARGET on history page $LH_PAGE"; return 0; }
      [ "$LH_RC" -eq 2 ] && break
      LH_PAGE=$((LH_PAGE+1))
      echo "  scan page $LH_PAGE/$MAX_HISTORY_PAGES"
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
  while [ "$CD_PAGE" -lt "$MAX_DETAIL_PAGES" ]; do
    CD_XML="$TMP/d-$CD_PAGE.xml"
    CD_NODES="$TMP/d-$CD_PAGE.nodes"
    dump_ui "$CD_XML" || { rm -f "$CD_PART"; return 1; }
    grep -q 'package="com.omarea.vtools"' "$CD_XML" || { rm -f "$CD_PART"; return 1; }
    grep -q 'text="历史记录"' "$CD_XML" && { rm -f "$CD_PART"; return 1; }
    sed 's/></>\n</g' "$CD_XML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$CD_NODES" || :
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
  mv "$CD_PART" "$CD_DEST"
  DETAIL_FILE="$CD_DEST"
  return 0
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

echo 'Switch to Scene -> 耗电统计 within 7 seconds...'
sleep 7
open_history || { echo 'ERROR: could not verify/open History after retries'; exit 1; }
echo 'History verified. Capturing index...'
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
parse_history_candidates "$HRAW" "$CAND"
CAND_COUNT="$(wc -l < "$CAND" 2>/dev/null | tr -d ' ')"
INDEX_LINES="$(wc -l < "$HRAW" 2>/dev/null | tr -d ' ')"
echo "history_pages=$HISTORY_PAGES history_index_lines=${INDEX_LINES:-0} candidate_rows=${CAND_COUNT:-0}"
echo 'Eligible finalized sessions:'
awk -F '\t' -v m="$MIN_FINAL_MINUTES" '($2*60)>=m {print "  "$1"  used="$2"h  avg="$4"W  predict="$6"h"}' "$CAND"
if [ "${CAND_COUNT:-0}" -eq 0 ]; then
  echo 'DEBUG: no finalized candidates parsed; first captured History nodes were:'
  head -n 20 "$HRAW"
fi

COUNT=0
while IFS="$TAB" read -r TITLE USED_H ELAPSED_H AVG PCT PRED; do
  [ -n "$TITLE" ] || continue
  USED_MIN="$(awk -v h="$USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
  [ "$USED_MIN" -ge "$MIN_FINAL_MINUTES" ] || continue
  if is_already_done "$TITLE"; then echo "SKIP already captured: $TITLE"; continue; fi
  if [ "$MAX_NEW_SESSIONS" -gt 0 ] && [ "$COUNT" -ge "$MAX_NEW_SESSIONS" ]; then echo "Pilot limit reached: $MAX_NEW_SESSIONS"; break; fi
  if ! locate_history_row "$TITLE"; then echo "WARN could not locate after recovery: $TITLE"; mark_manifest "$TITLE" locate_failed ''; continue; fi
  echo "Opening: $TITLE (used=${USED_H}h)"
  input tap 700 "$TAP_Y" >/dev/null 2>&1
  if ! wait_for_detail; then echo "WARN detail verify failed/interrupted: $TITLE (left retryable)"; mark_manifest "$TITLE" detail_interrupted ''; continue; fi
  if capture_detail_full "$TITLE"; then mark_manifest "$TITLE" captured "$DETAIL_FILE"; COUNT=$((COUNT+1))
  else echo "WARN detail capture interrupted: $TITLE (left retryable)"; mark_manifest "$TITLE" detail_interrupted ''; fi
done < "$CAND"

echo "DONE captured_new=$COUNT"
echo "history_index=$HRAW"
echo "manifest=$MANIFEST"
echo 'network timeline (MacroDroid) is expected at:'
echo "$BASE/network_timeline_md.csv"
