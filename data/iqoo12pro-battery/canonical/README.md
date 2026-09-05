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
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

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
- `sessions.csv` — normalized canonical session table.
- `app_summary.csv` — derived accumulated app-duration / weighted-power summary; not a substitute for per-session rows.
- `context_timeline.csv` — current normalized MacroDroid pilot context timeline.

Planned/future granular files:

- `app_sessions.csv` — populate only from genuine per-session app evidence.
- `context_events.csv` — final append-only context-event model.
- `device_state_events.csv` — sparse device/configuration timeline.

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

## Production source policy

A lawful `run-as` probe on the current installed package returned:

```text
STOP: run-as unavailable
```

Routine ingestion therefore uses the low-interference Scene History/detail screenshot contract in `SCREENSHOT_INGESTION_V1.md`.

Do not retry private-DB permission work, routine UIAutomator, OCR, force-stop/CLEAR_TASK capture loops, or background Runner processes for this ledger.
