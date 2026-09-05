# iQOO 12 Pro Battery Ledger

Long-term natural-usage battery ledger for iQOO 12 Pro / V2329A using Scene (`com.omarea.vtools`) battery statistics.

## Measurement model

- This is **not** a fixed-workload laboratory benchmark.
- Scene `理论续航` / theoretical runtime is a **workload-normalized endurance indicator**, not pure screen-on time.
- Scene `已使用` is not assumed to equal pure SOT.
- A discharge session does not need to start at 100% or end at 0%.
- Scene History timestamp is the preferred session identity.
- Network changes are context/segments inside a Scene session, not independent battery sessions.
- Live `today HH:MM:SS` rows and intermediate snapshots are provisional; they are never finalized merely because W/runtime values look unique.

## Primary scene classes

- `home_wifi`: connected through one of the user's home Wi-Fi networks.
- `out_4g`: cellular-use segment outside the home-Wi-Fi context; malls, restaurants and ordinary outdoor use are intentionally grouped together.
- `mixed`: a Scene session containing materially significant time in both `home_wifi` and `out_4g`.
- `unknown`: fallback when transport/context cannot be determined reliably.

`navigation` is a modifier rather than a top-level scene class.

## Data layers

- `baseline.csv`: confirmed historical/context records supplied before automation.
- raw device evidence: immutable Scene detail captures, invalid diagnostics and MacroDroid network timeline.
- `generated/`: canonical/session summaries derived without deleting or mutating raw evidence.

## Eligibility rule

Canonical eligibility is based on exact detail `screen_on_duration`, not the rounded History list:

- `< 20 min`: retained raw, excluded from primary ledger.
- `20–30 min`: provisional / reviewable.
- `>= 30 min`: main ledger.

Acquisition may use a lower rounded-History prefilter to avoid losing boundary samples; final classification always uses exact detail time.

## Duplicate/session rule

Do not deduplicate on average watts alone. Prefer Scene History timestamp/session identity. Otherwise consider history date/time, exact used time, theoretical runtime and app-duration progression. A later snapshot with longer used time and continuing app counters is normally the same session.

## 2026-09-05 canonical ingestion

Stored under `generated/2026-09-05/`.

- `session_ledger.csv`: **41 finalized Scene History detail sessions**.
- `app_summary.csv`: accumulated app-duration and duration-weighted app power from the finalized automated set.
- `network_timeline_normalized.csv`: MacroDroid transitions with invalid placeholder timestamps marked.
- `live_snapshots.csv`: provisional observations of the ongoing 2026-09-05 outdoor 4G/navigation session; excluded from finalized statistics.
- `accepted_missing_backlog.csv`: 12 older eligible History rows intentionally left uncaptured after acquisition was stopped.
- `CORRECTIONS_V2.md`: audit corrections to the first ingestion interpretation.
- `INGESTION_REPORT.md`: provenance, quality checks, network coverage limits and descriptive statistics.

Important quality notes:

- `sync_manifest.csv` is append-only and latest state is authoritative; old all-`Scene` / unresolved captures are excluded when a later healthy capture exists.
- All 41 finalized captured sessions have exact `screen_on_duration >= 30 min`.
- `2026-07-23 20:53` has only 56.9% app-duration coverage; session power/runtime remain usable but app breakdown is partial.
- MacroDroid's first valid transition is 2026-09-05 12:40:43 +08:00, later than all 41 finalized History sessions in the archive; historical transport is not inferred from missing timeline coverage.
- Scene `ActivityPowerUtilization` battery capacity/status/voltage/temperature fields are **current-page `GlobalStatus` values**, not historical-session attributes. Do not attach them to an older History timestamp merely because they appear in a detail-page UI dump.

## Ongoing incremental workflow

Do **not** use the deep backlog drainer for routine operation.

1. MacroDroid continuously appends `home_wifi` / `out_4g` transitions to `/sdcard/SceneBattery/network_timeline_md.csv`.
2. Once per day or every 1–2 days, use `capture_recent_v3.sh` from Shizuku Runner with Scene in the foreground. It scans only the recent window and captures at most two new sessions per run.
3. `capture_recent_v3.sh` deliberately does not normalize to the top just to capture battery header values, because those fields are current state rather than historical-session state.
4. It uses a 15-minute rounded-History acquisition prefilter so potential 20–30 minute samples are not lost; canonical ingestion later applies the exact `<20 / 20–30 / >=30` rule.
5. Periodically export `sync_manifest.csv`, `sync_raw/`, `sync_raw_invalid/`, and `network_timeline_md.csv` for canonical ingestion/GitHub update.

Current limitation: Scene UI/backend can become unhealthy under repeated UIAutomator interaction. Incremental runs are intentionally shallow. A label/backend failure must not be accepted as valid; reopen Scene and retry later.

## Full-auto research path

Scene source uses a private SQLite history database (`battery-history3` in the referenced source tree). If the installed Scene build is debuggable and `run-as com.omarea.vtools` can access its private files, future capture can bypass UIAutomator and export/query the database directly. This must be verified on the actual installed APK before treating DB export as available.
