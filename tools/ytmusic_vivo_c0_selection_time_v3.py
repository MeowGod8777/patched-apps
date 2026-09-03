#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
manifest = ROOT / "AndroidManifest.xml"
if not manifest.is_file():
    raise SystemExit(f"missing {manifest}")

ACTION = "com.vivo.musicwidgetmix.support.service"
SERVICE = "com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService"
VIVO_CLIENT = "com.vivo.musicwidgetmix"
VIVO_ROOT = "VIVO_MUSIC_MIX_ROOT"
VIVO_LIST = "vivomusicmix_current_list"
QUEUE_FIELD = "vivoQueue"
MEDIA_ID_PREFIX = "vivo_qid_"
SUPPORT_EVENT_KEY = "vivomusicmix.media.metadata.support_event"
SEEK_POSITION_EVENT = 0x10

# Exact support-library contract for this validated YT Music build.
desc_paths = list(ROOT.glob("smali*/android/support/v4/media/MediaDescriptionCompat.smali"))
item_paths = list(ROOT.glob("smali*/android/support/v4/media/MediaBrowserCompat$MediaItem.smali"))
queue_item_paths = list(ROOT.glob("smali*/android/support/v4/media/session/MediaSessionCompat$QueueItem.smali"))
if len(desc_paths) != 1 or len(item_paths) != 1 or len(queue_item_paths) != 1:
    raise SystemExit(
        f"unexpected compat type count: desc={desc_paths}, item={item_paths}, queue={queue_item_paths}"
    )

desc_smali = desc_paths[0].read_text(encoding="utf-8")
item_smali = item_paths[0].read_text(encoding="utf-8")
queue_item_smali = queue_item_paths[0].read_text(encoding="utf-8")
ctor_desc = ".method public constructor <init>(Ljava/lang/String;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Landroid/graphics/Bitmap;Landroid/net/Uri;Landroid/os/Bundle;Landroid/net/Uri;)V"
item_ctor = ".method public constructor <init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V"
if ctor_desc not in desc_smali:
    raise SystemExit("expected public 8-arg MediaDescriptionCompat constructor not found")
if item_ctor not in item_smali:
    raise SystemExit("expected MediaBrowserCompat$MediaItem constructor not found")
for needle in (
    ".field public final a:Ljava/lang/String;",
    ".field public final b:Ljava/lang/CharSequence;",
    ".field public final c:Ljava/lang/CharSequence;",
    ".field public final d:Landroid/graphics/Bitmap;",
    ".field public final e:Landroid/net/Uri;",
    ".field public final f:Landroid/os/Bundle;",
):
    if needle not in desc_smali:
        raise SystemExit(f"MediaDescriptionCompat field contract changed: missing {needle}")
for needle in (
    ".field public final a:Landroid/support/v4/media/MediaDescriptionCompat;",
    ".field public final b:J",
):
    if needle not in queue_item_smali:
        raise SystemExit(f"QueueItem field contract changed: missing {needle}")
if "description must have a non-empty media id" not in item_smali:
    raise SystemExit("expected MediaBrowserCompat non-empty mediaId contract not found")

# Add Vivo cooperation intent action to the existing YT Music MediaBrowserService.
m = manifest.read_text(encoding="utf-8")
if ACTION in m:
    raise SystemExit("Vivo support.service action already present before patch")
service_re = re.compile(
    r'(?ms)<service\b[^>]*android:name="com\.google\.android\.apps\.youtube\.music\.mediabrowser\.MusicBrowserService"[^>]*>.*?</service>'
)
sm = service_re.search(m)
if not sm:
    raise SystemExit("MusicBrowserService manifest block not found")
block = sm.group(0)
if block.count("<intent-filter") != 1:
    raise SystemExit(f"expected one MusicBrowserService intent-filter, got {block.count('<intent-filter')}")
block2 = block.replace(
    "</intent-filter>",
    '                <action android:name="com.vivo.musicwidgetmix.support.service"/>\n            </intent-filter>',
    1,
)
m = m[:sm.start()] + block2 + m[sm.end():]
manifest.write_text(m, encoding="utf-8")

