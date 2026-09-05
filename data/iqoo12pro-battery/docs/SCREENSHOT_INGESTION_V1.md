# iQOO 12 Pro battery ledger — Scene screenshot ingestion v1

Status: **production collection contract for current Scene 9.3.8 lineage**

This workflow is intentionally manual-at-capture and automated-at-ingestion. The user should not need daily Runner commands, UIAutomator, OCR, or private-DB access.

Current semantic authority:

- `SCENE_CURRENT_APK_RE_2026-09-05.md`
- `SCENE_CURRENT_APK_APP_ROWS_RE_2026-09-05.md`

## 1. User-side routine

### A. Periodic History-list capture

Open Scene battery/power History and capture the recent list periodically.

Requirements:

- include every new row since the last captured known session
- preferably include **one already-known previous row** as an overlap anchor
- do not capture only unusually good/bad power sessions
- do not crop away the History row's timestamp or either duration value
- no special filename is required; screenshots can be uploaded directly to ChatGPT

Frequency is based on convenience and row turnover, not a daily obligation. Capture often enough that new History rows are not lost from Scene's retained-history window.

### B. Detail capture for a new relevant session

For a new finalized session that is main-eligible or otherwise worth retaining, open the session detail and capture:

- average power
- exact Scene `screen_on_duration` / `已使用`
- theoretical runtime
- app attribution rows

If the app list needs multiple screens, capture enough screens to cover the rows intended for attribution. Do not use OCR or automated scrolling as the production path.

### C. Live/current screenshots

A current/live statistics page is **provisional only**. Repeated screenshots from the same ongoing session are observations of one live session until a finalized History row supplies stable identity.

## 2. History row semantics

For Scene 9.3.8 / APK SHA-256 `0ed83e956f9e6050cc3459a46ea80dfa7083bedb4f195051644fe19e28423d80`:

```text
History timestamp = session beginTime / start
first x.xh       = Scene-valid screen-on sampled duration
second x.xh      = session wall-clock duration
```

Both `x.xh` duration displays are **downward truncated** in 0.1 h / 6-minute buckets:

```text
shown_hours = floor(minutes / 6) / 10
```

They are not rounded to nearest 0.1 h.

## 3. Precision model for History-only evidence

For any displayed History duration `D` hours:

```text
lower_seconds = D * 3600
upper_seconds_exclusive = lower_seconds + 360
```

Example:

```text
1.4h -> actual duration is >= 5040 s and < 5400 s
```

History timestamp is displayed only as `yyyy-MM-dd HH:mm`, so the underlying start is bounded by:

```text
start_lower = displayed minute
start_upper_exclusive = displayed minute + 60 s
```

If only the History row is available, wall-duration-derived end bounds are:

```text
end_lower = start_lower + wall_lower
end_upper_exclusive = start_upper_exclusive + wall_upper_exclusive
```

Equivalently, relative to `displayed_start + shown_wall_duration`, the upper-exclusive uncertainty is 420 seconds.

Do **not** write a single exact `interval_end` from History-only `x.xh` evidence.

Recommended future-ingestion fields when a History wall duration is available:

- `history_screen_on_display_h`
- `history_screen_on_lower_seconds`
- `history_screen_on_upper_seconds_exclusive`
- `history_wall_display_h`
- `history_wall_lower_seconds`
- `history_wall_upper_seconds_exclusive`
- `interval_start_lower`
- `interval_start_upper_exclusive`
- `interval_end_lower`
- `interval_end_upper_exclusive`
- `interval_precision = history_ui_1min_start_6min_duration_truncation`

The canonical exact/detail `screen_on_duration_seconds` remains separate.

## 4. Eligibility prefilter from History list

Exact detail Scene screen-on duration remains authoritative:

- `<20 min` -> evidence only / excluded
- `20–30 min` -> provisional
- `>=30 min` -> main

The truncated History first duration can reduce unnecessary detail opening:

