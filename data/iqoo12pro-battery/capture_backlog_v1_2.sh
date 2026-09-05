#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - one-shot backlog drain v1.2
# One manual handoff only: start from Runner, switch once to Scene -> 耗电统计.
# After that, stay inside ActivityPowerStat and drain History automatically.
#
# v1.2 fixes the v1.1 failure pattern where the first row after manual handoff
# captured correctly, but a later row selected after programmatic History reopen
# sometimes did not open on the first coordinate tap. The worker now re-dumps the
# current History UI, re-resolves the exact timestamp row bounds, and retries that
# same row up to three times before failing. It also reports detail-open failures
# separately from History-reopen failures.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
MANIFEST="$BASE/sync_manifest.csv"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$BASE/backlog_tmp/$RUN_ID"
mkdir -p "$OUTDIR" "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}
MAX_HISTORY_SWIPES=${SCENE_BATTERY_BACKLOG_MAX_SWIPES:-240}
MAX_CAPTURES=${SCENE_BATTERY_BACKLOG_MAX_CAPTURES:-200}
DETAIL_TAP_RETRIES=${SCENE_BATTERY_DETAIL_TAP_RETRIES:-3}
HISTORY_SWIPE_START=${SCENE_BATTERY_HISTORY_SWIPE_START:-2600}
HISTORY_SWIPE_END=${SCENE_BATTERY_HISTORY_SWIPE_END:-1700}

nodes() { sed 's/></>\n</g' "$1"; }
dump() { rm -f "$1"; uiautomator dump "$1" >/dev/null 2>&1 && [ -s "$1" ]; }
is_history() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'text="历史记录"' "$1"; }
is_battery() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$1"; }

bounds_for_id() {
  BF_FILE="$1"
  BF_ID="$2"
  nodes "$BF_FILE" | grep "resource-id=\"$BF_ID\"" | head -n1 | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p'
}

tap_id() {
  TI_FILE="$1"
  TI_ID="$2"
  TI_B="$(bounds_for_id "$TI_FILE" "$TI_ID")"
  set -- $TI_B
  [ "$#" -eq 4 ] || return 1
  input tap $((($1+$3)/2)) $((($2+$4)/2)) >/dev/null 2>&1
}

find_target_y() {
  FTY_FILE="$1"
  FTY_TARGET="$2"
  FTY_LINE="$(nodes "$FTY_FILE" | grep 'resource-id="com.omarea.vtools:id/ItemTitle"' | grep -F "text=\"$FTY_TARGET\"" | head -n1)"
  [ -n "$FTY_LINE" ] || return 1
  FTY_BOUNDS="$(printf '%s\n' "$FTY_LINE" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p')"
  FTY_Y1="$(printf '%s' "$FTY_BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
  FTY_Y2="$(printf '%s' "$FTY_BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
  [ -n "$FTY_Y1" ] && [ -n "$FTY_Y2" ] || return 2
  TARGET_Y_CURRENT=$(( (FTY_Y1 + FTY_Y2) / 2 ))
  return 0
}

open_fresh_history_once() {
  OFH_S="$TMP/initial-state.xml"
  dump "$OFH_S" || return 1
  grep -q 'package="com.omarea.vtools"' "$OFH_S" || return 1

  if is_history "$OFH_S"; then
    input keyevent 4 >/dev/null 2>&1
    sleep 1
    dump "$OFH_S" || return 1
  fi

  if ! is_battery "$OFH_S"; then
    input keyevent 4 >/dev/null 2>&1
    sleep 1
    dump "$OFH_S" || return 1
  fi

  is_battery "$OFH_S" || return 1
  tap_id "$OFH_S" 'com.omarea.vtools:id/action_history' || return 1
  sleep 2
  dump "$OFH_S" || return 1
  is_history "$OFH_S" || return 1

  OFH_N="$TMP/initial-top.nodes"
  nodes "$OFH_S" > "$OFH_N"
  grep 'resource-id="com.omarea.vtools:id/NewTag"' "$OFH_N" | grep -q 'text="today"' || return 2
  OFH_FIRST="$(grep 'resource-id="com.omarea.vtools:id/ItemTitle"' "$OFH_N" | head -n1 | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
  case "$OFH_FIRST" in
    ??:??:??) return 0;;
    *) return 2;;
  esac
}

