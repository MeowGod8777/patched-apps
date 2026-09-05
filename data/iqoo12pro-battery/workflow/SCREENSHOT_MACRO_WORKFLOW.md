# Screenshot + MacroDroid workflow — SUPERSEDED

Status: **legacy workflow retained for provenance only**

This document described the first screenshot/MacroDroid pilot. It is no longer the production operating procedure.

Current authoritative workflow documents:

1. `../docs/ARCHITECTURE_V1_FINAL.md`
2. `../docs/SCREENSHOT_INGESTION_V1.md`
3. `../docs/MACRODROID_CONTEXT_V2.md`
4. `../docs/SCENE_CURRENT_APK_RE_2026-09-05.md`

## Retired assumptions

Do not continue the following pilot behavior:

- do not capture only when a current Scene session merely “looks worth recording”;
- do not treat a current/live screenshot as a finalized session;
- do not use `leave home SSID -> out_4g` as a network classifier;
- do not interpret legacy `out_4g` as confirmed mobile data;
- do not use UIAutomator/OCR/private-DB probing for routine collection.

## Current Scene capture rule

Use periodic recent-History coverage with overlap so unseen sessions are not cherry-picked or silently missed. History rows provide start identity and both duration buckets. Open detail primarily for new main-eligible rows (`History first duration >= 0.5h`) or when exact/provisional/app evidence is specifically needed.

Exact rules and 6-minute History quantization bounds are defined in `../docs/SCREENSHOT_INGESTION_V1.md`.

## Current MacroDroid rule

The old `home_wifi / out_4g` pilot is superseded by four-state context v2:

```text
home_wifi
other_wifi
mobile
unknown
```

plus an hourly coverage heartbeat.

The v2 design, classifier precedence, event schema, and legacy normalization rules are defined in `../docs/MACRODROID_CONTEXT_V2.md`.

## Preserved legacy evidence

The old device file and canonical pilot timeline remain provenance sources and are not rewritten in place. Valid pilot rows are normalized into `../canonical/context_events.csv`; legacy `out_4g` rows become `unknown` unless independently confirmed as mobile.
