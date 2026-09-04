# iQOO 12 Pro / OriginOS 6 — YouTube Music V4N c0 callback trace probe plan

Date: 2026-09-04

## Purpose

Stop feature-candidate iteration and locate the V4N regression boundary with one observation-only runtime probe.

The probe is **not V5** and is not a proposed fix. It exists only to answer why V4/V4N keep the Vivo playlist/queue but lose normal OriginPlayer information and still fail selection.

## Fixed runtime facts

- V2 (`REAL_QUEUE_V2`, SHA256 `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`) is the only verified runtime-stable baseline:
  - playlist opens;
  - real queue complete;
  - title/artist normal;
  - row selection inert;
  - initial elapsed/duration absent.
- True V4N (`NATIVE_MEDIAID_V4N`, SHA256 `4d5721cfbb4ae8cb42eb092d966dfb0882f6e44a8fbacc53937aee02b73aa692`) was tested on the target device:
  - playlist opens;
  - queue complete;
  - OriginPlayer song title/song information absent;
  - timeline/progress absent;
  - row selection still does not complete a song switch.
- V4N starts from the exact V2 patch and then changes only the native-ID sidecar / exposed browse ID path.
- `Lnoq.o()` and `Llgl.d(Lboht)` were statically proven pure with respect to MediaSession/playback state. Producer-side mutation is eliminated.
- `Lid` must remain untouched. QueueId -> `onSkipToQueueItem` is rejected.
- No timing-display patch may be mixed into this work.

## Probe architecture

Build from the exact validated Luna base, apply the proven V4N patcher unchanged, then add side-effect-only logging through a new helper class.

Log tag: `YTM_C0TRACE`

### Trace points

1. **Vivo browse entry**
   - `MusicBrowserService.b(parentId, result, extras)`
   - log parentId + extras.
   - `vivomusicmix_current_list` marks the playlist-open boundary.

2. **Queue mapping produced by V4N**
   - in the existing V4N `Lkyi.j()` mapping block, after `Llgl.d(Lboht)` succeeds;
   - log queueId + full native mediaId.

3. **Concrete browser item returned to Vivo**
   - in the V4N current-list loop after native/fallback mediaId resolution;
   - log QueueItem.queueId + exact `MediaItem.mediaId` that will be returned.

4. **Native callback target entry**
   - instrument **`Llag.g(String, Bundle)`**, not `Lid`;
   - log exact mediaId + exact extras reaching the real YT Music callback target.

5. **Decode boundary**
   - immediately after existing `Laveu.b(mediaId) -> Lavev` in `Llag.g()`;
   - log the returned object/default state without changing control flow.

6. **Endpoint boundary**
   - immediately after existing `Llbg.a(Lavev) -> Lboht` in `Llag.g()`;
   - log the recovered endpoint object/default state.

7. **Native playback dispatch boundary**
   - log immediately before and after the existing `Llbg.o(...)` call.
   - before-without-after indicates the call did not return normally; before+after proves dispatch was invoked and returned.

## Non-perturbation rules

- Do not edit `Lid` at all.
- Do not edit `Lii.m()` at all.
- Do not change V4N browse IDs, queue extraction, callback routing, PlaybackState actions, MediaSession queue, metadata or timing behavior.
- Do not catch or suppress exceptions from the production path.
- Logging helper methods may stringify arguments but may not write any app/session state.
- Existing V4N regression guards remain mandatory; additionally compare `Lid` and `Lii.m()` byte-for-byte against validated base.

## One-pass runtime sequence

After install:

1. Start a normal song and open OriginPlayer.
2. Clear logcat.
3. Open the OriginPlayer playlist and wait a few seconds **without tapping a row**.
4. Observe whether title/song information disappears before any row tap.
5. Tap one different row exactly once and wait a few seconds.
6. Dump only tag `YTM_C0TRACE` and preserve the screen recording/device observation.

This single sequence distinguishes:

- regression at browse exposure time (loss occurs before `Llag.g ENTRY`), versus
- regression after a native row callback enters YT Music (loss occurs only after `ENTRY` / decode / dispatch markers).

## Decision gates after trace

### If metadata regresses before row tap

The root cause is in Vivo's consumer semantics for the returned native/decodeable `MediaItem.mediaId` or browse-item contract. Stop callback work and reproduce the stock MediaBrowser item contract expected by Vivo.

### If metadata regresses only after row tap

Use the trace to identify the deepest reached boundary:

- no `ENTRY`: Vivo did not dispatch to the expected session callback;
- `ENTRY` but decode default/failure: wrong native mediaId encoding/content;
- decode succeeds but endpoint is default/incorrect: media-ID protobuf content mismatch;
- valid endpoint + no `DISPATCH_BEFORE`: branch/Bundle semantics prevent playback dispatch;
- `DISPATCH_BEFORE` + `DISPATCH_AFTER` but no song switch: `Llbg.o` accepted the request but downstream native playback requirements are missing; inspect the companion Bundle/context path rather than inventing another selection mechanism.

No feature APK is to be designed until this trace is complete.
