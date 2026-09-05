# iQOO 12 Pro battery ledger — architecture v1 FINAL

Status: **design frozen for the next implementation phase**

This document defines the product goal, data model, source hierarchy, collection policy, and next-step priorities. It supersedes the earlier UIAutomator-first / screenshot-first drafts as the architectural source of truth.

## 1. Product goal

Build a **low-interference, long-term natural-usage battery ledger** for the user's iQOO 12 Pro / V2329A.

The ledger must eventually support questions such as:

- What is the phone's normal natural-use endurance distribution now?
- How do home Wi-Fi, cellular/out-of-home use, mixed use, and navigation differ?
- Which app/workload patterns explain high or low power sessions?
- Is endurance changing over time as the battery ages?
- Did an OriginOS build, resolution/refresh change, scheduling/root modification, or other device-state change materially affect endurance?

This is **not** a fixed-workload laboratory benchmark. A session does not need to be 100% -> 0%.

## 2. Non-goals

- Do not optimize for collecting the maximum number of Scene rows.
- Do not require daily Runner commands or brittle UI automation.
- Do not treat Scene theoretical runtime as pure SOT.
- Do not infer context or historical battery header values when evidence is missing.
- Do not let automation cost exceed the manual action it is replacing.

## 3. Measurement semantics

Scene remains the primary power/workload source.

Canonical session metrics:

- Scene History timestamp / stable session identity
- average power
- exact detail `screen_on_duration`
- theoretical runtime
- History wall-duration / elapsed-span value when available
- per-session app attribution

Rules:

- `<20 min` exact `screen_on_duration`: retain evidence, exclude from primary ledger
- `20–30 min`: provisional
- `>=30 min`: main ledger
- do not deduplicate on average watts alone
- repeated current/live screenshots are provisional observations of one session until reconciled with a stable History identity

Important correction: Scene `ActivityPowerUtilization` battery capacity/status/voltage/temperature header values are **current-page GlobalStatus**, not historical-session metadata. They must not be attached to an old History row.

## 4. Source hierarchy

### 4.1 Scene — battery/workload source

Preferred order:

1. **Direct Scene private-history database export/query**, if the installed build can be accessed lawfully from shell (`run-as`/debuggable or another verified read-only route).
2. Scene History/detail screenshots as the production fallback.
3. UIAutomator capture scripts only for exceptional forensic/backlog recovery.

Known source-tree fact: the referenced Scene source stores samples in private SQLite database `battery-history3` with fields including time, temperature, status, mode, io, package, screen_on, and capacity.

Direct DB access is not assumed available until verified on the installed APK.

### 4.2 MacroDroid — environmental context source

MacroDroid does not capture Scene metrics. Its role is to continuously record low-cost context events.

Target network states:

- `home_wifi`
- `mobile`
- `other_wifi`
- `unknown`

Target additional events:

- context coverage / heartbeat
- navigation `on/off` after a reliable signal is designed and validated

The existing two-state `home_wifi` / `out_4g` macros are useful pilot evidence but are **not the final context model**, because leaving home Wi-Fi is not equivalent to being on mobile data.

### 4.3 Device-state timeline — configuration source

Long-term comparisons require a sparse event log of device/configuration changes.

Examples:

- OriginOS exact build
- resolution
- refresh rate
- battery health / cycle snapshot
- root state
- scheduler / governor / performance profile
- major power-related system setting change

Only changes need new rows. Sessions inherit the effective device state for their date/time during analysis.

## 5. Canonical data model

Target directory:

```text
data/iqoo12pro-battery/
├─ canonical/
│  ├─ sessions.csv
│  ├─ app_sessions.csv
│  ├─ context_events.csv
│  ├─ device_state_events.csv
│  └─ README.md
├─ generated/YYYY-MM-DD/
│  └─ immutable ingestion snapshots / reports / provisional observations
├─ docs/
│  └─ architecture / schema / handoff documentation
└─ legacy/
   └─ old UIAutomator / backlog tooling when migration is performed
```

### 5.1 `sessions.csv`

One finalized Scene History session per row.

Required/target fields:

