#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Preserve the exact V2 c0/root/real-queue implementation that already passed
# on the user's iQOO 12 Pro. V3S adds selection only; it MUST NOT touch metadata.
v2 = Path(__file__).with_name("ytmusic_vivo_c0_real_queue_v2.py")
if not v2.is_file():
    raise SystemExit(f"missing proven V2 patcher: {v2}")
subprocess.run([sys.executable, str(v2), str(ROOT)], check=True)

MEDIA_ID_PREFIX = "vivo_qid_"
FORBIDDEN_TIME_KEY = "vivomusicmix.media.metadata.support_event"

id_paths = [
    p for p in ROOT.glob("smali*/id.smali")
    if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")
    and "onSkipToQueueItem(J)V" in p.read_text(encoding="utf-8")
]
if len(id_paths) != 1:
    raise SystemExit(f"expected exactly one MediaSession callback id.smali, got: {id_paths}")

id_path = id_paths[0]
id_s = id_path.read_text(encoding="utf-8")
if MEDIA_ID_PREFIX in id_s:
    raise SystemExit("selection prefix already present before V3S delta")
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


selection_inject = r'''
    if-eqz p1, :vivo_v3s_original_play_from_media_id
    const-string v0, "vivo_qid_"
    invoke-virtual {p1, v0}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z
    move-result v0
    if-eqz v0, :vivo_v3s_original_play_from_media_id

    const/16 v0, 0x9
    invoke-virtual {p1, v0}, Ljava/lang/String;->substring(I)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Ljava/lang/Long;->parseLong(Ljava/lang/String;)J
    move-result-wide v1
    invoke-virtual {p0, v1, v2}, Lid;->onSkipToQueueItem(J)V
    return-void

    :vivo_v3s_original_play_from_media_id
'''

id_s = inject_after_registers(
    id_s,
    "public final onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V",
    min_locals=3,
    param_regs=3,
    injection=selection_inject,
)
id_path.write_text(id_s, encoding="utf-8")

assert MEDIA_ID_PREFIX in id_s
assert "Long;->parseLong(Ljava/lang/String;)J" in id_s
assert "Lid;->onSkipToQueueItem(J)V" in id_s

# Critical regression guard: selection-only candidate must not contain the
# rejected V3/V3R1 metadata capability injection anywhere in decoded smali.
for p in ROOT.glob("smali*/*.smali"):
    pass
hits=[]
for p in ROOT.glob("smali*/**/*.smali"):
    try:
        if FORBIDDEN_TIME_KEY in p.read_text(encoding="utf-8"):
            hits.append(str(p))
    except Exception:
        pass
if hits:
    raise SystemExit(f"forbidden rejected timing key present in V3S: {hits}")

print(f"V3S selection-only patched callback: {id_path}")
print("V3S keeps proven V2 bridge and does not mutate MediaMetadata")