# Locate exact classes.
browser_paths = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
ii_paths = [p for p in ROOT.glob("smali*/ii.smali") if "setMetadata(Landroid/media/MediaMetadata;)V" in p.read_text(encoding="utf-8")]
id_paths = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
if len(browser_paths) != 1:
    raise SystemExit(f"expected exactly one MusicBrowserService.smali, got: {browser_paths}")
if len(ii_paths) != 1:
    raise SystemExit(f"expected exactly one MediaSession ii.smali, got: {ii_paths}")
if len(id_paths) != 1:
    raise SystemExit(f"expected exactly one MediaSession callback id.smali, got: {id_paths}")

browser_path = browser_paths[0]
ii_path = ii_paths[0]
id_path = id_paths[0]
s = browser_path.read_text(encoding="utf-8")
ii = ii_path.read_text(encoding="utf-8")
id_s = id_path.read_text(encoding="utf-8")

if VIVO_ROOT in s or MEDIA_ID_PREFIX in s or QUEUE_FIELD in s:
    raise SystemExit("v3 bridge markers already present before patch")
if SUPPORT_EVENT_KEY in ii:
    raise SystemExit("Vivo support_event key already present in ii before patch")
if MEDIA_ID_PREFIX in id_s:
    raise SystemExit("vivo_qid selection marker already present in id before patch")
if ".method public final q(Ljava/util/List;)V" not in ii:
    raise SystemExit("MediaSession queue sink ii.q(List) not found")
if "iput-object p1, p0, Lii;->g:Ljava/util/List;" not in ii:
    raise SystemExit("ii.q no longer stores incoming queue in field g")
if "Landroid/media/session/MediaSession;->setQueue(Ljava/util/List;)V" not in ii:
    raise SystemExit("ii.q no longer reaches framework MediaSession.setQueue")
if ".method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V" not in ii:
    raise SystemExit("ii.m metadata sink not found")
for needle in (
    ".method public final onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V",
    ".method public final onSkipToQueueItem(J)V",
    "Lie;->g(Ljava/lang/String;Landroid/os/Bundle;)V",
    "Lie;->t(J)V",
):
    if needle not in id_s:
        raise SystemExit(f"selection callback contract changed: missing {needle}")

# Add one static capture field to the already-existing browser service.
static_anchor = ".field private static final A:Lbioo;"
if static_anchor not in s:
    raise SystemExit("MusicBrowserService static field anchor not found")
s = s.replace(
    static_anchor,
    static_anchor + "\n\n.field public static volatile vivoQueue:Ljava/util/List;",
    1,
)


def inject_after_registers(src: str, signature: str, min_locals: int, param_regs: int, injection: str) -> str:
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n(.*?)^\.end method')
    mm = pat.search(src)
    if not mm:
        raise SystemExit(f"method not found: {signature}")
    method = mm.group(0)

    lm = re.search(r'(?m)^\s*\.locals\s+(\d+)\s*$', method)
    if lm:
        old = int(lm.group(1))
        if old < min_locals:
            replacement = re.sub(r'\.locals\s+\d+', f'.locals {min_locals}', lm.group(0), count=1)
            method = method[:lm.start()] + replacement + method[lm.end():]
            lm = re.search(r'(?m)^\s*\.locals\s+(\d+)\s*$', method)
        insert_at = lm.end()
    else:
        rm = re.search(r'(?m)^\s*\.registers\s+(\d+)\s*$', method)
        if not rm:
            raise SystemExit(f"no .locals/.registers in: {signature}")
        old = int(rm.group(1))
        need = min_locals + param_regs
        if old < need:
            replacement = re.sub(r'\.registers\s+\d+', f'.registers {need}', rm.group(0), count=1)
            method = method[:rm.start()] + replacement + method[rm.end():]
            rm = re.search(r'(?m)^\s*\.registers\s+(\d+)\s*$', method)
        insert_at = rm.end()

    method = method[:insert_at] + "\n\n" + injection.strip("\n") + "\n" + method[insert_at:]
    return src[:mm.start()] + method + src[mm.end():]


