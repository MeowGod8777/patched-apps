#!/usr/bin/env python3
from pathlib import Path
import re, subprocess, sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else 'decoded')
if not ROOT.is_dir():
    raise SystemExit(f'missing decoded root: {ROOT}')

# Preserve the exact runtime-successful V5 selection and 0x9DF timing baseline.
base = Path(__file__).with_name('ytmusic_vivo_c0_v5_support_event_9df.py')
if not base.is_file():
    raise SystemExit(f'missing V5+9DF patcher: {base}')
subprocess.run([sys.executable, str(base), str(ROOT)], check=True)

browser_hits = list(ROOT.glob('smali*/com/google/android/apps/youtube/music/mediabrowser/MusicBrowserService.smali'))
ii_hits = [p for p in ROOT.glob('smali*/ii.smali') if '.method public final m(Landroid/support/v4/media/MediaMetadataCompat;)V' in p.read_text(encoding='utf-8') and '.method public final n(Landroid/support/v4/media/session/PlaybackStateCompat;)V' in p.read_text(encoding='utf-8')]
id_hits = [p for p in ROOT.glob('smali*/id.smali') if 'onPlayFromMediaId(Ljava/lang/String;Landroid/os/Bundle;)V' in p.read_text(encoding='utf-8')]
lag_hits = [p for p in ROOT.glob('smali*/lag.smali') if '.method public final g(Ljava/lang/String;Landroid/os/Bundle;)V' in p.read_text(encoding='utf-8')]
kyi_hits = [p for p in ROOT.glob('smali*/kyi.smali') if '.method public final j()V' in p.read_text(encoding='utf-8')]
if not (len(browser_hits) == len(ii_hits) == len(id_hits) == len(lag_hits) == len(kyi_hits) == 1):
    raise SystemExit(f'unexpected targets browser={browser_hits} ii={ii_hits} id={id_hits} lag={lag_hits} kyi={kyi_hits}')

BROWSER, II, ID, LAG, KYI = browser_hits[0], ii_hits[0], id_hits[0], lag_hits[0], kyi_hits[0]
HELPER = BROWSER.parent / 'VivoMediaIdentity.smali'
if HELPER.exists():
    raise SystemExit(f'identity helper already exists: {HELPER}')

helper = r'''.class public final Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;
.super Ljava/lang/Object;
.source "VivoMediaIdentity"

.field public static volatile currentMediaId:Ljava/lang/String;

.method private constructor <init>()V
    .locals 0
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public static onState(Landroid/support/v4/media/session/PlaybackStateCompat;)V
    .locals 4

    if-nez p0, :state_nonnull
    const/4 v0, 0x0
    sput-object v0, Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;->currentMediaId:Ljava/lang/String;
    return-void

    :state_nonnull
    iget-wide v0, p0, Landroid/support/v4/media/session/PlaybackStateCompat;->j:J
    const-wide/16 v2, 0x0
    cmp-long p0, v0, v2
    if-ltz p0, :clear

    sget-object v2, Lcom/google/android/apps/youtube/music/mediabrowser/MusicBrowserService;->vivoNativeIds:Ljava/util/concurrent/ConcurrentHashMap;
    if-eqz v2, :clear

    invoke-static {v0, v1}, Ljava/lang/Long;->valueOf(J)Ljava/lang/Long;
    move-result-object v3
    invoke-virtual {v2, v3}, Ljava/util/concurrent/ConcurrentHashMap;->get(Ljava/lang/Object;)Ljava/lang/Object;
    move-result-object v2
    instance-of v3, v2, Ljava/lang/String;
    if-eqz v3, :clear
    check-cast v2, Ljava/lang/String;
    invoke-virtual {v2}, Ljava/lang/String;->isEmpty()Z
    move-result v3
    if-nez v3, :clear
    sput-object v2, Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;->currentMediaId:Ljava/lang/String;
    return-void

    :clear
    const/4 v2, 0x0
    sput-object v2, Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;->currentMediaId:Ljava/lang/String;
    return-void
.end method

.method public static apply(Landroid/media/MediaMetadata$Builder;)V
    .locals 2
    if-eqz p0, :done
    sget-object v0, Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;->currentMediaId:Ljava/lang/String;
    if-eqz v0, :done
    invoke-virtual {v0}, Ljava/lang/String;->isEmpty()Z
    move-result v1
    if-nez v1, :done
    const-string v1, "android.media.metadata.MEDIA_ID"
    invoke-virtual {p0, v1, v0}, Landroid/media/MediaMetadata$Builder;->putString(Ljava/lang/String;Ljava/lang/String;)Landroid/media/MediaMetadata$Builder;
    :done
    return-void
.end method
'''
HELPER.write_text(helper, encoding='utf-8')


