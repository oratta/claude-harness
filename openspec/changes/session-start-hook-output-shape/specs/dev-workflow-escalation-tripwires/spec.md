## MODIFIED Requirements

### Requirement: SessionStart hook がトリップワイヤーを常駐注入する
dev-workflow プラグインは `hooks/hooks.json` を配布し、SessionStart イベント（matcher: `startup|clear|compact`）で注入スクリプトを起動しなければならない（SHALL）。コマンドパスは `${CLAUDE_PLUGIN_ROOT}` を使用する。スクリプトは `templates/escalation-tripwires.md` の「## 昇格トリップワイヤー」節を抽出し、`{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<節の本文>"}}` の JSON を stdout に出力する（single source of truth: 本文の複製を hook 側に持たない）。`additionalContext` をトップレベルに置いてはならない（MUST NOT。Claude Code はトップレベルの `additionalContext` を SessionStart の文脈に足さない）。`TRIPWIRES_SCOPE` が未設定のとき、テンプレートが見つからない・節が抽出できない場合は無出力・exit 0 で終了しなければならない（MUST NOT block session start）。`TRIPWIRES_SCOPE=subagent-budget` のときの出力は要件「SubagentStart hook が dev-workflow の役に運用情報を注入する」が定める。

#### Scenario: 注入 JSON が節を含む
- **WHEN** `CLAUDE_PLUGIN_ROOT` をプラグインルートに設定してスクリプトを実行する
- **THEN** stdout は valid JSON で、`hookSpecificOutput.hookEventName` が `SessionStart`、`hookSpecificOutput.additionalContext` に「昇格トリップワイヤー」「規模超過」「失敗ループ」「仕様の発明」を含み、トップレベルに `additionalContext` を持たない

#### Scenario: テンプレート欠損時は fail-soft
- **WHEN** `TRIPWIRES_SCOPE` 未設定で、`CLAUDE_PLUGIN_ROOT` をテンプレートの無いディレクトリに設定してスクリプトを実行する
- **THEN** exit code 0 で出力は空である

#### Scenario: hooks.json の構造
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SessionStart エントリが存在し、matcher が `startup|clear|compact`、command が `${CLAUDE_PLUGIN_ROOT}` 経由でスクリプトを指している
