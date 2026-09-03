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
PROBE_ID = "vivo_probe_1"

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

paths = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali"))
if len(paths) != 1:
    raise SystemExit(f"expected exactly one MusicBrowserService.smali, got: {paths}")
p = paths[0]
s = p.read_text(encoding="utf-8")
if VIVO_ROOT in s or PROBE_ID in s:
    raise SystemExit("probe markers already present before patch")


def inject_after_registers(src: str, signature: str, min_locals: int, param_regs: int, injection: str) -> str:
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n(.*?)^\.end method')
    mm = pat.search(src)
    if not mm:
        methods = "\n".join(
            line for line in src.splitlines()
            if line.startswith(".method") and (" f(" in line or " b(" in line)
        )
        raise SystemExit(f"method not found: {signature}\nnearby candidates:\n{methods}")
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


root_inject = r'''
    const-string v0, "com.vivo.musicwidgetmix"
    invoke-virtual {v0, p1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :vivo_probe_original_root

    new-instance v0, Lbze;
    const-string v1, "VIVO_MUSIC_MIX_ROOT"
    const/4 v2, 0x0
    invoke-direct {v0, v1, v2}, Lbze;-><init>(Ljava/lang/String;Landroid/os/Bundle;)V
    return-object v0

    :vivo_probe_original_root
'''

children_inject = r'''
    const-string v0, "vivomusicmix_current_list"
    invoke-virtual {p1, v0}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v0
    if-eqz v0, :vivo_probe_original_children

    new-instance v0, Ljava/util/ArrayList;
    invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V

    new-instance v1, Landroid/support/v4/media/MediaDescriptionCompat$Builder;
    invoke-direct {v1}, Landroid/support/v4/media/MediaDescriptionCompat$Builder;-><init>()V

    const-string v2, "vivo_probe_1"
    invoke-virtual {v1, v2}, Landroid/support/v4/media/MediaDescriptionCompat$Builder;->setMediaId(Ljava/lang/String;)Landroid/support/v4/media/MediaDescriptionCompat$Builder;

    const-string v2, "YT Music Vivo Bridge"
    invoke-virtual {v1, v2}, Landroid/support/v4/media/MediaDescriptionCompat$Builder;->setTitle(Ljava/lang/CharSequence;)Landroid/support/v4/media/MediaDescriptionCompat$Builder;

    const-string v2, "c0 cooperation probe"
    invoke-virtual {v1, v2}, Landroid/support/v4/media/MediaDescriptionCompat$Builder;->setSubtitle(Ljava/lang/CharSequence;)Landroid/support/v4/media/MediaDescriptionCompat$Builder;

    invoke-virtual {v1}, Landroid/support/v4/media/MediaDescriptionCompat$Builder;->build()Landroid/support/v4/media/MediaDescriptionCompat;
    move-result-object v2

    new-instance v3, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;
    const/4 v4, 0x2
    invoke-direct {v3, v2, v4}, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;-><init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V

    invoke-virtual {v0, v3}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z
    invoke-virtual {p2, v0}, Lbzu;->c(Ljava/lang/Object;)V
    return-void

    :vivo_probe_original_children
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
    min_locals=5,
    param_regs=4,
    injection=children_inject,
)
p.write_text(s, encoding="utf-8")

manifest_after = manifest.read_text(encoding="utf-8")
assert ACTION in manifest_after
assert SERVICE in manifest_after
assert VIVO_CLIENT in s
assert VIVO_ROOT in s
assert VIVO_LIST in s
assert PROBE_ID in s

print(f"patched manifest: {manifest}")
print(f"patched smali:    {p}")
print("probe markers OK")
