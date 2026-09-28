#!/bin/bash
# 測試 auto-osearch-on-prompt.sh：模擬「你送出一則訊息」
#   ./test_prompt_hook.sh               → 測這個資料夾裡（你修改中）的版本
#   ./test_prompt_hook.sh original      → 測上游原版（對照用）
# 重點：搜尋指令失敗時，不應該寫下解鎖標記
DIR="$(cd "$(dirname "$0")/../work" 2>/dev/null && pwd)" || { echo "請先執行 ../setup.sh"; exit 1; }
HOOK="$DIR/auto-osearch-on-prompt.sh"; [ "$1" = original ] && HOOK="$DIR/original/auto-osearch-on-prompt.sh"
SID="prompttest-$$"
M1=/tmp/claude-archive-preflight-$SID; M2=/tmp/claude-archive-osearch-$SID
cleanup() { rm -f $M1 $M2 /tmp/claude-osearch-cooldown; }
trap cleanup EXIT; cleanup
pass=0; fail=0

send() { jq -nc --arg s "$SID" --arg p "$1" '{session_id:$s, prompt:$p}' | bash "$HOOK" 2>/dev/null; }

echo "測試對象：$HOOK"

echo "== 1. 訊息沒有觸發詞 =="
cleanup; out=$(send "幫我把這段文字翻成英文")
if [ ! -e $M1 ]; then echo "  ✅ 沒有寫下解鎖標記"; pass=$((pass+1)); else echo "  ❌ 寫下了解鎖標記"; fail=$((fail+1)); fi

echo "== 2. 訊息有觸發詞「怎麼」 =="
cleanup; out=$(send "上次那個 hook 是怎麼設定的")
if [ -e $M1 ]; then
  if [ -n "$out" ]; then echo "  ✅ 有搜尋結果注入，並寫下解鎖標記"; pass=$((pass+1))
  else echo "  ❌ 沒有任何搜尋結果，卻寫下了解鎖標記（失敗被當成成功）"; fail=$((fail+1)); fi
else
  if [ -n "$out" ]; then echo "  ⚠️ 有搜尋結果但沒有解鎖"; fail=$((fail+1))
  else echo "  ⚠️ 沒有搜尋結果，也沒有解鎖（沒誤判，但也沒搜尋）"; pass=$((pass+1)); fi
fi
[ -n "$out" ] && echo "     注入內容前 3 行：" && printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | head -3 | cut -c1-100 | sed 's/^/       /'

echo "----"
echo "通過 ${pass}、失敗 ${fail}"
[ "$fail" -eq 0 ]
