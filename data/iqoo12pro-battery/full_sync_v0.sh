#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger full local sync v0.5-resilient
# - Retries transient UIAutomator/History failures.
# - Waits for Scene recovery instead of requiring a whole-script restart.
# - Always normalizes History to the top before indexing/searching.
# - Rejects live today rows by post-filtering for full YYYY-MM-DD HH:MM titles.
# - Detail captures are committed only when complete.
# - v0.5: History page extraction uses the proven broad Item* matcher, validates
#   that each dumped page actually exposes History rows, and retries empty pages.
# GitHub upload is intentionally NOT included yet.

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
  OUT="$1"; I=0
  while [ "$I" -lt "$UI_RETRIES" ]; do
    rm -f "$OUT"
    if uiautomator dump "$OUT" >/dev/null 2>&1 && [ -s "$OUT" ]; then return 0; fi
    I=$((I+1)); sleep 1
  done
  return 1
}

screen_kind() {
  XML="$TMP/state.xml"
  if ! dump_ui "$XML"; then echo unknown; return; fi
  if grep -q 'package="com.omarea.vtools"' "$XML"; then
    if grep -q 'text="历史记录"' "$XML"; then echo history
    elif grep -q 'text="耗电统计"' "$XML" || grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$XML"; then echo battery
    else echo scene_other; fi
  else echo other_app; fi
}

wait_for_scene() {
  KIND="$(screen_kind)"
  case "$KIND" in battery|history) return 0;; esac
  echo "WAIT: Scene is not on 耗电统计/历史记录. Reopen Scene -> 耗电统计; waiting up to ${RECOVERY_WAIT_SECONDS}s..."
  ELAPSED=0
  while [ "$ELAPSED" -lt "$RECOVERY_WAIT_SECONDS" ]; do
    sleep 2; ELAPSED=$((ELAPSED+2)); KIND="$(screen_kind)"
    case "$KIND" in battery|history) echo "RECOVERED: Scene detected ($KIND)."; return 0;; esac
  done
  echo 'ERROR: Scene recovery timeout.'; return 1
}

open_history() {
  ATTEMPT=1
  while [ "$ATTEMPT" -le 3 ]; do
    wait_for_scene || return 1
    KIND="$(screen_kind)"; [ "$KIND" = history ] && return 0
    input tap 1125 255 >/dev/null 2>&1
    P=0
    while [ "$P" -lt 6 ]; do
      sleep 1; KIND="$(screen_kind)"
      [ "$KIND" = history ] && return 0
      [ "$KIND" = other_app ] && break
      P=$((P+1))
    done
    echo "WARN: History open attempt $ATTEMPT failed; retrying..."; ATTEMPT=$((ATTEMPT+1))
  done
  return 1
}

history_to_top() {
  open_history || return 1
  I=0
  while [ "$I" -lt 10 ]; do
    input swipe 720 650 720 2900 320 >/dev/null 2>&1
    I=$((I+1))
  done
  sleep 2
  return 0
}

extract_history_nodes() {
  XML="$1"; N="$2"
  # This exact broad matcher mirrors the manual command proven to work on-device.
  sed 's/></>\n</g' "$XML" | grep -E 'ItemTitle|ItemStart|ItemCenter|ItemEnd|NewTag|dialogTitle' > "$N" || :
  grep -qE 'id/(ItemTitle|ItemStart|ItemCenter|ItemEnd)"' "$N"
}

