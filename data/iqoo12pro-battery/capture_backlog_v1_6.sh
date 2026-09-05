#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - backlog drain supervisor v1.6
#
# v1.5 could detect attribution collapse but then simply re-ran v1.4 while Scene
# was still sitting on the failed detail page. v1.4's fresh-history entry contract
# cannot recover from that state, so "AUTO-RESUME" was not actually self-healing.
#
# v1.6 adds an explicit Scene recovery transaction before every retry:
#   1) leave Scene to HOME;
#   2) reopen exported ActivityMain on the 功能 tab (select_tab=0);
#   3) locate/tap nav_power_utilization via UIAutomator;
#   4) verify the battery page by action_history;
#   5) only then start the next v1.4 pass.
#
# If two attribution failures occur consecutively without any new valid capture,
# v1.6 escalates from a soft reopen to `am kill` + reopen. `am kill` is used only
# while Scene is backgrounded; no force-stop and no CLEAR_TASK are used.
# Raw captures stay immutable and v1.4 manifest latest-state semantics are kept.

BASE=/sdcard/SceneBattery
WORKER="$BASE/capture_backlog_v1_4.sh"
MANIFEST="$BASE/sync_manifest.csv"
PINNED_URL='https://raw.githubusercontent.com/MeowGod8777/patched-apps/d025ec5504165c920c776756c07f9e3ce2caa86f/data/iqoo12pro-battery/capture_backlog_v1_4.sh'
MAX_AUTO_RESUMES=${SCENE_BATTERY_MAX_AUTO_RESUMES:-20}
QUIET_INITIAL=${SCENE_BATTERY_V16_INITIAL_SETTLE:-5}
QUIET_BETWEEN=${SCENE_BATTERY_V16_WAIT_SECONDS:-5}
WAIT_TRIES=${SCENE_BATTERY_V16_WAIT_TRIES:-8}
RECOVERY_TRIES=${SCENE_BATTERY_V16_RECOVERY_TRIES:-8}
RECOVERY_SETTLE=${SCENE_BATTERY_V16_RECOVERY_SETTLE:-3}
HARD_AFTER=${SCENE_BATTERY_V16_HARD_AFTER:-2}
TMP="$BASE/v16_tmp/$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$BASE" "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

nodes() { sed 's/></>\n</g' "$1"; }
dump_ui() { rm -f "$1"; uiautomator dump "$1" >/dev/null 2>&1 && [ -s "$1" ]; }
is_battery() { grep -q 'package="com.omarea.vtools"' "$1" && grep -q 'resource-id="com.omarea.vtools:id/action_history"' "$1"; }

bounds_for_id() {
  V16_BF_FILE="$1"; V16_BF_ID="$2"
  nodes "$V16_BF_FILE" | grep "resource-id=\"$V16_BF_ID\"" | head -n1 \
    | sed -n 's/.*bounds="\[\([0-9]*\),\([0-9]*\)\]\[\([0-9]*\),\([0-9]*\)\]".*/\1 \2 \3 \4/p'
}

tap_id() {
  V16_TI_FILE="$1"; V16_TI_ID="$2"; V16_TI_B="$(bounds_for_id "$V16_TI_FILE" "$V16_TI_ID")"
  set -- $V16_TI_B
  [ "$#" -eq 4 ] || return 1
  input tap $((($1+$3)/2)) $((($2+$4)/2)) >/dev/null 2>&1
}

captured_count() {
  [ -f "$MANIFEST" ] || { echo 0; return; }
  grep -c ',captured,' "$MANIFEST" 2>/dev/null || echo 0
}

open_power_page() {
  V16_OP_TRY=1
  while [ "$V16_OP_TRY" -le "$RECOVERY_TRIES" ]; do
    am start -W -n com.omarea.vtools/.activities.ActivityMain --ei select_tab 0 >/dev/null 2>&1 || :
    sleep "$RECOVERY_SETTLE"

    V16_OP_XML="$TMP/recover-$RECOVER_SEQ-$V16_OP_TRY.xml"
    dump_ui "$V16_OP_XML" || { V16_OP_TRY=$((V16_OP_TRY+1)); continue; }

    if is_battery "$V16_OP_XML"; then
      echo "RECOVERY battery_page_verified try=$V16_OP_TRY"
      return 0
    fi

    if grep -q 'resource-id="com.omarea.vtools:id/nav_power_utilization"' "$V16_OP_XML"; then
      tap_id "$V16_OP_XML" 'com.omarea.vtools:id/nav_power_utilization' || {
        V16_OP_TRY=$((V16_OP_TRY+1)); continue
      }
      sleep 2
      V16_OP_VERIFY="$TMP/recover-verify-$RECOVER_SEQ-$V16_OP_TRY.xml"
      dump_ui "$V16_OP_VERIFY" || { V16_OP_TRY=$((V16_OP_TRY+1)); continue; }
      if is_battery "$V16_OP_VERIFY"; then
        echo "RECOVERY power_page_opened try=$V16_OP_TRY"
        return 0
      fi
    fi

    V16_OP_TRY=$((V16_OP_TRY+1))
  done
  return 1
}

