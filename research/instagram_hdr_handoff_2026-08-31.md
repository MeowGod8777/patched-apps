# Instagram HDR on iQOO 12 Pro — current handoff (2026-08-31)

Status: active investigation. This file is the preferred continuation entry point.

## Target

Device:
- iQOO 12 Pro / V2329A
- Android 16
- build `PD2329B_A_16.2.19.1.W10.V0101L17`

Patched Instagram under test:
- Instagram `439.0.0.37.89`
- Piko `3.9.0`
- Release 8 package: `com.instagram.android`
- R8 SHA256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`
- R8 includes Piko `Validate links`; deep links are runtime-confirmed fixed.

Official control APK prepared for next test:
- official Instagram `439.0.0.37.89`
- versionCode `384510833`
- arm64-v8a
- split package contains base `com.instagram.android.apk` + `config.xxxhdpi.apk`
- purpose: exact-version control against R8 before testing latest official Instagram.

## What is already proven

### 1. 12 Pro system HDR path works

The physical display/framework exposes HDR10 / HLG / HDR10+.

YouTube HDR is a positive control and raises `hdrSdrRatio` well above 1 (`~3.96-4.98` observed). Therefore the panel, Android HDR presentation path, SurfaceFlinger and vivo display stack are capable of real HDR on this device.

Do not reopen the hypothesis that the phone globally cannot display HDR.

### 2. Instagram on 12 Pro is currently presented as SDR

During controlled Instagram playback:
- Instagram explicitly uses `c2.qti.av1.decoder` through hardware AV1 decode.
- SurfaceFlinger/HWC shows the current Instagram modal layers as `RGBA_8888_UBWC` with `V0_SRGB` dataspace.
- current HWC/display dynamic range is `SDR`.
- Instagram tests remain at `hdrSdrRatio = 1.0`.

Therefore the vivo XDR/AppHdr path is not being given an active HDR layer for the tested Instagram frame.

This is the strongest current runtime conclusion.

### 3. Remaining ambiguity is upstream of SurfaceFlinger

Still not distinguished:

A. Meta/Instagram selects an SDR rendition for V2329A / the current runtime bucket; or

B. Instagram receives HDR-capable media but its own playback/render path tone-maps/composites it into an SDR app surface before SurfaceFlinger.

Do not state that server-side SDR rendition is already proven.

## vivo / OriginOS findings

`/vendor/etc/vivo_config.ini` exposes:

```ini
[vivo.hardware.display.xdr]
version=v3.0
hdrui=true
ultraHdrSyncBrightness=true
is_support_zygote=1

[vivo.hardware.display.xdr_video]
app_hdr=true
```

Reverse engineering of `vivo-services.jar` found `AppHdrController` and the call path from SurfaceFlinger HDR-layer callbacks into vivo XDR state.

Important result:
- the obvious package/activity whitelist found in `AppHdrController` is associated with software SDR->HDR enhancement / Youku handling, not generic native HDR layer admission.
- no evidence currently shows `com.instagram.android` being blocked by a vivo native-HDR package whitelist.

Therefore forcing a vivo app whitelist is no longer the primary repair route.

`BrightnessPolicy.json` is also not the current HDR gate (`PolicyStatus=false`; semantics are brightness/max-nit policy).

## MetaConfig flags already tested — do not repeat blindly

Already tested without restoring HDR:
- `android14 ultra hdr consumption -> enable_hdr_on_fragment = ON`
- `android14 ultra hdr consumption -> probability = 1.0`
- `uhdr always on -> is_enabled = ON`
- `uhdr always on -> window_head_room = 1.7` unchanged
- `basel android -> enable_timeline_hdr_preview = ON`

Keep `enable_sdr_to_hdr_view_booster` OFF during true-HDR diagnosis. It is an SDR->HDR boost and contaminates the test.

Do not repeat these one-by-one tests unless new source evidence specifically changes their meaning.

## Media probes already attempted

Do not repeat:
- `dumpsys media.metrics --all`: no useful Instagram video entry; inconclusive.
- `dumpsys media.codec`: service does not exist on this Android 16 build.

Useful probe already obtained:
- Instagram-owned logcat confirms hardware AV1 decode via `c2.qti.av1.decoder`.

AV1 alone does not prove HDR vs SDR.

## Exact Instagram 439 / Piko static work

### Mapping anchor

Piko mapping for Instagram 439 identifies:

```text
ig4a_groot_surface_optimization
  experiment/universal ID: 74463
  enable_hdr_sdr_ratio: param 20
