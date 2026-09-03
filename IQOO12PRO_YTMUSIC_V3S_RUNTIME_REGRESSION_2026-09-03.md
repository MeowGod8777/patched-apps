# iQOO 12 Pro / OriginOS 6 / YT Music c0 V3S runtime regression — 2026-09-03

## Product goal
Fix patched YouTube Music OriginPlayer playlist behavior on iQOO 12 Pro / OriginOS 6.

## Proven-good reference
V2 real-queue candidate was runtime-PASS for:
- playlist button opens
- real queue renders
- title/artist visible in playlist

V2 still lacked working playlist-item selection and initial elapsed/duration time labels.

## V3S candidate
V3S was intentionally built as **V2 + selection-only delta**.
The previous `vivomusicmix.media.metadata.support_event` / `ii.m()` time patch was completely removed and statically guarded against reappearing.

## Runtime result reported by user
Observed on iQOO 12 Pro / V2329A / OriginOS 6:

1. Playlist opens ✅
2. Playlist real songs render ✅
3. Tapping a playlist row does **not** switch playback ❌
4. OriginPlayer / playback notification song title is missing ❌
5. Timeline / elapsed-duration presentation is missing ❌

## Exact finished-APK diff: V2 PASS vs V3S FAIL

Evidence workflow:
- run `33775924858`
- artifact `9901585654` (`ytmusic-v2-v3s-apk-diff`)

Finished APK entry comparison:
- V2 entries: 5257
- V3S entries: 5257
- entries only in V2: 0
- entries only in V3S: 0
- changed entries: 4
  - `META-INF/ANDREWLI.RSA`
  - `META-INF/ANDREWLI.SF`
  - `META-INF/MANIFEST.MF`
  - `classes5.dex`
- non-signature changed entries: exactly **1** -> `classes5.dex`

Decoded-output diff:
- changed decoded files: 3
  - `original/META-INF/ANDREWLI.SF`
  - `original/META-INF/MANIFEST.MF`
  - `smali_classes5/id.smali`
- changed smali files: exactly **1** -> `smali_classes5/id.smali`

Therefore the regression is **not** caused by manifest/resource/browser-service/queue-bridge/build-pipeline drift. V3S differs from runtime-PASS V2 only in the MediaSession callback class `Lid` plus normal signature material.

Exact V3S delta in `Lid.onPlayFromMediaId(String, Bundle)`:
- `.locals 1 -> .locals 3`
- if mediaId starts with `vivo_qid_`, parse suffix as long
- call `Lid.onSkipToQueueItem(long)`
- return
- otherwise execute original YT Music `onPlayFromMediaId` body

## Consequences

This falsifies the assumption that `QueueItem.b` encoded as `vivo_qid_<long>` and routed through the patched `Lid.onPlayFromMediaId()` -> `onSkipToQueueItem(long)` path is sufficient for Vivo c0 selection.

It also means the song-name/time regression cannot be blamed on unrelated APK output drift. Because the only non-signature change is `Lid`, one of the following must be true and must be proven before another functional build:

1. Vivo c0 invokes / interacts with this transport callback earlier than assumed (not only after an explicit user row tap), so the injected branch can perturb session state before the visible tap test.
2. `Lid` is a callback for a session involved in metadata/card state, but not necessarily the MediaSession token that c0 controls for browser selection.
3. The `QueueItem.b` value is not the identifier expected by YT Music's real queue-selection path in this context.
4. c0 may send a different mediaId/extras or use a different callback/session than the patched `Lid.onPlayFromMediaId` path.

## Next step

Do not generate another functional APK yet.

Static boundary to resolve first:
- trace `MusicBrowserService` session-token publication;
- identify the exact MediaSession / MediaSessionCompat instance whose token is exposed to `com.vivo.musicwidgetmix`;
- identify the exact callback object registered on that session;
- prove whether it is `Lid` or another callback layer;
- trace how that callback maps `playFromMediaId` and `skipToQueueItem` into the real player.

Runtime boundary after static trace:
- capture the actual mediaId/extras arriving from Vivo on row tap without changing playback behavior;
- compare active MediaSession metadata / PlaybackState before opening the playlist, after opening it, and after tapping a row.

No more queue-ID or metadata functional patches until those boundaries are proven.
