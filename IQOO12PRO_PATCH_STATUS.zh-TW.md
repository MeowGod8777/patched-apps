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

目前不是靠 clone package 讓 patched YouTube 偽裝成 Apple Music / 酷狗，而是直接修改 vivo 的 OriginPlayer package allow-list：

```sh
new_data='["tv.danmaku.bili","com.android.bbkmusic","app.revanced.android.youtube"]'
settings put system musicwidget_list_pkg_type_key "$new_data"

if [ $? -eq 0 ]; then
  echo "Successfully updated musicwidget_list_pkg_type_key."
  current_data=$(settings get system musicwidget_list_pkg_type_key)
  echo "New data: $current_data"
else
  echo "Error: Failed to update musicwidget_list_pkg_type_key."
  exit 1
fi
```

目前 YouTube 本身已是 patched build，package 為：

```text
app.revanced.android.youtube
```

這條設定可以讓 vivo OriginPlayer 直接讀取 YouTube；因此「再做一個改 package name 的 YouTube-OriginPlayer build」目前不是主線，除非之後證明 package identity 能帶來不同且必要的 UI / policy 行為。

### Exact OriginPlayer baseline（2026-09-03）

V2329A exact build 上的 OriginPlayer / `VivoMusicWidgetMix`：

```text
package: com.vivo.musicwidgetmix
versionCode: 6271
versionName: 6.2.7.1
minSdk: 34
targetSdk: 34
path: /system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk
```

當次實機 `settings list system | grep -Ei 'musicwidget|music_widget'` 基線：

```text
music_widget_mix_panel_show=0
music_widget_mix_play_control_pkg_key=com.android.bbkmusic.local
music_widget_play_local_key=0
musicwidget_list_pkg_other_type_key=[]
musicwidget_list_pkg_type_key=["com.android.bbkmusic","com.android.bbkmusic.local"]
musicwidgetmix_agree_statement_system_key=1
musicwidgetmix_service_and_statement_key=0
```

重要觀察：

1. exact build 上除了 `musicwidget_list_pkg_type_key`，確實還存在 `musicwidget_list_pkg_other_type_key` 與 `music_widget_mix_play_control_pkg_key`。
2. `musicwidget_list_pkg_other_type_key` 在當次基線為空陣列 `[]`，因此不能先假定它就是「完整鎖屏卡模板白名單」；需要 APK 靜態分析或受控 A/B 才能定義語義。
3. `music_widget_mix_play_control_pkg_key=com.android.bbkmusic.local` 看起來像目前 / 預設播放控制來源，但目前只記為觀察，不先當成模板分類證據。
4. 當次讀回的 `musicwidget_list_pkg_type_key` 已回到 stock-like 值 `com.android.bbkmusic` + `com.android.bbkmusic.local`，沒有先前手動加入的 Bilibili / patched YouTube。這表示先前 allow-list 寫入至少「當次並未持續存在」；原因可能是後續重設、系統重寫或其他流程覆蓋，尚未判定。後續若再測必須同時記錄寫入前 / 寫入後 / 重開機後值，不能把一次成功寫入當成永久設定。

### Ghost Player 的定位

Ghost Player **不排除**。

目前它的價值不是單純讓 YouTube 進 OriginPlayer，而是：

- Ghost 使用 vivo 已認可的音樂播放器身份 / MediaSession 路線。
- 鎖屏播放器模板比直接把 YouTube 加入 `musicwidget_list_pkg_type_key` 後的呈現更完整、主觀上也更好看。
- 因此即使原生白名單已能讓 YouTube 被 OriginPlayer 讀到，Ghost 仍有獨立的鎖屏 UI 價值。

已知問題：

- Ghost Player 與 Wavelet 同時使用時曾出現影片無聲。
- 停止播放後曾出現島 / 播放狀態殘留。

目前不急著修 Ghost，因為 Wavelet 使用頻率已降低；除非問題重新成為日用痛點，再進一步追 silent AudioTrack / MediaSession bridge 與 Wavelet audio-session detection 的衝突。

### 後續真正值得研究的 Player 問題

優先研究：

> 能否只靠 vivo 的 package classification / settings / policy，讓 `app.revanced.android.youtube` 直接取得 Ghost / 正式音樂播放器那種完整 OriginPlayer 鎖屏模板，而不需要 Ghost 中轉。

需要區分：

1. `musicwidget_list_pkg_type_key` 只負責 eligibility，還是也影響模板分類。
2. `musicwidget_list_pkg_other_type_key` 的真實用途。
3. `music_widget_mix_play_control_pkg_key` 是單純 current/default source，還是會參與 UI / control routing。
4. 完整鎖屏模板是否另依 package identity、audio playback activity、MediaSession metadata shape、vivo 私有 allow-list / app type 決定。
5. 若無法直接取得完整模板，則 Ghost 保留作鎖屏 UI bridge。

下一步優先取得 exact `/system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk` 做靜態分析，直接搜尋上述三個 settings key 的 reader / branch / template selection；在靜態語義確定前，不盲寫 `other_type_key`。

---

## MiCTS / Google Circle to Search

已安裝 / 測試 MiCTS，Google 已設為預設數位助理。

初次測試曾出現「第一次觸發沒反應、第二次才成功」的狀況；後續已找到可接受的觸發解法，因此 **CTS 路線目前不再繼續研究，視為已有可用方案**。

不再花時間追 MiCTS 內建長按小白條、VIS 延遲或其他替代觸發，除非日後現有方案失效。

---

## 已降級 / 已砍候選

### VLiveConvert / vivo 動態照片轉 Motion Photo

目前會拍動態照片，但頻率不高，跨 iPhone / 聊天軟體相容需求也不強。

**結論：先砍，不投入時間。**

### Bitwarden / Keyguard FIDO patch

只有在明確要把第三方密碼管理器當 passkey provider、且 vivo FIDO / Credential Manager 相容性真的出問題時才有價值。

目前沒有這個痛點。

**結論：砍。**

### Salt Player Hi-Fi whitelist

目前主要耳機 / 音訊設備不是以 vivo 手機內建有線 Hi-Fi DAC 路線為核心。Bluetooth 耳機不會因把 Salt 加入 vivo Hi-Fi allow-list 就取得等價收益。

**結論：砍。**

### SmartShot + VivoAssistant 新版

牽涉 vivo 系統包、簽名權限與中國本地 AI / 智慧服務整合，對目前台灣日用價值不高，風險 / 收益比不合理。

**結論：砍。**

### EasyShare 開源版

已有 Quick Share 與 LocalSend；EasyShare 額外互傳聯盟 / Shizuku 路線對目前設備組合沒有足夠價值。

**結論：砍。**

---

## 目前優先序

1. **OriginPlayer / 鎖屏模板分類研究**：確認能否讓 patched YouTube 直接取得 Ghost 類完整鎖屏模板。
2. **Ghost Player**：保留；只有 Wavelet 衝突或狀態殘留重新成為實際痛點時才修。
3. **MiCTS**：已有可用觸發方案，暫停研究。
4. 其餘 VLiveConvert / FIDO / Salt Hi-Fi / SmartShot / EasyShare：目前不做。

## 操作原則

- GitHub repo 作為修補專案的 source of truth。
- 已結案項目不要因新對話再次從頭診斷。
- Runner 是 V2329A 的 shell 執行工具；指令預設提供 Runner 可直接執行的格式。
- 對候選修補先看日用價值，不因為 GitHub 上存在可移植方案就自動列入主線。
