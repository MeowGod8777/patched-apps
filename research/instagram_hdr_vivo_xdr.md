# Instagram HDR on iQOO 12 Pro — vivo XDR reverse engineering

Status: active investigation (2026-08-31)

Target device/build:
- iQOO 12 Pro / V2329A
- Android 16
- build `PD2329B_A_16.2.19.1.W10.V0101L17`

Instagram test build:
- Instagram `439.0.0.37.89`
- Piko `3.9.0`
- Release 8 keeps official package `com.instagram.android`

## Runtime facts already established

- Panel/framework HDR capability is present: HDR10 / HLG / HDR10+ are exposed by `DisplayDeviceInfo`.
- YouTube HDR is a positive control and drives `hdrSdrRatio` well above 1 (`~3.96-4.98` observed).
- Instagram on the 12 Pro remains at `hdrSdrRatio = 1.0` in current tests.
- MetaConfig experiments already tested without restoring HDR include `enable_hdr_on_fragment=ON`, `probability=1.0`, timeline HDR preview, and `uhdr always on`.
- Release 8 deep-link regression is fixed by adding Piko `Validate links`.

## vivo / OriginOS feature evidence

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

Runtime properties confirm XDR support is exported to zygote/app-visible properties:

```text
ro.vendor.vivo.hardware.display.xdr=1
ro.vendor.vivo.hardware.display.xdr:hdrui=true
ro.vendor.vivo.hardware.display.xdr:is_support_zygote=1
ro.vendor.vivo.hardware.display.xdr:ultrahdrsyncbrightness=true
ro.vendor.vivo.hardware.display.xdr:version=v3.0
ro.vendor.vivo.hardware.display.xdr:vivo-support=1
```

`BrightnessPolicy.json` contains Instagram under a level-3 app category, but `PolicyStatus=false`; current evidence therefore does **not** support treating that file as the HDR gate.

`vivo_displayic_policy.xml` is mainly display-enhancement policy (`memc`, `sdr2hdr`, `nr`, `aisr`) and is currently considered separate from native HDR playback.

## Framework artifacts

User-supplied system framework jars were inspected locally; binaries are **not** committed to this repo.

SHA-256:

```text
vivo-framework.jar  2a664b4461da8ff902cdc519465aa2591fed21eb6810a3a46bf0a7f31dd26f00
vivo-services.jar   13d7f79cdbc660e4a07ee482fc7eade6b2b7e3d6aeb71fff2fc9c8091041106c
```

DEX layout:
- `vivo-framework.jar`: `classes.dex`
- `vivo-services.jar`: `classes.dex`, `classes2.dex`

## Reverse-engineering findings

### `vivo-framework.jar`

Relevant API/symbols include:
- `setUltraHdrMode`
- `setXdrMode`
- `notifyXdrModeToDriver`
- `notifyXdrRealBrightness`
- `isUltraHdrUiSupport`
- `getXdrLcmBrightness`

This establishes a vivo framework-level XDR API path above the lower display driver layer.

### `vivo-services.jar`: feature initialization

`com.android.server.display.common.config.LcmFeature` initializes `mSupportAppHdr` by reading:

```text
feature   = vivo.hardware.display.xdr_video
attribute = app_hdr
```

The value is obtained through `FtFeature.getFeatureAttribute(...)`. On this V2329A build, `/vendor/etc/vivo_config.ini` contains `app_hdr=true`, so the ROM-side App HDR feature gate is present/enabled.

`VivoLcmBrightnessManager` copies `LcmFeature.mSupportXdrVideo` / `mSupportXdrPhoto` into its own static support flags and creates a `SurfaceControlHdrLayerInfoListener` when the XDR path is supported.

### `vivo-services.jar`: `AppHdrController`

A concrete system-server implementation exists at:

`com.android.server.display.color.AppHdrController`

Important symbols include:
- `COLOR_MODE_APP_HDR`
- `mSupportAppHdr`
- `mInHdrVideoStage`
- `mIsHdrLayerPresent`
- `mHdrType`
- `mHdrInfoFlags`
- `setXdrEnabled(boolean)`
- `setVideoBrightenMultiple(float)`
- `onHdrInfoChanged(...)`
- `updateAppHDRState(boolean)`
- `registerAppHdrCallBack(...)`
- `isSupportAppHdr()`
- `isWhiteListPackage()` / `isWhiteListActivity()`

Verified call path:

```text
SurfaceControlHdrLayerInfoListener
  -> VivoLcmBrightnessManager.HdrListener.onHdrInfoChanged(...)
  -> AppHdrController.onHdrInfoChanged(...)
  -> AppHdrController.lambda$onHdrInfoChanged$0(...)
  -> setXdrEnabled(...) / requestXdrBrightnessRefreshRate()
  -> SurfaceFlinger transaction
```

`AppHdrController.initAppHdrBinder()` also registers an App-HDR binder with SurfaceFlinger through the `android.ui.ISurfaceComposer` interface. `setXdrEnabled(...)` and `setVideoBrightenMultiple(...)` both transact directly with SurfaceFlinger.

The internal binder can receive XDR config (sync-brightness and XDR-FPS booleans), HDR-video-stage changes, LCM nit changes, and then calls `updateAppHDRState(...)` as required.

### Package whitelist finding

`AppHdrController.isWhiteListPackage()` currently checks Youku-specific package state (`com.youku.phone`) and `isWhiteListActivity()` checks Youku/test activities. Those checks are referenced by `handlerAppHdrColorMode(...)`, which enters/exits `Sdr2HdrSwDisplayEnhanceController`.

Therefore this whitelist belongs to the **software SDR -> HDR enhancement path**, not the generic native HDR-layer detection path above.

**No evidence was found that `com.instagram.android` is blocked by a vivo native-HDR package whitelist.** This substantially lowers the probability of an OEM whitelist being the root cause.

### DisplayManager service exposure

`VivoDisplayManagerServiceImpl` exposes thin wrappers around the controller for:
- `isSupportAppHdr()`
- `setAppHdrStatus(int)`
- `registerAppHdrCallBack(packageName, callback)`
- `unregisterAppHdrCallBack(packageName, callback)`

The service methods delegate directly to `AppHdrController`.

## Current interpretation

The vivo side is not showing an obvious `Instagram -> denied` policy. Instead, native XDR activation is driven by SurfaceFlinger HDR-layer information. That means a normal third-party app does **not** appear to need to be in a vivo package whitelist merely to present native HDR.

This shifts the primary root-cause hypothesis upstream:

1. Instagram on V2329A is selecting an SDR rendition / classifying the device as not eligible for HDR; or
2. Instagram receives HDR media but creates a Surface/layer whose dataspace / HDR metadata / desired headroom is not recognized as HDR by SurfaceFlinger.

The previous idea of forcing a vivo whitelist is therefore no longer the primary repair route.

## Media-path probe #1: `media.metrics`

A first runtime probe used `dumpsys media.metrics --all` while Instagram content was being tested. The returned matching records were only `audio/vorbis` codec/extractor entries owned by `media`, `android.uid.systemui`, and `jp.naver.line.android`.

**No `com.instagram.android` video codec entry and no video color-transfer / HDR metadata entry were captured.**

Therefore this probe is **inconclusive** and must not be interpreted as evidence that Instagram selected an SDR rendition. It indicates only that `media.metrics` did not expose the relevant Instagram video decode path in this session.

## Media-path probe #2: controlled codec logcat

`dumpsys media.codec` is not available on this Android 16 V2329A build (`Can't find service: media.codec`), so that route is dropped.

A controlled logcat capture after restarting target Instagram playback **did** capture the active video decoder path:

```text
MediaCodec: [c2.qti.av1.decoder] setting surface generation ...
CCodec: Created component [c2.qti.av1.decoder]
```

The same process also initialized `c2.android.aac.decoder` for audio. The video path is therefore confirmed to use the Qualcomm hardware AV1 decoder on this session/content.

This is useful but **not sufficient to classify SDR vs HDR**: AV1 can carry either SDR or HDR. The next probe must extract AV1 decoder color aspects / output dataspace, especially transfer, primaries, matrix/range, HDR static metadata, or SurfaceFlinger layer dataspace.

## Current repair direction

Next high-information check is the AV1 decoder/render metadata rather than more MetaConfig toggles:

- determine the selected decoder color transfer / dataspace for the active `c2.qti.av1.decoder` session;
- if V2329A receives SDR, patch/spoof Meta device capability / HDR rendition eligibility;
- if V2329A receives HDR but SurfaceFlinger sees no HDR layer, patch Instagram Surface/headroom presentation.

Do not return to blind one-by-one MetaConfig flag testing unless new evidence points to a specific flag.
