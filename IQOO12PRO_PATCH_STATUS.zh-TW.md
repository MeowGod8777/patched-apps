# iQOO 12 Pro / OriginOS 6 修補狀態

更新：2026-09-03

這份文件是 `iQOO 12 Pro / V2329A / PD2329` 日用修補的目前 source of truth。詳細反編譯證據另見專項文件；本檔只保留目前可執行結論與下一步。

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

# 當前總結：non-root 日用修補已接近飽和

以目前限制：

- locked bootloader；
- 無 persistent root；
- 日常以 Runner / user-space APK patch / system settings / vivo 公開與可觀察介面為主；
- 目標是提升中國版 OriginOS 6 的日用完整度，不是為修而修；

目前 12 Pro **可修、值得修、且對日用有明顯收益的 non-root 項目已經接近做完**。

主體缺口已從「大量 OriginOS / Google / media integration 問題」縮小到少數剩餘工作：

1. **patched YouTube Music**：已完成第一顆 `com.luna.music` non-root 候選 build，待實機驗證 OriginPlayer / 登入 / 日用行為。
2. **Instagram HDR**：仍是實質未解功能缺口；Android / vivo HDR display path 已證明正常，真正問題仍在 Instagram / Meta HDR request eligibility / device classification / rendition delivery gate。此路線難度高，且不保證純 non-root APK patch 可完全解決。
3. **少數 App-level polish**：LINE / Instagram / Threads 去廣告、入口精簡、通知雙卡、長標題截斷等；這類屬 App customization / cosmetic，不再視為 12 Pro 核心系統缺口。

**Temporary Root / Scene root mode / scheduler / thermal / 續航研究不算本條 non-root 修補的未完成項目。** 若 temp root 日後真正可用，會進入另一個權限層級與研究專案，不應拿來判定目前日用修補是否「還缺很多」。

---

## 已結案 / 已打通

- Google Quick Share：結案；LocalSend 作跨平台備援。
- Google Maps 移動路線軸：結案，不重跑已完成診斷。
- Origin Isle / SuperX：已打通。
- 已驗證 `com.autonavi.minimap` 導航島失敗根因曾是 vivo 原子通知 policy `NAVIGATION=false`，不是 payload / template / signature。
- MiCTS / Google Circle to Search：已找到可接受的實機解法，暫停研究。

---

# OriginPlayer / 鎖屏播放器

## Exact OriginPlayer baseline

```text
package: com.vivo.musicwidgetmix
versionCode: 6271
versionName: 6.2.7.1
minSdk: 34
targetSdk: 34
path: /system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk
```

詳細靜態分析：`IQOO12PRO_ORIGINPLAYER_6.2.7.1_RE.zh-TW.md`

已驗證 controller / classification 至少包含：

```text
custom-insert package -> controller/c0
framework-support package -> controller/o0
tv.danmaku.bili -> controller/g
otherwise -> controller/z2 generic
```

所以原本：

```text
Ghost / com.kugou.android.lite -> framework-support / richer path
Bilibili / tv.danmaku.bili     -> dedicated path
patched YouTube                -> generic path
```

單純寫：

```sh
settings put system musicwidget_list_pkg_type_key '...'
```

可以讓 generic package 被 OriginPlayer 納入，但**不足以取得完整合作播放器模板**。

`custom_insert_music_white_list` 也不是普通白名單；它對應真實 `com.vivo.musicwidgetmix.support.service` + `MediaBrowserCompat` cooperation 路徑，因此不採用 dummy service 粗暴繞過。

---

## YouTube framework-support identity A/B：SUCCESS

專項記錄：`IQOO12PRO_ORIGINPLAYER_YT_APPLEMUSIC_AB_2026-09-03.md`

測試 build：

```text
stock app: YouTube
version: 20.51.39
patched package identity: com.apple.android.music
patches: anddea/revanced-patches 4.2.0
CLI: Morphe Desktop 1.14.0
SHA256: b4921cc76a8e6e36d956ef63231c7b0256071c1da072d54822ed0350d9f8a281
```

實機條件：

