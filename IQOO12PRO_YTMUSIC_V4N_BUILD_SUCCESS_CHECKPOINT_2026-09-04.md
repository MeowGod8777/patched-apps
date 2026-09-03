# iQOO 12 Pro / YouTube Music OriginPlayer — V4N build-success checkpoint

Date: 2026-09-04

## Scope

This checkpoint records the completed **V4N native-mediaId candidate build** before device-side selection testing.

V4N is derived from the verified runtime-stable V2 baseline and keeps the V3/V3R1/V3S callback/timing regressions out of the candidate.

The product target remains the OriginOS 6 OriginPlayer playlist experience; `c0` / MediaBrowser cooperation is only the implementation path.

## Candidate identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_NATIVE_MEDIAID_V4N.apk`
- GitHub Actions workflow: `Build YT Music Luna Vivo c0 native mediaId V4N`
- run: `33819154154`
- artifact: `9917643517`
- APK SHA256: `4d5721cfbb4ae8cb42eb092d966dfb0882f6e44a8fbacc53937aee02b73aa692`
- signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Validated base identity remains:

- package: `com.luna.music`
- version: `9.15.51`
- validated base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- validated signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

## V4N architecture

V4N does **not** patch `Lid` and does **not** reinterpret Android `MediaSessionCompat.QueueItem.queueId` as a YT Music playable mediaId.

The intended selection path is:

`Lnoq.o()`
→ `Lboht` playback endpoint
→ `Llgl.d(Lboht)`
→ native YT Music encoded mediaId
→ Vivo MediaBrowser `MediaItem.mediaId`
→ Vivo c0 `playFromMediaId(nativeMediaId, extras)`
→ untouched `Lid.onPlayFromMediaId()`
→ untouched `Llag.g()` native decoder / playback pipeline.

Implementation summary:

1. `MusicBrowserService` owns a `ConcurrentHashMap<Long, String>` sidecar mapping queueId → nativeMediaId.
2. While `Lkyi.j()` still has the upstream `Lnoq`, V4N reads:
   - `queueId = Lnoq.m()`
   - `endpoint = Lnoq.o()`
   - `nativeMediaId = Llgl.d(endpoint)`
3. The Vivo `vivomusicmix_current_list` browse result keeps the V2-verified title / artist / artwork path.
4. Its `MediaItem.mediaId` uses the sidecar native ID when present.
5. If the sidecar mapping is absent, V4N falls back to `vivo_qid_<queueId>` only to keep a non-empty renderable mediaId; that fallback is **not** treated as a selectable-success path.

## Build verification

The V4N build completed successfully and passed the required release gates:

- rebuild: PASS
- `zipalign -P 16`: PASS
- APK Signature Scheme v2 verification: PASS
- APK Signature Scheme v3 verification: PASS
- signer matches validated base: PASS
- 21 arm64 `.so` entries present: PASS
- all 21 arm64 `.so` entries stored: PASS
- final zip alignment verification: PASS
- package `com.luna.music`: PASS
- version `9.15.51`: PASS
- `com.vivo.musicwidgetmix.support.service`: present
- `VIVO_MUSIC_MIX_ROOT`: present

## Regression guards

Critical guards passed:

- `Lid` callback is byte-for-byte unchanged from the validated base: **PASS**
- `Lii.m()` metadata method is byte-for-byte unchanged from the validated base: **PASS**

Therefore V4N does not contain the earlier V3/V3R1/V3S queueId callback patch and does not include the rejected `Lii.m()` timing/metadata experiment.

## Runtime status at checkpoint

**V4N runtime selection result is not yet recorded here.**

The next device test is deliberately selection-only. Time display remains out of scope until selection passes.

PASS criteria:

1. OriginPlayer song title does not regress.
2. Playlist button opens.
3. Real current + upcoming queue still renders.
4. Title / artist remain correct.
5. Selecting a different row actually changes YouTube Music playback to that row.

If 1–4 pass but 5 fails, the next step is **not** another queueId guess and **not** another `Lid` patch. Capture the live c0 selection path instead:

- actual mediaId sent by Vivo c0
- extras sent with it
- whether `Llag.g()` receives the callback
- whether the native mediaId decodes successfully
- whether the decoded endpoint enters the playback pipeline

Elapsed / duration investigation remains a separate follow-up after selection is working.