recover_scene() {
  V16_MODE="$1"
  RECOVER_SEQ=$((RECOVER_SEQ+1))
  echo "RECOVERY begin mode=$V16_MODE seq=$RECOVER_SEQ"

  input keyevent 3 >/dev/null 2>&1 || :
  sleep 1

  if [ "$V16_MODE" = hard ]; then
    am kill com.omarea.vtools >/dev/null 2>&1 || :
    sleep 2
  fi

  open_power_page || {
    echo "ERROR recovery_failed mode=$V16_MODE seq=$RECOVER_SEQ"
    return 1
  }

  echo "RECOVERY ready mode=$V16_MODE seq=$RECOVER_SEQ"
  return 0
}

if [ ! -s "$WORKER" ]; then
  echo 'v1.4 worker missing; fetching pinned worker...'
  curl -fL --retry 3 "$PINNED_URL" -o "$WORKER" || {
    echo 'ERROR could_not_fetch_v1_4_worker'
    exit 90
  }
  chmod 700 "$WORKER" 2>/dev/null || :
fi

RESUMES=0
ATTR_FAIL_STREAK=0
RECOVER_SEQ=0
FIRST_PASS=1

echo '# iQOO 12 Pro Scene backlog drain v1.6 supervisor'
echo "quiet_initial=${QUIET_INITIAL}s quiet_between=${QUIET_BETWEEN}s wait_tries=$WAIT_TRIES max_auto_resumes=$MAX_AUTO_RESUMES"
echo 'First pass only: switch to Scene -> 耗电统计 (or History) during the 7-second handoff.'

while [ "$RESUMES" -le "$MAX_AUTO_RESUMES" ]; do
  echo "===== v1.6 pass=$((RESUMES+1)) ====="

  if [ "$FIRST_PASS" -eq 0 ]; then
    V16_RECOVERY_MODE=soft
    [ "$ATTR_FAIL_STREAK" -ge "$HARD_AFTER" ] && V16_RECOVERY_MODE=hard
    recover_scene "$V16_RECOVERY_MODE" || exit 92
    [ "$V16_RECOVERY_MODE" = hard ] && ATTR_FAIL_STREAK=0
  fi

  BEFORE_CAPTURED="$(captured_count)"

  SCENE_BATTERY_LABEL_INITIAL_SETTLE="$QUIET_INITIAL" \
  SCENE_BATTERY_LABEL_WAIT_SECONDS="$QUIET_BETWEEN" \
  SCENE_BATTERY_LABEL_WAIT_TRIES="$WAIT_TRIES" \
  sh "$WORKER"
  RC=$?

  AFTER_CAPTURED="$(captured_count)"
  if [ "$AFTER_CAPTURED" -gt "$BEFORE_CAPTURED" ] 2>/dev/null; then
    ATTR_FAIL_STREAK=0
  fi

  case "$RC" in
    0)
      echo "V1.6 COMPLETE passes=$((RESUMES+1))"
      exit 0
      ;;
    72|76)
      ATTR_FAIL_STREAK=$((ATTR_FAIL_STREAK+1))
      RESUMES=$((RESUMES+1))
      if [ "$RESUMES" -gt "$MAX_AUTO_RESUMES" ]; then
        echo "ERROR v1.6_auto_resume_limit rc=$RC resumes=$RESUMES"
        exit "$RC"
      fi
      echo "AUTO-RECOVER attribution_rc=$RC resume=$RESUMES/$MAX_AUTO_RESUMES streak=$ATTR_FAIL_STREAK"
      FIRST_PASS=0
      continue
      ;;
    *)
      echo "ERROR v1.6_child_rc=$RC"
      exit "$RC"
      ;;
  esac
done

exit 91
