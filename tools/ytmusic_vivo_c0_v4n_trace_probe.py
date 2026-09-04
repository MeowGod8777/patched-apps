#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Reproduce the exact V4N runtime path first; this probe observes it but does not
# change its selection, metadata, timing, queue, or session semantics.
v4n = Path(__file__).with_name("ytmusic_vivo_c0_native_mediaid_v4n.py")
if not v4n.is_file():
    raise SystemExit(f"missing V4N patcher: {v4n}")
subprocess.run([sys.executable, str(v4n), str(ROOT)], check=True)

TRACE_DESC = "Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;"

browser_hits = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
kyi_hits = [p for p in ROOT.glob("smali*/kyi.smali") if ".method public final j()V" in p.read_text(encoding="utf-8")]
lag_hits = [p for p in ROOT.glob("smali*/lag.smali") if ".method public final g(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
id_hits = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
ii_hits = [p for p in ROOT.glob("smali*/ii.smali") if ".method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V" in p.read_text(encoding="utf-8")]
if len(browser_hits) != 1 or len(kyi_hits) != 1 or len(lag_hits) != 1 or len(id_hits) != 1 or len(ii_hits) != 1:
    raise SystemExit(f"unexpected target counts browser={browser_hits} kyi={kyi_hits} lag={lag_hits} id={id_hits} ii={ii_hits}")

BROWSER, KYI, LAG, ID, II = browser_hits[0], kyi_hits[0], lag_hits[0], id_hits[0], ii_hits[0]
HELPER = BROWSER.parent / "VivoC0Trace.smali"
if HELPER.exists():
    raise SystemExit(f"trace helper already exists: {HELPER}")

helper = r'''.class public final Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;
.super Ljava/lang/Object;
.source "VivoC0Trace"

.field private static final TAG:Ljava/lang/String; = "YTM_C0TRACE"

.method private constructor <init>()V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method private static log(Ljava/lang/String;)V
    .locals 1
    const-string v0, "YTM_C0TRACE"
    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

.method public static browse(Ljava/lang/String;Landroid/os/Bundle;)V
    .locals 2
    const-string v0, "BROWSE parent="
    invoke-static {p0}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    const-string v1, " extras="
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {p1}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static queue(JLjava/lang/String;)V
    .locals 2
    const-string v0, "QUEUE qid="
    invoke-static {p0, p1}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    const-string v1, " native="
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {p2}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static browserItem(Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;Ljava/lang/String;)V
    .locals 3
    const-string v2, "ITEM qid="
    iget-wide v0, p0, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->b:J
    invoke-static {v0, v1}, Ljava/lang/Long;->toString(J)Ljava/lang/String;
    move-result-object v0
    invoke-virtual {v2, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    const-string v0, " mediaId="
    invoke-virtual {v2, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-static {p1}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v0
    invoke-virtual {v2, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-static {v2}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static entry(Ljava/lang/String;Landroid/os/Bundle;)V
    .locals 2
    const-string v0, "ENTRY mediaId="
    invoke-static {p0}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    const-string v1, " extras="
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {p1}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static decoded(Lavev;)V
    .locals 2
    const-string v0, "DECODE value="
    invoke-static {p0}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static endpoint(Lboht;)V
    .locals 2
    const-string v0, "ENDPOINT value="
    invoke-static {p0}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static beforeDispatch()V
    .locals 1
    const-string v0, "DISPATCH_BEFORE Llbg.o"
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static afterDispatch()V
    .locals 1
    const-string v0, "DISPATCH_AFTER Llbg.o"
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method
'''
HELPER.write_text(helper, encoding="utf-8")


def method_block(src: str, signature: str):
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n.*?^\.end method')
    m = pat.search(src)
    if not m:
        raise SystemExit(f"method not found: {signature}")
    return m, m.group(0)


def inject_entry(method: str, call: str) -> str:
    reg = re.search(r'(?m)^\s*\.(?:locals|registers)\s+\d+\s*$', method)
    if not reg:
        raise SystemExit("method register directive missing")
    return method[:reg.end()] + "\n\n" + call + "\n" + method[reg.end():]


def inject_after_object_result(method: str, needle: str, trace_call_fmt: str, max_scan: int = 30) -> str:
    """Find one invoke by descriptor, then the first move-result-object after it.

    apktool may place .line/.local/labels/comments between invoke and move-result.
    We accept only non-executable metadata while scanning; another real opcode means
    the assumed result boundary is unsafe and the build must fail.
    """
    lines = method.splitlines()
    hits = [i for i, line in enumerate(lines) if needle in line and line.lstrip().startswith("invoke-")]
    if len(hits) != 1:
        raise SystemExit(f"call count for {needle}: {len(hits)}")
    i = hits[0]
    for j in range(i + 1, min(len(lines), i + 1 + max_scan)):
        stripped = lines[j].strip()
        m = re.fullmatch(r'move-result-object\s+(\S+)', stripped)
        if m:
            reg = m.group(1)
            lines.insert(j + 1, trace_call_fmt.format(reg=reg))
            return "\n".join(lines)
        if not stripped or stripped.startswith((".", ":", "#")):
            continue
        raise SystemExit(f"unexpected executable before move-result for {needle}: {stripped}")
    raise SystemExit(f"move-result-object not found after {needle}")


def wrap_single_invoke(method: str, needle: str, before: str, after: str) -> str:
    lines = method.splitlines()
    hits = [i for i, line in enumerate(lines) if needle in line and line.lstrip().startswith("invoke-")]
    if len(hits) != 1:
        raise SystemExit(f"dispatch call count for {needle}: {len(hits)}")
    i = hits[0]
    lines.insert(i, before)
    lines.insert(i + 2, after)
    return "\n".join(lines)


# 1) Browse entry marker — no locals/register count changes.
browser = BROWSER.read_text(encoding="utf-8")
bm, bmethod = method_block(browser, "public final b(Ljava/lang/String;Lbzu;Landroid/os/Bundle;)V")
bmethod2 = inject_entry(
    bmethod,
    "    invoke-static {p1, p3}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->browse(Ljava/lang/String;Landroid/os/Bundle;)V",
)
if bmethod2.count("VivoC0Trace;->browse") != 1:
    raise SystemExit("browse trace insertion count wrong")
browser = browser[:bm.start()] + bmethod2 + browser[bm.end():]

# 2) Concrete MediaItem ID returned by V4N.
item_anchor = r'''    :vivo_v4n_mediaid_ready

    iget-object v2, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->a:Landroid/support/v4/media/MediaDescriptionCompat;'''
item_repl = r'''    :vivo_v4n_mediaid_ready

    invoke-static {v2, v4}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->browserItem(Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;Ljava/lang/String;)V

    iget-object v2, v2, Landroid/support/v4/media/session/MediaSessionCompat$QueueItem;->a:Landroid/support/v4/media/MediaDescriptionCompat;'''
if browser.count(item_anchor) != 1:
    raise SystemExit(f"V4N browser item anchor count={browser.count(item_anchor)}")
browser = browser.replace(item_anchor, item_repl, 1)
BROWSER.write_text(browser, encoding="utf-8")

# 3) QueueId -> native ID mapping marker inside the existing V4N mapping block.
kyi = KYI.read_text(encoding="utf-8")
queue_anchor = r'''    invoke-static {v9}, Llgl;->d(Lboht;)Ljava/lang/String;
    move-result-object v9
    if-eqz v9, :vivo_v4n_map_done
'''
queue_repl = queue_anchor + r'''
    invoke-static {v7, v8, v9}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->queue(JLjava/lang/String;)V
'''
if kyi.count(queue_anchor) != 1:
    raise SystemExit(f"V4N queue mapping anchor count={kyi.count(queue_anchor)}")
kyi = kyi.replace(queue_anchor, queue_repl, 1)
KYI.write_text(kyi, encoding="utf-8")

# 4-7) Trace the real callback target without touching framework adapter Lid.
lag = LAG.read_text(encoding="utf-8")
lm, g = method_block(lag, "public final g(Ljava/lang/String;Landroid/os/Bundle;)V")
g = inject_entry(
    g,
    "    invoke-static {p1, p2}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->entry(Ljava/lang/String;Landroid/os/Bundle;)V",
)
g = inject_after_object_result(
    g,
    "Laveu;->b(Ljava/lang/String;)Lavev;",
    "    invoke-static {{{reg}}}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->decoded(Lavev;)V",
)
g = inject_after_object_result(
    g,
    "Llbg;->a(Lavev;)Lboht;",
    "    invoke-static {{{reg}}}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->endpoint(Lboht;)V",
)
g = wrap_single_invoke(
    g,
    "Llbg;->o(Lckob;Lboht;Landroid/os/Bundle;)V",
    "    invoke-static {}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->beforeDispatch()V",
    "    invoke-static {}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->afterDispatch()V",
)

for marker in ("->entry(", "->decoded(", "->endpoint(", "->beforeDispatch()", "->afterDispatch()"):
    if g.count(marker) != 1:
        raise SystemExit(f"Llag trace marker count wrong for {marker}: {g.count(marker)}")
lag = lag[:lm.start()] + g + lag[lm.end():]
LAG.write_text(lag, encoding="utf-8")

# Hard scope assertions. Lid and Lii.m are deliberately not modified here.
id_text = ID.read_text(encoding="utf-8")
ii_text = II.read_text(encoding="utf-8")
if TRACE_DESC in id_text:
    raise SystemExit("trace leaked into Lid")
if TRACE_DESC in ii_text:
    raise SystemExit("trace leaked into Lii")
if "vivo_qid_" in id_text or "Long;->parseLong(Ljava/lang/String;)J" in id_text:
    raise SystemExit("rejected V3 selection logic present in Lid")
if "vivomusicmix.media.metadata.support_event" in ii_text:
    raise SystemExit("rejected timing patch present in Lii")

# V4N behavior must still be present exactly as the traced subject.
for needle in (
    "vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
    ":vivo_v4n_mediaid_fallback",
    ":vivo_v4n_mediaid_ready",
):
    if needle not in BROWSER.read_text(encoding="utf-8"):
        raise SystemExit(f"missing V4N browser subject marker: {needle}")
for needle in (
    "Lnoq;->o()Lboht;",
    "Llgl;->d(Lboht;)Ljava/lang/String;",
    "MusicBrowserService;->vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;",
):
    if needle not in KYI.read_text(encoding="utf-8"):
        raise SystemExit(f"missing V4N queue subject marker: {needle}")

print(f"trace helper: {HELPER}")
print(f"traced browser: {BROWSER}")
print(f"traced queue producer: {KYI}")
print(f"traced native callback target: {LAG}")
print("V4N trace probe markers OK; Lid/Lii remain out of scope")
