# iQOO 12 Pro YT Music Vivo c0 V3R1 runtime regression — 2026-09-03

## Device / baseline
- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build: PD2329B_A_16.2.19.1.W10.V0101L17
- YT Music package: com.luna.music
- version: 9.15.51

## Candidate under test
- V3R1: `YouTube_Music_9.15.51_Luna_VIVO_C0_SELECTION_TIME_V3R1.apk`
- build workflow run: 33766518367
- artifact: 9897773372
- APK SHA256: 7cdebd4821c12f634f1230ca50c91784d388f9aaf39b4b0613aec14c39101d88

## Runtime result — FAIL / regression
User reported on-device:
1. Playback notification / OriginPlayer metadata no longer shows the song title correctly.
2. Time values only appear after manually dragging/seeking; initial display remains missing, so `support_event = 0x10` is insufficient to restore normal initial time rendering.
3. Playlist functionality regressed again compared with the previously working V2 real-queue build.

## Interpretation
- The V3R1 `ii.m(MediaMetadataCompat)` mutation is rejected as a viable timing strategy. It introduces a metadata regression and must not be carried forward.
- `vivomusicmix.media.metadata.support_event = 0x10` is at most a capability/seek enable signal; it does not by itself supply the initial duration/position values expected by Vivo c0.
- Because V2 real-queue rendering was already runtime-PASS, the next candidate must return to the V2 bridge unchanged and add only the queue-selection delta.

## Next step
1. Restore the proven V2 c0/root/real-queue bridge with no `ii.m()` metadata mutation.
2. Add only `vivo_qid_<queueId>` -> `onSkipToQueueItem(queueId)` selection handling.
3. Rebuild -> 16K zipalign -> same-signer verification -> manifest/static verification.
4. Runtime test only playlist render + list-item selection + notification title preservation.
5. Investigate time rendering separately through Vivo c0 consumer expectations, without mutating YT Music's framework `MediaMetadata` object.

This checkpoint intentionally marks V3/V3R1 timing-metadata injection as rejected and prevents accidental reuse.
