# iQOO 12 Pro / YT Music c0 probe low-register staging checkpoint

更新：2026-09-03 20:16 +08:00

本檔承接：

- `IQOO12PRO_YTMUSIC_LUNA_COOPERATION_RE_2026-09-03.md`
- `IQOO12PRO_YTMUSIC_EXISTING_MEDIABROWSER_BRIDGE_PLAN_2026-09-03.md`
- checkpoint commit `6a9ea40bc77f88f5a31ab75341ac29919a94f75c`

唯一產品目標仍是修復 iQOO 12 Pro / OriginOS 6 上 patched YouTube Music 的 OriginPlayer「播放列表」按鈕點擊無反應。`c0 / MediaBrowser cooperation bridge` 只是實作手段。

## 已確認 failure

上一個 builder run：

```text
33753312578
job 100641676540
```

已確認以下 injection 均命中：

```text
support.service manifest injection   PASS
VIVO_MUSIC_MIX_ROOT                 PASS
vivomusicmix_current_list hook      PASS
vivo_probe_1 MediaItem              PASS
```

Apktool rebuild 第一個 failure：

```text
MusicBrowserService.smali[768,4]
Invalid register: v19. Must be between v0 and v15, inclusive.
```

根因是 injected ordinary `invoke-*` 使用 35c encoding，但原 method 的 `p1/p2` 因高 register-count 映射到 `v16+`。這是純 smali register encoding failure；不是 protocol、descriptor、class 或 Vivo cooperation hypothesis failure。

## 下一顆候選的 exact register 修法

### onGetRoot / `f(String, Bundle) -> Lbze;`

禁止再直接：

```smali
invoke-virtual {v0, p1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
```

改成先 staging：

```smali
const-string v0, "com.vivo.musicwidgetmix"
move-object/from16 v1, p1
invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
```

後續仍可重用 `v1` 建立 `VIVO_MUSIC_MIX_ROOT`，因 client package 比較完成後 staged value 已無生命週期需求。

### onLoadChildren / `b(String, Lbzu;, Bundle) -> void`

需要同時消除 injected 35c 對 `p1` 與 `p2` 的直接引用。

入口 staging：

```smali
move-object/from16 v3, p1
move-object/from16 v4, p2
```

parent id 判斷改用：

```smali
invoke-virtual {v3, v0}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
```

`v3` 在 contains 完成後即可重用為 `MediaBrowserCompat$MediaItem`。

`v4` 必須保留 staged `Lbzu;` 到最後 result callback，因此 MediaItem flags 不再使用 `v4`，改用已完成 builder 工作後可重用的低 register `v1`：

```smali
new-instance v3, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;
const/4 v1, 0x2
invoke-direct {v3, v2, v1}, Landroid/support/v4/media/MediaBrowserCompat$MediaItem;-><init>(Landroid/support/v4/media/MediaDescriptionCompat;I)V

invoke-virtual {v0, v3}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z
invoke-virtual {v4, v0}, Lbzu;->c(Ljava/lang/Object;)V
```

此配置維持 `min_locals=5`，不為了 staging 額外增加 locals，也避免因提高 locals 使 parameter physical register 再向上偏移。

## 下一步驗證鏈

修改 patcher 後只接受以下完整結果：

```text
patch injection
-> Apktool rebuild
-> zipalign -P 16
-> stored native library alignment verification
-> same signer verification
-> final zipalign check
-> package/version verification
-> manifest support.service verification
-> MusicBrowserService static smali marker verification
```

若 rebuild 出現下一個錯誤，先記錄實際 error / root cause / next step 到 GitHub，再產生下一顆候選；不退回重做已反證的 MediaSession action-bit 路線。

第一顆 probe 仍不加入 real queue 或 `playFromMediaId`，保持單變量，只驗證 `support.service -> custom-insert/c0 -> MediaBrowser bind -> vivomusicmix_current_list -> vivo_probe_1` transport。
