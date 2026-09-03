# iQOO 12 Pro / YT Music c0 browser probe v0 — device result

Date: 2026-09-03 (+08:00)

## Build under test

- package: `com.luna.music`
- version: `9.15.51`
- candidate: `YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V0.apk`
- APK SHA256: `278b1bd3a745f4afec6c8851360e743a875187e44ca764ba331c77d3b6a0da89`
- signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`
- workflow run: `33755186029`
- workflow artifact: `9893179077`

## Device

- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build `PD2329B_A_16.2.19.1.W10.V0101L17`

## UI A/B result

Before probe v0:

- OriginPlayer playlist button was completely inert.

With probe v0:

- tapping the playlist button opens Vivo's dedicated playlist UI;
- the UI remains on `載入中` / loading;
- the static `vivo_probe_1 / YT Music Vivo Bridge` row never renders.

This validates the first cooperation gate:

`com.vivo.musicwidgetmix.support.service -> Vivo custom-insert / c0 playlist UI activation` ✅

## Focused logcat result

A focused runtime trace was collected immediately after reproducing the loading state.

The decisive failure is in `com.luna.music` on the main thread:

```text
E AndroidRuntime: FATAL EXCEPTION: main
E AndroidRuntime: Process: com.luna.music
E AndroidRuntime: java.lang.NoClassDefFoundError: Failed resolution of: Landroid/support/v4/media/MediaDescriptionCompat$Builder;
E AndroidRuntime:     at com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService.b(Unknown Source:17)
E AndroidRuntime:     at cai.g(PG:19)
E AndroidRuntime:     at bzy.run(PG:98)
...
E AndroidRuntime: Caused by: java.lang.ClassNotFoundException: android.support.v4.media.MediaDescriptionCompat$Builder
```

This class reference exists only in the injected probe branch of `MusicBrowserService.b(...)`.

Therefore the runtime evidence now establishes more than the UI-only result:

1. the existing YT Music `MusicBrowserService` is executing;
2. its `b(Ljava/lang/String;Lbzu;Landroid/os/Bundle;)V` load-children path is reached;
3. the injected `vivomusicmix_current_list` branch is reached far enough to execute the first injected MediaDescription construction;
4. the branch then crashes before a probe item can be constructed or delivered because the injected implementation referenced the obsolete support-v4 compat media classes, which are not present in this YT Music runtime.

This is a probe implementation/type-family failure, not evidence against the c0 cooperation architecture.

## Other log observations

A separate earlier browser connection attempt from `com.google.android.wearable.app.cn` is rejected by YT Music's original root logic:

```text
W MusicBrowserService: MBS: onGetRoot(). appPkg: 'com.google.android.wearable.app.cn'
I MediaBrowserService: No root for client com.google.android.wearable.app.cn
E MediaBrowser: onConnectFailed for ComponentInfo{com.luna.music/com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService}
```

This is not the fatal cooperation failure above and must not be conflated with the Vivo current-list request.

Repeated `GoogleApiManager PackageVerificationRslt: not allowed` messages also occur before the cooperation failure and are pre-existing patched-app/GMS noise; they do not match the fatal stack responsible for the playlist loading failure.

## Updated failure boundary

Verified on device:

`support.service -> custom-insert/c0 playlist UI activation` ✅

`MusicBrowserService load-children path -> vivomusicmix_current_list injected branch` ✅

Current blocker:

`probe MediaItem construction` ❌

Exact root cause:

`android.support.v4.media.MediaDescriptionCompat$Builder` is absent at runtime.

The same compatibility risk applies to the injected `android.support.v4.media.MediaBrowserCompat$MediaItem` constructor and must be removed from the next candidate rather than merely fixing the first missing class.

## Immediate next step

Do NOT add real queue or `playFromMediaId` yet.

Build probe v1 as a single-variable type-family correction:

1. keep the proven manifest `support.service` action unchanged;
2. keep the proven Vivo root handling unchanged;
3. keep `vivomusicmix_current_list` selection unchanged;
4. replace the injected support-v4 `MediaDescriptionCompat` / `MediaBrowserCompat.MediaItem` construction with the concrete media item/description family expected by this YT Music `MediaBrowserService` implementation;
5. preserve the same static probe id/title/subtitle so the device result remains attributable;
6. rebuild -> 16K zipalign -> same-signer verification -> manifest/static verification before delivery.

Only after the static probe row renders should the project proceed to real queue mapping and then `playFromMediaId`.