- `session_id`
- `history_session_at`
- `history_time_semantics` (`unknown` until verified, then e.g. start/end)
- `wall_duration_seconds` (nullable)
- `interval_start` (nullable until semantics verified)
- `interval_end` (nullable until semantics verified)
- `avg_power_w`
- `screen_on_duration_seconds`
- `theoretical_runtime_seconds`
- `eligibility`
- `app_attribution_quality`
- `context_quality`
- `source_type`
- `source_ref`
- `notes`

Do not derive a wall-clock interval from History timestamp + duration until the timestamp and second History duration semantics are verified.

### 5.2 `app_sessions.csv`

Per-session app evidence. This is canonical; aggregate app summaries are derived.

Target fields:

- `session_id`
- `package_name` (when available)
- `app_label`
- `duration_seconds`
- `avg_power_w`
- `avg_temp_c` (only if Scene's app row genuinely represents that session)
- `max_temp_c`
- `source_ref`

### 5.3 `context_events.csv`

Append-only environmental event stream.

Target fields:

- `event_at`
- `event_type` (`network_state`, `navigation_state`, `coverage_heartbeat`, etc.)
- `state`
- `source`
- `detail`
- `valid`

Session scene classification is derived from overlap with this timeline; it is not manually guessed.

### 5.4 `device_state_events.csv`

Sparse configuration-change event stream.

Target fields:

- `effective_at`
- `key`
- `value`
- `source`
- `notes`

## 6. Derived outputs

The following are derived and must not replace canonical granular evidence:

- app aggregate summary
- home-Wi-Fi vs mobile statistics
- navigation vs non-navigation statistics
- build/config comparison summaries
- long-term rolling power/endurance trend
- dashboard/XLSX outputs

## 7. Session-context classification

Final classification depends on a verified session wall-clock interval.

Desired scene labels:

- `home_wifi`
- `out_mobile`
- `mixed`
- `other_wifi`
- `unknown`

`navigation` remains an independent modifier.

If context timeline coverage is incomplete, classify as `unknown` or partial coverage. Never infer a scene simply from average watts or app names.

## 8. Production collection policy

The production workflow is not finalized until the direct-DB feasibility test is complete.

Decision tree:

### Route A — direct DB access succeeds

Use a small read-only export/query path to capture new finalized Scene data with minimal user interaction. Pair it with MacroDroid context events and sparse device-state events. This becomes the preferred production route.

### Route B — direct DB access fails

Use a deliberately low-effort screenshot workflow:

- periodic recent History screenshot(s), not cherry-picked only when power looks interesting
- detail screenshot only when needed for exact metrics/app attribution
- MacroDroid context file uploaded periodically
- no routine UIAutomator/Runner retries

This avoids selection bias and keeps user effort lower than the failed automation path.

## 9. Existing evidence status (2026-09-05)

Accepted historical foundation:

- 41 finalized Scene History detail sessions
- all 41 have exact `screen_on_duration >=30 min`
- 12 older eligible History rows intentionally left uncaptured
- one known partial app-attribution session: `2026-07-23 20:53` (56.9% duration coverage)
- one provisional 2026-09-05 live session group, not a finalized canonical session
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

The 41-session set is useful as a cross-scene historical baseline, but most rows lack reliable network context and must not be presented as home-Wi-Fi/mobile comparisons.

## 10. Legacy tooling policy

All `capture_*`, `full_sync_*`, probe and backlog scripts created for the old recovery effort are **legacy forensic tooling**.

- Do not use them for routine logging.
- Do not delete them until migration/audit is complete.
- Future repository cleanup may move them under `legacy/` without changing their historical meaning.

## 11. Next implementation order

The next conversation should proceed in this order and should not skip ahead:

1. verify exact installed Scene package/build properties relevant to direct DB access;
2. test read-only `run-as com.omarea.vtools` / debuggable feasibility;
3. if accessible, locate/inspect `battery-history3` and verify schema/semantics without modifying it;
4. verify Scene History timestamp semantics and the second History duration value;
5. migrate current canonical data into final `sessions.csv` + `app_sessions.csv` schema;
6. redesign MacroDroid context events into `home_wifi/mobile/other_wifi/unknown` + coverage signal;
7. add initial `device_state_events.csv` baseline;
8. only then consider navigation automation;
9. if DB access fails, finalize the low-effort screenshot fallback.

No new UIAutomator capture version should be developed unless a specific historical-recovery need justifies it.
