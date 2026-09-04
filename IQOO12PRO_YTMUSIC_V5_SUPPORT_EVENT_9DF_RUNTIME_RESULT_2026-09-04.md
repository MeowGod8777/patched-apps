# iQOO 12 Pro / OriginOS 6 — YouTube Music V5 + support-event 0x9DF runtime result

Date: 2026-09-04

## Runtime result

The 0x9DF A/B materially fixes Vivo OriginPlayer timing, but metadata refresh is still inconsistent.

Observed from user screenshots after switching playback to `Sign / FLOW`:

- Vivo OriginPlayer progress bar is active.
- elapsed / duration are numeric (`00:06–00:09 / 04:08`) instead of `--:--`.
- artwork updates to the current `Sign` track.
- standard Android media notification shows the current track correctly: `Sign / FLOW`.
- Vivo OriginPlayer expanded card still shows stale previous-track text (`...Sigrid... / Sture Zetterberg`), while current artwork/timing are already for `Sign`.
- collapsed Vivo OriginPlayer surface still shows the app label (`汽水音樂`) rather than current title/artist.

## Interpretation

`vivomusicmix.media.metadata.support_event = 0x9DF` is sufficient to unlock the timing/progress capability path.

It is not sufficient by itself to make Vivo OriginPlayer refresh title/artist correctly on every track transition.

The remaining failure is now specifically a Vivo rich-card metadata refresh / event-notification contract problem, not standard Android MediaSession publication and not V5 queue selection.

## Preserved baseline

Keep V5 playable selection unchanged:

`Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(Lboht)`

Do not modify standard TITLE/ARTIST/DURATION or PlaybackState timing values.

## Next RE target

Reverse the official Luna/Vivo metadata refresh event path: determine what additional vendor event/update signal accompanies `MUSIC_INFO` / artwork changes so Vivo invalidates stale text after track transitions. 0x9DF stays as a proven timing-capability requirement unless later evidence disproves it.
