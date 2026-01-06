#!/bin/bash
# finalize_log.sh - タスク完了時にログを集計・分析
# Stop フックから呼び出される

LOG_DIR="${HOME}/.claude/execution-logs"
LOG_FILE="${LOG_DIR}/current_task.jsonl"
ARCHIVE_DIR="${LOG_DIR}/archive"

mkdir -p "$ARCHIVE_DIR"

# ログファイルが存在しない場合は終了
if [ ! -f "$LOG_FILE" ]; then
  exit 0
fi

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
task_id="task-$(date +%Y%m%d-%H%M%S)"

# 摩擦スコアを計算
friction_score=0

# 各摩擦タイプをカウント
explicit_corrections=$(grep -c '"friction_type": "explicit_correction"' "$LOG_FILE" 2>/dev/null || echo 0)
tone_escalations=$(grep -c '"friction_type": "tone_escalation"' "$LOG_FILE" 2>/dev/null || echo 0)
approach_pivots=$(grep -c '"friction_type": "approach_pivot"' "$LOG_FILE" 2>/dev/null || echo 0)

# スコア計算
friction_score=$((explicit_corrections * 2 + tone_escalations * 2 + approach_pivots * 4))

# 最大10に制限
if [ $friction_score -gt 10 ]; then
  friction_score=10
fi

# サマリーを作成
summary=$(jq -n \
  --arg id "$task_id" \
  --arg ts "$timestamp" \
  --argjson score "$friction_score" \
  --argjson explicit "$explicit_corrections" \
  --argjson tone "$tone_escalations" \
  --argjson pivots "$approach_pivots" \
  '{
    task_id: $id,
    completed_at: $ts,
    friction_score: $score,
    friction_breakdown: {
      explicit_corrections: $explicit,
      tone_escalations: $tone,
      approach_pivots: $pivots
    },
    needs_skill_proposal: ($score >= 5)
  }')

# サマリーをログの末尾に追加
echo "$summary" >> "$LOG_FILE"

# アーカイブに移動
mv "$LOG_FILE" "${ARCHIVE_DIR}/${task_id}.jsonl"

# 摩擦スコアが高い場合は標準出力に通知
if [ $friction_score -ge 5 ]; then
  echo "⚠️ 高摩擦タスク検出 (score: $friction_score/10)"
  echo "📋 /reflect コマンドでスキル作成を検討できます"
fi

exit 0
