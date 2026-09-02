# Origin Isle media diagnostic — iQOO 12 Pro / V2329A

Date: 2026-09-02

Target:
- iQOO 12 Pro / V2329A
- OriginOS 6 / Android 16
- Origin Isle upstream v1.4.0

Observed on device:
- Origin Isle listener health is Connected.
- `Cast notifications` and `Cast Media` enabled.
- Media source apps are enabled in the Apps tab.
- YouTube ReVanced and Bilibili appear in Origin Isle Log as `cast — media player`.
- Reboot / app restart / `Recast all notifications now` do not make the media card surface on the island.

This proves the notification-listener and MediaSession/controller detection stages are working. The failure is downstream of `MediaCard.post()` / SuperX surfacing.

## Variant A — force-show only

Upstream v1.4.0 MediaCard is kept unchanged except that media cards explicitly request island surfacing via `oi_force_show=true`.

Purpose: test the hypothesis that OriginOS accepts the media card but does not automatically surface it on V2329A unless force-show is requested.

APK artifact name:
`origin-isle-1.4.0-v2329a-A-force-show.apk`

## Variant B — force-show + conservative BASE template

Includes Variant A's force-show change and additionally changes the media card from the newer BUTTONS template back to the more conservative BASE template while retaining the wave right-side island presentation.

Purpose: only use if Variant A is still logged as cast but does not surface. This separates `forceShow` gating from a possible V2329A incompatibility with the BUTTONS + wave media-card combination.

APK artifact name:
`origin-isle-1.4.0-v2329a-B-force-show-base.apk`

## Build

Workflow:
`.github/workflows/build-origin-isle-v2329a.yml`

The workflow fetches the exact upstream `v1.4.0` tag, applies the two diagnostic patches independently, builds both debug APKs in the same job, and publishes them in one artifact.

## Signing / installation caveat

The official Origin Isle release is signed by the upstream maintainer. These diagnostic APKs are debug-signed by the same GitHub Actions job, so Android will not accept them as an in-place update over the official APK.

For the first diagnostic install, the official Origin Isle must therefore be uninstalled first. This clears its app data and permissions; notification access / background/autostart settings need to be granted again.

Variant A and Variant B are produced in the same workflow job and therefore use the same job's debug keystore. Variant B can be installed over Variant A for the same diagnostic session without returning to the official build first.

## Test order

1. Keep Origin Ghost Player disabled while testing Origin Isle media casting.
2. Install Variant A and restore Origin Isle notification listener/background permissions.
3. Enable `Cast Media` and the test media app in Apps.
4. Play YouTube ReVanced or Bilibili.
5. Confirm Log still says `cast — media player` and check whether the card now surfaces.
6. If Variant A still does not surface, install Variant B and repeat the same playback test.

Interpretation:
- A surfaces: missing force-show was the V2329A-specific blocker.
- A fails, B surfaces: BUTTONS + wave media template combination is incompatible/rejected/not surfaced on this build.
- A and B both fail while Log says `cast — media player`: the remaining failure is lower in the OriginOS SuperX presentation path and requires device-side logging / posted-notification inspection rather than more UI setting changes.
