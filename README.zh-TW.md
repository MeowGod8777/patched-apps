# patched-apps — 本 Fork 繁中說明

這個 repository 是由 Andrew 的 `patched-apps` 衍生／fork 出來的 patch build 工作區。為了降低之後同步 upstream 時的大量衝突，根目錄原本的 `README.md`、builder 說明與 upstream 文件**保留原文**，不整份翻譯覆寫。

## 這個 Fork 目前的用途

目前主要用來延續 LINE patch / build 流程。真正屬於本專案整理過的 LINE 行為差異、Root 相容性、XML Guard、版本風險與測試結論，集中放在另一個 repository：`LINE-Root-Patches`。

這樣分工可以避免：

- upstream 更新時，整份 README 因翻譯造成大量 merge conflict；
- 把 Andrew 的原始文件誤寫成本專案自己驗證的結論；
- LINE 專屬研究和通用 builder 混在一起，後續難以維護。

## 目前 `config.toml` 的實際 LINE build

目前本 fork 已核對的設定為：

- `version = "26.11.0"`
- `arch = "arm64-v8a"`
- `build-mode = "module"`
- `exclusive-patches = true`
- `enable-module-update = false`
- 只啟用以下 5 個 LINE patches：
  - `Hide ad views`
  - `Remove banner ads`
  - `Hide Home modules`
  - `Disable VOOM`
  - `Hide VOOM tab`

因此，Andrew upstream README 中列出的其他 LINE 能力，例如 Wallet / LINE TODAY 移除、keep chats unread、外部連結改走瀏覽器等，**不能直接視為目前這個 fork 已啟用的功能**。本 fork 的實際行為應以 `config.toml`、當次 build 與 `LINE-Root-Patches` 的驗證紀錄為準。

## 使用時要注意

- `patched-apps` upstream 文件中的功能與相容性，代表上游專案能力，不等於本 fork 目前 config 全部啟用。
- patched module 安裝成功，不代表所有功能都與原版一致。
- LINE 版本、patch bundle 或遠端配置更新後，需要重新驗證去廣告、Home、VOOM 與其他日用功能。
- 若本 fork 與 Andrew upstream 有差異，應先確認 `config.toml`、patch source、build workflow 與 commit，而不是只看 upstream README。
- signing key、token、CI secret 與帳號資料不要自行新增到公開 repository。

## Signing key 注意

此 fork 目前可看到的 `ks.keystore`、`ks-p12.keystore` 與 Andrew upstream 同名檔案一致，屬於上游本來就公開追蹤的 build key，不是這次整理時新增的私人 key。

但 repository 本身是 Public，因此**不要把個人／正式使用的 signing key 拿來覆蓋或新增進 Git history**。本 fork 的 `.gitignore` 已另外加入 `.env`、`local-secrets/`、`*.jks`、`*.p12`、`*.pem`、`*.key`、`*.keystore` 等規則，降低之後誤加私人憑證的風險；既有 upstream 已追蹤檔案不會因新增 `.gitignore` 而自動消失。

## 語言規則

本 fork 自己新增的說明與測試結論盡量使用繁體中文；upstream 原始 README、程式碼、config key、指令、package、patch 名稱與其他專有名詞維持原文。

---

> **附註：** 本專案的本地整理資料由 AI 透過 GitHub 外掛協助整理；若內容有誤、缺漏或其他問題，請私訊聯絡。
