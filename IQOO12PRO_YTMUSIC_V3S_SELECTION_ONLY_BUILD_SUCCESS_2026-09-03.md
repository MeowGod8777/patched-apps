# iQOO 12 Pro YT Music Vivo c0 V3S selection-only build success — 2026-09-03

## Purpose
Recover from V3R1 runtime regression by returning to the proven V2 c0/root/real-queue bridge and adding only queue-item selection. No timing metadata mutation is present.

## Candidate
- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_SELECTION_V3S.apk`
- package: `com.luna.music`
- version: `9.15.51`
- workflow run: `33767682476`
- artifact: `9898283280`
- APK SHA256: `1cdeea400e6b2d8233ecaca15864c2397736ba82f888311995a9a9a75c2e3645`
- signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

## Patch delta relative to runtime-PASS V2
Only:
`vivo_qid_<queueId>` -> parse long queueId -> `Lid;->onSkipToQueueItem(J)V` -> existing YT Music `Lie.t(long)` path.

Not present:
- `vivomusicmix.media.metadata.support_event`
- V3/V3R1 `ii.m(MediaMetadataCompat)` mutation
- synthetic duration/position

## Validation
PASS:
- exact validated Luna base download
- V2 c0/root/real-queue patch
- selection hook static markers
- forbidden timing-key regression guard
- Apktool rebuild
- `zipalign -P 16`
- APK Signature Scheme v2 = true
- APK Signature Scheme v3 = true
- signer matches validated base
- 21 arm64-v8a `.so` files, all ZIP_STORED
- package `com.luna.music`
- version `9.15.51`
- manifest contains `com.vivo.musicwidgetmix.support.service`

## Runtime test requested
1. Notification/OriginPlayer song title remains normal as in V2.
2. Playlist opens and renders the real queue as in V2.
3. Tap a non-current queue item and verify the player switches to that item.

Timing remains intentionally unfixed in this candidate. The time path will be investigated separately after selection is proven without regressing V2.
