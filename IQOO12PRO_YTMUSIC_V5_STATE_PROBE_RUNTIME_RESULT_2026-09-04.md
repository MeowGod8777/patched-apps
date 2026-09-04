# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 state-probe runtime result

Date: 2026-09-04

## Device result

V5 playable selection remains successful. The state probe resolves the remaining metadata/timing branch.

### MediaSession metadata is healthy

Observed standard metadata publication:

- `Any Song / ZICO`: duration `247000`
- `还是会想你 (DJ阿智版) / DJ阿智`: duration `252000`
- after Vivo c0 row selection, `Revive (合作演出：Sigrid Spångberg) / Sture Zetterberg`: duration transitions `0 -> 232000`

### PlaybackState is healthy

Observed:

- selected `Revive` becomes active queue id `79`
- previous selected queue id `78` reaches position `12925 ms`
- state/position/speed/update-time are published through the normal MediaSession path

### Vivo capability metadata is absent

Every observed metadata update reports:

`vivomusicmix.media.metadata.support_event = -1`

meaning the key is absent.

## Surface evidence

The standard Android media notification can display the real selected track metadata while the Vivo OriginPlayer rich surface may fall back to the app label and `--:--`. The lockscreen rich card can consume title/artist but still shows `--:--` timing.

This proves the remaining issue is not failure of YT Music's standard MediaSession metadata or PlaybackState publication.

## Corrected failure boundary

`YT Music standard MediaSession TITLE/ARTIST/DURATION/position = present and correct`

→ `Vivo OriginPlayer / c0 vendor capability consumer contract`

→ missing/incorrect rich-card metadata/timing presentation.

## Next functional gate

The next candidate must preserve V5 selection semantics and only add the official Luna Vivo capability contract at the existing framework MediaMetadata publication boundary.

Use the exact normal-track Luna mask:

`vivomusicmix.media.metadata.support_event = 0x9DF (2527)`

Rationale: the earlier disproven `0x10`-only test advertised SEEK_POSITION without MUSIC_INFO and other normal-track capabilities. Once the private capability key exists, Vivo may capability-gate the rich-card fields; therefore `0x10` alone was not a valid representation of a normal playable track.

Do not alter standard TITLE/ARTIST/DURATION, PlaybackState position, V5 playable endpoint selection, `Lid`, or queue semantics.