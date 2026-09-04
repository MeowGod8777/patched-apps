# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 state-probe build success

Date: 2026-09-04

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_V5_STATE_PROBE.apk`
- Run: `33827643700`
- Artifact: `9920549090`
- APK SHA256: `4bf2dd1a7f03b22dcf70ae989e4f24b0a25385ff7b90470f3d6e4d23cea54f29`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Observation only: `YTM_V5STATE` logs SELECT, MediaSession META (title/artist/duration/support_event), and PlaybackState STATE (state/position/speed/updateTime/activeQueueId).

Verification PASS: V5 playable endpoint retained; Lid unchanged; no queueId parser; no functional support_event write; no V4N trace; v2/v3 signer verification; 16K zipalign; 21 stored arm64 libraries; package/version/manifest identity.

This is not a functional V6. V5 selection-success behavior remains the regression invariant.
