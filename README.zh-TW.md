# patched-apps — 這個 Fork 的繁中說明

Andrew `patched-apps` 的 fork，目前主要拿來 build LINE 模塊。

> 根目錄 upstream `README.md` / builder 文件保留原文，這份只說明我這個 fork 現在實際怎麼用。

## 先看這裡

### 這是什麼

這個 repo 主要負責：

> **把 Andrew 的 LINE patch 按目前需要的設定 build 成 module。**

LINE 實際日用結果、namespace mount、以前自己的修補、XML Guard、VGuard / security、Standalone LINE Pay 相容性另外放 `LINE-Root-Patches`。

### 進行時間

- Andrew upstream 本身有自己的歷史，**不把 upstream 的開發時間算成本 fork 的時間。**
- **本 fork 實際拿來做 LINE 26.11.0 module build／日用整理：2026-08 起。**
- 之後 LINE / upstream 更新就繼續沿用這條時間線。

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

### 這裡跟 LINE repo 的差別

- **這裡**：build workspace / upstream sync / `config.toml`。
- **`LINE-Root-Patches`**：真正裝上去之後日用怎樣、namespace mount、以前自己的修補還要不要、LINE Pay / VGuard / Root 相容性。

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

- LINE version。
- Andrew upstream patch 名稱／default 行為。
- workflow / builder 變動。
- `config.toml` exclusions 是否仍合理。
- module 能不能 build / 安裝。
- patched payload SHA-256。
- 實機 LINE process namespace 是否真的看到 patched payload。
- LINE Pay / Wallet / Transfer / notification 等功能回歸。

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
- `LINE-Root-Patches`：日用／namespace mount／相容性／以前自己的 LINE 修補／LINE Pay。
- `MIGRATION_BACKLOG.md`：舊資料／設定回收。

---

> **附註：** 內容由 AI 按指定格式上傳整理，有錯、缺漏或其他問題請直接私訊。