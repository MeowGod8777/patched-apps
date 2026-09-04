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
4. A suspected V4N smali scratch-register clobber was checked against the patched `Lkyi.j()` context and **disproved**. The affected scratch registers are redefined by the original method before subsequent use.
5. Exact validated-base inspection found only two concrete `Lnoq` implementors used by this code family: `Lnox` and `Lnpa`. In both, `o()Lboht;` is a pure protobuf field getter: it checks the presence bit and returns the stored `Lbxxg.q:Lboht` or the default `Lboht.a`. It performs no queue mutation, callback, session operation or state write.
6. Exact `Llgl.d(Lboht)` implementation was recovered. It only:
   - creates an `Lbuyd` protobuf builder,
   - stores the supplied `Lboht` in field `Lbuyd.e` and sets its presence bit,
   - builds the protobuf,
   - calls `Llgl.g(Lbuyd)`.
7. Exact `Llgl.g(Lbuyd)` only calls `toByteArray()` and `android.util.Base64.encodeToString(bytes, 8)`. It performs no MediaSession, queue, controller, callback, cache or mutable global-state operation.
8. Stock YouTube Music contains at least five independent `Llgl.d(Lboht)` call sites (`Llgp`, `Lmxt` x3, `Lplq`), including direct helper paths and stock `MediaBrowserCompat.MediaItem` creation. Therefore this encoder is a normal stock media-ID codec.
9. Stock `Llgp.q()` demonstrates that a valid native-ID `MediaBrowserCompat.MediaItem` can use the `Llgl.d()` media ID with normal title/subtitle and **null extras**. Therefore a blanket claim that every native ID requires companion MediaDescription extras is false.

## Branch A status — ELIMINATED

The V4N regression is **not** caused by producer-side side effects from `Lnoq.o()` or `Llgl.d()`.

Both components are pure with respect to playback/session state, and the encoder is used normally by stock YouTube Music. No evidence remains for the prior producer-mutation hypothesis.

## Remaining root-cause problem

The regression must be downstream of the encoded ID being exposed through the Vivo cooperation browse/selection path, or in the concrete V4N browse-item / callback interaction.

Important constraints:

- Merely having a non-null MediaItem ID is not the trigger: V2 already has non-null synthetic `vivo_qid_*` IDs and remains metadata-stable.
- Vivo c0 current-list selection is known to take the selected `MediaItem.mediaId` and issue `playFromMediaId(mediaId, Bundle{"vivomusicmix_key_list"="vivomusicmix_current_list"})` through the cooperation controller.
- Untouched YT Music `Llag.g(String, Bundle)` decodes its input via `Laveu.b(String)`, resolves an `Lboht` via `Llbg.a(Lavev)`, and sends it into the native playback path via `Llbg.o(...)`.

This creates a stronger possibility that the V4N row click is **not actually inert**: a decodeable native ID may enter `Llag.g()` and partially perturb/replace playback/session state before failing to complete the requested song switch. That would explain why V2 synthetic IDs remain harmless while V4/V4N lose OriginPlayer metadata/progress after interaction.

This is not yet promoted to VERIFIED because the current device report did not separately timestamp the metadata/progress regression as occurring before vs. after the first playlist-row click.

## Required next step

Do **not** build another feature candidate.

The next runtime work, if required, must be a single observation-oriented trace with V2 behavior preserved or otherwise no selection rewrite. It must answer in one pass:

1. Does Vivo c0 row click actually reach untouched `Llag.g()`?
2. What exact mediaId and extras reach `Llag.g()`?
3. Does `Laveu.b(mediaId)` decode to a non-empty `Lavev`?
4. Does `Llbg.a(Lavev)` recover the intended `Lboht`?
5. Is the OriginPlayer metadata/progress loss before the first row click or only after that callback enters the native playback path?

Hard guards remain:

- **DO NOT PATCH `Lid` AGAIN.**
- **DO NOT map queueId to `onSkipToQueueItem`.**
- **DO NOT mix the time-display patch into selection work.**
- No V5 feature APK should be handed to the device until the callback/interaction boundary is positively located.
