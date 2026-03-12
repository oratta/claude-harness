#!/bin/bash
# update-progress.sh
# ロングラン実行中に {run-dir}/progress.md のタイムスタンプを更新するスクリプト
# Hook (Stop イベント) から呼び出される

# 最新のランディレクトリを特定
RUN_DIR=$(ls -1d _longrun/20*/ 2>/dev/null | sort | tail -1)

if [ -z "$RUN_DIR" ]; then
  exit 0
fi

PROGRESS_FILE="${RUN_DIR}progress.md"

if [ ! -f "$PROGRESS_FILE" ]; then
  exit 0
fi

# タイムスタンプを更新
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# "最終更新" 行を更新（存在する場合）
if grep -q "最終更新:" "$PROGRESS_FILE"; then
  sed -i '' "s/最終更新: .*/最終更新: $TIMESTAMP/" "$PROGRESS_FILE" 2>/dev/null || \
  sed -i "s/最終更新: .*/最終更新: $TIMESTAMP/" "$PROGRESS_FILE"
fi

# 最新のgitコミットハッシュを取得
LATEST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "no commits")

echo "Progress updated at $TIMESTAMP in $RUN_DIR (latest commit: $LATEST_COMMIT)"
