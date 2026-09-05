#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - recent incremental capture v2
#
# v2 keeps the shallow recent-only strategy from v1, but patches the proven v1.4
# worker at runtime so each opened History detail is first scrolled to the TOP.
# This is important because the historical backlog raws usually started around
# avg_power and therefore omitted battery_capacity / temperature / voltage/status.
# The v1.4 raw filter already knows those IDs; it simply needs them visible once.
#
# Expected use: once per day or every 1-2 days. MacroDroid logs network context
# continuously; this script captures only recent finalized Scene History details.

BASE=/sdcard/SceneBattery
UPSTREAM="$BASE/capture_backlog_v1_4.sh"
PATCHED="$BASE/capture_recent_worker_v2.sh"
PINNED_URL='https://raw.githubusercontent.com/MeowGod8777/patched-apps/d025ec5504165c920c776756c07f9e3ce2caa86f/data/iqoo12pro-battery/capture_backlog_v1_4.sh'

[ -s "$UPSTREAM" ] || {
  echo 'v1.4 worker missing; fetching pinned worker...'
  curl -fL --retry 3 "$PINNED_URL" -o "$UPSTREAM" || exit 90
  chmod 700 "$UPSTREAM" 2>/dev/null || :
}

# Inject a top-of-detail normalization immediately after open_target_detail.
awk '
  { print }
  index($0, "open_target_detail \"$CT_TARGET\" \"$CT_Y\" \"$CT_SEQ\"; CT_OPEN_RC=$?") {
    print "  if [ \"$CT_OPEN_RC\" -eq 0 ]; then"
    print "    input swipe 720 1000 720 2850 550 >/dev/null 2>&1"
    print "    sleep 1"
    print "    input swipe 720 1000 720 2850 550 >/dev/null 2>&1"
    print "    sleep 1"
    print "  fi"
  }
' "$UPSTREAM" > "$PATCHED" || exit 91
chmod 700 "$PATCHED" 2>/dev/null || :

grep -q 'input swipe 720 1000 720 2850' "$PATCHED" || {
  echo 'ERROR recent_v2_patch_not_applied'
  exit 92
}

echo '# Scene recent incremental capture v2'
echo 'Recent finalized sessions only; old July backlog is intentionally not drained.'
echo 'Detail pages are normalized to top first so battery level/temp/voltage can be captured when Scene exposes them.'
echo 'Switch to Scene -> 耗电统计 (or History) within the worker 7-second handoff.'

SCENE_BATTERY_BACKLOG_MAX_SWIPES=${SCENE_BATTERY_RECENT_MAX_SWIPES:-2} \
SCENE_BATTERY_BACKLOG_MAX_CAPTURES=${SCENE_BATTERY_RECENT_MAX_CAPTURES:-6} \
SCENE_BATTERY_LABEL_INITIAL_SETTLE=${SCENE_BATTERY_RECENT_INITIAL_SETTLE:-5} \
SCENE_BATTERY_LABEL_WAIT_SECONDS=${SCENE_BATTERY_RECENT_WAIT_SECONDS:-5} \
SCENE_BATTERY_LABEL_WAIT_TRIES=${SCENE_BATTERY_RECENT_WAIT_TRIES:-8} \
sh "$PATCHED"
RC=$?

case "$RC" in
  0)
    echo 'RECENT SYNC DONE'
    exit 0
    ;;
  23)
    echo 'RECENT SYNC DONE shallow_scan_limit'
    exit 0
    ;;
  24)
    echo 'RECENT SYNC DONE capture_cap_reached'
    exit 0
    ;;
  72|75|76)
    echo "RECENT SYNC RETRY_LATER rc=$RC"
    echo 'Reopen Scene, verify CPU/GPU/memory values are normal, then rerun this script.'
    exit "$RC"
    ;;
  *)
    echo "RECENT SYNC ERROR rc=$RC"
    exit "$RC"
    ;;
esac
