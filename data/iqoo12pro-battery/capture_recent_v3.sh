#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - recent incremental capture v3
#
# Forward-only routine capture. Do NOT use this as a deep backlog drainer.
# It captures only a very small number of recent finalized History sessions and
# relies on the existing latest-manifest + attribution-health logic from v1.4.
#
# Important correction from v2:
# ActivityPowerUtilization battery_capacity / battery_temperature / battery_voltage /
# battery_status are current-page GlobalStatus values, not historical-session values.
# Therefore v3 does NOT scroll to the detail-page top just to collect those fields;
# canonical ingestion must ignore those header values for old History sessions.
#
# The History summary is rounded to 0.1 h, so acquisition uses a low 15-minute
# prefilter. Canonical eligibility is still decided later from exact detail
# screen_on_duration: <20 min excluded, 20-30 min provisional, >=30 min main.

BASE=/sdcard/SceneBattery
WORKER="$BASE/capture_backlog_v1_4.sh"
PINNED_URL='https://raw.githubusercontent.com/MeowGod8777/patched-apps/d025ec5504165c920c776756c07f9e3ce2caa86f/data/iqoo12pro-battery/capture_backlog_v1_4.sh'

[ -s "$WORKER" ] || {
  echo 'v1.4 worker missing; fetching pinned worker...'
  curl -fL --retry 3 "$PINNED_URL" -o "$WORKER" || exit 90
  chmod 700 "$WORKER" 2>/dev/null || :
}

echo '# Scene recent incremental capture v3'
echo 'Forward-only: at most 2 recent new sessions per run; no abandoned July backlog drain.'
echo 'Switch to Scene -> 耗电统计 (or History) within the 7-second handoff.'

SCENE_BATTERY_MIN_FINAL_MINUTES=${SCENE_BATTERY_RECENT_PREFILTER_MINUTES:-15} \
SCENE_BATTERY_BACKLOG_MAX_SWIPES=${SCENE_BATTERY_RECENT_MAX_SWIPES:-1} \
SCENE_BATTERY_BACKLOG_MAX_CAPTURES=${SCENE_BATTERY_RECENT_MAX_CAPTURES:-2} \
SCENE_BATTERY_LABEL_INITIAL_SETTLE=${SCENE_BATTERY_RECENT_INITIAL_SETTLE:-5} \
SCENE_BATTERY_LABEL_WAIT_SECONDS=${SCENE_BATTERY_RECENT_WAIT_SECONDS:-5} \
SCENE_BATTERY_LABEL_WAIT_TRIES=${SCENE_BATTERY_RECENT_WAIT_TRIES:-6} \
sh "$WORKER"
RC=$?

case "$RC" in
  0)
    echo 'RECENT V3 DONE'
    exit 0
    ;;
  23)
    echo 'RECENT V3 DONE shallow_scan_limit'
    exit 0
    ;;
  24)
    echo 'RECENT V3 DONE capture_cap_reached'
    exit 0
    ;;
  72|75|76)
    echo "RECENT V3 RETRY_LATER rc=$RC"
    echo 'Reopen Scene and verify CPU/GPU/memory are normal; retry later. No bad raw is canonicalized.'
    exit "$RC"
    ;;
  *)
    echo "RECENT V3 ERROR rc=$RC"
    exit "$RC"
    ;;
esac
