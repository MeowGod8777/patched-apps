# 已驗證日用 App／修補成品與保留指引（2026-11-18）

> **用途**：整理使用者曾在真機實測的 patched App／相容性修復。不是最新 release 清單、APK 檔案倉庫，也不是下載／刪檔已完成的證明。以各裝置專案原始測試紀錄為證據。建立日期 2026-11-18；歷史實測日期不得誤寫為今日重新驗證。

## 判定規則

- **DEVICE PASS／歷史可日用**：有使用者的真機結果；只對指定 app 版本、機型、ROM、安裝方式及測過的功能成立。
- **CONDITIONAL PASS**：功能已實現，但仰賴特定 Root／模組／bind mount／安裝條件；不可把單顆 APK 宣稱為即裝即用。
- **BUILD PASS ONLY**：只完成產物、簽章或離線分析，尚不能視為已驗證日用。
- **REGRESSION／FAILED／UNKNOWN**：不得為了清理 Library 將其升格為穩定版本。
- GitHub 的 source、測試紀錄、commit、SHA、CI artifact 指標 **不等於持久保存 APK／ZIP 位元組**。刪除 ChatGPT Library 之前，須在使用者可存取且已校驗的獨立位置確認實體備份。

## A. 已有實機通過紀錄的 patched App

| App／用途 | 經證實的基線 | 真機結論與範圍 | 成品識別／保存判定 | 既有證據 |
|---|---|---|---|---|
| YouTube Music／OriginPlayer | iQOO 12 Pro V2329A；Android 16／OriginOS；Luna 9.15.51；`com.luna.music`；`YouTube_Music_9.15.51_Luna_VIVO_C0_V5_MEDIA_IDENTITY.apk` | **DEVICE PASS（2026-09-04）**：清單、目前／後續歌曲、點選切歌、封面與歌名歌手更新、時間／進度均正常 | SHA-256 `547d7b1d31a68e32d273a770e4575f50fef6948246f984ae5d310ad0195b8427`；保留最終 V5 binary，勿用 V2/V3/V4/V4N/TRACE 等探針取代 | [iQOO12Pro 修補狀態](IQOO12PRO_PATCH_STATUS.zh-TW.md)、[V5 runtime](IQOO12PRO_YTMUSIC_V5_MEDIA_IDENTITY_RUNTIME_SUCCESS_2026-09-04.md) |
| Instagram／Piko R8 | V2329A；IG 439.0.0.37.89；Piko 3.9.0；原 `com.instagram.android`；非 Root APK | **DEVICE PASS（R8 既有基線）**：安裝、瀏覽器／外部 IG deep link 導航已驗證；不能推出 12 Pro IG HDR 恢復或所有 Plus server entitlement 生效 | R8 SHA-256 `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`；Library 看到的原版 XAPK **不是** R8 備份 | [TEST_LEDGER.md](TEST_LEDGER.md)、[IG HDR 歷史 RE](research/instagram_hdr_status_2026-09-02.md) |
| Threads／Chiggi R6 | V2329A；Threads 434.0.0.41.74；Chiggi 1.19.0；原 `com.instagram.barcelona`；非 Root APK | **DEVICE PASS（2026-08-31）**：使用者回報可用；後續外部 App 的 Threads 連結跳轉問題已結案 | R6 SHA-256 `f263bc3baba23aca84cbf9a28b14a7d778dc33837531bd79303b6cd5e115e5d4`；只代表當時版本，不保證今日 Meta 更新相容 | [TEST_LEDGER.md](TEST_LEDGER.md)、[iQOO12Pro 修補狀態](IQOO12PRO_PATCH_STATUS.zh-TW.md) |
| LINE／Andrew non-root + MicroG-RE | V2329A；LINE 26.11.0；Andrew patches；Morphe MicroG-RE 6.1.4 `app.revanced.android.gms` | **DEVICE PASS（2026-08-31）**：聊天／去廣、Google picker、Note 12 Turbo → Drive → 12 Pro 聊天復原、YouTube ReVanced 共用 GmsCore；保留獨立 LINE Pay 跳轉 | 這是 **歷史 non-root 日用方案**，不得逕稱目前 LINE 26.15.0／臨時 Root 的同一版本／同一修補狀態 | [LINE-Root-Patches 相容性](https://github.com/MeowGod8777/LINE-Root-Patches/blob/main/COMPATIBILITY.md)、[nonroot 結案](https://github.com/MeowGod8777/LINE-Root-Patches/blob/main/nonroot-12pro/README.md) |
| YouTube ReVanced + MicroG-RE | iQOO 12 Pro；與上述 LINE 共用 Morphe MicroG-RE 6.1.4 | **DEVICE PASS（2026-08-31）**：YouTube 播放正常，無需第二套專用 MicroG | 沒有此輪核實的 APK 檔名／SHA，先記 runtime，不得據此任刪候選 APK | [LINE-Root-Patches](https://github.com/MeowGod8777/LINE-Root-Patches/blob/main/README.md) |
| Origin Isle／SuperX | iQOO 12 Pro；Origin Isle 1.4.0（2026-09） | **DEVICE PASS**：Google Maps、YouTube、Bilibili、Sample cards 上島；通話功能未驗證 | 不是所有 `origin-isle-*-diag.apk` 探針都等於最終安裝版；保留可重建來源與當時有效的實體包 | [iQOO12Pro 修補狀態](IQOO12PRO_PATCH_STATUS.zh-TW.md) |

## B. 有條件成功／裝置工具

| 工具／修補 | 對應條件與結論 | 不能誤解為 |
|---|---|---|
| MapsMaxFPS | Y700 四代 ColorOS 16 的 **v0.1** 已真機生效（換新版 Google Maps 後）；V2329A 有後續 **v0.3** 真機成功回報；應各自按機型與 Google Maps 版本保存 | 對所有 Maps 版本、所有機型通用 |
| i 主題本地字體整合 | V2329A：i 主題 20.5.8.1 經 Core Patch／LSPosed／zygote bind mount 組合後，已成功匯入並使用本地字體 | 單獨安裝 Library 中任何一顆 `iTheme_*fixed*.apk` 就必然成功；目前沒有釘死最終 APK hash |
| Y700 ColorCTS | Y700 四代 ColorOS 16：ColorCTS v1.0.0 底部手勢條長按叫出 Google Circle to Search，實機日用通過；MiCTS direct 是 fallback | OShin 自訂長按／Oplus-Assistant-Hook 也已通過 |
| Y700 外接顯示 | DP 2560×1440@165Hz、HDMI 2560×1440@120Hz 滿版已實測通過；目前**沒有在這份總表釘死唯一可重刷的 ZIP hash** | Library 中 61 份 display/composer 測試 ZIP 均穩定可用；先核對裝置 repo 最終成品再淘汰實驗版 |

裝置工具的詳細日用條件以 [Lenovo-Y700-4th-ColorOS16 CURRENT_STATUS](https://github.com/MeowGod8777/Lenovo-Y700-4th-ColorOS16/blob/main/CURRENT_STATUS.md) 與 [iQOO12Pro 修補狀態](IQOO12PRO_PATCH_STATUS.zh-TW.md) 為準。

## C. 不列入已驗證日用的常見候選

- **Y700 YouTube Music 9.15.51 root module**：有 BUILD PASS／產物紀錄，不能據此代替真機長期回歸。[Build checkpoint](Y700_YTMUSIC_GENERIC_ROOT_BUILD_CHECKPOINT_2026-09-04.md)
- **12 Turbo 的 LINE 26.11.0 Andrew root module + mount shim**：一度進 LINE process，但後續 process respawn 發生 namespace mount regression；不得以早期一次 PASS 宣稱穩定。[相容性矩陣](https://github.com/MeowGod8777/LINE-Root-Patches/blob/main/COMPATIBILITY.md)
- **V2329A LINE 26.15.0／臨時 Root／Andrew R17**：有近期實際使用和修補討論，但這份 catalog 尚缺同一 APK、patch 與 Runtime hash 的完整釘版；列 **待確認**，不是沿用 26.11.0 的 SHA。
- **紅果短劇 7.3.9.32** 多個 `retry`／`installfix`／`minimal` APK、**HapticBounce** 各候選、**HiBoard Widget Bridge** 測試包：檔名／build 存在不等於安裝與功能通過。先查真機驗收紀錄再選最終版。
- **LiquidVivo**：V2329A 曾發生軟重啟後黑屏／卡頓或耗電影響，使用者排除後恢復；不能列穩定日用。
- **Play Integrity / Wallet NFC**：Root 裝置上 Wallet 曾顯示不符合安全裝置；線上付款與 Samsung Pay 可用不能推論 NFC Wallet 通過。
- **L22 充電加速模組**：尚無安全可還原且實測可加速的正式可日用版本。[CURRENT_STATUS](https://github.com/MeowGod8777/iQOO-12Pro-Temporary-Root-Research/blob/main/CURRENT_STATUS.md)

## D. ChatGPT Library 清理與 GitHub 保存界線

- 2026-11-18 metadata 盤點發現：紅果短劇相關 APK／APKS **13 份約 3.01 GiB**；iQOO YouTube Music Luna 中間 APK **21 份約 1.57 GiB**；Y700 external display/composer 實驗 ZIP **61 份約 1.31 GiB**。**這是候選族群總量，不是安全可刪容量，也不是已校驗重複位元組。**
- 清理順序：先確認最新版實體與可重建來源、SHA-256、安裝／依賴條件，再考慮刪過程 probe／retry、重複上傳副本；Boot、recovery、校驗前的原始系統檔需額外備份。
- GitHub 這次**只保存清單／可重現資訊／歷史結論**，不提交第三方專有 APK、私有 Google／LINE 資料、root 權限擷取的私密 dump、付費內容、個人 keystore 或大型 boot 映像。
- `sha256sum <file>` 才能確認位元組相同；僅同名、同大小不足以判定重複。
- 若 CI artifact 已到期或來源失效，GitHub 的 hash 不能取回原 APK。保留至少一份離線實體後才清 Library。

## 下一輪待補欄位

- 每個已實機確認版本的 **實際 downloadable artifact URL／原始檔本體位置／SHA** 與回歸日期。
- Y700 DP／HDMI 最後實裝模組 ZIP hash；V2329A iTheme 最後實裝版 hash。
- LINE 26.15.0 現役 APK、Android Root profile、patch source revision、LINE Pay 日用回歸。
- 「今天仍裝著」與「過去曾可日用」分欄維護，避免用舊日期替代現況。


## 後續實體備份核對（同日第二輪）

- **[完整 3,399 檔清理稽核與三大候選族群逐檔名單](research/LIBRARY_CLEANUP_TRIAGE_2026-11-18.md)**：紅果 13 份／3.012 GiB、Luna 21 份／1.566 GiB、Y700 顯示 61 份／1.314 GiB，另保護 boot 5 份／0.938 GiB。
- **已證實的相同位元組**：`/红果免费短剧_7.3.9.32_去广纯净版.apk` 與同名 `(1)` 根目錄副本，SHA-256 均為 `b5f3bac192aa534a62a748130ff9fdf1c1aa790eb1fba6624e9c113beb788ff4`；保留一份可提議刪另一份（約 244.2 MiB），**未執行刪除**。
- **Instagram Piko R8（2026-08-31）**：歷史實測 SHA 與 [Release 8](https://github.com/MeowGod8777/patched-apps/releases/tag/8) asset digest `4015b171…d529c8` 一致，為可取回的確切版本；不要以後續同名 Release 9–12 取代它並宣稱未變更。
- **Threads Chiggi R6**：歷史實測 SHA 與 [Release 6](https://github.com/MeowGod8777/patched-apps/releases/tag/6) asset digest `f263bc3b…e115e5d4` 一致，後續同名 Release digest 不同，不能只憑名稱判定完全相同。
- LINE [R17 / 26.14.0](https://github.com/MeowGod8777/patched-apps/releases/tag/line-mainpay-r17) 與 [R18 / 26.16.0](https://github.com/MeowGod8777/patched-apps/releases/tag/line-mainpay-r18) 確認有 Github Release ZIP，但 R18 **未因發布而升格為使用者日用 PASS**。
- 最終 **YouTube Music `V5_MEDIA_IDENTITY` 仍無可核實的 GitHub Release 長期成品**；雖有 workflow build 與成功 log，務必保留當前 Library 最終原始 APK，直到獨立備份並檢查 SHA。
- 紅果 `all3` 與 `installfix` 等，未找回真正成功安裝與日用證據；**不是「只留最新，其餘皆可刪」**。
- Y700 外接顯示穩定功能成立，但完整最後的 HDMI crop-fix / B3.5 原始成品仍未在 GitHub 釘版，**不可先批量刪掉 61 顆候選 ZIP**。

