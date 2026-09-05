# iQOO 12 Pro Battery Ledger

Long-term natural-usage battery ledger for iQOO 12 Pro / V2329A using Scene (`com.omarea.vtools`) battery statistics.

## START HERE

Routine operation is now **screenshot-first**. Do not run the old Scene UIAutomator backlog/recent scripts for normal daily logging.

- Current canonical data: `canonical/`
- Routine operating procedure: `workflow/SCREENSHOT_MACRO_WORKFLOW.md`
- Dated immutable ingestion snapshots: `generated/YYYY-MM-DD/`
- Old `capture_*`, `full_sync_*`, probe/audit scripts at this directory level are forensic/backlog tooling only.

## Measurement model

- This is **not** a fixed-workload laboratory benchmark.
- Scene `理论续航` / theoretical runtime is a **workload-normalized endurance indicator**, not pure screen-on time.
- Scene `已使用` is not assumed to equal pure SOT.
- A discharge session does not need to start at 100% or end at 0%.
- Scene History timestamp is the preferred session identity.
- Network changes are context/segments inside a Scene session, not independent battery sessions.
- Live/current screenshots are provisional until matched to a finalized History session or explicitly retained as snapshot-only evidence.

## Primary scene classes

- `home_wifi`: connected through one of the user's home Wi-Fi networks.
- `out_4g`: cellular-use segment outside the home-Wi-Fi context.
- `mixed`: materially significant `home_wifi` + `out_4g` within one Scene session.
- `unknown`: fallback when transport/context cannot be determined reliably.

`navigation` is a modifier rather than a top-level scene class.

## Data layout

### `canonical/`
The single current working dataset.

- `session_ledger.csv`: finalized Scene History sessions only.
- `app_summary.csv`: current app-duration / weighted-power summary.
- `context_timeline.csv`: normalized MacroDroid context timeline.

### `generated/YYYY-MM-DD/`
Immutable dated ingestion snapshots, reports, corrections, provisional snapshots and accepted gaps.

### `baseline.csv`
Confirmed historical/context records supplied before automation.

### Device-side raw evidence
Raw Scene captures / invalid diagnostics / MacroDroid timeline remain immutable on-device or in uploaded ingestion artifacts. Canonical outputs are derived from them rather than replacing them.

## Eligibility rule

Canonical eligibility is based on exact Scene detail `screen_on_duration`, not rounded History summary text:

- `< 20 min`: retained evidence, excluded from primary ledger.
- `20–30 min`: provisional / reviewable.
- `>= 30 min`: main ledger.

## Duplicate/session rule

Do not deduplicate on average watts alone. Prefer Scene History timestamp/session identity. Otherwise consider history date/time, exact used time, theoretical runtime and app-duration progression. Multiple screenshots of one ongoing session remain one session.

## 2026-09-05 audited baseline state

- finalized Scene History detail sessions: **41**
- intentionally uncaptured old eligible History rows: **12**
- provisional live snapshot group: **1** (`2026-09-05-live-01`), not counted as a finalized canonical session
- one known partial app-attribution finalized session: `2026-07-23 20:53` (56.9% app-duration coverage)
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

Important correction: Scene `ActivityPowerUtilization` battery capacity/status/voltage/temperature header values are current-page `GlobalStatus` values. They must not be attached to an old History session merely because they are visible while opening that historical detail.

## Routine workflow

MacroDroid continuously records `home_wifi` / `out_4g` transitions to:

`/sdcard/SceneBattery/network_timeline_md.csv`

The user normally only sends Scene screenshots. Periodically, a recent History screenshot is used to finalize/deduplicate stable session IDs, and the MacroDroid CSV is uploaded to supply network context. No Runner command is required for routine logging.

See `workflow/SCREENSHOT_MACRO_WORKFLOW.md` for the exact sequence.

## Legacy automation

The deep backlog was a one-time recovery exercise. Scene repeatedly became unstable under UIAutomator, including attribution collapse and backend/UI state failures. Those scripts remain preserved for forensic recovery but are not the production workflow.