```

Compact identifier: `74463::20`.

This is a useful exact-439 anchor, but it is NOT yet a proven HDR repair switch.

Possible interpretations still include:
- true HDR-output / presentation gate; or
- a downstream optimization/ratio-sync flag that only matters after HDR is already active.

Do not treat `74463::20=true` as the solution without consumer semantics or a discriminating test.

### Piko MobileConfig hook capability

Piko already has a generic boolean MobileConfig hook:
- `HookFlagsPatch.kt` intercepts boolean flag queries.
- `HookFlags.handleBoolFlags(long mobileConfigSpecifier)` can override by universal ID / `universalId::paramId`.
- `Unlock developer options` depends on this hook, so R8 already contains the interception infrastructure.

Therefore, if later evidence justifies it, forcing `74463::20=true` can be implemented cleanly without hard-patching an obfuscated renderer branch.

### Important reverse-engineering correction

Do NOT chase the literal class name `X.0B3D` as the MobileConfig decoder.

Exact R8 disassembly showed the 439 native `X.0B3D` is an unrelated UI `Function0` class.

Piko source uses placeholder class/method strings and rewrites them during patching using fingerprints. `DeveloperOptionEntity.kt` shows the real process:

1. locate the Instagram method containing:
   - `ExperimentParameter`
   - `Failed to get config key with specifier:%d`
2. inspect its first `INVOKE_STATIC`
3. rewrite the extension helper to the actual defining class for that Instagram version.

An exact-R8 GitHub Actions probe now follows this fingerprint against the SHA-verified R8 APK. The human-readable mapping names are external metadata and are not present as plaintext in production DEX.

Temporary analysis workflows added during this investigation:
- `.github/workflows/ig-hdr-decompile.yml`
- `.github/workflows/ig-hdr-dexdump.yml`

Relevant research/debug commits include:
- `5ac71075c591dc092040d7d3030bca506f2dd9f4` — exact 439 decompile probe
- `e022ff5ab5d6bdb6a6126d24a5a05c81f3409c9e` — fast DEX probe
- `6d899e5e6b0340b478deb80763298ddbe9eddb33` — MobileConfig decoder trace attempt
- `041f4f0a476481cf93f02bf791b6f7efd843014d` — fix probe SIGPIPE
- `4611ae3a8207a145c01ac4b1e6c0e5f0164badda` — exact helper extraction
- `b1304f1c09f7a8c6b6b273957b5d42d22a45db19` — fix report commit order
- `435803920b83909399a887e384f231cc797f51ce` — trace exact Piko MobileConfig fingerprint

Generated report:
- `research/generated/instagram_439_hdr_fast_dex_report.txt`

## Public-case guidance

The overall research direction is not purely speculative, but there is no known public case of "iQOO 12 Pro + IG 439 + Piko + this exact flag" being repaired already.

Useful precedent classes:

1. OEM-side package HDR gates exist in the wild. Example: OnePlus 13 community HDR-enabler modules add app packages such as Instagram to OEM HDR/Dolby Vision configuration. This justified checking vivo policy, but current V2329A evidence does not match a simple whitelist block.

2. Modded/Piko Instagram can still display HDR on other devices. Therefore Piko/re-signing is not universally incompatible with Instagram HDR.

3. Instagram HDR support can vary by device/runtime/rollout and has appeared/disappeared on devices without a simple hardware explanation. This supports keeping Meta device eligibility / MobileConfig / rendition selection as a high-priority hypothesis.

4. Meta engineering documentation explicitly describes Instagram HDR playback and client-side HDR/SDR tone mapping. Therefore investigating Instagram's own rendition/render branch is grounded in the actual product architecture.

## Research-direction correction

The prior work became too narrow around `74463::20`. Current rule:

- keep `74463::20` as one precise candidate anchor;
- do NOT assume it is the root cause;
- prioritize tests that eliminate entire branches of the hypothesis tree.

Do not return to serial blind MetaConfig toggling.

## NEXT STEP — highest priority

Before further deep reverse engineering, perform the exact-version official control:

```text
same iQOO 12 Pro
same account
same ROM/build
same known test content
R8 Piko 439.0.0.37.89
vs
official 439.0.0.37.89
```

This is currently the highest-information real-device test.

Interpretation:

### Official 439 shows HDR

Then the problem is APK-side:
- Piko patch set
- re-sign/build behavior
- a patch interaction
- possibly signature-dependent/runtime behavior

Stop prioritizing vivo device eligibility until the patched-vs-official difference is isolated.

### Official 439 remains SDR

Then R8/Piko/re-signing becomes much lower priority.

Next controlled step: test official latest Instagram on the same 12 Pro.

- official latest HDR while official 439 SDR -> version/rollout behavior is important.
- official latest also SDR -> prioritize Meta device/runtime eligibility, rendition selection, or 12 Pro-specific Instagram presentation behavior.

### Only after that, use Turbo when useful

Turbo is a valid positive reference because Instagram has been observed entering HDR (`hdrSdrRatio > 1`) on some content there. However it changes device/ROM/platform simultaneously, so the same-device official-vs-R8 control is cleaner and should come first.

## Testing philosophy for continuation

Phone testing is allowed and useful. Do not avoid it artificially.

But request a device test only when it:
- discriminates between major root-cause branches; or
- validates a concrete patch/conclusion.

Do not ask for repetitive ratio checks or one-flag-at-a-time experiments with low information gain.

When giving shell commands for the phone, NEVER prefix them with `adb shell`.

## Current compact state

```text
12 Pro system HDR works                         CONFIRMED
Instagram R8 current presentation is SDR       CONFIRMED
vivo simple native-HDR package block           NOT SUPPORTED / LOW PRIORITY
AV1 hardware decode in Instagram               CONFIRMED
HDR vs SDR source rendition                    UNKNOWN
IG internal tone-map to SDR                    POSSIBLE
Meta device/runtime eligibility                POSSIBLE / HIGH PRIORITY
74463::20 is exact 439 Groot-related flag       CONFIRMED
74463::20 is the repair switch                  NOT PROVEN
R8/Piko/re-signing causes the failure           UNKNOWN
official exact 439 control                      NEXT TEST
```

Primary rule for the next session: do the official exact-439 control first, interpret that result, then choose the next branch. Do not resume broad HDR archaeology before this control is resolved.
