import sqlite3, sys, os, json
home = sys.argv[1]; label = sys.argv[2]
db = f"{home}/claude-archive/sessions.db"
c = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
q = lambda s: c.execute(s).fetchall()
msg = q("SELECT count(*) FROM msg")[0][0]
docsize = q("SELECT count(*) FROM msg_fts_docsize")[0][0]
orphan = q("SELECT count(*) FROM msg_fts_docsize WHERE id NOT IN (SELECT rowid FROM msg)")[0][0]
maxrowid = q("SELECT max(rowid) FROM msg")[0][0]
first5 = q("SELECT rowid,seq FROM msg ORDER BY seq LIMIT 5")
old = dict(q("SELECT seq,rowid FROM msg WHERE seq<50"))
st = q("SELECT file_path,mtime,lines FROM ingest_state")
hit = q("SELECT count(*) FROM msg_fts WHERE msg_fts MATCH 'zebratoken1'")[0][0]
sz = os.path.getsize(db); wal = os.path.getsize(db+"-wal") if os.path.exists(db+"-wal") else 0
prevf = f"{home}/../{label}.prev.json"
changed = "n/a"
if os.path.exists(prevf):
    prev = {int(k): v for k, v in json.load(open(prevf)).items()}
    changed = sum(1 for k in prev if old.get(k) != prev[k])
json.dump(old, open(prevf, "w"))
print(f"[{label}] msg={msg} max_rowid={maxrowid} fts_docsize={docsize} fts_orphans={orphan} "
      f"fts_hits('zebratoken1')={hit} db={sz} wal={wal} old_seq0-49_rowids_changed={changed}")
print(f"  first5(rowid,seq)={first5}")
print(f"  ingest_state={[(os.path.basename(a), b, l) for a,b,l in st]}")
