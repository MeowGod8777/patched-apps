# iQOO 12 Pro / YT Music c0 v3 selection + time — validated build

Date: 2026-09-03 (+08:00)

## Candidate scope

This is the combined v3 candidate requested after v2 real-queue render passed on-device.

It preserves the device-validated v2 browse/render path and adds both:

1. `vivo_qid_<queueId>` selection -> exact YT Music `Lie.t(queueId)` queue transport;
2. Vivo `SEEK_POSITION` support capability (`0x10`) in `vivomusicmix.media.metadata.support_event` while preserving standard duration/playback-state timing data.

## Build provenance

- package: `com.luna.music`
- version: `9.15.51`
- candidate: `YouTube_Music_9.15.51_Luna_VIVO_C0_V3_SELECTION_TIME.apk`
- workflow run: `33766401837`
- workflow artifact: `9897713411`
- workflow head: `7bc0da9aa0cced8c6c660183cc208efe2568c92b`
- artifact digest: `sha256:7c9c6132141bddc0e712d7caea99bc23d8dc7b0de4723eaa5de95724edd2ef7b`
- APK SHA256: `b5448d0da3b99b6ffe91a1fca36b12b52bc176e47f3b456469e5b3533e103df0`

## Validation chain

### Build / alignment

- Apktool rebuild: PASS
- final `zipalign -c -P 16 -v 4`: PASS (`Verification successful`)
- arm64 native `.so` count: 21
- all arm64 native entries: `ZIP_STORED`

### Signer

Validated base signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

BKS signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Output signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

APK signature:
- v2 PASS
- v3 PASS

### Static v2 invariants retained

- `com.vivo.musicwidgetmix.support.service` present
- `VIVO_MUSIC_MIX_ROOT` present
- real queue capture remains present
- `vivo_qid_<queueId>` browser items remain present
- no regression to static probe list

### Static v3 selection verification

`Lid.onPlayFromMediaId(String, Bundle)` now special-cases generated IDs:

```text
startsWith("vivo_qid_")
-> substring(9)
-> Long.parseLong(...)
-> Lid.a() -> Lii
-> Lid.c(...)
-> Lie.t(queueId)
-> Lid.b(...)
-> return
```

Non-Vivo media IDs fall through to the original YT Music `Lie.g(mediaId, extras)` logic.

This exactly reuses YT Music's existing `onSkipToQueueItem` queue-selection transport.

### Static v3 timing verification

Before `Lii.m(MediaMetadataCompat)` converts metadata to framework `MediaMetadata`, v3 now:

```text
existing = bundle.getLong("vivomusicmix.media.metadata.support_event")
bundle.putLong(
  "vivomusicmix.media.metadata.support_event",
  existing | 0x10
)
```

`0x10` is official Luna/Vivo `EVENT_TYPE_SEEK_POSITION`.

YT Music's standard `android.media.metadata.DURATION` and PlaybackState position/speed/update-time paths are otherwise unchanged.

## Device validation status

Selection transport has strong static confidence because it calls the exact existing YT Music queue command with the queue ID captured from the same MediaSession queue.

Time-label repair remains an on-device hypothesis until tested:

- standard duration/position data paths already exist in YT Music;
- official Luna explicitly publishes Vivo support-event capabilities;
- patched YT Music previously lacked the Vivo `SEEK_POSITION` capability;
- v3 adds that exact capability without faking time strings.

Expected device PASS:

1. tapping a different row in OriginPlayer playlist switches actual YT Music playback to that row;
2. elapsed/duration labels become numeric instead of `--:--` while progress remains coherent.

If item selection passes but time labels remain `--:--`, retain the selection patch and continue c0-specific timing RE; do not regress the now-proven browse/render path.