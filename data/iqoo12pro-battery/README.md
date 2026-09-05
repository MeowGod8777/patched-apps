# iQOO 12 Pro Battery Ledger

Long-term natural-usage battery ledger for iQOO 12 Pro / V2329A using Scene (`com.omarea.vtools`) battery statistics.

## Measurement model

- This is **not** a fixed-workload laboratory benchmark.
- Scene `理论续航` / theoretical runtime is treated as a **workload-normalized endurance indicator**, not pure screen-on time.
- Scene `已使用` is not assumed to equal pure SOT.
- A discharge session does not need to start at 100% or end at 0%.
- Scene History is preferred as the session source of truth when a stable history timestamp is available.
- Network changes are analysis segments/context inside a Scene session, not independent battery sessions.

## Primary scene classes

- `home_wifi`: connected through one of the user's home Wi-Fi networks.
- `out_4g`: cellular-use segment outside the home-Wi-Fi context; malls, restaurants and ordinary outdoor use are intentionally grouped together.
- `mixed`: a Scene session containing materially significant time in both `home_wifi` and `out_4g`.
- `unknown`: fallback only when transport/context cannot be determined reliably.

`navigation` is a modifier rather than a third top-level scene class.

## Data layers

- `baseline.csv`: confirmed historical records supplied by the user before automation.
- `raw/`: immutable automated evidence. Raw network timelines and Scene History captures are preserved even if excluded from statistics.
- Generated session/segment ledgers must deduplicate / merge raw evidence without deleting it.

## Eligibility rule (provisional v0)

Scene History records are ingested first, then filtered deterministically:

- `< 20 min` Scene `已使用`: retained raw, excluded from the primary endurance ledger.
- `20–30 min`: provisional / reviewable sample.
- `>= 30 min`: eligible for the primary ledger.

These thresholds are intentionally reversible because raw data is retained.

## Duplicate/session rule

Do not deduplicate on average watts alone. Prefer Scene History timestamp/session identity when available. Otherwise consider timestamp/history date, Scene `已使用`, theoretical runtime, battery level, app-duration distribution and monotonic progression. A later snapshot with longer `已使用` and mostly-continuing app counters is normally the same session, not a new record.

## v0 pilot

The pilot deliberately separates collection from interpretation:

1. `network_watch_v0.sh` records only transport-state changes at low frequency/overhead.
2. `history_capture_v0.sh` captures Scene History UI data with automatic scrolling while preserving raw node lines.
3. GitHub ingestion / generated ledgers will be layered on after the raw format and OEM network reporting are validated on-device.

This avoids losing evidence while the first real-world bugs are still being discovered.

## 2026-09-05 ingestion snapshot

The first canonical ingestion is stored under `generated/2026-09-05/`.

- `session_ledger.csv`: 41 valid automated Scene History detail captures plus one unmatched baseline-only 2026-09-05 sample.
- `app_summary.csv`: accumulated app-duration and duration-weighted app power summary from the automated detail set.
- `network_timeline_normalized.csv`: MacroDroid network transitions with invalid placeholder timestamps explicitly marked.
- `INGESTION_REPORT.md`: provenance, quality checks, scene/network coverage limits, and descriptive statistics.

Important quality notes for this snapshot:

- `sync_manifest.csv` is append-only and latest state is authoritative; old all-`Scene` / unresolved captures are excluded if a later healthy capture exists.
- All 41 automated canonical detail sessions have exact `screen_on_duration >= 30 min`.
- `2026-07-23 20:53` has only 56.9% app-duration coverage, so its session-level power/runtime remain usable but its app breakdown is flagged partial.
- MacroDroid's first valid transition is 2026-09-05 12:40:43 +08:00, later than all finalized automated History sessions in this archive; no transport class is inferred from missing timeline coverage.
