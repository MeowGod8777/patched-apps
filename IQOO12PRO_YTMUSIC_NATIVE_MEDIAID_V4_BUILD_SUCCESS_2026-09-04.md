# iQOO 12 Pro / OriginOS 6 / YT Music OriginPlayer — native mediaId V4 build success — 2026-09-04

## Product goal
Fix patched YouTube Music OriginPlayer playlist on iQOO 12 Pro / OriginOS 6 so the real current/upcoming queue renders and tapping a row actually switches YT Music playback, without regressing the richer card title/metadata path.

## Candidate architecture
This candidate starts from the runtime-proven V2 real-queue bridge and replaces only the synthetic Browser media ID selection layer.

V2 synthesized:
`vivo_qid_<MediaSession QueueItem.b>`

V4 instead captures YT Music's native playable media ID before the Android QueueItem export loses it:

`Lnoq.m() queueId`
+ `Lazck.o() -> Lboht playback endpoint`
+ `Llgl.d(Lboht) -> native YT Music MediaBrowser mediaId`

and stores:

`Long queueId -> String nativeMediaId`

in a `ConcurrentHashMap` sidecar owned by `MusicBrowserService`.

The Vivo `vivomusicmix_current_list` rendering path keeps V2's already-proven QueueItem title/artist/artwork presentation but uses the sidecar native ID as `MediaDescriptionCompat.mediaId`.

Selection is therefore intentionally left to the untouched native YT Music transport:

`Vivo c0 playFromMediaId(nativeMediaId, extras)`
→ original `Lid.onPlayFromMediaId`
→ current `Lie/Llag.g`
→ `Laveu/Lavev`
→ `Llbg.a`
→ normal YT Music playback pipeline.

## Evidence/source checkpoint
Architecture decision recorded before candidate generation:
- `IQOO12PRO_YTMUSIC_NATIVE_MEDIAID_SELECTION_PLAN_2026-09-04.md`
- commit `fef3b899068c4603c0c4ae8b567168d718f69e76`

V4 patcher:
- `tools/ytmusic_vivo_c0_native_mediaid_v4.py`
- initial patcher commit `6d6bf55225d5cc49b5865f61ba2bd1ea010ceb20`
- retrigger commit `cdbe39d17cd290b27886af1dfc01d569ad7f52f8`

## CI build
Workflow:
`Build YT Music Luna Vivo c0 native mediaId v4`

Run:
`33819028726`

Artifact:
`9917601465`

Artifact name:
`ytmusic-luna-vivo-c0-native-mediaid-v4`

APK:
`YouTube_Music_9.15.51_Luna_VIVO_C0_NATIVE_MEDIAID_V4.apk`

APK SHA256:
`e2458ccb53d461d155f247b8864c220d8a4a13802977b57ef1e80fc354fba943`

Package/version:
- package `com.luna.music`
- versionName `9.15.51`
- versionCode `91551240`

Validated input base SHA256:
`0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`

Signer SHA256:
`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Signer verification:
- base = expected signer ✅
- BKS signing key = expected signer ✅
- output = expected signer ✅

APK signature:
- v2 scheme ✅
- v3 scheme ✅

Alignment/native libraries:
- rebuild ✅
- `zipalign -P 16` before sign ✅
- final `zipalign -c -P 16` after sign ✅ (`Verification successful`)
- arm64 `.so` count = 21 ✅
- all 21 arm64 `.so` are ZIP_STORED ✅

Manifest/static cooperation checks:
- `com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService` present ✅
- `com.vivo.musicwidgetmix.support.service` present ✅
- `vivomusicmix_current_list` branch present ✅
- `vivoNativeIds` sidecar present ✅
- `vivoCaptureNativeId(Lnoq)` present ✅
- `Lazck.o()Lboht` endpoint capture present ✅
- `Llgl.d(Lboht)String` native mediaId encoder present ✅
- browser current-list uses `vivoNativeId(queueId)` ✅

## Critical regression guards
These guards are the main reason this candidate is acceptable for runtime testing after V3/V3R1/V3S regressions.

### Framework callback adapter untouched
`smali_classes5/id.smali` before V4 patch:
`e91f11ccba6d38297a4df373cdb62534be3ae69765cc47c41ae08a4896bfe21f`

`smali_classes5/id.smali` after V4 patch:
`e91f11ccba6d38297a4df373cdb62534be3ae69765cc47c41ae08a4896bfe21f`

Byte-identical ✅

Therefore V4 does **not** carry the rejected V3S `onPlayFromMediaId -> onSkipToQueueItem` modification.

### Metadata sink untouched
Exact method:
`Lii.m(Landroid/support/v4/media/MediaMetadataCompat;)V`

Before/after files compare byte-identical ✅

Therefore V4 does **not** carry the rejected V3/V3R1 `vivomusicmix.media.metadata.support_event=0x10` mutation.

### Explicit forbidden markers
- synthetic `vivo_qid_` absent globally after V4 patch ✅
- `vivomusicmix.media.metadata.support_event` absent globally ✅

## Runtime test criteria
V4 passes the selection phase only if all are true:

1. OriginPlayer richer card song title remains normal, matching V2 baseline.
2. Playlist button opens.
3. Real queue renders with V2-equivalent title/artist behavior.
4. Tapping a row other than the current item actually switches YouTube Music playback to that item.
5. No new crash or persistent loading regression.

If selection works while initial elapsed/duration labels remain absent, V4 still counts as a selection PASS. Time labels are a separate unresolved path and must not be mixed back into this candidate.

## Time-label status
Still unresolved. Do not claim fixed.

The earlier `support_event=0x10` / `Lii.m()` experiment is rejected because it produced metadata regressions and only caused time to appear after manual seek dragging.

No time/metadata modification exists in V4.
