# iQOO 12 Pro / OriginOS 6 修補狀態

更新：2026-09-04 12:05 +08:00

這份文件是 `iQOO 12 Pro / V2329A / PD2329` 日用 App / non-root 修補的目前 source of truth。詳細反編譯、A/B、build 與 runtime 證據保留在各專項文件；本檔只保留目前可執行結論與是否仍需投入。

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

截至 2026-09-04，iQOO 12 Pro 的 `patched-apps` / non-root App 修補主線已基本清空。

目前狀態：

- YouTube Music / OriginPlayer：**結案**。
- LINE 26.11.0：**已進入日用且目前正常，結案 / maintenance only**。
- Threads：**外部 App 連結跳轉問題已解決，結案**。
- Instagram HDR：**使用者主動放棄，不再投入時間**；保留既有 RE 與證據，但不列 active backlog。
- Google Quick Share：**結案**；LocalSend 作跨平台備援。
- Google Maps Timeline / 移動路線軸：**結案**，不重跑已完成診斷。
- Origin Isle / SuperX：**已打通**。

除非日用出現新的明確 regression / pain point，**目前沒有新的 iQOO 12 Pro App 修補主線待辦**。

**Temporary Root / Scene root mode / scheduler / thermal / 續航研究屬另一權限層級與另一研究專案，不計入本 non-root patched-apps 完成度。**

---

# YouTube Music / OriginPlayer：FINAL SUCCESS

## 最終產品目標

修復 iQOO 12 Pro / OriginOS 6 上 patched YouTube Music 的 OriginPlayer：

- richer OriginPlayer / lockscreen / media island 正常；
- 「播放列表」可打開；
- 顯示 real current + upcoming queue；
- row title / artist 正常；
- 點 playlist row 可切歌；
- main card artwork / title / artist 可跟著切歌刷新；
- elapsed / duration / progress 正常。

以上項目目前均已實機 PASS。

## 最終 known-good baseline

```text
APK: YouTube_Music_9.15.51_Luna_VIVO_C0_V5_MEDIA_IDENTITY.apk
stock version: 9.15.51
package: com.luna.music
APK SHA256: 547d7b1d31a68e32d273a770e4575f50fef6948246f984ae5d310ad0195b8427
signer SHA256: 7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c
workflow run: 33832184688
artifact: 9922079285
```

Build-success checkpoint：

`IQOO12PRO_YTMUSIC_V5_MEDIA_IDENTITY_BUILD_SUCCESS_CHECKPOINT_2026-09-04.md`

Runtime-success checkpoint：

`IQOO12PRO_YTMUSIC_V5_MEDIA_IDENTITY_RUNTIME_SUCCESS_2026-09-04.md`

## 最終已驗證 contract

完整成功組合不是單一 queue/action bit，而是：

```text
1. Vivo cooperation service / controller c0 path
2. real current-list MediaBrowser browse
3. V5 playable row mediaId
   Lnoq.n() -> Lazmi.b:Lboht -> Llgl.d(...)
4. playFromMediaId(native playable mediaId)
5. official Luna normal-track support_event = 0x9DF
6. android.media.metadata.MEDIA_ID = 同一個 native playable identity
```

其中：

- `queue + ACTION_SKIP_TO_QUEUE_ITEM` 已反證不足；
- `Lnoq.o()` 已證明是 queue DELETE endpoint，不可作 selection mediaId；
- `Lid` queueId parser / `skipToQueueItem` 路線已退休，不可重做；
- `support_event=0x9DF` 修復 Vivo timing/progress capability；
- metadata `MEDIA_ID` 與 current-list / selection playable identity 對齊後，Vivo title / artist refresh 正常。

**V5 media-identity APK 是目前 iQOO 12 Pro 的正式 regression baseline。不要再從早期 V2/V3/V4/V4N 分支重開。**

---

# LINE 26.11.0：DAILY / CLOSED

使用者已確認目前 12 Pro 上 LINE 26.11.0 進入日用，現階段功能正常。

先前關注的 patch / integration 包括廣告與入口精簡、push、LINE Pay、GMS / MicroG、Google Drive backup / restore 等；目前沒有新的日用 blocker，因此：

- 狀態：**CLOSED / maintenance only**
- 不主動重做 RE；
- 只有出現明確 regression、登入 / push / backup / link / payment 等實際問題時再開單點修補。

---

# Threads：CLOSED

先前問題：從其他聊天 App 內點 Threads 連結無法正常跳轉，而瀏覽器直接開正常。

目前使用者已確認：**跳轉問題已解決。**

- 狀態：**CLOSED**
- 不再列 active backlog。

---

# Instagram HDR：ABANDONED BY USER

既有 RE 已證明：

- Android / vivo HDR display path 正常；
- YouTube HDR 可正常工作；
- Instagram Reels 的真正缺口位於 Meta / Instagram HDR request eligibility / device classification / rendition delivery gate，而非面板或 Android HDR 顯示能力。

截至 2026-09-04，使用者判斷繼續投入的時間成本不值得，**主動放棄此修補方向**。

因此：

- 狀態：**ABANDONED / ARCHIVED**
- 保留既有 RE / traces / workflows 作歷史證據；
- 不再主動研究、build 或要求 device probe；
- 只有使用者未來明確要求重開時才恢復。

---

# 其他已結案 / 已打通

- Google Quick Share：本修補主線結案；LocalSend 作跨平台備援。
- Google Maps Timeline / 移動路線軸：結案，不重跑已完成診斷。
- Origin Isle / SuperX：已打通。
- `com.autonavi.minimap` 導航島失敗根因已證明曾是 vivo 原子通知 policy `NAVIGATION=false`，不是 payload / template / signature。
- MiCTS / Google Circle to Search：已有可接受實機解法，暫停研究。
- Ghost Player：不安裝、不修、不列主線；先前與 Wavelet 有無聲問題，而且目前核心播放器已不需要 Ghost 中介。

---

# 目前 backlog

```text
Active iQOO 12 Pro patched-apps backlog: none
```

若未來出現新問題，先確認是否屬：

1. App 本身 regression；
2. OriginOS / Vivo framework integration；
3. package identity / MediaSession / MediaBrowser cooperation；
4. 另一個獨立 temporary-root / scheduler / thermal 專案。

不要因新對話而把已結案項目重新從頭研究。

---

## 操作原則

- GitHub repo 是本專案唯一 source of truth。
- 每次要產出新的候選 APK 前，先把已確認的新證據、A/B 結果、retired hypothesis 與下一步同步 GitHub。
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A shell 執行工具。
- 新 patch 優先維持 single-variable / narrow hypothesis；避免一次改多層導致不可歸因。
- 對候選修補先看日用價值，不因公開存在方案就自動納入。
