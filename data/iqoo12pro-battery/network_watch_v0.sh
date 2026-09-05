#!/system/bin/sh
# iQOO 12 Pro battery-ledger network context watcher v0.1
# Intended for Shizuku Runner / shell UID.
# VPN is treated as an overlay: classify the underlying Wi-Fi/cellular context.

BASE=/sdcard/SceneBattery
RUNTIME=/data/local/tmp/scene_battery
LOG="$BASE/network_timeline_v01.csv"
PIDFILE="$RUNTIME/network_watch.pid"
INTERVAL=${SCENE_BATTERY_NET_INTERVAL:-60}

mkdir -p "$BASE" "$RUNTIME"

get_ssid() {
  OUT="$(cmd wifi status 2>/dev/null)"
  SSID="$(printf '%s\n' "$OUT" | sed -n 's/.*SSID: \([^,]*\), BSSID:.*/\1/p' | head -n 1)"
  [ -n "$SSID" ] || SSID="$(printf '%s\n' "$OUT" | sed -n 's/.*SSID: \([^,]*\).*/\1/p' | head -n 1)"
  # cmd wifi status may quote the SSID.
  SSID="$(printf '%s' "$SSID" | sed 's/^"//; s/"$//')"
  case "$SSID" in
    '<unknown ssid>'|'unknown'|'null') SSID='' ;;
  esac
  printf '%s' "$SSID"
}

detect_state() {
  CUR_TRANSPORT=unknown
  CUR_IFACE=''
  CUR_SSID="$(get_ssid)"

  # A real associated SSID is stronger evidence than the default route, which
  # may point at tun0 when AdGuard/other VPNs are active.
  if [ -n "$CUR_SSID" ]; then
    CUR_TRANSPORT=wifi
    CUR_IFACE="$(ip route 2>/dev/null | sed -n 's/.* dev \(wlan[0-9]*\).*/\1/p' | head -n 1)"
    [ -n "$CUR_IFACE" ] || CUR_IFACE=wlan
    return
  fi

  ROUTE="$(ip route get 1.1.1.1 2>/dev/null | head -n 1)"
  CUR_IFACE="$(printf '%s\n' "$ROUTE" | sed -n 's/.* dev \([^ ]*\).*/\1/p')"
  case "$CUR_IFACE" in
    rmnet*|v4-rmnet*|v6-rmnet*|ccmni*|pdp*|wwan*) CUR_TRANSPORT=cellular ;;
    wlan*|wifi*) CUR_TRANSPORT=wifi ;;
    tun*|tap*|wg*) CUR_TRANSPORT=cellular_vpn_or_unknown ;;
    '') CUR_TRANSPORT=unknown ;;
    *) CUR_TRANSPORT=unknown ;;
  esac
}

csv_escape() {
  printf '%s' "$1" | sed 's/"/""/g'
}

append_current() {
  TS="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  [ -f "$LOG" ] || printf 'timestamp,transport,iface,ssid\n' > "$LOG"
  SAFE_SSID="$(csv_escape "$CUR_SSID")"
  printf '%s,%s,%s,"%s"\n' "$TS" "$CUR_TRANSPORT" "$CUR_IFACE" "$SAFE_SSID" >> "$LOG"
  printf '%s  %s  iface=%s  ssid=%s\n' "$TS" "$CUR_TRANSPORT" "$CUR_IFACE" "$CUR_SSID"
}

run_loop() {
  LAST_TRANSPORT='__INIT__'
  LAST_IFACE='__INIT__'
  LAST_SSID='__INIT__'
  while :; do
    detect_state
    if [ "$CUR_TRANSPORT" != "$LAST_TRANSPORT" ] || [ "$CUR_IFACE" != "$LAST_IFACE" ] || [ "$CUR_SSID" != "$LAST_SSID" ]; then
      append_current
      LAST_TRANSPORT="$CUR_TRANSPORT"
      LAST_IFACE="$CUR_IFACE"
      LAST_SSID="$CUR_SSID"
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
    if is_running; then echo "running pid=$(cat "$PIDFILE")"; else echo "not running"; fi
    [ -f "$LOG" ] && tail -n 10 "$LOG"
    ;;
  once)
    detect_state
    append_current
    ;;
  _run)
    run_loop
    ;;
  *)
    echo "usage: sh $0 {start|stop|status|once}"
    ;;
esac
