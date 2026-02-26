#!/bin/bash
# update-progress.sh
# ロングラン実行中に _longrun/progress.md のタイムスタンプを更新するスクリプト
# Hook (Stop イベント) から呼び出される

PROGRESS_FILE="_longrun/progress.md"

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

echo "Progress updated at $TIMESTAMP (latest commit: $LATEST_COMMIT)"
