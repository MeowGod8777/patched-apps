#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Preserve the exact V2 c0/root/real-queue implementation that passed runtime.
v2 = Path(__file__).with_name("ytmusic_vivo_c0_real_queue_v2.py")
if not v2.is_file():
    raise SystemExit(f"missing proven V2 patcher: {v2}")
subprocess.run([sys.executable, str(v2), str(ROOT)], check=True)

BROWSER = "Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;"
NATIVE_FIELD = "vivoNativeIds"
FORBIDDEN_TIME_KEY = "vivomusicmix.media.metadata.support_event"
FORBIDDEN_SELECTION_PREFIX = "vivo_qid_"

browser_paths = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
if len(browser_paths) != 1:
    raise SystemExit(f"expected one MusicBrowserService, got {browser_paths}")
browser_path = browser_paths[0]
browser = browser_path.read_text(encoding="utf-8")

# Locate the exact queue exporter that still owns Lnoq before YT Music drops mediaId.
kyi_paths = []
for p in ROOT.glob("smali*/kyi.smali"):
    s = p.read_text(encoding="utf-8")
    if (
        ".method public final j()V" in s
        and "check-cast v6, Lnoq;" in s
        and "MediaSessionCompat$QueueItem;-><init>" in s
        and "Lnoq;->m()J" in s
    ):
        kyi_paths.append(p)
if len(kyi_paths) != 1:
    raise SystemExit(f"expected one queue exporter kyi.smali, got {kyi_paths}")
kyi_path = kyi_paths[0]
kyi = kyi_path.read_text(encoding="utf-8")

# Exact codec contracts proven from the validated 9.15.51 V2 artifact.
for cls, needle in (
    ("noq.smali", ".implements Lazck;"),
    ("azck.smali", ".method public abstract o()Lboht;"),
    ("lgl.smali", ".method public static d(Lboht;)Ljava/lang/String;"),
):
    hits = []
    for p in ROOT.glob(f"smali*/{cls}"):
        txt = p.read_text(encoding="utf-8")
        if needle in txt:
            hits.append(p)
    if len(hits) != 1:
        raise SystemExit(f"native mediaId codec contract changed for {cls}: {hits}")

# V2 must still be present before applying only the V4 delta.
for marker in (
    ".field public static volatile vivoQueue:Ljava/util/List;",
    'const-string v1, "vivomusicmix_current_list"',
    'const-string v5, "vivo_qid_"',
):
    if marker not in browser:
        raise SystemExit(f"proven V2 marker missing: {marker}")
if NATIVE_FIELD in browser:
    raise SystemExit("V4 native mediaId sidecar already present")

# Add sidecar field without changing the normal MediaSession queue description.
queue_field = ".field public static volatile vivoQueue:Ljava/util/List;"
browser = browser.replace(
    queue_field,
    queue_field + "\n\n.field public static volatile vivoNativeIds:Ljava/util/Map;",
    1,
)

# Helper methods keep all high-register complexity out of Lkyi.j().
helpers = r'''
.method public static vivoResetNativeIds()V
    .locals 1

    new-instance v0, Ljava/util/concurrent/ConcurrentHashMap;
    invoke-direct {v0}, Ljava/util/concurrent/ConcurrentHashMap;-><init>()V
    sput-object v0, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeIds:Ljava/util/Map;
    return-void
.end method

.method public static vivoCaptureNativeId(Lnoq;)V
    .locals 4

    if-eqz p0, :vivo_native_capture_return

    sget-object v0, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeIds:Ljava/util/Map;
    if-eqz v0, :vivo_native_capture_return

    invoke-interface {p0}, Lnoq;->m()J
    move-result-wide v1
    invoke-static {v1, v2}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;
    move-result-object v1

    invoke-interface {p0}, Lazck;->o()Lboht;
    move-result-object v2
    if-eqz v2, :vivo_native_capture_return

    invoke-static {v2}, Llgl;->d(Lboht;)Ljava/lang/String;
    move-result-object v2
    if-eqz v2, :vivo_native_capture_return

    invoke-interface {v0, v1, v2}, Ljava/util/Map;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v0

    :vivo_native_capture_return
    return-void
.end method

.method public static vivoNativeId(J)Ljava/lang/String;
    .locals 2

    sget-object v0, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeIds:Ljava/util/Map;
    if-eqz v0, :vivo_native_lookup_none

    invoke-static {p0, p1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;
    move-result-object v1
    invoke-interface {v0, v1}, Ljava/util/Map;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Ljava/lang/String;
    return-object v0

    :vivo_native_lookup_none
    const/4 v0, 0x0
    return-object v0
.end method
'''

