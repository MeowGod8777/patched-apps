# iQOO 12 Pro Battery Ledger

Long-term natural-usage battery ledger for iQOO 12 Pro / V2329A using Scene (`com.omarea.vtools`) battery statistics.

## START HERE

Architecture is now frozen as **v1 FINAL**. The production collection route is intentionally **not** declared screenshot-first or UIAutomator-first until direct Scene DB access is tested on the installed APK.

Read in this order:

1. `docs/ARCHITECTURE_V1_FINAL.md` — architectural source of truth.
2. `docs/HANDOFF_2026-09-05.md` — exact continuation point for the next conversation.
3. `canonical/` — current curated dataset.
4. `generated/YYYY-MM-DD/` — immutable dated ingestion/audit snapshots.

Old `capture_*`, `full_sync_*`, probe/audit scripts at this directory level are legacy forensic/backlog tooling only. Do not use them for routine logging.

## Product goal

Build a low-interference, long-term natural-usage battery ledger that can support reliable comparison of:

- home Wi-Fi vs out-of-home mobile use
- mixed sessions
- navigation vs non-navigation
- app/workload composition
- battery aging
- OriginOS / resolution / refresh / root / scheduler / other configuration changes

This is not a fixed-workload laboratory benchmark.

## Measurement model

- Scene `理论续航` / theoretical runtime is a workload-normalized endurance indicator, not pure screen-on time.
- Scene `已使用` is not assumed to equal pure SOT.
- A discharge session does not need to start at 100% or end at 0%.
- Scene History timestamp is the preferred session identity.
- Network/context changes are analysis events/segments inside a Scene session, not independent battery sessions.
- Live/current screenshots remain provisional until reconciled to a finalized History session or explicitly retained as snapshot-only evidence.

Important correction: Scene `ActivityPowerUtilization` battery capacity/status/voltage/temperature header values are current-page `GlobalStatus` values. They must not be attached to an old History session.

## Eligibility rule

Canonical eligibility is based on exact Scene detail `screen_on_duration`, not rounded History summary text:

- `<20 min`: retain evidence, exclude from primary ledger
- `20–30 min`: provisional / reviewable
- `>=30 min`: main ledger

Do not deduplicate on average watts alone.

## Current audited state — 2026-09-05

- finalized Scene History detail sessions: **41**
- intentionally uncaptured old eligible History rows: **12**
- provisional live snapshot group: **1** (`2026-09-05-live-01`), not finalized
- one known partial app-attribution finalized session: `2026-07-23 20:53` (56.9% app-duration coverage)
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

The 41-session set is a useful cross-scene historical baseline but most rows lack reliable network context; it must not be presented as a Wi-Fi/mobile comparison.

## Current organized data

`canonical/` is the current curated working state:

- `session_ledger.csv` — 41 finalized session rows
- `app_summary.csv` — derived aggregate app summary
- `context_timeline.csv` — current normalized MacroDroid pilot timeline

This is an intermediate organized state. Final v1 target schema is defined in `docs/ARCHITECTURE_V1_FINAL.md` and will migrate to granular canonical files:

```text
canonical/
├─ sessions.csv
├─ app_sessions.csv
├─ context_events.csv
├─ device_state_events.csv
└─ README.md
```

## Collection architecture

### Scene

Primary battery/workload source.

Preferred production order:

1. direct read-only Scene private-history DB export/query if the installed APK permits it;
2. low-effort periodic screenshots if direct DB access fails;
3. UIAutomator only for exceptional historical recovery.

Referenced Scene source contains private SQLite DB `battery-history3`; availability on the installed APK is not yet verified.

### MacroDroid

Environmental context only; it does not capture Scene battery metrics.

Current pilot records home Wi-Fi / leave-home transitions to:

`/sdcard/SceneBattery/network_timeline_md.csv`

The pilot `out_4g` model is not final because leaving home Wi-Fi is not equivalent to confirmed mobile data. Final target network states are `home_wifi`, `mobile`, `other_wifi`, and `unknown`, plus a coverage/heartbeat signal.

Navigation automation is deferred until the base context model is stable.

### Device-state timeline

A sparse device/config event log is required for meaningful long-term comparison. It should cover at least exact OriginOS build, resolution, refresh rate, battery-health/cycle snapshots, root state, and scheduler/performance profile changes.

## Key unresolved semantic issue

To intersect Scene sessions with MacroDroid context, the true wall-clock session interval must be known.

Scene History shows two duration-like values (for example `1.4h / 2.5h`). Exact detail supplies `screen_on_duration`, but the second History value and History timestamp start/end semantics have not yet been formally verified.

Do not derive interval start/end until that is verified from source, DB, or controlled observation.

## Next implementation step

Do not rewrite MacroDroid or Scene capture scripts first.

The next conversation begins with one minimal read-only feasibility test on the installed Scene APK:

1. inspect package/debuggable state;
2. test `run-as com.omarea.vtools`;
3. if allowed, locate/read only `battery-history3` and inspect schema/content;
4. if denied, stop the DB path and design the screenshot fallback without further UIAutomator development.

See `docs/HANDOFF_2026-09-05.md` for the exact continuation prompt.

## Legacy automation

The deep backlog was a one-time recovery exercise. Scene repeatedly became unstable under UIAutomator, including attribution collapse and broader backend/UI-state failures. The old scripts remain preserved as forensic tooling but are not part of the production workflow.
