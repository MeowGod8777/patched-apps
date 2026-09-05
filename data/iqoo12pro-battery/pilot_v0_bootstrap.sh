#!/system/bin/sh
BASE=/sdcard/SceneBattery
RAW=https://raw.githubusercontent.com/MeowGod8777/patched-apps/main/data/iqoo12pro-battery
mkdir -p "$BASE"

echo '[1/3] downloading v0 scripts...'
curl -fsSL "$RAW/network_watch_v0.sh" -o "$BASE/network_watch_v0.sh" || exit 1
curl -fsSL "$RAW/history_capture_v0.sh" -o "$BASE/history_capture_v0.sh" || exit 1
chmod 700 "$BASE/network_watch_v0.sh" "$BASE/history_capture_v0.sh" 2>/dev/null

echo '[2/3] starting network watcher...'
sh "$BASE/network_watch_v0.sh" start

echo '[3/3] current status...'
sh "$BASE/network_watch_v0.sh" status

echo
echo 'READY'
echo 'Network context will be logged on changes.'
echo 'When you want to sync Scene history, run:'
echo 'sh /sdcard/SceneBattery/history_capture_v0.sh'
