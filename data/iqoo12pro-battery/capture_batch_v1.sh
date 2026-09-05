#!/system/bin/sh
# Thin batch driver for Scene capture-next worker v1.2.
# It does not source or share worker state. Each session is a fresh child process.

BASE=/sdcard/SceneBattery
WORKER="$BASE/capture_next_session_v1_2.sh"
BATCH_MAX=${SCENE_BATTERY_BATCH_MAX:-2}
LOGDIR="$BASE/batch_logs"
RUN_ID="$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$LOGDIR"

[ -f "$WORKER" ] || {
  echo "ERROR worker_missing: $WORKER"
  exit 2
}

case "$BATCH_MAX" in
  ''|*[!0-9]*) echo "ERROR invalid_batch_max=$BATCH_MAX"; exit 3;;
esac
[ "$BATCH_MAX" -gt 0 ] || { echo 'ERROR batch_max_must_be_positive'; exit 4; }

echo '# Scene battery thin batch driver v1.1'
echo "batch_max=$BATCH_MAX"
echo 'Keep Scene on 耗电统计/历史记录; each child captures at most one session and exits.'

I=1
CAPTURED=0
while [ "$I" -le "$BATCH_MAX" ]; do
  LOG="$LOGDIR/$RUN_ID-$I.log"
  echo "===== WORKER $I/$BATCH_MAX ====="
  sh "$WORKER" > "$LOG" 2>&1
  RC=$?
  cat "$LOG"

  if grep -q '^CAPTURED session=' "$LOG"; then
    CAPTURED=$((CAPTURED+1))
  fi

  if grep -q '^NO_NEW_ELIGIBLE_SESSION' "$LOG"; then
    echo 'BATCH STOP no_new_eligible_session'
    break
  fi

  if [ "$RC" -ne 0 ]; then
    echo "BATCH STOP worker_failed rc=$RC"
    exit "$RC"
  fi

  I=$((I+1))
done

echo "BATCH DONE captured=$CAPTURED"
exit 0
