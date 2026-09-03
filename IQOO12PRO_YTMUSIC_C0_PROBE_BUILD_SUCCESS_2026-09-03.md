# iQOO 12 Pro / YT Music c0 browser probe v0 — validated build checkpoint

更新：2026-09-03

唯一產品目標仍是修復 iQOO 12 Pro / OriginOS 6 上 patched YouTube Music 的 OriginPlayer「播放列表」按鈕顯示但點擊無反應。`c0 / MediaBrowser cooperation bridge` 是目前已定位的實作手段，不是產品目標本身。

本 checkpoint 承接：

- `IQOO12PRO_YTMUSIC_LUNA_COOPERATION_RE_2026-09-03.md`
- `IQOO12PRO_YTMUSIC_EXISTING_MEDIABROWSER_BRIDGE_PLAN_2026-09-03.md`
- `IQOO12PRO_YTMUSIC_C0_PROBE_REGISTER_FIX_2026-09-03.md`
- previous failure checkpoint `6a9ea40bc77f88f5a31ab75341ac29919a94f75c`

## Source / build identity

Patcher source commit：

```text
b913005d77b57df7f7273c4188f9f06aa69628f4
Stage high p-registers before c0 probe invokes
```

GitHub Actions：

```text
workflow: Build YT Music Luna Vivo c0 browser probe v0
workflow id: 349274710
run id: 33755186029
job id: 100647808303
result: SUCCESS
```

Artifact：

```text
artifact id: 9893179077
artifact name: ytmusic-luna-vivo-c0-browser-probe-v0
artifact ZIP digest: sha256:f3ad373d9b676c1b86952ba6971db7cb38e0f498b93888be15c217123605bfa1
```

Candidate APK：

```text
YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V0.apk
SHA256: 278b1bd3a745f4afec6c8851360e743a875187e44ca764ba331c77d3b6a0da89
package: com.luna.music
versionName: 9.15.51
versionCode: 91551240
```

## Previous v19 failure is resolved

Previous rebuild failure：

```text
MusicBrowserService.smali[768,4]
Invalid register: v19. Must be between v0 and v15, inclusive.
```

已依前一 checkpoint 的 exact plan 將 injected high `p1/p2` 先用 `move-object/from16` staging 到 low registers，再進 ordinary 35c `invoke-*`。

本 run 已跨過該 failure，Apktool rebuild 成功。因此此 blocker 可標記為：

```text
high p-register invoke encoding: RESOLVED
```

這不改變既有 protocol 判斷。

## Required validation chain

本候選已全部通過：

```text
patch injection                         PASS
Apktool rebuild                         PASS
zipalign -P 16                          PASS
stored arm64 native-library alignment  PASS
same signer as validated base           PASS
APK signature verification              PASS
package / version verification          PASS
manifest cooperation action             PASS
onGetRoot VIVO_MUSIC_MIX_ROOT marker    PASS
onLoadChildren vivo_probe_1 marker      PASS
artifact upload                          PASS
```

### 16K alignment

Final `zipalign` verification reported success。

21 個 stored `lib/arm64-v8a/*.so` 全部為 `(OK)`，沒有 non-OK native library entry。

### Signer

Validated base signer SHA256：

```text
7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c
```

Candidate signer SHA256：

```text
7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c
```

Match：PASS。

`apksigner verify --verbose --print-certs`：

```text
Verifies
v2 = true
v3 = true
Number of signers = 1
Signer DN = CN=Morphe
```

### Manifest static verification

Final manifest contains existing exported YT Music service：

```text
com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService
```

Its intent-filter contains both original MediaBrowser action and injected Vivo action：

```text
android.media.browse.MediaBrowserService
com.vivo.musicwidgetmix.support.service
```

### Smali static verification

Final rebuilt source context contains：

```text
VIVO_MUSIC_MIX_ROOT
vivomusicmix_current_list
vivo_probe_1
YT Music Vivo Bridge
c0 cooperation probe
```

Probe item remains playable (`flags = 2`) and returns through staged low-register result callback.

## Scope of this APK

This is **only c0 browser probe v0**. It intentionally does NOT implement：

```text
real YT Music current queue -> MediaItem list
playFromMediaId bridge
```

Do not interpret static/build success as proof that the end-user playlist bug is fixed yet.

## Next step — runtime only

Next action is user-side runtime validation on the exact iQOO 12 Pro / OriginOS 6 target.

Test：

```text
1. Install this same-signer candidate over the currently validated Luna YT Music base.
2. Start normal playback in YT Music.
3. Open OriginPlayer richer card.
4. Tap the playlist button.
5. Observe whether the playlist UI opens.
6. Check whether a probe row appears with:
   title = YT Music Vivo Bridge
   mediaId = vivo_probe_1
```

First-stage success criterion：

```text
playlist button becomes non-inert
and/or
Vivo UI displays the vivo_probe_1 probe item
```

If observed, that is runtime evidence that the chain has reached：

```text
support.service
-> runtime custom-insert classification
-> controller/c0
-> MediaBrowser bind
-> vivomusicmix_current_list browse
-> service MediaItem delivery
```

Only after that runtime evidence should the next candidate replace the static probe with YT Music real current + upcoming queue.

If the list opens and displays the probe but selecting it does nothing, that is expected for v0 because `playFromMediaId` is intentionally not implemented; item-selection transport remains a later isolated stage.

If the playlist remains completely inert, do not jump to real queue implementation. Collect runtime evidence for classification/bind/browse failure and keep the next iteration attributable.
