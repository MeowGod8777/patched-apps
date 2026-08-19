# patched-apps — 本 Fork 繁中說明

這個 repository 是由 Andrew 的 `patched-apps` 衍生／fork 出來的 patch build 工作區。為了降低之後同步 upstream 時的大量衝突，根目錄原本的 `README.md`、builder 說明與 upstream 文件**保留原文**，不整份翻譯覆寫。

## 這個 Fork 目前的用途

目前主要用來延續 App patch / build 流程，尤其是 LINE 相關 patch 的建置與測試。真正屬於本專案整理過的 LINE 行為差異、Root 相容性、XML Guard、版本風險與測試結論，集中放在另一個 repository：`LINE-Root-Patches`。

這樣分工可以避免：

- upstream 更新時，整份 README 因翻譯造成大量 merge conflict；
- 把 Andrew 的原始文件誤寫成本專案自己驗證的結論；
- LINE 專屬研究和通用 builder 混在一起，後續難以維護。

## 使用時要注意

- `patched-apps` 中列出的功能與相容性，以實際 upstream patch、config、CI 結果和當前 App 版本為準。
- patched APK / module 的安裝成功，不代表所有功能都與原版一致。
- LINE patch 可能改變 Wallet / LINE Pay、VOOM、首頁模組、已讀／seen、收回訊息、外部連結與其他附加功能；實際行為應回到 `LINE-Root-Patches` 的版本化紀錄確認。
- 若本 fork 與 Andrew upstream 有差異，應先確認 `config.toml`、patch source、build workflow 與 commit，而不是只看 upstream README。
- signing key、token、CI secret 與帳號資料不要自行新增到公開 repository。

## 語言規則

本 fork 自己新增的說明與測試結論盡量使用繁體中文；upstream 原始 README、程式碼、config key、指令、package、patch 名稱與其他專有名詞維持原文。

---

> **附註：** 本專案的本地整理資料由 AI 透過 GitHub 外掛協助整理；若內容有誤、缺漏或其他問題，請私訊聯絡。
