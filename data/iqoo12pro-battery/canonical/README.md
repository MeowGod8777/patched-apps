# Canonical battery ledger (current)

This directory is the **single current working dataset** for iQOO 12 Pro battery tracking.

Everything under `generated/YYYY-MM-DD/` is an immutable dated ingestion snapshot. Everything under `canonical/` is the latest curated state used for ongoing comparisons.

## Current canonical state

- finalized Scene History sessions: **41**
- provisional live snapshot groups: kept outside the finalized ledger
- intentionally uncaptured old eligible History rows: **12**, documented in `generated/2026-09-05/accepted_missing_backlog.csv`
- one known partial app-attribution session: `2026-07-23 20:53`
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

## Current Scene semantic authority

Current installed Scene APK static RE is documented at:

`../docs/SCENE_CURRENT_APK_RE_2026-09-05.md`

Artifact SHA-256:

```text
0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80
```

For this APK lineage:

- History timestamp = **session start (`beginTime`)**
- History first duration = **Scene-valid screen-on sampled duration**
- current History sampling interval = **3 seconds**
- History second duration = **whole-session wall-clock span (`endTime - beginTime`)**
- History second duration is **not** theoretical runtime
- Scene session average power is calculated over valid screen-on discharge/not-charging samples
- theoretical runtime is a separate workload-normalized estimate

The old public-source `battery-history3` / 6-second implementation is legacy lineage evidence only.

## Files

- `session_ledger.csv` — preserved historical/intermediate 41-session source. Do not rewrite old evidence in place.
- `sessions.csv` — normalized canonical session schema once migration is materialized.
- `app_summary.csv` — derived accumulated app-duration / weighted-power summary; **not** a substitute for per-session app rows.
- `app_sessions.csv` — only genuine retained per-session app evidence may populate this file; never reverse aggregate `app_summary.csv`.
- `context_timeline.csv` — current normalized MacroDroid pilot network-context timeline.
- future `context_events.csv` — final append-only context event model.
- future `device_state_events.csv` — sparse device/configuration change timeline.

## Session rules

1. Do not insert live/current Scene screenshots directly into finalized canonical sessions. They remain provisional until matched to a finalized History session or explicitly retained as snapshot-only evidence.
2. Scene History timestamp is the preferred stable identity and its semantics are now **start time**.
3. Exact detail Scene screen-on duration controls eligibility: `<20m` excluded, `20–30m` provisional, `>=30m` main.
4. Scene screen-on duration means Scene-valid screen-on sampled time; do not relabel it Android framework SOT.
5. If History wall duration was captured, it may be used with the start timestamp to derive an end time. Mark UI-rounded interval precision when appropriate.
6. Older sessions whose captures did not preserve History wall duration must keep wall duration/end time blank. Never substitute theoretical runtime.
7. Network / scene context is assigned only when MacroDroid timeline coverage is sufficient; otherwise use `unknown`.
8. Do not infer historical battery temperature/voltage/capacity from the current ActivityPowerUtilization header.
9. Deduplication uses timestamp + power + durations + date/curve/app evidence, never average watts alone.
10. Old raw/invalid evidence is never deleted merely because later evidence supersedes it.

## Production source policy

The current installed package does not permit the lawful `run-as` private-DB route (`STOP: run-as unavailable`). Routine ingestion therefore uses a deliberately low-interference Scene History/detail screenshot workflow.

Do not retry private-DB permission work, routine UIAutomator, OCR, force-stop/CLEAR_TASK capture loops, or background Runner processes for this ledger.
