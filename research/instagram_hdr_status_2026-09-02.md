# Instagram HDR status checkpoint — 2026-09-02

This is a compact current-state checkpoint for the iQOO 12 Pro / V2329A Instagram HDR branch. The detailed continuation file remains `research/instagram_hdr_handoff_2026-09-02.md`.

## Validated baseline

- Target: iQOO 12 Pro / V2329A, Android 16, build `PD2329B_A_16.2.19.1.W10.V0101L17`.
- Instagram `439.0.0.37.89`, Piko `3.9.0`, package `com.instagram.android`.
- Exact base APK SHA256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`.
- R6/R6v2 proved the raw `video_dash_manifest` delivered to V2329A is already SDR-only (`1/1/1` color signalling, AV1 `.08` / 8-bit BT.709).
- R17 S24 Ultra-style Instagram network UA spoof still received SDR-only raw MPD; UA/model-only backend classification is therefore falsified for this context.

## Closed / demoted paths

Do not restart without new contradictory evidence:

- Android/vivo HDR display pipeline.
- AV1 Main10/HDR10/HDR10+ decoder support.
- local Media3/renderer/representation selection.
- vivo XDR/native HDR whitelist / Surface headroom.
- Dolby Vision telemetry and downstream `hdrSdrRatio` handling.
- S24 camera/profile allowlist.
- `ig_device_static_attributes` / `X.0Uiy` as synchronous playback gate.
- `LX/0knW` QPL HDR reporter.
- `LX/0lAl` MediaCodecInfoReporter.
- fixed `X-IG-Capabilities: 3brTv10=`.
- blind MetaConfig flag roulette.

## Proven request path

R19e–R19m established a real Reels/Clips media request chain:

`ClipsApiUtilHelper.A06()`
→ `LX/02pu.A0K()`
→ `LX/02tw.A00(...)`
→ `LX/02uA.call()`
→ `LX/03u7.A04()`
→ `LX/03u7.A01(...)`
→ first-party Instagram HTTP request.

`ClipsApiUtilHelper.A06()` is a genuine `clips/items/` streaming request builder used by Reels viewer prefetch/head-media loading. Explicit fields include `clips_media_ids`, `container_module`, optional repost IDs, and optional `X-IG-Accept-Hint`.

R19g resolved `X-IG-Accept-Hint` to only `image-grid` or `feed`; no exact-build evidence links it to HDR/codec/rendition class. Do not patch it as an HDR guess.

## Current strongest request-side candidate

R19l2/R19p2 proved the real request finalizer can attach a `device_status` parameter to media routes including `clips/` and `feed/reels_media`, and the exact `device_status` map contains HDR/10-bit-relevant keys:

- `hw_av1_dec`
- `10bit_hw_av1_dec`
- `is_hlg_supported`

This is the first concrete request payload in the branch that simultaneously satisfies both conditions:

1. it is part of the actual Reels/media request finalization path;
2. it carries explicit codec/HDR capability state.

## R20 prepared state

Repository contains:

- `research/tools/ig_hdr_device_status_r20_patch.py`
- `.github/workflows/build-ig-hdr-device-status-r20.yml`

R20 patch scope is deliberately narrow:

- enable existing `device_status` decoration for `clips/*` through the existing finalizer path;
- force only `hw_av1_dec=true`, `10bit_hw_av1_dec=true`, `is_hlg_supported=true` in the request-side map;
- log outgoing payload as `IG_HDR_R20_STATUS`;
- retain raw MPD logger as `IG_HDR_R20_RAW`;
- no UA/global Build spoof, no `X-IG-Capabilities`, no `X-IG-Accept-Hint`, no ODC/static-attribute patch, no decoder/renderer/display patch.

Commit anchors:

- `e1a5a0bc10f384067583dae06142e29fc27c80f7` — exact 10-bit AV1 / HLG `device_status` producers.
- `8b129dace4a5c5f1ed3f10cb99e7dc3f5d909d63` — R20 patcher.
- `2b8222f731a77c82164ae43bc1bc07fcf1616e6d` — R20 build candidate.
- `f1f0bed7d4164bf04d7f91aa402edd46ca8133e1` — detailed handoff through R20 candidate.

## Current external state

As of this checkpoint, GitHub release tag `ig-hdr-device-status-r20` is still absent. Therefore R20 is **prepared in source/workflow form but not yet treated as a delivered or user-tested artifact**.

## Resume rule

When work resumes:

1. first verify whether the R20 workflow produced a valid signed artifact/release;
2. if valid, one user test should capture only `IG_HDR_R20_STATUS` and `IG_HDR_R20_RAW`;
3. success is raw MPD gaining genuine 10-bit HDR representations;
4. if MPD remains SDR-only, preserve the proven request path and move upstream to Meta's server-persistent eligibility/classification join (device benchmark/performance group/identity), not back to local codec/display/UA paths.

No further observation-only APK should be built unless it resolves a specific remaining request/classification uncertainty.
