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

`LcmFeature` initializes `mSupportAppHdr` from feature `vivo.hardware.display.xdr_video`, attribute `app_hdr`. This directly links the system-server App HDR controller to the `app_hdr=true` device feature.

Current decompilation/xref evidence also shows:
- `AppHdrController.initAppHdrBinder()` registers a binder with SurfaceFlinger using the `android.ui.ISurfaceComposer` interface.
- `AppHdrController.onHdrInfoChanged(...)` posts HDR-layer information into controller logic and can call `setXdrEnabled(...)` / request XDR brightness refresh rate.
- `setXdrEnabled(...)` transacts directly with SurfaceFlinger.
- `isWhiteListPackage()` currently matches Youku-related package state and is used by the software `Sdr2HdrSwDisplayEnhanceController` path. Current evidence does **not** show Instagram being excluded from native HDR by this whitelist.

This shifts the working hypothesis away from an obvious vivo package whitelist and toward the upstream trigger: Instagram must actually deliver/report an HDR layer or HDR-capable rendition before the vivo App HDR controller enters XDR.

## Current working direction

Next priority is to distinguish:
1. Instagram on V2329A receives only an SDR rendition / reports SDR metadata; versus
2. Instagram receives HDR but fails to expose an HDR layer to SurfaceFlinger.

If (1), target Meta device/capability eligibility and rendition selection in the patched APK.
If (2), target Instagram Surface/headroom presentation and vivo App HDR interaction.

Do not return to blind one-by-one MetaConfig flag testing unless new evidence points to a specific flag.
