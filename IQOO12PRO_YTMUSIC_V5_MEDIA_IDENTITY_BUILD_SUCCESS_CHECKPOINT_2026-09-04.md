# iQOO 12 Pro / OriginOS 6 — YT Music V5 media-identity build-success checkpoint

Date: 2026-09-04

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_V5_MEDIA_IDENTITY.apk`
- Workflow: `Build YT Music V5 Vivo media identity`
- Run: `33832184688`
- Artifact: `9922079285`
- Artifact URL: `https://github.com/MeowGod8777/patched-apps/actions/runs/33832184688/artifacts/9922079285`
- APK SHA256: `547d7b1d31a68e32d273a770e4575f50fef6948246f984ae5d310ad0195b8427`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

## Functional delta over V5 + 0x9DF

Official Luna identity join is verified: current-list MediaItem ID, selection ID and metadata MEDIA_ID all use the same playable ID.

This candidate observes the already-published PlaybackState activeQueueId, resolves it through the existing V5 `vivoNativeIds` sidecar, and publishes only the matching `android.media.metadata.MEDIA_ID` at the framework metadata builder. TITLE/ARTIST/DURATION/position are not fabricated or altered.

## Mandatory verification

- exact validated base: PASS
- V5 n()->Lazmi.b playable selection: PASS
- rejected o()/p() endpoints absent: PASS
- Lid byte-for-byte unchanged: PASS
- Llag byte-for-byte unchanged: PASS
- support_event=0x9DF retained: PASS
- activeQueueId -> vivoNativeIds -> MEDIA_ID identity guard: PASS
- v2/v3 signatures: PASS
- signer identical: PASS
- zipalign -P16: PASS
- 21 arm64 libraries stored: PASS
- package/version/manifest: PASS
