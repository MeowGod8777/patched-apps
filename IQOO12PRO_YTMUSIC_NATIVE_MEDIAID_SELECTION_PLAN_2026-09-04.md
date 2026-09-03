# iQOO 12 Pro / OriginOS 6 / YT Music OriginPlayer — native mediaId selection plan — 2026-09-04

## Product goal
Fix the patched YouTube Music OriginPlayer playlist on iQOO 12 Pro / OriginOS 6 so the real current/upcoming queue renders and tapping a row switches playback, without regressing the richer card title/metadata path.

## Proven stable runtime baseline
V2 real-queue candidate remains the only stable baseline:
- playlist opens ✅
- real queue renders ✅
- title/artist render in playlist ✅
- OriginPlayer song title remains present ✅
- row selection not implemented/working ❌
- initial elapsed/duration labels still unresolved ❌

V2 artifact: `9896185089`
V2 run: `33762673544`
V2 APK SHA256: `639a99a109ea853eda2c53238626d4caab45b410dccfe968cd3f04685d151715`

## Rejected selection approach
V3S changed only `smali_classes5/id.smali` relative to the finished V2 APK (excluding normal signature files), yet runtime showed:
- playlist browse/render still works
- tapping a row does not switch playback
- OriginPlayer title/timeline presentation regresses

Exact finished-APK diff evidence:
- run `33775924858`
- artifact `9901585654`

Therefore do **not** patch `Lid.onPlayFromMediaId()` again and do not treat Android `QueueItem.b` as a YT Music-native playable media ID.

## Session callback wiring — verified
Static trace from exact V2 artifact:
- run `33776289463`
- artifact `9901712413`

`MusicBrowserService.onCreate()` publishes the `MediaSessionCompat.Token` from the same `Liq` session stack used by YT Music playback.

`Lid` is only the framework adapter:
- `Lid extends android.media.session.MediaSession$Callback`
- field `a: Lie`
- `onPlayFromMediaId(String, Bundle)` delegates to current `Lie.g(String, Bundle)`
- `onSkipToQueueItem(long)` delegates to current `Lie.t(long)`

The normal main callback provider resolves to `Llag` through the `Llai`/DI path; `Lbazp.c` is explicitly the `mediaSessionCallback` (`Lie`).

## Queue model — verified
Static trace from exact V2 artifact:
- run `33776601380`, artifact `9901843415`
- run `33777019752`, artifact `9902010091`
- targeted callback/provider run `33818153135`, artifact `9917300678`

`Lkyi.j()` obtains the YT Music queue as `List<Lnoq>` and converts each item to `MediaSessionCompat.QueueItem`.

`Lnoq` inherits:
- `Lazcj.m()J` / queue id
- `Lazck.o()Lboht` / endpoint
- `Lazcf.t()String` and other WatchEndpoint-like identifiers

During Android QueueItem construction, YT Music intentionally passes `null` as the first `MediaDescriptionCompat` constructor argument, so exported QueueItem `mediaId` is null. It separately writes `Lnoq.m()` as the Android queue ID.

This means the missing QueueItem mediaId is a lossy export step, not evidence that YT Music lacks a native playable identifier upstream.

## Native YT Music playFromMediaId codec — verified
Native Browser/mediaId trace:
- run `33818283922`, artifact `9917324249`
- final codec run `33818546276`, artifact `9917413031`

### Decoder
`Llag.g(String mediaId, Bundle)` does:

`mediaId -> Laveu.b(String) -> Lavev -> Llbg.a(Lavev) -> Lboht playback endpoint`

`Lavet`, the lazy parser behind `Lavev.b()`, explicitly:
1. reads `Lavev.k` string
2. `Base64.decode(mediaId, 0x0a)`
3. parses protobuf `Lbuyd`

Therefore a normal playable mediaId is **not** the Android queue long encoded as text and is not an arbitrary raw string. It is YT Music's encoded `MediaItemInfo` (`Lbuyd`).

### Playback endpoint extraction
`Llbg.a(Lavev)`:
- parses `Lbuyd`
- checks the endpoint-presence bit
- returns `Lbuyd.e : Lboht`

### Encoder already present in YT Music
YT Music's own Browser code calls:

`Llgl.d(Lboht) -> String`

The corresponding `Llgl` method constructs `Lbuyd`, stores the supplied `Lboht` into `Lbuyd.e`, sets its presence bit, builds it, and calls:

`Llgl.g(Lbuyd) -> Base64.encodeToString(protoBytes, 0x08)`

This is the exact inverse family consumed by `Lavet` (`0x0a` decode tolerates the URL-safe/no-wrap representation).

## Correct next candidate architecture
Start from the proven V2 patcher unchanged.

Do **not** modify:
- `Lid`
- any `Lie` callback
- `Lii.m()` metadata
- PlaybackState actions
- the normal MediaSession QueueItem description/mediaId

Add only a sidecar mapping for the Vivo browser bridge:

### 1. Static sidecar in MusicBrowserService
Add a static map:

`queueId (Long) -> nativeMediaId (String)`

Use a concurrent map so BrowserService reads cannot race queue refreshes.

### 2. Capture before YT Music drops mediaId
In `Lkyi.j()`, while each `Lnoq` is still available and before/while it is converted to QueueItem:

- queueId = `Lnoq.m()`
- endpoint = inherited `Lazck.o() -> Lboht`
- nativeMediaId = `Llgl.d(endpoint)`
- store `queueId -> nativeMediaId` in the sidecar

Do not alter the QueueItem itself.

### 3. Vivo current-list browse
Keep V2 title/artist/artwork extraction from the already-proven QueueItem descriptions.

Replace only the synthetic browser mediaId:

`vivo_qid_<queueId>`

with:

`sidecar.get(queueId)`

If a mapping is unavailable, retain a nonempty fallback solely so rendering does not crash; such fallback is not counted as selectable success.

### 4. Selection path
Leave YT Music's original framework callback completely untouched:

`Vivo c0 playFromMediaId(nativeMediaId, extras)`
→ original `Lid.onPlayFromMediaId`
→ current `Lie.g`
→ normal `Llag.g`
→ `Laveu/Lavev`
→ `Llbg.a`
→ original YT Music playback pipeline

This uses the app's own native transport instead of translating Vivo selection into `skipToQueueItem`.

## Falsifiable runtime criteria
Candidate passes this phase only if:
1. playlist still opens;
2. real queue still renders with the same title/artist behavior as V2;
3. OriginPlayer title/card behavior does not regress relative to V2;
4. tapping a different playlist row actually changes YT Music playback to that item.

Time-label repair remains a separate issue. The rejected `vivomusicmix.media.metadata.support_event=0x10` / `Lii.m()` mutation must not return in this candidate.

## Candidate build gate
Before delivery require:
`rebuild -> zipalign -P 16 -> same signer -> v2/v3 verification -> all 21 arm64 libs stored/aligned -> manifest/static markers -> explicit regression guards that Lid and metadata timing patches are absent`.
