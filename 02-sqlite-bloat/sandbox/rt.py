import sqlite3
for rt in (0, 1):
    c = sqlite3.connect(":memory:")
    c.executescript(f"""PRAGMA recursive_triggers={rt};
    CREATE TABLE msg(session_id TEXT, seq INT, content TEXT, PRIMARY KEY(session_id,seq));
    CREATE VIRTUAL TABLE msg_fts USING fts5(content, content='msg', content_rowid='rowid');
    CREATE TRIGGER msg_ai AFTER INSERT ON msg BEGIN INSERT INTO msg_fts(rowid,content) VALUES(new.rowid,new.content); END;
    CREATE TRIGGER msg_ad AFTER DELETE ON msg BEGIN INSERT INTO msg_fts(msg_fts,rowid,content) VALUES('delete',old.rowid,old.content); END;""")
    for _ in range(3):
        for i in range(10): c.execute("INSERT OR REPLACE INTO msg VALUES('s',?,?)", (i, f"hello{i}"))
    print(f"recursive_triggers={rt}: msg={c.execute('select count(*) from msg').fetchone()[0]} "
          f"fts_docsize={c.execute('select count(*) from msg_fts_docsize').fetchone()[0]} "
          f"max_rowid={c.execute('select max(rowid) from msg').fetchone()[0]}")
