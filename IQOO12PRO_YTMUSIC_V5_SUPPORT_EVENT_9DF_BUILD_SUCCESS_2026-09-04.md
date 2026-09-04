# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 + support-event 0x9DF build success

Date: 2026-09-04

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_V5_SUPPORT_EVENT_9DF.apk`
- Run: `33828478558`
- Artifact: `9920818175`
- APK SHA256: `b41e8114f737b8ef7130e37640e58ca7feb216064ee905e5d647a576ef3ca9ea`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Functional delta over exact V5: only `vivomusicmix.media.metadata.support_event=0x9DF` at the final framework MediaMetadata publication boundary.

V5 playable endpoint selection retained; Lid unchanged; rejected queueId parser absent; standard TITLE/ARTIST/DURATION and PlaybackState untouched; no trace instrumentation; v2/v3 signature verification PASS; 16K zipalign PASS; 21 stored arm64 libraries PASS; package/version/manifest identity PASS.
