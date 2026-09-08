# 2026-09-08 battery-ledger ingestion notes

## Inputs

- Scene live/detail screenshot at status-bar time `03:49:21`
- Scene live/detail screenshot at status-bar time `08:03:16`
- Scene live/detail screenshot at status-bar time `11:25:01`
- uploaded `/sdcard/SceneBattery/context_events_v2.csv`

The Scene screenshots do not show an internal Scene date/session-start timestamp. Per the ingestion contract, their date is therefore the conversation/capture date (`2026-09-08`) and all three remain **provisional live captures** until matched to finalized History rows.

## Provisional Scene captures

| capture | avg power | Scene-valid screen-on | theoretical runtime | remaining | app attribution coverage |
|---|---:|---:|---:|---:|---:|
| 03:49:21 | 3.13 W | 1h09m (4140 s) | 5h39m | 40% | 3939/4140 = 95.14% |
| 08:03:16 | 2.59 W | 55m02s (3302 s) | 6h50m | 53% | 3153/3302 = 95.49% |
| 11:25:01 | 2.92 W | 1h13m (4380 s) | 6h03m | 22% | 4250/4380 = 97.03% |

All three exceed the 30-minute main-eligibility duration threshold, but they are **not promoted to `canonical/sessions.csv` yet** because History identity/start/wall-span evidence is absent.

### Distinctness / dedupe

The three captures are treated as three distinct provisional Scene sessions:

- `03:49` -> `08:03`: battery remaining rises from 40% to 53%, proving an intervening charge/reset rather than one uninterrupted discharge session.
- `08:03` -> `11:25`: the app-attribution sets are non-cumulative while each screenshot already accounts for ~95–97% of Scene-valid screen-on time. Apps with substantial `08:03` duration (for example LINE貼貼/Gmail) disappear from the `11:25` capture, so these are not successive snapshots of one accumulating Scene session.

## MacroDroid context batch

The uploaded raw file is preserved byte-for-text as `context_events_v2_uploaded_raw.csv`.

Important source property: the uploaded file has **no CSV header**. It contains 68 raw rows from:

- first: `2026-09-05T22:52:49.910+08:00`
- last: `2026-09-08T11:03:47.107+08:00`

The raw batch includes acceptance-test rows plus later natural-use rows. It also contains two obvious near-simultaneous duplicate transition pairs:

- `2026-09-06T21:22:39.121/.127+08:00` -> `offline`
- `2026-09-07T19:32:11.865/.879+08:00` -> `home_wifi / DaFengLi_5G`

These remain preserved in the raw snapshot; future canonical promotion may suppress only the duplicate representation, never rewrite raw evidence.

## Context integrity warning discovered by the screenshots

Do **not** bulk-promote the 2026-09-06..08 MacroDroid batch into `canonical/context_events.csv` yet.

Reason: the Scene screenshots expose a coverage contradiction/gap around network state:

- `03:49:21` screenshot visibly shows a Wi-Fi status icon and substantial internet-app use, while the surrounding MacroDroid timeline carries `offline` from the prior night to the next morning with no corresponding Wi-Fi transition.
- `08:03:16` screenshot visibly shows a Wi-Fi status icon, but MacroDroid recorded an `offline` heartbeat only ~51 seconds earlier at `08:02:25.015`; no Wi-Fi transition was logged around the capture.
- `11:25:01` is consistent with MacroDroid: transition to `home_wifi / DaFengLi_5G` at `10:35:54.234`, heartbeat at `11:03:47.107`, and Wi-Fi icon visible in the screenshot.

The first two observations do not prove that the v2.5 classifier itself is always wrong; the user could have enabled Wi-Fi after an `offline` heartbeat. They do prove that **short Wi-Fi-on periods can be absent from the event timeline**, so session-wide network labels cannot be assigned from this batch without resolving the transition-coverage problem.

Therefore:

- `03:49` capture network = `unknown` (screenshot/context conflict)
- `08:03` capture network = `unknown` (nearby heartbeat/context conflict)
- `11:25` capture-instant network = `home_wifi`, but full-session network still awaits History interval joining

`canonical/context_events.csv` is intentionally left unchanged by this ingestion.

## Files created

- `provisional_live_sessions.csv`
- `provisional_app_rows.csv`
- `context_events_v2_uploaded_raw.csv`

The next stable identity evidence should be a recent Scene History screenshot containing these sessions, including both displayed duration values. That will allow reconciliation into finalized `canonical/sessions.csv` and later per-session app rows without inventing start/end timestamps.
