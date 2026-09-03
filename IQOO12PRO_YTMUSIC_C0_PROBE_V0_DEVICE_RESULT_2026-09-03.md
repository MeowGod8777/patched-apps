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

## Real-device observation

Device:

- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build `PD2329B_A_16.2.19.1.W10.V0101L17`

Observed in the user-recorded screen capture after installing probe v0:

- Before probe: OriginPlayer playlist button was completely inert.
- With probe v0: tapping the playlist button now opens Vivo's dedicated playlist UI.
- The playlist UI visibly remains at a `載入中` / loading spinner state for multiple frames.
- The injected static `vivo_probe_1 / YT Music Vivo Bridge` row is not rendered.
- The later transition back to notification center / launcher is NOT sufficient by itself to classify this as a crash; no crash stack or explicit crash dialog is present in the video.

## What is now device-validated

The A/B result proves a real state transition:

`playlist button inert` -> `Vivo playlist UI opens`

This strongly validates the first cooperation gate:

`com.vivo.musicwidgetmix.support.service` -> Vivo custom-insert / c0 playlist UI activation

Therefore the previous theory that the missing OriginPlayer playlist backend is the Vivo cooperation path remains supported, and the probe has crossed the pre-cooperation UI gate.

## What is NOT yet proven

Because `vivo_probe_1` never appears, this is NOT an end-to-end MediaBrowser pass.

Still unresolved:

- whether c0 successfully binds the existing YT Music `MusicBrowserService`;
- whether `onGetRoot()` is invoked by `com.vivo.musicwidgetmix`;
- whether the returned `VIVO_MUSIC_MIX_ROOT` is accepted;
- whether c0 sends a browse request whose parent contains `vivomusicmix_current_list`;
- whether the injected `onLoadChildren()` branch executes;
- whether `result.sendResult()` / the service's concrete result wrapper accepts and delivers the injected list;
- whether Vivo rejects/parses the returned MediaItem after delivery.

## Current failure boundary

Verified:

`support.service -> custom-insert/c0 playlist UI activation` ✅

Unverified / current boundary:

`MediaBrowser bind -> root negotiation -> current-list browse -> result delivery/render` ❓

Observed terminal state:

`playlist UI -> loading spinner; no probe item`

This is a narrower failure boundary than the original inert-button state and is not evidence that the overall c0 architecture hypothesis failed.

## Immediate next step

Do not add real queue or `playFromMediaId` yet.

First collect a focused runtime trace from this same probe to distinguish:

1. service never binds;
2. service binds but root/client-package negotiation differs from the injected assumption;
3. root succeeds but actual parentId differs from `vivomusicmix_current_list`;
4. current-list hook executes but result delivery throws/fails;
5. item is delivered but rejected by Vivo's parser/UI.

Start with ordinary logcat / service state. If it does not expose the callback boundary clearly enough, the next APK should be a single-variable diagnostic probe with temporary explicit log markers around:

- `onGetRoot(clientPackageName, clientUid, rootHints)` entry;
- Vivo-client branch hit and root returned;
- `onLoadChildren(parentId, result)` entry;
- current-list branch hit;
- immediately before/after result delivery.

Only after the static MediaItem renders should the project proceed to real queue mapping and then `playFromMediaId`.