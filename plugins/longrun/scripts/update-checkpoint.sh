#!/bin/bash
# update-checkpoint.sh
# 自律実行中に {longrun-dir}/checkpoint.md のタイムスタンプを更新するスクリプト
# Hook (Stop イベント) から呼び出される

# 最新のランディレクトリを特定
LONGRUN_DIR=$(ls -1d _longruns/20*/ 2>/dev/null | sort | tail -1)

if [ -z "$LONGRUN_DIR" ]; then
  exit 0
fi

CHECKPOINT_FILE="${LONGRUN_DIR}checkpoint.md"

if [ ! -f "$CHECKPOINT_FILE" ]; then
  exit 0
fi

# タイムスタンプを更新
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# "最終更新" 行を更新（存在する場合）
if grep -q "last_updated:" "$CHECKPOINT_FILE"; then
  sed -i '' "s/last_updated: .*/last_updated: $TIMESTAMP/" "$CHECKPOINT_FILE" 2>/dev/null || \
  sed -i "s/last_updated: .*/last_updated: $TIMESTAMP/" "$CHECKPOINT_FILE"
fi

# 最新のgitコミットハッシュを取得
LATEST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "no commits")

echo "Checkpoint updated at $TIMESTAMP in $LONGRUN_DIR (latest commit: $LATEST_COMMIT)"
