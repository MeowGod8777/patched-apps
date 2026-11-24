# OriginPlayer historical pre-closeout video — 2026-09-04

Historical attachment `2026_09_04_09_05_54.mp4` (47,690,770 bytes, H.264 1440×3200, 44.818644 s). Re-reviewed 2026-11-24; historical evidence, not a new device test. Exact APK identity of this recording is **UNKNOWN**, and the date alone cannot identify the build.

## Observed behavior

Frames sampled at 2, 8, 14, 20, 26, 32, 38 and 43 seconds:
- App media library and active media row are visible at 8 s.
- OriginPlayer floating card appears at 14 s, with artwork, title/artist and playback controls; queue interface appears at 20 and 26 s and contains multiple title/artist rows.
- At 32 s, card is visible again. Time labels are not legible/confirmed in sampled frames; do not infer progress capability or a specific failure from missing labels alone.
- At 38 s, a trace text file is visible in the UI. At 43 s, the notification shade shows two media surfaces, one with artwork and controls and the other with explicit title/artist. This is not enough to establish the same active playable identity across all surfaces.
- No independent proof from these sampled frames of exact row-selection behavior, metadata API values, patch revision, or a complete feature PASS.

## Relation to the existing closeout

The existing [runtime success report](../IQOO12PRO_YTMUSIC_V5_MEDIA_IDENTITY_RUNTIME_SUCCESS_2026-09-04.md) and [status](../IQOO12PRO_PATCH_STATUS.zh-TW.md) establish the final known-good build independently, including real queue, row selection, title/artist, artwork and advancing timing. Its SHA-256 is `547d7b1d31a68e32d273a770e4575f50fef6948246f984ae5d310ad0195b8427`. The earlier recording is a historical UI demonstration of intermediate behavior, not the only final success evidence. Do not replace the actual runtime report with this video, or assert it was the final APK.

The useful observations, uncertainty and link to final conclusion are retained here. The historical UI recording can be discarded under the purpose-based Library policy without discarding the final APK or unique underlying trace. No raw frames, notification contents, account data, or proprietary binaries are included. No changes to the application, current status, or existing PRs.
