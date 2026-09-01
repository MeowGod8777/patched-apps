# Instagram 439 HDR R19j/R19m conclusion

Exact APK SHA256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`.

## Proven end-to-end request construction chain

For `ClipsApiUtilHelper.A06()` streaming `clips/items/` requests, the exact construction chain is now proven:

`ClipsApiUtilHelper.A06()`
→ `LX/02pu.A0K()`
→ `LX/02tw.A00(...)`
→ `LX/02uA.call()` (`buildApiRequest <path>`)
→ `LX/03u7.A04()`
→ `LX/03u7.A01(...)`
→ final first-party Instagram HTTP request.

`LX/02uA.call()` explicitly invokes `LX/03u7.A04()` in both priority branches. `LX/03u7.A04()` explicitly invokes static `LX/03u7.A01(...)` and returns its `LX/03ci` request object.

This closes the previous uncertainty about whether the generic `LX/03u7.A01()` header finalizer actually applies to the Reels/Clips streaming request: it does.

## Server-visible metadata on the real Clips streaming request

The exact generic finalizer `LX/03u7.A01()` adds normal request/session/network metadata including:

- `X-IG-App-Locale`
- `X-IG-Device-Locale`
- `X-IG-Mapped-Locale`
- `X-IG-Bandwidth-Speed-KBPS`
- `X-IG-Bandwidth-Speed-KBPS-Sensitive`
- `X-IG-Bandwidth-TotalBytes-B`
- `X-IG-Bandwidth-TotalTime-MS`
- `X-IG-Prefetch-Request`
- `X-IG-Low-Data-Mode-Image`
- `X-IG-Low-Data-Mode-Video`
- `X-IG-WWW-Claim`
- `X-IG-Cross-Repo-Setup`
- `X-IG-Attest-Params`
- `X-IG-Device-Languages`
- `X-IG-Fetch-AAT`
- `X-IG-Device-ID`
- `X-IG-Family-Device-ID`
- `X-IG-Android-ID`
- `X-IG-Session-Visitation`
- `X-IG-CLIENT-ENDPOINT`
- `X-IG-SALT-IDS`
- `X-IG-QPL-ID-MAPPING`
- `X-IG-Is-Foldable`

No explicit build-model, manufacturer, HDR-support, codec-support, decoder-profile, display-HDR, video-quality, or HDR-rendition request header was found in this finalization path.

## Streaming callback is not the missing request gate

`LX/02ug`, conditionally attached to streaming requests, is `ClientHintsStreamingApiCallback.onNewDataInBackground`. It handles received streaming data and forwards response hints to `LX/08vc/LX/08vd`; its request-side callback methods are otherwise no-ops. It is downstream of request construction and is not an HDR eligibility producer.

## Implication

The actual `clips/items/` request exposes stable device/session identity to Meta while carrying no explicit local `hdr=true` / model / codec capability field. Combined with the failure of R17's UA-only S24U spoof, the remaining plausible device-specific HDR decision is increasingly consistent with server-persistent device/account classification keyed or correlated by stable device identity, rather than a synchronous visible HDR flag in the Clips request.

This is still a hypothesis until the static-device-profile / device-segmentation reporting path is linked to the same server-side identity. Do not rotate/spoof device IDs yet.
