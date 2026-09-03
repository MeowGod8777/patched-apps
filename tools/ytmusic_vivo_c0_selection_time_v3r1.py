#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Preserve the exact c0/root/real-queue implementation that already passed V2
# on the user's iQOO 12 Pro. V3R1 is only a delta on top of that proven patch.
v2 = Path(__file__).with_name("ytmusic_vivo_c0_real_queue_v2.py")
if not v2.is_file():
    raise SystemExit(f"missing proven V2 patcher: {v2}")
subprocess.run([sys.executable, str(v2), str(ROOT)], check=True)

MEDIA_ID_PREFIX = "vivo_qid_"
SUPPORT_EVENT_KEY = "vivomusicmix.media.metadata.support_event"

# Locate the exact YT Music MediaSession sink and callback after V2 has patched
# the browser/queue path.
ii_paths = [
    p for p in ROOT.glob("smali*/ii.smali")
    if "setMetadata(Landroid/media/MediaMetadata;)V" in p.read_text(encoding="utf-8")
    and ".method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V" in p.read_text(encoding="utf-8")
]
id_paths = [
    p for p in ROOT.glob("smali*/id.smali")
    if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")
    and "onSkipToQueueItem(J)V" in p.read_text(encoding="utf-8")
]
if len(ii_paths) != 1:
    raise SystemExit(f"expected exactly one MediaSession ii.smali, got: {ii_paths}")
if len(id_paths) != 1:
    raise SystemExit(f"expected exactly one MediaSession callback id.smali, got: {id_paths}")

ii_path = ii_paths[0]
id_path = id_paths[0]
ii = ii_path.read_text(encoding="utf-8")
id_s = id_path.read_text(encoding="utf-8")

if SUPPORT_EVENT_KEY in ii:
    raise SystemExit("support_event already present before V3R1 delta")
if MEDIA_ID_PREFIX in id_s:
    raise SystemExit("selection prefix already present before V3R1 delta")
for needle in (
    ".method public final onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V",
    ".method public final onSkipToQueueItem(J)V",
    "Lie;->g(Ljava/lang/String;Landroid/os/Bundle;)V",
    "Lie;->t(J)V",
):
    if needle not in id_s:
        raise SystemExit(f"selection callback contract changed: missing {needle}")


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


def inject_after_anchor_in_method(src: str, signature: str, anchor: str, injection: str) -> str:
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n(.*?)^\.end method')
    mm = pat.search(src)
    if not mm:
        raise SystemExit(f"method not found for anchor injection: {signature}")
    method = mm.group(0)
    if method.count(anchor) != 1:
        raise SystemExit(f"expected one anchor {anchor!r} in {signature}, got {method.count(anchor)}")
    method = method.replace(anchor, anchor + "\n" + injection.strip("\n"), 1)
    return src[:mm.start()] + method + src[mm.end():]


# c0 list selection: our Browser mediaId encodes YT Music's own QueueItem.b.
# Reuse YT Music's native onSkipToQueueItem -> Lie.t(long) path.
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

# YT Music already publishes real DURATION and PlaybackState position. Add only
# Vivo's SEEK_POSITION capability. IMPORTANT: this block is injected AFTER the
# :cond_c convergence label, so it runs whether MediaMetadataCompat.c was
# pre-materialized or built inside ii.m during this call.
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

id_s = inject_after_registers(
    id_s,
    "public final onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V",
    min_locals=3,
    param_regs=3,
    injection=selection_inject,
)
ii = inject_after_anchor_in_method(
    ii,
    "public final m(Landroid/support/v4/media/MediaMetadataCompat;)V",
    "    :cond_c",
    time_inject,
)

id_path.write_text(id_s, encoding="utf-8")
ii_path.write_text(ii, encoding="utf-8")

# Semantic static assertions, including the control-flow placement that caused
# the rejected first V3 build.
assert MEDIA_ID_PREFIX in id_s
assert "Long;->parseLong(Ljava/lang/String;)J" in id_s
assert "Lid;->onSkipToQueueItem(J)V" in id_s
assert SUPPORT_EVENT_KEY in ii
assert "const-wide/16 v3, 0x10" in ii
assert "MediaMetadata$Builder;-><init>(Landroid/media/MediaMetadata;)V" in ii

m_pat = re.compile(r'(?ms)^\.method public final m\(Landroid/support/v4/media/MediaMetadataCompat;\)V\n(.*?)^\.end method')
mm = m_pat.search(ii)
if not mm:
    raise SystemExit("patched ii.m not found")
m_body = mm.group(0)
label_pos = m_body.index("    :cond_c")
key_pos = m_body.index(SUPPORT_EVENT_KEY)
original_get_pos = m_body.index("iget-object p1, p1, Landroid/support/v4/media/MediaMetadataCompat;->c:Landroid/media/MediaMetadata;", label_pos)
if not (label_pos < key_pos < original_get_pos):
    raise SystemExit(
        f"support_event placement invalid: label={label_pos}, key={key_pos}, original_get={original_get_pos}"
    )

print(f"V3R1 delta patched selection: {id_path}")
print(f"V3R1 delta patched time:      {ii_path}")
print("V3R1 support_event executes after :cond_c convergence label")
