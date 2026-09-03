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

4. 因此目前路徑實際上是：

```text
Ghost / com.kugou.android.lite -> framework-support -> o0
Bilibili / tv.danmaku.bili     -> dedicated g
patched YouTube                -> generic z2
```

這是目前最強的 exact-build 證據，可直接解釋為什麼 patched YouTube 即使透過 `musicwidget_list_pkg_type_key` 進 OriginPlayer，鎖屏仍比 Ghost 的正式音樂播放器模板簡單。

### Secure lock whitelist / custom insert

APK 另確認：

- `lock_music_app_white_list` 位於 `Settings.Secure`。
- 若該 key 非空，lockscreen 先使用它；否則 fallback 到 stock `lock_cooperation_list`。
- 但之後仍會經過 package eligibility validator，所以單純 `settings put secure lock_music_app_white_list ...` 不是完整 bypass。
- `custom_insert_music_white_list` 也不是普通手寫白名單：`MainApplication` 會 query action `com.vivo.musicwidgetmix.support.service` 來建立 runtime `l0`。
- custom-insert package 會被 `controller/c0` 當成 cooperation player，OriginPlayer 會用 `MediaBrowserCompat` 連到該 exported service。

因此不採用「給 YouTube Manifest 塞一個空 dummy service」的粗暴方案；service 若不真正符合 MediaBrowser 預期，可能直接把控制路徑弄壞。

### Ghost Player 的定位

Ghost Player **不排除**。

目前它的價值不是單純讓 YouTube 進 OriginPlayer，而是：

- Ghost package `com.kugou.android.lite` 在 exact APK 中本來就是 framework-support + lock cooperation 身份。
- 因此 Ghost 天生會走 `controller/o0`，與普通手動加入 allow-list 的 YouTube 不同。
- 鎖屏播放器模板更完整，主觀上也更好看。

已知問題：

- Ghost Player 與 Wavelet 同時使用時曾出現影片無聲。
- 停止播放後曾出現島 / 播放狀態殘留。

目前不急著修 Ghost，因為 Wavelet 使用頻率已降低。

### Player 主線修正

先前曾把「改 YouTube package identity」視為與 `musicwidget_list_pkg_type_key` 大致重複；**exact APK 反編譯後此結論已修正。**

如果目標是不用 Ghost、直接讓真正 YouTube 取得更接近 Ghost 的完整 OriginPlayer / lockscreen path，目前最合理的測試是：

1. 保留現有 `app.revanced.android.youtube` 不動。
2. 做一顆可並存的 YouTube test build。
3. 測試版使用一個目前未占用、同時位於 `framework_support_list` + `lock_cooperation_list` 的 package identity。
4. 先只驗證播放、MediaSession、OriginPlayer 鎖屏 UI、MicroG 登入與外部 intent，不碰 system APK。

候選身份：

```text
com.apple.android.music
com.spotify.music
cn.kuwo.player
cmccwm.mobilemusic
com.kugou.android.elder
app.podcast.cosmos
fm.qingting.qtradio
com.yibasan.lizhifm
com.luna.music
com.hiby.music
com.tencent.blackkey
cn.missevan
```

`com.kugou.android.lite` 已由 Ghost 使用，不作 parallel test identity。

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

1. **OriginPlayer framework-support identity A/B**：確認 patched YouTube 直接使用 framework-support package 身份後，能否取得 Ghost 類完整鎖屏模板。
2. **Ghost Player**：保留；Wavelet 衝突目前非高優先。
3. **MiCTS**：已有可用方案，暫停研究。
4. 其餘低價值候選目前不做。

## 操作原則

- GitHub repo 作為修補專案 source of truth。
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A 的 shell 執行工具；指令預設提供 Runner 可直接執行的格式。
- 對候選修補先看日用價值，不因為公開存在方案就自動列入主線。
