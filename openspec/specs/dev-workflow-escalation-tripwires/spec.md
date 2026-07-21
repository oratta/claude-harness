# dev-workflow-escalation-tripwires Specification (Delta)

## ADDED Requirements

### Requirement: 昇格トリップワイヤー3本の定義
dev-workflow プラグインは、solo からの離脱条件を定義する常駐ルールテンプレートを配布しなければならない（SHALL）。テンプレートは以下の3本のトリップワイヤーを、行為ベースの数えられる条件として定義する:

1. **規模超過 → workflow 型**: 編集対象ファイルが5個を超えた、または着手前の見積もりから作業項目が2回増えた
2. **失敗ループ → モデル昇格**: 同じテストが2連続で落ちた、または同じ箇所を2回書き直した（昇格は1段ずつ: Sonnet → Opus → Fable。`FABLE_BUDGET_MODE=reserve` の自動実行では Opus 上限）
3. **仕様の発明検知 → plan/質問**: ユーザーの指示に書かれていない仕様上の決定を自分で埋めた回数が2回に達した

閾値は初期値であり運用調整前提であることをテンプレートに明記しなければならない（SHALL）。「あと少しで終わるから」を乗り換えない理由にしないことを明記する。

#### Scenario: 規模超過での乗り換え
- **WHEN** solo 作業中に編集対象ファイルが6個目に達する
- **THEN** その場で手を止め、workflow 型の実行スキルに乗り換える

#### Scenario: 失敗ループでの昇格
- **WHEN** 同じテストが2連続で落ちる
- **THEN** 実行役のモデルを1段昇格して続行する

#### Scenario: 仕様の発明での停止
- **WHEN** ユーザーの指示に無い仕様決定（例:「DB は SQLite でいいだろう」）を自分で埋めた回数が2回に達する
- **THEN** 手を止めて埋めた決定を列挙し、局所的なら AskUserQuestion、構造に及ぶなら plan 系スキルの起動、unmanned なら Discord 質問 + needs-approval でサイクル終了する

### Requirement: 2段構えの配線
常駐ルールテンプレートは「いつ手を止めるか」（トリップワイヤー条件）のみを含み、発火時のアクションはすべてスキル呼び出し（/lr:e、/lr:p 等の名前）で表現しなければならない（SHALL）。テンプレートは Workflow ツールやサブエージェント起動の直接的な操作手順を含んではならない（MUST NOT）。

#### Scenario: テンプレートにツール直接操作が無い
- **WHEN** 配布されたテンプレートの内容を検査する
- **THEN** 発火時のアクションはスキル/コマンド名の呼び出しのみで、Workflow ツールの直接呼び出し指示は含まれない

### Requirement: テンプレートの配布と導入手順
常駐ルールテンプレートは `plugins/dev-workflow/templates/` 配下に配置され、導入手順を README またはテンプレート冒頭に記載しなければならない（SHALL）。interactive 層への配布は SessionStart hook による自動注入を既定とし、手動コピー（グローバルルールまたはプロジェクト CLAUDE.md）はプラグイン未導入環境・閾値カスタマイズ向けのオプションとして記載する。unmanned は loop-dev-agent 憲法への組み込み（loop-dev-agent-tripwires）で行われることを記載する。

#### Scenario: interactive への導入
- **WHEN** dev-workflow プラグインを導入済みのユーザーが新しいセッションを開始する
- **THEN** トリップワイヤーは hook により自動で文脈に載り、手動コピーは不要である

#### Scenario: 手動コピーのオプションが残っている
- **WHEN** ユーザーがテンプレート冒頭の導入手順を読む
- **THEN** プラグイン未導入環境や閾値カスタマイズ向けに手動コピーの手順が記載されている

### Requirement: 乗り換え時の成果引き継ぎ
トリップワイヤー発火による乗り換え・昇格の際、それまでの成果（編集済みファイル・通ったテスト・埋めた決定の列挙）を破棄せず引き継ぐことをテンプレートが指示しなければならない（SHALL）。

#### Scenario: workflow 型への引き継ぎ
- **WHEN** 規模超過トリップワイヤーが発火して workflow 型に乗り換える
- **THEN** ここまでの編集内容と判明した事実を引き継ぎ情報として渡し、作業をやり直さない

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
