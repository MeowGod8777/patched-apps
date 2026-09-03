# iQOO 12 Pro / YT Music existing MediaBrowser -> Vivo c0 bridge plan

更新：2026-09-03 20:00 +08:00

此檔是 `IQOO12PRO_YTMUSIC_LUNA_COOPERATION_RE_2026-09-03.md` 的後續 narrow checkpoint。建立本檔後才產出下一顆 APK。

## 新確認：YT Music 9.15.51 本身已經有 exported MediaBrowserService

對已驗證日用 base APK：

```text
YouTube_Music_9.15.51_Luna_iQOO12Pro.apk
package = com.luna.music
SHA256 = 0b1b61ad6bd87dacc88517adf19c1115085d529e63847d50d587476efa4ce307
```

用 JADX 1.5.6 直接解 manifest，發現 YT Music 已宣告：

```xml
<service
    android:name="com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService"
    android:exported="true"
    android:configChanges="locale"
    android:foregroundServiceType="mediaPlayback">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService"/>
        <action android:name="android.intent.action.MEDIA_BUTTON"/>
    </intent-filter>
</service>
```

因此下一步**不需要先注入一整顆新的 MediaBrowserService**。較乾淨的路徑是重用 YT Music 自己已經和 real player/session 整合的 `MusicBrowserService`，只加 Vivo cooperation bridge。

## YT Music MusicBrowserService 的 onGetRoot gate

JADX exact class：

```text
com.google.android.apps.youtube.music.mediabrowser.MusicBrowserService
```

其 obfuscated callback：

```text
f(String clientPackageName, Bundle rootHints) -> bze
```

對應 MediaBrowser `onGetRoot`。

該方法會先做 client allowlist：

```text
if (!kxo.g(clientPackage, browserInfo)) {
    return null;
}
```

因此單純在 manifest 增加：

```text
com.vivo.musicwidgetmix.support.service
```

雖然足以讓 Vivo query 找到 service、使 package 進 custom-insert 候選，但 `com.vivo.musicwidgetmix` 很可能仍會被 YT Music 自己的 MediaBrowser client allowlist 拒絕。

所以第一顆 cooperation prototype 至少要同時做兩件事：

```text
1. existing MusicBrowserService 增加 Vivo cooperation intent action
2. onGetRoot 對 clientPackageName == com.vivo.musicwidgetmix 特判放行
```

Vivo root 使用官方 Luna exact 值：

```text
VIVO_MUSIC_MIX_ROOT
```

## Official Luna PlayerService exact behavior：修正先前過度推測

官方 Luna `PlayerService` exact source 已取得（workflow `33750529313`, artifact `9891349015`）。

它是：

```text
com.luna.biz.playing.player.PlayerService
extends androidx.media.MediaBrowserServiceCompat
```

`onGetRoot` exact 行為：

```text
clientPackageName == com.vivo.musicwidgetmix
    -> BrowserRoot("VIVO_MUSIC_MIX_ROOT", null)

clientPackageName == own package
    -> BrowserRoot(appName, null)

otherwise
    -> null
```

`onLoadChildren` 對：

```text
parentId contains "vivomusicmix_current_list"
```

時回傳：

```text
currentPlayable
+ nextQueue
```

每個 item：

```text
MediaDescriptionCompat.mediaId = playable.getPlayableId()
MediaDescriptionCompat.title   = track title
MediaDescriptionCompat.subtitle = artist / subtitle
MediaBrowserCompat.MediaItem flags = 2 (playable)
```

因此對 official Luna 這個版本，服務端 current-list 實作**沒有依賴 paging extras 才能工作**。Vivo `c0` 即使傳 page option，official Luna 此 implementation 也可直接忽略，回 current + next queue。

這修正了前一 checkpoint 對 `vivomusicmix_key_has_more / page` 的過度延伸：那些 key 可存在於 Vivo controller/paging 邏輯，但不是第一顆 YT Music bridge 的必要條件。

## 下一顆：Vivo c0 browser probe v0

為避免一次把 actual queue bridge + item selection 全部塞進去，第一顆先做 end-to-end cooperation probe。

Base：

```text
YT Music 9.15.51
com.luna.music
validated ReVanced/Morphe base unchanged
```

只增加：

```text
A. Manifest
   existing MusicBrowserService intent-filter +=
   com.vivo.musicwidgetmix.support.service

B. onGetRoot
   if clientPackageName == com.vivo.musicwidgetmix:
       return BrowserRoot("VIVO_MUSIC_MIX_ROOT", null)
   else:
       original YT Music logic

C. onLoadChildren
   if parentId contains vivomusicmix_current_list:
       return one static playable MediaItem:
         mediaId = vivo_probe_1
         title = YT Music Vivo Bridge
         subtitle = c0 cooperation probe
         flags = 2
   else:
       original YT Music logic
```

**這一顆暫時不實作 playFromMediaId。**

目的只回答：

```text
1. Vivo package 是否因 support.service 被升到 custom-insert/c0
2. c0 能否成功 bind YT Music existing MusicBrowserService
3. playlist 按鈕是否由 inert 變成可開
4. Vivo 是否能顯示 service 回傳的 probe MediaItem
```

若 probe item 能出現，下一顆再把 static item 換成 real current MediaSession queue；若 list 可顯示但點 item 不動，再單獨做 `playFromMediaId` bridge。

這樣每一輪都保持可歸因，不再用 MediaSession action-bit 猜測。

## Build bootstrap checkpoint

第一版新 workflow：

```text
.github/workflows/build-ytmusic-luna-vivo-c0-browser-probe-v0.yml
commit c8c5d55d1750727ccb671cc772c1a74b7dfa46d2
run 33752115800
```

GitHub 對該 run 直接回：

```text
status=completed
conclusion=failure
jobs=[]
```

也就是 workflow 尚未進入任何 runner job，因此**沒有產出 APK，也不能把它算成 patch/build failure**；這是 Actions workflow bootstrap / registration 層失敗。

另建最小 smoke workflow 後，push trigger 也沒有正常出現在該 commit 的 workflow runs；同時 repo 內數個舊 workflow 會在每次 push 立即產生 `jobs=[]` failure。因目前 API 沒有提供更進一步的 workflow-parser annotation，下一步改用已知在本輪稍早成功執行過的既有 workflow slot：

```text
.github/workflows/extract-luna-vivo-protocol-classes25.yml
previous successful run: 33749338695
```

把該已驗證可進 runner 的 workflow 暫時改造成 c0 probe builder，避免把「新 workflow registration 問題」和「APK patch 本身」混在一起。

只有 runner 真正開始並完成 rebuild / zipalign / signer verification 後，才會把 APK 提供實機測試。
