#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - read-only backlog completeness checker v1
# One manual handoff: switch once to Scene -> 耗电统计 or History.
# Does NOT capture detail pages and does NOT modify manifest/raw files.
# It scans the entire History index, finds finalized sessions >=30 min, then
# compares each session against the latest manifest state and raw attribution health.

BASE=/sdcard/SceneBattery
MANIFEST="$BASE/sync_manifest.csv"
TMP="$BASE/check_tmp/backlog-complete-$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_HISTORY_SWIPES=${SCENE_BATTERY_BACKLOG_MAX_SWIPES:-260}
HISTORY_SWIPE_START=${SCENE_BATTERY_HISTORY_SWIPE_START:-2600}
HISTORY_SWIPE_END=${SCENE_BATTERY_HISTORY_SWIPE_END:-1700}
TOP_SWIPE_START=${SCENE_BATTERY_TOP_SWIPE_START:-900}
TOP_SWIPE_END=${SCENE_BATTERY_TOP_SWIPE_END:-2700}

nodes() { sed 's/></>\n</g' "$1"; }
dump() { rm -f "$1"; uiautomator dump "$1" >/dev/null 2>&1 && [ -s "$1" ]; }
is_history() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'text="历史记录"' "$1"; }
is_battery() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$1"; }

bounds_for_id() {
  BF_FILE="$1"; BF_ID="$2"
  nodes "$BF_FILE" | grep "resource-id=\"$BF_ID\"" | head -n1 | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p'
}

tap_id() {
  TI_FILE="$1"; TI_ID="$2"; TI_B="$(bounds_for_id "$TI_FILE" "$TI_ID")"
  set -- $TI_B
  [ "$#" -eq 4 ] || return 1
  input tap $((($1+$3)/2)) $((($2+$4)/2)) >/dev/null 2>&1
}

history_sig() {
  HS_FILE="$1"
  nodes "$HS_FILE" | grep -E 'resource-id="com.omarea.vtools:id/(NewTag|ItemTitle|ItemCenter|ItemEnd)"' | cksum | awk '{print $1":"$2}'
}

history_top_ok() {
  HTO_FILE="$1"; HTO_N="$TMP/top-check.nodes"
  nodes "$HTO_FILE" > "$HTO_N"
  grep 'resource-id="com.omarea.vtools:id/NewTag"' "$HTO_N" | grep -q 'text="today"' || return 1
  HTO_FIRST="$(grep 'resource-id="com.omarea.vtools:id/ItemTitle"' "$HTO_N" | head -n1 | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
  case "$HTO_FIRST" in ??:??:??) return 0;; *) return 1;; esac
}

prepare_history_top() {
  PHT_XML="$TMP/start.xml"
  dump "$PHT_XML" || return 1
  grep -q 'package="com.omarea.vtools"' "$PHT_XML" || return 1

  if is_battery "$PHT_XML" && ! is_history "$PHT_XML"; then
    tap_id "$PHT_XML" 'com.omarea.vtools:id/action_history' || return 1
    sleep 2
    dump "$PHT_XML" || return 1
  fi
  is_history "$PHT_XML" || return 1

  PHT_TRY=0; PHT_PREV=''
  while [ "$PHT_TRY" -lt 20 ]; do
    history_top_ok "$PHT_XML" && return 0
    PHT_SIG="$(history_sig "$PHT_XML")"
    if [ -n "$PHT_PREV" ] && [ "$PHT_SIG" = "$PHT_PREV" ]; then return 2; fi
    PHT_PREV="$PHT_SIG"
    input swipe 720 "$TOP_SWIPE_START" 720 "$TOP_SWIPE_END" 500 >/dev/null 2>&1
    sleep 1
    dump "$PHT_XML" || return 1
    is_history "$PHT_XML" || return 1
    PHT_TRY=$((PHT_TRY+1))
  done
  return 2
}

collect_rows_from_view() {
  CRV_XML="$1"; CRV_N="$TMP/view.nodes"; nodes "$CRV_XML" > "$CRV_N"
  CRV_TITLE=''
  while IFS= read -r CRV_LINE; do
    case "$CRV_LINE" in
      *'resource-id="com.omarea.vtools:id/ItemTitle"'*)
        CRV_TITLE="$(printf '%s\n' "$CRV_LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        ;;
      *'resource-id="com.omarea.vtools:id/ItemCenter"'*)
        [ -n "$CRV_TITLE" ] || continue
        case "$CRV_TITLE" in ????-??-??\ ??:??) ;; *) CRV_TITLE=''; continue;; esac
        CRV_CENTER="$(printf '%s\n' "$CRV_LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        CRV_USED_H="$(printf '%s' "$CRV_CENTER" | sed -n 's/^\([0-9][0-9.]*\)h.*/\1/p')"
        [ -n "$CRV_USED_H" ] || { CRV_TITLE=''; continue; }
        CRV_USED_MIN="$(awk -v h="$CRV_USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
        if [ "$CRV_USED_MIN" -ge "$MIN_MINUTES" ]; then
          printf '%s\t%s\n' "$CRV_TITLE" "$CRV_USED_H" >> "$TMP/all-eligible.tsv"
        fi
        CRV_TITLE=''
        ;;
    esac
  done < "$CRV_N"
}