- 沒有把 `com.apple.android.music` 手動加入 Origin Isle；
- 沒有把 `com.apple.android.music` 手動加入 `musicwidget_list_pkg_type_key`；
- 只安裝 APK、給一般所需權限並播放影片。

結果：

- **PASS：OriginPlayer 自動識別。**
- **PASS：完整 artwork / 進度 / 上一首 / 播放暫停 / 下一首 / 收藏等 richer music-player template。**
- **PASS：鎖屏為完整音樂播放器卡，不再是 generic YouTube 簡化卡。**
- **PASS：OriginOS 上方媒體島 / 展開卡自動出現，沒有另外加 Isle。**
- **PASS：未登入帳戶的首頁影片播放、基本控制與一般使用實測正常。**
- **PASS：使用者回報目前基本行為沒有發現異常。**
- **OBSERVED：通知中心可能同時出現 vivo richer media card + YouTube 自身 media notification。**
- **OBSERVED：超長 YouTube 標題套用音樂模板時可能截字。**

因此目前核心因果關係已由 exact APK 靜態分析 + 單變量 package-identity A/B + 實機 UI 一致支持：

```text
YouTube MediaSession
  + framework-support / lock-cooperation package identity
  -> VivoMusicWidgetMix richer player classification
  -> full OriginPlayer / lockscreen / media-island presentation
```

## YouTube 日用決策

`com.apple.android.music` build **已可直接日用**。

ReVanced 舊版設定匯入新版後存在 defaults / schema / host-version 差異，無法靠 sparse export 完整重建舊體驗；使用者已決定自行手動調整新版設定，不再把這件事當修補主線。

目前仍建議暫時保留舊 `app.revanced.android.youtube` 作 fallback，直到日用確認帳號登入、外部連結、背景播放 / PiP / Cast 等個人常用功能均正常。

若未來要裝真正 Apple Music，需改用另一個尚未占用的 framework-support + lock-cooperation identity。

---

## Ghost Player：目前不需要重裝

Ghost Player 現在**沒有安裝**。先前因與 Wavelet 同時使用時出現無聲問題而移除。

在 YouTube 已可直接以 framework-support identity 取得完整 OriginPlayer UI 後，Ghost 不再是 YouTube 的必要中介。

撇除 YouTube，目前也沒有強需求要求重裝 Ghost：

- Bilibili `tv.danmaku.bili` 在 exact OriginPlayer 內已有 dedicated cooperation path；
- YT Music 可直接使用另一個 framework-support identity；
- Ghost 仍會增加額外 MediaSession / audio-activity bridge，且與 Wavelet 已有實機衝突紀錄。

**目前結論：Ghost 保留為概念上的備援工具，但不安裝、不修、不列主線。**

只有未來出現「某個無法重打包、OriginPlayer 又完全不支援的播放器，而且確實需要 richer lockscreen」時才重新考慮 Ghost。

---

# patched YouTube Music / Luna identity

Bilibili 音樂整理 / 歌單搬運由使用者另外處理，**不與 12 Pro YT Music patch 綁成同一條工作**。

## Build candidate

已建立第一顆可實機驗證的 12 Pro non-root build：

```text
stock package: com.google.android.apps.youtube.music
stock version: 9.15.51
arch: arm64-v8a
patched identity: com.luna.music
GmsCore vendor: app.revanced
patches: anddea/revanced-patches 4.2.0
CLI: Morphe Desktop 1.14.0
build run: 33729902415
artifact id: 9883451275
APK SHA256: 0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307
```

Build config：`ytmusic-originplayer-luna.toml`

Workflow：`.github/workflows/build-ytmusic-originplayer-luna.yml`

使用 package-scoped Morphe options file 寫入 `packageNameYouTubeMusic=com.luna.music`；先前單純 `-O packageNameYouTubeMusic=...` 會落回 `anddea.youtube.music`，已確認不可作為 Luna build 的有效證據。

最終候選 APK 靜態驗證：

- Manifest string pool **存在 `com.luna.music`**；
- provider / permission identities 已可見 `com.luna.music.*`；
- GmsCore reference 為 `app.revanced.android.gms`；
- 不再使用 `anddea.youtube.music` 作 package identity。

