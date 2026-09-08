# Canonical battery ledger (current)

This directory is the **single current working dataset** for iQOO 12 Pro battery tracking.

Everything under `generated/YYYY-MM-DD/` is immutable dated ingestion evidence. Everything under `canonical/` is the latest curated state used for ongoing comparisons.

## Current state

- finalized Scene History rows in `sessions.csv`: **50**
- duration-main-eligible rows: **47**
- History-prefilter provisional row: **1** (`2026-09-04 14:18`, displayed 0.3h = actual 18–<24m)
- evidence-only rows: **2** (`2026-09-03 23:54`, `2026-09-04 14:46`)
- preserved historical/intermediate rows in `session_ledger.csv`: **41**; do not rewrite the old source
- intentionally uncaptured older eligible History rows: **12**
- first canonical granular future-era app evidence now exists in `app_sessions.csv`: **38 rows across 3 reconciled sessions**
- one older known partial app-attribution session remains `2026-07-23 20:53` (56.9% duration coverage), but its granular rows were not retained
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`
- MacroDroid v2.5 natural-use raw batch received through `2026-09-08T11:03:47.107+08:00`; bulk canonical context promotion remains paused because screenshots exposed missed short Wi-Fi-on periods / transition-coverage gaps

Current 47-row main average-power descriptive baseline:

- mean: **2.63 W**
- median: **2.57 W**
- IQR: **2.095–3.075 W**
- observed range: **1.36–4.07 W**

Current 47-row main theoretical-runtime descriptive baseline uses exact detail values for old rows and displayed lower-bound values for new History-only rows:

- mean: **7.17 h**
- median: **6.90 h**

Do not present these overall figures as Wi-Fi/mobile statistics because network context remains unavailable or unreliable for many sessions.

## Current Scene semantic authority

See:

- `../docs/SCENE_CURRENT_APK_RE_2026-09-05.md`
- `../docs/SCREENSHOT_INGESTION_V1.md`

Current installed artifact:

```text
package: com.omarea.vtools
versionName: 9.3.8
APK SHA-256: 0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80
```

For this APK lineage:

- History timestamp = **session start (`beginTime`)**
- History first duration = **Scene-valid screen-on sampled duration**
- History second duration = **whole-session wall duration (`endTime - beginTime`)**
- History sampling interval = **3 seconds**
- both History `x.xh` duration fields are **downward truncated in 6-minute / 0.1h buckets**, not rounded
- session average power is over valid screen-on discharge/not-charging samples
- theoretical runtime is a separate workload-normalized estimate

The old public `battery-history3` / 6-second implementation is legacy lineage evidence only.

## Files

- `session_ledger.csv` — preserved historical/intermediate 41-session source; do not rewrite old evidence in place.
- `sessions.csv` — normalized canonical finalized-session table; now includes History-only duration bounds for newer rows.
- `app_summary.csv` — legacy derived accumulated app-duration / weighted-power summary; not a substitute for per-session rows.
- `app_sessions.csv` — genuine granular per-session app rows from reconciled future-era screenshots. Package name / Scene mode remain blank when not visible.
- `context_timeline.csv` — normalized MacroDroid pilot context timeline.
- `context_events.csv` — curated context-event model; **do not bulk-import the 2026-09-06..08 raw v2.5 batch until the transition-coverage gap is resolved**.
- `device_state_events.csv` — sparse device/configuration timeline.

Current dated evidence:

- `../generated/2026-09-08/provisional_live_sessions.csv`
- `../generated/2026-09-08/provisional_app_rows.csv`
- `../generated/2026-09-08/context_events_v2_uploaded_raw.csv`
- `../generated/2026-09-08/INGEST_NOTES.md`
- `../generated/2026-09-08/HISTORY_RECONCILIATION.md`

The earlier provisional files remain immutable snapshots of what was known at ingestion time. `HISTORY_RECONCILIATION.md` records the later History-based identity correction.

## Session rules

1. Live/current Scene screenshots remain provisional until matched to a finalized History session.
2. Scene History timestamp is the preferred stable identity and means **session start**.
3. Exact detail Scene screen-on duration controls eligibility when available: `<20m` evidence-only, `20–30m` provisional, `>=30m` main.
4. History prefilter: `0.0–0.2h` definitely below 20m; `0.3h` ambiguous 18–<24m; `0.4h` provisional; `>=0.5h` main-eligible.
5. Scene screen-on duration means Scene-valid screen-on sampled time; do not relabel it Android framework SOT.
6. History `x.xh` values are quantized evidence, not exact seconds. For displayed `D h`, actual duration is `>=D h` and `<D+0.1 h`.
7. If only a History row exists, represent derived interval end as bounds/UI precision rather than a falsely exact timestamp.
8. Older sessions whose captures did not preserve History wall duration keep wall duration/end time blank. Never substitute theoretical runtime.
9. Network/scene context is assigned only when context coverage is sufficient; otherwise use `unknown`.
10. Do not infer historical battery temperature/voltage/capacity from current ActivityPowerUtilization header state.
11. Deduplication uses timestamp + power + durations + date/curve/app evidence, never average watts alone.
12. Old raw/invalid evidence is never deleted merely because later evidence supersedes it.
13. A MacroDroid heartbeat/state is not sufficient when contemporaneous screenshot evidence shows the event timeline missed an active network period; conflicting intervals remain `unknown` until coverage is resolved.
14. Do not classify long sessions by wall-time dominance of `offline` versus Wi-Fi: Scene average power is computed only from valid screen-on samples, and current MacroDroid data does not expose screen-on-aligned transport state.

## 2026-09-08 History reconciliation

The new History screenshot added **9 finalized rows** beyond the existing overlap anchors. Six are main-eligible, one is provisional by History prefilter, and two are evidence-only.

It also resolves the three earlier live/detail screenshots:

- status-bar `08:03:16` -> History session **`2026-09-05 23:22`**; actual capture date inferred as `2026-09-06`; final History: 2.58 W, 0.9h / 20.7h, theoretical 6.8h
- status-bar `03:49:21` -> History session **`2026-09-06 20:30`**; actual capture date inferred as `2026-09-07`; final History: 3.14 W, 1.1h / 19.3h, theoretical 5.6h
- status-bar `11:25:01` -> History session **`2026-09-07 16:07`**; actual capture date `2026-09-08`; final History: 2.92 W, 1.2h / 19.3h, theoretical 6.0h

The match uses average power + History screen-on bucket + theoretical-runtime bucket + interval containment. Observation-time exact `h/m/s` values are not automatically promoted as exact final duration when the capture predates the final History endpoint.

The reconciled app rows are now canonical granular evidence in `app_sessions.csv`, with snapshot coverage of approximately **95.49%**, **95.14%**, and **97.03%** respectively.

## MacroDroid context warning

The date reconciliation confirms rather than removes the v2.5 coverage warning:

- `2026-09-06 08:03:16` visibly shows Wi-Fi while the event timeline carried/nearby reported `offline`.
- `2026-09-07 03:49:21` visibly shows Wi-Fi during a span where the timeline lacks the corresponding Wi-Fi-on transition.
- `2026-09-08 11:25:01` is consistent with `home_wifi / DaFengLi_5G` at the capture instant.

Therefore the raw context batch is retained as evidence but is not blindly promoted into session-wide network labels.

## Production source policy

A lawful `run-as` probe on the current installed package returned:

```text
STOP: run-as unavailable
```

Routine ingestion therefore uses the low-interference Scene History/detail screenshot contract in `SCREENSHOT_INGESTION_V1.md`.

Do not retry private-DB permission work, routine UIAutomator, OCR, force-stop/CLEAR_TASK capture loops, or background Runner processes for this ledger.
