#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "decoded")
if not ROOT.is_dir():
    raise SystemExit(f"missing decoded root: {ROOT}")

# Start from the already-validated observation-only V4N trace probe.
base_probe = Path(__file__).with_name("ytmusic_vivo_c0_v4n_trace_probe.py")
if not base_probe.is_file():
    raise SystemExit(f"missing trace probe patcher: {base_probe}")
subprocess.run([sys.executable, str(base_probe), str(ROOT)], check=True)

helper_hits = list(ROOT.glob("smali*/com/google/android/apps/youtube/music/mediabrowser/VivoC0Trace.smali"))
lag_hits = [p for p in ROOT.glob("smali*/lag.smali") if ".method public final g(Ljava/lang/String;Landroid/os/Bundle;)V" in p.read_text(encoding="utf-8") and ".method public final x(Llkq;Ljava/lang/String;Lbupb;)V" in p.read_text(encoding="utf-8")]
if len(helper_hits) != 1 or len(lag_hits) != 1:
    raise SystemExit(f"unexpected helper/lag counts helper={helper_hits} lag={lag_hits}")
HELPER, LAG = helper_hits[0], lag_hits[0]

extra_helper = r'''

.method public static result(Ljava/lang/String;Lbupb;Llkq;)V
    .locals 3
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "RESULT action="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, " error="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    iget-boolean v1, p1, Lbupb;->c:Z
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    const-string v1, " code="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    iget v1, p1, Lbupb;->d:I
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, " appPkg="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    iget-object v1, p2, Llkq;->b:Lavgi;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    const-string v1, " source="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    iget-object v1, p2, Llkq;->d:Laves;
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method

.method public static bundleFacts(Landroid/os/Bundle;)V
    .locals 3
    if-nez p0, :bundle_nonnull
    const-string v0, "BUNDLE null"
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void

    :bundle_nonnull
    new-instance v0, Ljava/lang/StringBuilder;
    invoke-direct {v0}, Ljava/lang/StringBuilder;-><init>()V
    const-string v1, "BUNDLE skip="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "skip_entitlement_check"
    const/4 v2, 0x0
    invoke-virtual {p0, v1, v2}, Landroid/os/Bundle;->getBoolean(Ljava/lang/String;Z)Z
    move-result v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    const-string v1, " paused="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "EXTRA_START_PAUSED"
    const/4 v2, 0x0
    invoke-virtual {p0, v1, v2}, Landroid/os/Bundle;->getBoolean(Ljava/lang/String;Z)Z
    move-result v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Z)Ljava/lang/StringBuilder;
    const-string v1, " legacy="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "android.media.session.extra.LEGACY_STREAM_TYPE"
    const/4 v2, 0x0
    invoke-virtual {p0, v1, v2}, Landroid/os/Bundle;->getInt(Ljava/lang/String;I)I
    move-result v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v1, " vivoList="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "vivomusicmix_key_list"
    invoke-virtual {p0, v1}, Landroid/os/Bundle;->getString(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, " callerOverride="
    invoke-virtual {v0, v1}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-string v1, "com.google.android.apps.youtube.music.mediabrowser.caller_package_name"
    invoke-virtual {p0, v1}, Landroid/os/Bundle;->getString(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v0, v2}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v0}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->log(Ljava/lang/String;)V
    return-void
.end method
'''
helper = HELPER.read_text(encoding="utf-8")
if "->result(Ljava/lang/String;Lbupb;Llkq;)V" in helper or ".method public static result(" in helper:
    raise SystemExit("result helper already present")
HELPER.write_text(helper.rstrip() + extra_helper + "\n", encoding="utf-8")


def method_block(src: str, signature: str):
    pat = re.compile(r'(?ms)^\.method ' + re.escape(signature) + r'\n.*?^\.end method')
    m = pat.search(src)
    if not m:
        raise SystemExit(f"method not found: {signature}")
    return m, m.group(0)


def inject_entry(method: str, call: str) -> str:
    reg = re.search(r'(?m)^\s*\.(?:locals|registers)\s+\d+\s*$', method)
    if not reg:
        raise SystemExit("method register directive missing")
    return method[:reg.end()] + "\n\n" + call + "\n" + method[reg.end():]


def inject_after_result(method: str, needle: str, expected_result: str, call: str, max_scan: int = 30) -> str:
    lines = method.splitlines()
    hits = [i for i, line in enumerate(lines) if needle in line and line.lstrip().startswith("invoke-")]
    if len(hits) != 1:
        raise SystemExit(f"call count for {needle}: {len(hits)}")
    i = hits[0]
    for j in range(i + 1, min(len(lines), i + 1 + max_scan)):
        stripped = lines[j].strip()
        if stripped == expected_result:
            lines.insert(j + 1, call)
            return "\n".join(lines)
        if not stripped or stripped.startswith((".", ":", "#")):
            continue
        raise SystemExit(f"unexpected executable before {expected_result}: {stripped}")
    raise SystemExit(f"{expected_result} not found after {needle}")

lag = LAG.read_text(encoding="utf-8")

# Log the final asynchronous playback result at the existing stock result handler.
xm, x = method_block(lag, "public final x(Llkq;Ljava/lang/String;Lbupb;)V")
x2 = inject_entry(
    x,
    "    invoke-static {p2, p3, p1}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->result(Ljava/lang/String;Lbupb;Llkq;)V",
)
if x2.count("VivoC0Trace;->result") != 1:
    raise SystemExit("result trace insertion count wrong")
lag = lag[:xm.start()] + x2 + lag[xm.end():]

# Log only the normalized Bundle actually handed to Llbg.o/Llbg.i.
gm, g = method_block(lag, "public final g(Ljava/lang/String;Landroid/os/Bundle;)V")
g2 = inject_after_result(
    g,
    "Llai;->b(Laves;Landroid/os/Bundle;)Landroid/os/Bundle;",
    "move-result-object p2",
    "    invoke-static {p2}, Lcom/google/android/apps/youtube/music/mediabrowser/VivoC0Trace;->bundleFacts(Landroid/os/Bundle;)V",
)
if g2.count("VivoC0Trace;->bundleFacts") != 1:
    raise SystemExit("bundleFacts trace insertion count wrong")
lag = lag[:gm.start()] + g2 + lag[gm.end():]
LAG.write_text(lag, encoding="utf-8")

final_helper = HELPER.read_text(encoding="utf-8")
final_lag = LAG.read_text(encoding="utf-8")
for marker in (".method public static result(Ljava/lang/String;Lbupb;Llkq;)V", ".method public static bundleFacts(Landroid/os/Bundle;)V"):
    if final_helper.count(marker) != 1:
        raise SystemExit(f"helper marker count wrong: {marker}")
for marker in ("VivoC0Trace;->result", "VivoC0Trace;->bundleFacts"):
    if final_lag.count(marker) != 1:
        raise SystemExit(f"lag marker count wrong: {marker}")

print("Applied V4N result-code observation probe")
