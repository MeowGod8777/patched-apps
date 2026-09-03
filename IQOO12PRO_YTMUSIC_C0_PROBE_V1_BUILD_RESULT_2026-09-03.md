# iQOO 12 Pro / YT Music c0 browser probe v1 — build result

Date: 2026-09-03 (+08:00)

## Purpose

Probe v1 is a single-variable correction of the device-proven probe-v0 crash:

- keep Vivo cooperation manifest/root/list selector unchanged;
- keep static probe payload unchanged;
- keep `MediaBrowserCompat$MediaItem` unchanged;
- remove only the nonexistent `MediaDescriptionCompat$Builder` dependency;
- instantiate the APK's existing `MediaDescriptionCompat` directly via its public 8-argument constructor.

No real queue bridge or `playFromMediaId` is included yet.

## GitHub Actions

- workflow: `Build YT Music Luna Vivo c0 browser probe v1`
- run: `33760967214`
- head commit: `a9a2b3b56d334ab065bf84d6fd7a600364028771`
- artifact: `9895454194`
- artifact name: `ytmusic-luna-vivo-c0-browser-probe-v1`
- workflow conclusion: success

## Candidate

- filename: `YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V1.apk`
- package: `com.luna.music`
- versionName: `9.15.51`
- versionCode: `91551240`
- APK SHA256: `b65705c48bf4c2fcb074243696644b61ce17888489c581faadfcb6c48ec4a14d`

## Signature verification

Validated base signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Builder BKS signer SHA256:

`7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

Final APK:

- signer CN: `Morphe`
- signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`
- APK Signature Scheme v2: verified
- APK Signature Scheme v3: verified

Same-signer requirement: PASS.

## 16K alignment

Final `zipalign -c -P 16 -v 4` verification: PASS.

- arm64 `.so` entries checked: 21
- non-OK arm64 `.so` entries: 0

## Static cooperation verification

Manifest contains:

`com.vivo.musicwidgetmix.support.service` ✅

Existing service remains:

`com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService` ✅

Injected root/list markers remain:

- `VIVO_MUSIC_MIX_ROOT` ✅
- `vivomusicmix_current_list` ✅
- `vivo_probe_1` ✅
- title `YT Music Vivo Bridge` ✅
- subtitle `c0 cooperation probe` ✅

Probe-v1 description construction is exactly:

```smali
new-instance v1, Landroid/support/v4/media/MediaDescriptionCompat;
const-string v2, "vivo_probe_1"
const-string v3, "YT Music Vivo Bridge"
const-string v4, "c0 cooperation probe"
...
invoke-direct/range {v1 .. v9}, Landroid/support/v4/media/MediaDescriptionCompat;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Landroid/graphics/Bitmap;Landroid/net/Uri;Landroid/os/Bundle;Landroid/net/Uri;)V

new-instance v2, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;
const/4 v3, 0x2
invoke-direct {v2, v1, v3}, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;-><init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V
```

`MediaDescriptionCompat$Builder` reference in the patched browser-service context: absent ✅

## Build status

`decode -> patch -> rebuild -> 16K zipalign -> same signer -> APK signature verify -> manifest/static verify -> artifact upload` all PASS.

This candidate is therefore eligible for real-device testing under the project delivery rule.

## Device test criterion

The only required test for this round:

`OriginPlayer -> playlist button -> playlist UI`

Expected successful probe result:

- no `MediaDescriptionCompat$Builder` crash;
- `vivo_probe_1 / YT Music Vivo Bridge` renders as a list row.

If it renders, the static result-construction/delivery path is validated and the next candidate may replace the static row with the real YT Music current/upcoming queue.

If it still stays loading or crashes, collect the next exact logcat stack before altering queue mapping or switching the entire media type family.