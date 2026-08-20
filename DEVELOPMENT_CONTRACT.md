# Development Contract — patched-apps

這個 repo 是 patch build workspace / upstream fork。核心要求是 **可重現 build、來源可追溯、runtime 驗證與 CI 分離**。

## Source of truth

`config.toml` + patch source revision + stock APK version/signature + CI commit/artifact > README feature description > runtime個案。

上游 README 說「支援某功能」不等於目前 config 一定有啟用；以實際 build config 與 patch list 為準。

## Build reproducibility

每次 release/build 至少保存：

- repo commit；
- stock app package/version/versionCode；
- stock source URL / mirror 與官方 signer verification；
- patch source/bundle revision；
- `config.toml` include/exclude；
- build mode / ABI / clone/module 設定；
- output SHA / provenance attestation；
- module/APK package identity。

## Upstream sync

上游更新與本地功能改動分開 commit。sync 後若 build/runtime regression，先 diff upstream change，不要同時改 config 來掩蓋問題。

## CI vs runtime

- CI build/pass/provenance 只證明 artifact 產出與來源鏈。
- App 能否啟動、module mount 是否進 consumer process、patch 功能是否正常，要在對應 runtime repo 驗證。
- LINE 的 Root/namespace/Pay 日用結果以 `LINE-Root-Patches` 為主，不在這裡重複下 runtime 結論。

## App-specific isolation

每個 app config entry 視為獨立 target。修改 LINE 不應讓 Instagram/Threads/YouTube 等無關 artifact 的 config 同步漂移，除非是明確的共用 build-engine 更新。

## Artifact discipline

成功 artifact 不只靠 latest release；重要日用 checkpoint 要保存 commit、SHA、provenance與 config snapshot，避免 upstream/daily rebuild 後無法還原。

## 安全 / 隱私

repo secrets、signing key、Telegram token/chat id 等不得進普通檔案或 log。自架 stock mirror 的來源/簽章驗證要保留，不以下載成功代替來源可信。