first_method = browser.find(".method ")
if first_method < 0:
    raise SystemExit("MusicBrowserService has no method anchor")
browser = browser[:first_method] + helpers + "\n" + browser[first_method:]

# Replace only V2's synthetic browser mediaId block.  The presentation fields
# (title/artist/artwork/extras) remain byte-for-byte equivalent at source level.
old_id = r'''    iget-wide v4, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v4, v5}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v4
    const-string v5, "vivo_qid_"
    invoke-virtual {v5, v4}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v4
'''
new_id = r'''    iget-wide v4, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v4, v5}, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeId(J)Ljava/lang/String;
    move-result-object v4
    if-eqz v4, :vivo_v2_queue_loop
'''
if browser.count(old_id) != 1:
    raise SystemExit(f"expected exactly one V2 synthetic mediaId block, got {browser.count(old_id)}")
browser = browser.replace(old_id, new_id, 1)

# Scope edits to Lkyi.j() only.
method_re = re.compile(r'(?ms)^\.method public final j\(\)V\n.*?^\.end method')
mm = method_re.search(kyi)
if not mm:
    raise SystemExit("Lkyi.j() not found")
method = mm.group(0)

# Reset sidecar only once a live MediaSession exists (the first :cond_0 in this exact method).
reset_anchor = "    :cond_0\n    iget-object v2, v0, Lkyi;->n:Lciqr;"
if method.count(reset_anchor) != 1:
    raise SystemExit(f"queue reset anchor changed: {method.count(reset_anchor)}")
method = method.replace(
    reset_anchor,
    "    :cond_0\n    invoke-static {}, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoResetNativeIds()V\n\n    iget-object v2, v0, Lkyi;->n:Lciqr;",
    1,
)

# Every non-null Lnoq that is about to become a QueueItem contributes its
# native YT Music mediaId to the sidecar. QueueItem itself remains unchanged.
capture_anchor = "    if-eqz v6, :cond_5\n\n    .line 181\n    .line 182\n    instance-of v7, v6, Lnog;"
if method.count(capture_anchor) != 1:
    raise SystemExit(f"queue capture anchor changed: {method.count(capture_anchor)}")
method = method.replace(
    capture_anchor,
    "    if-eqz v6, :cond_5\n\n    invoke-static {v6}, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoCaptureNativeId(Lnoq;)V\n\n    .line 181\n    .line 182\n    instance-of v7, v6, Lnog;",
    1,
)
kyi = kyi[:mm.start()] + method + kyi[mm.end():]

browser_path.write_text(browser, encoding="utf-8")
kyi_path.write_text(kyi, encoding="utf-8")

# Hard regression guards.
all_smali = []
for p in ROOT.glob("smali*/**/*.smali"):
    try:
        all_smali.append((p, p.read_text(encoding="utf-8")))
    except Exception:
        pass

if any(FORBIDDEN_TIME_KEY in txt for _, txt in all_smali):
    raise SystemExit("rejected V3/V3R1 metadata timing key reappeared")
# V4 must not patch the framework callback adapter. The only vivo_qid_ marker
# should have been removed from the V2 browser branch, and it must be absent globally.
if any(FORBIDDEN_SELECTION_PREFIX in txt for _, txt in all_smali):
    hits = [str(p) for p, txt in all_smali if FORBIDDEN_SELECTION_PREFIX in txt]
    raise SystemExit(f"synthetic vivo_qid_ selection path still present: {hits}")

browser_final = browser_path.read_text(encoding="utf-8")
kyi_final = kyi_path.read_text(encoding="utf-8")
for needle in (
    ".field public static volatile vivoNativeIds:Ljava/util/Map;",
    ".method public static vivoCaptureNativeId(Lnoq;)V",
    "Lazck;->o()Lboht;",
    "Llgl;->d(Lboht;)Ljava/lang/String;",
    ".method public static vivoNativeId(J)Ljava/lang/String;",
    "->vivoNativeId(J)Ljava/lang/String;",
):
    if needle not in browser_final:
        raise SystemExit(f"V4 browser marker missing: {needle}")
for needle in (
    "->vivoResetNativeIds()V",
    "->vivoCaptureNativeId(Lnoq;)V",
):
    if needle not in kyi_final:
        raise SystemExit(f"V4 queue capture marker missing: {needle}")

print(f"V4 native-mediaId browser patched: {browser_path}")
print(f"V4 native-mediaId queue sidecar:  {kyi_path}")
print("V4 leaves Lid and MediaMetadata timing path untouched")
