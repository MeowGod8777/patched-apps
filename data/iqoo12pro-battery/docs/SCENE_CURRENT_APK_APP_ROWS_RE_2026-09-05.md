# Scene 9.3.8 current APK — per-app battery row RE (2026-09-05)

Artifact authority:

```text
package: com.omarea.vtools
versionName: 9.3.8
APK SHA-256: 0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80
classes.dex SHA-256: b2e36578ad3f0f2d54e0eedc236798d0b504bbea274e183f60e8afad8b96830f
```

This note extends `SCENE_CURRENT_APK_RE_2026-09-05.md` with the exact semantics of per-app rows shown in a selected power-statistics session.

## Session app query

The current APK contains this query:

```sql
select * from (
    select
        avg(current) AS current,
        avg(current * voltage) AS power,
        avg(temperature) as avg,
        min(temperature) as min,
        max(temperature) as max,
        package,
        mode,
        count(current)
    from records
    where session = ?
      and status in (?, ?)
      and screen_on = 1
      and package != ''
    group by package, mode
) r
order by current
```

Therefore an app row is not merely keyed by package. It is grouped by:

```text
package + Scene mode
```

The same package can legitimately produce multiple rows in one session when it is observed under different Scene modes.

## PowerStatAVG row semantics

The query maps to a `PowerStatAVG` model with fields including:

- average current
- average electrical power (`current * voltage`)
- average temperature
- minimum temperature
- maximum temperature
- package name
- mode
- sample count

The row is restricted to:

```text
screen_on = 1
status = DISCHARGING or NOT_CHARGING
package != empty
```

Thus per-app power/temperature/duration attribution refers to Scene-valid screen-on samples, consistent with the session-level workload metric.

## Per-app duration

The current app-row adapter constructor stores the literal sampling interval:

```text
3 seconds
```

When binding a row it performs effectively:

```text
duration_seconds = PowerStatAVG.count * 3
```

then converts seconds to minutes and sends the result to Scene's detailed duration formatter (`xj0.c`).

Therefore:

> **Current Scene 9.3.8 per-app duration = valid app sample count × 3 seconds.**

This is independent direct APK evidence; do not use the old public-source 6-second interval for current app-row interpretation.

## Display behavior

The adapter supports at least these visible statistics depending on display mode/preferences:

```text
%.2fW, %d℃
```

or:

```text
%dmA, %d℃
```

and separately binds maximum temperature and duration. It also retains the Scene mode associated with each row.

The app list may be re-sorted by current Scene UI preferences; display order is not a semantic key.

## Canonical implications

Future `app_sessions.csv` should preserve at minimum:

- `session_id`
- `package_name` when recoverable
- `app_label`
- `mode`
- `duration_seconds`
- `duration_semantics = scene_valid_app_samples_3s`
- `avg_power_w` when shown/available
- `avg_current_ma` when shown/available
- `avg_temp_c`
- `max_temp_c`
- `source_ref`

Do not merge two rows solely because their app labels match. Package + mode is the implementation-level grouping identity.

The historical 436 deduplicated app rows discussed during the 2026-09-05 ingestion effort were not retained as a granular repository artifact, and their referenced `sync_raw/detail-*` files are absent from the repository tree. They must not be reconstructed from aggregate `app_summary.csv`.

For future sessions, granular app rows should be appended when genuine detail evidence is captured so aggregate summaries can be regenerated from canonical data rather than becoming the only retained representation.
