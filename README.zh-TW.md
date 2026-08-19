# patched-apps — 這個 Fork 的繁中說明

這個 repo 是從 Andrew 的 `patched-apps` fork 出來，現在主要拿來 build LINE patch。

根目錄原本的 `README.md`、builder 說明和 upstream 文件不整份翻掉，因為之後同步 upstream 只會一直撞 merge conflict。自己這邊的說明就放這份。

## 這個 Fork 現在拿來幹嘛

主要就是延續 LINE patch / build。這裡負責「怎麼 build」；LINE 實際改了什麼、Root 相容性、XML Guard、版本差異和日用結果，另外整理在 `LINE-Root-Patches`。

## 目前進度

**狀態：目前 LINE 26.11.0 build 工作區可用，持續跟 upstream／LINE 版本維護。**

目前已經做到：

- `config.toml` 明確鎖 LINE `26.11.0`、`arm64-v8a`、`module`。
- `exclusive-patches = true`，只開需要的 5 個 LINE patch，不吃 Andrew 全套功能。
- build 產物已實際安裝使用，這套配置目前可正常日用。
- upstream 原始 README / workflow 保留，自己新增的繁中說明和安全規則另外放，後面比較好同步。

還要持續注意：

- LINE 一更新版本，patch 是否還能套、功能有沒有副作用都要重測。
- upstream patch 名稱／行為變動時，`config.toml` 要重新核對。
- 這是 Public repo，自己的 signing key、token、CI secret、帳號資料不能進 history。

所以這不是「已經做完永久不動」，也不是無解放棄；它是**目前版本可用的 build workspace**。

## 現在 `config.toml` 真正有開的 LINE patch

目前設定：

- `version = "26.11.0"`
- `arch = "arm64-v8a"`
- `build-mode = "module"`
- `exclusive-patches = true`
- `enable-module-update = false`

只開這 5 個：

- `Hide ad views`
- `Remove banner ads`
- `Hide Home modules`
- `Disable VOOM`
- `Hide VOOM tab`

所以 Andrew upstream README 裡寫的 Wallet / LINE TODAY、keep chats unread、外部連結改瀏覽器等功能，**不要直接當成現在這個 fork 也有開**。

到底 build 了什麼，看 `config.toml`；到底日用起來怎樣，看 `LINE-Root-Patches`。

## 更新後要注意

- upstream 寫的是它能做什麼，不代表本 fork 全開。
- module 裝成功，也不代表 LINE 所有功能都跟原版一樣。
- LINE 版本、patch bundle、遠端配置有改，就重新測廣告、Home、VOOM 和日用功能。
- 跟 upstream 對不上時，先看 `config.toml`、patch source、workflow 和 commit，不要只看 README。
- token、CI secret、帳號資料、自己的 signing key 不要丟進 Public repo。

## Signing key

現在 repo 裡的 `ks.keystore`、`ks-p12.keystore` 跟 Andrew upstream 同名檔案一致，是 upstream 本來就公開追蹤的 build key，不是這次整理時加進去的私人 key。

但這個 repo 是 Public，**不要拿自己的正式 signing key 去覆蓋或新增進 Git history**。

`.gitignore` 已另外擋 `.env`、`local-secrets/`、`*.jks`、`*.p12`、`*.pem`、`*.key`、`*.keystore`。原本 upstream 已經 tracked 的檔案不會因為加 `.gitignore` 自己消失。

自己新增的說明用繁中；upstream README、程式碼、config key、指令、package、patch 名稱保留原文。

---

> **附註：** 內容由 AI 按指定格式上傳整理，有錯、缺漏或其他問題請直接私訊。
