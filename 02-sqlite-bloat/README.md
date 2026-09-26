# #2 對話才多 239 筆，DB 卻暴漲 10 倍？

這個資料夾是「打造 Claude Code 的長期記憶 #2」的重現資源：讓你在**自己的電腦上親眼看到** [claude-session-archive-skill](https://github.com/jrjohn/arcana-skills/tree/main/claude-session-archive-skill)（SQLite 版）的 DB 膨脹問題，以及修正後的效果。

所有測試都在這個資料夾裡的沙盒進行，**不會碰到你真正的 `~/claude-archive`**。

## 問題一句話

crs 在 JSONL 檔案有變動時會**整份重讀**，並用 `INSERT OR REPLACE` 寫入每一行。REPLACE 會把舊資料刪掉再重寫、換一個新的 rowid，但刪除時不會觸發 FTS 的 trigger，於是全文索引留下孤兒、向量表留下 stale 向量，每 15 分鐘累積一次。

修正：把 `crs/src/main.rs` 第 1103 行的 `INSERT OR REPLACE` 改成 `INSERT OR IGNORE`（[patches/01-insert-or-ignore.patch](patches/01-insert-or-ignore.patch)），再對既有的 DB 做一次清理。

## 1. 最快的方式：SQLite 練習（不用裝任何東西）

只需要支援 FTS5 的 sqlite3（macOS 內建的 `/usr/bin/sqlite3` 就可以）：

```bash
cd practice
rm -f practice.db && /usr/bin/sqlite3 practice.db < practice.sql
```

你會依序看到：
1. SQLite 自動給的 rowid
2. `REPLACE` 讓內容一字未改的資料換了新 rowid（1 → 4），`IGNORE` 則不變
3. 模擬一輪排程後，msg 只有 4 筆，全文索引卻有 7 筆（孤兒）
4. 讀取孤兒直接報錯 `missing row 4 from content table`；換成 IGNORE 不會產生新孤兒，但清不掉舊的
5. `optimize` 清不掉孤兒，`rebuild` 才清得掉

> 注意：有些環境 PATH 上的 `sqlite3` 沒有編進 FTS5（例如 Android SDK 附的版本），會出現 `no such module: fts5`。

## 2. 用真正的 crs 做 A/B 對照

