from pathlib import Path
import re, sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'work')

# R20 scope (exact Instagram 439 / Piko base only):
# 1) Ensure the real clips/* API request path attaches the existing device_status JSON.
# 2) Force only the HDR-relevant values inside that request-side device_status map:
#      hw_av1_dec=true, 10bit_hw_av1_dec=true, is_hlg_supported=true.
# 3) Log the exact device_status JSON sent by the request and retain the RAW MPD logger.
# No UA / Build.* / X-IG-Capabilities / ODC static-attribute spoofing.

# ---------------------------------------------------------------------------
# classes15: LX/03u7.A04() — real API finalization, clips/* device_status gate.
# ---------------------------------------------------------------------------
p = root / 'smali15/X/03u7.smali'
lines = p.read_text().splitlines()
needle = '.method public final A04()LX/03ci;'
starts = [i for i,l in enumerate(lines) if l.strip() == needle]
assert len(starts) == 1, starts
s = starts[0]
e = next(i for i in range(s+1, len(lines)) if lines[i].startswith('.end method'))

# Force the DeviceStatusApiUtil infrastructure boolean on inside A04 only.
flag_hits = [i for i in range(s,e) if 'sget-boolean' in lines[i] and 'LX/02xX;->A00:Z' in lines[i]]
assert len(flag_hits) == 1, flag_hits
fi = flag_hits[0]
# Find the move target register from the sget.
m = re.match(r'\s*sget-boolean\s+([vp]\d+),\s+LX/02xX;->A00:Z', lines[fi])
assert m, lines[fi]
flag_reg = m.group(1)
lines.insert(fi+1, f'    const/4 {flag_reg}, 0x1    # R20: enable DeviceStatusApiUtil request decoration')
e += 1

# Find exact clips/ prefix block and bypass only its MobileConfig boolean.
clips = [i for i in range(s,e) if 'const-string v0, "clips/"' in lines[i]]
assert len(clips) == 1, clips
ci = clips[0]
mc = [i for i in range(ci, min(ci+80,e)) if 'const-wide v0, 0x81061e00031d79L' in lines[i]]
assert len(mc) == 1, mc
mi = mc[0]
# The clips prefix false path must still go to :cond_139; when prefix is true,
# replace the MC read/test sequence with an unconditional jump to the existing
# :cond_134 status-generation block.
# Start at invoke-static UserSession immediately preceding this exact MC.
bs = mi
while bs > ci and 'invoke-static {v5}, LX/02qP;->A01(LX/04BG;)LX/00AT;' not in lines[bs]:
    bs -= 1
assert bs > ci, (ci,mi)
be = mi
while be < min(mi+30,e) and 'if-eqz v0, :cond_139' not in lines[be]:
    be += 1
assert be < min(mi+30,e), (mi,be)
replacement = [
    '    # R20: clips/* always carries the existing device_status payload.',
    '    goto :cond_134',
]
lines[bs:be+1] = replacement
# recompute method end after length change
e = next(i for i in range(s+1, len(lines)) if lines[i].startswith('.end method'))

# Log the exact JSON that is written as request parameter device_status.
status_hits = [i for i in range(s,e) if 'const-string v0, "device_status"' in lines[i]]
assert len(status_hits) == 1, status_hits
si = status_hits[0]
# Expected value register is v1 immediately before AOA; assert exact writer nearby.
writer = next(i for i in range(si+1, min(si+8,e)) if 'LX/03u7;->AOA(Ljava/lang/String;Ljava/lang/String;)V' in lines[i])
assert '{v15, v0, v1}' in lines[writer], lines[writer]
log_inject = [
    '    const-string v0, "IG_HDR_R20_STATUS"',
    '    invoke-static {v0, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I',
    '    const-string v0, "device_status"',
]
# Replace existing const-string with log + restore key.
lines[si:si+1] = log_inject
p.write_text('\n'.join(lines) + '\n')
print('R20 patched clips device_status attachment + status logger')

