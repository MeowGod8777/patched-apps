#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger full local sync v0
# Captures History rows, filters finalized sessions, drills into eligible rows,
# captures detailed stats + app list, and preserves raw evidence locally.
# GitHub upload is intentionally NOT included yet.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
TMP="$BASE/sync_tmp"
MANIFEST="$BASE/sync_manifest.csv"
mkdir -p "$OUTDIR" "$TMP"

MIN_FINAL_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_PAGES=${SCENE_BATTERY_MAX_HISTORY_PAGES:-12}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}

now_iso() { date '+%Y-%m-%dT%H:%M:%S%z'; }

node_text_by_id() {
  FILE="$1"; ID="$2"
  grep -m1 "resource-id=\"com.omarea.vtools:id/$ID\"" "$FILE" | sed -n 's/.*text="\([^"]*\)".*/\1/p'
}

open_history() {
  XML="$TMP/open.xml"
  uiautomator dump "$XML" >/dev/null 2>&1 || return 1
  N="$TMP/open.nodes"
  sed 's/></>\n</g' "$XML" | grep -E 'text="[^"]+"|resource-id="com.omarea.vtools:id/action_history"' > "$N"
  if grep -q 'text="历史记录"' "$N"; then return 0; fi
  if ! grep -q 'text="耗电统计"' "$N"; then return 1; fi
  # action_history is around x 1125 on this 1440x3200 device.
  input tap 1125 255 >/dev/null 2>&1
  sleep 1
  uiautomator dump "$XML" >/dev/null 2>&1 || return 1
  sed 's/></>\n</g' "$XML" | grep -E 'text="[^"]+"' > "$N"
  grep -q 'text="历史记录"' "$N"
}

capture_history_pages() {
  OUT="$1"
  : > "$OUT"
  PREV=''
  PAGE=0
  while [ "$PAGE" -lt "$MAX_HISTORY_PAGES" ]; do
    XML="$TMP/h-$PAGE.xml"; N="$TMP/h-$PAGE.nodes"
    uiautomator dump "$XML" >/dev/null 2>&1 || break
    sed 's/></>\n</g' "$XML" | grep -E 'resource-id="com.omarea.vtools:id/(dialogTitle|NewTag|ItemTitle|ItemStart|ItemCenter|ItemEnd)"' > "$N"
    H="$(sha256sum "$N" 2>/dev/null | awk '{print $1}')"
    [ -n "$PREV" ] && [ "$H" = "$PREV" ] && break
    printf '\n===== PAGE %02d =====\n' "$PAGE" >> "$OUT"
    cat "$N" >> "$OUT"
    PREV="$H"
    PAGE=$((PAGE+1))
    [ "$PAGE" -ge "$MAX_HISTORY_PAGES" ] && break
    input swipe 720 2750 720 800 650 >/dev/null 2>&1
    sleep 1
  done
  echo "$PAGE"
}

# Build unique finalized candidate rows from captured history.
# Output TSV: title\tused_hours\telapsed_hours\tavg_w\tpct_per_h\tpredict_h
parse_history_candidates() {
  SRC="$1"; OUT="$2"
  awk '
    function textval(line,  x){
      x=line; sub(/^.*text="/,"",x); sub(/" resource-id=.*$/,"",x); return x
    }
    /id\/ItemTitle"/ { title=textval($0); next }
    /id\/NewTag"/   { title="today"; next }
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
      if (title != "" && title != "today") print title "\t" used "\t" elapsed "\t" avg "\t" pct "\t" p;
      title=""; used=""; elapsed=""; avg=""; pct=""; p=""; next
    }
  ' "$SRC" | awk -F '\t' '!seen[$1]++' > "$OUT"
}

find_row_on_screen() {
  TARGET="$1"
  XML="$TMP/find.xml"; N="$TMP/find.nodes"
  uiautomator dump "$XML" >/dev/null 2>&1 || return 1
  sed 's/></>\n</g' "$XML" | grep -E 'resource-id="com.omarea.vtools:id/(ItemTitle|NewTag|ItemStart|ItemCenter|ItemEnd)"' > "$N"
  LINE="$(grep "text=\"$TARGET\"" "$N" | head -n1)"
  [ -n "$LINE" ] || return 1
  B="$(printf '%s' "$LINE" | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p')"
  set -- $B
  [ "$#" -eq 4 ] || return 1
  TAP_Y=$((($2+$4)/2))
  return 0
}

