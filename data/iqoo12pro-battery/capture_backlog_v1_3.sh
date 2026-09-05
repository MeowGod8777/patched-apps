#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - one-shot backlog drain v1.3
#
# Key fix: Scene's battery RecyclerView initially renders every itemTitle as the
# app name "Scene" and resolves each real app label/icon asynchronously through
# AppInfoLoader. Rapid UIAutomator paging can capture those placeholder labels.
# v1.3 therefore waits for attribution to resolve on every detail page before
# accepting raw data. It also uses latest manifest state semantics and can
# invalidate an older captured row whose raw file contains only Scene placeholders.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
INVALIDDIR="$BASE/sync_raw_invalid"
MANIFEST="$BASE/sync_manifest.csv"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$BASE/backlog_tmp/$RUN_ID"
mkdir -p "$OUTDIR" "$INVALIDDIR" "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}
MAX_HISTORY_SWIPES=${SCENE_BATTERY_BACKLOG_MAX_SWIPES:-240}
MAX_CAPTURES=${SCENE_BATTERY_BACKLOG_MAX_CAPTURES:-200}
DETAIL_TAP_RETRIES=${SCENE_BATTERY_DETAIL_TAP_RETRIES:-3}
LABEL_WAIT_TRIES=${SCENE_BATTERY_LABEL_WAIT_TRIES:-20}
LABEL_WAIT_SECONDS=${SCENE_BATTERY_LABEL_WAIT_SECONDS:-1}
HISTORY_SWIPE_START=${SCENE_BATTERY_HISTORY_SWIPE_START:-2600}
HISTORY_SWIPE_END=${SCENE_BATTERY_HISTORY_SWIPE_END:-1700}

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

find_target_y() {
  FTY_FILE="$1"; FTY_TARGET="$2"
  FTY_LINE="$(nodes "$FTY_FILE" | grep 'resource-id="com.omarea.vtools:id/ItemTitle"' | grep -F "text=\"$FTY_TARGET\"" | head -n1)"
  [ -n "$FTY_LINE" ] || return 1
  FTY_BOUNDS="$(printf '%s\n' "$FTY_LINE" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p')"
  FTY_Y1="$(printf '%s' "$FTY_BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
  FTY_Y2="$(printf '%s' "$FTY_BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
  [ -n "$FTY_Y1" ] && [ -n "$FTY_Y2" ] || return 2
  TARGET_Y_CURRENT=$(( (FTY_Y1 + FTY_Y2) / 2 ))
  return 0
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

raw_attribution_health() {
  RAH_FILE="$1"; RAH_TITLES="$TMP/raw-health.txt"
  : > "$RAH_TITLES"
  grep 'resource-id="com.omarea.vtools:id/itemTitle"' "$RAH_FILE" 2>/dev/null | sed -n 's/.*text="\([^"]*\)".*/\1/p' | sed '/^$/d' > "$RAH_TITLES"
  RAH_COUNT="$(wc -l < "$RAH_TITLES" | tr -d ' ')"; [ -n "$RAH_COUNT" ] || RAH_COUNT=0
  [ "$RAH_COUNT" -gt 0 ] || return 70
  RAH_NONSCENE="$(grep -vc '^Scene$' "$RAH_TITLES" 2>/dev/null || true)"; [ -n "$RAH_NONSCENE" ] || RAH_NONSCENE=0
  [ "$RAH_COUNT" -ge 2 ] && [ "$RAH_NONSCENE" -eq 0 ] && return 71
  return 0
}

