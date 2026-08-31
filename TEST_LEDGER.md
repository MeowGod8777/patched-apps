# Test Ledger — patched-apps

這裡主要記 **build / provenance / config checkpoint**；若本 repo 的 APK 已有直接實機回報，也會只記最小 runtime 結論。更深入的裝置功能與 namespace runtime 結果仍放對應專案 repo。

| ID | Baseline | Build / config | 結果 | 結論 | 狀態 |
|---|---|---|---|---|---|
| BUILDER-UPSTREAM | j-hc/revanced-magisk-module based build engine | CI / module / APK build | repo 可持續產出多 App artifact | build engine 是共用依賴；sync 與本地 config 分開追 | ACTIVE |
| STOCK-SIGNATURE | 各 target stock APK | `sig.txt` / official signer verification | build 流程會驗 stock signer | 下載成功不等於來源可信；簽章是 gate | FROZEN methodology |
| PROVENANCE | GitHub Actions release | artifact attestation | release artifact 有 build provenance | provenance 只證明 CI/source chain，不證明 runtime 功能 | FROZEN methodology |
| LINE-26.11 | LINE 26.11.0 / arm64-v8a / module | Andrew patch config；目前保留 default patch 並排除指定項目 | module 可 build；runtime mount/Pay/功能結果另見 LINE-Root-Patches | config snapshot 必須與 runtime checkpoint 對應 | ACTIVE target |
| IG-Piko-R5 | Instagram 439.0.0.37.89 / Piko 3.9.0 | non-root APK；official package；`Disable ads` only | build PASS，舊版功能基線 | 已由 Release 6 擴充取代 | SUPERSEDED |
| IG-Piko-R6 | Instagram 439.0.0.37.89 / Piko 3.9.0 / arm64-v8a | `exclusive-patches=true`；12 項 explicit allow-list；run `33370071676` | Morphe log：`Applying 12 patches...`，12/12 均 `Applied:`；artifact SHA-256 `06ca8cc521ff6576efb99f2d1f073428bbb6e78cba1dff9488768d3412a691e5` | build/provenance PASS；`Unlock Plus benefits` 僅代表 local entitlement hook，不能推論全部 Plus server feature 可用 | SUPERSEDED by R7/R8 |
| IG-Piko-R7 | Instagram 439.0.0.37.89 / Piko 3.9.0 | R6 + `Add settings` + `Unlock developer options` | build PASS；MetaConfig / developer-option 診斷入口可用 | HDR flags 可被觀察/override，但多項強制 HDR flags 未恢復 12 Pro HDR | SUPERSEDED by R8 |
| IG-Piko-R8 | Instagram 439.0.0.37.89 / Piko 3.9.0 / arm64-v8a | R7 + `Validate links`; run `33386913460` | build PASS；artifact SHA-256 `4015b171ac59f3e7172134d194ec2dcf701f64c3339f127c19d7a04c13d529c8`；使用者實機確認 browser / explicit IG deep link 均可直達內容 | `Validate links` 命中重新簽章後的 external/deep-link signature handling；HDR 仍 unresolved | ACTIVE confirmed baseline |
| IG-HDR-V2329A | iQOO 12 Pro / V2329A / Android 16 | vivo XDR framework reverse engineering | YouTube HDR positive control `hdrSdrRatio > 1`; IG remains `1.0`; vivo framework confirms `xdr v3.0`, `xdr_video app_hdr=true`, `AppHdrController` + SurfaceFlinger HDR-layer listener path | 目前未見 Instagram 被 vivo native-HDR package whitelist 排除；主嫌疑轉向 IG HDR rendition/device eligibility 或 HDR layer metadata/presentation | ACTIVE research; see `research/instagram_hdr_vivo_xdr.md` |
| THREADS-Chiggi-R6 | Threads 434.0.0.41.74 / Chiggi 1.19.0 / arm64-v8a | official `com.instagram.barcelona`；`Hide ads` + `Remove AD_ID permission`；排除 package/name clone | build PASS；使用者 2026-08-31 回報 Threads 目前可用 | 保留官方 package 是目前可用 baseline；不再回退 clone package | ACTIVE confirmed baseline |

## Instagram Piko Release 6 allow-list

```text
Disable ads
Copy comment
Improve image viewing
Hide suggested content
Limit feed to following profiles
Disable screenshot detection
View DMs anonymously
View stories anonymously
View live anonymously
Save deleted messages
Make ephemeral media permanent
Unlock Plus benefits
```

## 新 build ledger 必填

commit、target package/version、stock signer、patch source revision、config diff、build mode/ABI、artifact SHA/provenance、是否需要對應 runtime regression。
