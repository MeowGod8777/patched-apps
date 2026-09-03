# iQOO 12 Pro / YT Music Luna cooperation protocol RE

更新：2026-09-03

本檔記錄 iQOO 12 Pro / OriginOS 6 上 `YouTube Music -> com.luna.music` 的 OriginPlayer richer UI、播放列表失效、單變量 A/B，以及 exact `VivoMusicWidgetMix 6.2.7.1` / official Luna protocol reverse engineering 結論。

## 裝置與系統基線

```text
Device: iQOO 12 Pro / V2329A / PD2329
Android: 16
OriginOS: 6 中國版
Exact build: PD2329B_A_16.2.19.1.W10.V0101L17
Bootloader: locked
Persistent root: none
Shell tool: Runner
```

Exact vivo media integration package：

```text
package: com.vivo.musicwidgetmix
versionCode: 6271
versionName: 6.2.7.1
path: /system/app/VivoMusicWidgetMix/VivoMusicWidgetMix.apk
```

## 已成功的 YT Music Luna build

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

Runtime UI validation：

- PASS：full richer OriginPlayer card。
- PASS：OriginOS home media island / expanded media card。
- PASS：lockscreen / notification richer vivo media presentation。
- PASS：artwork / title / artist / progress。
- PASS：previous / play-pause / next。
- OBSERVED：standard YouTube Music notification 可能與 vivo richer card 同時存在，屬 cosmetic duplicate。
- FAIL：richer card 的「播放列表」按鈕顯示但點擊無反應。

## MediaSession baseline：queue 本身不是問題

Runner dump：

```text
package=com.luna.music
active=true
flags=3
rating type=2
actions=2600887
queueTitle=即將播放
queue size=25
```

使用者實測上一首、下一首均正常。

因此 baseline 已證明：

```text
MediaSession queue       ✅ 25 items
queue title              ✅ 即將播放
previous / next          ✅
playlist button click    ❌
```

## Queue-bit A/B：已反證

原 hypothesis：Vivo richer playlist 可能要求 `ACTION_SKIP_TO_QUEUE_ITEM = 0x1000`。

建立單變量 A/B，只在 framework `PlaybackState.actions` OR 入 `0x1000`，不改 queue、不注入 callback。

最終可安裝 aligned build：

```text
workflow run: 33734284316
artifact id: 9885107216
release: ytmusic-luna-queue-bit-ab-aligned-33734284316
APK: YouTube_Music_9.15.51_Luna_QUEUE_BIT_AB_ALIGNED.apk
SHA256: dc3b03ca6a91303e90fbbfd8607e4fa4771f3a3e304e14b10522ceaab0c1b2c8
signer SHA256: 7762ee243d1157ef3d6de884690ff70a385fc251fe8f491eb6c71f6a8e392e2c
```

初版 `eac6240b202c178dc689579f7c7500ddf5155506b2ddad7d783f62b0f7a9e8d9` 因 apktool rebuild 破壞 native `.so` ZIP alignment，導致：

```text
INSTALL_FAILED_INVALID_APK: Failed to extract native libraries, res=-2
```

該版本已退休；後續 `zipalign -P 16` 修正，21 個 stored native libraries 均 16K aligned。

Runtime A/B：

```text
actions=2604983
queueTitle=即將播放
queue size=25
```

`2604983 = 2600887 + 4096`，證明 `ACTION_SKIP_TO_QUEUE_ITEM` 已在實機生效。

結果仍為：

```text
播放列表 button -> 點擊完全無反應
```

結論：

> `queue non-empty + ACTION_SKIP_TO_QUEUE_ITEM` 不足以解鎖 Vivo OriginPlayer playlist。Queue-bit hypothesis 已 falsified，不再追加其他 MediaSession action bits。

## exact VivoMusicWidgetMix controller routing

既有 exact APK RE 已驗證 factory routing：

```text
custom-insert package -> controller/c0
framework-support package -> controller/o0
tv.danmaku.bili -> controller/g
otherwise -> controller/z2 generic
```

重要優先級：custom-insert 判定早於 framework-support。

`com.luna.music` 位於 framework-support list，因此目前 patched YT Music 在沒有 cooperation service 時會走：

```text
com.luna.music
  -> framework-support
  -> controller/o0
```

這可解釋為什麼 richer UI / lockscreen / island 全部正常，但 playlist affordance 不可用。

## Root cause：官方 Luna 不只靠 package identity

Official Luna 具有 vivo cooperation service，VivoMusicWidgetMix 會 query：

```text
Intent action: com.vivo.musicwidgetmix.support.service
```

當同 package 存在符合條件、可 bind 的 exported service 時，package 會被加入 runtime `custom_insert_music_white_list`，Vivo controller factory 因優先級改走：

```text
custom-insert -> controller/c0 / CooperateController
```

因此官方 Luna 真實路徑是：

