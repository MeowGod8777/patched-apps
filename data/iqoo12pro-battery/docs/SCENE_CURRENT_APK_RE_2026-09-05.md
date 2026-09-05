# Scene current installed APK — battery statistics RE (2026-09-05)

Status: **current implementation evidence for the user's installed Scene APK**

This note records static reverse-engineering results from the APK copied directly from the user's installed `com.omarea.vtools` on iQOO 12 Pro / V2329A on 2026-09-05.

## Artifact identity

- source: current installed Scene APK copied from the device
- package: `com.omarea.vtools`
- local analysis filename: `Scene_current.apk`
- size: about 7.0 MiB
- SHA-256: `0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80`
- DEX layout: single `classes.dex`

The exact app version string was not asserted because the available analysis environment did not decode the binary Android manifest reliably. The SHA-256 is the authoritative artifact identity for this note.

## Current storage model

The current APK uses private SQLite database:

```text
power8
```

Current table schema recovered from the APK:

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

This supersedes the older public-source `battery-history3` / `battery_io` schema for current-version semantic interpretation.

## History session construction

The current APK contains the following session-level query logic:

```sql
select a.*, b.p, b.used
from (
    select session as s, min(time), max(time)
    from records
    group by session
) as a
left join (
    select session as s,
           avg(current * voltage) as p,
           count(1) as used
    from records
    where screen_on = 1
      and status in (?, ?)
    group by session
) as b
on a.s = b.s
```

Recovered cursor mapping:

- column 0 `session` -> `PowerStatSession.session`
- column 1 `min(time)` -> `PowerStatSession.beginTime`
- column 2 `max(time)` -> `PowerStatSession.endTime`
- column 3 -> `PowerStatSession.avgPower`
- column 4 -> `PowerStatSession.used`

Therefore one History row is a Scene `session`, with:

```text
beginTime = min(records.time)
endTime   = max(records.time)
```

## History timestamp semantics

The History selector formats `PowerStatSession.beginTime` with:

```text
yyyy-MM-dd HH:mm
```

Therefore:

> **Scene History timestamp = session start timestamp (`beginTime`).**

It is not the session end timestamp.

## History two-duration semantics

The current APK uses a 3000 ms sampling interval for the History/session duration calculation.

The first History duration is:

```text
used * 3000 ms
```

where `used` is the count of rows satisfying:

```sql
screen_on = 1
AND status IN (DISCHARGING, NOT_CHARGING)
```

Therefore the first History duration is:

> **Scene-valid screen-on sampled duration = valid screen-on sample count × 3 seconds.**

This is Scene's own sampled screen-on metric. It should not be renamed Android framework SOT without separate evidence.

The second History duration is:

```text
endTime - beginTime
```

Therefore a History row such as:

```text
1.4h / 2.5h
```

means approximately:

```text
Scene-valid screen-on duration / whole-session wall-clock span
```

The second value is **not theoretical runtime**.

## Average-power semantics

The current session History query computes:

```sql
avg(current * voltage)
```

only for rows satisfying:

```sql
screen_on = 1
AND status IN (DISCHARGING, NOT_CHARGING)
```

A separate single-session query follows the same screen-on/status restriction.

Therefore Scene's session average power is a **screen-on workload-normalized device-power average**, not a wall-session average that includes the entire screen-off standby interval.

This is why Scene theoretical runtime is useful as a workload-normalized indicator but must not be called pure SOT or whole-session endurance.

## Theoretical-runtime calculation

Static RE recovered the core relationship:

```text
theoretical runtime ~= batteryEnergy / abs(avgPower) * 0.9
```

The current APK derives battery energy from battery capacity and a nominal voltage of approximately `3.785097 V`, with a doubled-energy branch for a detected higher-voltage / dual-cell-series condition.

Conceptually:

```text
batteryEnergy_mWh ~= capacity_mAh * 3.785097
```

or, for the detected doubled-energy case:

```text
batteryEnergy_mWh ~= capacity_mAh * 3.785097 * 2
```

Since `current(mA) * voltage(V)` is `mW`, `mWh / mW` yields hours. The implementation then applies the `0.9` correction factor.

Treat this as implementation semantics tied to this APK hash, not as a generic formula for all Scene versions.

## Session boundary implications

Scene's modern History feature is session-based. Public Scene changelog evidence also indicates that modern power statistics are reset when charging begins. For ledger purposes, History identity is therefore the Scene session itself, with the exact start timestamp supplied by `beginTime` and wall span supplied by `endTime - beginTime` when that second History duration is captured.

## Legacy source distinction

Previously referenced public source:

- repo: `ramabondanp/vtools_en`
- commit: `faeab044b68fb4f1b9187c6020c01c88330523b9`
- DB: `battery-history3`
- table: `battery_io`
- older sampling behavior: 6 seconds in the referenced UI/statistics code

That source remains useful for historical lineage only. It must **not** be used to define the current installed APK's exact storage schema, sampling interval, History timestamp semantics, or two-duration semantics.

Current installed APK evidence takes precedence for those questions.

## Device access result

A lawful read-only `run-as com.omarea.vtools` feasibility probe on the user's installed package returned:

```text
STOP: run-as unavailable
```

Therefore the private `power8` database is **not a production collection route** on the current package/build. No permission-bypass route should be attempted.

No additional private-DB validation is required for these implementation definitions: they were recovered directly from the current installed APK. Re-run static RE only if the installed Scene APK changes or observed UI behavior materially contradicts these definitions.

## Canonical consequences

For this APK lineage:

- `history_time_semantics = start`
- `history_session_at = beginTime`
- `screen_on_duration = valid screen-on sample count × 3 s`
- `wall_duration = endTime - beginTime`
- `avg_power = average current × voltage over valid screen-on discharge/not-charging samples`
- theoretical runtime is workload-normalized and includes the implementation's `0.9` correction
- do not confuse History second duration with theoretical runtime
- do not attach current-page battery header state to old History sessions

The production route for the current device is therefore the low-interference History/detail screenshot path, with static APK RE supplying the field semantics.
