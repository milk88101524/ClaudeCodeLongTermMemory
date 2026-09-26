# Claude Code Long-Term Memory

「打造 Claude Code 的長期記憶」系列文章的配套資源。

這個系列記錄我從開源專案 [claude-session-archive-skill](https://github.com/jrjohn/arcana-skills/tree/main/claude-session-archive-skill)（作者 jrjohn，MIT）學習如何永久保存 Claude Code 的對話紀錄，邊裝邊學、邊修問題的過程。

## 文章與資料夾

| 篇 | 主題 | 資料夾 |
|---|---|---|
| #1 | 讓 Claude Code 不再失憶：這套 archive 在做什麼、怎麼裝 | — |
| #2 | [對話才多 239 筆，DB 卻暴漲 10 倍？](https://medium.com/@milk88101524/%E6%89%93%E9%80%A0-claude-code-%E7%9A%84%E9%95%B7%E6%9C%9F%E8%A8%98%E6%86%B6-2-%E5%B0%8D%E8%A9%B1%E6%89%8D%E5%A4%9A-239-%E7%AD%86-db-%E5%8D%BB%E6%9A%B4%E6%BC%B2-10-%E5%80%8D-23ad1e4f50d7) | [02-sqlite-bloat](02-sqlite-bloat) |

## 環境

- macOS、Claude Code CLI
- claude-session-archive-skill 預設的 SQLite 版（上游 commit `2665bee`，v1.30.0）

## 注意

- 這裡**只放合成資料與腳本**，不含任何真實對話。
- 真實的 `sessions.db` 會逐字保存對話與工具輸出（可能包含密碼、token），請只放在本機，不要上傳。
- 修正或 patch 請先在沙盒測試、並備份 DB 後再套用到自己的安裝。

## License

[MIT](LICENSE)。patch 的對象是上游 [jrjohn/arcana-skills](https://github.com/jrjohn/arcana-skills)（MIT License）。
