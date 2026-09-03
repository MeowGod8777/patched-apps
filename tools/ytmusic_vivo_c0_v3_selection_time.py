#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")

ID_PREFIX = "vivo_qid_"
SUPPORT_KEY = "vivomusicmix.media.metadata.support_event"
SEEK_POSITION_BIT = 0x10

# v3 is intentionally an overlay on top of the already device-validated v2 patch.
browser_paths = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
ii_paths = list(ROOT.glob("smali*/ii.smali"))
id_paths = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]

if len(browser_paths) != 1:
    raise SystemExit(f"expected exactly one MusicBrowserService, got {browser_paths}")
if len(ii_paths) != 1:
    raise SystemExit(f"expected exactly one ii.smali, got {ii_paths}")
if len(id_paths) != 1:
    raise SystemExit(f"expected exactly one MediaSession callback id.smali, got {id_paths}")

browser_path = browser_paths[0]
ii_path = ii_paths[0]
id_path = id_paths[0]

browser = browser_path.read_text(encoding="utf-8")
ii = ii_path.read_text(encoding="utf-8")
id_src = id_path.read_text(encoding="utf-8")

# Freeze v2 invariants before adding v3 behavior.
for marker in (
    "VIVO_MUSIC_MIX_ROOT",
    "vivomusicmix_current_list",
    "vivo_qid_",
    "vivoQueue:Ljava/util/List;",
):
    if marker not in browser and marker not in ii:
        raise SystemExit(f"v2 prerequisite marker missing: {marker}")
if "MusicBrowserService;->vivoQueue:Ljava/util/List;" not in ii:
    raise SystemExit("v2 queue capture missing from ii.smali")
if SUPPORT_KEY in ii:
    raise SystemExit("v3 support-event marker already present before v3 patch")


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
            raise SystemExit(f"no .locals/.registers in {signature}")
        old = int(rm.group(1))
        need = min_locals + param_regs
        if old < need:
            replacement = re.sub(r'\.registers\s+\d+', f'.registers {need}', rm.group(0), count=1)
            method = method[:rm.start()] + replacement + method[rm.end():]
            rm = re.search(r'(?m)^\s*\.registers\s+(\d+)\s*$', method)
        insert_at = rm.end()

    method = method[:insert_at] + "\n\n" + injection.strip("\n") + "\n" + method[insert_at:]
    return src[:mm.start()] + method + src[mm.end():]


# Vivo c0 selects a browser item using playFromMediaId().  Our v2 IDs encode the
# exact MediaSession queueId.  For only those IDs, translate back into the exact
# existing YT Music queue-selection transport used by onSkipToQueueItem(): Lie.t(J).
selection_inject = r'''
    const-string v0, "vivo_qid_"
    invoke-virtual {p1, v0}, Ljava/lang/String;->startsWith(Ljava/lang/String;)Z
    move-result v0
    if-eqz v0, :vivo_v3_original_play_from_media_id

    const/16 v0, 0x9
    invoke-virtual {p1, v0}, Ljava/lang/String;->substring(I)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Ljava/lang/Long;->parseLong(Ljava/lang/String;)J
    move-result-wide v1

    invoke-direct {p0}, Lid;->a()Lii;
    move-result-object v0
    if-eqz v0, :vivo_v3_selection_return

    invoke-static {v0}, Lid;->c(Lig;)V
    iget-object v4, p0, Lid;->a:Lie;
    invoke-virtual {v4, v1, v2}, Lie;->t(J)V
    invoke-static {v0}, Lid;->b(Lig;)V

    :vivo_v3_selection_return
    return-void

    :vivo_v3_original_play_from_media_id
'''

# Official Luna publishes Vivo's SEEK_POSITION capability bit (0x10) through
# vivomusicmix.media.metadata.support_event.  Standard duration/position already
# exists in YT Music; preserve any existing bits and OR only this exact capability.
time_inject = r'''
    if-eqz p1, :vivo_v3_time_original
    iget-object v0, p1, Landroid/support/v4/media/MediaMetadataCompat;->b:Landroid/os/Bundle;
    if-eqz v0, :vivo_v3_time_original
    const-string v1, "vivomusicmix.media.metadata.support_event"
    invoke-virtual {v0, v1}, Landroid/os/Bundle;->getLong(Ljava/lang/String;)J
    move-result-wide v2
    const-wide/16 v4, 0x10
    or-long/2addr v2, v4
    invoke-virtual {v0, v1, v2, v3}, Landroid/os/Bundle;->putLong(Ljava/lang/String;J)V

    :vivo_v3_time_original
'''

id_src = inject_after_registers(
    id_src,
    "public final onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V",
    min_locals=5,
    param_regs=3,
    injection=selection_inject,
)

ii = inject_after_registers(
    ii,
    "public final m(Landroid/support/v4/media/MediaMetadataCompat;)V",
    min_locals=6,
    param_regs=2,
    injection=time_inject,
)

id_path.write_text(id_src, encoding="utf-8")
ii_path.write_text(ii, encoding="utf-8")

# Static postconditions.
assert ID_PREFIX in id_src
assert "Ljava/lang/Long;->parseLong(Ljava/lang/String;)J" in id_src
assert "Lie;->t(J)V" in id_src
assert SUPPORT_KEY in ii
assert "const-wide/16 v4, 0x10" in ii
assert "or-long/2addr v2, v4" in ii
assert "android.media.metadata.DURATION" not in selection_inject

print(f"patched selection callback: {id_path}")
print(f"patched Vivo seek capability: {ii_path}")
print("v3 selection/time markers OK")
