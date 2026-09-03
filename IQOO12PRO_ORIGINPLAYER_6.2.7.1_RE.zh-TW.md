# iQOO 12 Pro OriginPlayer 6.2.7.1 reverse engineering

更新：2026-09-03

來源：iQOO 12 Pro / V2329A / PD2329，exact build `PD2329B_A_16.2.19.1.W10.V0101L17` 的 `/system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk`。

APK：

```text
package: com.vivo.musicwidgetmix
versionName: 6.2.7.1
versionCode: 6271
minSdk: 34
targetSdk: 34
```

本文件只記錄從 exact APK 靜態分析直接驗證到的行為；未實機驗證的推論會另外標記。

---

## 核心結論

目前 `musicwidget_list_pkg_type_key` 並不是 OriginPlayer 唯一的播放器分類層。

對 `app.revanced.android.youtube` 而言，把 package 寫進 `musicwidget_list_pkg_type_key` 可以解決一般 OriginPlayer eligibility，但 APK 內還存在更高一層的 hardcoded framework-support / lockscreen cooperation 分類。

Ghost Player 使用的 `com.kugou.android.lite` 同時存在於：

1. `framework_support_list`
2. `lock_cooperation_list`

因此它不是單純靠同一個 settings 白名單達成較完整鎖屏 UI。

`app.revanced.android.youtube` 不存在於 APK 內任何 hardcoded package list / package string 中，因此即使透過 `musicwidget_list_pkg_type_key` 讓 OriginPlayer 接受它，controller factory 仍會落到 generic controller 路線。

---

## framework_support_list

APK 內 `R$array.framework_support_list`：

```text
cn.kuwo.player
cmccwm.mobilemusic
com.kugou.android.lite
com.kugou.android.elder
app.podcast.cosmos
fm.qingting.qtradio
com.yibasan.lizhifm
com.luna.music
com.hiby.music
com.tencent.blackkey
com.apple.android.music
com.spotify.music
cn.missevan
```

`MainApplication.k0()` 會將此 array 載入靜態集合 `MainApplication.f0`，log 名稱可見 `frameworkSupporWhitetList`。

controller factory `controller/d3.a(...)` 會檢查 package 是否位於 `MainApplication.f0`；命中時回傳獨立 controller `controller/o0`。

這點對 Ghost 很重要：`com.kugou.android.lite` 會走 `o0`，不是 generic controller。

---

## lock_cooperation_list

APK 內 `R$array.lock_cooperation_list`：

```text
com.android.bbkmusic
com.tencent.qqmusic
com.ximalaya.ting.android
com.kugou.android
com.netease.cloudmusic
com.vivo.newsreader
bubei.tingshu
cn.kuwo.player
cmccwm.mobilemusic
com.kugou.android.lite
com.kugou.android.elder
app.podcast.cosmos
fm.qingting.qtradio
com.yibasan.lizhifm
com.luna.music
com.hiby.music
com.tencent.blackkey
com.vivo.agent
com.vivo.base.agent
com.xs.fm
com.xs.fm.lite
com.apple.android.music
com.spotify.music
cn.missevan
com.vivo.screenreader
com.vivo.ai.gptagent
com.qiyi.video
com.ss.android.ugc.aweme
com.tencent.qqmusicpad
cn.wenyu.bodian
com.kmxs.reader
com.qidian.QDReader
com.dragon.read
com.qq.reader
io.dushu.fandengreader
com.jjwxc.reader
com.jd.app.reader
bubei.tingshu.pro
com.luojilab.player
com.kugou.android.tingshu
tv.danmaku.bili
com.shuqi.controller
com.salt.music
com.kugou.viper
com.tencent.weread
com.shinyv.cnr
com.tencent.mm
com.zzqweb.lightplayer
com.tencent.news
```

因此 Bilibili 也確實在 stock lockscreen cooperation list 中；YouTube patched package 則不在。

---

## music_black_list

APK 內 `R$array.music_black_list`：

```text
com.netease.cloudmusic:videoplay
```

目前與 YouTube 問題無直接關係。

---

## Secure Settings / lockscreen whitelist 路徑

`com.vivo.musicwidgetmix.utils.d.I(Context)`：

1. 從 Secure Settings 讀 `lock_music_app_white_list`。
2. 若值非空，直接使用。
3. 若值為空，才 fallback 到 `R$array.lock_cooperation_list`。

讀取 JSON List 的 `MusicListUtils.i(...)` 最終使用：

```text
Settings.Secure.getString(...)
```

因此這一組 lockscreen whitelist 在 `secure` namespace，不是 `system`。

`d.H(Context)` 會再從上述清單扣除 vivo suppression list：

```text
/data/bbkcore/NanoMusicPlayer_remove_app_lists_2.0.xml
key: remove_music_list
```

`d.K(Context)` 會：

1. 取得 `d.H(...)`
2. 逐 package 呼叫 `d.e(Context, pkg)`
3. `d.e(...) == false` 的 package 會被移除

`LockScreenMusicWidgetV2.setSupportPkgs()`、V1 及 fold lock variant 都會使用 `d.K(...)`，最後把 `support_packages` 傳給 KeyguardMusicRemoteManager。

因此只手動把任意 package 塞進 `lock_music_app_white_list`，不代表一定能越過後續 eligibility filter。

---

## d.e() 與 custom insert whitelist

