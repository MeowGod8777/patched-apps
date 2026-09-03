# iQOO 12 Pro / YT Music c0 probe v1 — native media type-family decision

Date: 2026-09-03 (+08:00)

## Input evidence

Probe v0 device log failed in the injected `MusicBrowserService.b(...)` current-list branch with:

```text
java.lang.NoClassDefFoundError: Failed resolution of:
Landroid/support/v4/media/MediaDescriptionCompat$Builder;
```

The failure occurs before construction/delivery of `vivo_probe_1`.

## Static inspection of the validated YT Music 9.15.51 Luna base

The base APK was decoded with the same Apktool 3.0.3 used by the builder before applying the probe patch.

### Service hierarchy / callback API

`MusicBrowserService`:

```smali
.class public Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;
.super Lkxt;
```

Its relevant callbacks are the existing compat-style abstraction used by this build:

```smali
.method public final f(Ljava/lang/String;Landroid/os/Bundle;)Lbze;
.method public final b(Ljava/lang/String;Lbzu;Landroid/os/Bundle;)V
```

`Lbzu` is the local result wrapper. Its `c(Ljava/lang/Object;)V` is the send-result path and calls its virtual `a(Ljava/lang/Object;)V` delivery hook.

`Lbze` is the local BrowserRoot-style object with exactly:

```smali
.field public final a:Ljava/lang/String;
.field public final b:Landroid/os/Bundle;
.method public constructor <init>(Ljava/lang/String;Landroid/os/Bundle;)V
```

The already-working probe root injection therefore remains unchanged.

## Critical class-availability finding

The validated APK defines:

- `Landroid/support/v4/media/MediaDescriptionCompat;` ✅
- `Landroid/support/v4/media/MediaBrowserCompat$MediaItem;` ✅

but does NOT define:

- `Landroid/support/v4/media/MediaDescriptionCompat$Builder;` ❌

This exactly matches the device `NoClassDefFoundError`.

The existing `MediaDescriptionCompat` class exposes a public constructor with this exact descriptor:

```smali
Landroid/support/v4/media/MediaDescriptionCompat;-><init>(
    Ljava/lang/String;
    Ljava/lang/CharSequence;
    Ljava/lang/CharSequence;
    Ljava/lang/CharSequence;
    Landroid/graphics/Bitmap;
    Landroid/net/Uri;
    Landroid/os/Bundle;
    Landroid/net/Uri;
)V
```

The existing `MediaBrowserCompat$MediaItem` exposes the expected public constructor:

```smali
Landroid/support/v4/media/MediaBrowserCompat$MediaItem;-><init>(
    Landroid/support/v4/media/MediaDescriptionCompat;
    I
)V
```

## Decision for probe v1

Do NOT switch the entire probe to framework `android.media.*` types yet.

That would change two variables at once and is not required by the observed failure.

Probe v1 will instead make the minimum type-family correction:

1. keep `support.service` manifest injection unchanged;
2. keep `VIVO_MUSIC_MIX_ROOT` root handling unchanged;
3. keep `vivomusicmix_current_list` selection unchanged;
4. keep `MediaBrowserCompat$MediaItem` unchanged;
5. remove only the nonexistent `MediaDescriptionCompat$Builder` dependency;
6. instantiate the APK's existing `MediaDescriptionCompat` directly with its public 8-argument constructor;
7. preserve probe payload exactly:
   - mediaId `vivo_probe_1`
   - title `YT Music Vivo Bridge`
   - subtitle `c0 cooperation probe`
   - playable flag `2`.

Because the MediaDescription constructor requires eight arguments plus the receiver, the injected code will use contiguous low registers and `invoke-direct/range` to avoid another 35c register-count/encoding failure.

## v1 success criterion

On device:

`OriginPlayer playlist -> playlist UI -> vivo_probe_1 row renders`

If that occurs, result construction/delivery/render is validated and the next phase may replace the static item with the real YT Music queue.

If v1 still fails, capture the new exact runtime stack before changing media type families or queue logic.