#!/bin/bash
# log_tool_use.sh - ツール使用をログに記録
# PostToolUse フックから呼び出される

LOG_DIR="${HOME}/.claude/execution-logs"
LOG_FILE="${LOG_DIR}/current_task.jsonl"

# ログディレクトリを作成
mkdir -p "$LOG_DIR"

# 標準入力からツール使用情報を読み取る
input=$(cat)

# ツール名と結果を抽出
tool_name=$(echo "$input" | jq -r '.tool_name // "unknown"')
tool_result=$(echo "$input" | jq -r '.tool_result.success // "unknown"')
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ログエントリを作成
log_entry=$(jq -n \
  --arg ts "$timestamp" \
  --arg tool "$tool_name" \
  --arg result "$tool_result" \
  '{
    timestamp: $ts,
    type: "tool_use",
    tool: $tool,
    result: $result
  }')

# ログファイルに追記
echo "$log_entry" >> "$LOG_FILE"

# 正常終了（フックを続行）
exit 0