should_skip_session() {
  SSS_TITLE="$1"
  [ -f "$MANIFEST" ] || return 1
  manifest_latest "$SSS_TITLE"
  [ "$ML_STATE" = captured ] || return 1
  if [ -f "$ML_FILE" ]; then
    raw_attribution_health "$ML_FILE"
    SSS_RC=$?
    [ "$SSS_RC" -eq 0 ] && return 0
    SSS_NOW="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    if [ "$SSS_RC" -eq 71 ]; then
      printf '"%s",invalid_scene_attribution_collapsed,"%s",%s\n' "$SSS_TITLE" "$ML_FILE" "$SSS_NOW" >> "$MANIFEST"
      echo "AUTO-INVALID session=$SSS_TITLE reason=all_titles_scene"
    else
      printf '"%s",invalid_scene_attribution_missing,"%s",%s\n' "$SSS_TITLE" "$ML_FILE" "$SSS_NOW" >> "$MANIFEST"
      echo "AUTO-INVALID session=$SSS_TITLE reason=no_item_titles"
    fi
    return 1
  fi
  printf '"%s",invalid_missing_raw,"%s",%s\n' "$SSS_TITLE" "$ML_FILE" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
  echo "AUTO-INVALID session=$SSS_TITLE reason=missing_raw"
  return 1
}

open_fresh_history_once() {
  OFH_S="$TMP/initial-state.xml"
  dump "$OFH_S" || return 1
  grep -q 'package="com.omarea.vtools"' "$OFH_S" || return 1
  if is_history "$OFH_S"; then
    input keyevent 4 >/dev/null 2>&1; sleep 1; dump "$OFH_S" || return 1
  fi
  if ! is_battery "$OFH_S"; then
    input keyevent 4 >/dev/null 2>&1; sleep 1; dump "$OFH_S" || return 1
  fi
  is_battery "$OFH_S" || return 1
  tap_id "$OFH_S" 'com.omarea.vtools:id/action_history' || return 1
  sleep 2; dump "$OFH_S" || return 1; is_history "$OFH_S" || return 1
  OFH_N="$TMP/initial-top.nodes"; nodes "$OFH_S" > "$OFH_N"
  grep 'resource-id="com.omarea.vtools:id/NewTag"' "$OFH_N" | grep -q 'text="today"' || return 2
  OFH_FIRST="$(grep 'resource-id="com.omarea.vtools:id/ItemTitle"' "$OFH_N" | head -n1 | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
  case "$OFH_FIRST" in ??:??:??) return 0;; *) return 2;; esac
}

scan_current_history() {
  SCH_XML="$1"; SCH_N="$TMP/current.nodes"; nodes "$SCH_XML" > "$SCH_N"
  TARGET=''; TARGET_USED=''; TARGET_Y=''; SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''
  while IFS= read -r SCH_LINE; do
    case "$SCH_LINE" in
      *'resource-id="com.omarea.vtools:id/ItemTitle"'*)
        SCH_ROW_TITLE="$(printf '%s\n' "$SCH_LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        SCH_ROW_BOUNDS="$(printf '%s\n' "$SCH_LINE" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p')";;
      *'resource-id="com.omarea.vtools:id/ItemCenter"'*)
        [ -n "$SCH_ROW_TITLE" ] || continue
        case "$SCH_ROW_TITLE" in ????-??-??\ ??:??) ;; *) SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue;; esac
        SCH_CENTER="$(printf '%s\n' "$SCH_LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        SCH_USED_H="$(printf '%s' "$SCH_CENTER" | sed -n 's/^\([0-9][0-9.]*\)h.*/\1/p')"
        [ -n "$SCH_USED_H" ] || { SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue; }
        SCH_USED_MIN="$(awk -v h="$SCH_USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
        [ "$SCH_USED_MIN" -ge "$MIN_MINUTES" ] || { SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue; }
        should_skip_session "$SCH_ROW_TITLE" && { SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue; }
        SCH_Y1="$(printf '%s' "$SCH_ROW_BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
        SCH_Y2="$(printf '%s' "$SCH_ROW_BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
        [ -n "$SCH_Y1" ] && [ -n "$SCH_Y2" ] || return 2
        TARGET="$SCH_ROW_TITLE"; TARGET_USED="$SCH_USED_H"; TARGET_Y=$(( (SCH_Y1 + SCH_Y2) / 2 )); return 0;;
    esac
  done < "$SCH_N"
  return 1
}