locate_history_row() {
  TARGET="$1"
  # Always reopen history from detail/current page and search from top.
  input keyevent 4 >/dev/null 2>&1
  sleep 1
  open_history || return 1
  # jump to top aggressively
  I=0; while [ "$I" -lt 6 ]; do input swipe 720 700 720 2850 400 >/dev/null 2>&1; I=$((I+1)); done
  sleep 1
  P=0
  while [ "$P" -lt "$MAX_HISTORY_PAGES" ]; do
    if find_row_on_screen "$TARGET"; then return 0; fi
    input swipe 720 2750 720 800 650 >/dev/null 2>&1
    sleep 1
    P=$((P+1))
  done
  return 1
}

capture_detail_full() {
  TITLE="$1"; SAFE="$(printf '%s' "$TITLE" | tr ' :' '--')"; OUT="$OUTDIR/detail-$SAFE.txt"
  : > "$OUT"
  printf 'session_title=%s\ncapture_at=%s\n' "$TITLE" "$(now_iso)" >> "$OUT"
  PREV=''; PAGE=0
  while [ "$PAGE" -lt "$MAX_DETAIL_PAGES" ]; do
    XML="$TMP/d-$PAGE.xml"; N="$TMP/d-$PAGE.nodes"
    uiautomator dump "$XML" >/dev/null 2>&1 || break
    sed 's/></>\n</g' "$XML" | grep -E 'resource-id="com.omarea.vtools:id/(battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts)"' > "$N"
    H="$(sha256sum "$N" 2>/dev/null | awk '{print $1}')"
    [ -n "$PREV" ] && [ "$H" = "$PREV" ] && break
    printf '\n===== DETAIL PAGE %02d =====\n' "$PAGE" >> "$OUT"
    cat "$N" >> "$OUT"
    PREV="$H"
    PAGE=$((PAGE+1))
    [ "$PAGE" -ge "$MAX_DETAIL_PAGES" ] && break
    input swipe 720 2800 720 900 650 >/dev/null 2>&1
    sleep 1
  done
  echo "$OUT"
}

is_already_done() {
  TITLE="$1"
  [ -f "$MANIFEST" ] && grep -Fq "\"$TITLE\",captured" "$MANIFEST"
}

mark_manifest() {
  TITLE="$1"; STATE="$2"; FILE="$3"
  [ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
  printf '"%s",%s,"%s",%s\n' "$TITLE" "$STATE" "$FILE" "$(now_iso)" >> "$MANIFEST"
}

echo 'Switch to Scene -> 耗电统计 within 7 seconds...'
sleep 7
open_history || { echo 'ERROR: could not verify/open History'; exit 1; }
echo 'History verified. Capturing index...'
HRAW="$OUTDIR/history-index-$(date '+%Y%m%d-%H%M%S').txt"
PAGES="$(capture_history_pages "$HRAW")"
CAND="$TMP/candidates.tsv"
parse_history_candidates "$HRAW" "$CAND"

echo "history_pages=$PAGES"
echo 'Eligible finalized sessions:'
awk -F '\t' -v m="$MIN_FINAL_MINUTES" '($2*60)>=m {print "  "$1"  used="$2"h  avg="$4"W  predict="$6"h"}' "$CAND"

COUNT=0
while IFS='\t' read -r TITLE USED_H ELAPSED_H AVG PCT PRED; do
  [ -n "$TITLE" ] || continue
  USED_MIN="$(awk -v h="$USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
  [ "$USED_MIN" -ge "$MIN_FINAL_MINUTES" ] || continue
  if is_already_done "$TITLE"; then
    echo "SKIP already captured: $TITLE"
    continue
  fi
  if ! locate_history_row "$TITLE"; then
    echo "WARN could not locate: $TITLE"
    mark_manifest "$TITLE" locate_failed ''
    continue
  fi
  echo "Opening: $TITLE (used=${USED_H}h)"
  input tap 700 "$TAP_Y" >/dev/null 2>&1
  sleep 1
  XML="$TMP/verify-detail.xml"; uiautomator dump "$XML" >/dev/null 2>&1
  if ! grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$XML"; then
    echo "WARN detail verify failed: $TITLE"
    mark_manifest "$TITLE" detail_verify_failed ''
    continue
  fi
  FILE="$(capture_detail_full "$TITLE")"
  mark_manifest "$TITLE" captured "$FILE"
  COUNT=$((COUNT+1))
done < "$CAND"

echo "DONE captured_new=$COUNT"
echo "history_index=$HRAW"
echo "manifest=$MANIFEST"
echo 'network timeline (MacroDroid) is expected at:'
echo "$BASE/network_timeline_md.csv"
