#!/bin/bash
# 下載上游的兩個 hook（固定在 jrjohn/arcana-skills commit 2665bee），放到 work/：
#   work/original/   上游原版（唯讀，當對照）
#   work/            套用 patches/ 之後的修正版
# 不會動到你的 ~/.claude/hooks
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SHA=2665beeed04a046a658fce2dbc519398862a9c63
BASE="https://raw.githubusercontent.com/jrjohn/arcana-skills/$SHA/claude-session-archive-skill/scripts"
W="$HERE/work"
command -v jq >/dev/null || { echo "需要 jq"; exit 1; }
rm -rf "$W"; mkdir -p "$W/original"
for f in archive-preflight.sh auto-osearch-on-prompt.sh; do
  curl -fsSL "$BASE/$f" -o "$W/original/$f"
  cp "$W/original/$f" "$W/$f"
  patch -s -p1 -d "$W" < "$HERE/patches/${f%.sh}.patch"
  bash -n "$W/$f"
done
chmod a-w "$W/original/"*.sh
grep -q 'HAS_OSEARCH' "$W/archive-preflight.sh" && grep -q 'SEARCH_CMD' "$W/auto-osearch-on-prompt.sh" \
  || { echo "!! patch 沒有套用成功"; exit 1; }
echo "==> 完成：work/ 是修正版，work/original/ 是上游原版"
echo "    測試：tests/test_preflight.sh [original]、tests/test_prompt_hook.sh [original]"