# ---------------------------------------------------------------------------
# classes13: LX/07sY.A00(UserSession) — exact device_status capability map.
# ---------------------------------------------------------------------------
p = root / 'smali13/X/07sY.smali'
lines = p.read_text().splitlines()
needle_prefix = '.method public static final A00(LX/04BG;)LX/02tZ;'
starts = [i for i,l in enumerate(lines) if l.strip() == needle_prefix]
assert len(starts) == 1, starts
s = starts[0]
e = next(i for i in range(s+1,len(lines)) if lines[i].startswith('.end method'))

targets = ['hw_av1_dec', '10bit_hw_av1_dec', 'is_hlg_supported']
for key in targets:
    hits = [i for i in range(s,e) if f'"{key}"' in lines[i] and 'const-string' in lines[i]]
    assert len(hits) == 1, (key,hits)
    i = hits[0]
    # v1 is the map value in exact 439 A00. Require the immediate put pattern.
    put = next(j for j in range(i+1,min(i+8,e)) if 'LX/02tZ;->put(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;' in lines[j])
    assert '{v3, v0, v1}' in lines[put], (key, lines[put])
    force = [
        '    const/4 v1, 0x1',
        '    invoke-static {v1}, Ljava/lang/Boolean;->valueOf(Z)Ljava/lang/Boolean;',
        '    move-result-object v1',
    ]
    lines[i+1:i+1] = force
    e += len(force)
    print('R20 forced device_status', key, '= true')
p.write_text('\n'.join(lines) + '\n')

# ---------------------------------------------------------------------------
# classes13: RAW video_dash_manifest logger, same proven observer as R17.
# ---------------------------------------------------------------------------
p = root / 'smali13/com/instagram/feed/media/LiveTreeMediaDict.smali'
lines = p.read_text().splitlines()
needle = '.method public final A7q()Ljava/lang/String;'
starts = [i for i,l in enumerate(lines) if l.strip() == needle]
assert len(starts) == 1, starts
s = starts[0]
e = next(i for i in range(s+1,len(lines)) if lines[i].startswith('.end method'))
out=[]; count=0
for l in lines[s:e+1]:
    if l.strip() == 'return-object v0':
        ind=l[:len(l)-len(l.lstrip())]
        out.append(ind+'invoke-static {v0}, Lcom/instagram/feed/media/LiveTreeMediaDict;->hdrRawR20(Ljava/lang/String;)V')
        count += 1
    out.append(l)
assert count == 2, count
lines[s:e+1]=out
lines += [
    '',
    '.method private static hdrRawR20(Ljava/lang/String;)V',
    '    .registers 9',
    '    if-eqz p0, :done_raw',
    '    invoke-virtual {p0}, Ljava/lang/String;->length()I',
    '    move-result v0',
    '    invoke-virtual {p0}, Ljava/lang/String;->hashCode()I',
    '    move-result v6',
    '    const/4 v1, 0x0',
    ':raw_loop',
    '    if-ge v1, v0, :done_raw',
    '    add-int/lit16 v2, v1, 0xbb8',
    '    invoke-static {v2, v0}, Ljava/lang/Math;->min(II)I',
    '    move-result v2',
    '    invoke-virtual {p0, v1, v2}, Ljava/lang/String;->substring(II)Ljava/lang/String;',
    '    move-result-object v3',
    '    new-instance v4, Ljava/lang/StringBuilder;',
    '    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V',
    '    const-string v5, "hash="',
    '    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;',
    '    invoke-virtual {v4, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;',
    '    const-string v5, " off="',
    '    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;',
    '    invoke-virtual {v4, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;',
    '    const-string v5, " "',
    '    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;',
    '    invoke-virtual {v4, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;',
    '    invoke-virtual {v4}, Ljava/lang/Object;->toString()Ljava/lang/String;',
    '    move-result-object v3',
    '    const-string v4, "IG_HDR_R20_RAW"',
    '    invoke-static {v4, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I',
    '    move v1, v2',
    '    goto :raw_loop',
    ':done_raw',
    '    return-void',
    '.end method',
    ''
]
p.write_text('\n'.join(lines) + '\n')
print('R20 RAW manifest observer patched')
