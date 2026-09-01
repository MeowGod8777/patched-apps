# Instagram 439 HDR R19g conclusion

## Exact-build findings

Target APK SHA256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`.

### `X-IG-Accept-Hint` is not an HDR enum

Exact `LX/02qh.A00(Integer)` maps only two wire values:

- integer `1` -> `image-grid`
- every other integer -> `feed`

The exact Instagram 439 APK contains eight methods carrying the `X-IG-Accept-Hint` literal. Reels/Clips streaming builders that use a literal value use `feed`; other request builders obtain the same two-valued string through `LX/02qh.A00()`.

Therefore there is no exact-build evidence for a hidden `hdr`, `video`, `high-quality`, codec, or rendition value in `X-IG-Accept-Hint`. Treating arbitrary invented header values as an HDR gate is unsupported.

### `ClipsApiUtilHelper.A06()` is a real Reels streaming request, but exposes no HDR/device parameter

`ClipsApiUtilHelper.A06(UserSession,String,String,String,int)` builds `clips/items/` streaming requests. Proven primary callers include:

- `LX/01Jw.A06()` — `ClipsViewerPrefetcher_executeStreamingPrefetchRequest`
- `LX/01Jv.A03()` — `ClipsHeadMediaInsertionHelper_loadSourceMediaAsFlow`

The explicit request fields in A06 are:

- `clips_media_ids`
- `container_module`
- optional `prepend_media_repost_author_ids`
- optional `X-IG-Accept-Hint: feed`

No explicit HDR, codec, decoder, display, quality, bandwidth, resolution, or device-class field is written by A06.

For the ordinary `ClipsViewerPrefetcher` A06 call, `container_module` and `prepend_media_repost_author_ids` are both null; the request integer is the fixed constant `0x0a59b6f5`. The media-id argument is serialized as a one-item JSON array.

For `ClipsHeadMediaInsertionHelper`, the same fixed request integer is used; the caller supplies a container-module string and an optional repost-author-id string.

## Decision

Do **not** build an R20 APK around `X-IG-Accept-Hint` or A06 local parameters. The next justified trace is below A06 into shared streaming request construction/finalization (`LX/02pu`, `LX/02ue`, related request decorators/interceptors) to identify automatic server-visible device/media-delivery headers or variables not locally written by `ClipsApiUtilHelper`.
