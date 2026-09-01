from pathlib import Path
import re, sys

root=Path(sys.argv[1] if len(sys.argv)>1 else 'work')

# 1) Scoped Instagram network User-Agent identity spoof.
p=root/'smali2/X/02rk.smali'; lines=p.read_text().splitlines()
needle='.method public static final declared-synchronized A00()Ljava/lang/String;'
starts=[i for i,l in enumerate(lines) if l.strip()==needle]
assert len(starts)==1, starts
s=starts[0]; e=next(i for i in range(s+1,len(lines)) if lines[i].startswith('.end method'))
reg=next(i for i in range(s+1,min(s+15,e)) if lines[i].strip().startswith('.registers'))
m=re.match(r'\s*\.registers\s+(\d+)',lines[reg]); assert m
n=int(m.group(1)); assert n==2, lines[reg]
lines[reg]=re.sub(r'\.registers\s+2', '.registers 4', lines[reg])
call=[i for i in range(s,e) if 'LX/02xS;->A00(Landroid/content/Context;)Ljava/lang/String;' in lines[i]]
assert len(call)==1, call
mr=result=None
for j in range(call[0]+1,min(call[0]+8,e)):
    mm=re.match(r'\s*move-result-object\s+([vp]\d+)\s*$',lines[j])
    if mm: mr=j; result=mm.group(1); break
assert mr is not None
inject=['','    # R13v3 scoped Meta backend device-classification spoof.']
for old,new in [('vivo','samsung'),('V2329A','SM-S928B'),('PD2329B','e3q'),('PD2329','e3q')]:
    inject += [f'    const-string v2, "{old}"',f'    const-string v3, "{new}"',f'    invoke-virtual {{{result}, v2, v3}}, Ljava/lang/String;->replace(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Ljava/lang/String;',f'    move-result-object {result}']
lines[mr+1:mr+1]=inject
p.write_text('\n'.join(lines)+'\n')
print('UA spoof patched, result=',result)

# 2) ODC/static classifier HDR booleans.
p=root/'smali4/X/0Uiy.smali'; lines=p.read_text().splitlines()
for key in ['key_display_hdr_supported','key_video_decoder_hdr_supported']:
    hits=[i for i,l in enumerate(lines) if f'"{key}"' in l]; assert len(hits)==1,(key,hits)
    inv=next(j for j in range(hits[0]+1,min(hits[0]+12,len(lines))) if 'LX/00vy;->A0n(Ljava/lang/String;Ljava/lang/Boolean;)V' in lines[j])
    lines[inv:inv]=['    sget-object v1, Ljava/lang/Boolean;->TRUE:Ljava/lang/Boolean;']
p.write_text('\n'.join(lines)+'\n')
print('ODC HDR booleans patched')

# 3) Persisted decoder HDR capability.
p=root/'smali12/X/0hTo.smali'; lines=p.read_text().splitlines()
patched=[]
for key,required in [('video_decoder_hdr_supported',True),('video_av1_hardware_decoder_supported',False),('video_hevc_hardware_decoder_supported',False),('display_hdr_supported',False)]:
    hits=[i for i,l in enumerate(lines) if f'"{key}"' in l]
    if not hits:
        if required: raise RuntimeError('missing '+key)
        continue
    if len(hits)!=1:
        if required: raise RuntimeError(f'{key} hits={hits}')
        continue
    inv=None
    for j in range(hits[0]+1,min(hits[0]+16,len(lines))):
        if 'SharedPreferences$Editor;->putBoolean(Ljava/lang/String;Z)' in lines[j]: inv=j; break
    if inv is None:
        if required: raise RuntimeError('no putBoolean '+key)
        continue
    mm=re.search(r'invoke-interface(?:/range)?\s+\{([^}]*)\}',lines[inv]); assert mm
    regs=[x.strip() for x in mm.group(1).split(',')]
    value=regs[-1]
    lines[inv:inv]=[f'    const/4 {value}, 0x1']
    patched.append(key)
p.write_text('\n'.join(lines)+'\n')
print('persisted:',patched)

# 4) One proven RAW video_dash_manifest observer.
p=root/'smali13/com/instagram/feed/media/LiveTreeMediaDict.smali'; lines=p.read_text().splitlines()
needle='.method public final A7q()Ljava/lang/String;'
starts=[i for i,l in enumerate(lines) if l.strip()==needle]; assert len(starts)==1
s=starts[0]; e=next(i for i in range(s+1,len(lines)) if lines[i].startswith('.end method'))
out=[]; count=0
for l in lines[s:e+1]:
    if l.strip()=='return-object v0':
        ind=l[:len(l)-len(l.lstrip())]; out.append(ind+'invoke-static {v0}, Lcom/instagram/feed/media/LiveTreeMediaDict;->hdrRawR13(Ljava/lang/String;)V'); count+=1
    out.append(l)
assert count==2,count
lines[s:e+1]=out
lines += ['', '.method private static hdrRawR13(Ljava/lang/String;)V','    .registers 9','    if-eqz p0, :done_raw','    invoke-virtual {p0}, Ljava/lang/String;->length()I','    move-result v0','    invoke-virtual {p0}, Ljava/lang/String;->hashCode()I','    move-result v6','    const/4 v1, 0x0',':raw_loop','    if-ge v1, v0, :done_raw','    add-int/lit16 v2, v1, 0xbb8','    invoke-static {v2, v0}, Ljava/lang/Math;->min(II)I','    move-result v2','    invoke-virtual {p0, v1, v2}, Ljava/lang/String;->substring(II)Ljava/lang/String;','    move-result-object v3','    new-instance v4, Ljava/lang/StringBuilder;','    invoke-direct {v4}, Ljava/lang/StringBuilder;-><init>()V','    const-string v5, "hash="','    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;','    invoke-virtual {v4, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;','    const-string v5, " off="','    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;','    invoke-virtual {v4, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;','    const-string v5, " "','    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;','    invoke-virtual {v4, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;','    invoke-virtual {v4}, Ljava/lang/Object;->toString()Ljava/lang/String;','    move-result-object v3','    const-string v4, "IG_HDR_R13_RAW"','    invoke-static {v4, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I','    move v1, v2','    goto :raw_loop',':done_raw','    return-void','.end method','']
p.write_text('\n'.join(lines)+'\n')
print('RAW observer patched')
