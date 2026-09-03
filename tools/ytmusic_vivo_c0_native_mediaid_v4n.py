#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Start from the exact V2 c0/root/real-queue implementation that passed runtime.
v2 = Path(__file__).with_name("ytmusic_vivo_c0_real_queue_v2.py")
if not v2.is_file():
    raise SystemExit(f"missing proven V2 patcher: {v2}")
subprocess.run([sys.executable, str(v2), str(ROOT)], check=True)

BROWSER = ROOT / "smali_classes5/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"
if not BROWSER.is_file():
    hits = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
    if len(hits) != 1:
        raise SystemExit(f"expected one MusicBrowserService, got {hits}")
    BROWSER = hits[0]

kyi_hits = [p for p in ROOT.glob("smali*/kyi.smali") if ".method public final j()V" in p.read_text(encoding="utf-8")]
if len(kyi_hits) != 1:
    raise SystemExit(f"expected one kyi.j queue producer, got {kyi_hits}")
KYI = kyi_hits[0]

lgl_hits = [p for p in ROOT.glob("smali*/lgl.smali") if re.search(r'(?m)^\.method .* static d\(Lboht;\)Ljava/lang/String;$', p.read_text(encoding="utf-8"))]
if len(lgl_hits) != 1:
    raise SystemExit(f"expected one Llgl.d(Lboht)->String encoder, got {lgl_hits}")

browser = BROWSER.read_text(encoding="utf-8")
kyi = KYI.read_text(encoding="utf-8")

if "vivoNativeIds" in browser or "vivo_v4n_" in browser or "vivo_v4n_" in kyi:
    raise SystemExit("V4N markers already present before patch")
if "field public static volatile vivoQueue:Ljava/util/List;" not in browser:
    raise SystemExit("proven V2 vivoQueue field missing")
if "vivo_qid_" not in browser:
    raise SystemExit("proven V2 synthetic mediaId fallback missing")

# Add sidecar map field. It is published as a fresh ConcurrentHashMap per queue rebuild.
field_anchor = ".field public static volatile vivoQueue:Ljava/util/List;"
browser = browser.replace(
    field_anchor,
    field_anchor + "\n\n.field public static volatile vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
    1,
)

# Replace only the V2 synthetic browser mediaId construction with a sidecar lookup.
old_id_block = r'''    iget-wide v4, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v4, v5}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v4
    const-string v5, "vivo_qid_"
    invoke-virtual {v5, v4}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v4
'''
new_id_block = r'''    iget-wide v4, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v4, v5}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;
    move-result-object v4

    sget-object v5, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;
    if-eqz v5, :vivo_v4n_mediaid_fallback

    invoke-virtual {v5, v4}, Ljava/util/concurrent/ConcurrentHashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v4
    check-cast v4, Ljava/lang/String;
    if-nez v4, :vivo_v4n_mediaid_ready

    :vivo_v4n_mediaid_fallback
    iget-wide v4, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v4, v5}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v4
    const-string v5, "vivo_qid_"
    invoke-virtual {v5, v4}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v4

    :vivo_v4n_mediaid_ready
'''
if browser.count(old_id_block) != 1:
    raise SystemExit(f"expected exactly one V2 mediaId block, got {browser.count(old_id_block)}")
browser = browser.replace(old_id_block, new_id_block, 1)

# Patch only Lkyi.j(): allocate one fresh map local, capture queueId->nativeMediaId while
# Lnoq still carries its Lboht endpoint, then publish the map alongside the queue refresh.
method_re = re.compile(r'(?ms)^\.method public final j\(\)V\n(.*?)^\.end method')
mm = method_re.search(kyi)
if not mm:
    raise SystemExit("Lkyi.j() not found")
method = mm.group(0)

if ".locals 26" not in method:
    raise SystemExit("Lkyi.j() locals changed from validated .locals 26")
if re.search(r'\bv26\b', method):
    raise SystemExit("validated Lkyi.j() unexpectedly already uses raw v26")
method = method.replace(".locals 26", ".locals 27", 1)

init_anchor = "    move-object/from16 v0, p0\n"
init_block = r'''

    new-instance v26, Ljava/util/concurrent/ConcurrentHashMap;
    invoke-direct/range {v26 .. v26}, Ljava/util/concurrent/ConcurrentHashMap;-><init>()V
'''
if method.count(init_anchor) != 1:
    raise SystemExit("Lkyi.j() initial p0 staging anchor changed")
method = method.replace(init_anchor, init_anchor + init_block, 1)

capture_anchor = "    if-eqz v6, :cond_5\n"
capture_block = r'''

    invoke-interface {v6}, Lnoq;->m()J
    move-result-wide v7

    invoke-interface {v6}, Lnoq;->o()Lboht;
    move-result-object v9
    if-eqz v9, :vivo_v4n_map_done

    invoke-static {v9}, Llgl;->d(Lboht;)Ljava/lang/String;
    move-result-object v9
    if-eqz v9, :vivo_v4n_map_done

    invoke-static {v7, v8}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;
    move-result-object v10
    move-object/from16 v11, v26
    invoke-virtual {v11, v10, v9}, Ljava/util/concurrent/ConcurrentHashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;

    :vivo_v4n_map_done
'''
if method.count(capture_anchor) != 1:
    raise SystemExit(f"expected one Lkyi queue-item null-check anchor, got {method.count(capture_anchor)}")
method = method.replace(capture_anchor, capture_anchor + capture_block, 1)

publish_anchor = "    iget-object v4, v1, Liq;->a:Lig;\n"
publish_block = r'''    sput-object v26, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;

'''
if method.count(publish_anchor) != 1:
    raise SystemExit(f"expected one Liq queue sink anchor, got {method.count(publish_anchor)}")
method = method.replace(publish_anchor, publish_block + publish_anchor, 1)

kyi = kyi[:mm.start()] + method + kyi[mm.end():]
BROWSER.write_text(browser, encoding="utf-8")
KYI.write_text(kyi, encoding="utf-8")

# Hard regression guards: V4N must not bring back rejected selection/time patches.
callback_hits = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
if len(callback_hits) != 1:
    raise SystemExit(f"expected one framework callback Lid, got {callback_hits}")
callback = callback_hits[0].read_text(encoding="utf-8")
if "vivo_qid_" in callback or "vivo_v3" in callback or "Long;->parseLong(Ljava/lang/String;)J" in callback:
    raise SystemExit("rejected V3/V3S selection hook leaked into Lid")

for p in ROOT.glob("smali*/**/*.smali"):
    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "vivomusicmix.media.metadata.support_event" in text:
        raise SystemExit(f"rejected timing metadata patch present: {p}")

# Static assertions for intended architecture.
patched_browser = BROWSER.read_text(encoding="utf-8")
patched_kyi = KYI.read_text(encoding="utf-8")
for needle in (
    "field public static volatile vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
    "ConcurrentHashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;",
    ":vivo_v4n_mediaid_fallback",
    ":vivo_v4n_mediaid_ready",
):
    if needle not in patched_browser:
        raise SystemExit(f"missing V4N browser marker: {needle}")
for needle in (
    ".locals 27",
    "Lnoq;->o()Lboht;",
    "Llgl;->d(Lboht;)Ljava/lang/String;",
    "ConcurrentHashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;",
    "MusicBrowserService;->vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
):
    if needle not in patched_kyi:
        raise SystemExit(f"missing V4N queue-model marker: {needle}")

print(f"V4N patched browser: {BROWSER}")
print(f"V4N patched queue model: {KYI}")
print("V4N uses native YT Music Llgl.d(Lboht) mediaIds and leaves Lid/metadata untouched")
