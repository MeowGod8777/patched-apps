# iQOO 12 Pro / OriginOS 6 修補狀態

更新：2026-09-03 19:42 +08:00

這份文件是 `iQOO 12 Pro / V2329A / PD2329` 日用修補的目前 source of truth。詳細反編譯證據另見專項文件；本檔保留目前可執行結論、已反證方向與下一步。

## 裝置基線

```text
Device: iQOO 12 Pro / V2329A / PD2329
OS: Android 16 / OriginOS 6 中國版
Exact build: PD2329B_A_16.2.19.1.W10.V0101L17
Bootloader: locked
Persistent root: none
Shell 操作工具: Runner
```

**Runner 是此機的日常 shell 執行方式；不要再預設 `rish -c`。**

---

# 當前總結

non-root 日用修補已接近飽和。目前真正仍值得投入的主線只剩少數：

1. **patched YouTube Music / Vivo cooperation playlist**：richer OriginPlayer / 鎖屏 / media island 已成功；目前只剩 richer card 的「播放列表」不可用。根因已收斂到 `controller/o0` 與官方 Luna `controller/c0 + MediaBrowser cooperation service` 的差異，下一步是 cooperation service prototype。
2. **Instagram HDR**：Android / vivo HDR display path 已證明正常；真正缺口仍在 Instagram / Meta HDR request eligibility / device classification / rendition delivery gate。
3. **App-level polish**：LINE / Instagram / Threads 去廣告、入口精簡、通知雙卡、長標題截斷等。這些屬 App customization / cosmetic，不再視為 12 Pro 核心系統缺口。

**Temporary Root / Scene root mode / scheduler / thermal / 續航研究屬另一權限層級與另一研究專案，不計入本 non-root 修補完成度。**

---

## 已結案 / 已打通

- Google Quick Share：本修補主線已結案；LocalSend 作跨平台備援。
- Google Maps 移動路線軸：結案，不重跑已完成診斷。
- Origin Isle / SuperX：已打通。
- `com.autonavi.minimap` 導航島失敗根因已證明曾是 vivo 原子通知 policy `NAVIGATION=false`，不是 payload / template / signature。
- MiCTS / Google Circle to Search：已有可接受實機解法，暫停研究。

---

# OriginPlayer / 鎖屏播放器

## Exact VivoMusicWidgetMix baseline

```text
package: com.vivo.musicwidgetmix
versionCode: 6271
versionName: 6.2.7.1
minSdk: 34
targetSdk: 34
path: /system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk
```

詳細靜態分析：`IQOO12PRO_ORIGINPLAYER_6.2.7.1_RE.zh-TW.md`

已驗證 controller routing：

```text
custom-insert package -> controller/c0
framework-support package -> controller/o0
tv.danmaku.bili -> controller/g
otherwise -> controller/z2 generic
```

重要：**custom-insert 判定優先於 framework-support。**

單純寫：

```sh
settings put system musicwidget_list_pkg_type_key '...'
```

只能讓 generic package 被 OriginPlayer 納入，不能取得完整 cooperation controller。

`custom_insert_music_white_list` 不是普通 Settings 白名單；它由 Vivo runtime query 真實 `com.vivo.musicwidgetmix.support.service` service 建立，對應 `MediaBrowserCompat` cooperation path。

---

# YouTube framework-support identity A/B：SUCCESS

專項記錄：`IQOO12PRO_ORIGINPLAYER_YT_APPLEMUSIC_AB_2026-09-03.md`

```text
stock app: YouTube
version: 20.51.39
patched package: com.apple.android.music
anddea/revanced-patches: 4.2.0
Morphe Desktop: 1.14.0
SHA256: b4921cc76a8e6e36d956ef63231c7b0256071c1da072d54822ed0350d9f8a281
```

實機沒有手動加入 Origin Isle 或 `musicwidget_list_pkg_type_key`，只安裝、給權限、播放。

結果：

- PASS：OriginPlayer 自動識別。
- PASS：richer artwork / progress / prev / play-pause / next / music-style controls。
- PASS：鎖屏完整音樂播放器卡。
- PASS：OriginOS 上方 media island / expanded card 自動出現。
- OBSERVED：vivo richer media card + YouTube 自身 media notification 可能同時存在。
- OBSERVED：超長 YouTube 標題套 music template 時可能截字。

核心因果：

```text
YouTube MediaSession
  + framework-support / lock-cooperation package identity
  -> VivoMusicWidgetMix framework-support classification
  -> richer player path
  -> full OriginPlayer / lockscreen / media-island presentation
```

`com.apple.android.music` build 已可日用。Ghost 不再是 YouTube 的必要中介。

---

# Ghost Player

目前不安裝、不修、不列主線。

原因：

- 先前與 Wavelet 同時使用出現無聲問題；
- YouTube 已可直接利用 framework-support identity；
- Bilibili 有 dedicated controller path；
- YT Music 已可用 `com.luna.music` rich identity；
- Ghost 會增加額外 MediaSession / audio bridge 複雜度。

