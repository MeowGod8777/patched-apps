# 2026-09-05 ingestion corrections v2

This file supersedes the v1 interpretation where the 2026-09-05 live snapshot was counted as a canonical finalized session.

## Authoritative counts

- latest valid Scene History detail captures: **41**
- finalized canonical Scene History sessions: **41**
- finalized deduplicated app rows: **436**
- intentionally uncaptured eligible old History rows: **12**
- provisional live snapshot groups: **1** (`2026-09-05-live-01`)

## Corrections

1. The `baseline:2026-09-05` row in the original `session_ledger.csv` is **not finalized**. It was an intermediate snapshot of the same ongoing session later observed at 3.23 W / 1h43m / 5h29m and 3.01 W / 2h07m / 5h52m. Treat that row as `provisional_live_snapshot`; see `live_snapshots.csv`.
2. Historical `battery_capacity`, `battery_temperature`, `battery_voltage`, and `battery_status` values exposed on `ActivityPowerUtilization` must not be interpreted as old-session metadata. Scene binds those fields from current `GlobalStatus` when the page is rendered. In particular, the 26.5°C / 3.714 V values visible while capturing `2026-07-23 20:53` describe the 2026-09-05 capture moment, not the July session.
3. `2026-07-23 20:53` retains valid session power/runtime but its app-duration coverage is only 56.9%, so app attribution is partial.
4. MacroDroid's first valid epoch transition is `2026-09-05T12:40:43+08:00`; no historical finalized session in this archive gets network context inferred from missing timeline coverage.

## Finalized distribution (41 sessions)

- mean average power: **2.64 W**
- median average power: **2.56 W**
- power IQR: **2.12–3.09 W**
- mean theoretical runtime: **7.18 h**
- median theoretical runtime: **6.92 h**

These are cross-scene natural-use statistics, not a single Wi-Fi/4G endurance figure.

## Forward capture

`capture_recent_v2.sh` is superseded by `capture_recent_v3.sh`. v3 deliberately does not scroll to the top merely to collect battery header fields, because those are current-page state rather than historical-session state. Routine capture should remain shallow and forward-only.
