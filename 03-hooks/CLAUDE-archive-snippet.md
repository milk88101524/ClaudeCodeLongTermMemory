# Cross-session history（SQLite archive）

所有 Claude Code 的 session JSONL 每 15 分鐘會由 `crs`（launchd 排程）收進 `~/claude-archive/sessions.db`，
內容是所有專案、所有 session 的逐字紀錄：使用者訊息、回覆、工具的輸入與輸出。

**這台電腦裝的是 SQLite 版，沒有 `osearch`。** `vsearch` 和 `csearch` 就是完整的查詢工具。

## 什麼時候要查
- 使用者問到過去 session 的事 → 先查 archive，不要直接說「不記得」
- 接續中斷的工作 → 查該專案最近的 session
- 追查設定什麼時候改過 → 過去的工具呼叫和結果就是一手資料
- 要翻 log、讀 memory 檔、用 sqlite3 查 DB 之前 → 先查 archive，答案常常已經在裡面

## 用哪個指令
| 想找的東西 | 指令 |
|---|---|
| 模糊描述、概念、中英對照（「上次那個 X 怎麼設的」） | `vsearch '<描述>' [project]`（預設） |
| 確切的字串：IP、主機名、檔案路徑、已知的句子 | `csearch '<關鍵字>' [project]`（新的在前） |

- 含 `.` `/` `:` `-` 的字串，在 csearch 要加雙引號：`csearch '"192.168.1.1"'`
- 把回傳的結果都看完，答案常常在第 2～4 筆，不一定是第 1 筆

## Hook 的規則（`archive-preflight.sh`）
- 跑過 `vsearch` 或 `csearch` 之後 30 分鐘內，才能：用 sqlite3 查 metadata、讀 memory 資料夾的 .md（`MEMORY.md` 除外）、grep log、`git log --grep`
- 用 sqlite3 做內容搜尋（LIKE / MATCH / msg_fts / GLOB）一律被擋 → 改用 `csearch`
- 被擋的訊息會叫你「run OSEARCH first」：這台沒有 osearch，請改跑 `vsearch` 或 `csearch`，不要嘗試繞過 hook

## 自動帶入的內容
- 開新 session 時，SessionStart hook 會產生 `memory/auto_recent.md`（最近 48 小時的相關對話片段）
- 使用者訊息含「上次」「之前」「為什麼」等詞時，UserPromptSubmit hook 會自動跑 `vsearch`，把結果附在訊息後面

## 注意
- DB 是歷史紀錄，動手前要再確認現在的狀態（檔案內容、設定）
- DB 含敏感資料（密碼、token、IP），只在本機使用，不要分享
