#!/bin/bash
# 跑一輪測試：./round.sh <A|B|C> <輪次>
#   第 0 輪：建立 50 行合成對話；之後每輪追加 5 行，再跑一次 crs build
#   NOEMBED=1 ./round.sh A 0   → 不產生向量（沒有 Ollama 時使用）
# 所有資料都放在這個資料夾的 home<A|B|C>/ 底下，不會碰到你真正的 ~/claude-archive
S="$(cd "$(dirname "$0")" && pwd)"
V=$1; R=$2; H=$S/home$V; BIN=$S/bin/crs-$V
[ -x "$BIN" ] || { echo "找不到 $BIN，請先執行 ../setup.sh"; exit 1; }
P=$H/.claude/projects/-sandbox-proj; F=$P/11111111-2222-3333-4444-555555555555.jsonl
mkdir -p $P $H/claude-archive
if [ "$R" = 0 ]; then rm -f $F $S/$V.prev.json; python3 $S/gen.py $F 0 50
else sleep 1.1; N=$(wc -l < $F); python3 $S/gen.py $F $N 5; fi
echo "=== variant $V round $R: jsonl lines=$(wc -l < $F) ==="
export HOME=$H CRS_DB=$H/claude-archive/sessions.db
EMBED_FLAG=""; [ -n "$NOEMBED" ] && EMBED_FLAG="--no-embed"
/usr/bin/time -p $BIN build --no-refresh $EMBED_FLAG 2>&1 | grep -v '^$'
python3 $S/metrics.py $H $V
[ -z "$NOEMBED" ] && $BIN doctor 2>&1 | sed -n '/\[storage\]/,/latest msg ts/p' | grep -E 'msg_vec|stale|backlog'
exit 0
