# iQOO 12 Pro battery ledger — architecture v1 FINAL

Status: **production route and Scene semantics resolved on 2026-09-05**

This document is the architectural source of truth for the iQOO 12 Pro natural-use battery ledger. Current Scene semantics are grounded in static RE of the APK copied directly from the user's installed `com.omarea.vtools` on 2026-09-05. See `SCENE_CURRENT_APK_RE_2026-09-05.md`.

## 1. Product goal

Build a **low-interference, long-term natural-usage battery ledger** for iQOO 12 Pro / V2329A.

The ledger should support:

- natural-use power/endurance distribution over time
- home Wi-Fi / mobile / mixed / other-Wi-Fi comparisons when context evidence exists
- navigation vs non-navigation comparisons
- app/workload explanations for high/low power sessions
- battery-aging trends
- OriginOS / resolution / refresh / root / scheduler / other device-state comparisons

This is not a fixed-workload laboratory benchmark. Sessions do not need to be 100% -> 0%.

## 2. Non-goals

- do not maximize row count at the cost of user effort or selection bias
- do not require daily Runner commands
- do not create another routine UIAutomator capture version
- do not use OCR for Scene UI
- do not treat Scene theoretical runtime as pure SOT or wall-clock endurance
- do not infer environmental context when evidence is missing
- do not attach current-page battery header values to old History sessions
- do not bypass Android private-data permissions

## 3. Current Scene implementation authority

Current installed artifact:

```text
package: com.omarea.vtools
versionName: 9.3.8
APK SHA-256: 0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80
classes.dex SHA-256: b2e36578ad3f0f2d54e0eedc236798d0b504bbea274e183f60e8afad8b96830f
```

The old public `battery-history3` / `battery_io` / 6-second source is **legacy lineage evidence only**. It must not define current 9.3.8 semantics.

### 3.1 Current private storage model

Current APK uses SQLite database `power8`, table `records`:

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

### 3.2 History identity and interval

Current APK groups History by `records.session` and maps:

```text
beginTime = min(records.time)
endTime   = max(records.time)
```

History selector timestamp formats **`beginTime`** as `yyyy-MM-dd HH:mm`.

Therefore:

- `history_time_semantics = start`
- `history_session_at = beginTime`
- wall duration = `endTime - beginTime`

History timestamp is minute-resolution UI output; the hidden underlying `beginTime` may contain seconds/milliseconds.

### 3.3 History two durations

Current History sampling interval is **3 seconds**.

First History duration:

```text
used × 3 s
```

`used` counts only:

```sql
screen_on = 1
AND status IN (DISCHARGING, NOT_CHARGING)
```

Canonical meaning: **Scene-valid screen-on sampled duration**. Do not rename it Android framework SOT.

Second History duration:

```text
endTime - beginTime
```

Canonical meaning: **whole-session wall-clock span**.

Thus `1.4h / 2.5h` means screen-on sampled duration / wall span. The second value is not theoretical runtime.

### 3.4 Exact History display quantization

The History adapter sends both duration values, in minutes, to `xj0.d(double)`. Re-disassembly shows the formatter implements:

```text
shown_hours = floor(minutes / 6) / 10.0
shown_text  = shown_hours + "h"
```

Therefore History `x.xh` values are **truncated downward in 0.1 h = 6 min steps**, not rounded to nearest 0.1 h.

If a History value displays `D` hours, the actual represented duration is:

```text
D <= actual_duration < D + 0.1 h
```

or equivalently:

```text
shown_seconds <= actual_seconds < shown_seconds + 360 s
```

This precision must be retained in future screenshot ingestion. Do not store the displayed History duration as exact seconds.

Because History start time itself is displayed only to the minute, an end time inferred solely from a History row should be represented as a bounded/UI-rounded interval rather than a falsely exact timestamp.

### 3.5 Average power

Scene session average power is:

```sql
avg(current * voltage)
```

restricted to valid screen-on discharge/not-charging samples.

Therefore `avg_power_w` is a **screen-on workload-normalized device-power metric**, not the whole wall-session average including screen-off standby.

### 3.6 Theoretical runtime

Current 9.3.8 detail calculation uses:

```text
batteryEnergy / abs(avgPower) * 60 * 0.9
```

and passes that value as minutes to Scene's detailed duration formatter. In hours:

```text
theoretical_runtime_hours ~= batteryEnergy / abs(avgPower) * 0.9
```

Current battery-energy helper uses nominal **3.86 V**:

```text
energy = batteryCapacity * 3.86
```

with a doubled-energy branch when:

```text
batteryCapacity <= 2510
AND detected/reported battery voltage > 5.0 V
```

then:

```text
energy = batteryCapacity * 3.86 * 2
```

Theoretical runtime remains a workload-normalized indicator, not pure SOT or whole-session endurance.

### 3.7 Historical current-page headers are invalid

Scene ActivityPowerUtilization capacity/status/voltage/temperature header values describe current global device state, not an old selected History session. Never attach those header values to historical rows.

## 4. Production source hierarchy

For the current installed package/build:

1. **Scene History/detail screenshots** — production data source
2. current installed APK static RE — semantic authority
3. UIAutomator — exceptional historical forensic recovery only

A lawful read-only probe returned:

```text
STOP: run-as unavailable
```

Direct private-DB access is therefore **closed as a production route**. Do not retry `run-as` variants, permission bypasses, or private-data extraction tricks.

## 5. MacroDroid and device-state sources

MacroDroid records environmental context, not Scene metrics.

Final target network states:

- `home_wifi`
- `mobile`
- `other_wifi`
- `unknown`

