# 2026-09-08 Scene History reconciliation

## Input

Scene History screenshot `conversation_attachment:1000150181.jpg` captured/uploaded on 2026-09-08.

The screenshot provides finalized History identities, average power, truncated Scene-valid screen-on duration, truncated wall duration, and truncated theoretical runtime for recent sessions. Existing overlap anchors `2026-09-03 22:30`, `2026-09-04 07:27`, and `2026-09-04 13:23` match canonical rows and are not duplicated.

## Newly observed finalized History rows

| History start | avg W | screen-on shown | wall shown | theoretical shown | eligibility from History prefilter |
|---|---:|---:|---:|---:|---|
| 2026-09-03 23:54 | 2.42 | 0.0h | 0.0h | 7.3h | evidence-only (<18m guaranteed) |
| 2026-09-04 14:18 | 1.92 | 0.3h | 0.3h | 9.2h | provisional/ambiguous (18–<24m) |
| 2026-09-04 14:46 | 3.80 | 0.1h | 9.1h | 4.6h | evidence-only (<18m guaranteed) |
| 2026-09-05 08:45 | 2.73 | 3.5h | 4.6h | 6.4h | main-eligible |
| 2026-09-05 13:45 | 2.00 | 5.1h | 5.2h | 8.8h | main-eligible |
| 2026-09-05 19:26 | 1.98 | 1.0h | 3.5h | 8.9h | main-eligible |
| 2026-09-05 23:22 | 2.58 | 0.9h | 20.7h | 6.8h | main-eligible |
| 2026-09-06 20:30 | 3.14 | 1.1h | 19.3h | 5.6h | main-eligible |
| 2026-09-07 16:07 | 2.92 | 1.2h | 19.3h | 6.0h | main-eligible |

History `x.xh` values are downward-truncated in 0.1h / 6-minute buckets. They are stored as bounds, not exact seconds.

## Reconciliation of the three prior live/detail captures

The History screenshot resolves the date/session identity of all three previously provisional captures. The earlier generated provisional snapshot remains immutable evidence; this file records the later reconciliation.

### `03:49:21` capture -> `2026-09-06 20:30`

Live/detail observation:

- avg power 3.13 W
- Scene-valid screen-on 1h09m = 4140 s
- theoretical runtime 5h39m

Final History row:

- avg power 3.14 W
- screen-on 1.1h => actual >=3960 s and <4320 s
- wall 19.3h => session end bounded around 2026-09-07 15:48–15:55
- theoretical 5.6h

The metric match plus interval containment strongly identifies the capture as `2026-09-07T03:49:21+08:00` inside History session `2026-09-06 20:30`.

### `08:03:16` capture -> `2026-09-05 23:22`

Live/detail observation:

- avg power 2.59 W
- Scene-valid screen-on 55m02s = 3302 s
- theoretical runtime 6h50m

Final History row:

- avg power 2.58 W
- screen-on 0.9h => actual >=3240 s and <3600 s
- wall 20.7h => session end bounded around 2026-09-06 20:04–20:11
- theoretical 6.8h

The metric match plus interval containment identifies the capture as `2026-09-06T08:03:16+08:00` inside History session `2026-09-05 23:22`.

### `11:25:01` capture -> `2026-09-07 16:07`

Live/detail observation:

- avg power 2.92 W
- Scene-valid screen-on 1h13m = 4380 s
- theoretical runtime 6h03m

Final History row:

- avg power 2.92 W
- screen-on 1.2h => actual >=4320 s and <4680 s
- wall 19.3h => session end bounded around 2026-09-08 11:25–11:32
- theoretical 6.0h

This is an especially strong match: the capture time lies at the lower edge of the History-derived end window and the average power is identical. It is reconciled to History session `2026-09-07 16:07`.

## Precision rule for reconciled live captures

The live/detail `h/m/s` values are exact at the observation time, but for captures taken before the finalized History endpoint they are not automatically promoted as the exact final session duration. Canonical final duration therefore remains History-bounded unless a trustworthy final detail capture proves the exact endpoint value.

The app rows are genuine per-session granular evidence after reconciliation and may be promoted to `canonical/app_sessions.csv` with `snapshot_partial` quality.

## MacroDroid context implication

The date reconciliation preserves the context warning from `INGEST_NOTES.md`:

- `2026-09-06 08:03:16` visibly shows Wi-Fi while the v2.5 timeline had an `offline` observation around that period.
- `2026-09-07 03:49:21` visibly shows Wi-Fi during a span where the event timeline lacks the corresponding Wi-Fi transition.
- `2026-09-08 11:25:01` is consistent with `home_wifi / DaFengLi_5G` at the capture instant.

Because Scene average power is computed only from valid screen-on samples while MacroDroid events describe wall-clock network state, session-wide network labels remain `unknown` when active-time network coverage is insufficient or conflicting. Do not classify the long 19–21h sessions merely by wall-time dominance of `offline` versus Wi-Fi.
