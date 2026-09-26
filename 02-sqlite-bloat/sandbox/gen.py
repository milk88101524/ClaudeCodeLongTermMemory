import json, sys
# usage: gen.py <file> <start> <count>  (append lines seq start..start+count-1)
path, start, n = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
sid = path.rsplit('/',1)[1][:-6]
with open(path, 'a', encoding='utf-8') as f:
    for i in range(start, start+n):
        role = 'user' if i % 2 == 0 else 'assistant'
        txt = (f"synthetic message {i} about gardening tomatoes zebratoken{i}" if i % 3
               else f"合成測試訊息 {i}：今天天氣很好，我們來討論番茄種植 zebratoken{i}")
        content = txt if role == 'user' else [{"type": "text", "text": txt}]
        rec = {"type": role, "sessionId": sid, "uuid": f"00000000-0000-0000-0000-{i:012d}",
               "timestamp": f"2026-09-25T10:{i//60:02d}:{i%60:02d}.000Z",
               "message": {"role": role, "content": content}}
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