open_target_detail() {
  OTD_TARGET="$1"; OTD_INITIAL_Y="$2"; OTD_SEQ="$3"; OTD_TRY=1; OTD_Y="$OTD_INITIAL_Y"
  while [ "$OTD_TRY" -le "$DETAIL_TAP_RETRIES" ]; do
    echo "Detail tap: session=$OTD_TARGET try=$OTD_TRY y=$OTD_Y"
    input tap 700 "$OTD_Y" >/dev/null 2>&1; sleep 2
    OTD_VERIFY="$TMP/detail-verify-$OTD_SEQ-$OTD_TRY.xml"
    dump "$OTD_VERIFY" || return 30
    grep -q 'package="com.omarea.vtools"' "$OTD_VERIFY" || return 31
    if grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$OTD_VERIFY" && ! grep -q 'text="历史记录"' "$OTD_VERIFY"; then DETAIL_VERIFY_FILE="$OTD_VERIFY"; return 0; fi
    [ "$OTD_TRY" -lt "$DETAIL_TAP_RETRIES" ] || return 32
    is_history "$OTD_VERIFY" || return 32
    sleep 1; OTD_HISTORY="$TMP/detail-retry-history-$OTD_SEQ-$OTD_TRY.xml"; dump "$OTD_HISTORY" || return 30
    find_target_y "$OTD_HISTORY" "$OTD_TARGET" || return 37
    OTD_Y="$TARGET_Y_CURRENT"; OTD_TRY=$((OTD_TRY+1))
  done
  return 32
}

wait_resolved_detail_page() {
  WRP_SEQ="$1"; WRP_PAGE="$2"; WRP_TRY=1
  while [ "$WRP_TRY" -le "$LABEL_WAIT_TRIES" ]; do
    WRP_XML="$TMP/settled-$WRP_SEQ-$WRP_PAGE-$WRP_TRY.xml"
    dump "$WRP_XML" || return 73
    grep -q 'package="com.omarea.vtools"' "$WRP_XML" || return 74
    grep -q 'text="历史记录"' "$WRP_XML" && return 75
    WRP_TITLES="$TMP/settled-titles-$WRP_SEQ-$WRP_PAGE.txt"
    nodes "$WRP_XML" | grep 'resource-id="com.omarea.vtools:id/itemTitle"' | sed -n 's/.*text="\([^"]*\)".*/\1/p' | sed '/^$/d' > "$WRP_TITLES"
    WRP_COUNT="$(wc -l < "$WRP_TITLES" | tr -d ' ')"; [ -n "$WRP_COUNT" ] || WRP_COUNT=0
    WRP_NONSCENE="$(grep -vc '^Scene$' "$WRP_TITLES" 2>/dev/null || true)"; [ -n "$WRP_NONSCENE" ] || WRP_NONSCENE=0
    # No app rows visible, at least one real label resolved, or a single Scene row
    # (which may legitimately be Scene) are all safe to capture.
    if [ "$WRP_COUNT" -eq 0 ] || [ "$WRP_NONSCENE" -gt 0 ] || [ "$WRP_COUNT" -eq 1 ]; then
      SETTLED_DETAIL_FILE="$WRP_XML"
      [ "$WRP_TRY" -gt 1 ] && echo "Attribution resolved: page=$WRP_PAGE wait=${WRP_TRY}s"
      return 0
    fi
    [ "$WRP_TRY" -eq 1 ] && echo "Waiting for Scene app labels: page=$WRP_PAGE"
    sleep "$LABEL_WAIT_SECONDS"
    WRP_TRY=$((WRP_TRY+1))
  done
  return 72
}