manifest_latest() {
  ML_TITLE="$1"
  ML_OUT="$(awk -F',' -v want="$ML_TITLE" '
    NR>1 {
      t=$1; s=$2; f=$3;
      gsub(/^"|"$/, "", t); gsub(/^"|"$/, "", s); gsub(/^"|"$/, "", f);
      if (t==want) { state=s; file=f }
    }
    END { if (state!="") printf "%s\t%s", state, file }
  ' "$MANIFEST" 2>/dev/null)"
  ML_STATE="$(printf '%s' "$ML_OUT" | cut -f1)"
  ML_FILE="$(printf '%s' "$ML_OUT" | cut -f2-)"
}

raw_health() {
  RH_FILE="$1"; RH_TITLES="$TMP/health.txt"
  [ -f "$RH_FILE" ] || return 81
  grep 'resource-id="com.omarea.vtools:id/itemTitle"' "$RH_FILE" 2>/dev/null | sed -n 's/.*text="\([^"]*\)".*/\1/p' | sed '/^$/d' > "$RH_TITLES"
  RH_COUNT="$(wc -l < "$RH_TITLES" | tr -d ' ')"; [ -n "$RH_COUNT" ] || RH_COUNT=0
  [ "$RH_COUNT" -gt 0 ] || return 82
  RH_NONSCENE="$(grep -vc '^Scene$' "$RH_TITLES" 2>/dev/null || true)"; [ -n "$RH_NONSCENE" ] || RH_NONSCENE=0
  [ "$RH_COUNT" -ge 2 ] && [ "$RH_NONSCENE" -eq 0 ] && return 83
  return 0
}

echo '# Scene backlog completeness checker v1'
echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds.'
sleep 7
prepare_history_top
PHT_RC=$?
[ "$PHT_RC" -eq 0 ] || { [ "$PHT_RC" -eq 2 ] && echo 'ERROR history_top_not_reached' || echo 'ERROR history_not_ready'; exit 10; }
echo 'History top verified. Scanning full index only...'

: > "$TMP/all-eligible.tsv"
SCAN_XML="$TMP/history.xml"
TOTAL_SWIPES=0; PREV_SIG=''
while [ "$TOTAL_SWIPES" -le "$MAX_HISTORY_SWIPES" ]; do
  dump "$SCAN_XML" || { echo 'ERROR history_dump_failed'; exit 20; }
  is_history "$SCAN_XML" || { echo 'ERROR left_history'; exit 21; }
  collect_rows_from_view "$SCAN_XML"
  CUR_SIG="$(history_sig "$SCAN_XML")"
  if [ -n "$PREV_SIG" ] && [ "$CUR_SIG" = "$PREV_SIG" ]; then break; fi
  PREV_SIG="$CUR_SIG"
  [ "$TOTAL_SWIPES" -lt "$MAX_HISTORY_SWIPES" ] || { echo 'ERROR bottom_not_reached'; exit 22; }
  input swipe 720 "$HISTORY_SWIPE_START" 720 "$HISTORY_SWIPE_END" 550 >/dev/null 2>&1
  sleep 1
  TOTAL_SWIPES=$((TOTAL_SWIPES+1))
done

sort -u "$TMP/all-eligible.tsv" > "$TMP/eligible.tsv"
ELIGIBLE_COUNT="$(wc -l < "$TMP/eligible.tsv" | tr -d ' ')"
PENDING=0; VALID=0
: > "$TMP/pending.tsv"

TAB="$(printf '\t')"
while IFS="$TAB" read -r TITLE USED; do
  [ -n "$TITLE" ] || continue
  if [ ! -f "$MANIFEST" ]; then
    printf '%s\t%s\tmissing_manifest\n' "$TITLE" "$USED" >> "$TMP/pending.tsv"; PENDING=$((PENDING+1)); continue
  fi
  manifest_latest "$TITLE"
  if [ "$ML_STATE" != captured ]; then
    printf '%s\t%s\tstate=%s\n' "$TITLE" "$USED" "${ML_STATE:-none}" >> "$TMP/pending.tsv"; PENDING=$((PENDING+1)); continue
  fi
  raw_health "$ML_FILE"; RH_RC=$?
  case "$RH_RC" in
    0) VALID=$((VALID+1));;
    81) printf '%s\t%s\tmissing_raw\n' "$TITLE" "$USED" >> "$TMP/pending.tsv"; PENDING=$((PENDING+1));;
    82) printf '%s\t%s\tno_item_titles\n' "$TITLE" "$USED" >> "$TMP/pending.tsv"; PENDING=$((PENDING+1));;
    83) printf '%s\t%s\tall_titles_scene\n' "$TITLE" "$USED" >> "$TMP/pending.tsv"; PENDING=$((PENDING+1));;
    *) printf '%s\t%s\thealth_rc=%s\n' "$TITLE" "$USED" "$RH_RC" >> "$TMP/pending.tsv"; PENDING=$((PENDING+1));;
  esac
done < "$TMP/eligible.tsv"

echo "eligible=$ELIGIBLE_COUNT valid=$VALID pending=$PENDING swipes=$TOTAL_SWIPES"
if [ "$PENDING" -eq 0 ]; then
  echo 'BACKLOG COMPLETE'
  exit 0
fi

echo '===== PENDING ====='
cat "$TMP/pending.tsv"
echo 'BACKLOG INCOMPLETE'
exit 1
