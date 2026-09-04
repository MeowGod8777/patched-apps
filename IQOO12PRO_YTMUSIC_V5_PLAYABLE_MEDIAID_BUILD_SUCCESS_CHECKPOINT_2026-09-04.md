# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 playable-mediaId build-success checkpoint

Date: 2026-09-04

## Identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_PLAYABLE_MEDIAID_V5.apk`
- Workflow: `Build YT Music Luna Vivo c0 playable mediaId V5`
- Run: `33825824333`
- Artifact: `9919920481`
- Artifact URL: `https://github.com/MeowGod8777/patched-apps/actions/runs/33825824333/artifacts/9919920481`
- APK SHA256: `5f8d786b794f96049911323ecba6f7e68d0cd2133e2a11dfcf8bff151c25c02a`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

## Root-cause correction

V5 replaces only the disproven V4/V4N selection payload source:

`Lnoq.o() / Lazck.o() / Lbxxg.q` (stock queue DELETE endpoint)

with the exact stock playable queue representation used by `Llag.onSkipToQueueItem`:

`Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(Lboht)`.

## Mandatory verification

- validated Luna base identity: PASS
- V2/V4N c0 queue/browser architecture retained: PASS
- playable endpoint guard (n -> Lazmi.b): PASS
- rejected o()/p() selection endpoints absent from V5 mapping: PASS
- `Lid` byte-for-byte unchanged from validated base: PASS
- `Llag` byte-for-byte unchanged from validated base: PASS
- `Lii.m()` byte-for-byte unchanged from validated base: PASS
- trace/result instrumentation absent: PASS
- rejected timing metadata patch absent: PASS
- v2 signature: PASS
- v3 signature: PASS
- signer matches validated Morphe signer: PASS
- final 16K zipalign: PASS
- 21 arm64 native libraries stored/uncompressed: PASS
- package `com.luna.music`, version `9.15.51`: PASS
- Vivo support.service / MusicBrowserService manifest checks: PASS

## Runtime status

NOT YET TESTED. This is the first functional correction after the endpoint-role root cause was VERIFIED; it is not a speculative transport change.
