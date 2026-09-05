# Screenshot + MacroDroid workflow

This is the routine operating procedure. It deliberately avoids Scene UIAutomator for normal daily logging.

## Goal

The user should normally do only two things:

1. take/send Scene screenshots when a battery sample is worth keeping;
2. occasionally upload the MacroDroid context CSV.

Everything else (dedupe, eligibility, session matching, scene classification, ledger update, statistics) is done during ingestion.

## What MacroDroid is for

MacroDroid does **not** capture Scene battery metrics. Its only job is to keep an independent environment timeline so the user does not need to remember or manually type whether a sample was home Wi-Fi or cellular.

Current automatic events:

- connect to any home SSID -> append `timestamp,home_wifi,SSID`
- leave all home SSIDs for 30 seconds -> append `timestamp,out_4g,`

File on device:

`/sdcard/SceneBattery/network_timeline_md.csv`

The timeline is later intersected with Scene History timestamps. If coverage is incomplete, the ledger stays `unknown`; no scene is guessed.

Navigation is intentionally **not** automated yet. Until a robust Maps-navigation signal is designed, `navigation` is supplied by obvious screenshot/app evidence or user note and otherwise left unknown.

## Normal capture: one screenshot is enough

When a current Scene session looks worth recording:

1. Open Scene -> 耗电统计.
2. Take a screenshot that includes, if visible: average power, used time, theoretical runtime and app list.
3. Send the screenshot in chat. No Runner command is required.

The screenshot filename/capture time is retained as `capture_at`. A current/live screenshot is provisional, not automatically treated as a finalized History session.

If Scene supports a useful long screenshot, it is preferred because it improves app attribution. If not, a normal screenshot is still accepted and app attribution can be marked partial.

## Finalizing / deduplicating

When convenient (not every day), send one screenshot of Scene -> 历史记录 containing the recent rows.

That History screenshot provides stable timestamps used as session IDs. The ingestion step matches earlier current screenshots to finalized History rows using timestamp/date plus power, used time, theoretical runtime and app progression.

This prevents repeated snapshots of one ongoing session from becoming duplicate ledger rows.

## Context handoff

About once every 1–2 weeks, or whenever several new screenshots have accumulated, upload this one file:

`/sdcard/SceneBattery/network_timeline_md.csv`

No tar, shell script or Scene automation is required.

Ingestion then:

1. parses new screenshots;
2. reconciles them with recent History rows when available;
3. applies exact eligibility (`<20m` excluded, `20–30m` provisional, `>=30m` main);
4. deduplicates repeated snapshots;
5. intersects the MacroDroid timeline where coverage exists;
6. appends finalized rows to `canonical/session_ledger.csv`;
7. updates `canonical/app_summary.csv` and `canonical/context_timeline.csv`;
8. preserves dated evidence under `generated/YYYY-MM-DD/`.

## What the user does not need to do

- no routine `capture_backlog_*` or `capture_recent_*` execution;
- no repeated Runner retries because Scene labels/backend failed;
- no manual Wi-Fi/4G annotation when MacroDroid coverage exists;
- no manual dedupe;
- no need to start or end a session at 100% / 0%.

## Data-state meanings

- `provisional_live_snapshot`: current Scene screenshot, not yet tied to a finalized History ID.
- `finalized`: matched to a stable History timestamp and eligible for the canonical ledger.
- `partial_app_attribution`: session metrics are valid but the screenshot/app list is incomplete.
- `unknown` context: MacroDroid coverage is insufficient; do not guess.

## Recovery / fallback

The old UIAutomator scripts remain only as forensic/backlog tools. They are not part of the normal workflow. Use them only if a large historical gap must be recovered and the expected value justifies the instability.