def inject_before_anchor_in_method(src: str, signature: str, anchor: str, injection: str) -> str:
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n(.*?)^\.end method')
    mm = pat.search(src)
    if not mm:
        raise SystemExit(f"method not found for anchor injection: {signature}")
    method = mm.group(0)
    if method.count(anchor) != 1:
        raise SystemExit(f"expected one anchor {anchor!r} in {signature}, got {method.count(anchor)}")
    method = method.replace(anchor, injection.strip("\n") + "\n\n" + anchor, 1)
    return src[:mm.start()] + method + src[mm.end():]


root_inject = r'''
    const-string v0, "com.vivo.musicwidgetmix"
    move-object/from16 v1, p1
    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :vivo_v3_original_root

    new-instance v0, Lbze;
    const-string v1, "VIVO_MUSIC_MIX_ROOT"
    const/4 v2, 0x0
    invoke-direct {v0, v1, v2}, Lbze;-><init>(Ljava/lang/String;Landroid/os/Bundle;)V
    return-object v0

    :vivo_v3_original_root
'''

children_inject = r'''
    move-object/from16 v0, p1
    const-string v1, "vivomusicmix_current_list"
    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v0
    if-eqz v0, :vivo_v3_original_children

    new-instance v0, Ljava/util/ArrayList;
    invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V

    sget-object v2, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoQueue:Ljava/util/List;
    if-eqz v2, :vivo_v3_send_queue

    invoke-interface {v2}, Ljava/util/List;->iterator()Ljava/util/Iterator;
    move-result-object v1

    :vivo_v3_queue_loop
    invoke-interface {v1}, Ljava/util/Iterator;->hasNext()Z
    move-result v2
    if-eqz v2, :vivo_v3_send_queue

    invoke-interface {v1}, Ljava/util/Iterator;->next()Ljava/lang/Object;
    move-result-object v2
    if-eqz v2, :vivo_v3_queue_loop
    check-cast v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;

    iget-wide v4, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v4, v5}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v4
    const-string v5, "vivo_qid_"
    invoke-virtual {v5, v4}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v4

    iget-object v2, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->a:Landroid/support/v4/media/MediaDescriptionCompat;
    if-eqz v2, :vivo_v3_queue_loop

    iget-object v5, v2, Landroid/support/v4/media/MediaDescriptionCompat;->b:Ljava/lang/CharSequence;
    iget-object v6, v2, Landroid/support/v4/media/MediaDescriptionCompat;->c:Ljava/lang/CharSequence;
    const/4 v7, 0x0
    iget-object v8, v2, Landroid/support/v4/media/MediaDescriptionCompat;->d:Landroid/graphics/Bitmap;
    iget-object v9, v2, Landroid/support/v4/media/MediaDescriptionCompat;->e:Landroid/net/Uri;
    iget-object v10, v2, Landroid/support/v4/media/MediaDescriptionCompat;->f:Landroid/os/Bundle;
    const/4 v11, 0x0

    new-instance v3, Landroid/support/v4/media/MediaDescriptionCompat;
    invoke-direct/range {v3 .. v11}, Landroid/support/v4/media/MediaDescriptionCompat;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Landroid/graphics/Bitmap;Landroid/net/Uri;Landroid/os/Bundle;Landroid/net/Uri;)V

    new-instance v2, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;
    const/4 v4, 0x2
    invoke-direct {v2, v3, v4}, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;-><init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V
    invoke-virtual {v0, v2}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z
    goto :vivo_v3_queue_loop

    :vivo_v3_send_queue
    move-object/from16 v2, p2
    invoke-virtual {v2, v0}, Lbzu;->c(Ljava/lang/Object;)V
    return-void

    :vivo_v3_original_children
'''

queue_capture_inject = r'''
    sput-object p1, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoQueue:Ljava/util/List;
'''

