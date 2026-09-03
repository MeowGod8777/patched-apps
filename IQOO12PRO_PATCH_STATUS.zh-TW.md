# iQOO 12 Pro / OriginOS 6 修補狀態

更新：2026-09-03

這份文件記錄目前 `iQOO 12 Pro / V2329A / PD2329` 的日用修補、候選功能與已排除方向，避免後續重做已完成或低價值工作。

## 裝置基線

```text
Device: iQOO 12 Pro / V2329A / PD2329
OS: Android 16 / OriginOS 6 中國版
Exact build: PD2329B_A_16.2.19.1.W10.V0101L17
Bootloader: locked
Persistent root: none
Shell 操作工具: Runner
```

**重要：這台裝置日常 shell 指令使用 Runner。不要再把 `rish -c` 當成預設執行方式。**

---

## 已結案 / 已打通

### Google Quick Share

已完成目前需要的修補與驗證，列為結案項目。日常另有 LocalSend 可作跨平台傳輸備援。

### Google Maps 移動路線軸

已完成本機 / overlay / GMS 路線排查，列為結案項目；不要再重跑已完成診斷。

### Origin Isle / 原子通知

Origin Isle / SuperX 路線已打通。

已知一個重要案例：`com.autonavi.minimap` 導航島失敗根因不是 payload / template / signature，而是 vivo 原子通知 policy 對該 package 的 `NAVIGATION=false`。

---

## OriginPlayer / 鎖屏播放器

### 目前實際做法

目前 patched YouTube package：

```text
app.revanced.android.youtube
```

先前透過 Runner 修改：

```sh
new_data='["tv.danmaku.bili","com.android.bbkmusic","app.revanced.android.youtube"]'
settings put system musicwidget_list_pkg_type_key "$new_data"
```

可以讓 OriginPlayer 直接讀取 patched YouTube / Bilibili。

但 exact APK 反編譯後已確認：**`musicwidget_list_pkg_type_key` 只代表整條分類鏈中的一層，與 Ghost 使用的 framework-support package identity 並不等價。**

### Exact OriginPlayer baseline

V2329A exact build：

```text
package: com.vivo.musicwidgetmix
versionCode: 6271
versionName: 6.2.7.1
minSdk: 34
targetSdk: 34
path: /system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk
```

當次 system settings：

```text
music_widget_mix_panel_show=0
music_widget_mix_play_control_pkg_key=com.android.bbkmusic.local
music_widget_play_local_key=0
musicwidget_list_pkg_other_type_key=[]
musicwidget_list_pkg_type_key=["com.android.bbkmusic","com.android.bbkmusic.local"]
musicwidgetmix_agree_statement_system_key=1
musicwidgetmix_service_and_statement_key=0
```

先前自訂 `musicwidget_list_pkg_type_key` 當次已回到 stock-like 值，因此該寫入至少不是可直接假定永久存在；原因尚未判定。

### Exact APK reverse-engineering checkpoint

完整靜態分析另見：

`IQOO12PRO_ORIGINPLAYER_6.2.7.1_RE.zh-TW.md`

已驗證：

1. APK 內存在 hardcoded `framework_support_list`，包括：
   `com.kugou.android.lite`、`com.apple.android.music`、`com.spotify.music`、`cn.kuwo.player`、`com.luna.music` 等。
2. APK 內另有 `lock_cooperation_list`；`com.kugou.android.lite` 與 `tv.danmaku.bili` 都在其中，`app.revanced.android.youtube` 不在。
3. controller factory 的 routing 不只依 settings 白名單：

```text
custom-insert package -> controller/c0
framework-support package -> controller/o0
tv.danmaku.bili -> controller/g
otherwise -> controller/z2 generic
```

4. 因此原先路徑實際上是：

```text
Ghost / com.kugou.android.lite -> framework-support -> o0
Bilibili / tv.danmaku.bili     -> dedicated g
patched YouTube                -> generic z2
```

這是目前最強的 exact-build 靜態證據，可直接解釋為什麼 patched YouTube 即使透過 `musicwidget_list_pkg_type_key` 進 OriginPlayer，鎖屏仍比 Ghost 的正式音樂播放器模板簡單。

### Secure lock whitelist / custom insert

APK 另確認：

- `lock_music_app_white_list` 位於 `Settings.Secure`。
- 若該 key 非空，lockscreen 先使用它；否則 fallback 到 stock `lock_cooperation_list`。
- 但之後仍會經過 package eligibility validator，所以單純 `settings put secure lock_music_app_white_list ...` 不是完整 bypass。
- `custom_insert_music_white_list` 也不是普通手寫白名單：`MainApplication` 會 query action `com.vivo.musicwidgetmix.support.service` 來建立 runtime `l0`。
- custom-insert package 會被 `controller/c0` 當成 cooperation player，OriginPlayer 會用 `MediaBrowserCompat` 連到該 exported service。

因此不採用「給 YouTube Manifest 塞一個空 dummy service」的粗暴方案；service 若不真正符合 MediaBrowser 預期，可能直接把控制路徑弄壞。

### Ghost Player 的定位

Ghost Player **不排除**，但 package-identity A/B 已證明它不是取得完整播放器 UI 的必要條件。

