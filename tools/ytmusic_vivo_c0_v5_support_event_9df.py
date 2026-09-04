#!/usr/bin/env python3
from pathlib import Path
import re, subprocess, sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else 'decoded')
if not ROOT.is_dir():
    raise SystemExit(f'missing decoded root: {ROOT}')

# Reproduce exact V5 selection-success architecture first.
v5 = Path(__file__).with_name('ytmusic_vivo_c0_playable_mediaid_v5.py')
subprocess.run([sys.executable, str(v5), str(ROOT)], check=True)

hits=[p for p in ROOT.glob('smali*/ii.smali') if '.method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V' in p.read_text(encoding='utf-8')]
if len(hits)!=1:
    raise SystemExit(f'unexpected ii.smali targets: {hits}')
p=hits[0]
s=p.read_text(encoding='utf-8')
key='vivomusicmix.media.metadata.support_event'
if key in s:
    raise SystemExit('support_event already present before V5+9DF patch')

m=re.search(r'(?ms)^\.method public final m\(Landroid/support/v4/media/MediaMetadataCompat;\)V\n.*?^\.end method',s)
if not m:
    raise SystemExit('ii.m missing')
body=m.group(0)
needle='    invoke-virtual {v0}, Landroid/media/MediaMetadata$Builder;->build()Landroid/media/MediaMetadata;'
if body.count(needle)!=1:
    raise SystemExit(f'framework MediaMetadata.Builder.build count={body.count(needle)}')

inject='''    const-string v3, "vivomusicmix.media.metadata.support_event"\n\n    const-wide/16 v4, 0x9df\n\n    invoke-virtual {v0, v3, v4, v5}, Landroid/media/MediaMetadata$Builder;->putLong(Ljava/lang/String;J)Landroid/media/MediaMetadata$Builder;\n\n'''
body2=body.replace(needle, inject+needle, 1)
s=s[:m.start()]+body2+s[m.end():]
p.write_text(s,encoding='utf-8')

# Hard guards: V5 selection stays intact, rejected queue endpoints stay absent.
kyi=[q for q in ROOT.glob('smali*/kyi.smali') if '.method public final j()V' in q.read_text(encoding='utf-8')]
if len(kyi)!=1:
    raise SystemExit('kyi.j target missing')
j=re.search(r'(?ms)^\.method public final j\(\)V\n.*?^\.end method',kyi[0].read_text(encoding='utf-8')).group(0)
assert j.count('Lnoq;->n()Lazmi;')==1
assert j.count('Lazmi;->b:Lboht;')==1
assert 'Lnoq;->o()Lboht;' not in j
assert 'Lnoq;->p()Lboht;' not in j

id_hits=[q for q in ROOT.glob('smali*/id.smali') if 'onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V' in q.read_text(encoding='utf-8')]
assert len(id_hits)==1
idt=id_hits[0].read_text(encoding='utf-8')
assert 'Long;->parseLong(Ljava/lang/String;)J' not in idt
assert 'vivo_qid_' not in idt

assert s.count(key)==1
assert 'const-wide/16 v4, 0x9df' in body2
print('PASS: exact V5 + Vivo support_event=0x9DF only')
