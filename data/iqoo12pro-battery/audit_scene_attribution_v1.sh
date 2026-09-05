#!/system/bin/sh
# Audit Scene battery raw captures for broken app attribution.
# Raw files are immutable. Manifest is append-only: bad captures are invalidated
# by appending a newer state row instead of deleting or rewriting old entries.

BASE=/sdcard/SceneBattery
MANIFEST="$BASE/sync_manifest.csv"
TMP="$BASE/audit_tmp/scene-attribution-$(date '+%Y%m%d-%H%M%S')-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP" 2>/dev/null' EXIT HUP INT TERM

[ -f "$MANIFEST" ] || { echo "ERROR manifest_missing=$MANIFEST"; exit 2; }

latest_rows() {
  awk -F',' '
    NR>1 {
      t=$1; s=$2; f=$3;
      gsub(/^"|"$/, "", t);
      gsub(/^"|"$/, "", s);
      gsub(/^"|"$/, "", f);
      state[t]=s; file[t]=f;
    }
    END {
      for (t in state) printf "%s\t%s\t%s\n", t, state[t], file[t];
    }
  ' "$MANIFEST" | sort -r
}

check_health() {
  AH_FILE="$1"
  AH_TITLES="$TMP/titles.txt"
  : > "$AH_TITLES"
  grep 'resource-id="com.omarea.vtools:id/itemTitle"' "$AH_FILE" 2>/dev/null \
    | sed -n 's/.*text="\([^"]*\)".*/\1/p' \
    | sed '/^$/d' > "$AH_TITLES"

  AH_COUNT="$(wc -l < "$AH_TITLES" | tr -d ' ')"
  [ -n "$AH_COUNT" ] || AH_COUNT=0
  [ "$AH_COUNT" -gt 0 ] || return 70

  AH_NONSCENE="$(grep -vc '^Scene$' "$AH_TITLES" 2>/dev/null || true)"
  [ -n "$AH_NONSCENE" ] || AH_NONSCENE=0
  if [ "$AH_COUNT" -ge 2 ] && [ "$AH_NONSCENE" -eq 0 ]; then
    return 71
  fi
  return 0
}

TAB="$(printf '\t')"
AUDITED=0
INVALIDATED=0
VALID=0

latest_rows | while IFS="$TAB" read -r TITLE STATE FILE; do
  [ "$STATE" = captured ] || continue
  AUDITED=$((AUDITED+1))

  if [ ! -f "$FILE" ]; then
    printf '"%s",invalid_missing_raw,"%s",%s\n' "$TITLE" "$FILE" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
    echo "INVALID session=$TITLE reason=missing_raw file=$FILE"
    INVALIDATED=$((INVALIDATED+1))
    continue
  fi

  check_health "$FILE"
  RC=$?
  case "$RC" in
    0)
      echo "VALID session=$TITLE file=$FILE"
      VALID=$((VALID+1))
      ;;
    70)
      printf '"%s",invalid_scene_attribution_missing,"%s",%s\n' "$TITLE" "$FILE" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
      echo "INVALID session=$TITLE reason=no_item_titles file=$FILE"
      INVALIDATED=$((INVALIDATED+1))
      ;;
    71)
      printf '"%s",invalid_scene_attribution_collapsed,"%s",%s\n' "$TITLE" "$FILE" "$(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$MANIFEST"
      echo "INVALID session=$TITLE reason=all_titles_scene file=$FILE"
      INVALIDATED=$((INVALIDATED+1))
      ;;
    *)
      echo "ERROR health_check rc=$RC session=$TITLE file=$FILE"
      exit "$RC"
      ;;
  esac
done

# Recompute current states after append-only invalidations.
echo '===== CURRENT VALID CAPTURED ====='
awk -F',' '
  NR>1 {
    t=$1; s=$2;
    gsub(/^"|"$/, "", t);
    gsub(/^"|"$/, "", s);
    state[t]=s;
  }
  END {
    n=0;
    for (t in state) if (state[t]=="captured") { print t; n++ }
    print "count=" n > "/dev/stderr"
  }
' "$MANIFEST" | sort -r

echo 'AUDIT DONE'
exit 0