只有未來出現「無法重打包、OriginPlayer 又完全不支援，但確實需要 richer lockscreen」的播放器才重新考慮。

---

# patched YouTube Music / Luna identity

詳細最新 RE：`IQOO12PRO_YTMUSIC_LUNA_COOPERATION_RE_2026-09-03.md`

## Main Luna build

```text
stock package: com.google.android.apps.youtube.music
stock version: 9.15.51
arch: arm64-v8a
patched package: com.luna.music
GmsCore vendor: app.revanced
anddea/revanced-patches: 4.2.0
Morphe Desktop: 1.14.0
build run: 33729902415
artifact id: 9883451275
APK SHA256: 0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307
```

Build config：`ytmusic-originplayer-luna.toml`

Workflow：`.github/workflows/build-ytmusic-originplayer-luna.yml`

Package-scoped Morphe options 已正確寫入 `packageNameYouTubeMusic=com.luna.music`。先前單獨 `-O packageNameYouTubeMusic=...` 可能落回 `anddea.youtube.music`，不作有效證據。

## ReVanced / RVX preset

Anddea import/export 已確認 export 會刻意移除 outer `{}`；importer 會自行包 braces。最初 normal JSON `{...}` 導致 import parser 變成 `{{...}}` 而失敗。

修正 commit：

```text
f386dfa6e16a67b1e0e4d5e5401c08129987ec6c
Fix RVX Music import format by removing outer JSON braces
```

使用者已成功 import。Toast 只顯示 6 個，是因 preset 只覆寫 6 個 setting keys，不代表只有 6 個 patches。

覆寫內容：

```text
custom_playback_speeds
force_original_audio=false
hide_cast_button=false
ryd_compact_layout=true
ryd_dislike_percentage=true
sb_sponsor=ignore
```

YT Music SponsorBlock 沒有 YouTube 版 `manual-skip`，只有 `skip / skip-once / ignore`；為保留「不要自動跳 sponsor」偏好，使用 `ignore`。

## Runtime richer UI：PASS

使用者實機已確認：

- PASS：full richer OriginPlayer。
- PASS：home media island / expanded card。
- PASS：lockscreen / notification richer Vivo player。
- PASS：artwork / title / artist / progress。
- PASS：previous / play-pause / next。
- OBSERVED：standard YT Music media notification 可能與 Vivo richer card 同時存在，屬 cosmetic duplicate。
- FAIL：richer card 的「播放列表」按鈕顯示，但點擊完全無反應。

因此原先 `RUNTIME VALIDATION PENDING` 已撤銷；**rich integration 已實機 PASS，現在只剩 playlist cooperation 缺口。**

---

# YT Music playlist investigation

## MediaSession queue 已證明存在

Runner baseline：

```text
package=com.luna.music
active=true
flags=3
rating type=2
actions=2600887
queueTitle=即將播放
queue size=25
```

使用者確認 previous / next 正常。

因此不能再說 queue 沒發布：

```text
queue          ✅ 25 items
queue title    ✅ 即將播放
prev / next    ✅
playlist       ❌ inert
```

## ACTION_SKIP_TO_QUEUE_ITEM A/B：NEGATIVE

原 hypothesis：Vivo playlist 可能要求 `ACTION_SKIP_TO_QUEUE_ITEM = 0x1000`。

最終 aligned A/B：

```text
workflow run: 33734284316
artifact id: 9885107216
release: ytmusic-luna-queue-bit-ab-aligned-33734284316
APK SHA256: dc3b03ca6a91303e90fbbfd8607e4fa4771f3a3e304e14b10522ceaab0c1b2c8
signer SHA256: 7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c
```

初版 `eac6240b202c178dc689579f7c7500ddf5155506b2ddad7d783f62b0f7a9e8d9` 因 apktool rebuild 破壞 native `.so` ZIP alignment 而無法安裝，已退休。後續用 `zipalign -P 16` 修正，21 個 stored native libs 均 16K aligned。

Runtime：

```text
actions=2604983
queueTitle=即將播放
queue size=25
```

`2604983 = 2600887 + 4096`，證明 0x1000 patch 已在實機生效，但 playlist 仍完全無反應。

**結論：`queue + ACTION_SKIP_TO_QUEUE_ITEM` 不足以解鎖 Vivo playlist。Queue-bit hypothesis 已 falsified。不要再亂加其他 MediaSession action bits。**

---

# YT Music playlist root cause：controller tier 不同

目前 patched YT Music 只有 package identity：

```text
com.luna.music
  -> framework-support list
  -> controller/o0
```

進一步 exact `VivoMusicWidgetMix 6.2.7.1` RE 顯示，`o0` 可以提供 richer MediaSession controls，但**沒有 custom-insert cooperation 的 MediaBrowser playlist backend**。

官方 Luna 除了 package identity，還有 Vivo cooperation service。VivoMusicWidgetMix 會 query：

```text
Intent action:
com.vivo.musicwidgetmix.support.service
```

若同 package 有可 bind / exported service，runtime 會把它加入 custom-insert path，controller factory 由 `o0` 提升為：

```text
custom-insert -> controller/c0 / CooperateController
```

