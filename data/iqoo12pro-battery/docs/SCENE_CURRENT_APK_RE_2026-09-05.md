# Scene current installed APK — battery statistics RE (2026-09-05)

Status: **current implementation evidence for the user's installed Scene APK**

This note records static reverse-engineering results from the APK copied directly from the user's installed `com.omarea.vtools` on iQOO 12 Pro / V2329A on 2026-09-05.

## Artifact identity

- source: current installed Scene APK copied from the device
- package: `com.omarea.vtools`
- versionName: `9.3.8`
- local analysis filename: `Scene_current.apk`
- size: `7,292,507` bytes
- APK SHA-256: `0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80`
- `classes.dex` SHA-256: `b2e36578ad3f0f2d54e0eedc236798d0b504bbea274e183f60e8afad8b96830f`
- main app DEX layout: single `classes.dex` (`res/raw/rish_shizuku.dex` is a separate embedded helper payload)

The APK SHA-256 is the authoritative artifact identity for this note.

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

The model fields recovered from `PowerStatSession` are:

```text
avgPower : double
beginTime: long
endTime  : long
session  : int
used     : int
```

Recovered cursor-to-model mapping:

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

The History-selector adapter formats `PowerStatSession.beginTime` with:

```text
yyyy-MM-dd HH:mm
```

Therefore:

> **Scene History timestamp = session start timestamp (`beginTime`).**

It is not the session end timestamp. The UI string itself has minute resolution even though the underlying `beginTime` is a `long` timestamp.

## History two-duration semantics

The current APK uses a 3000 ms sampling interval for the History/session duration calculation.

The first History duration is implemented as:

```text
used * 3000 ms
```

The adapter bytecode loads `PowerStatSession.used`, converts it to `long`, multiplies it by the literal `3000`, converts to `double`, and divides by `60000.0` before passing the result to the duration formatter.

`used` itself comes from the SQL count of rows satisfying:

```sql
screen_on = 1
AND status IN (DISCHARGING, NOT_CHARGING)
```

Therefore the first History duration is:

> **Scene-valid screen-on sampled duration = valid screen-on sample count × 3 seconds.**

This is Scene's own sampled screen-on metric. It should not be renamed Android framework SOT without separate evidence.

The second History duration is implemented from:

```text
endTime - beginTime
```

The adapter loads `PowerStatSession.endTime`, subtracts `PowerStatSession.beginTime`, converts the result to minutes, and passes it to the same duration formatter.

Therefore a History row such as:

```text
1.4h / 2.5h
```

means approximately:

```text
Scene-valid screen-on duration / whole-session wall-clock span
```

The second value is **not theoretical runtime**.

## Exact History `x.xh` formatting / precision

Both History duration values are passed to obfuscated utility method `xj0.d(double)`, whose parameter is minutes.

Re-disassembly of that method shows the following effective calculation:

```text
shown_hours = floor(minutes / 6) / 10.0
shown_text  = shown_hours + "h"
```

The bytecode sequence is effectively:

1. divide input minutes by `6.0`
2. convert the result to integer, truncating toward zero (all relevant durations are non-negative)
3. convert back to double
4. divide by `10.0`
5. append `"h"`

Therefore History duration display is **downward quantization in 0.1 h / 6-minute buckets**, not conventional decimal rounding.

Examples:

```text
84 min  -> floor(84 / 6) / 10 = 1.4h
89 min  -> floor(89 / 6) / 10 = 1.4h
90 min  -> 1.5h
```

For any displayed History value `D h`:

```text
D h <= actual duration < (D + 0.1) h
```

or in seconds:

```text
shown_seconds <= actual_seconds < shown_seconds + 360
```

This applies independently to:

- the first History value derived from `used × 3000 ms`
- the second History value derived from `endTime - beginTime`

Canonical implication: a History-list duration alone must not be recorded as an exact second count. Preserve the displayed value and/or its lower/upper bounds. Detail-page `h/m/s` evidence is preferred for exact Scene screen-on duration.

Because the History start timestamp is itself shown only to the minute, an end time inferred from only the History row has combined UI uncertainty: the underlying start may be up to <60 seconds later than the displayed minute, and the wall duration may be up to <360 seconds larger than its displayed bucket. A safe bound from History UI alone is therefore:

```text
end_lower = displayed_start + shown_wall_duration
end_upper_exclusive = displayed_start + shown_wall_duration + 420 s
```

assuming the device timezone represented by the screenshot is known and unchanged.

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

A separate single-session query follows the same screen-on/status restriction:

```sql
select avg(current * voltage) AS power
from records
where session = ?
  and status in (?, ?)
  and screen_on = 1
```

Therefore Scene's session average power is a **screen-on workload-normalized device-power average**, not a wall-session average that includes the entire screen-off standby interval.

This is why Scene theoretical runtime is useful as a workload-normalized indicator but must not be called pure SOT or whole-session endurance.

## Theoretical-runtime calculation

Static RE of the current History/detail adapter recovers the following sequence:

```text
batteryEnergy / abs(avgPower) * 60 * 0.9
```

The result is passed to a formatter that expects minutes. Equivalently, in hours:

```text
theoretical_runtime_hours ~= batteryEnergy / abs(avgPower) * 0.9
```

### Battery-energy helper

The current APK's battery-energy helper uses a nominal voltage literal of **`3.86 V`**.

Its effective logic is:

```text
energy = batteryCapacity * 3.86
```

with a doubled-energy branch when both of the following are true:

```text
batteryCapacity <= 2510
reported/detected battery voltage > 5.0 V
```

In that branch:

```text
energy = batteryCapacity * 3.86 * 2
```

The capacity helper is populated through Scene's battery-capacity path; the APK also contains reflective use of:

```text
com.android.internal.os.PowerProfile
getBatteryCapacity
```

For dimensional interpretation, the implementation is consistent with treating capacity as mAh and the nominal voltage factor as V, yielding mWh, while `current(mA) * voltage(V)` yields mW. Thus `mWh / mW` yields hours before the `0.9` correction.

Important correction: an earlier oral/static-RE note incorrectly stated approximately `3.785097 V`. Re-disassembly of the actual `ha0.l()` bytecode shows the literal double is **exactly `3.86`** for this APK. `3.86 V` is the authoritative value for APK SHA-256 `0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80`.

Treat this formula as implementation semantics tied to this APK hash/version, not as a generic formula for all Scene versions.

## Session boundary implications

Scene's modern History feature is session-based. Public Scene changelog evidence also indicates that modern power statistics are reset when charging begins. For ledger purposes, History identity is therefore the Scene session itself, with the exact start timestamp supplied by `beginTime` and wall span supplied by `endTime - beginTime` when that second History duration is captured.

## Legacy source distinction

Previously referenced public source:

- repo: `ramabondanp/vtools_en`
- commit `faeab044b68fb4f1b9187c6020c01c88330523b9`
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

For Scene `9.3.8` / this APK hash:

- `history_time_semantics = start`
- `history_session_at = beginTime`
- `screen_on_duration = valid screen-on sample count × 3 s`
- History first/second `x.xh` values are downward-truncated 6-minute buckets
- `wall_duration = endTime - beginTime`
- `avg_power = average current × voltage over valid screen-on discharge/not-charging samples`
- theoretical runtime is workload-normalized and includes the implementation's `0.9` correction
- current theoretical-runtime energy helper uses nominal `3.86 V`, with the conditional doubled-energy branch described above
- do not confuse History second duration with theoretical runtime
- do not attach current-page battery header state to old History sessions

The production route for the current device is therefore the low-interference History/detail screenshot path, with static APK RE supplying field semantics and precision bounds.
