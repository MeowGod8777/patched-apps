# iQOO 12 Pro / YT Music c0 real queue bridge v2 plan

Date: 2026-09-03 (+08:00)

## Starting point

Probe v1 is device-PASS. The complete browse/render path is now verified:

`support.service -> custom-insert/c0 -> MusicBrowserService -> VIVO_MUSIC_MIX_ROOT -> vivomusicmix_current_list -> result delivery -> MediaBrowserCompat.MediaItem render`

Do not modify this proven transport in v2.

## New static-analysis evidence

Analysis workflow:

- run `33761953394`
- artifact `9895861113`

Exact YT Music media-item contract inspection:

- run `33762308524`
- artifact `9896004861`

### 1. Exact MediaSession queue sink

Class `Lii;` is the legacy `MediaSessionCompat` implementation used to publish the Android media session queue.

Exact method:

```smali
.method public final q(Ljava/util/List;)V
```

It first stores the incoming list:

```smali
iput-object p1, p0, Lii;->g:Ljava/util/List;
```

Then iterates it as:

```text
List<android.support.v4.media.session.MediaSessionCompat.QueueItem>
```

and ultimately calls:

```text
android.media.session.MediaSession.setQueue(...)
```

The target device already reports queue size 25 through the live MediaSession, so this method is a proven runtime source of the same current queue we need to expose to Vivo c0.

### 2. Exact YT Music QueueItem construction

`Lkyi;` builds the queue items.

For each playable it builds:

```text
MediaSessionCompat.QueueItem
  description = MediaDescriptionCompat
  queueId     = noq.m() long
```

The description contains real YT Music metadata:

```text
title      = track title
subtitle   = artist
bitmap     = artwork for current item when available
iconUri    = artwork URI when available
extras     = existing extras
```

Important: YT Music constructs this MediaDescriptionCompat with:

```text
mediaId = null
```

The stable identifier is instead the `QueueItem.b` long queueId.

### 3. Direct reuse of QueueItem.description is invalid for MediaBrowser

Exact `MediaBrowserCompat$MediaItem(MediaDescriptionCompat, int)` constructor in this APK checks:

```text
description != null
AND
TextUtils.isEmpty(description.mediaId) == false
```

Otherwise it throws:

```text
IllegalArgumentException: description must have a non-empty media id
```

Therefore v2 must NOT simply wrap `QueueItem.a` directly.

## v2 single-variable bridge design

Preserve all validated v1 c0 routing unchanged.

### A. Capture the exact MediaSession queue

Add a static queue reference on `MusicBrowserService`, for example:

```text
public static volatile List vivoQueue
```

At the beginning of:

```text
Lii;->q(Ljava/util/List;)V
```

store the exact incoming queue list into that static field before the original method continues.

No playback behavior is changed.

### B. Replace only the v1 static probe row in current-list browse

For:

```text
parentId contains vivomusicmix_current_list
```

read the captured `List<MediaSessionCompat.QueueItem>` and build a fresh `ArrayList<MediaBrowserCompat.MediaItem>`.

For each queue item:

```text
queueId = QueueItem.b
original = QueueItem.a
browserMediaId = "vivo_qid_" + Long.toString(queueId)
```

Create a new `MediaDescriptionCompat` using:

```text
mediaId  = browserMediaId
title    = original.b
subtitle = original.c
description = null
bitmap   = original.d
iconUri  = original.e
extras   = original.f
mediaUri = null
```

Then:

```text
new MediaBrowserCompat.MediaItem(description, 2)
```

Return the resulting list through the exact same `Lbzu;->c(Object)` result path already proven by v1.

### C. Scope of v2

v2 is a real-queue **render** candidate only.

It does NOT yet add or alter:

- `playFromMediaId`
- `skipToQueueItem`
- MediaSession PlaybackState action bits
- c0 root routing
- Vivo paging behavior

Success criterion:

```text
OriginPlayer playlist opens
-> real YT Music current/upcoming queue rows render
-> titles and artists correspond to the actual YT Music queue
-> no crash
```

If rows render, the next separate phase maps:

```text
vivo_qid_<long>
```

back to queueId when Vivo calls `playFromMediaId`, without changing this render bridge.

## Register / build constraints

Keep `MusicBrowserService.b(String, bzu, Bundle)` at no more than `.locals 12`, so instance parameters map through `v15` at most and original 35c invokes remain encodable.

Use contiguous low registers for the 8-argument `MediaDescriptionCompat` direct constructor and `invoke-direct/range`.

Before delivery require:

`rebuild -> zipalign -P 16 -> stored-native alignment verification -> same signer -> manifest/static smali verification`
