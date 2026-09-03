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

# Probe-v1 invariant: this exact YT Music build contains the old compat classes
# themselves, but not MediaDescriptionCompat$Builder.  The v1 patch therefore
# keeps the native compat MediaItem family and only replaces the nonexistent
# Builder with MediaDescriptionCompat's public 8-argument constructor.
desc_paths = list(ROOT.glob("smali*/android/support/v4/media/MediaDescriptionCompat.smali"))
builder_paths = list(ROOT.glob("smali*/android/support/v4/media/MediaDescriptionCompat$Builder.smali"))
item_paths = list(ROOT.glob("smali*/android/support/v4/media/MediaBrowserCompat$MediaItem.smali"))
if len(desc_paths) != 1:
    raise SystemExit(f"expected exactly one MediaDescriptionCompat class, got: {desc_paths}")
if builder_paths:
    raise SystemExit(f"unexpected MediaDescriptionCompat$Builder present: {builder_paths}")
if len(item_paths) != 1:
    raise SystemExit(f"expected exactly one MediaBrowserCompat$MediaItem class, got: {item_paths}")

desc_smali = desc_paths[0].read_text(encoding="utf-8")
ctor_desc = ".method public constructor <init>(Ljava/lang/String;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Landroid/graphics/Bitmap;Landroid/net/Uri;Landroid/os/Bundle;Landroid/net/Uri;)V"
if ctor_desc not in desc_smali:
    raise SystemExit("expected public 8-arg MediaDescriptionCompat constructor not found")

item_smali = item_paths[0].read_text(encoding="utf-8")
item_ctor = ".method public constructor <init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V"
if item_ctor not in item_smali:
    raise SystemExit("expected MediaBrowserCompat$MediaItem constructor not found")

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
    move-object/from16 v1, p1
    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
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
    move-object/from16 v0, p1
    const-string v1, "vivomusicmix_current_list"
    invoke-virtual {v0, v1}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v0
    if-eqz v0, :vivo_probe_original_children

    new-instance v0, Ljava/util/ArrayList;
    invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V

    new-instance v1, Landroid/support/v4/media/MediaDescriptionCompat;
    const-string v2, "vivo_probe_1"
    const-string v3, "YT Music Vivo Bridge"
    const-string v4, "c0 cooperation probe"
    const/4 v5, 0x0
    const/4 v6, 0x0
    const/4 v7, 0x0
    const/4 v8, 0x0
    const/4 v9, 0x0
    invoke-direct/range {v1 .. v9}, Landroid/support/v4/media/MediaDescriptionCompat;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Landroid/graphics/Bitmap;Landroid/net/Uri;Landroid/os/Bundle;Landroid/net/Uri;)V

    new-instance v2, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;
    const/4 v3, 0x2
    invoke-direct {v2, v1, v3}, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;-><init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V

    invoke-virtual {v0, v2}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z
    move-object/from16 v4, p2
    invoke-virtual {v4, v0}, Lbzu;->c(Ljava/lang/Object;)V
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
    min_locals=10,
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
assert "MediaDescriptionCompat$Builder" not in s
assert "MediaDescriptionCompat;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Ljava/lang/CharSequence;Landroid/graphics/Bitmap;Landroid/net/Uri;Landroid/os/Bundle;Landroid/net/Uri;)V" in s

print(f"validated compat description: {desc_paths[0]}")
print(f"validated compat media item:  {item_paths[0]}")
print(f"patched manifest:              {manifest}")
print(f"patched smali:                 {p}")
print("probe v1 markers/type-family OK")
