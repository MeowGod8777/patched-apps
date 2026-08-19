# patched-apps — 這個 Fork 的繁中說明

Andrew `patched-apps` 的 fork，目前主要拿來 build LINE 模塊。

> 根目錄 upstream `README.md` / builder 文件保留原文，這份只說明我這個 fork 現在實際怎麼用。

## 先看這裡

### 這是什麼

這個 repo 主要負責：

> **把 Andrew 的 LINE patch 按目前需要的設定 build 成 module。**

LINE 實際日用結果、以前自己的修補、XML Guard、VGuard / security 相容性另外放 `LINE-Root-Patches`。

### 目前做到哪

**🟢 LINE 26.11.0 build workspace 目前可用，持續跟 LINE / upstream 維護。**

目前 config：

```text
version = 26.11.0
arch = arm64-v8a
build-mode = module
exclusive-patches = true
enable-module-update = false
```

只開 5 個 patch：

- `Hide ad views`
- `Remove banner ads`
- `Hide Home modules`
- `Disable VOOM`
- `Hide VOOM tab`

所以 Andrew upstream README 裡其他能力，**不代表本 fork 現在也有開。**

### 這裡跟 LINE repo 的差別

- **這裡**：build workspace / upstream sync / `config.toml`。
- **`LINE-Root-Patches`**：真正裝上去之後日用怎樣、以前自己的修補還要不要、版本副作用。

### Public repo 注意

這個 repo 是 Public。

自己的 signing key、token、CI secret、帳號資料不要進 Git history。

---

## 玩機／技術細節

### Build config

現在真正決定 LINE build 行為的是 `config.toml`，不是 upstream README 的完整 feature list。

目前：

```toml
version = "26.11.0"
arch = "arm64-v8a"
build-mode = "module"
exclusive-patches = true
enable-module-update = false
```

實際啟用：

- `Hide ad views`
- `Remove banner ads`
- `Hide Home modules`
- `Disable VOOM`
- `Hide VOOM tab`

### 更新時要看什麼

- LINE version。
- Andrew upstream patch 名稱／行為。
- workflow / builder 變動。
- `config.toml` 是否還能套。
- module 能不能 build / 安裝。
- 實機功能回歸。

upstream 寫「支援」不等於本 fork 有啟用；到底 build 了什麼以 config / patch source / commit 為準。

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
- `README.zh-TW.md`：本 fork 的中文狀態。
- `LINE-Root-Patches`：日用／相容性／以前自己的 LINE 修補。

### 待回收

看 `MIGRATION_BACKLOG.md`。

---

> **附註：** 內容由 AI 按指定格式上傳整理，有錯、缺漏或其他問題請直接私訊。
