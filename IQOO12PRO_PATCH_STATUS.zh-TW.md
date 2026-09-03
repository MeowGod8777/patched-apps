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

`com.apple.android.music` build **升級為日用候選，可以直接開始日用**。

但目前尚未做 Google 帳號登入，因此在刪除原本 `app.revanced.android.youtube` 前，至少補完：

1. MicroG / GmsCore 帳號登入；
2. 重開機後帳號仍存在；
3. `youtube.com` / `youtu.be` 外部連結可正常進入這顆；
4. 平常有使用的背景播放 / PiP / Cast 再各驗一次。

以上不是系統風險 gate，而是 production polish。此 build 本質仍是普通 user APK，出問題可卸載；現階段最合理做法是**先直接日用，但暫時保留舊 YouTube 當 fallback**。

若未來要裝真正 Apple Music，需改用另一個尚未占用的 framework-support + lock-cooperation identity。

---

## Ghost Player：目前不需要重裝

Ghost Player 現在**沒有安裝**。先前因與 Wavelet 同時使用時出現無聲問題而移除。

在 YouTube 已可直接以 framework-support identity 取得完整 OriginPlayer UI 後，Ghost 不再是 YouTube 的必要中介。

撇除 YouTube，目前也沒有強需求要求重裝 Ghost：

- Bilibili `tv.danmaku.bili` 在 exact OriginPlayer 內已有 dedicated cooperation path；
- 未來 YT Music 可直接使用另一個 framework-support identity；
- Ghost 仍會增加額外 MediaSession / audio-activity bridge，且與 Wavelet 已有實機衝突紀錄。

**目前結論：Ghost 保留為概念上的備援工具，但不安裝、不修、不列主線。**

只有未來出現「某個無法重打包、OriginPlayer 又完全不支援的播放器，而且確實需要 richer lockscreen」時才重新考慮 Ghost。

---

# 下一條：patched YT Music + Bilibili 音樂整合

使用者下一步打算安裝 / 製作 patched YouTube Music，並把 Bilibili 音樂來源整合到 YT Music；目前尚未安裝與實作。

OriginPlayer 方向已經很明確：

1. YouTube 保留 `com.apple.android.music`。
2. YT Music **必須使用不同 package identity**，避免 collision。
3. 第一候選暫定 `com.luna.music`：exact OriginPlayer 6.2.7.1 已確認它屬 framework-support 候選，且先前實機 collision scan 為 FREE。
4. `com.spotify.music` 等也可用，但若未來要裝真 Spotify 會直接 collision，因此不是第一選擇。
5. 如果 Bilibili 音樂實際是在 YT Music App 內播放、MediaSession owner 仍是 patched YT Music，那 OriginPlayer 只需要認 YT Music 的 framework-support identity；這會比再引入 Ghost 更乾淨。

在選定 Bilibili 音樂整合 patch / source 之前，不先假定其內部實作方式。下一輪先確認 patched YT Music 的來源、版本與 integration 機制，再建立獨立 identity build。

---

## 已砍候選

- VLiveConvert / vivo 動態照片：目前需求低，先砍。
- Bitwarden / Keyguard FIDO patch：無實際痛點，砍。
- Salt Player Hi-Fi whitelist：目前主要藍牙耳機使用情境無實質收益，砍。
- SmartShot + VivoAssistant：中國本地 AI / 智慧服務收益低、系統耦合高，砍。
- EasyShare 開源版：已有 Quick Share + LocalSend，砍。

---

## 目前優先序

1. **YouTube `com.apple.android.music` 日用**：直接開始使用；補帳號登入 / 重啟持久化 / 外部連結驗證後即可正式替代舊 build。
2. **patched YT Music + Bilibili 音樂整合**：下一條主線；使用獨立 framework-support identity，首選暫定 `com.luna.music`。
3. **通知雙卡 / 長標題 UI**：只有日用真的覺得煩再處理。
4. **Ghost Player**：目前不安裝、不修；僅備援。
5. **MiCTS**：已有可用方案，暫停研究。

## 操作原則

- GitHub repo 為修補專案 source of truth。
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A shell 執行工具。
- 對候選修補先看日用價值，不因公開存在方案就自動列入主線。
