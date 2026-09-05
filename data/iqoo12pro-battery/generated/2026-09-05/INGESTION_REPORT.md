# iQOO 12 Pro Scene battery ingestion report — 2026-09-05 (audit v2)

## Ingestion result

- Source archive SHA256: `cd129dea836c8c646e233d2ea42cdb870ae5272bf7eb8faeae06c266f7fb66a9`
- Manifest rows: **73**; unique latest session keys: **42** (41 dated captures + one failed live time-only key).
- Latest valid Scene History detail captures: **41**.
- Finalized canonical session ledger rows: **41**.
- Exact eligibility: **41/41** captured detail sessions have `screen_on_duration >= 30 min` and are `main`.
- Captured finalized range: **2026-07-18 12:36 → 2026-09-04 13:23**.
- Intentionally uncaptured eligible old History rows: **12**; see `accepted_missing_backlog.csv`.

## Corrections from the first ingestion

- The 2026-09-05 3.38 W / 1h24m / 5h14m record was an **ongoing live snapshot**, not a finalized History session. It is removed from `session_ledger.csv` and kept with later observations in `live_snapshots.csv`.
- Scene `ActivityPowerUtilization` displays battery capacity/status/voltage/temperature from **current `GlobalStatus` when the page is rendered**. These UI header fields must not be assigned to an older History session. In particular, the 26.5°C / 3.714 V visible while capturing `2026-07-23 20:53` were capture-time values on 2026-09-05, not July historical values.
- `capture_recent_v2.sh` is superseded by `capture_recent_v3.sh`; routine capture no longer scrolls to the top just to collect those non-historical header fields.

## Quality controls

- `sync_manifest.csv` is append-only; latest state per History timestamp is authoritative.
- Old all-`Scene`, unresolved and interrupted evidence remains immutable but is excluded when superseded by a later healthy capture.
- Preserved incomplete `.partial` files: **3**.
- Preserved `sync_raw_invalid` diagnostics: **6**.
- Finalized app ledger after overlap deduplication: **436 rows**.
- `2026-07-23 20:53` app-duration coverage is only **56.9%**. Its session-level power/runtime remain valid; only app attribution is partial.

## Network / scene attribution

- MacroDroid timeline has **4** valid epoch transitions. First valid transition: **2026-09-05T12:40:43+08:00**.
- All 41 finalized History sessions in this archive predate that coverage window, so network transport is not inferred from MacroDroid for them.
- Independently confirmed baseline context enriches only matching historical rows, including `2026-08-31 16:30`, `2026-08-31 23:08`, and `2026-09-02 07:28` as `home_wifi`.

## Descriptive summary — finalized 41-session set

- Average power: mean **2.64 W**, median **2.56 W**, IQR **2.12–3.09 W**.
- Scene theoretical runtime: mean **7.18 h**, median **6.92 h**.
- These are cross-scene natural-use distributions, not a single Wi-Fi or 4G endurance figure.

Top apps by accumulated Scene `itemCounts` duration in the finalized automated set:

- ChatGPT: **20.23 h** across 31 sessions, duration-weighted avg **1.93 W**.
- 系統桌面: **7.89 h** across 39 sessions, duration-weighted avg **3.23 W**.
- LINE: **6.16 h** across 36 sessions, duration-weighted avg **2.97 W**.
- Threads: **4.34 h** across 24 sessions, duration-weighted avg **2.93 W**.
- 酷安: **3.51 h** across 19 sessions, duration-weighted avg **2.70 W**.

## Repository outputs

- `session_ledger.csv` — 41 finalized Scene History sessions only.
- `app_summary.csv` — finalized automated app-duration / duration-weighted power summary.
- `network_timeline_normalized.csv` — normalized MacroDroid timeline.
- `live_snapshots.csv` — provisional observations of the ongoing 2026-09-05 session.
- `accepted_missing_backlog.csv` — 12 intentionally uncollected eligible old History rows.
- `CORRECTIONS_V2.md` — audit corrections and finalization semantics.