selection_inject = r'''
    if-eqz p1, :vivo_v3_original_play_from_media_id
    const-string v0, "vivo_qid_"
    invoke-virtual {p1, v0}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z
    move-result v0
    if-eqz v0, :vivo_v3_original_play_from_media_id

    const/16 v0, 0x9
    invoke-virtual {p1, v0}, Ljava/lang/String;->substring(I)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Ljava/lang/Long;->parseLong(Ljava/lang/String;)J
    move-result-wide v1
    invoke-virtual {p0, v1, v2}, Lid;->onSkipToQueueItem(J)V
    return-void

    :vivo_v3_original_play_from_media_id
'''

time_inject = r'''
    iget-object v0, p1, Landroid/support/v4/media/MediaMetadataCompat;->c:Landroid/media/MediaMetadata;
    new-instance v1, Landroid/media/MediaMetadata$Builder;
    invoke-direct {v1, v0}, Landroid/media/MediaMetadata$Builder;-><init>(Landroid/media/MediaMetadata;)V
    const-string v2, "vivomusicmix.media.metadata.support_event"
    const-wide/16 v3, 0x10
    invoke-virtual {v1, v2, v3, v4}, Landroid/media/MediaMetadata$Builder;->putLong(Ljava/lang/String;J)Landroid/media/MediaMetadata$Builder;
    invoke-virtual {v1}, Landroid/media/MediaMetadata$Builder;->build()Landroid/media/MediaMetadata;
    move-result-object v0
    iput-object v0, p1, Landroid/support/v4/media/MediaMetadataCompat;->c:Landroid/media/MediaMetadata;
'''

s = inject_after_registers(
    s,
    "public final f(Ljava/lang/String;Landroid/os/Bundle;)Lbze;",
    min_locals=3,
    param_regs=3,
    injection=root_inject,
)
s = inject_after_registers(
    s,
    "public final b(Ljava/lang/String;Lbzu;Landroid/os/Bundle;)V",
    min_locals=12,
    param_regs=4,
    injection=children_inject,
)
ii = inject_after_registers(
    ii,
    "public final q(Ljava/util/List;)V",
    min_locals=6,
    param_regs=2,
    injection=queue_capture_inject,
)
id_s = inject_after_registers(
    id_s,
    "public final onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V",
    min_locals=3,
    param_regs=3,
    injection=selection_inject,
)
ii = inject_before_anchor_in_method(
    ii,
    "public final m(Landroid/support/v4/media/MediaMetadataCompat;)V",
    "    :cond_c",
    time_inject,
)

browser_path.write_text(s, encoding="utf-8")
ii_path.write_text(ii, encoding="utf-8")
id_path.write_text(id_s, encoding="utf-8")

manifest_after = manifest.read_text(encoding="utf-8")
assert ACTION in manifest_after
assert SERVICE in manifest_after
assert VIVO_CLIENT in s
assert VIVO_ROOT in s
assert VIVO_LIST in s
assert QUEUE_FIELD in s
assert MEDIA_ID_PREFIX in s
assert "MediaSessionCompat$QueueItem;->b:J" in s
assert "MediaSessionCompat$QueueItem;->a:Landroid/support/v4/media/MediaDescriptionCompat;" in s
assert "MusicBrowserService;->vivoQueue:Ljava/util/List;" in ii
assert MEDIA_ID_PREFIX in id_s
assert "Long;->parseLong(Ljava/lang/String;)J" in id_s
assert "Lid;->onSkipToQueueItem(J)V" in id_s
assert SUPPORT_EVENT_KEY in ii
assert "const-wide/16 v3, 0x10" in ii
assert "MediaMetadata$Builder;-><init>(Landroid/media/MediaMetadata;)V" in ii
assert "vivo_probe_1" not in s

print(f"patched manifest:  {manifest}")
print(f"patched browser:   {browser_path}")
print(f"patched queue/time:{ii_path}")
print(f"patched selection: {id_path}")
print("v3 real queue + selection + seek capability markers OK")