本輪選入 / 可用功能包括：

- GmsCore support；
- Hide ads；
- Remove background playback restrictions；
- Force original audio；
- Return YouTube Dislike；
- SponsorBlock；
- Video playback / custom playback speeds；
- Bitrate default value（mobile / Wi-Fi 預設 Always High）；
- Sanitize sharing links；
- Third-party lyrics；
- 以及 Anddea 4.2.0 對 YT Music 9.15.51 的正常依賴 / default patches。

使用者 YouTube 習慣可對應者另外提供 preset：`ytmusic-12pro-settings-2026-09-03.json`。

注意：YT Music 版 SponsorBlock 的 category behavior **沒有 YouTube 版 `manual-skip`**，只有 `skip` / `skip-once` / `ignore`。為避免把使用者原本「不要自動跳 sponsor」的偏好改成自動跳，本 preset 對 `sb_sponsor` 使用 `ignore`。

目前仍為 **RUNTIME VALIDATION PENDING**。下一步實機只需驗：

1. 安裝 / GmsCore 登入；
2. 播放歌曲；
3. 是否在沒有 Runner whitelist / Isle 手動加入的情況下自動進入 richer OriginPlayer、鎖屏、媒體島；
4. 背景播放 / Cast / session 清理；
5. Wavelet 並用是否正常。

若上述通過，YT Music 可直接列為完成，non-root 日用修補主線基本可封箱。

---

# 仍有價值但不是目前必做的項目

## Instagram HDR

仍屬真正功能缺口，不是 cosmetic。

已知基線：

- YouTube HDR / Android / vivo HDR display path 正常；
- Instagram Reels 實際問題已定位到 Meta / Instagram HDR request eligibility / device classification / rendition delivery gate；
- 若繼續研究，應直接找可修改的 eligibility / request / rendition path，而不是重做 display capability 診斷。

此項仍值得研究，但難度與不確定性遠高於 OriginPlayer / package identity patch；完成 YT Music 後再決定是否回頭硬啃。

## App-level customization

LINE / Instagram / Threads 的去廣告、入口隱藏、外部連結、push 等仍可持續維護，但應視為**通用 App patching**，不再視為 iQOO 12 Pro / OriginOS 核心修補未完成。

## OriginPlayer cosmetic polish

- vivo richer card + YouTube 自身通知可能雙卡；
- 超長 YouTube 標題在 music template 可能截斷；
- 控制語意（收藏、playlist 等）不一定完全對應 YouTube video semantics。

只有實際日用覺得煩再修，不主動投入時間。

---

## 已砍候選

- VLiveConvert / vivo 動態照片：目前需求低，先砍。
- Bitwarden / Keyguard FIDO patch：無實際痛點，砍。
- Salt Player Hi-Fi whitelist：目前主要藍牙耳機使用情境無實質收益，砍。
- SmartShot + VivoAssistant：中國本地 AI / 智慧服務收益低、系統耦合高，砍。
- EasyShare 開源版：已有 Quick Share + LocalSend，砍。

---

## 目前優先序

1. **patched YouTube Music / `com.luna.music` runtime validation**。
2. **YouTube `com.apple.android.music` 日用觀察**：已可使用；只做必要 polish，不再花時間追求舊 ReVanced 設定 1:1 複製。
3. **Instagram HDR**：YT Music 完成後，若仍有需求，再回到 Meta HDR eligibility / rendition gate。
4. **LINE / IG / Threads 等 App patch**：有明確痛點再維護。
5. **通知雙卡 / 長標題 UI**：cosmetic，低優先。
6. **Ghost Player**：不安裝、不修；僅備援。
7. **MiCTS**：已有可用方案，暫停研究。

## 操作原則

- GitHub repo 為修補專案 source of truth。
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A shell 執行工具。
- 對候選修補先看日用價值，不因公開存在方案就自動納入。
- non-root 日用修補已接近飽和；新項目若只是「能做」，但沒有實際缺口或收益，不自動納入。
