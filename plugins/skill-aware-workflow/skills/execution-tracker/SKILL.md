---
name: execution-tracker
description: This skill should be used during task execution to track user feedback, corrections, failed attempts, and pivots in approach. It records friction signals that indicate potential skill opportunities. Activates when user says "no, try this instead", "that's wrong", corrects Claude's output, or when Claude retries an approach multiple times.
version: 1.0.0
---

# Execution Tracker

タスク実行中のフィードバック、試行錯誤、アプローチ変更を記録するスキル。

## 目的

- ユーザーからの修正指示を検出・記録
- 失敗した試行とその原因を追跡
- アプローチの変更（ピボット）を記録
- skill-proposer に引き継ぐための「摩擦シグナル」を収集

## 摩擦シグナルの種類

### 1. 明示的修正 (Explicit Correction)

ユーザーが直接的に修正を指示するケース：

```
検出パターン:
- "違う、〇〇して"
- "それじゃなくて"
- "〇〇は間違い"
- "no, try..."
- "that's wrong"
- "〇〇に変えて"
```

記録例:
```yaml
friction_signal:
  type: explicit_correction
  timestamp: "2025-01-07T10:30:00"
  context: "PDFの署名欄配置"
  original_approach: "右下に配置"
  correction: "中央下部に配置"
  user_message: "署名欄は中央下に配置して"
  severity: medium
```

### 2. 暗黙的修正 (Implicit Correction)

ユーザーが別のアプローチを提案するケース：

```
検出パターン:
- "〇〇の方法でやってみて"
- "別のアプローチで"
- "〇〇を使って"
- "instead, ..."
```

### 3. 繰り返し失敗 (Repeated Failure)

同じ操作を複数回試行するケース：

```yaml
friction_signal:
  type: repeated_failure
  timestamp: "2025-01-07T10:35:00"
  operation: "PDF form field creation"
  attempts: 3
  errors:
    - "pypdf doesn't support form fields"
    - "reportlab import error"
    - "pdfrw form field not working"
  final_solution: "pikepdf library"
  severity: high
```

### 4. トーンエスカレーション (Tone Escalation)

ユーザーのフラストレーションが増加するケース：

```
検出パターン:
- 句点や感嘆符の増加
- 命令形の増加
- "なんで？" "まだ？"
- 短い返答への変化
```

### 5. アプローチピボット (Approach Pivot)

根本的なアプローチを変更するケース：

```yaml
friction_signal:
  type: approach_pivot
  timestamp: "2025-01-07T10:40:00"
  original_approach: "Python で PDF 編集"
  new_approach: "Node.js の pdf-lib を使用"
  reason: "Python ライブラリの制約"
  suggested_by: user  # user | claude
  severity: high
```

## 記録フォーマット

タスク実行中、以下の構造で記録を蓄積：

```yaml
execution_log:
  task_id: "task-20250107-001"
  task_summary: "PDFに署名欄を追加"
  started_at: "2025-01-07T10:00:00"
  
  initial_approach:
    method: "pypdf を使用したフォームフィールド追加"
    skill_used: null
    confidence: medium
    
  friction_signals:
    - type: repeated_failure
      # ... 詳細
    - type: explicit_correction
      # ... 詳細
      
  pivots:
    - from: "pypdf"
      to: "pikepdf"
      reason: "フォームフィールドサポートなし"
      
  tools_tried:
    - name: pypdf
      result: failed
      error: "No form field support"
    - name: pikepdf
      result: success
      
  successful_approach:
    method: "pikepdf でフォームフィールド作成"
    key_learnings:
      - "pikepdf は PDF フォーム操作に適している"
      - "署名欄は AcroForm として追加"
      
  ended_at: "2025-01-07T10:45:00"
  friction_score: 7  # 0-10, 高いほど摩擦大
```

## 摩擦スコア計算

| シグナルタイプ | 重み |
|---------------|------|
| explicit_correction | +2 |
| implicit_correction | +1 |
| repeated_failure | +3/回 |
| tone_escalation | +2 |
| approach_pivot | +4 |

閾値:
- 0-3: スムーズな実行（スキル不要かも）
- 4-6: 軽度の摩擦（改善余地あり）
- 7-10: 高摩擦（スキル作成を強く推奨）

## 次のステップ

タスク完了時、このログを **skill-proposer** に渡す：

1. `friction_score >= 5` → スキル提案を生成
2. `pivots` が存在 → ピボット理由を分析
3. `key_learnings` → スキル内容の候補として活用

## Hooks 連携

PreToolUse / PostToolUse / Stop フックと連携して自動記録：

```json
{
  "PostToolUse": [
    {
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/log_tool_use.sh"
      }]
    }
  ],
  "Stop": [
    {
      "matcher": "*", 
      "hooks": [{
        "type": "command",
        "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/finalize_log.sh"
      }]
    }
  ]
}
```

## 参照

- `references/friction-patterns.md` - 摩擦パターンの詳細定義
- `scripts/log_tool_use.sh` - ツール使用ログ記録
- `scripts/finalize_log.sh` - 実行ログ完了処理
