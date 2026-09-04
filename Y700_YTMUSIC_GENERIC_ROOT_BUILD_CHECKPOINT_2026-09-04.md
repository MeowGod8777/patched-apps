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