capture_history_pages() {
  OUT="$1"; : > "$OUT"; PREV=''; PAGE=0
  history_to_top || return 1
  while [ "$PAGE" -lt "$MAX_HISTORY_PAGES" ]; do
    XML="$TMP/h-$PAGE.xml"; N="$TMP/h-$PAGE.nodes"
    ROWTRY=1
    GOT_ROWS=0
    while [ "$ROWTRY" -le "$PAGE_ROW_RETRIES" ]; do
      dump_ui "$XML" || { ROWTRY=$((ROWTRY+1)); sleep 1; continue; }
      grep -q 'package="com.omarea.vtools"' "$XML" || return 1
      grep -q 'text="历史记录"' "$XML" || return 1
      if extract_history_nodes "$XML" "$N"; then
        GOT_ROWS=1
        break
      fi
      echo "WARN: History page $PAGE exposed no rows (try $ROWTRY/$PAGE_ROW_RETRIES); waiting..."
      ROWTRY=$((ROWTRY+1)); sleep 1
    done
    [ "$GOT_ROWS" -eq 1 ] || { echo "ERROR: History page $PAGE remained row-empty"; return 1; }

    H="$(cksum "$N" 2>/dev/null | awk '{print $1":"$2}')"
    [ -n "$PREV" ] && [ "$H" = "$PREV" ] && break
    printf '\n===== PAGE %02d =====\n' "$PAGE" >> "$OUT"; cat "$N" >> "$OUT"
    PREV="$H"; PAGE=$((PAGE+1)); [ "$PAGE" -ge "$MAX_HISTORY_PAGES" ] && break
    input swipe 720 2750 720 800 650 >/dev/null 2>&1; sleep 1
  done
  HISTORY_PAGES="$PAGE"; return 0
}

parse_history_candidates() {
  SRC="$1"; OUT="$2"; ALL="$TMP/candidates-all.tsv"
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
  ' "$SRC" | awk -F '\t' '!seen[$1]++' > "$ALL"

  grep -E '^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9][[:space:]]' "$ALL" > "$OUT" || :
}

find_row_on_screen() {
  TARGET="$1"; XML="$TMP/find.xml"; N="$TMP/find.nodes"
  dump_ui "$XML" || return 2
  grep -q 'package="com.omarea.vtools"' "$XML" || return 2
  grep -q 'text="历史记录"' "$XML" || return 2
  sed 's/></>\n</g' "$XML" | grep -E 'ItemTitle|ItemStart|ItemCenter|ItemEnd|NewTag|dialogTitle' > "$N" || :
  LINE="$(grep -F "text=\"$TARGET\"" "$N" | head -n1)"; [ -n "$LINE" ] || return 1
  B="$(printf '%s' "$LINE" | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p')"
  set -- $B; [ "$#" -eq 4 ] || return 1; TAP_Y=$((($2+$4)/2)); return 0
}

locate_history_row() {
  TARGET="$1"; echo "Locating: $TARGET"; TRY=1
  while [ "$TRY" -le 2 ]; do
    history_to_top || return 1
    P=0
    while [ "$P" -lt "$MAX_HISTORY_PAGES" ]; do
      find_row_on_screen "$TARGET"; RC=$?
      [ "$RC" -eq 0 ] && { echo "Located: $TARGET on history page $P"; return 0; }
      [ "$RC" -eq 2 ] && break
      P=$((P+1)); echo "  scan page $P/$MAX_HISTORY_PAGES"
      input swipe 720 2750 720 800 650 >/dev/null 2>&1; sleep 1
    done
    echo "WARN: locate interrupted/not found for $TARGET; recovery try $TRY..."; TRY=$((TRY+1))
  done
  return 1
}

wait_for_detail() {
  P=0
  while [ "$P" -lt 8 ]; do
    XML="$TMP/verify-detail.xml"
    if dump_ui "$XML" && grep -q 'package="com.omarea.vtools"' "$XML" && grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$XML" && ! grep -q 'text="历史记录"' "$XML"; then return 0; fi
    sleep 1; P=$((P+1))
  done
  return 1
}

