#!/bin/bash
# detect_friction.sh - ユーザー入力から摩擦シグナルを検出
# UserPromptSubmit フックから呼び出される

LOG_DIR="${HOME}/.claude/execution-logs"
LOG_FILE="${LOG_DIR}/current_task.jsonl"

mkdir -p "$LOG_DIR"

# 標準入力からユーザープロンプトを読み取る
input=$(cat)
user_message=$(echo "$input" | jq -r '.user_prompt // ""')
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 摩擦シグナルのパターン検出
friction_type=""
severity=""

# 明示的修正パターン
if echo "$user_message" | grep -qiE "(違う|それじゃなくて|間違い|no,|that's wrong|変えて|instead)"; then
  friction_type="explicit_correction"
  severity="medium"
fi

# トーンエスカレーションパターン
if echo "$user_message" | grep -qiE "(なんで|まだ|！！|？？|what the|why did)"; then
  friction_type="tone_escalation"
  severity="high"
fi

# アプローチピボットパターン
if echo "$user_message" | grep -qiE "(別のやり方|別のアプローチ|違う方法|try different|another way|switch to)"; then
  friction_type="approach_pivot"
  severity="high"
fi

# 摩擦が検出された場合のみログ
if [ -n "$friction_type" ]; then
  log_entry=$(jq -n \
    --arg ts "$timestamp" \
    --arg type "$friction_type" \
    --arg sev "$severity" \
    --arg msg "$user_message" \
    '{
      timestamp: $ts,
      type: "friction_signal",
      friction_type: $type,
      severity: $sev,
      user_message: ($msg | .[0:200])
    }')
  
  echo "$log_entry" >> "$LOG_FILE"
fi

exit 0
