# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 runtime selection success

Date: 2026-09-04

## Candidate identity

- APK: `YouTube_Music_9.15.51_Luna_VIVO_C0_PLAYABLE_MEDIAID_V5.apk`
- APK SHA256: `5f8d786b794f96049911323ecba6f7e68d0cd2133e2a11dfcf8bff151c25c02a`
- Build run: `33825824333`
- Build artifact: `9919920481`
- Build-success checkpoint: `bbc7a5d2d84bbb40c4cdad40d73284b2b74a8a1e`
- Device: iQOO 12 Pro / V2329A / OriginOS 6 / Android 16
- Device build: `PD2329B_A_16.2.19.1.W10.V0101L17`

## VERIFIED runtime result

The user reports that the Vivo OriginPlayer playlist now:

- opens successfully;
- renders the real queue;
- shows song title and artist in playlist rows;
- selecting a different playlist row successfully switches playback to that song.

Therefore the primary product bug — visible playlist rows that could not actually change playback — is **FIXED in V5**.

This validates the exact-stock endpoint-role root cause and the correction:

`Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(Lboht) -> Vivo MediaItem.mediaId`

and falsifies the previous V4/V4N selection payload based on `Lnoq.o()`.

## Remaining OriginPlayer / notification issues

The user reports that the main OriginPlayer notification/card still does not show:

- current song title;
- current artist;
- elapsed-time number;
- duration number.

The playlist rows themselves do show title and artist. These are separate consumer paths and must not be conflated with playlist selection.

Playlist rows are not expected to require an elapsed/progress timeline per row; the unresolved timing requirement applies to the main OriginPlayer/notification playback surface.

## Next gate

Freeze V5 as the new selection-success regression baseline.

Do not modify the now-working selection path (`Lnoq.n() -> Lazmi.b -> Llgl.d`).

Next work is offline RE of the Vivo OriginPlayer main-card metadata/timing contract:

1. compare the metadata/session state expected by the original working richer OriginPlayer card with the current V5 state;
2. identify why title/artist are absent from the main card while the same information is available in the c0 browse list;
3. reverse the exact initial elapsed/duration consumer contract;
4. do not reuse the disproven `vivomusicmix.media.metadata.support_event=0x10` / `Lii.m()` patch;
5. preserve V5 playlist rendering and row-selection behavior as hard runtime invariants.
