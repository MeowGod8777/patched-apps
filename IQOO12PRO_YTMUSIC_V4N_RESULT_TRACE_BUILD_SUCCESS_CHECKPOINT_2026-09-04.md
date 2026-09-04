# iQOO 12 Pro / OriginOS 6 — YouTube Music V4N result-code trace build-success checkpoint

Date: 2026-09-04

## Identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_V4N_RESULT_TRACE.apk`
- Workflow: `Build YT Music Luna Vivo c0 V4N result-code probe`
- Run: `33825599038`
- Artifact: `9919840293`
- Artifact URL: `https://github.com/MeowGod8777/patched-apps/actions/runs/33825599038/artifacts/9919840293`
- APK SHA256: `c0e47519ecf616e6e2fa3744c2027f8503cac0aaf9bed315d1cd5b2df8e548af`
- Base SHA256: `0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307`
- Signer SHA256: `7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c`

## Scope

Observation-only reproduction of V4N plus the already-validated c0 trace, with additional logging of the final `Lbupb` playback result code, resolved caller/source, and normalized Bundle gate facts.

This is **not V5** and is **not a fix candidate**. It does not alter playback routing, selection semantics, MediaSession queue/actions, metadata, or timing behavior.

## Mandatory verification

- validated Luna base identity: PASS
- V4N patch architecture retained: PASS
- prior V4N trace architecture retained: PASS
- final `Llag.x()` result-code trace present: PASS
- normalized Bundle facts trace present: PASS
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

## Runtime gate

One row press should now reveal `RESULT action=onPlayFromMediaId() error=<bool> code=<n>` plus the normalized caller/source/Bundle context. The result code selects the next offline branch (1 / 3 / 4 / 0).