所以：

```text
official Luna
  com.luna.music
  + Vivo cooperation MediaBrowser service
  -> c0
  -> working playlist
```

目前 YT Music：

```text
patched YT Music
  com.luna.music
  - no Vivo cooperation service
  -> o0
  -> rich UI but inert playlist
```

---

# 已逆出的 Vivo cooperation playlist protocol

核心協議目前已收斂成標準 Android `MediaBrowserCompat`，尚未看到 privileged / platform-signature-only 的硬限制。

Vivo `c0` current-list browse：

```text
parentId = vivomusicmix_current_list
```

Paging option：

```text
vivomusicmix_key_media_page = <page>
```

Service 回傳：

```text
List<MediaBrowserCompat.MediaItem>
```

Vivo 至少讀 item 的：

```text
mediaId
title
artist
```

Paging metadata：

```text
vivomusicmix_key_has_more
vivomusicmix_key_media_page
```

使用者在 OriginPlayer playlist 點某首時，`c0` 呼叫：

```text
MediaControllerCompat.TransportControls.playFromMediaId(
    mediaId,
    Bundle {
        "vivomusicmix_key_list" = "vivomusicmix_current_list"
    }
)
```

官方 Luna 的 controller callback 會處理 `onPlayFromMediaId(mediaId, extras)`，把 playable ID 對應到 real queue 再切歌。

因此真正 transport 是：

```text
MediaBrowser current-list browse
  + MediaItem.mediaId
  + playFromMediaId(mediaId, vivo-list-extra)
```

不是 `skipToQueueItem()`。

Official Luna narrow RE workflows / artifacts：

```text
33749338695  Extract Luna Vivo protocol classes25
artifact 9890899253

33749573708  Extract Luna Vivo remote-control package
artifact 9890989720

33750258046  Locate Luna BasePlayerControllerService
artifact 9891242789

33750529313  Extract Luna PlayerService MediaBrowser implementation

33750642122  Fetch JADX 1.5.6 for exact local analysis
artifact 9891379337
```

---

# 下一顆 YT Music build：cooperation prototype

**產出 APK 前先更新 GitHub；GitHub 仍是 source of truth。**

下一顆不再做 action-bit 猜測。最小 prototype：

```text
YT Music 9.15.51
package = com.luna.music
existing ReVanced / Morphe patches unchanged
+
exported MediaBrowserService-compatible Vivo cooperation service
  action = com.vivo.musicwidgetmix.support.service
+
current-list browse bridge
  parentId = vivomusicmix_current_list
+
YT Music current queue -> MediaBrowserCompat.MediaItem list
+
playFromMediaId(mediaId, extras) -> 指定 queue item / playable ID
```

第一階段優先驗：

```text
Vivo 是否從 o0 切到 c0
playlist 按鈕是否由 inert 變成可開啟
是否能列出 current queue
```

若 browse 成功但點歌失敗，再單獨拆 `playFromMediaId` dispatch，不把兩個問題混在同一輪亂修。

目前未看到下列硬阻擋證據：

```text
signature-level permission
platform signature requirement
privileged UID requirement
system UID requirement
不可重現的 private Binder token
```

因此 cooperation prototype 值得直接做。

---

# Instagram HDR

仍屬真正功能缺口。

已知：

- YouTube HDR / Android / vivo HDR display path 正常；
- Instagram Reels 問題已定位到 Meta / Instagram HDR request eligibility / device classification / rendition delivery gate；
- 若繼續，應直接找可修改的 eligibility / request / rendition path，不重做 display capability 診斷。

---

# 已砍 / 低優先候選

- VLiveConvert / vivo 動態照片：需求低，先砍。
- Bitwarden / Keyguard FIDO patch：無實際痛點，砍。
- Salt Player Hi-Fi whitelist：目前主要藍牙使用情境無實質收益，砍。
- SmartShot + VivoAssistant：本地 AI / 系統耦合高、收益低，砍。
- EasyShare 開源版：已有 Quick Share / LocalSend，砍。
- FrameX / better_vivo / AppControl-X / akiHz / otweak：高風險 generic tweak，不推薦作日用修補主線。

---

## 目前優先序

1. YT Music `com.luna.music` Vivo cooperation MediaBrowser prototype。
2. YouTube `com.apple.android.music` 日用觀察；只修明確問題。
3. Instagram HDR eligibility / rendition gate。
4. LINE / IG / Threads 等 App patch，有明確痛點再維護。
5. notification duplicate / title truncation 等 cosmetic polish。
6. Ghost Player：不安裝、不修，只留備援概念。
7. MiCTS：已有可用方案，暫停研究。

## 操作原則

- GitHub repo 是本專案唯一 source of truth。
- **每次要產出新的候選 APK 前，先把已確認的新證據、A/B 結果、retired hypothesis 與下一步同步 GitHub。**
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A shell 執行工具。
- 新 patch 優先維持 single-variable / narrow hypothesis；避免一次改多層導致不可歸因。
- 對候選修補先看日用價值，不因公開存在方案就自動納入。
