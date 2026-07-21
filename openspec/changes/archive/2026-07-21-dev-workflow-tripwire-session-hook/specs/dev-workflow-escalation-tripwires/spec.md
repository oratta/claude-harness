## MODIFIED Requirements

### Requirement: テンプレートの配布と導入手順
常駐ルールテンプレートは `plugins/dev-workflow/templates/` 配下に配置され、導入手順を README またはテンプレート冒頭に記載しなければならない（SHALL）。interactive 層への配布は SessionStart hook による自動注入を既定とし、手動コピー（グローバルルールまたはプロジェクト CLAUDE.md）はプラグイン未導入環境・閾値カスタマイズ向けのオプションとして記載する。unmanned は loop-dev-agent 憲法への組み込み（loop-dev-agent-tripwires）で行われることを記載する。

#### Scenario: interactive への導入
- **WHEN** dev-workflow プラグインを導入済みのユーザーが新しいセッションを開始する
- **THEN** トリップワイヤーは hook により自動で文脈に載り、手動コピーは不要である

#### Scenario: 手動コピーのオプションが残っている
- **WHEN** ユーザーがテンプレート冒頭の導入手順を読む
- **THEN** プラグイン未導入環境や閾値カスタマイズ向けに手動コピーの手順が記載されている

## ADDED Requirements

### Requirement: SessionStart hook がトリップワイヤーを常駐注入する
dev-workflow プラグインは `hooks/hooks.json` を配布し、SessionStart イベント（matcher: `startup|clear|compact`）で注入スクリプトを起動しなければならない（SHALL）。コマンドパスは `${CLAUDE_PLUGIN_ROOT}` を使用する。スクリプトは `templates/escalation-tripwires.md` の「## 昇格トリップワイヤー」節を抽出し、`{"additionalContext": "<節の本文>"}` の JSON を stdout に出力する（single source of truth: 本文の複製を hook 側に持たない）。テンプレートが見つからない・節が抽出できない場合は無出力・exit 0 で終了しなければならない（MUST NOT block session start）。

#### Scenario: 注入 JSON が節を含む
- **WHEN** `CLAUDE_PLUGIN_ROOT` をプラグインルートに設定してスクリプトを実行する
- **THEN** stdout は valid JSON で、`additionalContext` に「昇格トリップワイヤー」「規模超過」「失敗ループ」「仕様の発明」を含む

#### Scenario: テンプレート欠損時は fail-soft
- **WHEN** `CLAUDE_PLUGIN_ROOT` をテンプレートの無いディレクトリに設定してスクリプトを実行する
- **THEN** exit code 0 で出力は空である

#### Scenario: hooks.json の構造
- **WHEN** `plugins/dev-workflow/hooks/hooks.json` をパースする
- **THEN** SessionStart エントリが存在し、matcher が `startup|clear|compact`、command が `${CLAUDE_PLUGIN_ROOT}` 経由でスクリプトを指している