Ghost 的核心價值來自：

- package `com.kugou.android.lite` 在 exact APK 中本來就是 framework-support + lock cooperation 身份；
- 因此 Ghost 天生會走 `controller/o0`。

已知問題：

- Ghost Player 與 Wavelet 同時使用時曾出現影片無聲。
- 停止播放後曾出現島 / 播放狀態殘留。

因 framework-support identity 已可直接套在真正 YouTube 上，Ghost 後續降為備援，不再是主線依賴。

### 2026-09-03 framework-support identity A/B：SUCCESS

第一顆可並存測試版使用：

```text
stock app: YouTube
selected version: 20.51.39
patched package identity: com.apple.android.music
patches: anddea/revanced-patches 4.2.0
CLI: Morphe Desktop 1.14.0
```

實機驗證條件：

- 未把 `com.apple.android.music` 手動加入 Origin Isle / 原子通知白名單；
- 未依賴原本對 `app.revanced.android.youtube` 的 `musicwidget_list_pkg_type_key` 寫入；
- 僅安裝測試 APK 並給一般所需權限後播放 YouTube。

結果：

- **PASS：OriginPlayer 自動識別並出現。**
- **PASS：桌面 / 展開播放器取得完整 artwork、進度、上一首 / 播放暫停 / 下一首、收藏等 richer music-player template。**
- **PASS：鎖屏直接出現完整音樂播放器卡，而非原本 generic YouTube 簡化樣式。**
- **PASS：OriginOS 上方媒體島 / 展開媒體卡亦自動出現；這次沒有另外把測試 package 加進 Isle。**
- **OBSERVED：通知中心同時可看到 vivo richer media card 與 YouTube 自身 media notification，存在雙卡顯示。**

因此目前可把核心因果關係提升為實機驗證：

```text
YouTube MediaSession
    + framework-support / lock-cooperation package identity
    -> VivoMusicWidgetMix framework-support classification
    -> controller/o0-like richer player path
    -> full OriginPlayer / lockscreen / media-island presentation
```

這表示先前的 `musicwidget_list_pkg_type_key` 只能讓 generic package 被 OriginPlayer 納入；**它不是取得完整合作播放器模板的關鍵。package identity 才是本輪 A/B 中改變 UI path 的關鍵變數。**

目前不再需要優先研究 dummy service / custom-insert bypass，也不需要靠 Ghost 轉發 MediaSession 才能拿到完整模板。

### 仍需做的 production validation

視覺路徑已通；下一步不是再找白名單，而是驗證把此身份當日用 YouTube 是否有副作用：

1. 外部 `youtube.com` / `youtu.be` intent 與預設開啟行為。
2. MicroG 登入、帳號持久化、push / 通知。
3. 背景播放、PiP、Cast、播放佇列與上一首 / 下一首控制。
4. 暫停 / force-stop / 滑掉後 OriginPlayer 與媒體島是否正常清除，不殘留 session。
5. 通知中心雙卡是否可接受，或能否只保留 vivo richer card 而不破壞 MediaSession。
6. 長標題 / 非音樂影片 metadata 在 richer music template 下是否有截斷或控制語意不匹配。

如果上述日用驗證通過，`com.apple.android.music` 可作為目前 V2329A 的 production identity；若日後要安裝真正 Apple Music，再換另一個同屬 framework-support + lock-cooperation 且無 collision 的 identity 即可。

---

## MiCTS / Google Circle to Search

已安裝 / 測試 MiCTS，Google 已設為預設數位助理。

初次測試曾出現「第一次觸發沒反應、第二次才成功」；後續已找到可接受的解法，因此 **CTS 路線暫停研究，視為已有可用方案**。

---

## 已降級 / 已砍候選

### VLiveConvert / vivo 動態照片轉 Motion Photo

目前會拍動態照片，但頻率不高。

**結論：先砍。**

### Bitwarden / Keyguard FIDO patch

目前沒有第三方 passkey provider 的實際痛點。

**結論：砍。**

### Salt Player Hi-Fi whitelist

目前主要音訊設備不是 vivo 手機內建有線 Hi-Fi DAC 路線；Bluetooth 耳機不會因此得到等價收益。

**結論：砍。**

### SmartShot + VivoAssistant 新版

中國本地 AI / 智慧服務收益低、系統耦合高。

**結論：砍。**

### EasyShare 開源版

已有 Quick Share + LocalSend。

**結論：砍。**

---

## 目前優先序

1. **OriginPlayer production validation**：framework-support identity A/B 已成功；現在驗證 `com.apple.android.music` 身份的日用副作用與 session 清理，不再重做白名單研究。
2. **通知雙卡 / 控制語意收尾**：若 production validation 其餘都正常，再決定是否值得處理。
3. **Ghost Player**：降為備援；Wavelet 衝突目前非高優先。
4. **MiCTS**：已有可用方案，暫停研究。
5. 其餘低價值候選目前不做。

## 操作原則

- GitHub repo 作為修補專案 source of truth。
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A 的 shell 執行工具；指令預設提供 Runner 可直接執行的格式。
- 對候選修補先看日用價值，不因為公開存在方案就自動列入主線。
