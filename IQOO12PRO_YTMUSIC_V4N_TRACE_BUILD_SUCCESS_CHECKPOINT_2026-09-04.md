# iQOO 12 Pro / OriginOS 6 — YouTube Music V4N trace build-success checkpoint

Date: 2026-09-04

## Identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_V4N_TRACE.apk`
- Workflow: `Build YT Music Luna Vivo c0 V4N trace probe`
- Run: `33823745078`
- Artifact: `9919197991`
- Artifact URL: `https://github.com/MeowGod8777/patched-apps/actions/runs/33823745078/artifacts/9919197991`
- APK SHA256: `cc6dd5601ce143239fcefdc08ac58cc8a55bbfafda1c62636526df31a95906db`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

## Scope

Observation-only reproduction of V4N with log tag `YTM_C0TRACE`.

Trace points: Vivo browse entry, V4N queue native-ID mapping, concrete returned MediaItem ID, untouched callback target `Llag.g` entry, `Laveu.b` decode result, `Llbg.a` endpoint result, and before/after `Llbg.o` dispatch.

This is not V5 and is not a fix candidate.

## Mandatory verification

- validated Luna base identity: PASS
- V4N patch architecture retained: PASS
- `Lid` byte-for-byte unchanged from validated base: PASS
- `Lii.m()` byte-for-byte unchanged from validated base: PASS
- rejected queueId -> skip hook absent: PASS
- rejected timing metadata patch absent: PASS
- v2 signature: PASS
- v3 signature: PASS
- signer matches validated Morphe signer: PASS
- final 16K zipalign verification: PASS
- 21 arm64 native libraries stored/uncompressed: PASS
- package `com.luna.music`, version `9.15.51`: PASS
- Vivo support.service / MusicBrowserService manifest checks: PASS

## Runtime status

NOT YET TESTED. The only allowed device use is the one-pass trace sequence documented in `IQOO12PRO_YTMUSIC_V4N_TRACE_PROBE_PLAN_2026-09-04.md`.
