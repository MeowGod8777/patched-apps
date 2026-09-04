#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

# Workflow-registration trigger; no functional delta.
ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Preserve the runtime-confirmed V5 playable queue selection first.
v5 = Path(__file__).with_name("ytmusic_vivo_c0_playable_mediaid_v5.py")
if not v5.is_file():
    raise SystemExit(f"missing V5 patcher: {v5}")
subprocess.run([sys.executable, str(v5), str(ROOT)], check=True)

# Add only the official Luna normal-track Vivo capability mask at the existing
# MediaMetadataCompat -> framework MediaMetadata publication boundary.
ii_hits = [p for p in ROOT.glob("smali*/ii.smali") if ".method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V" in p.read_text(encoding="utf-8")]
if len(ii_hits) != 1:
    raise SystemExit(f"expected one ii.m metadata sink, got {ii_hits}")
II = ii_hits[0]
s = II.read_text(encoding="utf-8")
key = "vivomusicmix.media.metadata.support_event"
if key in s:
    raise SystemExit("support_event already present before V6 injection")

mh = re.search(r'(?ms)^\.method public final m\(Landroid/support/v4/media/MediaMetadataCompat;\)V\n.*?^\.end method', s)
if not mh:
    raise SystemExit("ii.m(MediaMetadataCompat) not found")
body = mh.group(0)
needle = '    invoke-virtual {v0}, Landroid/media/MediaMetadata$Builder;->build()Landroid/media/MediaMetadata;'
if body.count(needle) != 1:
    raise SystemExit(f"expected one framework MediaMetadata.Builder.build in ii.m, got {body.count(needle)}")

inject = '''    const-string v3, "vivomusicmix.media.metadata.support_event"

    const-wide/16 v4, 0x9df

    invoke-virtual {v0, v3, v4, v5}, Landroid/media/MediaMetadata$Builder;->putLong(Ljava/lang/String;J)Landroid/media/MediaMetadata$Builder;

'''
body2 = body.replace(needle, inject + needle, 1)
s = s[:mh.start()] + body2 + s[mh.end():]
II.write_text(s, encoding="utf-8")

# Functional guards: V5 selection retained; no probes; exactly one capability
# write; standard title/artist/duration/PlaybackState values are not rewritten.
kyi_hits = [p for p in ROOT.glob("smali*/kyi.smali") if ".method public final j()V" in p.read_text(encoding="utf-8")]
id_hits = [p for p in ROOT.glob("smali*/id.smali") if "onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
lag_hits = [p for p in ROOT.glob("smali*/lag.smali") if ".method public final g(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8")]
if len(kyi_hits) != 1 or len(id_hits) != 1 or len(lag_hits) != 1:
    raise SystemExit("unexpected V5 target counts")
kyi = kyi_hits[0].read_text(encoding="utf-8")
id_text = id_hits[0].read_text(encoding="utf-8")
lag_text = lag_hits[0].read_text(encoding="utf-8")
assert kyi.count("Lnoq;->n()Lazmi;") == 1
assert kyi.count("Lazmi;->b:Lboht;") == 1
assert "Lnoq;->o()Lboht;" not in re.search(r'(?ms)^\.method public final j\(\)V\n.*?^\.end method', kyi).group(0)
assert "vivo_qid_" not in id_text
assert "Long;->parseLong(Ljava/lang/String;)J" not in id_text
assert "YTM_C0TRACE" not in lag_text and "YTM_V5STATE" not in lag_text

all_hits = []
for p in ROOT.glob("smali*/**/*.smali"):
    try:
        t = p.read_text(encoding="utf-8")
    except Exception:
        continue
    if key in t:
        all_hits.append(p)
    if "YTM_C0TRACE" in t or "VivoC0Trace;" in t or "YTM_V5STATE" in t or "VivoV5StateTrace;" in t:
        raise SystemExit(f"observation probe leaked into V6: {p}")
if all_hits != [II]:
    raise SystemExit(f"support_event appears outside ii.m owner: {all_hits}")

patched_ii = II.read_text(encoding="utf-8")
assert patched_ii.count(key) == 1
assert patched_ii.count('const-wide/16 v4, 0x9df') == 1
assert patched_ii.count('MediaMetadata$Builder;->putLong(Ljava/lang/String;J)') >= 1

print(f"V6 patched metadata sink: {II}")
print("PASS: V5 playable selection retained; official Luna support_event=0x9DF added as sole functional delta")
