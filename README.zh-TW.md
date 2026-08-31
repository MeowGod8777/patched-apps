# patched-apps — 這個 Fork 的繁中說明

Andrew `patched-apps` 的 fork，目前主要拿來 build LINE 模塊，以及 iQOO 12 Pro 非 Root 的 Instagram / Threads patched APK。

> 根目錄 upstream `README.md` / builder 文件保留原文，這份只說明我這個 fork 現在實際怎麼用。

## 先看這裡

### 這是什麼

這個 repo 目前主要負責：

> **把 Andrew / Piko / Chiggi 的 patch 按目前需要的設定 build 成 LINE module 與 Meta App 非 Root APK。**

LINE 實際日用結果、namespace mount、以前自己的修補、XML Guard、VGuard / security、Standalone LINE Pay 相容性另外放 `LINE-Root-Patches`。

### 進行時間

- Andrew upstream 本身有自己的歷史，**不把 upstream 的開發時間算成本 fork 的時間。**
- **本 fork 實際拿來做 LINE 26.11.0 module build／日用整理：2026-08 起。**
- **Instagram / Threads 非 Root build：2026-08-31 起。**
- 之後 LINE / upstream / Piko / Chiggi 更新就繼續沿用這條時間線。

### 目前做到哪

**🟢 LINE 26.11.0 build workspace 目前可用，持續跟 LINE / upstream 維護。**

目前 config：

```text
version = 26.11.0
arch = arm64-v8a
build-mode = module
include-stock = auto
enable-module-update = false
```

目前不是舊的 `exclusive-patches = true / 只開 5 個 patch` 配置，而是採 **Andrew default patches + exclusions**。

目前 exclusions：

- `Hide Wallet tab`
- `Hide Transfer button`
- `Keep chats unread`
- `Hide community button`
- `Fix push notifications`
- `Fix chat backup sign-in via GmsCore`

因此目前 build：

- 保留 Wallet tab。
- 保留聊天室 Transfer / LINE Pay button。
- 保留社群 button。
- 不開 `Keep chats unread`。
- **`Redirect LINE Pay` 目前有啟用。**
- Andrew 其餘 default patch 依 upstream 當前 default 狀態套用；不能再用舊文件的「只開 5 patch」描述。

### 目前實機 payload

2026-08-20 checkpoint：

```text
patched LINE base.apk SHA-256:
683853ceecac06964eac7703e5f02c47fd43ac3afbeba2f80630e614fbd14289
```

這顆已在實機確認真的進 LINE process，不只是 master namespace 看得到。

LINE Pay merchant `pay/payment/<reserveId>` redirect 也已實測能交給台灣獨立 LINE Pay App。Wallet / 好友轉帳的完整 standalone route 仍在 `LINE-Root-Patches` 繼續研究。

### iQOO 12 Pro：Instagram / Threads 非 Root APK

2026-08-31 checkpoint：目標是保留 Meta 官方 package name，不依賴 Root / BL unlock / LSPosed。

#### Instagram — Piko 3.9.0

```text
package: com.instagram.android
Instagram: 439.0.0.37.89
ABI: arm64-v8a
build-mode: apk
Release: 6
```

使用 `exclusive-patches = true`，目前只套指定的 12 個 patch：

- `Disable ads`
- `Copy comment`
- `Improve image viewing`
- `Hide suggested content`
- `Limit feed to following profiles`
- `Disable screenshot detection`
- `View DMs anonymously`
- `View stories anonymously`
- `View live anonymously`
- `Save deleted messages`
- `Make ephemeral media permanent`
- `Unlock Plus benefits`

GitHub Actions run `33370071676` 的 Morphe log 明確顯示 `Applying 12 patches...`，以上 12 項均逐項 `Applied:`，最後成功產出非 Root APK。

Release 6 artifact：

```text
instagram-piko-v439.0.0.37.89-arm64-v8a.apk
SHA-256: 06ca8cc521ff6576efb99f2d1f073428bbb6e78cba1dff9488768d3412a691e5
```

`Unlock Plus benefits` 只解 Piko 能找到的 **Instagram Plus 本機 entitlement check**。它不會建立真正的 Meta 訂閱，也不能保證通過伺服器端 entitlement / feature flag / rollout；因此「patch 套用成功」不能直接等同「所有 Instagram Plus 功能都可用」。

