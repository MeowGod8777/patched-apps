# iQOO 12 Pro / YT Music c0 real queue v2 — device PASS and combined v3 plan

Date: 2026-09-03 (+08:00)

## Device result

Candidate under test:

`YouTube_Music_9.15.51_Luna_VIVO_C0_REAL_QUEUE_V2.apk`

Device:

- iQOO 12 Pro / V2329A / PD2329
- Android 16 / OriginOS 6
- exact build `PD2329B_A_16.2.19.1.W10.V0101L17`

User screenshots confirm:

- OriginPlayer playlist opens normally.
- The static `YT Music Vivo Bridge / c0 cooperation probe` row is gone.
- Multiple real YT Music queue rows render.
- Titles and artists match the actual YT Music queue.
- No crash.

Therefore the following path is now device-validated end-to-end:

`YT Music MediaSession queue -> ii.q(List) capture -> vivoQueue -> vivomusicmix_current_list browse -> MediaBrowserCompat.MediaItem render in Vivo c0 playlist UI` ✅

This closes the list-render phase.

## Remaining user-visible issues

1. Tapping a rendered playlist row does not yet switch YT Music tracks because v2 intentionally did not implement Vivo `playFromMediaId` mapping.
2. After switching the package into Vivo custom-insert / `c0`, OriginPlayer elapsed/duration labels show `--:--` / no numeric time. This is visible in the v1/v2 screenshots and should now be repaired together with row selection, per explicit user request.

## Selection transport — exact YT Music callback

YT Music 9.15.51 already has a MediaSession callback implementation in `Lid;`:

- `onPlayFromMediaId(String, Bundle)` -> `Lie.g(String, Bundle)`
- `onSkipToQueueItem(long)` -> `Lie.t(long)`

The v2 Browser media ID is our controlled format:

`vivo_qid_<decimal MediaSessionCompat.QueueItem.b>`

Therefore the narrow selection bridge is:

- intercept `Lid;->onPlayFromMediaId(String, Bundle)` only when mediaId starts with `vivo_qid_`;
- parse the decimal queueId;
- dispatch to the app's own already-existing `onSkipToQueueItem(queueId)` path;
- leave all non-Vivo media IDs on the original YT Music `Lie.g(String, Bundle)` path.

This reuses YT Music's native queue-item switching implementation rather than inventing a new player-control path.

## Time/progress evidence from official Luna

Official Luna's Vivo cooperation stack publishes standard MediaSession timing plus Vivo capability metadata.

`CoreRemoteControl.update(...)` publishes:

- `android.media.metadata.DURATION = controller.getDuration()`
- PlaybackState position = `controller.getPlaybackTime()`

`VivoOriginRemoteControl.update(...)` additionally publishes:

- `vivomusicmix.media.metadata.support_event`
- `vivomusicmix.media.metadata.LOOP_MODE`

The official support-event bitmask includes a dedicated `EVENT_TYPE_SEEK_POSITION` capability for normal track playback.

Current patched YT Music entered `c0` only by adding the cooperation service/browser bridge; it does not yet emulate Luna's Vivo capability metadata. The elapsed/duration labels disappearing after c0 routing is therefore treated as a cooperation-metadata gap until falsified.

## V3 scope — user explicitly requested combined fix

The next candidate will intentionally combine these two remaining user-visible gaps:

A. playlist row selection

`playFromMediaId("vivo_qid_<queueId>") -> parse queueId -> YT Music native onSkipToQueueItem(queueId)`

B. time display

- preserve YT Music's existing PlaybackState position/speed path;
- verify whether YT Music's emitted metadata already contains `android.media.metadata.DURATION`;
- if duration is already present, add only the exact Vivo cooperation capability metadata needed for seek/time display;
- if duration is missing, add/fix the duration metadata at the narrowest existing MediaSession metadata sink before enabling the Vivo seek-position capability.

Do not change the now-proven c0 browse/render transport or queue capture unless the build/runtime evidence requires it.

## Delivery rule

Before device delivery, candidate must pass:

`rebuild -> zipalign -P 16 -> same signer -> v2/v3 signature verify -> package/version verify -> manifest/static selection/time markers verify`.