`d.e(Context,String)` 是 package / version / eligibility validator。

對沒有專用 hardcoded case 的 package，default branch 會檢查：

```text
MainApplication.l0.contains(packageName)
```

`MainApplication.l0` 是 runtime 的 custom-insert whitelist。

`MainApplication.i0()` 會：

1. 清空 `l0`
2. query Intent service action：

```text
com.vivo.musicwidgetmix.support.service
```

3. 將查到的 `serviceInfo.packageName` 加入 `l0`
4. 再把 `l0` JSON 寫入 Secure key：

```text
custom_insert_music_white_list
```

重要：這裡不是「從 Secure key 讀回 l0」。真正決定 l0 的來源是 PackageManager 查到的 service。

所以僅執行：

```text
settings put secure custom_insert_music_white_list ...
```

不能保證把任意 package 真正加入 `MainApplication.l0`。

---

## custom-insert controller 不是單純 dummy service

controller factory 對 `MainApplication.l0` 命中的 package 回傳 `controller/c0`（CooperateController）。

`controller/c0` 會再次 query：

```text
com.vivo.musicwidgetmix.support.service
```

然後找出：

- package 名相符
- `serviceInfo.exported == true`

的 service，建立 `ComponentName`，再用 `MediaBrowserCompat` 連線。

因此「只在 YouTube manifest 加一個空的 exported service」不是安全的捷徑；OriginPlayer 會真的把它當 MediaBrowser service 使用。若 service 不實作預期的 MediaBrowser 行為，極可能變成無法連線，而不是得到完整播放器。

目前不把 dummy-service patch 列為候選。

---

## controller factory 分類

`controller/d3.a(Context,int,String,callback)` 已確認的 package routing：

```text
com.netease.cloudmusic       -> controller/x3
bubei.tingshu                -> controller/p2
com.ximalaya.ting.android    -> controller/q5
com.kugou.android            -> controller/e2
com.vivo.newsreader          -> controller/y3
com.android.bbkmusic.local   -> IMusicController
com.android.bbkmusic         -> IMusicController
com.tencent.qqmusic          -> QQMusicController
com.qiyi.video               -> controller/t1
com.vivo.carlauncher         -> controller/o
```

之後再依序：

```text
package in MainApplication.l0 -> controller/c0
package in MainApplication.f0 -> controller/o0
package == tv.danmaku.bili    -> controller/g
otherwise                     -> controller/z2 (generic)
```

因此：

```text
Ghost / com.kugou.android.lite -> framework-support -> o0
Bilibili / tv.danmaku.bili     -> dedicated g
patched YouTube                -> generic z2
```

這是目前最強的 exact-build 證據，能解釋為什麼：

- patched YouTube 只加 `musicwidget_list_pkg_type_key` 後雖然能被 OriginPlayer 讀到，但鎖屏 UI 較普通。
- Ghost 用 `com.kugou.android.lite` 卻能取得更完整的 vivo 音樂播放器路徑。

---

## music_app_white_list 雲端 / model 配置

`MainApplication.p0()` 會從 Secure key：

```text
music_app_white_list
```

讀取 JSON `List<AppModel>`。

`AppModel` 至少包含：

```text
packageName
isCooperate
showLockScreen
colorType
```

解析後會生成：

```text
resident_music_app_white_list
lock_music_app_white_list
music_app_color_map_list
```

並額外把 `framework_support_list` 納入相關集合。

這解釋了 `lock_music_app_white_list` 的資料來源之一，但 controller factory 仍有上述 hardcoded / f0 / l0 分層，因此這些 Secure whitelist 不是 controller tier 的完整替代品。

---

## 對目前修補策略的修正

先前曾把「改 YouTube package identity」視為與 `musicwidget_list_pkg_type_key` 大致重複，現在 exact APK 反編譯後需要修正：

**兩者不是同一件事。**

`musicwidget_list_pkg_type_key` 可以讓 YouTube 進一般 OriginPlayer eligibility；但如果 package identity 本身屬於 `framework_support_list`，controller factory 會改走 `o0`，並且該 package 通常也已在 stock `lock_cooperation_list`。

因此若目標是：

> 不靠 Ghost，讓真正播放 YouTube 的 APK 直接取得與 Ghost 更接近的 OriginPlayer / lockscreen music path

目前最合理、最小風險的實驗是：

1. 保留現有 `app.revanced.android.youtube`。
2. 另外 build 一顆可並存測試版 YouTube。
3. 將測試版 package 改成一個目前未占用、且同時存在於 `framework_support_list` + `lock_cooperation_list` 的身份。
4. 優先只做 runtime UI / playback regression，不先改 system APK 或 secure whitelist。

可候選身份包括：

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

哪一個身份優先，先以實機 collision 檢查與 package-specific special cases 再決定；不要假定任一身份完全等價。

---

## 下一步

Runner 先只做 package collision 檢查，不修改系統：

```sh
for p in com.apple.android.music com.spotify.music cn.kuwo.player cmccwm.mobilemusic com.kugou.android.elder app.podcast.cosmos fm.qingting.qtradio com.yibasan.lizhifm com.luna.music com.hiby.music com.tencent.blackkey cn.missevan; do pm path "$p" >/dev/null 2>&1 && echo "USED $p" || echo "FREE $p"; done
```

再依 collision 結果挑一個 framework-support identity 做 parallel patched YouTube test build。
