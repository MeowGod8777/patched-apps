#!/system/bin/sh
# iQOO 12 Pro battery-ledger v0 network context watcher
# Intended for Shizuku Runner / shell UID.
# Low-overhead design: route lookup once per minute; only logs state changes.

BASE=/sdcard/SceneBattery
RUNTIME=/data/local/tmp/scene_battery
LOG="$BASE/network_timeline.csv"
PIDFILE="$RUNTIME/network_watch.pid"
INTERVAL=${SCENE_BATTERY_NET_INTERVAL:-60}

mkdir -p "$BASE" "$RUNTIME"

get_ssid() {
  # Only queried when a state change is detected or the current route is VPN/unknown.
  # cmd wifi status output differs slightly between Android builds, so keep fallbacks.
  OUT="$(cmd wifi status 2>/dev/null)"
  SSID="$(printf '%s\n' "$OUT" | sed -n 's/.*SSID: \([^,]*\), BSSID:.*/\1/p' | head -n 1)"
  [ -n "$SSID" ] || SSID="$(printf '%s\n' "$OUT" | sed -n 's/.*SSID: \([^,]*\).*/\1/p' | head -n 1)"
  case "$SSID" in
    '<unknown ssid>'|'unknown'|'null') SSID='' ;;
  esac
  printf '%s' "$SSID"
}

sample_state() {
  ROUTE="$(ip route get 1.1.1.1 2>/dev/null | head -n 1)"
  IFACE="$(printf '%s\n' "$ROUTE" | sed -n 's/.* dev \([^ ]*\).*/\1/p')"
  TRANSPORT=unknown
  SSID=''

  case "$IFACE" in
    wlan*|wifi*)
      TRANSPORT=wifi
      SSID="$(get_ssid)"
      ;;
    rmnet*|v4-rmnet*|v6-rmnet*|ccmni*|pdp*|wwan*)
      TRANSPORT=cellular
      ;;
    tun*|tap*|wg*)
      SSID="$(get_ssid)"
      if [ -n "$SSID" ]; then
        TRANSPORT=wifi_vpn
      else
        TRANSPORT=cellular_vpn_or_unknown
      fi
      ;;
    '')
      SSID="$(get_ssid)"
      if [ -n "$SSID" ]; then TRANSPORT=wifi_no_route; fi
      ;;
    *)
      SSID="$(get_ssid)"
      if [ -n "$SSID" ]; then TRANSPORT=wifi_other_route; fi
      ;;
  esac

  printf '%s|%s|%s' "$TRANSPORT" "$IFACE" "$SSID"
}

append_state() {
  STATE="$1"
  TS="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  TRANSPORT="${STATE%%|*}"
  REST="${STATE#*|}"
  IFACE="${REST%%|*}"
  SSID="${REST#*|}"
  if [ ! -f "$LOG" ]; then
    printf 'timestamp,transport,iface,ssid\n' > "$LOG"
  fi
  # Escape the only CSV field likely to contain punctuation/space.
  SAFE_SSID="$(printf '%s' "$SSID" | sed 's/"/""/g')"
  printf '%s,%s,%s,"%s"\n' "$TS" "$TRANSPORT" "$IFACE" "$SAFE_SSID" >> "$LOG"
  printf '%s  %s  iface=%s  ssid=%s\n' "$TS" "$TRANSPORT" "$IFACE" "$SSID"
}

run_loop() {
  LAST=''
  while :; do
    STATE="$(sample_state)"
    if [ "$STATE" != "$LAST" ]; then
      append_state "$STATE"
      LAST="$STATE"
    fi
    sleep "$INTERVAL"
  done
}

is_running() {
  [ -f "$PIDFILE" ] || return 1
  PID="$(cat "$PIDFILE" 2>/dev/null)"
  [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null
}

case "${1:-}" in
  start)
    if is_running; then
      echo "already running pid=$(cat "$PIDFILE")"
      exit 0
    fi
    if command -v nohup >/dev/null 2>&1; then
      nohup sh "$0" _run >/dev/null 2>&1 &
    else
      sh "$0" _run >/dev/null 2>&1 &
    fi
    PID=$!
    echo "$PID" > "$PIDFILE"
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
      echo "started pid=$PID interval=${INTERVAL}s"
      echo "log=$LOG"
    else
      echo "ERROR: watcher exited immediately"
      rm -f "$PIDFILE"
      exit 1
    fi
    ;;
  stop)
    if is_running; then
      PID="$(cat "$PIDFILE")"
      kill "$PID" 2>/dev/null
      rm -f "$PIDFILE"
      echo "stopped pid=$PID"
    else
      rm -f "$PIDFILE"
      echo "not running"
    fi
    ;;
  status)
    if is_running; then
      echo "running pid=$(cat "$PIDFILE")"
    else
      echo "not running"
    fi
    [ -f "$LOG" ] && tail -n 10 "$LOG"
    ;;
  once)
    append_state "$(sample_state)"
    ;;
  _run)
    run_loop
    ;;
  *)
    echo "usage: sh $0 {start|stop|status|once}"
    ;;
esac
