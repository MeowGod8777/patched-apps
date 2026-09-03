# iQOO 12 Pro / OriginOS 6 / YT Music c0 V3S runtime regression — 2026-09-03

## Product goal
Fix patched YouTube Music OriginPlayer playlist behavior on iQOO 12 Pro / OriginOS 6.

## Proven-good reference
V2 real-queue candidate was runtime-PASS for:
- playlist button opens
- real queue renders
- title/artist visible in playlist

V2 still lacked working playlist-item selection and initial elapsed/duration time labels.

## V3S candidate
V3S was intentionally built as **V2 + selection-only delta**.
The previous `vivomusicmix.media.metadata.support_event` / `ii.m()` time patch was completely removed and statically guarded against reappearing.

## Runtime result reported by user
Observed on iQOO 12 Pro / V2329A / OriginOS 6:

1. Playlist opens ✅
2. Playlist real songs render ✅
3. Tapping a playlist row does **not** switch playback ❌
4. OriginPlayer / playback notification song title is missing ❌
5. Timeline / elapsed-duration presentation is missing ❌

## Consequences
This falsifies the previous attribution that the song-title/time regression was caused only by the V3/V3R1 `support_event` metadata mutation.

The selection-only hook is also not functionally complete: `vivo_qid_<queueId> -> onSkipToQueueItem(queueId)` did not cause a real track switch.

More importantly, a method-entry selection hook should not affect title/time before the user taps a playlist row. Therefore the next step must not assume the patch script is the only delta. We need to compare the **actual V2 and V3S APK outputs** and their build inputs, including dex/class/resource/manifest differences, to determine why V3S is not runtime-equivalent to the proven V2 baseline.

## Next step
1. Download the exact V2 PASS artifact and V3S artifact.
2. Verify both used the same validated base APK hash and signer.
3. Compare APK entry inventories, CRC/SHA256 by entry, manifest, resources, and dex files.
4. Decode both outputs and diff all smali, not only the intended callback class.
5. Confirm whether only `id.smali/onPlayFromMediaId()` differs. If additional differences exist, identify them before building another candidate.
6. Separately capture runtime evidence for playlist-row tap so we can determine whether Vivo calls `playFromMediaId()` at all, and if so what `mediaId`/extras reach YT Music.

Do not generate another APK until this diff and runtime boundary are understood.
