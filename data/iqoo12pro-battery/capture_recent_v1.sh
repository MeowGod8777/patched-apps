#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - recent incremental capture v1
#
# Purpose: capture only recent finalized Scene History sessions and avoid crawling
# the old intentionally-uncollected July backlog. This wraps the proven v1.4 worker
# with a shallow History scan and small per-run capture cap.
#
# Expected use: run once per day or every 1-2 days after opening Scene -> 耗电统计.
# MacroDroid continues logging network context independently.

BASE=/sdcard/SceneBattery
WORKER="$BASE/capture_backlog_v1_4.sh"
PINNED_URL='https://raw.githubusercontent.com/MeowGod8777/patched-apps/d025ec5504165c920c776756c07f9e3ce2caa86f/data/iqoo12pro-battery/capture_backlog_v1_4.sh'

[ -s "$WORKER" ] || {
  echo 'v1.4 worker missing; fetching pinned worker...'
  curl -fL --retry 3 "$PINNED_URL" -o "$WORKER" || exit 90
  chmod 700 "$WORKER" 2>/dev/null || :
}

echo '# Scene recent incremental capture v1'
echo 'Goal: recent finalized sessions only; old backlog is intentionally not drained.'
echo 'Switch to Scene -> 耗电统计 (or History) within the worker 7-second handoff.'

SCENE_BATTERY_BACKLOG_MAX_SWIPES=${SCENE_BATTERY_RECENT_MAX_SWIPES:-2} \
SCENE_BATTERY_BACKLOG_MAX_CAPTURES=${SCENE_BATTERY_RECENT_MAX_CAPTURES:-6} \
SCENE_BATTERY_LABEL_INITIAL_SETTLE=${SCENE_BATTERY_RECENT_INITIAL_SETTLE:-5} \
SCENE_BATTERY_LABEL_WAIT_SECONDS=${SCENE_BATTERY_RECENT_WAIT_SECONDS:-5} \
SCENE_BATTERY_LABEL_WAIT_TRIES=${SCENE_BATTERY_RECENT_WAIT_TRIES:-8} \
sh "$WORKER"
RC=$?

case "$RC" in
  0)
    echo 'RECENT SYNC DONE'
    exit 0
    ;;
  23)
    # Shallow scan exhausted by design. This is normal for incremental mode.
    echo 'RECENT SYNC DONE shallow_scan_limit'
    exit 0
    ;;
  24)
    # Per-run capture cap reached by design. Run again later if desired.
    echo 'RECENT SYNC DONE capture_cap_reached'
    exit 0
    ;;
  72|75|76)
    echo "RECENT SYNC RETRY_LATER rc=$RC"
    echo 'Scene attribution/backend became unhealthy. Reopen Scene, verify CPU/GPU/memory values, then rerun this script.'
    exit "$RC"
    ;;
  *)
    echo "RECENT SYNC ERROR rc=$RC"
    exit "$RC"
    ;;
esac