Also retain a coverage/heartbeat signal. The pilot `out_4g` state must not be interpreted as confirmed mobile data because `not home Wi-Fi != mobile`.

Maintain a sparse append-only device-state timeline for changes such as:

- OriginOS exact build
- resolution
- refresh rate
- battery health / cycles
- root state
- scheduler / governor / performance profile
- major power-related system settings

## 6. Canonical data model

Current/target directory:

```text
data/iqoo12pro-battery/
├─ canonical/
│  ├─ session_ledger.csv     # preserved historical/intermediate source
│  ├─ sessions.csv           # normalized canonical sessions
│  ├─ app_summary.csv        # derived aggregate only
│  ├─ app_sessions.csv       # only if genuine granular rows exist
│  ├─ context_timeline.csv   # pilot context source
│  ├─ context_events.csv     # final context event model
│  ├─ device_state_events.csv
│  └─ README.md
├─ generated/YYYY-MM-DD/
├─ docs/
└─ legacy/
```

### 6.1 `sessions.csv`

One finalized Scene History session per row.

Core fields include:

- `session_id`
- `history_session_at`
- `history_time_semantics = start`
- `history_timezone`
- `wall_duration_seconds` when genuinely known
- `interval_start`
- `interval_end` when genuinely known
- `interval_precision`
- `avg_power_w`
- `screen_on_duration_seconds`
- `screen_on_semantics = scene_valid_screen_on_samples_3s`
- `theoretical_runtime_seconds`
- eligibility/context/app-quality/source fields

Historical migration is lossless: if old evidence did not preserve History wall duration, leave wall duration/end time blank. Never substitute theoretical runtime.

The 41 historical sessions were migrated to `canonical/sessions.csv` on 2026-09-05 while preserving `session_ledger.csv` unchanged.

### 6.2 `app_sessions.csv`

Per-session app rows are canonical only when genuine granular evidence exists. `app_summary.csv` is derived and cannot be reverse-expanded into per-session rows.

The prior 436 deduped app rows were not retained as a granular repo artifact; `sync_raw/detail-*` source refs are not present in the repository tree. Do not fabricate historical `app_sessions.csv` from aggregates.

### 6.3 `context_events.csv`

Append-only environmental events:

- `event_at`
- `event_type`
- `state`
- `source`
- `detail`
- `valid`

Scene classification is derived from overlap with a sufficiently known session interval.

### 6.4 `device_state_events.csv`

Sparse configuration changes:

- `effective_at`
- `key`
- `value`
- `source`
- `notes`

## 7. Eligibility and deduplication

Exact detail Scene screen-on duration controls eligibility:

- `<20 min`: evidence only / excluded
- `20–30 min`: provisional
- `>=30 min`: main

History-list quantization can be used only as a prefilter:

- `0.2h` or less: guaranteed below 18 min -> excluded from 20-min eligibility
- `0.3h`: actual 18–<24 min -> ambiguous across the 20-min threshold; inspect detail if needed
- `0.4h`: actual 24–<30 min -> provisional
- `0.5h` or greater: actual >=30 min -> main-eligible by duration, subject to finalized-session status

Deduplication must combine:

- History start timestamp
- average power
- screen-on duration
- wall duration when captured
- theoretical runtime
- date/curve evidence
- app distribution

Never dedupe on watts alone. Repeated live/current screenshots remain provisional observations until matched to finalized History.

## 8. Production screenshot workflow

### History capture

Periodically capture the recent History list rather than only cherry-picking interesting sessions. Preserve the whole row so the start timestamp and both truncated duration values remain available.

For each captured History duration, store both the displayed value and its known 6-minute truncation bounds if interval analysis is needed.

### Detail capture

For new finalized sessions that matter to the ledger, open detail as needed to capture:

- exact Scene screen-on duration
- average power
- theoretical runtime
- per-app attribution

Detail `h/m/s` evidence is preferred over the quantized History first duration for canonical screen-on duration and eligibility.

### Forbidden routine workflow

- no UIAutomator capture loop
- no OCR
- no force-stop / CLEAR_TASK state machine
- no background Runner process
- no repeated private-DB probes

## 9. Existing evidence status (2026-09-05)

Accepted foundation:

- 41 finalized Scene History detail sessions
- all 41 have exact Scene screen-on duration >=30 min
- 41 normalized rows now exist in `canonical/sessions.csv`
- 12 older eligible History rows intentionally left uncaptured
- one partial app-attribution session: `2026-07-23 20:53` (56.9% duration coverage)
- one provisional 2026-09-05 live group, not finalized
- first valid MacroDroid transition: `2026-09-05T12:40:43+08:00`

Most historical rows lack reliable network context and must not be presented as Wi-Fi/mobile comparisons.

Older captures did not preserve the History second/wall duration in canonical data. Those wall spans remain blank.

## 10. Current implementation order

Completed:

1. direct private-DB feasibility resolved -> unavailable
2. current installed Scene APK semantics RE'd and documented
3. History timestamp / both duration semantics resolved
4. 41 historical sessions migrated losslessly into `canonical/sessions.csv`

Next:

1. finalize the low-effort History/detail screenshot ingestion record format, including 6-minute truncation bounds
2. do not reconstruct missing historical `app_sessions.csv`; begin granular retention only with future genuine detail evidence
3. redesign MacroDroid context events into `home_wifi/mobile/other_wifi/unknown` + coverage signal
4. add initial `device_state_events.csv` baseline
5. only then consider navigation automation

No additional `run-as` or private-DB validation step is required for this APK.
