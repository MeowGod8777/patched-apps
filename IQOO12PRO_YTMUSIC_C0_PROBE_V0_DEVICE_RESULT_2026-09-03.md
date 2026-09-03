# iQOO 12 Pro / YT Music c0 browser probe v0 — first device result

Date: 2026-09-03 (+08:00)

## Build under test

- package: `com.luna.music`
- version: `9.15.51`
- candidate: `YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V0.apk`
- APK SHA256: `278b1bd3a745f4afec6c8851360e743a875187e44ca764ba331c77d3b6a0da89`
- signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`
- workflow run: `33755186029`
- workflow artifact: `9893179077`

## First real-device observation

Device:

- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build `PD2329B_A_16.2.19.1.W10.V0101L17`

Observed after installing probe v0 and tapping the OriginPlayer playlist button:

- Before probe: playlist button was completely inert.
- With probe v0: tapping the playlist button now **does produce a playlist/UI transition**, but it **immediately crashes / exits**.
- The static `vivo_probe_1 / YT Music Vivo Bridge` row has not yet been confirmed visible long enough to count as a successful browse render.

A user-recorded screen capture shows the patched YT Music session active immediately before the failure and the app returning to the launcher immediately after the attempted playlist open.

## Interpretation

This is a positive partial result but NOT an end-to-end pass.

The behavioral A/B strongly indicates that adding the Vivo cooperation surface changed the OriginPlayer playlist path from `inert` to `active`, so the previous hypothesis that `support.service + c0/cooperation` is the missing path remains viable.

However, this result does **not** yet prove all of the following:

- that `com.vivo.musicwidgetmix` successfully completed MediaBrowser root negotiation,
- that `VIVO_MUSIC_MIX_ROOT` was accepted,
- that `vivomusicmix_current_list` reached the injected branch,
- that the injected `MediaBrowserCompat.MediaItem` list was accepted by the receiver,
- that the crash is in `com.luna.music` rather than the Vivo side.

The immediate next step is therefore crash-log capture, not another speculative protocol rewrite.

## Next diagnostic step

Collect the Android crash buffer immediately after reproduction and identify the exact throwing process / exception / stack trace.

Priority hypotheses to resolve from the stack, without treating any as confirmed before evidence:

1. injected current-list callback returns an object/list element type incompatible with the concrete YT Music MediaBrowser implementation;
2. `Lbzu;->c(Ljava/lang/Object;)V` result contract is being satisfied with the wrong MediaItem family (`android.support.v4.media.MediaBrowserCompat$MediaItem` vs framework/internal type expected by this service implementation);
3. Vivo c0 accepts the service/root but crashes while parsing an incomplete probe item / missing metadata required by its UI;
4. a YT Music client/service lifecycle invariant is violated by the early-return injected branch.

Do not add real queue or `playFromMediaId` until this crash is localized.