需要：git、[Rust](https://rustup.rs)、python3。要測向量的話另外需要 [Ollama](https://ollama.com) 並 `ollama pull bge-m3`（沒有的話加 `NOEMBED=1`）。

```bash
./setup.sh      # 下載上游原始碼（固定 commit 2665bee），編出 crs-A / crs-B / crs-C

cd sandbox
for r in 0 1 2 3 4 5; do ./round.sh A $r; done   # 原版 REPLACE
for r in 0 1 2 3 4 5; do ./round.sh B $r; done   # 只改一個字 IGNORE
# 沒有 Ollama：NOEMBED=1 ./round.sh A 0 ...
```

每一輪會先追加 5 行合成對話，再跑一次 `crs build`，最後印出：
- `msg`：真正的資料筆數
- `max_rowid`：發出去的最大編號
- `fts_orphans`：全文索引裡的孤兒
- `fts_hits('zebratoken1')`：一個只出現在第 1 筆的字被搜到幾次
- `old_seq0-49_rowids_changed`：最早 50 筆有幾筆換了編號

作者電腦上的結果（50 行起始，每輪 +5 行，含向量）：

| | A：REPLACE | B：IGNORE |
|---|---|---|
| msg 筆數（第 5 輪） | 75 | 75 |
| max rowid | 375 | 75 |
| FTS 孤兒 | 300 | 0 |
| stale 向量 | 300 | 0 |
| 同一個字被搜到幾次 | 6 | 1 |
| 每輪重新產生向量 | 整份（55→75 筆） | 只有新增的 5 筆 |

清掉測試資料：`rm -rf sandbox/home? sandbox/*.prev.json`

## 3. 修正你自己的安裝

> ⚠️ 先備份。以下假設 macOS、預設安裝路徑，並在**你自己的終端機**執行。

```bash
# 暫停排程、備份
launchctl unload ~/Library/LaunchAgents/com.$(whoami).claude-archive.plist
/usr/bin/sqlite3 ~/claude-archive/sessions.db ".backup '$HOME/claude-archive/sessions.db.bak-before-fix'"
chmod 600 ~/claude-archive/sessions.db.bak-before-fix

# 改一個字、重新編譯
cd ~/claude-archive/crs
sed -n 1103p src/main.rs     # 確認是 INSERT OR REPLACE INTO msg(...) 那行
sed -i '' '1103s/INSERT OR REPLACE INTO msg(/INSERT OR IGNORE INTO msg(/' src/main.rs
cargo build --release

# 清理：rebuild（不是 optimize）→ 刪 stale 向量 → 回收空間 → 檢查
/usr/bin/sqlite3 ~/claude-archive/sessions.db "INSERT INTO msg_fts(msg_fts) VALUES('rebuild');"
crs prune-vec --dry-run && crs prune-vec
/usr/bin/sqlite3 ~/claude-archive/sessions.db "VACUUM;"
/usr/bin/sqlite3 ~/claude-archive/sessions.db "PRAGMA quick_check;"
/usr/bin/sqlite3 ~/claude-archive/sessions.db "INSERT INTO msg_fts(msg_fts, rank) VALUES('integrity-check', 1);"
crs doctor

# 恢復排程
launchctl load ~/Library/LaunchAgents/com.$(whoami).claude-archive.plist
```

作者的實際結果：181.3 MB → 43.3 MB；stale 向量 36,915 → 0；對話筆數不變；修正 2 小時後 stale 仍為 0。

## 4. 這樣改會不會有問題？

作者請 Claude 做了幾組驗證（合成資料）：

- **大資料量**：1 千到 144 萬筆，每輪逐筆全文比對，修正版全部正確；原版 100 萬筆 3 輪就產生 54 萬個孤兒
- **邊界情況**：程式被強制中止、寫到一半的行、build 途中寫入、兩個 build 同時跑 → 都正確
- **Claude Code 會不會改寫 JSONL 舊行**：一般對話、resume、continue、fork、compact、rewind、同時寫入 → 都只往後加
- **已知限制**：Claude Code 在串流出錯等罕見情況下會刪掉檔尾附近的一行（tombstone），這時 IGNORE 可能漏掉接下來的幾筆新對話

## 5. 實驗性：只讀新增的部分（crs-C）

[patches/02-incremental-read.patch](patches/02-incremental-read.patch)（套在 01 之後，約 +130／−30 行）：在 `ingest_state` 記錄讀到的位置、下一個 seq 和那個位置前 4 KB 的 SHA-256，下次只讀新增的部分；hash 對不上時（例如 tombstone）就從頭逐列比對並修正。

| | crs-B（IGNORE） | crs-C（增量） |
|---|---|---|
| 15 萬行 session 追加 1 行 | 0.4 秒 | 0.01 秒 |
| 60 萬行 session 追加 1 行 | 1.6–2.6 秒 | 0.04 秒 |
| 1 千～100 萬筆正確性 | ✅ | ✅ |
| tombstone（刪行後追加） | ❌ 殘留舊行、漏掉新行 | ✅ 正確並印出警告 |

> ⚠️ **僅在沙盒測試過，作者沒有用在正式環境**。限制：最後 4 KB 以外、長度不變的改寫偵測不到；遇到 tombstone 時成本約等於整份重讀。

## 關於 PostgreSQL 版

上游另有 PostgreSQL 版（`./install.sh --with-pg`）。從原始碼看，PG 版寫入時用 `ON CONFLICT (session_id, seq) DO NOTHING`，等同 IGNORE，理論上不會有這個問題，但**沒有實際驗證**。

## 資料夾內容

```
02-sqlite-bloat/
├── setup.sh                         下載上游並編出 crs-A / B / C
├── patches/
│   ├── 01-insert-or-ignore.patch    一個字的修正
│   └── 02-incremental-read.patch    實驗性：只讀新增的部分
├── practice/practice.sql            SQLite 練習
└── sandbox/
    ├── round.sh                     跑一輪 A/B/C 對照
    ├── gen.py                       產生合成對話
    ├── metrics.py                   統計孤兒與 rowid
    ├── cmp.py                       比對兩份 JSONL 快照（檢查舊行有沒有被改寫）
    └── rt.py                        recursive_triggers 開／關的小實驗
```
