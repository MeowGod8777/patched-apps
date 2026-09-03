# iQOO 12 Pro / YT Music c0 real queue v2 — validated build

Date: 2026-09-03 (+08:00)

## Purpose

This candidate is the first real-queue render build after c0 browser probe v1 passed on-device.

It preserves the already device-validated cooperation transport and changes only the current-list payload source:

`static vivo_probe_1`
-> exact YT Music MediaSessionCompat queue captured at `Lii;->q(List)`
-> rebuilt Browser items with stable `vivo_qid_<queueId>` media IDs.

It deliberately does NOT implement `playFromMediaId` yet.

## Build provenance

- package: `com.luna.music`
- version: `9.15.51`
- candidate: `YouTube_Music_9.15.51_Luna_VIVO_C0_REAL_QUEUE_V2.apk`
- workflow run: `33762673544`
- workflow artifact: `9896185089`
- workflow head: `aaba0283b91ef69689eef9cc7f4c616ee592b794`
- artifact digest: `sha256:8513ff55bdba1ff6c2951d3929e406530993d7a89d6674924070350f110b07d9`
- APK size: `80203998` bytes
- APK SHA256: `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`

## Validation chain

All required delivery gates passed.

### Rebuild

Apktool rebuild: PASS.

### 16K zip alignment / native libraries

Final `zipalign -c -P 16 -v 4`: PASS (`Verification successful`).

arm64 native library count: `21`.

All 21 `lib/arm64-v8a/*.so` entries are `ZIP_STORED` (`compress_type = 0`).

### Signer

Validated base signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

BKS signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Output APK signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

APK signature verification:

- v2: PASS
- v3: PASS

### Manifest / static bridge verification

Verified in built APK / patched smali:

- `com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService` present
- `com.vivo.musicwidgetmix.support.service` present
- Vivo root special-case returns `VIVO_MUSIC_MIX_ROOT`
- `MusicBrowserService.vivoQueue:List` static capture field present
- `Lii;->q(List)` captures the exact incoming queue before original `ii.g` assignment / framework `MediaSession.setQueue` path continues
- current-list branch uses `MediaSessionCompat$QueueItem.b:J` as stable queue ID
- Browser media IDs use `vivo_qid_<decimal queueId>`
- title/subtitle/bitmap/iconUri/extras are copied from the original `MediaDescriptionCompat`
- Browser result is rebuilt as playable `MediaBrowserCompat.MediaItem` entries
- old `vivo_probe_1` static item is absent

## Device test scope

This is a render-only real-queue candidate.

Expected PASS behavior:

`OriginPlayer -> 播放列表`
-> multiple real YT Music queue rows render
-> row title / artist match the current YT Music queue
-> no `YT Music Vivo Bridge / c0 cooperation probe` static row
-> no crash

Do NOT require tapping a row to switch tracks in this phase. `playFromMediaId` is intentionally not implemented yet.

If real rows render, the next isolated phase is selection transport:

`playFromMediaId("vivo_qid_<queueId>", {vivomusicmix_key_list=vivomusicmix_current_list})`
-> parse queueId
-> map to the corresponding MediaSession queue item / playback command.

Do not change the now-proven c0 browse/render transport while implementing selection.

## Separate issue

OriginPlayer elapsed/duration numeric time labels are currently absent in the user's screenshots and appear to predate this real-queue candidate. Keep that as a separate presentation investigation; do not mix it into the playlist bridge experiment.