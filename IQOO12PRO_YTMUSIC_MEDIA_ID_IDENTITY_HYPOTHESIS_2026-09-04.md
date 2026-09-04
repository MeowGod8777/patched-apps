# iQOO 12 Pro / OriginOS 6 — YouTube Music Vivo `MEDIA_ID` identity result

Date: 2026-09-04

## Frozen runtime baseline

Preserve the runtime-successful V5 selection architecture and the validated `support_event=0x9DF` timing fix.

Do not modify:

- `Lid` / framework `onPlayFromMediaId` adapter;
- V5 `Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(...)` playable-ID producer;
- PlaybackState state/position/speed/update-time values;
- queue row title/artist/artwork construction.

## VERIFIED runtime observations

1. V5 c0 rows select successfully with the native playable media ID generated from `Lnoq.n() -> Lazmi.b -> Llgl.d`.
2. After c0 selection YT Music publishes correct standard Android TITLE, ARTIST, DURATION and PlaybackState; Android's normal media notification follows the new track.
3. `support_event=0x9DF` makes Vivo OriginPlayer artwork and elapsed/duration refresh correctly, but its title/artist remain stale.
4. Official Luna has no separate `MUSIC_INFO` session event.

## VERIFIED official Luna identity join

Workflow: `Verify Luna Vivo list mediaId identity`

- run: `33831804868`
- artifact: `9921980727`
- artifact digest: `sha256:e2377d5056c73fdc00c920e40ad91e78487b7672b08f8e6f69f8dc6308021c9a`

Exact official Luna `PlayerService` behavior:

1. `vivomusicmix_current_list` builds the current item and next queue by calling `toMediaItem(IPlayable, ...)`.
2. `toMediaItem(...)` calls `IQueueItem.getPlayableId()` and writes the result directly with `MediaDescriptionCompat.Builder.setMediaId(...)`.
3. `VIVOSupportUtil.isTargetCanPlay(...)` resolves the incoming Vivo row mediaId by scanning the real queue and comparing directly against each `IQueueItem.getPlayableId()`.
4. `CoreRemoteControl.update()` writes `android.media.metadata.MEDIA_ID` from the active `IPlayable.getPlayableId()` into the same metadata builder as TITLE/ARTIST/DURATION.

Therefore official Luna uses one identity domain end-to-end:

`current-list MediaItem.mediaId == playFromMediaId identity == current metadata MEDIA_ID == IQueueItem.getPlayableId()`.

This is now VERIFIED, not inferred.

## YT Music delta

YT Music V5 already gives Vivo rows a working native playable media ID (`Llgl.d(Lnoq.n().b)`), and that ID successfully selects the target track. However YT Music's canonical metadata producer omits `android.media.metadata.MEDIA_ID`.

The V5 state probe also establishes ordering useful for a minimal fix. On a c0 row change:

- SELECT arrives;
- PlaybackState publishes the new active queue id (e.g. qid 79);
- only after that does metadata publish the new TITLE/ARTIST/DURATION.

Thus the active queue id is available before the metadata publication that needs the matching identity.

## Evidence-based final A/B design

Build exactly one candidate over exact V5 + `0x9DF`:

1. On the existing `Lii.n(PlaybackStateCompat)` sink, observe only `activeQueueId` and look it up in the existing V5 `MusicBrowserService.vivoNativeIds` map.
2. Latch the matching native playable media ID in a tiny helper. If lookup fails / qid is invalid, clear the latch rather than publish a stale identity.
3. On the existing `Lii.m(MediaMetadataCompat)` framework-builder path, add only:
   `android.media.metadata.MEDIA_ID = latched native playable mediaId`
   when non-null.
4. Keep `vivomusicmix.media.metadata.support_event=0x9DF` unchanged.

This does not fabricate title, artist, duration or position and does not alter selection. It only restores the exact identity field official Luna publishes.

Hard guards:

- `Lid` unchanged;
- `Llag` unchanged;
- V5 `n()->Lazmi.b` producer unchanged;
- no `o()` / `p()` endpoint;
- no queueId parsing into a playback callback;
- PlaybackState values unchanged;
- no old trace instrumentation.
