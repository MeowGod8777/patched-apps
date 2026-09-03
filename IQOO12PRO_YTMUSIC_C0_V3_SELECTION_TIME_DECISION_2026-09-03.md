# iQOO 12 Pro / YT Music c0 V3 — selection + time decision

Date: 2026-09-03 (+08:00)

## Scope

Per explicit device-test request, V3 combines the two remaining visible gaps after V2 real-queue render passed:

1. tapping a Vivo c0 playlist row must switch YT Music to that queue item;
2. OriginPlayer elapsed/duration numbers must stop showing `--:--` and use YT Music's real timing.

The already-proven c0 browse/render and `ii.q(List)` real-queue capture are not changed.

## Selection — exact native YT Music path

Analysis workflow:

- run `33765330227`
- artifact `9897245140`

Exact class `Lid;` is the MediaSession callback.

`onPlayFromMediaId(String, Bundle)` currently ends in:

`Lie;->g(String, Bundle)`

`onSkipToQueueItem(long)` currently ends in:

`Lie;->t(long)`

V2 Browser items use the controlled media ID format:

`vivo_qid_<decimal MediaSessionCompat.QueueItem.b>`

where the decimal value is the exact queue ID already assigned by YT Music to the same QueueItem that YT Music publishes to MediaSession.

### V3 selection patch

At the start of `Lid;->onPlayFromMediaId(String, Bundle)`:

- if mediaId is null or does not start with `vivo_qid_`, preserve original YT Music code unchanged;
- for `vivo_qid_...`, strip the 9-character prefix;
- parse the suffix with `Long.parseLong`;
- call the existing `Lid;->onSkipToQueueItem(long)` path;
- return.

This deliberately reuses YT Music's existing `Lie.t(long)` queue-selection implementation rather than inventing a new player-control path.

## Timing — standard YT Music duration/position already exist

The same analysis confirms this YT Music 9.15.51 build already emits standard Android timing data.

### Duration

Active metadata-generation classes contain explicit writes of:

`android.media.metadata.DURATION`

Examples recovered from the validated base:

- `Lkzf;`: obtains duration through the current playable/player object and `Bundle.putLong("android.media.metadata.DURATION", ...)`;
- `Lbazk;`: obtains current media duration and writes it through the app's `MediaMetadataCompat` builder path.

`Lii;->m(MediaMetadataCompat)` then converts/preserves MediaMetadataCompat values and sends them to framework:

`MediaSession.setMetadata(MediaMetadata)`.

### Position

`Lii;->n(PlaybackStateCompat)` preserves the compat playback state's position, speed, update time, actions, buffered position and active queue item when constructing framework PlaybackState and calls:

`MediaSession.setPlaybackState(PlaybackState)`.

Therefore V3 must NOT fabricate duration or replace YT Music's position clock.

## Why c0 still shows `--:--`

Official Luna's Vivo cooperation path adds vendor capability metadata on top of the same standard MediaSession timing model:

`vivomusicmix.media.metadata.support_event`

Official Luna's exact Vivo event constants are:

- PLAY_CONTROL = `0x1`
- MUSIC_INFO = `0x2`
- MUSIC_IMAGE = `0x4`
- MUSIC_LRC = `0x8`
- SEEK_POSITION = `0x10`
- MUSIC_TAG = `0x20`
- FAVORITE = `0x40`
- LOOP_MODE = `0x80`
- LIST_CURRENT = `0x100`
- LIST_FAVORITE = `0x200`
- LIST_LOCAL = `0x400`
- PLAY_INDEX = `0x800`

Official Luna's `VivoOriginRemoteControl.update()` writes this support-event mask into MediaMetadata, while its core remote control separately writes standard `android.media.metadata.DURATION` and PlaybackState position.

The patched YT Music currently entered c0 through the cooperation service/browser bridge but publishes no Vivo support-event key. The fact that real title/art/controls/list already work while numeric timing changes to `--:--`, combined with official Luna's dedicated `SEEK_POSITION = 0x10` capability, makes the narrow timing patch:

**publish only the missing `SEEK_POSITION` capability (`0x10`) while leaving YT Music's standard duration/position untouched.**

This is a targeted, falsifiable vendor-capability fix, not a replacement timing implementation.

## V3 timing injection point

Patch `Lii;->m(MediaMetadataCompat)` at the final framework-MediaMetadata stage.

For every non-null metadata update:

- clone the already-built framework `MediaMetadata` with `new MediaMetadata.Builder(existing)`;
- add `putLong("vivomusicmix.media.metadata.support_event", 0x10)`;
- build and continue through the original `MediaSession.setMetadata` path.

This works regardless of whether `MediaMetadataCompat.c` was already materialized before entering `ii.m`, and it does not mutate the standard duration value.

## Expected V3 device behavior

1. `OriginPlayer -> 播放列表` continues rendering the same real queue as V2.
2. Tapping a different row switches playback to that exact queue item.
3. OriginPlayer elapsed/duration values become numeric and track the real playback position/duration rather than `--:--`.
4. Existing artwork/title/artist/previous/play-pause/next remain functional.

If selection passes but time remains `--:--`, the selection path is kept and the time hypothesis `SEEK_POSITION bit alone is sufficient` is falsified; next timing work must inspect Vivo c0's exact metadata-consumer conditions rather than altering YT Music duration.
