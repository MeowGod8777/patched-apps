# iQOO 12 Pro Scene battery ingestion report — 2026-09-05

## Ingestion result

- Source archive SHA256: `cd129dea836c8c646e233d2ea42cdb870ae5272bf7eb8faeae06c266f7fb66a9`
- Manifest rows: **73**; unique latest session keys: **42**.
- Latest valid Scene History detail captures: **41**.
- Canonical session ledger rows after baseline merge: **42** (includes unmatched baseline-only snapshots).
- Exact eligibility: **41/41** automated captures are `>=30 min`; no automated captured row falls into provisional/excluded buckets.
- Captured History range: **2026-07-18 12:36 → 2026-09-04 13:23**. Older History backlog was intentionally left uncollected after the user stopped acquisition.

## Quality controls

- `sync_manifest.csv` is interpreted append-only; the latest state for each session is authoritative.
- Old `all Scene` / unresolved attribution evidence is preserved but excluded from canonical rows whenever a later healthy `captured` state exists.
- Preserved incomplete `.partial` files: **3**; preserved `sync_raw_invalid` diagnostics: **6**.
- Overlapping detail-page rows are deduplicated by exact app identity + duration + power + temperature tuple; raw files remain untouched.
- App-duration coverage warning: `2026-07-23 20:53`=56.9%. Session-level power/runtime remain usable; only app attribution is flagged partial.

## Network / scene attribution

- MacroDroid timeline contains **4** valid epoch transitions; first valid transition is **2026-09-05T12:40:43+08:00**.
- All finalized automated Scene sessions in this archive predate that coverage window, so transport is **not inferred** from MacroDroid for those rows.
- Confirmed `baseline.csv` context is used only to enrich matching historical rows. This yields three confirmed `home_wifi` automated sessions (2026-08-31 16:30, 2026-08-31 23:08, 2026-09-02 07:28) plus the baseline-only 2026-09-05 `out_4g + navigation` sample.

## Descriptive summary (automated 41-session set)

- Average power: mean **2.64 W**, median **2.56 W**, IQR **2.12–3.09 W**.
- Scene theoretical runtime: mean **7.18 h**, median **6.92 h**.
- These are cross-scene natural-use distributions, **not** a single Wi-Fi or 4G endurance figure.

Top apps by accumulated Scene `itemCounts` duration in the automated set:

- ChatGPT: **20.23 h** across 31 sessions, duration-weighted avg **1.93 W**.
- 系統桌面: **7.89 h** across 39 sessions, duration-weighted avg **3.23 W**.
- LINE: **6.16 h** across 36 sessions, duration-weighted avg **2.97 W**.
- Threads: **4.34 h** across 24 sessions, duration-weighted avg **2.93 W**.
- 酷安: **3.51 h** across 19 sessions, duration-weighted avg **2.70 W**.
- 三星瀏覽器: **3.50 h** across 25 sessions, duration-weighted avg **2.20 W**.
- 拼多多: **1.70 h** across 19 sessions, duration-weighted avg **3.04 W**.
- 地圖: **1.45 h** across 9 sessions, duration-weighted avg **3.74 W**.
- Instagram: **0.85 h** across 7 sessions, duration-weighted avg **2.93 W**.
- 設定: **0.80 h** across 14 sessions, duration-weighted avg **2.80 W**.

## Repository outputs

- `session_ledger.csv` — canonical session-level ledger.
- `app_summary.csv` — accumulated app-duration / duration-weighted power summary.
- `network_timeline_normalized.csv` — parsed MacroDroid transitions with placeholder lines explicitly invalidated.

The full per-session app ledger and detailed capture-quality audit are kept in the downloadable ingestion artifact generated from the uploaded archive.
