# iQOO 12 Pro / YT Music c0 v2 device PASS + v3 combined scope

Date: 2026-09-03 (+08:00)

## Device result — v2 PASS

Device:
- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build `PD2329B_A_16.2.19.1.W10.V0101L17`

Candidate:
- `YouTube_Music_9.15.51_Luna_VIVO_C0_REAL_QUEUE_V2.apk`
- APK SHA256 `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`

User-provided screenshots confirm:
- OriginPlayer playlist opens normally.
- Multiple real YT Music queue rows render.
- Row titles/artists match the active YT Music queue, e.g. `Birdy Fly（最近寫的歌） / 陳忻玥`, `模特 / 李榮浩`, etc.
- No static `YT Music Vivo Bridge / c0 cooperation probe` row remains.
- No crash observed.

Therefore the following path is now device-validated end to end:

`support.service -> custom-insert/c0 -> MusicBrowserService bind -> VIVO_MUSIC_MIX_ROOT -> vivomusicmix_current_list -> exact YT Music MediaSession queue capture -> Browser MediaItem rebuild -> Vivo playlist render` ✅

This validates the real-queue render source and the `vivo_qid_<queueId>` media-id scheme for browse delivery.

## Remaining product gaps requested for v3

The user explicitly requests that the next candidate fix both remaining visible issues together:

1. Playlist row tap / selection:
   - tapping a rendered real queue row should switch YT Music playback to that corresponding queue item.
   - Vivo c0 is already known to call `playFromMediaId(mediaId, Bundle{vivomusicmix_key_list=vivomusicmix_current_list})`.
   - v3 should parse `vivo_qid_<queueId>` and dispatch the exact YT Music/MediaSession queue selection command.

2. OriginPlayer elapsed / duration time labels:
   - progress bar itself is present.
   - left/right numeric elapsed/duration labels render as `--:--` / blank-style placeholders in the screenshots.
   - this behavior is present on the c0 path and must be traced to its actual data source; do not fake UI strings.
   - fix should preserve proper live progress and real duration semantics.

## v3 rules

User explicitly requested both fixes in the same next candidate, overriding the previous one-variable sequencing preference for this step.

Do not regress or redesign the now-proven c0 browse/render path.

Before producing v3 APK:
1. recover exact `playFromMediaId` callback/transport on YT Music 9.15.51;
2. recover exact Vivo c0 time/progress data source and compare with official Luna cooperation behavior;
3. document the chosen hooks and uncertainty;
4. then build.

Delivery gate remains mandatory:

`rebuild -> zipalign -P 16 -> same signer -> manifest/static verification -> artifact hash/provenance`

Only after all pass may the v3 APK be delivered.