#!/bin/bash
# 測試 archive-preflight.sh：用「假的工具呼叫」餵給 hook，看它擋還是放行
#   ./test_preflight.sh                 → 測這個資料夾裡（你修改中）的版本
#   ./test_preflight.sh original        → 測 original/ 裡的上游原版（對照用）
# 不會動到正式的 ~/.claude/hooks，用的是假的 session id，解鎖標記測完就刪
DIR="$(cd "$(dirname "$0")/../work" 2>/dev/null && pwd)" || { echo "請先執行 ../setup.sh"; exit 1; }
HOOK="$DIR/archive-preflight.sh"; [ "$1" = original ] && HOOK="$DIR/original/archive-preflight.sh"
SID="hooktest-$$"; DB="$HOME/claude-archive/sessions.db"; MEM="$HOME/.claude/projects/-example/memory"
cleanup() { rm -f /tmp/claude-archive-preflight-$SID /tmp/claude-archive-osearch-$SID; }
trap cleanup EXIT; cleanup
pass=0; fail=0

bash_call() { jq -nc --arg s "$SID" --arg c "$1" '{session_id:$s, tool_name:"Bash", tool_input:{command:$c}}'; }
read_call() { jq -nc --arg s "$SID" --arg f "$1" '{session_id:$s, tool_name:"Read", tool_input:{file_path:$f}}'; }

check() {  # check <說明> <預期 allow|deny> <json>
  out=$(printf '%s' "$3" | bash "$HOOK" 2>/dev/null)
  # Claude Code 只認「合法的 JSON」：不合法的 deny 等於沒擋，所以要用 jq 解析，不能只找字串
  if [ -z "$out" ]; then got=allow
  elif [ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ]; then got=deny
  else got="allow(輸出不是合法 JSON)"; fi
  if [ "$got" = "$2" ]; then echo "  ✅ $1 → ${got}"; pass=$((pass+1))
  else echo "  ❌ $1 → ${got}（預期 $2）"; fail=$((fail+1)); fi
}

echo "測試對象：$HOOK"
echo "== 1. 還沒搜尋過 archive =="
check "sqlite3 查 DB 基本資訊"          deny  "$(bash_call "sqlite3 $DB \"SELECT count(*) FROM msg\"")"
check "sqlite3 用 LIKE 搜尋內容"         deny  "$(bash_call "sqlite3 $DB \"SELECT * FROM msg WHERE content LIKE '%x%'\"")"
check "讀 MEMORY.md（索引，永遠放行）"   allow "$(read_call "$MEM/MEMORY.md")"
check "讀 memory 裡的 auto_recent.md"    deny  "$(read_call "$MEM/auto_recent.md")"
check "無關的指令 ls"                    allow "$(bash_call "ls ~")"

echo "== 1b. 指令裡只是「提到」osearch（SQLite 版沒有 osearch）=="
check "which osearch 本身"               allow "$(bash_call "which osearch")"
check "之後 sqlite3 查基本資訊（不該被解鎖）" deny "$(bash_call "sqlite3 $DB \"SELECT count(*) FROM msg\"")"
cleanup

echo "== 2. 跑一次 vsearch =="
check "vsearch 本身"                     allow "$(bash_call "crs vsearch 'hooks'")"

echo "== 3. vsearch 之後（修正的目標：這裡要能放行）=="
check "sqlite3 查 DB 基本資訊"          allow "$(bash_call "sqlite3 $DB \"SELECT count(*) FROM msg\"")"
check "讀 memory 裡的 auto_recent.md"    allow "$(read_call "$MEM/auto_recent.md")"
check "sqlite3 用 MATCH 搜尋（永遠要擋）" deny  "$(bash_call "sqlite3 $DB \"SELECT rowid FROM msg_fts WHERE msg_fts MATCH 'x'\"")"
check "sqlite3 用 LIKE 搜尋（永遠要擋）"  deny  "$(bash_call "sqlite3 $DB \"SELECT * FROM msg WHERE content LIKE '%x%'\"")"

echo "== 4. 解鎖過期（模擬 30 分鐘後）=="
[ -f /tmp/claude-archive-preflight-$SID ] && touch -t "$(date -v-31M +%Y%m%d%H%M)" /tmp/claude-archive-preflight-$SID /tmp/claude-archive-osearch-$SID 2>/dev/null
check "過期後 sqlite3 查基本資訊"        deny  "$(bash_call "sqlite3 $DB \"SELECT count(*) FROM msg\"")"

echo "----"
echo "通過 ${pass}、失敗 ${fail}"
[ "$fail" -eq 0 ]
