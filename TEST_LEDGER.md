# Test Ledger — patched-apps

這裡只記 **build / provenance / config checkpoint**。裝置上的功能與 namespace runtime 結果放對應專案 repo。

| ID | Baseline | Build / config | 結果 | 結論 | 狀態 |
|---|---|---|---|---|---|
| BUILDER-UPSTREAM | j-hc/revanced-magisk-module based build engine | CI / module / APK build | repo 可持續產出多 App artifact | build engine 是共用依賴；sync 與本地 config 分開追 | ACTIVE |
| STOCK-SIGNATURE | 各 target stock APK | `sig.txt` / official signer verification | build 流程會驗 stock signer | 下載成功不等於來源可信；簽章是 gate | FROZEN methodology |
| PROVENANCE | GitHub Actions release | artifact attestation | release artifact 有 build provenance | provenance 只證明 CI/source chain，不證明 runtime 功能 | FROZEN methodology |
| LINE-26.11 | LINE 26.11.0 / arm64-v8a / module | Andrew patch config；目前保留 default patch 並排除指定項目 | module 可 build；runtime mount/Pay/功能結果另見 LINE-Root-Patches | config snapshot 必須與 runtime checkpoint 對應 | ACTIVE target |
| IG-Piko | Instagram Piko | clone APK only | module 因 settings/runtime 問題已 dropped | 不把 APK 成功推成 module 可用 | FROZEN product decision |
| THREADS-Chiggi | Threads | De-Vanced → Chiggi | package/patch source 已改 | 舊 clone 不能當直接升級 artifact | FROZEN migration fact |

## 新 build ledger 必填

commit、target package/version、stock signer、patch source revision、config diff、build mode/ABI、artifact SHA/provenance、是否需要對應 runtime regression。
