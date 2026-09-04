# iQOO 12 Pro / OriginOS 6 — YouTube Music Vivo `MEDIA_ID` identity hypothesis

Date: 2026-09-04

## Frozen runtime baseline

Preserve the runtime-successful V5 selection architecture and the validated `support_event=0x9DF` timing fix.

Do not modify:

- `Lid` / framework `onPlayFromMediaId` adapter;
- V5 `Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(...)` playable-ID producer;
- PlaybackState position/timing publication;
- queue row title/artist/artwork construction.

## VERIFIED observations

1. V5 c0 rows now select successfully with the native playable media ID generated from `Lnoq.n() -> Lazmi.b -> Llgl.d`.
2. After selection, YT Music publishes correct standard Android TITLE, ARTIST, DURATION and PlaybackState. The standard Android media notification follows the selected track.
3. Adding official Luna normal-track `vivomusicmix.media.metadata.support_event=0x9DF` makes Vivo OriginPlayer artwork and elapsed/duration refresh correctly, but title/artist remain stale.
4. Official Luna does not send a separate `MUSIC_INFO` session event; `MUSIC_INFO` is only a capability bit in the normal support mask.
5. Official Luna `CoreRemoteControl.update()` writes `android.media.metadata.MEDIA_ID` from the active `IPlayable.getPlayableId()` into the same `MediaMetadataCompat.Builder` used for TITLE/ARTIST/DURATION.
6. Exact YT Music metadata producer `Lbazk` writes TITLE, ARTIST, DURATION, artwork and other standard fields but does not publish `android.media.metadata.MEDIA_ID` from application code.
7. Official Luna `VIVOSupportUtil.isTargetCanPlay(...)` resolves an incoming Vivo media ID by scanning the real queue and comparing that string directly to each queue item's `getPlayableId()`.

## Current hypothesis

Official Luna appears to maintain a unified Vivo identity domain around `IQueueItem.getPlayableId()`:

- incoming Vivo row selection mediaId;
- current playable identity;
- framework metadata `android.media.metadata.MEDIA_ID`.

YT Music currently satisfies the first identity (its c0 row native mediaId is playable and selects correctly) but omits the corresponding metadata identity. Vivo may therefore refresh artwork and timing from normal metadata/state while keeping title/artist bound to the previous current-list identity.

This is the strongest remaining single structural difference and matches the runtime symptom.

## Final evidence gate before a device candidate

Statically prove that official Luna's `vivomusicmix_current_list` browser/list producer emits `MediaItem.mediaId` from the same `getPlayableId()` identity used by `VIVOSupportUtil` and metadata `MEDIA_ID`.

If that identity join is verified, build exactly one narrow A/B candidate:

- exact V5 playable selection;
- exact `support_event=0x9DF`;
- add `android.media.metadata.MEDIA_ID` using the exact native playable media ID associated with the selected/current item;
- no selection, queue, title, artist, duration, position or action behavior changes.

Do not build if the official Luna list identity does not join cleanly.