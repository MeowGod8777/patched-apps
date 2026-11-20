# Lenovo Legion Y700 4th gen / ColorOS 16 — generic rooted YouTube Music checkpoint

Date: 2026-09-04

## Product scope

Daily-use patched YouTube Music on the rooted Lenovo Legion Y700 4th gen. This branch is intentionally generic and must not inherit the iQOO 12 Pro / Vivo OriginPlayer cooperation delta.

## Device baseline from prior captured evidence

- model/device: `OPD2413` / `OP615EL1`
- Android: 16 / SDK 36
- build display ID: `OPD2413_16.0.8.300(CN01)`
- fingerprint: `OnePlus/OPD2413/OP615EL1:16/AP3A.240617.008/V.117e01a_12a5c38_12a5c37:user/release-keys`
- root: KernelSU (`uid=0`, `u:r:ksu:s0`, SELinux Enforcing)
- ABI: arm64 / aarch64
- historical GmsCore evidence (2026-07-22): `app.revanced.android.gms` was present and serving the existing ReVanced YouTube package.

Current YouTube Music / GmsCore package inventory still requires a minimal live re-check before flashing so existing data/settings are not destroyed by a version/signature replacement.

## Generic build contract

Config: `ytmusic-y700.toml`

- stock identity: `com.google.android.apps.youtube.music`
- version: `9.15.51`
- arch: `arm64-v8a`
- build mode: root module only
- stock inclusion: `auto`
- patches: `anddea/revanced-patches` `v4.2.0`
- CLI actually resolved by the successful run: `MorpheApp/morphe-desktop-1.15.0-all.jar`
- builder explicitly excluded `GmsCore support` in module mode
- no `com.luna.music`
- no VivoMusicWidgetMix service / controller-c0 / current-list / native mediaId / `support_event=0x9DF` / MEDIA_ID bridge

Explicit capability patches requested on top of defaults:

- Hide ads
- Remove background playback restrictions
- Force original audio
- Return YouTube Dislike
- SponsorBlock
- Video playback
- Bitrate default value
- Sanitize sharing links
- Third-party lyrics

The successful build applied 37 patches total because the Anddea bundle also applies its normal default patches.

## Build result

Workflow: `Build YT Music Y700 generic root`

- run: `33836401680`
- commit: `95f40ea271b2e810cc1c38096e1de1cd32165167`
- artifact: `9923436810` (`ytmusic-y700-generic-root`)
- module filename: `youtube-music-revanced-module-v9.15.51-arm64-v8a.zip`
- module SHA256: `4d50b64fc48089ede0c8a2089948ead181980069ad485fdf2b56018d274579c0`
- GitHub artifact wrapper SHA256: `1af7b0bbb1709d7dcf960093e4be97b4e7af507c809dbbc3534f7f700c9079a1`

Workflow fail-closed checks passed:

- exactly one expected root-module ZIP: PASS
- no APK emitted in `build/`: PASS
- package configuration in module: `com.google.android.apps.youtube.music`: PASS
- module arch: `arm64`: PASS
- GmsCore support patch disabled in module patch command: PASS

## Installation gate

Do not flash blindly if `com.google.android.apps.youtube.music` is already installed at a different version or with a non-Google signer. The module installer can replace stock when versions/signatures conflict, and a replacement can remove existing app data. First capture the minimal live package inventory and choose the preservation path.

Status: **BUILD PASS / DEVICE INSTALL + LOGIN + PLAYBACK VERIFICATION PENDING**.


## 2026-11-20 device incident update

The build itself remains provenance-valid, but the Y700 daily device later entered an abnormal reboot/package-code state during unrelated WFD testing.

Observed current package state:

```text
package = com.google.android.apps.youtube.music
versionName = 9.15.51
versionCode = 91551240
uid = u0_a405
PackageSetting = present
installed = true
recorded /data/app codePath = present in package metadata
physical recorded codePath = missing
CE data ≈ 121M
DE data ≈ 1.1M
```

The module reported:

```text
description=⚠️ Needs reflash: 'App not installed: '''
```

The existing patched payload survived with SHA-256:

```text
baefd91ef026e162ecec50533c9a3646a07b4e9d47251a5887ac9034b5946f3d
```

Interpretation:

- this is a package-code loss / PackageManager-codePath incident, not evidence that the app-private data was wiped;
- it occurred in the same broader device incident that removed LINE's underlying stock code path;
- causality must not be assigned to the YouTube Music module without further evidence.

Recovery policy:

1. backup CE/DE and PackageManager metadata;
2. recover the exact Google-signed 9.15.51 stock split set;
3. use replace-only PackageInstaller session semantics;
4. never use uninstall fallback;
5. verify UID/inodes/data preservation;
6. only then restore the ReVanced/RVHC bind mount.

Current status: **BUILD PASS / HISTORICAL DEVICE USE EXISTS / 2026-11-20 PACKAGE-CODE RECOVERY PENDING**.

See: `research/Y700_PATCHED_APP_CODEPATH_INCIDENT_2026-11-20.md`.


## 2026-11-20 launch-crash correction

The preservation recovery successfully reconstructed stock package identity without losing app data:

```text
stock APK SHA256 = a003ac2e673c2979b2268e5acfbfd74f88b93c4b75af5c7d604b3c7fb92768a4
appId = 10405 (unchanged)
CE inode = 439750 (unchanged)
DE inode = 301907 (unchanged)
versionCode = 91551240
versionName = 9.15.51
```

The surviving patched payload `baefd91e...` mounted successfully, but the app now crashes immediately:

```text
java.lang.UnsatisfiedLinkError:
dlopen failed: library "libelements.so" not found
```

The original 2026-09-04 build log is now relevant in a new way: the module build applied `Spoof video streams`.

An upstream MorpheApp root/mount issue with the same exception reported that excluding `Spoof video streams` fixed launch, and upstream maintainers stated that this patch was intended for MicroG/GmsCore users rather than root mount users.

Do not rebuild yet solely from that upstream result: this exact Y700 payload had historical working runtime before the 2026-11-20 package-code incident. First compare the reconstructed stock install's native-library materialization (`/data/app/.../lib/arm64`) against what the module expects, especially `libelements.so`.

Status: **PACKAGE IDENTITY RECOVERED / DATA PRESERVED / MOUNT PASS / LAUNCH FAIL: `libelements.so` / ROOT CAUSE UNDER NATIVE-LIB VS PATCH DIFFERENTIATION**.


## Native-library installation invariant recovered from source

The module build intentionally removes `lib/*` from the patched APK before patching. The original installer then extracts the stock APK's ABI libraries into:

```text
/data/app/<current-package-codePath>/lib/arm64
```

with owner/group `1000:1000`, mode `0755`, and SELinux context `u:object_r:apk_data_file:s0`.

The 2026-11-20 replace-only package reconstruction restored PackageManager identity/data but did not execute that module installer stage, leaving the new codePath's native-lib directory empty. This exactly explains:

```text
dlopen failed: library "libelements.so" not found
```

because:

- stock 9.15.51 APK contains `libelements.so`;
- the patched root payload contains no native libraries by design;
- the reconstructed installed native-lib directory was empty.

Current root-cause classification: **PACKAGE IDENTITY RECOVERED / NATIVE-LIB MATERIALIZATION MISSING / MINIMAL RESTORE REQUIRED**.
