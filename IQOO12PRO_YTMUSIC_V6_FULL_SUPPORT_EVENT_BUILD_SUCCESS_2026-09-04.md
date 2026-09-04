# iQOO 12 Pro / OriginOS 6 — YouTube Music V6 full support-event build success

Date: 2026-09-04

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_FULL_SUPPORT_EVENT_V6.apk`
- Run: `33828276334`
- Artifact: `9920752599`
- Artifact URL: `https://github.com/MeowGod8777/patched-apps/actions/runs/33828276334/artifacts/9920752599`
- APK SHA256: `eedf203d5ae81d140dc6aa6c560fa41b0affef2fa8333d6befe45278a1fe3fd6`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Functional delta over runtime-confirmed V5: only `vivomusicmix.media.metadata.support_event=0x9DF` at `Lii.m` framework MediaMetadata publication.

Verification PASS: V5 playable endpoint retained; Lid/Llag unchanged; PlaybackState sink byte-for-byte unchanged; ii.m delta exactly one support-event block; no trace instrumentation; v2/v3 signature; same signer; 16K zipalign; 21 stored arm64 libraries; package/version/manifest identity.
