# iQOO 12 Pro / YT Music c0 V3R1 — validated build

Date: 2026-09-03 (+08:00)

## Purpose

V3R1 combines the two remaining user-visible gaps after V2 real-queue render passed on-device:

1. tap a Vivo c0 playlist row and switch YT Music to that exact queue item;
2. restore OriginPlayer numeric elapsed/duration capability without replacing YT Music's standard timing model.

It reuses the device-validated V2 c0/root/real-queue patch unchanged and adds only:

- `vivo_qid_<queueId>` selection -> YT Music's native `onSkipToQueueItem(queueId)` path;
- Vivo cooperation metadata `vivomusicmix.media.metadata.support_event = 0x10` (`SEEK_POSITION`).

## Provenance

- package: `com.luna.music`
- version: `9.15.51`
- candidate: `YouTube_Music_9.15.51_Luna_VIVO_C0_SELECTION_TIME_V3R1.apk`
- workflow: `.github/workflows/build-ytmusic-luna-vivo-c0-selection-time-v3r1.yml`
- workflow run: `33766518367`
- job: `100685687204`
- workflow head: `440a129f63b2f14ed589f74bebe16a1ce88c7021`
- workflow artifact: `9897773372`
- artifact digest: `sha256:969e83f834785ad9ab288529e8d1712588ed132620dada22cc15fbdf9493d48c`
- APK size: `80203998` bytes
- APK SHA256: `7cdebd4821c12f634f1230ca50c91784d388f9aaf39b4b0613aec14c39101d88`

## Validation chain

All delivery gates passed.

### Rebuild / alignment

- Apktool rebuild: PASS
- final `zipalign -c -P 16 -v 4`: PASS (`Verification successful`)
- arm64 native libraries: exactly `21`
- all `lib/arm64-v8a/*.so` entries are `ZIP_STORED`

### Signer / APK signatures

Validated base signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

BKS signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Output signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

- APK Signature Scheme v2: PASS
- APK Signature Scheme v3: PASS

### Package / manifest / c0 bridge

- package `com.luna.music`
- versionName `9.15.51`
- `com.vivo.musicwidgetmix.support.service` present
- existing `MusicBrowserService` present
- V2 `VIVO_MUSIC_MIX_ROOT` / real queue / `vivoQueue` / `vivo_qid_` path preserved
- static probe item remains absent

### Selection delta

Static output confirms `Lid;->onPlayFromMediaId` contains:

- prefix `vivo_qid_`
- `Long.parseLong(String)`
- `Lid;->onSkipToQueueItem(J)V`

All other media IDs retain the original YT Music path.

### Timing delta

YT Music's own standard `android.media.metadata.DURATION` and PlaybackState position/speed/updateTime are left intact.

V3R1 adds only:

`vivomusicmix.media.metadata.support_event = 0x10`

via a framework `MediaMetadata.Builder(existingMetadata)` copy.

Crucially, the first V3 build was rejected before delivery because the support-event block was placed before the `:cond_c` convergence label and could be bypassed when framework metadata was already materialized.

V3R1 explicitly validates corrected placement:

```text
cond_c=7026 support_event=7329 original_get=7776
PASS: support_event executes on both metadata materialization paths
```

Therefore:

`:cond_c < support_event injection < original framework metadata extraction`

and both metadata paths execute the Vivo capability injection.

## Device test target

Install over V2 and verify together:

1. OriginPlayer playlist still renders the real current queue.
2. Tap a clearly different playlist row; playback should switch to that exact track.
3. OriginPlayer elapsed/duration labels should become numeric instead of `--:--` and progress should track playback.
4. Existing artwork/title/artist/previous/play-pause/next must remain functional.

Interpretation rules:

- selection PASS + time PASS -> combined playlist functionality effectively complete;
- selection PASS + time FAIL -> keep selection; falsify `SEEK_POSITION 0x10 alone is sufficient` and inspect Vivo c0 metadata-consumer conditions next;
- selection FAIL with no YT callback evidence -> investigate whether Vivo requires `PLAY_INDEX (0x800)` support capability before dispatching list-row selection; do not add it without runtime evidence.
