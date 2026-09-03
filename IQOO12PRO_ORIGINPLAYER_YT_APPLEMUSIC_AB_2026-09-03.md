# iQOO 12 Pro OriginPlayer — YouTube Apple Music identity A/B

Date: 2026-09-03

Device target:

```text
iQOO 12 Pro / V2329A / PD2329
Android 16 / OriginOS 6 CN
PD2329B_A_16.2.19.1.W10.V0101L17
OriginPlayer com.vivo.musicwidgetmix 6.2.7.1
```

## Goal

Test whether changing a non-root patched YouTube package identity from the generic ReVanced package to an identity that the exact VivoMusicWidgetMix APK classifies as a framework-support / lock-cooperation music app is sufficient to move YouTube from the generic OriginPlayer path toward the richer music lockscreen path used by Ghost Player.

First test identity:

```text
com.apple.android.music
```

The package was confirmed FREE on the target V2329A before building.

## Build path

Dedicated files:

```text
originplayer-test.toml
.github/workflows/build-youtube-origin-test.yml
```

The first forced `20.40.45` run failed only because no configured stock source could supply that exact stock APK. The patch option itself did not fail.

The second run changed the test config to `version = "auto"`. anddea 4.2.0 selected a supported/downloadable YouTube stock version:

```text
YouTube: 20.51.39
Patches: anddea/revanced-patches 4.2.0
CLI: MorpheApp/morphe-desktop 1.14.0
GmsCore support option: packageNameYouTube=com.apple.android.music
Applied patches: 65
```

The Morphe log reached `Post-processing package name change`, aligned, signed, and saved successfully.

Output:

```text
youtube-origintest-originplayertest-v20.51.39-all.apk
size: ~115 MiB
SHA-256: b4921cc76a8e6e36d956ef63231c7b0256071c1da072d54822ed0350d9f8a281
```

Workflow run:

```text
33715141556
```

Prerelease tag:

```text
originplayer-test-33715141556
```

Release asset is intentionally marked as a one-off A/B test, not a production replacement.

## Static verification of built APK

After downloading the workflow artifact, the binary AndroidManifest string pool contains:

```text
com.apple.android.music
com.apple.android.music.SuggestionProvider
com.apple.android.music.fileprovider
com.apple.android.music.permission.C2D_MESSAGE
app.revanced.android.gms
app.revanced.android.c2dm.permission.RECEIVE
```

This confirms that the package-name/GmsCore manifest transformation was actually emitted into the built artifact rather than only passed as a CLI argument.

## Runtime test protocol

Do **not** change `musicwidget_list_pkg_type_key` for the first pass. Keep the existing daily YouTube `app.revanced.android.youtube` installed.

Install the test APK and verify:

1. Test APK installs alongside the existing YouTube.
2. It launches and can use the current MicroG-RE/GmsCore account path.
3. Normal video/audio/background playback works.
4. OriginPlayer detects the test APK without manually adding it to `musicwidget_list_pkg_type_key`.
5. Compare lockscreen UI against:
   - current direct-whitelisted YouTube generic card;
   - Ghost Player `com.kugou.android.lite` rich music card.
6. Check play/pause/next/previous, progress, artwork, and cleanup after stopping/force-closing.
7. Only after the basic classification result is known, test Origin Isle / Wavelet / external YouTube links.

## Interpretation

- If the test APK is automatically detected and gets the richer music lockscreen template, package identity is sufficient (or a dominant part) of the missing Vivo classification path.
- If automatically detected but still renders the generic card, framework-support controller routing alone is not sufficient; next inspect metadata/control capabilities/template branch conditions.
- If it is not automatically detected, re-check the exact `framework_support_list` / eligibility validator relationship before touching settings.
- If login/GmsCore breaks, treat that separately from OriginPlayer classification; the APK build itself successfully applied the GmsCore package rewrite.