reopen_history_from_detail() {
  RH_SEQ="$1"; RH_TRY=0
  while [ "$RH_TRY" -lt 6 ]; do
    RH_XML="$TMP/reopen-$RH_SEQ-$RH_TRY.xml"; dump "$RH_XML" || return 60
    is_history "$RH_XML" && return 0
    if grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$RH_XML"; then
      tap_id "$RH_XML" 'com.omarea.vtools:id/action_history' || return 61
      sleep 2; RH_VERIFY="$TMP/reopen-verify-$RH_SEQ-$RH_TRY.xml"; dump "$RH_VERIFY" || return 62
      is_history "$RH_VERIFY" && return 0
    fi
    input swipe 720 900 720 2700 450 >/dev/null 2>&1; sleep 1; RH_TRY=$((RH_TRY+1))
  done
  return 63
}

capture_target_detail() {
  CT_TARGET="$1"; CT_USED="$2"; CT_Y="$3"; CT_SEQ="$4"
  echo "Selected: $CT_TARGET used=${CT_USED}h tap_y=$CT_Y"
  open_target_detail "$CT_TARGET" "$CT_Y" "$CT_SEQ"; CT_OPEN_RC=$?; [ "$CT_OPEN_RC" -eq 0 ] || return "$CT_OPEN_RC"
  CT_SAFE="$(printf '%s' "$CT_TARGET" | tr ' :' '--')"; CT_DEST="$OUTDIR/detail-$CT_SAFE-$RUN_ID-$CT_SEQ.txt"; CT_PART="$CT_DEST.partial"
  : > "$CT_PART"; printf 'session_title=%s\ncapture_id=%s-%s\ncapture_at=%s\n' "$CT_TARGET" "$RUN_ID" "$CT_SEQ" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$CT_PART"
  CT_DP=0; CT_PREV=''
  while [ "$CT_DP" -lt "$MAX_DETAIL_PAGES" ]; do
    wait_resolved_detail_page "$CT_SEQ" "$CT_DP"; CT_WAIT_RC=$?
    if [ "$CT_WAIT_RC" -ne 0 ]; then
      CT_BAD="$INVALIDDIR/detail-$CT_SAFE-$RUN_ID-$CT_SEQ-unresolved.txt"
      [ -f "$SETTLED_DETAIL_FILE" ] && nodes "$SETTLED_DETAIL_FILE" | grep -E 'avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$CT_BAD" 2>/dev/null
      printf '"%s",invalid_scene_attribution_unresolved,"%s",%s\n' "$CT_TARGET" "$CT_BAD" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
      echo "INVALID session=$CT_TARGET reason=labels_unresolved_after_${LABEL_WAIT_TRIES}s"
      return 72
    fi
    CT_DXML="$SETTLED_DETAIL_FILE"; CT_DN="$TMP/detail-$CT_SEQ-$CT_DP.nodes"
    nodes "$CT_DXML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$CT_DN" || :
    CT_HASH="$(cksum "$CT_DN" 2>/dev/null | awk '{print $1":"$2}')"
    [ -n "$CT_PREV" ] && [ "$CT_HASH" = "$CT_PREV" ] && break
    printf '\n===== DETAIL PAGE %02d =====\n' "$CT_DP" >> "$CT_PART"; cat "$CT_DN" >> "$CT_PART"
    CT_PREV="$CT_HASH"; CT_DP=$((CT_DP+1)); [ "$CT_DP" -ge "$MAX_DETAIL_PAGES" ] && break
    input swipe 720 2800 720 900 650 >/dev/null 2>&1; sleep 1
  done
  grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$CT_PART" || { rm -f "$CT_PART"; return 40; }
  grep -q 'resource-id="com.omarea.vtools:id/screen_on_duration"' "$CT_PART" || { rm -f "$CT_PART"; return 41; }
  grep -q 'resource-id="com.omarea.vtools:id/predict_time"' "$CT_PART" || { rm -f "$CT_PART"; return 42; }
  raw_attribution_health "$CT_PART"; CT_HEALTH_RC=$?
  if [ "$CT_HEALTH_RC" -ne 0 ]; then
    CT_BAD="$INVALIDDIR/detail-$CT_SAFE-$RUN_ID-$CT_SEQ-invalid.txt"; mv "$CT_PART" "$CT_BAD"
    printf '"%s",invalid_scene_attribution_collapsed,"%s",%s\n' "$CT_TARGET" "$CT_BAD" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
    echo "INVALID session=$CT_TARGET reason=all_titles_scene_after_capture"; return 72
  fi
  mv "$CT_PART" "$CT_DEST"
  [ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
  printf '"%s",captured,"%s",%s\n' "$CT_TARGET" "$CT_DEST" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
  echo "CAPTURED session=$CT_TARGET pages=$CT_DP"; echo "file=$CT_DEST"
  reopen_history_from_detail "$CT_SEQ"; return $?
}

echo '# iQOO 12 Pro Scene backlog drain v1.3'
echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds. This is the only manual handoff.'
sleep 7
open_fresh_history_once; INIT_RC=$?
[ "$INIT_RC" -eq 0 ] || { [ "$INIT_RC" -eq 2 ] && echo 'ERROR history_top_validation_failed' || echo 'ERROR could_not_open_fresh_history'; exit 10; }
echo 'History top verified. Automatic backlog drain started.'
CAPTURED=0; TOTAL_SWIPES=0; PREV_SCROLL_SIG=''
while [ "$CAPTURED" -lt "$MAX_CAPTURES" ]; do
  CUR="$TMP/history-current.xml"; dump "$CUR" || { echo 'ERROR history_dump_current'; exit 20; }; is_history "$CUR" || { echo 'ERROR left_history_page'; exit 21; }
  scan_current_history "$CUR"; SCAN_RC=$?
  if [ "$SCAN_RC" -eq 0 ]; then
    NEXT_SEQ=$((CAPTURED+1)); capture_target_detail "$TARGET" "$TARGET_USED" "$TARGET_Y" "$NEXT_SEQ"; CAP_RC=$?
    [ "$CAP_RC" -eq 0 ] || { case "$CAP_RC" in 72) echo "ERROR attribution_unresolved session=$TARGET";; 30|31|32|33|37) echo "ERROR detail_open rc=$CAP_RC session=$TARGET";; 60|61|62|63) echo "ERROR reopen_history rc=$CAP_RC session=$TARGET";; *) echo "ERROR capture_target_detail rc=$CAP_RC session=$TARGET";; esac; exit "$CAP_RC"; }
    CAPTURED=$NEXT_SEQ; PREV_SCROLL_SIG=''; continue
  fi
  [ "$SCAN_RC" -eq 1 ] || { echo 'ERROR bad_history_row_bounds'; exit 22; }
  CUR_N="$TMP/history-scroll-$TOTAL_SWIPES.nodes"; nodes "$CUR" > "$CUR_N"; CUR_SIG="$(cksum "$CUR_N" 2>/dev/null | awk '{print $1":"$2}')"
  if [ -n "$PREV_SCROLL_SIG" ] && [ "$CUR_SIG" = "$PREV_SCROLL_SIG" ]; then echo "NO_NEW_ELIGIBLE_SESSION captured=$CAPTURED swipes=$TOTAL_SWIPES"; echo 'BACKLOG DONE'; exit 0; fi
  PREV_SCROLL_SIG="$CUR_SIG"
  [ "$TOTAL_SWIPES" -lt "$MAX_HISTORY_SWIPES" ] || { echo "ERROR max_history_swipes_reached captured=$CAPTURED swipes=$TOTAL_SWIPES"; exit 23; }
  input swipe 720 "$HISTORY_SWIPE_START" 720 "$HISTORY_SWIPE_END" 550 >/dev/null 2>&1; sleep 1; TOTAL_SWIPES=$((TOTAL_SWIPES+1))
done
echo "ERROR max_captures_reached captured=$CAPTURED"; exit 24
