# iQOO 12 Pro / OriginOS 6 — YT Music V5 media-identity runtime success

Date: 2026-09-04

## Device

- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build `PD2329B_A_16.2.19.1.W10.V0101L17`

## Tested APK

- `YouTube_Music_9.15.51_Luna_VIVO_C0_V5_MEDIA_IDENTITY.apk`
- build run `33832184688`
- artifact `9922079285`
- APK SHA256 `547d7b1d31a68e32d273a770e4575f50fef6948246f984ae5d310ad0195b8427`

## Runtime result

User screenshots confirm the remaining OriginPlayer regressions are fixed while the V5 queue-selection path remains intact:

- OriginPlayer main card title updates to the currently playing track: PASS
- OriginPlayer main card artist updates: PASS
- elapsed time is visible and advancing: PASS (`00:04` then `00:09` in the supplied captures)
- duration is visible: PASS (`03:36` in the supplied captures)
- artwork is correct for the selected/current track: PASS
- c0 playlist still opens and displays the real queue with title/artist rows: PASS
- standard Android media notification shows the same current track and artist as the OriginPlayer surface: PASS

The visible track in the captures is `未接來電 - 莫宰羊 Covered by 陳忻玥`, artist `陳忻玥`; both the OriginPlayer surface and the normal media notification reflect this same current item.

## Root cause / fix conclusion

The final missing contract was Vivo's playable identity propagation.

Official Luna uses the same playable identity across:

1. current-list MediaItem ID;
2. selection mediaId;
3. framework metadata `android.media.metadata.MEDIA_ID`.

YT Music V5 already had a working playable selection ID but did not publish the corresponding `MEDIA_ID`. With `support_event=0x9DF` already restoring Vivo timing/artwork refresh, adding the active queue item's native playable ID as metadata `MEDIA_ID` makes Vivo refresh title/artist correctly as well.

Implementation remains narrow:

- V5 `Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(...)` selection retained;
- `support_event=0x9DF` retained;
- active `PlaybackStateCompat.activeQueueItemId` resolves through the existing `vivoNativeIds` sidecar;
- only `android.media.metadata.MEDIA_ID` is added at the framework metadata builder;
- TITLE / ARTIST / DURATION / position are not fabricated or rewritten;
- `Lid` and `Llag` selection callback logic remain untouched.

## Project status

The original product goal is now satisfied on the target device/build:

1. OriginPlayer playlist button opens;
2. real current/upcoming queue is visible;
3. queue rows show correct song/artist;
4. tapping a queue row changes playback;
5. OriginPlayer main-card title/artist refresh correctly;
6. elapsed/duration numbers are visible and advancing.

Treat this APK/architecture as the current known-good product baseline. Future changes must preserve these behaviors as regression invariants.