```text
official Luna / com.luna.music
  + com.vivo.musicwidgetmix.support.service
  -> custom-insert classification
  -> controller/c0
  -> MediaBrowser cooperation protocol
  -> full functional playlist
```

而目前 patched YT Music：

```text
YT Music / com.luna.music
  - no vivo cooperation service
  -> framework-support only
  -> controller/o0
  -> richer UI but inert playlist
```

## controller/o0 的關鍵結論

對 exact `VivoMusicWidgetMix 6.2.7.1` 的 `o0` 進一步逆向顯示：

- `o0` 使用標準 MediaController / MediaSession 路徑支撐 richer controls；
- 沒有實作 custom-insert cooperation playlist browsing；
- 沒有等價於 `c0` 的 MediaBrowser list-loading / item-selection transport；
- 因此即使 YT Music MediaSession 已發布 25-item queue，Vivo UI 仍沒有可用的 `c0` list backend。

這是 queue-bit A/B 失敗的架構層原因。

## controller/c0 / Vivo cooperation playlist protocol

目前已逆出核心協議，不是 privileged Binder，也未見需要 platform signature 的證據。

VivoMusicWidgetMix 的 `c0` 會透過 `MediaBrowserCompat` 對 cooperation service 讀取 current list。

Browse parent ID：

```text
vivomusicmix_current_list
```

Paging option：

```text
vivomusicmix_key_media_page = <page>
```

Service 回傳：

```text
List<MediaBrowserCompat.MediaItem>
```

Vivo 至少讀每個 item 的：

```text
mediaId
title
artist
```

並從尾端 / paging metadata 使用：

```text
vivomusicmix_key_has_more
vivomusicmix_key_media_page
```

當使用者在 OriginPlayer playlist 選某一首，`c0` 取該 `MediaItem.mediaId` 並呼叫：

```text
MediaControllerCompat.TransportControls.playFromMediaId(
    mediaId,
    Bundle {
        "vivomusicmix_key_list" = "vivomusicmix_current_list"
    }
)
```

官方 Luna 的 controller callback 會處理 `onPlayFromMediaId(mediaId, extras)`，把該 playable ID 對應回其 real playback queue 並切換歌曲。

因此 playlist transport 的核心不是 `skipToQueueItem()`，而是：

```text
MediaBrowser current-list browse
  + stable MediaItem.mediaId
  + playFromMediaId(mediaId, vivo-list-extra)
```

## Official Luna cooperation evidence acquisition

為避免依賴猜測，已另外建立 narrow RE workflows 針對 official Luna：

```text
33749338695  Extract Luna Vivo protocol classes25
artifact 9890899253

33749573708  Extract Luna Vivo remote-control package
artifact 9890989720

33750258046  Locate Luna BasePlayerControllerService
artifact 9891242789

33750529313  Extract Luna PlayerService MediaBrowser implementation
```

另建立 JADX tool artifact 供 exact local APK analysis：

```text
run 33750642122
artifact 9891379337
JADX 1.5.6
```

## 已退休 / 不再優先的方向

以下不再作為 playlist 主線：

- MediaSession `ACTION_SKIP_TO_QUEUE_ITEM` action-bit patch；
- 繼續亂加其他 `PlaybackState.actions`；
- 單純增加 receiver / Bach event hook；
- 只靠 package identity 再換另一個 framework-support package；
- dummy service 但不實作真正 browse / playFromMediaId protocol。

## 下一顆 build 的最小目標

下一顆不是 action-bit A/B，而是 cooperation protocol prototype：

```text
YT Music 9.15.51
package = com.luna.music
existing ReVanced / Morphe patches unchanged
+
exported MediaBrowserService-compatible cooperation service
  action = com.vivo.musicwidgetmix.support.service
+
current-list browse bridge
  parentId = vivomusicmix_current_list
+
YT Music current queue -> MediaBrowserCompat.MediaItem list
+
playFromMediaId(mediaId, extras) -> 指定 YT Music queue item / playable ID
```

優先保持單變量原則：第一顆 cooperation prototype 先只回答「Vivo 是否改走 c0、playlist 是否由灰色 / inert 變成可開啟並列出歌曲」。若 browse 成功但選歌失敗，再把 `playFromMediaId` dispatch 分成第二階段定位。

## 當前判斷

可行性較 queue-bit 階段顯著提升，因為目前缺口已從「未知的 Vivo 私有 gate」收斂成可觀察的 Android `MediaBrowserCompat` cooperation protocol。

目前尚未看到下列硬阻擋證據：

```text
signature-level permission
platform signature requirement
privileged UID requirement
system UID requirement
不可重現的 private Binder token
```

因此下一步應直接做 cooperation service prototype；但在產出 APK 前，先把本 RE 與主狀態同步到 GitHub，GitHub 仍為專案 source of truth。