capture_detail_full() {
  TITLE="$1"; SAFE="$(printf '%s' "$TITLE" | tr ' :' '--')"; OUT="$OUTDIR/detail-$SAFE.txt"; PART="$OUT.partial"
  : > "$PART"; printf 'session_title=%s\ncapture_at=%s\n' "$TITLE" "$(now_iso)" >> "$PART"
  PREV=''; PAGE=0
  while [ "$PAGE" -lt "$MAX_DETAIL_PAGES" ]; do
    XML="$TMP/d-$PAGE.xml"; N="$TMP/d-$PAGE.nodes"
    dump_ui "$XML" || { rm -f "$PART"; return 1; }
    grep -q 'package="com.omarea.vtools"' "$XML" || { rm -f "$PART"; return 1; }
    grep -q 'text="历史记录"' "$XML" && { rm -f "$PART"; return 1; }
    sed 's/></>\n</g' "$XML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$N" || :
    H="$(cksum "$N" 2>/dev/null | awk '{print $1":"$2}')"; [ -n "$PREV" ] && [ "$H" = "$PREV" ] && break
    printf '\n===== DETAIL PAGE %02d =====\n' "$PAGE" >> "$PART"; cat "$N" >> "$PART"
    PREV="$H"; PAGE=$((PAGE+1)); [ "$PAGE" -ge "$MAX_DETAIL_PAGES" ] && break
    input swipe 720 2800 720 900 650 >/dev/null 2>&1; sleep 1
  done
  mv "$PART" "$OUT"; DETAIL_FILE="$OUT"; return 0
}

is_already_done() { TITLE="$1"; [ -f "$MANIFEST" ] && grep -Fq "\"$TITLE\",captured" "$MANIFEST"; }
mark_manifest() {
  TITLE="$1"; STATE="$2"; FILE="$3"
  [ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
  printf '"%s",%s,"%s",%s\n' "$TITLE" "$STATE" "$FILE" "$(now_iso)" >> "$MANIFEST"
}

echo 'Switch to Scene -> 耗电统计 within 7 seconds...'; sleep 7
open_history || { echo 'ERROR: could not verify/open History after retries'; exit 1; }
echo 'History verified. Capturing index...'
HRAW="$OUTDIR/history-index-$(date '+%Y%m%d-%H%M%S').txt"
INDEX_TRY=1
while [ "$INDEX_TRY" -le 2 ]; do
  if capture_history_pages "$HRAW"; then break; fi
  echo "WARN: History capture interrupted; recovery try $INDEX_TRY..."; open_history || { echo 'ERROR: History recovery failed'; exit 1; }; INDEX_TRY=$((INDEX_TRY+1))
done
[ "$INDEX_TRY" -le 2 ] || { echo 'ERROR: History capture failed twice'; exit 1; }

CAND="$TMP/candidates.tsv"; parse_history_candidates "$HRAW" "$CAND"
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
  USED_MIN="$(awk -v h="$USED_H" 'BEGIN{printf "%d", h*60+0.5}')"; [ "$USED_MIN" -ge "$MIN_FINAL_MINUTES" ] || continue
  if is_already_done "$TITLE"; then echo "SKIP already captured: $TITLE"; continue; fi
  if [ "$MAX_NEW_SESSIONS" -gt 0 ] && [ "$COUNT" -ge "$MAX_NEW_SESSIONS" ]; then echo "Pilot limit reached: $MAX_NEW_SESSIONS"; break; fi
  if ! locate_history_row "$TITLE"; then echo "WARN could not locate after recovery: $TITLE"; mark_manifest "$TITLE" locate_failed ''; continue; fi
  echo "Opening: $TITLE (used=${USED_H}h)"; input tap 700 "$TAP_Y" >/dev/null 2>&1
  if ! wait_for_detail; then echo "WARN detail verify failed/interrupted: $TITLE (left retryable)"; mark_manifest "$TITLE" detail_interrupted ''; continue; fi
  if capture_detail_full "$TITLE"; then mark_manifest "$TITLE" captured "$DETAIL_FILE"; COUNT=$((COUNT+1))
  else echo "WARN detail capture interrupted: $TITLE (left retryable)"; mark_manifest "$TITLE" detail_interrupted ''; fi
done < "$CAND"

echo "DONE captured_new=$COUNT"
echo "history_index=$HRAW"
echo "manifest=$MANIFEST"
echo 'network timeline (MacroDroid) is expected at:'
echo "$BASE/network_timeline_md.csv"