def method_block(src: str, signature: str):
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n.*?^\.end method')
    m = pat.search(src)
    if not m:
        raise SystemExit(f'method not found: {signature}')
    return m, m.group(0)


def inject_entry(method: str, call: str) -> str:
    reg = re.search(r'(?m)^\s*\.(?:locals|registers)\s+\d+\s*$', method)
    if not reg:
        raise SystemExit('register directive missing')
    return method[:reg.end()] + '\n\n' + call + '\n' + method[reg.end():]

# PlaybackState is observation-only: use the already-published active queue id to
# select the exact V5 native playable ID from the existing sidecar map. No state
# field is modified.
ii = II.read_text(encoding='utf-8')
nm, nbody = method_block(ii, 'public final n(Landroid/support/v4/media/session/PlaybackStateCompat;)V')
nbody2 = inject_entry(nbody, '    invoke-static {p1}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;->onState(Landroid/support/v4/media/session/PlaybackStateCompat;)V')
ii = ii[:nm.start()] + nbody2 + ii[nm.end():]

# The V5+9DF path has exactly one framework MediaMetadata.Builder.build() in
# Lii.m. Add only the official Luna identity field immediately before build.
mm, mbody = method_block(ii, 'public final m(Landroid/support/v4/media/MediaMetadataCompat;)V')
needle = '    invoke-virtual {v0}, Landroid/media/MediaMetadata$Builder;->build()Landroid/media/MediaMetadata;'
if mbody.count(needle) != 1:
    raise SystemExit(f'framework metadata build count={mbody.count(needle)}')
apply_call = '    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoMediaIdentity;->apply(Landroid/media/MediaMetadata$Builder;)V\n\n'
mbody2 = mbody.replace(needle, apply_call + needle, 1)
ii = ii[:mm.start()] + mbody2 + ii[mm.end():]
II.write_text(ii, encoding='utf-8')

# Hard regression guards.
id_text = ID.read_text(encoding='utf-8')
lag_text = LAG.read_text(encoding='utf-8')
kyi_text = KYI.read_text(encoding='utf-8')
jm = re.search(r'(?ms)^\.method public final j\(\)V\n.*?^\.end method', kyi_text)
if not jm:
    raise SystemExit('Lkyi.j missing')
j = jm.group(0)
if j.count('Lnoq;->n()Lazmi;') != 1 or j.count('Lazmi;->b:Lboht;') != 1:
    raise SystemExit('V5 playable endpoint mapping changed')
if 'Lnoq;->o()Lboht;' in j or 'Lnoq;->p()Lboht;' in j:
    raise SystemExit('rejected queue-management endpoint present')
if 'Long;->parseLong(Ljava/lang/String;)J' in id_text or 'vivo_qid_' in id_text or 'vivo_v3' in id_text:
    raise SystemExit('rejected Lid queueId selection hook present')
if 'VivoMediaIdentity' in lag_text:
    raise SystemExit('Llag must remain untouched by identity patch')

final_ii = II.read_text(encoding='utf-8')
if final_ii.count('VivoMediaIdentity;->onState') != 1:
    raise SystemExit('state identity insertion count wrong')
if final_ii.count('VivoMediaIdentity;->apply') != 1:
    raise SystemExit('metadata identity insertion count wrong')
if final_ii.count('vivomusicmix.media.metadata.support_event') != 1:
    raise SystemExit('0x9DF support_event baseline missing or duplicated')
if final_ii.count('android.media.metadata.MEDIA_ID') != 0:
    raise SystemExit('MEDIA_ID key must live only in helper, not duplicated in Lii')
helper_text = HELPER.read_text(encoding='utf-8')
if helper_text.count('android.media.metadata.MEDIA_ID') != 1:
    raise SystemExit('MEDIA_ID helper key count wrong')
if 'setPlaybackState' in helper_text or 'setMetadata' in helper_text:
    raise SystemExit('helper must not publish or mutate session state directly')

print(f'Vivo identity helper: {HELPER}')
print(f'Vivo identity sink:   {II}')
print('PASS: exact V5 + 0x9DF + active-qid/native-mediaId metadata identity only')
