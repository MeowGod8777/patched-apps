# iQOO 12 Pro / OriginOS 6 — YouTube Music V4N c0 trace runtime result

Date: 2026-09-04

## Probe identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_V4N_TRACE.apk`
- APK SHA256: `cc6dd5601ce143239fcefdc08ac58cc8a55bbfafda1c62636526df31a95906db`
- Build run: `33823745078`
- Build artifact: `9919197991`
- Build-success checkpoint: `6d7a218d33f9f5f5b840d0ac63be149d5ae6ff48`
- Device: iQOO 12 Pro / V2329A / OriginOS 6 / Android 16
- Device build: `PD2329B_A_16.2.19.1.W10.V0101L17`

## Runtime evidence supplied

- screen recording: `2026_09_04_09_05_54.mp4`
- filtered trace: `ytmusic_c0_trace.txt`
- trace tag: `YTM_C0TRACE`

## VERIFIED runtime observations

### 1. Browse exposure is not the selection failure boundary

At `09:06:13.832` Vivo requests:

`BROWSE parent=vivomusicmix_current_list`

The service returns the real queue with concrete V4N native media IDs. The playlist renders normally.

The screen recording shows the current song remains `Deadman / KUN` after the playlist opens. The previous V4N report that title/song information can disappear is therefore **not reproduced in this run** and cannot be treated as an invariant consequence of exposing the native media ID.

The original missing elapsed/duration numbers remain a separate unresolved issue.

### 2. Selected Vivo row reaches the untouched YT Music callback

The second visible row is `哥歌 / 王苑之`. Its returned browser item is queue id `78`.

Trace:

`ITEM qid=78 mediaId=GqABEiQIsQMQyCAYASITCLbTrfnd05YDFRUCewcdxTU5x8oBBLk7d4DqlLbnAXQKIlBMenZLZ1Fx...`

On row press, the exact same media ID reaches the untouched native callback target:

`ENTRY mediaId=GqABEiQIsQMQyCAYASITCLbTrfnd05YDFRUCewcdxTU5x8oBBLk7d4DqlLbnAXQKIlBMenZLZ1Fx...`

Two `ENTRY` sequences are visible in the trace and correspond to two visible pressed states on the same `哥歌` row in the recording. Both behave identically.

Therefore the previous hypothesis “Vivo row click may never reach `Llag.g()`” is **eliminated**.

### 3. Native media ID transport is intact

Immediately after callback entry:

`DECODE value=MediaId(value=<same exact ID>)`

`Llbg.a(Lavev)` then returns a non-null `Lboht` object:

`ENDPOINT value=# boht@92b80785 [60666189] { }`

The endpoint object identity is stable across both presses.

Therefore the row ID is not being truncated, replaced with `vivo_qid_*`, or rejected before endpoint extraction.

### 4. `Llbg.o()` is invoked and returns synchronously

Both presses reach:

`DISPATCH_BEFORE Llbg.o`

followed immediately by:

`DISPATCH_AFTER Llbg.o`

However the requested song does not begin playing. Returning from `Llbg.o()` only proves that its asynchronous scheduling call returned; it does **not** prove that downstream playback accepted or completed the request.

This distinction is important because exact stock `Llbg.o()` creates async success/failure continuations (`Llaw` / `Llax`) after preparing a future.

### 5. Requested track still does not switch

The screen recording shows the `哥歌` row pressed, but when returning to OriginPlayer the current track is still `Deadman / KUN`.

Thus the current failure boundary is downstream of:

`Vivo row press -> playFromMediaId -> untouched Llag.g -> Laveu.b -> Llbg.a -> Llbg.o entry`

and upstream of completed playback/session transition.

## Corrected model

The following are now VERIFIED:

1. Vivo c0 row selection dispatches `playFromMediaId` to the correct MediaSession callback.
2. The exact native ID returned in the selected `MediaItem` reaches `Llag.g()` unchanged.
3. `Laveu.b()` accepts it.
4. `Llbg.a()` returns a non-null endpoint.
5. `Llbg.o()` is entered and schedules asynchronous downstream work.
6. No song switch occurs.

The following are eliminated as primary selection causes:

- missing Vivo row callback;
- wrong framework callback (`Lid` routing);
- queueId -> `onSkipToQueueItem` requirement;
- synthetic/native mediaId transport corruption;
- failure before `Llbg.o()` is called;
- browse-open itself being sufficient to destroy metadata/session state.

## Next offline RE gate

Do **not** build another feature candidate yet.

Inspect the exact stock asynchronous path after `Llbg.o()`:

1. `Llaw` success continuation;
2. `Llax` failure continuation;
3. `Llam` endpoint preprocessing path;
4. the `Llbg.i(Lboht, Bundle)` / downstream command path reached by those continuations;
5. every Bundle key and source/referrer field that changes behavior;
6. compare with stock in-app/native call sites that successfully play an `Lboht`.

The next device probe, if still necessary after static RE, must observe the async completion/failure boundary rather than merely wrapping `Llbg.o()`.

Time-display repair remains deferred until row selection succeeds.
