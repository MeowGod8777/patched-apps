# Canonical battery ledger (current)

This directory is the **single current working dataset** for iQOO 12 Pro battery tracking.

Everything under `generated/YYYY-MM-DD/` is an immutable dated ingestion snapshot. Everything under `canonical/` is the latest curated state used for ongoing comparisons.

Current canonical state:

- finalized Scene History sessions: 41
- provisional live snapshot groups: kept outside the finalized ledger
- intentionally uncaptured old eligible History rows: 12, documented in `generated/2026-09-05/accepted_missing_backlog.csv`
- one known partial app-attribution session: `2026-07-23 20:53`
- first valid MacroDroid context transition: `2026-09-05T12:40:43+08:00`

Files:

- `session_ledger.csv` — finalized session-level source of truth.
- `app_summary.csv` — current accumulated app-duration / weighted-power summary from finalized sessions.
- `context_timeline.csv` — normalized MacroDroid network-context timeline.

Rules:

1. Do not insert live/current Scene screenshots directly into `session_ledger.csv` as finalized rows. They remain provisional until matched to a finalized History session or explicitly retained as snapshot-only evidence.
2. Scene History timestamp is the preferred session identity.
3. Exact detail `screen_on_duration` determines eligibility: `<20m` excluded, `20–30m` provisional, `>=30m` main.
4. Network / scene context is assigned only when MacroDroid timeline coverage is sufficient; otherwise use `unknown`.
5. Do not infer historical battery temperature/voltage/capacity from the current ActivityPowerUtilization header.
6. Old raw/invalid evidence is never deleted merely because a later capture supersedes it.
