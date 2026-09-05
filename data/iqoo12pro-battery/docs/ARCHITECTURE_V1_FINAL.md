# iQOO 12 Pro battery ledger — architecture v1 FINAL

Status: **production route and Scene semantics resolved on 2026-09-05**

This document defines the product goal, data model, source hierarchy, collection policy, and implementation priorities for the iQOO 12 Pro natural-use battery ledger. It supersedes earlier UIAutomator-first / screenshot-first drafts where they conflict.

Current Scene implementation semantics are grounded in static RE of the APK copied directly from the user's installed `com.omarea.vtools` on 2026-09-05. See `SCENE_CURRENT_APK_RE_2026-09-05.md`.

## 1. Product goal

Build a **low-interference, long-term natural-usage battery ledger** for the user's iQOO 12 Pro / V2329A.

The ledger should support:

- normal natural-use endurance distribution over time
- home Wi-Fi / mobile / mixed / other-Wi-Fi comparisons when context evidence exists
- navigation vs non-navigation comparisons
- app/workload explanations for high- and low-power sessions
- battery-aging trends
- OriginOS / resolution / refresh / root / scheduler / other device-state comparisons

This is **not** a fixed-workload laboratory benchmark. Sessions do not need to be 100% -> 0%.

## 2. Non-goals

- do not maximize row count at the cost of user effort or selection bias
- do not require daily Runner commands
- do not develop another routine UIAutomator capture version
- do not use OCR for Scene UI
- do not treat Scene theoretical runtime as pure SOT or whole-session wall endurance
- do not infer environmental context when evidence is missing
- do not attach current-page battery header values to old History sessions
- do not bypass Android private-data permissions to obtain Scene's database

## 3. Current Scene implementation semantics

Authoritative current-artifact identity:

```text
package: com.omarea.vtools
SHA-256: 0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80
```

### 3.1 Current private storage model

Current APK uses private SQLite database `power8`, table `records`:

```sql
create table records(
    time text primary key,
    session int,
    temperature REAL default(-1),
    status int default(-1),
    mode text,
    current int default(-1),
    voltage int,
    package text,
    screen_on INTEGER,
    capacity INTEGER
)
```

The previously referenced `battery-history3` / `battery_io` / 6-second implementation belongs to an older public-source lineage and is **legacy implementation evidence only**.

### 3.2 Scene History identity and interval

Current APK groups History by `records.session` and maps:

```text
beginTime = min(records.time)
endTime   = max(records.time)
```

The History selector formats **`beginTime`** as `yyyy-MM-dd HH:mm`.

Therefore:

- Scene History timestamp semantics = **session start**
- `history_session_at` = `beginTime`
- session wall duration = `endTime - beginTime` when the second History duration is captured

The previous rule forbidding interval derivation because timestamp semantics were unknown is retired.

When only rounded History UI evidence exists, `history_session_at + wall_duration` may be used as an approximate end time, with precision explicitly marked as UI-rounded. Do not invent wall duration for older captures that did not preserve it.

### 3.3 Scene History two durations

Current sampling interval for this History implementation is **3 seconds**.

History first duration:

```text
used × 3 s
```

where `used` counts records satisfying:

```sql
screen_on = 1
AND status IN (DISCHARGING, NOT_CHARGING)
```

Canonical meaning:

> **Scene-valid screen-on sampled duration**

It is Scene's own screen-on statistic, not automatically Android framework SOT.

History second duration:

```text
endTime - beginTime
```

Canonical meaning:

> **whole-session wall-clock span**

Therefore `1.4h / 2.5h` means approximately screen-on sampled duration / whole-session wall duration. The second value is **not theoretical runtime**.

### 3.4 Average power

Scene session average power is calculated from valid screen-on discharge/not-charging samples using:

```sql
avg(current * voltage)
```

Therefore `avg_power_w` is a **screen-on workload-normalized device-power metric**, not the entire session's wall-clock average including screen-off standby.

### 3.5 Theoretical runtime

Current APK implements the core relationship approximately as:

```text
theoretical_runtime ~= batteryEnergy / abs(avgPower) × 0.9
```

Battery energy is derived from battery capacity and a nominal voltage around `3.785097 V`, with a doubled-energy branch for a detected higher-voltage / dual-cell-series case.

This metric is workload-normalized. It must not be relabeled pure SOT or whole-session endurance.

### 3.6 Historical current-page header values remain invalid

Scene `ActivityPowerUtilization` capacity/status/voltage/temperature header values describe **current page/global device state**, not the selected old History session. They must not be copied onto historical sessions.

## 4. Source hierarchy

### 4.1 Scene — battery/workload source

For the current installed package/build:

1. **Production source: Scene History/detail screenshots**
2. Current installed APK static RE for field semantics
3. UIAutomator only for exceptional historical forensic recovery, never routine collection

A lawful read-only `run-as com.omarea.vtools` probe returned:

```text
STOP: run-as unavailable
```

Therefore direct private-DB access is **closed as a production route** for this current build. Do not retry private-data access variants or permission-bypass approaches.

### 4.2 MacroDroid — environmental context source

MacroDroid does not capture Scene metrics. It records low-cost environmental events.

Target network states:

- `home_wifi`
- `mobile`
- `other_wifi`
- `unknown`

Target additional events:

- coverage / heartbeat
- navigation `on/off` after a reliable signal is designed and validated

