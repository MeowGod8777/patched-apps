# iQOO 12 Pro / YT Music existing MediaBrowser -> Vivo c0 bridge plan

更新：2026-09-03 20:08 +08:00

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

## Build checkpoint

### 1. New-workflow bootstrap

第一版新 workflow run `33752115800` 在 workflow bootstrap 層 `jobs=[]` failure，因此沒有 APK。

為排除 registration 問題，改用本輪稍早已成功的既有 workflow slot：

```text
.github/workflows/extract-luna-vivo-protocol-classes25.yml
workflow id: 349274710
previous success: 33749338695
```

### 2. Raw descriptor correction

Builder run：

```text
33752953035
job 100640510283
```

成功完成 base download / hash / Apktool full decode，第一個真實 failure 是：

```text
method not found:
public final f(Ljava/lang/String;Landroid/os/Bundle;)Ldefpackage/bze;
```

確認是 JADX `defpackage.*` 顯示 alias；raw smali 使用 no-package descriptor：

```text
Lbze;
Lbzu;
```

patcher 已修正。

### 3. Injection 已命中，第二個 failure 是 invoke register encoding

修 descriptor 後 run：

```text
33753312578
job 100641676540
```

已成功：

```text
manifest support.service injection ✅
onGetRoot VIVO_MUSIC_MIX_ROOT injection ✅
onLoadChildren vivo_probe_1 injection ✅
```

Apktool smali output 也直接確認：

```text
MusicBrowserService.smali
new-instance v0, Lbze;
const-string v1, "VIVO_MUSIC_MIX_ROOT"
...
const-string v2, "vivo_probe_1"
...
invoke-virtual {p2, v0}, Lbzu;->c(Ljava/lang/Object;)V
```

Rebuild failure：

```text
MusicBrowserService.smali[768,4]
Invalid register: v19. Must be between v0 and v15, inclusive.
```

根因：原 `onGetRoot` 是高 register-count method，`p1` 映射到 `v19+`；注入中的普通 `invoke-virtual {v0, p1}` 使用 35c encoding，只允許低 register。這不是 protocol / class / method mismatch。

修法：在 invoke 前先：

```smali
move-object/from16 v1, p1
```

再用：

```smali
invoke-virtual {v0, v1}, ...
```

`onLoadChildren` 也對 `p1/p2` 做同樣 low-register staging，避免下一步才撞同一類問題。

只有 rebuild、16K zipalign、same-signer verification 全部通過後才把 APK 提供實機測試。
