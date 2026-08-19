# patched-apps 本地回收清單

這份只記這個 fork 自己要補的資料，不去改 Andrew upstream 原本的文件。

## LINE build

- [x] 目前 `config.toml` 的 5 個實際 patch 已整理。
- [ ] 每次 LINE / patch bundle 更新後，補 build commit、版本與回歸結果。
- [ ] 和 `LINE-Root-Patches` 對應的功能矩陣。
- [ ] build artifact 的版本命名／來源 commit 規則。

## 上游同步

- [ ] 記錄本 fork 相對 Andrew upstream 的本地變更。
- [ ] upstream 更新後先看 config / workflow / patch source 差異，再判斷要不要同步。

## 不放這裡

- LINE XML Guard source → `LINE-Root-Patches`。
- Root / PIF 共用處理 → 對應共用 repo。
- 私人 signing key、token、CI secret、帳號資料。

> **附註：** 內容由 AI 按指定格式上傳整理，有錯、缺漏或其他問題請直接私訊。
