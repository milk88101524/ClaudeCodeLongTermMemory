-- SQLite 練習：親眼看到 INSERT OR REPLACE 怎麼產生 FTS 孤兒
-- 執行方式（macOS 請用內建的 /usr/bin/sqlite3，需要支援 FTS5）：
--   rm -f practice.db && /usr/bin/sqlite3 practice.db < practice.sql
-- 中間有兩個錯誤是「故意的」，會在註解裡說明。

.headers on
.mode column
.echo on

-- ============================================================
-- 第 1 步：建表，看 SQLite 自動給的 rowid
-- ============================================================
CREATE TABLE msg (
  session_id TEXT,
  seq        INTEGER,
  content    TEXT,
  PRIMARY KEY (session_id, seq)
);
INSERT INTO msg VALUES ('s1', 0, '你好');
INSERT INTO msg VALUES ('s1', 1, '今天天氣很好');
INSERT INTO msg VALUES ('s1', 2, '我們來討論番茄');
SELECT rowid, * FROM msg;
-- 預期：rowid 1、2、3

-- ============================================================
-- 第 2 步：同一筆資料再寫一次
-- ============================================================
-- 一般 INSERT：主鍵重複 → 故意的錯誤 UNIQUE constraint failed
INSERT INTO msg VALUES ('s1', 0, '你好');

-- REPLACE：內容一字未改，但會「刪掉再重寫」→ 換新 rowid
INSERT OR REPLACE INTO msg VALUES ('s1', 0, '你好');
SELECT rowid, * FROM msg;
-- 預期：「你好」的 rowid 從 1 變成 4

-- IGNORE：已存在就跳過 → rowid 不變
INSERT OR IGNORE INTO msg VALUES ('s1', 1, '今天天氣很好');
SELECT rowid, * FROM msg;
-- 預期：「今天天氣很好」仍是 rowid 2

-- ============================================================
-- 第 3 步：加上全文索引與 trigger（跟 crs 的做法一樣）
-- ============================================================
CREATE VIRTUAL TABLE msg_fts USING fts5(content, content='msg', content_rowid='rowid');
CREATE TRIGGER msg_ai AFTER INSERT ON msg BEGIN
  INSERT INTO msg_fts(rowid, content) VALUES (new.rowid, new.content);
END;
CREATE TRIGGER msg_ad AFTER DELETE ON msg BEGIN
  INSERT INTO msg_fts(msg_fts, rowid, content) VALUES ('delete', old.rowid, old.content);
END;
INSERT INTO msg_fts(msg_fts) VALUES ('rebuild');

SELECT count(*) AS msg筆數 FROM msg;
SELECT count(*) AS 索引筆數 FROM msg_fts_docsize;
SELECT rowid FROM msg_fts WHERE msg_fts MATCH '你好';
-- 預期：3 筆、3 筆、搜到 rowid 4 → 一切正常

-- 模擬 crs 的一輪排程：整份重讀 + REPLACE，多了一行新的
INSERT OR REPLACE INTO msg VALUES
  ('s1', 0, '你好'),
  ('s1', 1, '今天天氣很好'),
  ('s1', 2, '我們來討論番茄'),
  ('s1', 3, '番茄要多曬太陽');
SELECT rowid, * FROM msg;
SELECT count(*) AS msg筆數 FROM msg;
SELECT count(*) AS 索引筆數 FROM msg_fts_docsize;
SELECT rowid FROM msg_fts WHERE msg_fts MATCH '你好';
-- 預期：msg 4 筆，但索引 7 筆；「你好」搜到 rowid 4 和 5
-- 原因：REPLACE 刪除舊資料時不會觸發 msg_ad（除非開啟 recursive_triggers）→ 舊索引變孤兒

-- ============================================================
-- 第 4 步：孤兒長什麼樣子？換成 IGNORE 又會怎樣？
-- ============================================================
-- 讀取孤兒的內容 → 故意的錯誤 missing row 4 from content table
SELECT rowid, content FROM msg_fts WHERE msg_fts MATCH '你好';

-- 修正後的下一輪：IGNORE，整份重讀，再多一行
INSERT OR IGNORE INTO msg VALUES
  ('s1', 0, '你好'),
  ('s1', 1, '今天天氣很好'),
  ('s1', 2, '我們來討論番茄'),
  ('s1', 3, '番茄要多曬太陽'),
  ('s1', 4, '記得澆水');
SELECT rowid, * FROM msg;
SELECT count(*) AS 索引筆數 FROM msg_fts_docsize;
SELECT rowid FROM msg_fts WHERE msg_fts MATCH '你好';
-- 預期：舊資料 rowid 不變、索引 8 筆（只多了新的一筆）
--       但舊孤兒 rowid 4 還在 → IGNORE 不會產生新孤兒，但清不掉舊的

-- ============================================================
-- 第 5 步：optimize 清不掉，rebuild 才清得掉
-- ============================================================
INSERT INTO msg_fts(msg_fts) VALUES ('optimize');
SELECT count(*) AS optimize後索引筆數 FROM msg_fts_docsize;
SELECT rowid FROM msg_fts WHERE msg_fts MATCH '你好';
-- 預期：還是 8 筆、還是搜到 4 和 5（optimize 只合併索引，不看 msg 表）

INSERT INTO msg_fts(msg_fts) VALUES ('rebuild');
SELECT count(*) AS rebuild後索引筆數 FROM msg_fts_docsize;
SELECT rowid, content FROM msg_fts WHERE msg_fts MATCH '你好';
-- 預期：5 筆、只剩 rowid 5，讀內容也不再報錯
