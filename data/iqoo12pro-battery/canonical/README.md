# Canonical battery ledger (current)

This directory is the **single current working dataset** for iQOO 12 Pro battery tracking.

Everything under `generated/YYYY-MM-DD/` is an immutable dated ingestion snapshot. Everything under `canonical/` is the latest curated state used for ongoing comparisons.

## Current state

- finalized Scene History sessions: **41**
- normalized canonical rows in `sessions.csv`: **41**
- preserved historical/intermediate rows in `session_ledger.csv`: **41**
- intentionally uncaptured old eligible History rows: **12**
- one known partial app-attribution session: `2026-07-23 20:53`
- provisional live groups remain outside finalized sessions
- new provisional live captures on `2026-09-08`: **3** (`03:49:21`, `08:03:16`, `11:25:01`), all duration-main-eligible but awaiting History identity/reconciliation
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`
- MacroDroid v2.5 natural-use batch received through `2026-09-08T11:03:47.107+08:00`, but bulk canonical promotion is paused because screenshots revealed missed short Wi-Fi-on periods / transition-coverage gaps

The `sessions.csv` migration is additive and lossless: `session_ledger.csv` was not rewritten.

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
- `sessions.csv` — normalized canonical finalized-session table.
- `app_summary.csv` — derived accumulated app-duration / weighted-power summary; not a substitute for per-session rows.
- `context_timeline.csv` — normalized MacroDroid pilot context timeline.
- `context_events.csv` — curated append-only context-event model; **do not bulk-import the 2026-09-06..08 raw v2.5 batch until the transition-coverage gap is resolved**.
- `device_state_events.csv` — sparse device/configuration timeline.

Current dated provisional evidence:

- `../generated/2026-09-08/provisional_live_sessions.csv`
- `../generated/2026-09-08/provisional_app_rows.csv`
- `../generated/2026-09-08/context_events_v2_uploaded_raw.csv`
- `../generated/2026-09-08/INGEST_NOTES.md`

Future granular canonical file:

- `app_sessions.csv` — populate only from genuine per-session app evidence **after the provisional capture is reconciled to a finalized History session identity**.

The prior 436 deduped per-app rows were not retained as a granular repo artifact, and referenced `sync_raw/detail-*` files are absent from the repository tree. Do not reconstruct historical `app_sessions.csv` from aggregate `app_summary.csv`.

## Session rules

1. Live/current Scene screenshots remain provisional until matched to a finalized History session.
2. Scene History timestamp is the preferred stable identity and means **session start**.
3. Exact detail Scene screen-on duration controls eligibility: `<20m` excluded, `20–30m` provisional, `>=30m` main.
4. Scene screen-on duration means Scene-valid screen-on sampled time; do not relabel it Android framework SOT.
5. History `x.xh` values are quantized evidence, not exact seconds. For displayed `D h`, actual duration is `>=D h` and `<D+0.1 h`.
6. If only a History row exists, represent derived interval end as bounds/UI precision rather than a falsely exact timestamp.
7. Older sessions whose captures did not preserve History wall duration keep wall duration/end time blank. Never substitute theoretical runtime.
8. Network/scene context is assigned only when context coverage is sufficient; otherwise use `unknown`.
9. Do not infer historical battery temperature/voltage/capacity from current ActivityPowerUtilization header state.
10. Deduplication uses timestamp + power + durations + date/curve/app evidence, never average watts alone.
11. Old raw/invalid evidence is never deleted merely because later evidence supersedes it.
12. A MacroDroid heartbeat/state is not sufficient when contemporaneous screenshot evidence shows the event timeline missed an active network period; conflicting intervals remain `unknown` until coverage is resolved.

## 2026-09-08 provisional ingest

Three distinct live Scene captures were preserved outside `sessions.csv`:

- `03:49:21` — 3.13 W, 1h09m Scene-valid screen-on, 5h39m theoretical runtime, 40% remaining, app attribution 95.14%
- `08:03:16` — 2.59 W, 55m02s, 6h50m, 53% remaining, app attribution 95.49%
- `11:25:01` — 2.92 W, 1h13m, 6h03m, 22% remaining, app attribution 97.03%

They are treated as three distinct provisional sessions. `03:49 -> 08:03` is separated by an increase in battery remaining (40% -> 53%), and `08:03 -> 11:25` has non-cumulative app attribution despite ~95–97% coverage, which is inconsistent with one accumulating Scene session.

The first two screenshots also expose MacroDroid context coverage gaps: Wi-Fi is visibly present during active use while the v2.5 event timeline lacks the corresponding Wi-Fi transition and carries `offline` observations around those periods. Therefore no session-wide network label is assigned from the raw batch yet.

## Production source policy

A lawful `run-as` probe on the current installed package returned:

```text
STOP: run-as unavailable
```

Routine ingestion therefore uses the low-interference Scene History/detail screenshot contract in `SCREENSHOT_INGESTION_V1.md`.

Do not retry private-DB permission work, routine UIAutomator, OCR, force-stop/CLEAR_TASK capture loops, or background Runner processes for this ledger.