#### Threads — Chiggi 1.19.0

```text
package: com.instagram.barcelona
Threads: 434.0.0.41.74
ABI: arm64-v8a
build-mode: apk
Release: 6
```

目前只保留：

- `Hide ads`
- `Remove AD_ID permission`

刻意排除：

- `Change app name`
- `Change package name`

原因是要保留官方 `com.instagram.barcelona`，避免 clone package 破壞外部 intent / IG ↔ Threads 登入路徑。2026-08-31 已由實機回報目前 Threads 可正常使用。

Release 6 artifact：

```text
threads-chiggi-v434.0.0.41.74-arm64-v8a.apk
SHA-256: f263bc3baba23aca84cbf9a28b14a7d778dc33837531bd79303b6cd5e115e5d4
```

### 這裡跟 LINE repo 的差別

- **這裡**：build workspace / upstream sync / `config.toml` / IG & Threads APK build checkpoint。
- **`LINE-Root-Patches`**：真正裝上去之後 LINE 日用怎樣、namespace mount、以前自己的修補還要不要、LINE Pay / VGuard / Root 相容性。

### Public repo 注意

這個 repo 是 Public。

自己的 signing key、token、CI secret、帳號資料不要進 Git history。

---

## 玩機／技術細節

### Build config

現在真正決定 LINE build 行為的是 `config.toml`，不是 upstream README 的完整 feature list。

目前：

```toml
enable-module-update = false
parallel-jobs = 1

[LINE-Andrew]
app-name = "LINE"
patches-source = "andrewliang25/morphe-patches"
cli-source = "MorpheApp/morphe-cli"
rv-brand = "Andrew"
build-mode = "module"
version = "26.11.0"
arch = "arm64-v8a"
include-stock = "auto"
excluded-patches = """\
  'Hide Wallet tab' \
  'Hide Transfer button' \
  'Keep chats unread' \
  'Hide community button' \
  'Fix push notifications' \
  'Fix chat backup sign-in via GmsCore' \
  """
```

這代表：

- 不再維護一份手寫的「只開哪些 patch」清單。
- Andrew default patch 變動時要重新 review。
- exclusions 是目前刻意不套的功能。
- `Redirect LINE Pay` 沒有被 exclude，所以目前會套用。

### 更新時要看什麼

- LINE / Instagram / Threads target version。
- Andrew / Piko / Chiggi patch 名稱、版本與 default 行為。
- workflow / builder 變動。
- `config.toml` exclusions / allow-list 是否仍合理。
- module / APK 能不能 build / 安裝。
- patched artifact SHA-256 / provenance。
- LINE 實機 process namespace 是否真的看到 patched payload。
- LINE Pay / Wallet / Transfer / notification 等功能回歸。
- Instagram DM / call / Story / Plus local-gate 與 Threads login / external intent 的 runtime regression。

upstream 寫「支援」不等於本 fork 實機已驗證；到底 build 了什麼以 config / patch source / commit / payload 為準。

### Signing key

repo 裡現有：

- `ks.keystore`
- `ks-p12.keystore`

先前已比對過，和 Andrew upstream 同名檔案一致，屬 upstream 本來就公開追蹤的 build key，不是整理時誤加的私人 key。

但自己的正式 signing key 不要覆蓋／新增進 Public history。

`.gitignore` 另外擋：

- `.env`
- `local-secrets/`
- `*.jks`
- `*.p12`
- `*.pem`
- `*.key`
- `*.keystore`

既有 upstream tracked file 不會因 `.gitignore` 自己消失。

### 文件分工

- upstream `README.md` / `CONFIG.md` / `CONTRIBUTING.md`：保留 upstream。
- `README.zh-TW.md`：本 fork 的中文 build/config 狀態。
- `TEST_LEDGER.md`：build / provenance / config / 已回報 runtime checkpoint。
- `LINE-Root-Patches`：LINE 日用／namespace mount／相容性／以前自己的 LINE 修補／LINE Pay。
- `MIGRATION_BACKLOG.md`：舊資料／設定回收。

---

> **附註：** 內容由 AI 按指定格式上傳整理，有錯、缺漏或其他問題請直接私訊。