The existing pilot `home_wifi` / `out_4g` logic is not final because `not home Wi-Fi != confirmed mobile`.

### 4.3 Device-state timeline

Maintain a sparse append-only timeline for changes such as:

- OriginOS exact build
- resolution
- refresh rate
- battery health / cycles snapshot
- root state
- scheduler / governor / performance profile
- major power-related system-setting changes

Only changes need new rows.

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
│  └─ architecture / RE / schema / handoff documentation
└─ legacy/
   └─ old UIAutomator / backlog tooling if/when migrated
```

### 5.1 `sessions.csv`

One finalized Scene History session per row.

Target fields:

- `session_id`
- `history_session_at`
- `history_time_semantics` = `start`
- `history_timezone`
- `wall_duration_seconds` (nullable if old evidence did not preserve it)
- `interval_start`
- `interval_end` (nullable if wall duration is unavailable)
- `interval_precision`
- `avg_power_w`
- `screen_on_duration_seconds`
- `screen_on_semantics` = `scene_valid_screen_on_samples_3s`
- `theoretical_runtime_seconds`
- `eligibility`
- `scene`
- `network`
- `navigation`
- `app_attribution_quality`
- `context_quality`
- `source_type`
- `source_ref`
- `notes`

Historical migration must be lossless: if an old capture did not retain History wall duration, leave `wall_duration_seconds` / `interval_end` blank. Never substitute theoretical runtime.

### 5.2 `app_sessions.csv`

Per-session app evidence. Aggregate app summaries are derived outputs.

Target fields:

- `session_id`
- `package_name` when available
- `app_label`
- `duration_seconds`
- `avg_power_w`
- `avg_temp_c` only when the Scene row genuinely represents that session
- `max_temp_c`
- `source_ref`

Do not reconstruct per-session rows from an aggregate `app_summary.csv` if the original granular rows were not retained.

### 5.3 `context_events.csv`

Append-only environmental event stream:

- `event_at`
- `event_type`
- `state`
- `source`
- `detail`
- `valid`

Session scene classification is derived from overlap with a verified session interval; it is not inferred from watts or app names.

### 5.4 `device_state_events.csv`

Sparse configuration-change event stream:

- `effective_at`
- `key`
- `value`
- `source`
- `notes`

## 6. Eligibility and deduplication

Exact detail `screen_on_duration` remains the eligibility criterion:

- `<20 min`: evidence only / excluded
- `20–30 min`: provisional
- `>=30 min`: main ledger

Deduplication must use multiple signals, not average watts alone:

- History start timestamp
- average power
- screen-on duration
- wall duration when captured
- theoretical runtime
- date / curve evidence
- app distribution

Repeated live/current screenshots are provisional observations of one ongoing session until reconciled with finalized History.

## 7. Production screenshot workflow

The production route for the current build is deliberately low-interference.

### Periodic History capture

Take recent History-list screenshots periodically rather than only when a session looks interesting. The list can supply:

- stable session start timestamp
- rounded Scene-valid screen-on duration
- rounded wall duration
- other visible History summary values

This reduces selection bias and avoids repeated automation.

### Detail capture

For a new finalized eligible session, open its detail when needed to capture:

- exact Scene `screen_on_duration`
- average power
- theoretical runtime
- per-app attribution

Current/live detail screenshots remain provisional until matched to a finalized History identity.

### Forbidden routine workflow

- no UIAutomator capture loop
- no OCR
- no force-stop / CLEAR_TASK state machine
- no background Runner process
- no repeated private-DB access probes

## 8. Existing evidence status (2026-09-05)

Accepted historical foundation:

- 41 finalized Scene History detail sessions
- all 41 have exact `screen_on_duration >=30 min`
- 12 older eligible History rows intentionally left uncaptured
- one known partial app-attribution session: `2026-07-23 20:53` (56.9% duration coverage)
- one provisional 2026-09-05 live session group, not finalized canonical data
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

The 41-session set is useful as a cross-scene historical baseline, but most rows lack reliable network context and must not be presented as Wi-Fi/mobile comparisons.

Older captures did not preserve the History-list wall-duration field in the current canonical ledger. Do not backfill it from theoretical runtime or assumptions.

## 9. Legacy tooling and source policy

All `capture_*`, `full_sync_*`, probe and backlog scripts from the old recovery effort are **legacy forensic tooling**.

- do not use them for routine logging
- do not delete them merely because a later architecture supersedes them
- move under `legacy/` only when an audit-safe migration is performed

The old public `battery-history3` / 6-second source remains lineage/reference material only. For current Scene semantics, the current installed APK RE note is authoritative.

## 10. Current implementation order

The previous DB-semantics blocker is resolved. Proceed in this order:

1. preserve the current installed APK RE findings in GitHub — **done**
2. migrate session-level canonical data into the resolved `sessions.csv` schema without inventing missing wall-duration values
3. preserve `session_ledger.csv` as the historical intermediate source rather than rewriting its 41 rows in place
4. create `app_sessions.csv` only from genuine retained per-session app evidence; do not reverse aggregate `app_summary.csv`
5. finalize the low-effort History/detail screenshot ingestion workflow
6. redesign MacroDroid context events into `home_wifi/mobile/other_wifi/unknown` plus coverage signal
7. add initial `device_state_events.csv` baseline
8. only then consider navigation automation

No additional `run-as`/private-DB validation step is required for the current APK semantics.
