# Instagram 439 HDR handoff — 2026-09-02

## Scope

Target device: iQOO 12 Pro / V2329A, Android 16, build `PD2329B_A_16.2.19.1.W10.V0101L17`.

Target Instagram/Piko base:

- Instagram `439.0.0.37.89`
- Piko `3.9.0`
- package `com.instagram.android`
- exact base APK SHA256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`

Goal: make Reels receive a genuine HDR rendition. Success must begin at the raw `video_dash_manifest`: 10-bit AV1/HEVC plus HDR color signalling (BT.2020 + PQ/ST2084 or HLG), followed by `hdrSdrRatio > 1` at display time.

This file supersedes `research/instagram_hdr_handoff_2026-08-31.md` as the current continuation point.

---

## User-validated ground truth

### R6/R6v2

Instrumentation proved the raw `video_dash_manifest` returned to V2329A is already SDR-only:

- `MatrixCoefficients=1`
- `ColourPrimaries=1`
- `TransferCharacteristics=1`
- AV1 representations are `.08` / 8-bit BT.709 SDR

Therefore parser, renderer selector, decoder and Surface/display are not stripping HDR after receipt; HDR is absent in the delivered media representation set.

### R17

R17 changed only the Instagram network UA result to a Galaxy S24 Ultra-style identity (`samsung / SM-S928B / e3q`) while retaining the raw MPD logger.

User test result: raw MPD remained SDR-only.

**Conclusion:** UA/model-only backend classification is falsified for this device/build/account context.

---

## Permanently closed / demoted paths

Do not restart these without new contradictory evidence:

- Android/vivo HDR display pipeline: proven working with YouTube HDR.
- AV1 Main10/HDR10/HDR10+ decoder support: proven supported by `c2.qti.av1.decoder`.
- Instagram codec capability collector: already reports AV1 HDR support.
- Media3 renderer compatibility gate.
- vivo XDR/native HDR whitelist/Surface `desiredHdrHeadroom`.
- `X.0D2R.A08()` Dolby Vision display telemetry.
- `74463::20 / enable_hdr_sdr_ratio` downstream Surface behavior.
- local renderer/representation selection: R4 showed every candidate was already SDR.
- blind MetaConfig flag roulette.
- S24 camera/profile allowlist.
- `ig_device_static_attributes` / `X.0Uiy.run()` as a synchronous playback gate.
- `LX/0knW` HDR reporter (QPL telemetry).
- `LX/0lAl` MediaCodecInfoReporter telemetry.
- fixed `X-IG-Capabilities: 3brTv10=` as a device HDR capability encoding.

---

## R19e → R19g: exact Clips streaming request

R19e proved `com.instagram.clips.api.ClipsApiUtilHelper.A06(...)` is a real Reels/Clips streaming media request builder for `clips/items/`.

Proven high-value callers include:

- `LX/01Jw.A06()` — `ClipsViewerPrefetcher_executeStreamingPrefetchRequest`
- `LX/01Jv.A03()` — `ClipsHeadMediaInsertionHelper_loadSourceMediaAsFlow`

Explicit A06 request fields are:

- `clips_media_ids`
- `container_module`
- optional `prepend_media_repost_author_ids`
- optional `X-IG-Accept-Hint: feed`

R19g then resolved `X-IG-Accept-Hint` exactly:

- integer `1` -> `image-grid`
- all other values -> `feed`

There is no exact-build evidence for hidden `hdr`, `video`, `high-quality`, codec or rendition values in this header.

**Decision:** do not patch `X-IG-Accept-Hint` or A06 local parameters as an HDR experiment.

Relevant files:

- `.github/workflows/ig-hdr-clips-items-a06-r19e.yml`
- `research/generated/instagram_439_hdr_clips_items_a06_r19e.txt`
- `research/instagram_439_hdr_r19g_conclusion.md`

---

## R19j/R19m: real request finalization chain

Exact end-to-end construction chain is proven:

`ClipsApiUtilHelper.A06()`
→ `LX/02pu.A0K()`
→ `LX/02tw.A00(...)`
→ `LX/02uA.call()` (`buildApiRequest <path>`)
→ `LX/03u7.A04()`
→ `LX/03u7.A01(...)`
→ final first-party Instagram HTTP request.

`LX/03u7.A01()` adds ordinary session/network/device identity metadata including bandwidth, locale, stable device IDs, session visitation, endpoint, attestation and foldable status.

No explicit synchronous request header for the following was found in the ordinary finalizer path:

- model/manufacturer
- HDR capability
- codec/decoder profile
- display HDR
- HDR rendition eligibility
- video quality/resolution lane

The conditional streaming callback `LX/02ug` is response-side `ClientHintsStreamingApiCallback.onNewDataInBackground`, not the missing request eligibility producer.

Relevant file:

- `research/instagram_439_hdr_r19j_m_conclusion.md`

---

## R19l2: `device_status` becomes the real request-side candidate

The `com.facebook.devicesegmentation` machinery feeding `ig_device_static_attributes` is confirmed to be a local device-static-attribute telemetry pipeline. It contains HDR/decoder/codec fields, but that alone does not make it the synchronous rendition gate.

Separately, exact `LX/03u7.A04()` contains an actual request parameter named `device_status` and explicitly gates it for media routes including:

- `clips/`
- `feed/reels_media`
- feed/user/discover/injected reels/ads surfaces

This path is distinct from `ig_device_static_attributes` and is part of real API request finalization.

Relevant file:

- `research/instagram_439_hdr_r19l2_conclusion.md`

---

## R19o: Meta architecture evidence

Meta's own Reels engineering documentation materially supports a non-UA, non-literal-HDR-flag delivery architecture:

- Android devices are benchmarked with compute/memory/rendering tests.
- Meta derives a performance score/group rather than trusting model/spec fields alone.
- A/B testing is used to determine which device groups can receive 720p, 1080p and **10-bit HDR** playback.
- HDR uploads have both HDR and tone-mapped SDR representations server-side; unsupported/ineligible devices receive only SDR.

This directly matches the V2329A observation that the raw MPD is SDR-only.

Current strong architecture candidate:

`device capability / benchmark signals -> Meta eligibility classification -> server-side rendition filtering -> SDR-only or HDR-capable MPD`

Relevant file:

- `research/instagram_hdr_meta_benchmark_delivery_evidence_r19o.md`

Unknowns that remain:

- exact score/group derivation in Instagram 439
- whether classification is client-side, server-side, or hybrid
- exact identity join between benchmark/device profile and a Reels request
- exact threshold/group for 10-bit HDR

Do not falsify benchmark values or rotate/spoof device IDs until a join is proven.

---

## R19p2: exact HDR-relevant `device_status` producers

The generated R19p2 trace identifies exact producers for HDR-relevant values carried by the real request-side `device_status` map. The R20 patcher targets the exact map owner `LX/07sY.A00(UserSession)` and the exact keys:

- `hw_av1_dec`
- `10bit_hw_av1_dec`
- `is_hlg_supported`

This upgrades `device_status` from a generic route parameter to a concrete request payload containing codec/HDR-relevant capability state.

Evidence/report:

- `research/generated/instagram_439_hdr_device_status_bool_producers_r19p2.txt`

Commit anchor:

- `e1a5a0bc10f384067583dae06142e29fc27c80f7` — `Add exact 10-bit AV1 and HLG device_status producers R19p2`

---

## Current HEAD: R20 concrete candidate prepared

Current repository HEAD at this handoff: `2b8222f731a77c82164ae43bc1bc07fcf1616e6d` (`Build real Instagram HDR device_status R20 candidate`).

R20 is the first candidate in this branch that patches a **proven real Reels request parameter carrying explicit HDR/10-bit capability fields**, rather than UA or telemetry-only values.

### Patch scope

`research/tools/ig_hdr_device_status_r20_patch.py`

**classes15 / `LX/03u7.A04()`**

- force the existing `DeviceStatusApiUtil` request decoration infrastructure active in this finalizer
- for `clips/*`, bypass only MobileConfig `0x81061e00031d79` so the existing `device_status` payload is attached
- log the exact outgoing JSON as `IG_HDR_R20_STATUS`

**classes13 / `LX/07sY.A00(UserSession)`**

Force only these request-side `device_status` values true:

- `hw_av1_dec=true`
- `10bit_hw_av1_dec=true`
- `is_hlg_supported=true`

**classes13 / `LiveTreeMediaDict.A7q()`**

- retain the raw MPD observer as `IG_HDR_R20_RAW`

Explicitly **not** patched:

- UA / global `Build.*`
- `X-IG-Capabilities`
- `X-IG-Accept-Hint`
- ODC / `ig_device_static_attributes`
- decoder/renderer/display path

Build workflow:

- `.github/workflows/build-ig-hdr-device-status-r20.yml`
- intended output: `instagram-piko-v439.0.0.37.89-HDR-R20-DEVICE-STATUS.apk`
- intended tag: `ig-hdr-device-status-r20`

At handoff time the workflow and patcher are committed, but the release tag was not yet present when queried. Treat R20 as **prepared but not yet user-tested / not yet validated as delivered**.

Commit anchors:

- `8b129dace4a5c5f1ed3f10cb99e7dc3f5d909d63` — add R20 patcher
- `2b8222f731a77c82164ae43bc1bc07fcf1616e6d` — add/build R20 workflow candidate

---

## Resume point

When work resumes, start from the repository state above. Do **not** return to the closed renderer/decoder/UA/telemetry paths.

Immediate order:

1. Confirm the R20 workflow/release completes and verify signer/base SHA/scope.
2. Only if a valid R20 artifact exists, one user test is sufficient:
   - capture `IG_HDR_R20_STATUS`
   - capture `IG_HDR_R20_RAW`
3. Success criterion is raw MPD gaining 10-bit HDR representations. SurfaceFlinger is only checked after that.
4. If R20 still returns SDR-only MPD, keep the request path proven and move upstream to the server-persistent eligibility/classification join (device benchmark / performance group / identity), rather than trying more local codec or display gates.

No additional observation-only APK should be built unless it answers a specific unresolved request/classification question.