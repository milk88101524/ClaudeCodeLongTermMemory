#!/bin/bash
# 從上游原始碼編出三個版本的 crs，放到 sandbox/bin/：
#   crs-A：上游原版（INSERT OR REPLACE）
#   crs-B：只改一個字（INSERT OR IGNORE）          ← patches/01-insert-or-ignore.patch
#   crs-C：B + 只讀新增的部分（增量讀取，實驗性）   ← patches/02-incremental-read.patch
# 上游固定在 jrjohn/arcana-skills commit 2665bee（claude-session-archive-skill v1.30.0）
# 需要：git、Rust（cargo）
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_SHA=2665beeed04a046a658fce2dbc519398862a9c63
WORK="$HERE/.work"; BIN="$HERE/sandbox/bin"
command -v cargo >/dev/null || { echo "需要 Rust：https://rustup.rs"; exit 1; }
mkdir -p "$WORK" "$BIN"

if [ ! -d "$WORK/upstream/.git" ]; then
  echo "==> 下載上游原始碼（commit ${UPSTREAM_SHA:0:7}）"
  git init -q "$WORK/upstream"
  git -C "$WORK/upstream" fetch -q --depth 1 https://github.com/jrjohn/arcana-skills.git "$UPSTREAM_SHA"
  git -C "$WORK/upstream" checkout -q FETCH_HEAD
fi
SRC="$WORK/upstream/claude-session-archive-skill/scripts/crs"

build() {  # build <版本> <patch...>
  local v=$1; shift
  echo "==> 編譯 crs-$v"
  rm -rf "$WORK/crs-$v"; cp -R "$SRC" "$WORK/crs-$v"
  for p in "$@"; do patch -s -p1 -d "$WORK/crs-$v" < "$HERE/patches/$p"; done
  (cd "$WORK/crs-$v" && CARGO_TARGET_DIR="$WORK/target" cargo build --release -q)
  cp "$WORK/target/release/crs" "$BIN/crs-$v"
}
check() {  # check <版本> <預期字串>：確認 patch 真的編進去了
  grep -q "$2" <(strings "$BIN/crs-$1") || { echo "!! crs-$1 裡找不到「$2」，patch 沒有套用成功"; exit 1; }
}
build A
build B 01-insert-or-ignore.patch
build C 01-insert-or-ignore.patch 02-incremental-read.patch
check A "INSERT OR REPLACE INTO msg(session_id"
check B "INSERT OR IGNORE INTO msg(session_id"
check C "byte_offset"
echo "==> 完成：$(ls "$BIN" | tr '\n' ' ')"
