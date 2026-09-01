from pathlib import Path
import re, sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else 'work')

# R17 scope:
#   1) Spoof ONLY Instagram's network User-Agent device identity at LX/02rk.A00().
#   2) Retain a RAW video_dash_manifest logger so one APK both attempts the fix and proves delivery.
# No ODC/static-attribute/codec-pref forcing is performed here.

# 1) Scoped Instagram network User-Agent identity spoof.
p = root / 'smali2/X/02rk.smali'
lines = p.read_text().splitlines()
needle = '.method public static final declared-synchronized A00()Ljava/lang/String;'
starts = [i for i, l in enumerate(lines) if l.strip() == needle]
assert len(starts) == 1, starts
s = starts[0]
e = next(i for i in range(s + 1, len(lines)) if lines[i].startswith('.end method'))
reg = next(i for i in range(s + 1, min(s + 15, e)) if lines[i].strip().startswith('.registers'))
m = re.match(r'\s*\.registers\s+(\d+)', lines[reg])
assert m, lines[reg]
assert int(m.group(1)) == 2, lines[reg]
lines[reg] = re.sub(r'\.registers\s+2', '.registers 4', lines[reg])

calls = [i for i in range(s, e) if 'LX/02xS;->A00(Landroid/content/Context;)Ljava/lang/String;' in lines[i]]
assert len(calls) == 1, calls
mr = None
result = None
for j in range(calls[0] + 1, min(calls[0] + 8, e)):
    mm = re.match(r'\s*move-result-object\s+([vp]\d+)\s*$', lines[j])
    if mm:
        mr = j
        result = mm.group(1)
        break
assert mr is not None and result is not None

inject = [
    '',
    '    # R17 scoped Meta backend request-classification spoof.',
    '    # Modify the Instagram network UA string only; Android Build.* remains untouched.'
]
for old, new in [
    ('vivo', 'samsung'),
    ('V2329A', 'SM-S928B'),
    ('PD2329B', 'e3q'),
    ('PD2329', 'e3q'),
]:
    inject += [
        f'    const-string v2, "{old}"',
        f'    const-string v3, "{new}"',
        f'    invoke-virtual {{{result}, v2, v3}}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;',
        f'    move-result-object {result}',
    ]
lines[mr + 1:mr + 1] = inject
p.write_text('\n'.join(lines) + '\n')
print('R17 UA spoof patched, result register =', result)

# 2) Proven RAW video_dash_manifest observer, renamed for R17.
p = root / 'smali13/com/instagram/feed/media/LiveTreeMediaDict.smali'
lines = p.read_text().splitlines()
needle = '.method public final A7q()Ljava/lang/String;'
starts = [i for i, l in enumerate(lines) if l.strip() == needle]
assert len(starts) == 1, starts
s = starts[0]
e = next(i for i in range(s + 1, len(lines)) if lines[i].startswith('.end method'))
out = []
count = 0
for l in lines[s:e + 1]:
    if l.strip() == 'return-object v0':
        ind = l[:len(l) - len(l.lstrip())]
        out.append(ind + 'invoke-static {v0}, Lcom/instagram/feed/media/LiveTreeMediaDict;->hdrRawR17(Ljava/lang/String;)V')
        count += 1
    out.append(l)
assert count == 2, count
lines[s:e + 1] = out

lines += [
    '',
    '.method private static hdrRawR17(Ljava/lang/String;)V',
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
    '    const-string v4, "IG_HDR_R17_RAW"',
    '    invoke-static {v4, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I',
    '    move v1, v2',
    '    goto :raw_loop',
    ':done_raw',
    '    return-void',
    '.end method',
    ''
]
p.write_text('\n'.join(lines) + '\n')
print('R17 RAW manifest observer patched')
