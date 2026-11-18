# ChatGPT Library 清理稽核：Android 修改版 App 與 Y700 歷史產物

日期：2026-11-18（Asia/Taipei）。資料來源為當日 ChatGPT Library 檔案清單 + 專案 GitHub 實際相容性/發行資料 + 少量可合法提取的本機位元組 SHA-256。**這是盤點與清理提案，不是已完成刪除。**

## 可核對的整體統計

- 可列出的 Library：**3399 個檔案；19.617 GiB**（二進位 GiB；有些檔案可能未回報 size）。
- 以下四群總量（互不重疊）：紅果 13 份 3.012 GiB、YTM Luna 21 份 1.566 GiB、Y700 Display/Composer 61 份 1.314 GiB、boot MAGISK 5 份 0.938 GiB。
- 針對 Google Drive-backed Library，完整遞迴列出未被支援；這份計數僅針對實際可見範圍，不是官方儲存額度的唯一權威。

## 真正證實重複的檔案：可保留一份、提出刪另一份（**尚未執行**）

| 保留一份 | 另一份待刪候選 | 兩份 SHA-256（讀取原始位元組確認） | 單份容量 |
|---|---|---|---|
| `/红果免费短剧_7.3.9.32_去广纯净版.apk` | `/红果免费短剧_7.3.9.32_去广纯净版(1).apk` | `b5f3bac192aa534a62a748130ff9fdf1c1aa790eb1fba6624e9c113beb788ff4` | 244.2 MiB |

兩份來源的獨立 Library 項目都已成功提取並完整 hash；**此對才稱為 SHA-verified duplicate**。其他同名/等大仍只是 metadata duplication candidates，未做 bytewise 驗證。

## 已驗證內容與持久 GitHub Release：精確版本配對

