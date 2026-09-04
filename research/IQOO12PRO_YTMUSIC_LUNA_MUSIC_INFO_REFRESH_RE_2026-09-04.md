# iQOO 12 Pro / YouTube Music — Luna Vivo MUSIC_INFO refresh RE result

Date: 2026-09-04

## Scope

Offline static RE only. No new device APK.

Compared against the official Luna implementation to determine whether Vivo OriginPlayer track-info refresh requires an explicit vendor `MUSIC_INFO` session event beyond standard `MediaSession` metadata plus `vivomusicmix.media.metadata.support_event`.

Source workflow:

- run: `33829470668`
- artifact: `9921169291`
- artifact name: `luna-vivo-music-info-refresh-smali`
- artifact digest: `sha256:aa65cb6c13c3ce338ab012e64c2db5e25bfb4bd69969e2b7848bf10d9594b191`
- head: `809e14bdb54c0a3daaad96bbab1d4919d7ea8a90`

## VERIFIED

### 1. Official Luna does not emit a dedicated `MUSIC_INFO` `sendSessionEvent`

Static search of official Luna found Vivo-specific session events for other functions such as errors, play mode / favorite handling, and lyric-related extras, but no dedicated `MUSIC_INFO` refresh event.

Therefore the prior hypothesis — that YT Music still needs one missing explicit vendor `MUSIC_INFO` session event to force title/artist refresh — is DISPROVEN.

### 2. Official Luna's `VivoOriginRemoteControl.update(...)` augments the normal `MediaMetadataCompat.Builder`

The official implementation writes:

- `vivomusicmix.media.metadata.support_event`
- `vivomusicmix.media.metadata.LOOP_MODE`
- optional `android.media.metadata.ALBUM_ART`
- lyric update side-path

Then returns through the normal remote-control metadata update pipeline.

There is no separate title/artist payload in this method.

### 3. `MUSIC_INFO` is a capability bit, not a separate event payload

`VivoConstant$MediaSupportEvent` initializes:

- PLAY_CONTROL = `0x1`
- MUSIC_INFO = `0x2`
- MUSIC_IMAGE = `0x4`
- MUSIC_LRC = `0x8`
- SEEK_POSITION = `0x10`
- ...

The previously tested normal-track `support_event = 0x9DF` therefore already advertises `MUSIC_INFO`.

### 4. Runtime evidence remains authoritative

The V5 + `support_event=0x9DF` runtime already proved:

- c0 playlist opens
- real queue renders
- row selection changes playback
- artwork refreshes
- elapsed/duration numbers and progress refresh
- standard Android media notification receives the correct new TITLE / ARTIST / DURATION / PlaybackState

Any remaining OriginPlayer text behavior is therefore downstream of a valid standard MediaSession publication and is not explained by a missing dedicated Luna `MUSIC_INFO` session event.

## Corrected model

Do NOT build a candidate that merely invents or sends a synthetic `MUSIC_INFO` session event. Official Luna does not establish such a contract.

The remaining gap must be resolved by comparing the exact metadata lifecycle / publication ordering / additional metadata fields used by official Luna's normal remote-control pipeline against the YT Music bridge, while preserving the validated V5 selection path and `0x9DF` timing capability.

## Regression locks

Do not modify:

- V5 `Lnoq.n() -> Lazmi.b -> Llgl.d()` playable endpoint mapping
- `Lid`
- `Llag`
- queueId parser (must remain absent)
- duration / PlaybackState producer values
- c0 real-queue rendering

Do not re-test `support_event=0x10` or action-bit / `onSkipToQueueItem` approaches.

## Status

Offline MUSIC_INFO-event hypothesis: CLOSED / DISPROVEN.

No final follow-up APK has been justified by this RE result alone yet.
