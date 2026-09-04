# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 metadata/timing static result

Date: 2026-09-04

## Input identity

- V2 exact runtime artifact: `9896185089`
- V2 APK SHA256: `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`
- V5 exact runtime artifact: `9919920481`
- V5 APK SHA256: `5f8d786b794f96049911323ecba6f7e68d0cd2133e2a11dfcf8bff151c25c02a`
- Static workflow: `Inspect YT Music V5 OriginPlayer metadata timing`
- Run: `33826784117`
- Artifact: `9920278906`
- Artifact digest: `sha256:370d9121b9c30535dfff410da312426478bed6d9085a02aafa61df71850820df`
- Runtime selection-success checkpoint: `IQOO12PRO_YTMUSIC_V5_RUNTIME_SELECTION_SUCCESS_2026-09-04.md`

## VERIFIED exact V2 -> V5 diff

Only two smali classes differ between the exact runtime-tested V2 and V5 APKs:

1. `com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali`
2. `kyi.smali`

The framework/session classes are byte-for-byte identical between V2 and V5:

- `Lid` SHA256 in both: `fd497e77f198da080c3fc613fff68836139a36aa65e98d64c11002387690a08d`
- `Llag` SHA256 in both: `3d11bd1c44a2e71b0d33be279651bbc446e5713669b067df2bf9d3bf738e65aa`
- `Lii` SHA256 in both: `2a6a0d7a8d91ef1ce36842fa386eb90644ff45bd965562acf576ff69d8b6bc40`

The AndroidManifest is unchanged between V2 and V5.

Therefore V5 did not directly modify the MediaSession metadata publisher, PlaybackState publisher, or MediaSession callback implementation.

## VERIFIED V5-only changes

`MusicBrowserService` adds only the queueId -> native mediaId sidecar lookup, preserving the V2 row title/subtitle/artwork construction.

`Lkyi.j()` adds only the playable-ID producer:

`Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(Lboht) -> vivoNativeIds[queueId]`

No `setMetadata`, `setPlaybackState`, title, artist, duration, position or Vivo support-event publication is injected by V5.

## VERIFIED stock MediaSession metadata path

Exact YT Music class `Lbazk` builds standard Android media metadata from the active player object:

- `Lbaxh.v()` -> `android.media.metadata.ARTIST`
- `Lbaxh.w()` -> `android.media.metadata.TITLE`
- `Lbaxh.o()` -> `android.media.metadata.DURATION`
- artwork -> `android.media.metadata.ALBUM_ART`

`Lbazk.i()` obtains the `Liq` MediaSession facade, activates it, builds this metadata and calls:

`Liq.k(MediaMetadataCompat)`

which reaches `Lii.m(MediaMetadataCompat)` and then framework:

`MediaSession.setMetadata(MediaMetadata)`.

Thus YT Music already has a canonical standard title/artist/duration publication path; V5 did not remove it.

## VERIFIED stock PlaybackState/position path

`Lbazk.g(int)` reads the active player position through `Lbaxh.p()` and speed through `Lbaxh.a()`, constructs `PlaybackStateCompat`, then schedules/publishes the state through the same `Liq` facade.

`Lii.n(PlaybackStateCompat)` preserves state, position, speed, update time, actions, buffered position and active queue item before calling framework `MediaSession.setPlaybackState(PlaybackState)`.

Therefore YT Music also already owns a standard position clock. Do not fabricate elapsed time in a future patch.

## Vivo capability contract

Earlier exact Luna reverse engineering established the vendor metadata capability key:

`vivomusicmix.media.metadata.support_event`

with official event mask bits:

- PLAY_CONTROL `0x1`
- MUSIC_INFO `0x2`
- MUSIC_IMAGE `0x4`
- MUSIC_LRC `0x8`
- SEEK_POSITION `0x10`
- MUSIC_TAG `0x20`
- FAVORITE `0x40`
- LOOP_MODE `0x80`
- LIST_CURRENT `0x100`
- LIST_FAVORITE `0x200`
- LIST_LOCAL `0x400`
- PLAY_INDEX `0x800`

The official Luna normal-track capability mask used by the existing A/B workflow is `0x9DF` (2527), which includes MUSIC_INFO, SEEK_POSITION, LIST_CURRENT and PLAY_INDEX among the supported operations.

The previous experimental V3 patch that advertised only `0x10` is **falsified** by runtime and must not be reused. It caused metadata regression and did not provide correct initial timing.

## Current unresolved boundary

V5 now switches songs correctly, but after the successful c0 row selection the OriginPlayer main surface is reported to lack title, artist and elapsed/duration numbers while the c0 playlist rows themselves show title and artist.

Static RE cannot distinguish the remaining two possibilities:

### Branch A — YT Music session publication does not refresh correctly after external c0 `playFromMediaId`

The playable endpoint starts audio, but the normal `Lbazk` metadata/PlaybackState publication sequence may not be reached or may publish incomplete state after this external selection route.

### Branch B — YT Music publishes correct standard session state, but Vivo rich-card consumer requires the vendor capability/refresh contract

If TITLE / ARTIST / DURATION / position are present in the actual framework MediaSession after the V5 switch, the remaining fix belongs to the Vivo cooperation capability/consumer contract rather than YT Music's standard metadata producer.

## Next gate

Do not make a functional V6 yet.

Build one observation-only V5 probe that preserves the working selection path and logs, without altering values:

1. every `Lii.m(MediaMetadataCompat)` publication: TITLE, ARTIST, DURATION;
2. every `Lii.n(PlaybackStateCompat)` publication: state, position, speed, update time and active queue id;
3. the selected c0 mediaId / queue item identity only for correlation;
4. optionally whether the published framework metadata contains `vivomusicmix.media.metadata.support_event` (expected absent in unmodified V5).

Decision:

- if metadata/state become correct after the row switch -> fix/replicate the Vivo capability/consumer contract, not the standard metadata producer;
- if metadata/state are absent/stale after the row switch -> trace the missing queue-state/session-publication step relative to stock `onSkipToQueueItem` before changing vendor capability flags.

Freeze V5 selection behavior as a hard regression invariant.