| 成品 | 已驗證 SHA-256 | 真正對上的 GitHub Release（不是只猜相同名稱） |
|---|---|---|
| Instagram Piko R8 439.0.0.37.89 | `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8` | [Release 8](https://github.com/MeowGod8777/patched-apps/releases/tag/8)，Release asset digest 完全吻合 |
| Threads Chiggi R6 434.0.0.41.74 | `f263bc3baba23aca84cbf9a28b14a7d778dc33837531bd79303b6cd5e115e5d4` | [Release 6](https://github.com/MeowGod8777/patched-apps/releases/tag/6)，Release asset digest 完全吻合 |
| LINE Andrew R17 / 26.14.0 | `e6557f5daddb65d5bb92d75000bf6c29c7af95c5bfe0b28b9aa8446924ba70b1` | [line-mainpay-r17](https://github.com/MeowGod8777/patched-apps/releases/tag/line-mainpay-r17)，是存在的成品，**不能以此證實當前 26.15/26.16 日用** |
| LINE Andrew R18 / 26.16.0 | `04a619ad68a78e022b1ba2d0447dfea95484f6716c006adfc710e58f0ff0f16e` | [line-mainpay-r18](https://github.com/MeowGod8777/patched-apps/releases/tag/line-mainpay-r18)，**Release 存在不代表實測成功** |

特別注意：iQOO Luna 的最終 `V5_MEDIA_IDENTITY` 已有 [真機成功報告](https://github.com/MeowGod8777/patched-apps/blob/main/IQOO12PRO_YTMUSIC_V5_MEDIA_IDENTITY_RUNTIME_SUCCESS_2026-09-04.md)，SHA `547d7b1d31a68e32d273a770e4575f50fef6948246f984ae5d310ad0195b8427`，但**GitHub Releases 的 40 條當前可見記錄未列出這個最終檔案**；工作流程 artifact ID 也不是永久可取回保證。清理前一定先保留這份 APK 的持久原始位元組。

## 紅果 7.3.9.32：13 份／3.012 GiB

**結論：目前無法找回哪一顆真的安裝並日用成功。** 過往 `hg73932_nomodupdate_all3.apk` 的設計與 SHA 曾記錄，但 MT 安裝器出現 `binder haven't been received`，並無安裝 `Success` 證據；`retry`、`installfix` 不因為名稱就等於 final。不得將 8 個以修復命名的版本全標為已淘汰；這批優先以「取回源檔、同環境確認成功版、保留一份原始版」處理。

- `/Android App Patching/hongguo_no_mod_update_installfix.apk` — 244.3 MiB
- `/Android App Patching/hongguo_no_mod_update_installfix_retry2.apk` — 244.3 MiB
- `/Android App Patching/hongguo_no_mod_update_retry2.apk` — 244.3 MiB
- `/Android App Patching/红果免费短剧_7.3.9.32_去广纯净_去MOD强更.apk` — 244.3 MiB
- `/Android App Patching/hongguo_no_mod_update_retry1.apk` — 244.3 MiB
- `/Android App Patching/hongguo_no_mod_update_retry3.apk` — 244.3 MiB
- `/红果免费短剧_7.3.9.32_去广纯净_去MOD强更.apk` — 244.3 MiB
- `/红果免费短剧_7.3.9.32_去广纯净版(1).apk` — 244.2 MiB
- `/红果免费短剧_7.3.9.32_去广纯净版.apk` — 244.2 MiB
- `/Android App Patching/hg73932_nomodupdate_minimal.apk` — 244.2 MiB
- `/Android App Patching/hg73932_nomodupdate_all3.apk` — 244.2 MiB
- `/Android App Patching/hg73932_nomodupdate_allentries.apk` — 244.2 MiB
- `/红果短剧_7.3.5.32.apks` — 153.8 MiB

## Luna OriginPlayer：21 份／1.566 GiB

- **KEEP（唯一確認最終實機通過）**：`/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V5_MEDIA_IDENTITY.apk`，76.5 MiB。
- 其他 20 份（約 1.491 GiB）列作「歷史 probe/實驗可清候選」，**須先確保最終 V5 的離線實體已另存**。失敗調查需要保留時，可留差分研究紀錄而不留每顆 proprietary APK。
- 注意：此群只涵蓋 `/iQOO 12Pro修補/` 內 Luna 前綴；Library 根目錄另有 V4 等，同名等大仍需另外 hash 驗證。

- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V3_SELECTION_TIME.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V5_STATE_PROBE.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_PLAYABLE_MEDIAID_V5.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_REAL_QUEUE_V2.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V0.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V4N_RESULT_TRACE.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_SELECTION_TIME_V3R1.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_FULL_SUPPORT_EVENT_V6.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V4N_TRACE.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V5_SUPPORT_EVENT_9DF.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_BROWSER_PROBE_V1.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_BACH_RECEIVER_AB.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_SELECTION_V3S.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_NATIVE_MEDIAID_V4.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_NATIVE_MEDIAID_V4N.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_C0_V5_MEDIA_IDENTITY.apk` — 76.5 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_QUEUE_BIT_AB_ALIGNED.apk` — 76.1 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_EVENT_AB_ALIGNED.apk` — 76.1 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_VIVO_EVENT_AB.apk` — 76.1 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_iQOO12Pro.apk` — 76.0 MiB
- `/iQOO 12Pro修補/YouTube_Music_9.15.51_Luna_QUEUE_BIT_AB.apk` — 75.8 MiB

## Y700 Display / Composer：61 份／1.314 GiB

GitHub [stable 目錄](https://github.com/MeowGod8777/Lenovo-Y700-4th-ColorOS16/blob/main/external-display/stable/README.md) 已證實功能：DP QHD165、HDMI QHD120 裁切已解；但**最後完成裁切修復的完整原始腳本與 B3.5 完整版本仍待回收**。在未釘死最終運行成品前，不能將此 61 份 ZIP 全部刪除。檔名包含 `FINAL` 或 `STABLE` 只反映**當時歷史階段**，不代表最新日用版本。

- `/Flash and patch/Y700_Gen4_ColorOS16_External_Display_Lab_v1.7.0_ONE_FLASH_HOT_UPDATE_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_Display_Lab_v1.7.5_DMS_NATIVE_SAFE_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.6_HDMI_FRAMEWORK_SYNC_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.5_HDMI_POST_GEOMETRY_DIAG_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.4_HDMI_GEOMETRY_DIAG_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.2_GEOMETRY_DIAG_SWITCH_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_Display_Lab_v1.7.4_WORKBENCH_LIVE_SAFE_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.4.0_BYGLEE.zip` — 22.5 MiB
- `/Y700_Gen4_ColorOS16_External_QHD120_Unlock_v1.3.3_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD120_Unlock_v1.3.3_BYGLEE.zip` — 22.5 MiB
- `/Y700_Gen4_ColorOS16_External_QHD120_Unlock_v1.3.3_BYGLEE(1).zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_Display_Lab_v1.7.6_SF_EVENT_LOCK_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTSWAP_GUARD_120_v0.9D2.1_POSTHOLD_DEEP_READONLY.zip` — 22.5 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTSWAP_GUARD_120_v0.9D3P_4LANE_CONTROL_PROBE.zip` — 22.5 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_Display_Lab_v1.7.3_SAFE_ONESHOT_BYGLEE.zip` — 22.5 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTSWAP_GUARD_120_v0.9D1_HDMI_READONLY_DIAG.zip` — 22.5 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_QHD120_ONLY_HOTSWAP_v1.2_FINAL.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_QHD120_ONLY_HOTSWAP_v1.1.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_Display_Lab_v1.7.7_JAVA_SF_POLICY_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_QHD120_ONLY_HOTSWAP_v1.0.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.6.2_DISPLAYCONTROL_TOKEN_BRIDGE_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.6.1_SF_POLICY_JNI_BRIDGE_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.7_HDMI_FRAMEWORK_SYNC_BYGLEE(1).zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.7_HDMI_FRAMEWORK_SYNC_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.6.0_SF_POLICY_BRIDGE_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.3_HDMI_GEOMETRY_DIAG_BYGLEE.zip` — 22.4 MiB
- `/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.1_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.1_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.5.0_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.4.1_CAPTUREFIX_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.4.2_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.4.1_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD120_Unlock_v1.3.3_BYGLEE_log_redirect.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_Unlock_v1.4.0_MINPATCH_BYGLEE.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_SF_PROJECTION_WIREMAP_120_v1.8.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_QHD120_ONLY_HOTSWAP_v1.3.2_AUTO_LOWPOWER_HARDENED.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_ADAPTIVE_DISPLAY_LAB_120_v1.5.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_GEOMETRY_DIFFMAP_120_v1.7.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_QHD120_ONLY_HOTSWAP_v1.3.1_AUTO_LOWPOWER_SAFE.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_TRIPLE_LADDER_120_v1.6.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_NATIVE_PROJECTION_120_v1.4.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_CANVAS_CONVERGE_120_v1.1.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTSWAP_GUARD_120_v0.9D2_DEEP_READONLY_DIAG.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_CANVAS_SYNC_120_v1.0.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_PROJECTION_DIAG_120_v1.3.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_QHD120_ONLY_HOTSWAP_v1.3_AUTO_LOWPOWER.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_PROJECTION_PROBE_120_v1.2.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTSWAP_GUARD_120_v0.9.zip` — 22.4 MiB
- `/（DP、HDMI熱切換正常但畫面裁切版本）Y700_ColorOS16_Composer3_Frida17.16_HOTSWAP_GUARD_120_v0.9.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_DUALROUTE_120_v0.8.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HDMISCAN_2K120_v0.7.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTPLUG_DYNAMIC_2K120_v0.4.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_HOTPLUG_DYNAMIC_2K120_v0.4.1.zip` — 22.4 MiB
- `/Y700_ColorOS16_Composer3_Frida17.16_BRIDGE_2K120_v0.6.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_BRIDGE_2K120_v0.6.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_SESSION_SAFE_2K120_v0.5.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_DIRECT_2K120_v0.3.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_AUTO_2K120_v0.2.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_LOGONLY_v0.1.zip` — 22.4 MiB
- `/Flash and patch/Y700_ColorOS16_Composer3_Frida17.16_ONE_SHOT_2K120_v0.1.zip` — 22.4 MiB
- `/Flash and patch/Y700_Gen4_ColorOS16_External_QHD_DP165_HDMI120_FrameworkSync_v1.6.0_BYGLEE.zip` — 0.0 MiB

## Boot image：5 份／0.938 GiB — 保護項目

- 不可把版本編號較舊的 `boot` 視為垃圾，尤其原廠原始基線／已知可恢復的 boot／recovery。
- 刪除前須確認 exact device/ROM build、槽位、原始或修補身份、hash、至少一個可取回的離線備份。

- `/Flash and patch/boot_CURRENT_MAGISK_a_HeyCast_OPEX_V5.0.img` — 192.0 MiB
- `/boot_CURRENT_MAGISK_a.img` — 192.0 MiB
- `/Flash and patch/boot_CURRENT_MAGISK_a_HeyCast_OPEX_V5.1.img` — 192.0 MiB
- `/Flash and patch/boot_CURRENT_MAGISK_a_HeyCast_OPEX_V5.3_FINAL.img` — 192.0 MiB
- `/Flash and patch/boot_CURRENT_MAGISK_a_HeyCast_OPEX_V5.2.img` — 192.0 MiB

## 額外需保留的日用成果（不在前三群）

- [Android-Ad-Removal JMComic3](https://github.com/MeowGod8777/Android-Ad-Removal/blob/main/JMComic3/README.md)：靜態去廣告曾實機可看漫畫，但回首頁偶爾要重選線路；完整 patch recipe 未回收。Library 的 `JMComic3_NoAds`／`JMComic3_NoAds_V2` 仍需確認最後成功版。
- [Redmi Note 12 Turbo 合庫 App](https://github.com/MeowGod8777/Redmi-note-12Turbo-ColorOS16/blob/main/app-compatibility/tcb-bank.md)：2026-08-09 真機可登入／登出；以前使用者取得精簡修補包 `TCB_Ptrace_Policy_Fix_v1.1.1_Minimal.zip`，歷史回報 SHA `04870ea98644aea88231abc5b7d225e2c9bd951982567668780820ef93729c6c`，但這份**未在本輪重新讀取檔案 bytes 或驗證仍在 Library**，故只當歷史已知版本指標，不能據此聲稱完整可取回備份。
- 紅果沒有安裝成功回報；不要因為它佔用 3 GiB 就宣稱「已有穩定版可保留，其他都可刪」。

## 分批清理門檻與預估回收

| 優先順序 | 範圍 | 可能回收 | 前提與現況 |
|---|---|---:|---|
| 1 | 紅果 **確定 SHA 相同的 1 個根目錄副本** | 244.2 MiB | 另一份原檔確實存在，已校驗；待使用者批准刪除 |
| 2 | Luna 20 份歷史探針 | 約 1.491 GiB | **V5 先另外備份**；並接受歷史候選 APK 可丟棄 |
| 3 | 紅果其餘多個重試版本 | 在 3.012 GiB 群組中 | 尚不知哪版可用，不可批刪 |
| 4 | Y700 61 份歷史 ZIP | 最多涉及 1.314 GiB 群組 | 最終完整腳本與必要版本缺檔，先保留 |
| 保護 | boot/recovery 與唯一 raw 研究資料 | 不納入立即釋放目標 | 高還原風險 |

**目前刪除數量：0；已證實重複且可提出刪除的量：單份 244.2 MiB；其他數字只代表待核對候選容量。**

> 資安與著作權：公開 GitHub 僅上傳去識別 metadata／SHA／來源說明，不上傳第三方修改 APK 本體、私人日誌或專有 boot 映像。


## 2026-11-18 後續清理實績（本檔初次稽核之後，非覆寫原快照）

- **紅果根目錄 3 份：個人 Library `delete` 回報成功／移到垃圾桶**（兩個 `去广纯净版`／`去广纯净版(1)`，以及一個 `去广纯净_去MOD强更`）。再盤點確認已不在主 Library 清單。
- **紅果 `/Android App Patching/` 專案 9 份：delete 全部失敗**（`project_library_mutation_unsupported`），保留待 UI/專案管理處理。另有 `红果短剧_7.3.5.32.apks` 未列本批修改測試。
- **個人 Library 根目錄 AI 中間圖**：成功移除 16 個 `/image-gen-[數字].png` 及附有 `(n)` 的命名變體，合計 35,021,785 bytes／33.40 MiB；未觸碰具名圖片、原始照片、裝置截圖。
- **實際再查詢**：主 Library 3380 個檔案／18.86877 GiB；圖片 1638 個／501.47 MiB；`/待分類/` 164 張 AI 圖仍佔約 201.28 MiB，受 Project mutation 限制未刪。
- 新增完整跨領域遷移和清理規範：[ChatGPT Library → GitHub Runbook](https://github.com/MeowGod8777/Android-Root-Environment/blob/main/docs/CHATGPT_LIBRARY_MIGRATION_RUNBOOK_2026-11-18.md)。公共 repo 只留去識別成果／hash；不要公開原始對話與私密附件。
