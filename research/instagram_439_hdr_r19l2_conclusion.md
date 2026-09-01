# Instagram 439 HDR R19l2 conclusion

Exact APK SHA256: `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`.

## What `com.facebook.devicesegmentation` is doing in the static-attributes path

The exact `ig_device_static_attributes` event producer is `LX/0ece.A00(Context, UserSession)`.

It creates the event through the Instagram logging framework, wraps it in `LX/03Tz`, constructs `LX/0Uiy`, then obtains `LX/0hkS` and posts `LX/0mJp` with the full `LX/0hkS.A3V` descriptor array.

`LX/0mJp.run()` calls `LX/0hkS.A02`, fills an `Object[0xd2]` (210 values) from the device-segmentation attribute descriptors, stores that array into `LX/0Uiy.A00`, then posts `LX/0Uiy` to serialize the values into the `ig_device_static_attributes` event.

Thus the observed `com.facebook.devicesegmentation` SharedPreferences / descriptor machinery is directly part of a **local device-static-attribute collection framework feeding telemetry**. It is not, by itself, evidence of a server-returned Reels eligibility bucket.

`LX/0Uiy.run()` serializes, among many values:
- `key_display_hdr_supported`
- `key_video_decoder_hdr_supported`
- codec support/profile data
- display/camera/CPU/device attributes.

This reinforces the earlier warning: patching `com.facebook.devicesegmentation` values blindly would primarily falsify the static device telemetry event, not a proven synchronous Reels rendition gate.

## New independent request-side finding

Separately, exact `LX/03u7.A04()` contains a request parameter named `device_status`, with explicit route gating for `clips/`, `feed/reels_media`, feed/user/discover/injected reels/ads surfaces. This is a distinct path from `ig_device_static_attributes` and is now the higher-priority request-side candidate to decode.
