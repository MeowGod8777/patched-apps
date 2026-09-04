#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Reproduce the exact selection-success V5 architecture first. This probe adds
# observation-only logging at existing MediaSession sinks and does not alter
# selection, metadata, timing, queue, capability, or playback values.
v5 = Path(__file__).with_name("ytmusic_vivo_c0_playable_mediaid_v5.py")
if not v5.is_file():
    raise SystemExit(f"missing V5 patcher: {v5}")
subprocess.run([sys.executable, str(v5), str(ROOT)], check=True)

browser_hits = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
lag_hits = [p for p in ROOT.glob("smali*/lag.smali") if ".method public final g(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
ii_hits = [p for p in ROOT.glob("smali*/ii.smali") if ".method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V" in p.read_text(encoding="utf-8") and ".method public final n(Landroid/support/v4/media/session/PlaybackStateCompat;)V" in p.read_text(encoding="utf-8")]
id_hits = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
kyi_hits = [p for p in ROOT.glob("smali*/kyi.smali") if ".method public final j()V" in p.read_text(encoding="utf-8")]
if not (len(browser_hits) == len(lag_hits) == len(ii_hits) == len(id_hits) == len(kyi_hits) == 1):
    raise SystemExit(f"unexpected targets browser={browser_hits} lag={lag_hits} ii={ii_hits} id={id_hits} kyi={kyi_hits}")

BROWSER, LAG, II, ID, KYI = browser_hits[0], lag_hits[0], ii_hits[0], id_hits[0], kyi_hits[0]
HELPER = BROWSER.parent / "VivoV5StateTrace.smali"
if HELPER.exists():
    raise SystemExit(f"state helper already exists: {HELPER}")

helper = r'''.class public final Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;
.super Ljava/lang/Object;
.source "VivoV5StateTrace"

.field private static final TAG:Ljava/lang/String; = "YTM_V5STATE"

.method private constructor <init>()V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method private static log(Ljava/lang/String;)V
    .locals 1
    const-string v0, "YTM_V5STATE"
    invoke-static {v0, p0}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void
.end method

.method public static select(Ljava/lang/String;)V
    .locals 2
    const-string v0, "SELECT mediaId="
    invoke-static {p0}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static meta(Landroid/support/v4/media/MediaMetadataCompat;)V
    .locals 8
    if-nez p0, :meta_nonnull
    const-string v0, "META null"
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->log(Ljava/lang/String;)V
    return-void

    :meta_nonnull
    iget-object v0, p0, Landroid/support/v4/media/MediaMetadataCompat;->b:Landroid/os/Bundle;
    if-nez v0, :meta_bundle
    const-string v1, "META bundle=null"
    invoke-static {v1}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->log(Ljava/lang/String;)V
    return-void

    :meta_bundle
    const-string v1, "android.media.metadata.TITLE"
    invoke-virtual {v0, v1}, Landroid/os/Bundle;->get(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v1

    const-string v2, "android.media.metadata.ARTIST"
    invoke-virtual {v0, v2}, Landroid/os/Bundle;->get(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v2

    const-string v7, "android.media.metadata.DURATION"
    const-wide/16 v5, -0x1
    invoke-virtual {v0, v7, v5, v6}, Landroid/os/BaseBundle;->getLong(Ljava/lang/String;J)J
    move-result-wide v3

    const-string v7, "vivomusicmix.media.metadata.support_event"
    const-wide/16 v5, -0x1
    invoke-virtual {v0, v7, v5, v6}, Landroid/os/BaseBundle;->getLong(Ljava/lang/String;J)J
    move-result-wide v5

    new-instance v0, Ljava/lang/StringBuilder;
    const-string v7, "META title="
    invoke-direct {v0, v7}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-static {v1}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, " artist="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-static {v2}, Ljava/lang/String;->valueOf(Ljava/lang/Object;)Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, " duration="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v3, v4}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v1, " support="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v5, v6}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static state(Landroid/support/v4/media/session/PlaybackStateCompat;)V
    .locals 9
    if-nez p0, :state_nonnull
    const-string v0, "STATE null"
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->log(Ljava/lang/String;)V
    return-void

    :state_nonnull
    iget v1, p0, Landroid/support/v4/media/session/PlaybackStateCompat;->a:I
    iget-wide v2, p0, Landroid/support/v4/media/session/PlaybackStateCompat;->b:J
    iget v4, p0, Landroid/support/v4/media/session/PlaybackStateCompat;->d:F
    iget-wide v5, p0, Landroid/support/v4/media/session/PlaybackStateCompat;->h:J
    iget-wide v7, p0, Landroid/support/v4/media/session/PlaybackStateCompat;->j:J

    new-instance v0, Ljava/lang/StringBuilder;
    const-string p0, "STATE state="
    invoke-direct {v0, p0}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string p0, " pos="
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v2, v3}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string p0, " speed="
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v4}, Ljava/lang/StringBuilder;->append(F)Ljava/lang/StringBuilder;
    const-string p0, " update="
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v5, v6}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string p0, " qid="
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, v7, v8}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->log(Ljava/lang/String;)V
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

# Observe the native selection callback entry.
lag = LAG.read_text(encoding="utf-8")
lm, g = method_block(lag, "public final g(Ljava/lang/String;Landroid/os/Bundle;)V")
g2 = inject_entry(g, "    invoke-static {p1}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->select(Ljava/lang/String;)V")
lag = lag[:lm.start()] + g2 + lag[lm.end():]
LAG.write_text(lag, encoding="utf-8")

# Observe the exact MediaSession metadata and PlaybackState sinks. The helper
# reads fields only; target register counts and all original control flow remain unchanged.
ii = II.read_text(encoding="utf-8")
mm, mbody = method_block(ii, "public final m(Landroid/support/v4/media/MediaMetadataCompat;)V")
mbody2 = inject_entry(mbody, "    invoke-static {p1}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->meta(Landroid/support/v4/media/MediaMetadataCompat;)V")
ii = ii[:mm.start()] + mbody2 + ii[mm.end():]

nm, nbody = method_block(ii, "public final n(Landroid/support/v4/media/session/PlaybackStateCompat;)V")
nbody2 = inject_entry(nbody, "    invoke-static {p1}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoV5StateTrace;->state(Landroid/support/v4/media/session/PlaybackStateCompat;)V")
ii = ii[:nm.start()] + nbody2 + ii[nm.end():]
II.write_text(ii, encoding="utf-8")

# Hard non-perturbation / architecture guards.
id_text = ID.read_text(encoding="utf-8")
kyi = KYI.read_text(encoding="utf-8")
if "vivo_qid_" in id_text or "Long;->parseLong(Ljava/lang/String;)J" in id_text or "vivo_v3" in id_text:
    raise SystemExit("rejected queueId selection hook leaked into Lid")
if kyi.count("Lnoq;->n()Lazmi;") != 1 or kyi.count("Lazmi;->b:Lboht;") != 1:
    raise SystemExit("V5 playable endpoint mapping missing")
jm = re.search(r'(?ms)^\.method public final j\(\)V\n.*?^\.end method', kyi)
if not jm:
    raise SystemExit("Lkyi.j missing after V5 patch")
j = jm.group(0)
if "Lnoq;->o()Lboht;" in j:
    raise SystemExit("rejected DELETE endpoint leaked into V5 mapping")
if "Lnoq;->p()Lboht;" in j:
    raise SystemExit("rejected secondary endpoint leaked into V5 mapping")

for p in ROOT.glob("smali*/**/*.smali"):
    try:
        t = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if "YTM_C0TRACE" in t or "VivoC0Trace;" in t:
        raise SystemExit(f"old V4N trace leaked into V5 state probe: {p}")
    if "vivomusicmix.media.metadata.support_event" in t and p != HELPER:
        raise SystemExit(f"functional support_event patch leaked outside observation helper: {p}")

helper_final = HELPER.read_text(encoding="utf-8")
if "putLong" in helper_final and "vivomusicmix.media.metadata.support_event" in helper_final:
    raise SystemExit("state helper must never write support_event")
if helper_final.count("YTM_V5STATE") != 2:
    raise SystemExit("unexpected state trace tag count")
if LAG.read_text(encoding="utf-8").count("VivoV5StateTrace;->select") != 1:
    raise SystemExit("select trace insertion count wrong")
if II.read_text(encoding="utf-8").count("VivoV5StateTrace;->meta") != 1:
    raise SystemExit("metadata trace insertion count wrong")
if II.read_text(encoding="utf-8").count("VivoV5StateTrace;->state") != 1:
    raise SystemExit("state trace insertion count wrong")

print(f"V5 state probe helper: {HELPER}")
print(f"V5 state probe Llag:   {LAG}")
print(f"V5 state probe Lii:    {II}")
print("PASS: observation-only SELECT/META/STATE logging over V5 playable selection")
