#!/system/bin/sh
# iQOO 12 Pro Scene battery ledger - backlog drain supervisor v1.5
#
# v1.4 correctly rejects unresolved default "Scene" labels, but it aborts the
# entire backlog on rc=72/76. Also, after the first unresolved dump it polls
# UIAutomator every second, which may leave too little quiet time for Scene's
# async AppInfoLoader/Main dispatcher to finish updating RecyclerView labels.
#
# v1.5 deliberately keeps the proven v1.4 capture logic and changes only the
# orchestration/timing around it:
#   - longer quiet settle before the first attribution dump;
#   - 5 s between attribution dumps instead of 1 s;
#   - automatic restart/resume when v1.4 returns attribution rc=72/76;
#   - valid captures remain skipped by v1.4's latest-manifest semantics;
#   - invalid/unresolved sessions are retried automatically.
#
# No background '&', no force-stop, no CLEAR_TASK, no ActivityMain state machine.

BASE=/sdcard/SceneBattery
WORKER="$BASE/capture_backlog_v1_4.sh"
PINNED_URL='https://raw.githubusercontent.com/MeowGod8777/patched-apps/d025ec5504165c920c776756c07f9e3ce2caa86f/data/iqoo12pro-battery/capture_backlog_v1_4.sh'
MAX_AUTO_RESUMES=${SCENE_BATTERY_MAX_AUTO_RESUMES:-12}
QUIET_INITIAL=${SCENE_BATTERY_V15_INITIAL_SETTLE:-5}
QUIET_BETWEEN=${SCENE_BATTERY_V15_WAIT_SECONDS:-5}
WAIT_TRIES=${SCENE_BATTERY_V15_WAIT_TRIES:-8}
RESUME_COOLDOWN=${SCENE_BATTERY_V15_RESUME_COOLDOWN:-8}

mkdir -p "$BASE"

if [ ! -s "$WORKER" ]; then
  echo 'v1.4 worker missing; fetching pinned worker...'
  curl -fL --retry 3 "$PINNED_URL" -o "$WORKER" || {
    echo 'ERROR could_not_fetch_v1_4_worker'
    exit 90
  }
  chmod 700 "$WORKER" 2>/dev/null || :
fi

RESUMES=0

echo '# iQOO 12 Pro Scene backlog drain v1.5 supervisor'
echo "quiet_initial=${QUIET_INITIAL}s quiet_between=${QUIET_BETWEEN}s wait_tries=$WAIT_TRIES max_auto_resumes=$MAX_AUTO_RESUMES"
echo 'Switch to Scene -> 耗电统计 (or History) during the first 7-second handoff only.'

while [ "$RESUMES" -le "$MAX_AUTO_RESUMES" ]; do
  echo "===== v1.5 pass=$((RESUMES+1)) ====="

  SCENE_BATTERY_LABEL_INITIAL_SETTLE="$QUIET_INITIAL" \
  SCENE_BATTERY_LABEL_WAIT_SECONDS="$QUIET_BETWEEN" \
  SCENE_BATTERY_LABEL_WAIT_TRIES="$WAIT_TRIES" \
  sh "$WORKER"
  RC=$?

  case "$RC" in
    0)
      echo "V1.5 COMPLETE passes=$((RESUMES+1))"
      exit 0
      ;;
    72|76)
      RESUMES=$((RESUMES+1))
      if [ "$RESUMES" -gt "$MAX_AUTO_RESUMES" ]; then
        echo "ERROR v1.5_auto_resume_limit rc=$RC resumes=$RESUMES"
        exit "$RC"
      fi
      echo "AUTO-RESUME attribution_rc=$RC resume=$RESUMES/$MAX_AUTO_RESUMES cooldown=${RESUME_COOLDOWN}s"
      echo 'Keeping Scene foreground; no manual action is needed.'
      sleep "$RESUME_COOLDOWN"
      continue
      ;;
    *)
      echo "ERROR v1.5_child_rc=$RC"
      exit "$RC"
      ;;
  esac
done

exit 91
