#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Start from the exact V4N sidecar architecture, which itself starts from the
# runtime-stable V2 c0/real-queue implementation. V5 changes only which queue
# endpoint is encoded into the Vivo browser MediaItem ID.
v4n = Path(__file__).with_name("ytmusic_vivo_c0_native_mediaid_v4n.py")
if not v4n.is_file():
    raise SystemExit(f"missing V4N patcher: {v4n}")
subprocess.run([sys.executable, str(v4n), str(ROOT)], check=True)

kyi_hits = [p for p in ROOT.glob("smali*/kyi.smali") if ".method public final j()V" in p.read_text(encoding="utf-8")]
if len(kyi_hits) != 1:
    raise SystemExit(f"expected one kyi.j queue producer, got {kyi_hits}")
KYI = kyi_hits[0]
kyi = KYI.read_text(encoding="utf-8")

method_re = re.compile(r'(?ms)^\.method public final j\(\)V\n(.*?)^\.end method')
mm = method_re.search(kyi)
if not mm:
    raise SystemExit("Lkyi.j() not found")
method = mm.group(0)

# V4N used Lnoq.o(), now proven by exact stock RE to be the Lazck queue DELETE
# endpoint role. Replace only that injected mapping source with the same playable
# object stock onSkipToQueueItem uses: Lnoq.n() -> Lazmi.b:Lboht.
old = r'''    invoke-interface {v6}, Lnoq;->o()Lboht;
    move-result-object v9
    if-eqz v9, :vivo_v4n_map_done

    invoke-static {v9}, Llgl;->d(Lboht;)Ljava/lang/String;
'''
new = r'''    invoke-interface {v6}, Lnoq;->n()Lazmi;
    move-result-object v9
    if-eqz v9, :vivo_v4n_map_done

    iget-object v9, v9, Lazmi;->b:Lboht;
    if-eqz v9, :vivo_v4n_map_done

    invoke-static {v9}, Llgl;->d(Lboht;)Ljava/lang/String;
'''
if method.count(old) != 1:
    raise SystemExit(f"expected exactly one V4N o()-endpoint mapping block, got {method.count(old)}")
method = method.replace(old, new, 1)

if "Lnoq;->o()Lboht;" in method:
    raise SystemExit("rejected queue DELETE endpoint still present in Lkyi.j()")
if method.count("Lnoq;->n()Lazmi;") != 1:
    raise SystemExit(f"expected one playable n() mapping call, got {method.count('Lnoq;->n()Lazmi;')}")
if method.count("Lazmi;->b:Lboht;") != 1:
    raise SystemExit(f"expected one Lazmi.b playable endpoint read, got {method.count('Lazmi;->b:Lboht;')}")
if method.count("Llgl;->d(Lboht;)Ljava/lang/String;") != 1:
    raise SystemExit("native mediaId encoder count changed")

kyi = kyi[:mm.start()] + method + kyi[mm.end():]
KYI.write_text(kyi, encoding="utf-8")

# Architecture guards: browser sidecar remains V4N/V2-derived; only producer
# endpoint role changed. No callback/timing instrumentation belongs in V5.
browser_hits = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
if len(browser_hits) != 1:
    raise SystemExit(f"expected one MusicBrowserService, got {browser_hits}")
BROWSER = browser_hits[0]
browser = BROWSER.read_text(encoding="utf-8")
for needle in (
    "field public static volatile vivoQueue:Ljava/util/List;",
    "field public static volatile vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
    "ConcurrentHashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;",
    "vivo_qid_",
):
    if needle not in browser:
        raise SystemExit(f"missing V2/V4N browser invariant: {needle}")

callback_hits = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
if len(callback_hits) != 1:
    raise SystemExit(f"expected one Lid callback, got {callback_hits}")
callback = callback_hits[0].read_text(encoding="utf-8")
if "vivo_qid_" in callback or "vivo_v3" in callback or "Long;->parseLong(Ljava/lang/String;)J" in callback:
    raise SystemExit("rejected queueId selection hook leaked into Lid")

for p in ROOT.glob("smali*/**/*.smali"):
    try:
        text = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "vivomusicmix.media.metadata.support_event" in text:
        raise SystemExit(f"rejected timing metadata patch present: {p}")
    if "YTM_C0TRACE" in text or "VivoC0Trace;" in text:
        raise SystemExit(f"observation probe leaked into functional V5: {p}")

patched = KYI.read_text(encoding="utf-8")
for needle in (
    "Lnoq;->n()Lazmi;",
    "Lazmi;->b:Lboht;",
    "Llgl;->d(Lboht;)Ljava/lang/String;",
    "ConcurrentHashMap;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;",
    "MusicBrowserService;->vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
):
    if needle not in patched:
        raise SystemExit(f"missing V5 playable mapping marker: {needle}")

print(f"V5 patched queue model: {KYI}")
print("V5 maps Vivo rows from stock-playable Lnoq.n()->Lazmi.b, not DELETE Lnoq.o()")
