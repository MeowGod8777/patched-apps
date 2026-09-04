# iQOO 12 Pro / OriginOS 6 — YouTube Music V4N runtime regression

Date: 2026-09-04

## Candidate identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_NATIVE_MEDIAID_V4N.apk`
- Workflow: `Build YT Music Luna Vivo c0 native mediaId V4N`
- Run: `33819154154`
- Artifact: `9917643517`
- SHA256: `4d5721cfbb4ae8cb42eb092d966dfb0882f6e44a8fbacc53937aee02b73aa692`
- Build-success checkpoint: `IQOO12PRO_YTMUSIC_V4N_BUILD_SUCCESS_CHECKPOINT_2026-09-04.md`

## Device runtime result

True V4N was tested on the target iQOO 12 Pro / OriginOS 6 device.

Observed:

- Vivo OriginPlayer playlist opens: **PASS**
- Real queue remains complete: **PASS**
- Song title / song information on OriginPlayer: **FAIL / absent**
- Timeline / progress information: **FAIL / absent**
- Playlist row selection changes playback: **FAIL**

Therefore V4N is not a product-success candidate. V2 remains the only verified runtime-stable baseline.

## V2 baseline reminder

V2 (`REAL_QUEUE_V2`, SHA256 `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`) keeps OriginPlayer title / metadata stable and renders the real queue, but row selection is inert and initial elapsed/duration is absent.

## Method-level delta facts established after the V4N failure

1. V2 and V4N construct the Vivo `MediaBrowserCompat.MediaItem` with the same queue-derived title / subtitle / description / artwork and the same playable flag.
2. At the browser item level, the material content difference is the `mediaId` string:
   - V2: synthetic `vivo_qid_<queueId>`
   - V4N: `vivoNativeIds.get(queueId)` with synthetic fallback only for mapping misses.
3. V4 and V4N share an additional producer-side operation inside `Lkyi.j()` that V2 does not perform:
   - `Lnoq.o() -> Lboht`
   - `Llgl.d(Lboht) -> native mediaId`
4. A suspected V4N smali scratch-register clobber was checked against the patched `Lkyi.j()` context and **disproved**. The affected scratch registers are redefined by the original method before subsequent use; this is not the current root cause.
5. Prior stock-code static traces already show YouTube Music itself calling `Llgl.d(Lboht)` when assembling `MediaBrowserCompat$MediaItemInfo` media IDs from a playback endpoint (`Lavev.a() -> Lboht`). Therefore `Llgl.d()` is an existing stock media-ID encoder, not an invented V4N-only codec. This reduces, but does not yet eliminate, the probability of encoder-side mutation.

## Current narrowed root-cause branches

### Branch A — producer capture side effect

The additional `Lnoq.o()` / `Llgl.d()` work performed in the hot `Lkyi.j()` queue producer may perturb queue/session state or invoke a concrete `Lnoq.o()` implementation with non-trivial semantics. This must be checked at the implementation level; `Lnoq` itself is abstract.

### Branch B — Vivo consumer semantic branch

V2 already supplies non-empty synthetic media IDs without breaking OriginPlayer metadata, so the regression is not explained by merely making `MediaItem.mediaId` non-null. Supplying a native/decodeable-looking YouTube Music media ID may cause Vivo c0 / OriginPlayer to take a different cooperation/control branch with additional expectations. That branch may suppress or replace the normal MediaSession metadata/progress path while still failing to dispatch a usable selection request.

## Required next analysis

Do **not** make another feature APK yet.

Before another candidate is built, statically recover and compare:

1. Concrete `Lnoq` subclass(es) used by `Lkyi.j()` and the actual implementation of `o()Lboht;`.
2. Full `Llgl.d(Lboht)` implementation.
3. Stock call sites that use `Llgl.d()` for `MediaBrowserCompat$MediaItemInfo`, including any companion extras/root semantics that V4N did not reproduce.
4. Vivo c0 / Music Mix handling of returned `MediaItem.mediaId` and its row-click dispatch path, especially any branch that distinguishes synthetic/opaque IDs from native-looking IDs.

No V5 candidate should be handed to the device until at least one of Branch A or Branch B is eliminated or positively identified.
