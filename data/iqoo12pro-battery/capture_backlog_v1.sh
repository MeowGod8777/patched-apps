#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - one-shot backlog drain v1.0
# User starts this once from Runner, switches to Scene -> 耗电统计 once during the
# initial handoff window, then the script stays in Scene and drains all finalized
# >=30 min History sessions without returning to Runner between sessions.
#
# Design:
# - Reuses the proven v1.1.1 History/detail transaction.
# - Initial History normalization happens exactly once.
# - After each detail capture, Back returns to the same History viewport.
# - The next eligible row is selected from that viewport; only when none remains
#   does the script make one small overlapping downward swipe.
# - Manifest dedupe is authoritative; raw detail files are immutable.

BASE=/sdcard/SceneBattery
OUTDIR="$BASE/sync_raw"
MANIFEST="$BASE/sync_manifest.csv"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
TMP="$BASE/backlog_tmp/$RUN_ID"
mkdir -p "$OUTDIR" "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

MIN_MINUTES=${SCENE_BATTERY_MIN_FINAL_MINUTES:-30}
MAX_DETAIL_PAGES=${SCENE_BATTERY_MAX_DETAIL_PAGES:-8}
MAX_HISTORY_SWIPES=${SCENE_BATTERY_BACKLOG_MAX_SWIPES:-120}
MAX_CAPTURES=${SCENE_BATTERY_BACKLOG_MAX_CAPTURES:-200}
HISTORY_SWIPE_START=${SCENE_BATTERY_HISTORY_SWIPE_START:-2600}
HISTORY_SWIPE_END=${SCENE_BATTERY_HISTORY_SWIPE_END:-1700}

nodes() { sed 's/></>\n</g' "$1"; }
dump() { rm -f "$1"; uiautomator dump "$1" >/dev/null 2>&1 && [ -s "$1" ]; }
is_history() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'text="历史记录"' "$1"; }
is_battery() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$1"; }

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
  input tap 1125 256 >/dev/null 2>&1
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

capture_target_detail() {
  CT_TARGET="$1"
  CT_USED="$2"
  CT_Y="$3"
  CT_SEQ="$4"

  echo "Selected: $CT_TARGET used=${CT_USED}h tap_y=$CT_Y"
  input tap 700 "$CT_Y" >/dev/null 2>&1
  sleep 2

  CT_VERIFY="$TMP/detail-verify-$CT_SEQ.xml"
  dump "$CT_VERIFY" || return 30
  grep -q 'package="com.omarea.vtools"' "$CT_VERIFY" || return 31
  grep -q 'resource-id="com.omarea.vtools:id/avg_power"' "$CT_VERIFY" || return 32
  grep -q 'text="历史记录"' "$CT_VERIFY" && return 33

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
    if [ "$CT_DP" -eq 0 ]; then
      cp "$CT_VERIFY" "$CT_DXML"
    else
      dump "$CT_DXML" || { rm -f "$CT_PART"; return 34; }
    fi

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

  # Return from detail to the exact History viewport that launched it.
  input keyevent 4 >/dev/null 2>&1
  sleep 1
  CT_BACK="$TMP/history-return-$CT_SEQ.xml"
  dump "$CT_BACK" || return 50
  is_history "$CT_BACK" || return 51
  return 0
}

echo '# iQOO 12 Pro Scene backlog drain v1.0'
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
SWIPES=0
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
      echo "ERROR capture_target_detail rc=$CAP_RC session=$TARGET"
      exit "$CAP_RC"
    }
    CAPTURED=$NEXT_SEQ
    # A successful capture does not advance History. Re-scan this same viewport;
    # the just-captured row is now skipped by manifest and the next row can be taken.
    PREV_SCROLL_SIG=''
    continue
  fi

  [ "$SCAN_RC" -eq 1 ] || { echo 'ERROR bad_history_row_bounds'; exit 22; }

  CUR_N="$TMP/history-scroll-$SWIPES.nodes"
  nodes "$CUR" > "$CUR_N"
  CUR_SIG="$(cksum "$CUR_N" 2>/dev/null | awk '{print $1":"$2}')"
  if [ -n "$PREV_SCROLL_SIG" ] && [ "$CUR_SIG" = "$PREV_SCROLL_SIG" ]; then
    echo "NO_NEW_ELIGIBLE_SESSION captured=$CAPTURED swipes=$SWIPES"
    echo 'BACKLOG DONE'
    exit 0
  fi
  PREV_SCROLL_SIG="$CUR_SIG"

  [ "$SWIPES" -lt "$MAX_HISTORY_SWIPES" ] || {
    echo "ERROR max_history_swipes_reached captured=$CAPTURED swipes=$SWIPES"
    exit 23
  }

  input swipe 720 "$HISTORY_SWIPE_START" 720 "$HISTORY_SWIPE_END" 550 >/dev/null 2>&1
  sleep 1
  SWIPES=$((SWIPES+1))
done

echo "ERROR max_captures_reached captured=$CAPTURED"
exit 24
