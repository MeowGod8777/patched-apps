# Instagram/Reels HDR — Meta performance-score delivery evidence (R19o)

## Why this matters

R6/R17 established that V2329A receives an SDR-only `video_dash_manifest`; HDR is absent before renderer/decoder selection. R19m then found no explicit `hdr`, `codec`, `av1`, `hevc`, or device-capability field in the exact `clips/discover/stream/` request builder.

Meta's own Reels engineering documentation provides a direct architectural explanation for a non-explicit request gate: Android device performance is benchmarked and grouped, and the resulting performance classification is used to determine delivery eligibility, including 10-bit HDR.

## Primary Meta evidence

### How Meta brought AV1 to Reels — 2023-02-21

Source:
https://engineering.fb.com/2023/02/21/video-engineering/av1-codec-facebook-instagram-reels/

Relevant claims from Meta:

- Android device characteristics such as CPU core count, chipset vendor, RAM size, year, and model were not considered sufficient to classify playback capability.
- Meta therefore runs a small on-device benchmark consisting of compute operations such as Gaussian blur, memory allocation/copy, and 3D rendering.
- The benchmark gives each phone a **performance score** and groups devices based on that score.
- Meta states that A/B tests then identified the models capable of **720p, 1080p, and 10-bit HDR playback**.
- Meta further states that server-side mixed-codec ABR delivery can select allowed AV1/VP9 lanes based on the device's **performance score**.

This is direct evidence that Meta/Reels HDR delivery on Android can be controlled by a device-performance classification outside the literal synchronous Reels request fields.

### Bringing HDR video to Reels — 2023-07-17

Source:
https://engineering.fb.com/2023/07/17/video-engineering/hdr-video-reels-meta/

Relevant claims from Meta:

- HDR uploads are processed into both HDR and tone-mapped SDR representations on the server.
- Meta explicitly states that if a device does not support HDR, **only the SDR representation is delivered for playback**.
- HDR delivery is more demanding because it requires 10-bit decoding and typically newer codecs; Meta therefore avoids delivering HDR to devices that do not meet support/performance requirements.

This exactly matches the V2329A observation: the raw MPD itself contains only SDR representations rather than a client renderer discarding HDR after receipt.

## Exact Instagram 439 APK correlation already established

Existing exact-APK research found a live device-segmentation benchmark pipeline:

- event: `ig_device_perf_benchmark`
- native runner: `com.instagram.devicesegmentation.logging.PerfMetricRunnerJni`
- persistent marker: `preference_logged_performance_benchmarks`
- event object: `LX/03Tz` / `LX/00vv`
- benchmark result fields include:
  - `benchmark_name`
  - `benchmark_units`
  - `benchmark_samples`
  - `benchmark_min`
  - `benchmark_quartile1`
  - `benchmark_median`
  - `benchmark_quartile3`
  - `benchmark_max`
  - `benchmark_arithmeticmean`
  - `benchmark_standarddeviation`
  - `power`
  - power-save state

Existing report:
`research/generated/instagram_439_hdr_meta_device_benchmark_trace.txt`

The APK also contains `com.facebook.devicesegmentation` preference infrastructure and static device capability reporting, including HDR/display/decoder capability fields.

## R19o conclusion

**Strong candidate architecture:**

`local benchmark / device-segmentation signals -> Meta device performance classification -> server-side Reels delivery eligibility -> HDR/SDR rendition set`

This is materially stronger than the previously falsified UA/model-only spoof (R17) and stronger than `X-IG-Accept-Hint`, which R19l resolved to only `feed` vs `image-grid`.

## What remains UNKNOWN

- Exact Instagram 439 method that converts raw benchmark metrics to a performance score/group, if conversion is client-side.
- Whether the score/group is stored locally, returned by server configuration, or computed entirely server-side from uploaded benchmark telemetry.
- Exact identity key joining benchmark/device-segmentation data to `clips/discover/stream/` requests.
- Exact threshold/group corresponding to 10-bit HDR in Instagram 439.
- Whether current 2026 delivery uses the original benchmark score directly or a newer ML-based device eligibility framework fed by related signals.

Do not patch benchmark values until at least one of the score/group/identity joins above is established.
