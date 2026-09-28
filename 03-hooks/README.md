# #3 問一句「為什麼」就解鎖？hooks 的奇怪行為

「[打造 Claude Code 的長期記憶 #3](https://medium.com/@milk88101524/%E6%89%93%E9%80%A0-claude-code-%E7%9A%84%E9%95%B7%E6%9C%9F%E8%A8%98%E6%86%B6-3-%E5%95%8F%E4%B8%80%E5%8F%A5-%E7%82%BA%E4%BB%80%E9%BA%BC-%E5%B0%B1%E8%A7%A3%E9%8E%96-hooks-%E7%9A%84%E5%A5%87%E6%80%AA%E8%A1%8C%E7%82%BA-975100586778)」的配套資源：[claude-session-archive-skill](https://github.com/jrjohn/arcana-skills/tree/main/claude-session-archive-skill) 兩個 hook 的修正、測試腳本，以及適合 SQLite 版的 CLAUDE.md 規則。

## 問題

預設安裝的是 SQLite 版，但規則和 hooks 是以 PG 版才有的 `osearch` 為前提寫的：

| 問題 | SQLite 版 | PG 版 | 修正 |
|---|---|---|---|
| 照規則用 vsearch／csearch 也解不了鎖、memory 讀不到 | 會 | 不會 | A |
| 指令裡只要「提到」osearch 就解鎖（例如 `which osearch`） | 會 | 會，但影響不大 | A（只改 SQLite 版） |
| 送訊息時呼叫不存在的 osearch | 會 | 不會 | B |
| 搜尋失敗被當成成功，照樣解鎖（只把逾時當失敗） | 會 | 會 | B |
| 擋 LIKE／MATCH 的訊息含未跳脫的雙引號 → 輸出不是合法 JSON → Claude Code 當作沒擋 | 會 | 會 | C |
| SKILL.md 的規則前後矛盾（先說用 vsearch／csearch，又說只有 osearch 能解鎖） | 會 | 會 | CLAUDE.md 改寫 |

PG 版的部分是讀原始碼加上模擬（讓 `crs --help` 含 osearch）得出的，沒有實際的 PG 環境測試。

## 修正內容

- **A**（`archive-preflight.sh`）：用 `crs --help` 偵測有沒有 osearch → `HAS_OSEARCH`；只有真的有 osearch 時，提到 osearch 才解鎖；沒有 osearch 時 vsearch／csearch 也能解鎖。PG 版行為不變。
- **B**（`auto-osearch-on-prompt.sh`）：沒有 osearch 就改跑 vsearch；任何非 0 的 exit code 都算失敗，不寫解鎖標記。
- **C**（`archive-preflight.sh`）：`deny_with_reason()` 改用 `jq -n --arg` 產生 JSON，說明文字裡有什麼字元都不會壞。

patch：[patches/archive-preflight.patch](patches/archive-preflight.patch)、[patches/auto-osearch-on-prompt.patch](patches/auto-osearch-on-prompt.patch)

## 在沙盒測試

需要：curl、jq、patch。

```bash
./setup.sh                          # 下載上游原版到 work/original/，套用 patch 到 work/
tests/test_preflight.sh original    # 上游原版：通過 7、失敗 6
tests/test_preflight.sh             # 修正版：通過 13、失敗 0
tests/test_prompt_hook.sh original
tests/test_prompt_hook.sh
```

測試是把「假的工具呼叫」用 JSON 餵給 hook，看它擋還是放行，**不會動到你的 `~/.claude/hooks`**。判斷有沒有擋時，會用 jq 解析輸出（跟 Claude Code 一樣），格式壞掉的 JSON 會被視為沒擋。

- `test_preflight.sh` 會讀 `~/claude-archive/crs/target/release/crs --help` 來判斷版本；沒有安裝 crs 時視為 SQLite 版。
- `test_prompt_hook.sh` 的情境 2 會真的執行一次搜尋，需要已安裝 crs，SQLite 版還需要 Ollama（vsearch）。

## 套用到自己的安裝

```bash
mkdir -p ~/.claude/hooks-backup && cp ~/.claude/hooks/*.sh ~/.claude/hooks-backup/
cp work/archive-preflight.sh work/auto-osearch-on-prompt.sh ~/.claude/hooks/
```

改完 hook 腳本當下就生效，不用重開 session。還原：`cp ~/.claude/hooks-backup/*.sh ~/.claude/hooks/`

## CLAUDE.md 規則

[CLAUDE-archive-snippet.md](CLAUDE-archive-snippet.md)：以 SKILL.md 的 snippet 為基礎，拿掉 osearch、修正矛盾，並新增「被擋的訊息叫你跑 osearch 時，改跑 vsearch／csearch，不要繞過 hook」。貼到全域 `~/.claude/CLAUDE.md` 最上面。

> CLAUDE.md 只是上下文、不是強制設定，Claude 會盡量遵守但不保證每次照做。
