# Instagram 439 Groot HDR surface gate — exact R8 reverse engineering

Status: exact-build/source-side finding, pending one runtime A/B validation

Target artifact:
- Instagram `439.0.0.37.89`
- Piko `3.9.0`
- Release 8 APK SHA-256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`
- Device under test: iQOO 12 Pro V2329A / Android 16 (API 36)

## Runtime baseline

The V2329A display/framework HDR path is functional. YouTube HDR raises `hdrSdrRatio` well above 1, while Instagram remains at `hdrSdrRatio=1.0`.

The full Instagram SurfaceFlinger/HWC probe shows the currently visible Instagram modal surfaces as `RGBA_8888_UBWC`, `V0_SRGB`, with display `dynamic_range: SDR`. Therefore the vivo XDR/App-HDR service is not receiving a currently active HDR layer from Instagram.

## Exact MobileConfig mapping

Piko 439 mapping identifies:

```text
ig4a_groot_surface_optimization::enable_hdr_sdr_ratio
universalId = 74463
paramId = 20
```

Piko's human-readable mapping is external metadata; the production Instagram DEX does not contain the flag name as a normal string.

Exact 439 `ExperimentParameter` decoding was recovered from the Release 8 DEX:

```text
X.04Kj.A02()
  -> X.00Al.A00(long)
```

`X.00Al.A00(J)I` decodes the universal ID with:

```text
rawTable = (specifier >>> 54) & 0x3f
index    = (specifier >>> 32) & 0xffff
if rawTable < 3: effectiveTable = 1
universalId = A0B[effectiveTable][index]
```

The `A01` universal-ID table contains 5,583 entries. Universal ID `74463` occurs uniquely at index `1698`.

Scanning all 21 Release 8 DEX files for MobileConfig constants matching `(universalId=74463,paramId=20)` produced one unique constant:

```text
0x008106a20014205d
```

Decoded properties:
- raw table = 2 (effective table = 1)
- index = 1698
- parameter = 20
- type = Boolean

## Unique exact-439 consumer

The raw specifier occurs once in `classes15.dex`, in:

```text
X.02Ug.A00:(LX/02g4;)LX/02Vh;
```

The method identifies itself with:

```text
IgGrootPlayer.createSurfaceViewSurfaceController
```

The relevant logic is equivalent to:

```java
if (mobileConfig(74463, 20)) {
    config.A07 = Build.VERSION.SDK_INT >= 35;
}
```

Therefore on the iQOO 12 Pro running Android 16 / API 36:

```text
enable_hdr_sdr_ratio=true -> X.02g4.A07=true
```

## What `X.02g4.A07` actually controls

There are three exact references in the Release 8 DEX set:

1. The write above in `IgGrootPlayer.createSurfaceViewSurfaceController`.
2. A debug/config map export naming `A07` as:

```text
sc_applyDesiredHdrSdrRatio
```

The same map exposes a fixed ratio:

```text
sc_desiredHdrSdrRatio = 1.5
```

3. A runtime read in `X.02q6.B0T(...)` while creating/configuring the `SurfaceView`.

For API >= 35, if `A07` is true, Instagram executes:

```text
SurfaceView.setDesiredHdrHeadroom(1.5f)
new X.06EM(config).A03(surfaceControl)
new X.06EM(config).A02(surfaceControl)
```

`X.06EM.A03(surfaceControl)` is exactly:

```text
SurfaceControl.Transaction.setDesiredHdrHeadroom(surfaceControl, 1.5f)
```

`X.06EM.A02(surfaceControl)` immediately applies and closes that transaction.

Thus `74463::20` is not a telemetry-only flag. On API 35+ it directly enables Instagram Groot's SurfaceView / SurfaceControl HDR-headroom application path.

## Interpretation / limit

This is a real presentation-path gate, but it must not be overclaimed as a complete HDR enable switch.

Android's API semantics define `setDesiredHdrHeadroom` as specifying desired headroom for a layer / SurfaceView when HDR content is presented. It does not itself convert an SDR buffer or SDR rendition into HDR.

Therefore forcing `74463::20=true` is now a high-information A/B test:

- If V2329A begins presenting HDR (`hdrSdrRatio > 1`) on known HDR Instagram content, the missing Groot headroom gate is a concrete repair target and can be baked into a follow-up patch.
- If it remains SDR, the headroom gate is necessary/available but insufficient; investigation should move upstream to HDR rendition/input-transfer/output-renderer selection rather than continuing random MetaConfig toggles.

## Generated evidence

Supporting generated reports in this repository:
- `research/generated/instagram_439_hdr_decoder_methods.txt`
- `research/generated/instagram_439_hdr_specifier_trace.txt`
- `research/generated/instagram_439_hdr_consumer.txt`
- `research/generated/instagram_439_hdr_a07_consumers.txt`
- `research/generated/instagram_439_hdr_transaction_trace.txt`
