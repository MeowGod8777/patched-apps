# iQOO 12 Pro / YT Music c0 v3 — selection + time design

Date: 2026-09-03 (+08:00)

## Scope

Per user request, v3 fixes both remaining issues in one candidate:

1. tapping a Vivo playlist row must switch YT Music to that queue item;
2. OriginPlayer elapsed/duration labels must stop showing `--:--` and use the real session timing path.

The c0 browse/render path from v2 is frozen and must not be redesigned.

## Selection transport — exact YT Music callback recovered

Validated YT Music 9.15.51 framework MediaSession callback class:

```text
Lid;
extends android.media.session.MediaSession$Callback
field a: Lie;
```

Existing `onPlayFromMediaId(String, Bundle)` dispatches to:

```text
Lie.g(mediaId, extras)
```

Existing `onSkipToQueueItem(long queueId)` dispatches to:

```text
Lie.t(queueId)
```

with the same `Lid.c(Lig)` / `Lid.b(Lig)` pre/post command guard around it.

Therefore v3 selection bridge will special-case only generated Vivo IDs:

```text
vivo_qid_<decimal queueId>
```

Algorithm:

```text
onPlayFromMediaId(mediaId, extras):
  if mediaId startsWith "vivo_qid_":
      queueId = Long.parseLong(mediaId.substring(prefix.length))
      acquire Lii using existing Lid.a()
      if null: return
      Lid.c(session)
      this.a.t(queueId)
      Lid.b(session)
      return
  else:
      original onPlayFromMediaId logic
```

This reuses YT Music's exact existing queue-selection transport instead of inventing a controller path.

## Time labels — standard timing data exists; missing Vivo capability is the narrow gap

YT Music 9.15.51 already produces standard timing metadata:

- `android.media.metadata.DURATION` is written from the real player duration (`Lbaxh.o()J`);
- `Lii.m(MediaMetadataCompat)` preserves long metadata entries when converting to framework `android.media.MediaMetadata` and calls `MediaSession.setMetadata()`;
- `Lii.n(PlaybackStateCompat)` maps state, position, speed and update time into framework `PlaybackState.Builder.setState(...)` and calls `MediaSession.setPlaybackState()`.

Thus the code path supports standard `duration + position + speed` semantics; v3 will not synthesize display strings.

Official Luna Vivo integration adds an additional Vivo protocol metadata field:

```text
vivomusicmix.media.metadata.support_event
```

Its exact `VivoConstant.MediaSupportEvent` values include:

```text
EVENT_TYPE_SEEK_POSITION = 16 (0x10)
```

Official Luna computes and publishes this capability bit when seeking/current media supports it. Patched YT Music currently has no Vivo-specific support_event metadata at all.

Given the device symptom:

- progress UI exists,
- standard YT timing data path exists,
- c0/custom-insert labels remain `--:--`,

v3 will add only the exact Vivo `SEEK_POSITION` capability bit to the outgoing MediaMetadataCompat bundle before framework conversion:

```text
bundle["vivomusicmix.media.metadata.support_event"] |= 0x10
```

If the key is absent, it becomes `0x10`; if another future patch already supplies bits, preserve them and OR `0x10` rather than overwrite.

This is a protocol capability fix, not a UI-string hack.

## v3 patch boundaries

Preserve from v2 unchanged:

- `support.service` manifest action;
- Vivo root special-case;
- exact `Lii.q(List)` queue capture;
- `vivo_qid_<queueId>` browser IDs;
- real queue title/artist/artwork rebuild;
- current-list browse transport.

Add only:

A. `Lid.onPlayFromMediaId` Vivo queue-id special case -> `Lie.t(queueId)`.

B. `Lii.m(MediaMetadataCompat)` -> OR `0x10` into `vivomusicmix.media.metadata.support_event` before conversion / `MediaSession.setMetadata()`.

## Expected device validation

PASS requires both:

1. open OriginPlayer playlist, tap a different row -> active YT Music track actually switches to that row;
2. OriginPlayer left/right elapsed/duration labels display real numeric timing rather than `--:--` and track progress remains coherent.

If selection passes but time does not, retain selection and investigate c0 timing protocol further; do not regress browse/render.

## Delivery gates

Before user delivery:

`rebuild -> zipalign -P 16 -> same signer -> manifest/static verification -> artifact SHA256/provenance`

All must pass.