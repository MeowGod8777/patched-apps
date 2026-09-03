# iQOO 12 Pro / YT Music c0 browser probe v1 — device PASS

Date: 2026-09-03 (+08:00)

## Device

- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build: `PD2329B_A_16.2.19.1.W10.V0101L17`

## Build under test

- package: `com.luna.music`
- version: `9.15.51`
- candidate: `YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V1.apk`
- workflow run: `33760967214`
- artifact: `9895454194`
- APK SHA256: `b65705c48bf4c2fcb074243696644b61ce17888489c581faadfcb6c48ec4a14d`

## Real-device result

PASS.

OriginPlayer playlist UI opens and renders the injected static item:

- title: `YT Music Vivo Bridge`
- subtitle: `c0 cooperation probe`
- mediaId: `vivo_probe_1`

The app does not crash.

This device result closes the previously unresolved browse/render boundary.

## Now device-validated

The following end-to-end path is proven on the target device:

`com.vivo.musicwidgetmix.support.service`
-> Vivo custom-insert / `controller/c0`
-> bind patched YT Music `MusicBrowserService`
-> Vivo root negotiation
-> `VIVO_MUSIC_MIX_ROOT`
-> browse request containing `vivomusicmix_current_list`
-> injected `onLoadChildren` branch
-> result delivery through YT Music's legacy compat result wrapper
-> `MediaBrowserCompat.MediaItem`
-> Vivo playlist row render

All of the above are now VERIFIED by real-device behavior, not only static RE.

## Important scope

The one-row playlist is expected for probe v1. It is not a defect in this candidate: v1 deliberately returns only one static item and does not yet bridge the real YT Music queue.

The next phase is therefore real queue exposure, not more c0/root/browse probing.

## Separate observation: missing time labels

The same screenshots show that OriginPlayer's progress bar does not display elapsed/duration numeric labels. The user reports this appears to have already been present on the previous probe as well.

Do not conflate this with playlist browse success. Treat it as a separate presentation issue unless later evidence proves a common cause.

## Next step

Build the first real-queue candidate while preserving the now-proven c0 transport unchanged.

Target for the next candidate:

- replace only the static `vivo_probe_1` list with real YT Music current + upcoming queue data;
- preserve `support.service`, `VIVO_MUSIC_MIX_ROOT`, `vivomusicmix_current_list` routing, and result-delivery mechanism unchanged;
- expose stable mediaId + title + artist/subtitle for each item;
- do NOT implement `playFromMediaId` in the same candidate unless required to obtain queue data;
- first verify real rows render; then test item selection as a separate phase.

Maintain single-variable progression.