scan_current_history() {
  SCH_XML="$1"
  SCH_N="$TMP/current.nodes"
  nodes "$SCH_XML" > "$SCH_N"

  TARGET=''
  TARGET_USED=''
  TARGET_Y=''
  SCH_ROW_TITLE=''
  SCH_ROW_BOUNDS=''

  while IFS= read -r SCH_LINE; do
    case "$SCH_LINE" in
      *'resource-id="com.omarea.vtools:id/ItemTitle"'*)
        SCH_ROW_TITLE="$(printf '%s\n' "$SCH_LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        SCH_ROW_BOUNDS="$(printf '%s\n' "$SCH_LINE" | sed -n 's/.*bounds="\([^"]*\)".*/\1/p')"
        ;;
      *'resource-id="com.omarea.vtools:id/ItemCenter"'*)
        [ -n "$SCH_ROW_TITLE" ] || continue
        case "$SCH_ROW_TITLE" in
          ????-??-??\ ??:??) ;;
          *) SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue;;
        esac
        SCH_CENTER="$(printf '%s\n' "$SCH_LINE" | sed -n 's/.*text="\([^"]*\)".*/\1/p')"
        SCH_USED_H="$(printf '%s' "$SCH_CENTER" | sed -n 's/^\([0-9][0-9.]*\)h.*/\1/p')"
        [ -n "$SCH_USED_H" ] || { SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue; }
        SCH_USED_MIN="$(awk -v h="$SCH_USED_H" 'BEGIN{printf "%d", h*60+0.5}')"
        [ "$SCH_USED_MIN" -ge "$MIN_MINUTES" ] || { SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue; }
        if [ -f "$MANIFEST" ] && grep -Fq "\"$SCH_ROW_TITLE\",captured" "$MANIFEST"; then
          SCH_ROW_TITLE=''; SCH_ROW_BOUNDS=''; continue
        fi
        SCH_Y1="$(printf '%s' "$SCH_ROW_BOUNDS" | sed -n 's/^\[[0-9]*,\([0-9]*\)\]\[[0-9]*,[0-9]*\]$/\1/p')"
        SCH_Y2="$(printf '%s' "$SCH_ROW_BOUNDS" | sed -n 's/^\[[0-9]*,[0-9]*\]\[[0-9]*,\([0-9]*\)\]$/\1/p')"
        [ -n "$SCH_Y1" ] && [ -n "$SCH_Y2" ] || return 2
        TARGET="$SCH_ROW_TITLE"
        TARGET_USED="$SCH_USED_H"
        TARGET_Y=$(( (SCH_Y1 + SCH_Y2) / 2 ))
        return 0
        ;;
    esac
  done < "$SCH_N"
  return 1
}

open_target_detail() {
  OTD_TARGET="$1"
  OTD_INITIAL_Y="$2"
  OTD_SEQ="$3"
  OTD_TRY=1
  OTD_Y="$OTD_INITIAL_Y"

  while [ "$OTD_TRY" -le "$DETAIL_TAP_RETRIES" ]; do
    echo "Detail tap: session=$OTD_TARGET try=$OTD_TRY y=$OTD_Y"
    input tap 700 "$OTD_Y" >/dev/null 2>&1
    sleep 2

    OTD_VERIFY="$TMP/detail-verify-$OTD_SEQ-$OTD_TRY.xml"
    dump "$OTD_VERIFY" || return 30
    grep -q 'package="com.omarea.vtools"' "$OTD_VERIFY" || return 31

    if grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$OTD_VERIFY" && ! grep -q 'text="历史记录"' "$OTD_VERIFY"; then
      DETAIL_VERIFY_FILE="$OTD_VERIFY"
      return 0
    fi

    # If Scene has left the History dialog but detail metrics are not populated yet,
    # allow one extra settle/dump before deciding that the tap failed.
    if ! is_history "$OTD_VERIFY"; then
      sleep 1
      OTD_SETTLE="$TMP/detail-settle-$OTD_SEQ-$OTD_TRY.xml"
      dump "$OTD_SETTLE" || return 30
      grep -q 'package="com.omarea.vtools"' "$OTD_SETTLE" || return 31
      if grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$OTD_SETTLE" && ! grep -q 'text="历史记录"' "$OTD_SETTLE"; then
        DETAIL_VERIFY_FILE="$OTD_SETTLE"
        return 0
      fi
      return 32
    fi

    [ "$OTD_TRY" -lt "$DETAIL_TAP_RETRIES" ] || return 32

    # First tap was ignored/intercepted. Re-read the current History layout and
    # resolve this exact timestamp again instead of reusing stale coordinates.
    sleep 1
    OTD_HISTORY="$TMP/detail-retry-history-$OTD_SEQ-$OTD_TRY.xml"
    dump "$OTD_HISTORY" || return 30
    is_history "$OTD_HISTORY" || return 32
    find_target_y "$OTD_HISTORY" "$OTD_TARGET" || return 37
    OTD_Y="$TARGET_Y_CURRENT"
    OTD_TRY=$((OTD_TRY+1))
  done
  return 32
}

reopen_history_from_detail() {
  RH_SEQ="$1"
  RH_TRY=0
  while [ "$RH_TRY" -lt 6 ]; do
    RH_XML="$TMP/reopen-$RH_SEQ-$RH_TRY.xml"
    dump "$RH_XML" || return 60

    if is_history "$RH_XML"; then
      return 0
    fi

    if grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$RH_XML"; then
      tap_id "$RH_XML" 'com.omarea.vtools:id/action_history' || return 61
      sleep 2
      RH_VERIFY="$TMP/reopen-verify-$RH_SEQ-$RH_TRY.xml"
      dump "$RH_VERIFY" || return 62
      is_history "$RH_VERIFY" && return 0
    fi

    input swipe 720 900 720 2700 450 >/dev/null 2>&1
    sleep 1
    RH_TRY=$((RH_TRY+1))
  done
  return 63
}

capture_target_detail() {
  CT_TARGET="$1"
  CT_USED="$2"
  CT_Y="$3"
  CT_SEQ="$4"

  echo "Selected: $CT_TARGET used=${CT_USED}h tap_y=$CT_Y"
  open_target_detail "$CT_TARGET" "$CT_Y" "$CT_SEQ"
  CT_OPEN_RC=$?
  [ "$CT_OPEN_RC" -eq 0 ] || return "$CT_OPEN_RC"

  CT_VERIFY="$DETAIL_VERIFY_FILE"
  CT_SAFE="$(printf '%s' "$CT_TARGET" | tr ' :' '--')"
  CT_DEST="$OUTDIR/detail-$CT_SAFE-$RUN_ID-$CT_SEQ.txt"
  CT_PART="$CT_DEST.partial"
  : > "$CT_PART"
  printf 'session_title=%s\ncapture_id=%s-%s\ncapture_at=%s\n' "$CT_TARGET" "$RUN_ID" "$CT_SEQ" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$CT_PART"

  CT_DP=0
  CT_PREV=''
  while [ "$CT_DP" -lt "$MAX_DETAIL_PAGES" ]; do
    CT_DXML="$TMP/detail-$CT_SEQ-$CT_DP.xml"
    CT_DN="$TMP/detail-$CT_SEQ-$CT_DP.nodes"
    if [ "$CT_DP" -eq 0 ]; then cp "$CT_VERIFY" "$CT_DXML"; else dump "$CT_DXML" || { rm -f "$CT_PART"; return 34; }; fi
    grep -q 'package="com.omarea.vtools"' "$CT_DXML" || { rm -f "$CT_PART"; return 35; }
    grep -q 'text="历史记录"' "$CT_DXML" && { rm -f "$CT_PART"; return 36; }
    nodes "$CT_DXML" | grep -E 'battery_capacity|battery_size|battery_temperature|battery_voltage|battery_status|avg_power|screen_on_duration|predict_time|itemTitle|itemAvgIO|itemTemperature|itemCounts' > "$CT_DN" || :
    CT_HASH="$(cksum "$CT_DN" 2>/dev/null | awk '{print $1":"$2}')"
    [ -n "$CT_PREV" ] && [ "$CT_HASH" = "$CT_PREV" ] && break
    printf '\n===== DETAIL PAGE %02d =====\n' "$CT_DP" >> "$CT_PART"
    cat "$CT_DN" >> "$CT_PART"
    CT_PREV="$CT_HASH"
    CT_DP=$((CT_DP+1))
    [ "$CT_DP" -ge "$MAX_DETAIL_PAGES" ] && break
    input swipe 720 2800 720 900 650 >/dev/null 2>&1
    sleep 1
  done

  grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$CT_PART" || { rm -f "$CT_PART"; return 40; }
  grep -q 'resource-id="com.omarea.vtools:id/screen_on_duration"' "$CT_PART" || { rm -f "$CT_PART"; return 41; }
  grep -q 'resource-id="com.omarea.vtools:id/predict_time"' "$CT_PART" || { rm -f "$CT_PART"; return 42; }

  mv "$CT_PART" "$CT_DEST"
  [ -f "$MANIFEST" ] || printf 'session_title,state,file,updated_at\n' > "$MANIFEST"
  printf '"%s",captured,"%s",%s\n' "$CT_TARGET" "$CT_DEST" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
  echo "CAPTURED session=$CT_TARGET pages=$CT_DP"
  echo "file=$CT_DEST"

  reopen_history_from_detail "$CT_SEQ"
  return $?
}

echo '# iQOO 12 Pro Scene backlog drain v1.2'
echo 'Switch to Scene -> 耗电统计 (or History) within 7 seconds. This is the only manual handoff.'
sleep 7
open_fresh_history_once
INIT_RC=$?
[ "$INIT_RC" -eq 0 ] || {
  [ "$INIT_RC" -eq 2 ] && echo 'ERROR history_top_validation_failed' || echo 'ERROR could_not_open_fresh_history'
  exit 10
}
echo 'History top verified. Automatic backlog drain started.'

CAPTURED=0
TOTAL_SWIPES=0
PREV_SCROLL_SIG=''

while [ "$CAPTURED" -lt "$MAX_CAPTURES" ]; do
  CUR="$TMP/history-current.xml"
  dump "$CUR" || { echo 'ERROR history_dump_current'; exit 20; }
  is_history "$CUR" || { echo 'ERROR left_history_page'; exit 21; }

  scan_current_history "$CUR"
  SCAN_RC=$?

  if [ "$SCAN_RC" -eq 0 ]; then
    NEXT_SEQ=$((CAPTURED+1))
    capture_target_detail "$TARGET" "$TARGET_USED" "$TARGET_Y" "$NEXT_SEQ"
    CAP_RC=$?
    [ "$CAP_RC" -eq 0 ] || {
      case "$CAP_RC" in
        30|31|32|33|37) echo "ERROR detail_open rc=$CAP_RC session=$TARGET";;
        60|61|62|63) echo "ERROR reopen_history rc=$CAP_RC session=$TARGET";;
        *) echo "ERROR capture_target_detail rc=$CAP_RC session=$TARGET";;
      esac
      exit "$CAP_RC"
    }
    CAPTURED=$NEXT_SEQ
    PREV_SCROLL_SIG=''
    continue
  fi

  [ "$SCAN_RC" -eq 1 ] || { echo 'ERROR bad_history_row_bounds'; exit 22; }

  CUR_N="$TMP/history-scroll-$TOTAL_SWIPES.nodes"
  nodes "$CUR" > "$CUR_N"
  CUR_SIG="$(cksum "$CUR_N" 2>/dev/null | awk '{print $1":"$2}')"
  if [ -n "$PREV_SCROLL_SIG" ] && [ "$CUR_SIG" = "$PREV_SCROLL_SIG" ]; then
    echo "NO_NEW_ELIGIBLE_SESSION captured=$CAPTURED swipes=$TOTAL_SWIPES"
    echo 'BACKLOG DONE'
    exit 0
  fi
  PREV_SCROLL_SIG="$CUR_SIG"

  [ "$TOTAL_SWIPES" -lt "$MAX_HISTORY_SWIPES" ] || {
    echo "ERROR max_history_swipes_reached captured=$CAPTURED swipes=$TOTAL_SWIPES"
    exit 23
  }
  input swipe 720 "$HISTORY_SWIPE_START" 720 "$HISTORY_SWIPE_END" 550 >/dev/null 2>&1
  sleep 1
  TOTAL_SWIPES=$((TOTAL_SWIPES+1))
done

echo "ERROR max_captures_reached captured=$CAPTURED"
exit 24