| History first value | Actual Scene screen-on range | Action |
|---|---|---|
| `0.0h–0.2h` | `<18 min` | definitely below 20 min; no detail needed for eligibility |
| `0.3h` | `18–<24 min` | crosses 20-min threshold; detail if classification matters |
| `0.4h` | `24–<30 min` | provisional range |
| `>=0.5h` | `>=30 min` | duration is main-eligible; detail still preferred for exact metrics/app attribution |

This table is a prefilter only. It does not replace detail evidence when exact duration is needed.

## 5. Ingestion / deduplication behavior

When the user uploads new Scene screenshots:

1. identify History rows and parse timestamp + both displayed durations
2. use History timestamp as the primary stable session-start identity
3. compare against existing canonical sessions
4. dedupe using multiple signals:
   - History start timestamp
   - average power
   - exact/detail screen-on duration when available
   - History wall-duration bucket when available
   - theoretical runtime
   - date / curve evidence
   - app distribution
5. never dedupe on average watts alone
6. append genuinely new sessions; do not arbitrarily rewrite old source records
7. preserve live/current observations outside finalized sessions until matched

If a screenshot date and the embedded History date differ, use the embedded History date for that History session and preserve capture date separately where relevant.

## 6. Detail metric precedence

### Screen-on duration

Priority:

1. exact detail `h/m/s` value
2. History first `x.xh` only as bounded/quantized evidence

### Wall duration

Priority:

1. direct exact value if a future trustworthy source exposes it
2. History second `x.xh` as 6-minute truncation bounds
3. blank if not captured

Never substitute theoretical runtime for wall duration.

### Average power

Use Scene's session/detail value. Current implementation semantics are screen-on workload-normalized average device power.

### Theoretical runtime

Use the Scene detail value as the canonical displayed estimate. It remains separate from wall duration and screen-on duration.

## 7. App attribution

Current Scene 9.3.8 groups per-app statistics by:

```text
package + Scene mode
```

The underlying query is restricted to valid screen-on discharge/not-charging samples and uses `count(current)` for duration attribution. The current app adapter converts that count using:

```text
duration_seconds = count × 3
```

Therefore current per-app duration semantics are:

```text
scene_valid_app_samples_3s
```

The same package may legitimately appear multiple times within one session under different Scene modes. **Do not merge those rows merely because their app label/package matches.**

Future `app_sessions.csv` should retain granular rows with at least:

- `session_id`
- `package_name` when available
- `app_label`
- `mode`
- `duration_seconds`
- `duration_semantics = scene_valid_app_samples_3s`
- `avg_power_w` when available
- `avg_current_ma` when available
- `avg_temp_c` when genuinely session-specific
- `max_temp_c`
- `source_ref`

Scene may show power or current depending on display settings; absent metrics remain blank rather than reconstructed.

Do not reverse-engineer historical per-session app rows from `app_summary.csv`. The old 436 deduped rows and their referenced `sync_raw/detail-*` source files were not retained as granular repository artifacts.

## 8. Context joining

Do not assign `home_wifi`, `mobile`, etc. from power level or app names.

Once MacroDroid context coverage is upgraded, join context against the best available session interval:

- exact interval if available
- bounded History interval if only History duration evidence exists
- `unknown` / partial when interval or context coverage is insufficient

`out_4g` from the current pilot remains non-authoritative because leaving home Wi-Fi does not prove mobile data.

## 9. Explicitly retired workflows

Do not reintroduce these as routine collection methods:

- `run-as` / private DB probing for the current installed package
- UIAutomator capture loops
- OCR
- force-stop / CLEAR_TASK recovery state machines
- background Runner `&`
- deep backlog recovery of the accepted 12 missing old rows

## 10. What the user needs to do going forward

For normal operation, the user only needs to upload new Scene screenshots.

The assistant should handle:

- parsing
- History precision bounds
- eligibility
- deduplication
- provisional/final reconciliation
- canonical append
- granular app-row retention for future genuine detail evidence
- rolling scene/workload statistics

The user should not be asked to restate old ledger history or re-upload already-ingested screenshots.
