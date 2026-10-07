# dev-workflow-agent-effort Specification

## Purpose
TBD - created by archiving change agent-effort-tiers. Update Purpose after archive.
## Requirements
### Requirement: agent 定義は役ごとの effort を frontmatter に持つ
`plugins/dev-workflow/agents/` の `worker.md`・`gate-runner.md`・`reviewer.md`・`decider.md` は、frontmatter に `effort:` をちょうど 1 行持たなければならない（MUST）。初期値は `worker` と `gate-runner` が `medium`、`reviewer` と `decider` が `high` とする（SHALL）。

#### Scenario: 4 ファイルとも effort が 1 行
- **WHEN** `grep -c '^effort:' plugins/dev-workflow/agents/*.md` を実行する
- **THEN** 4 ファイルとも 1 を返す

#### Scenario: 役ごとの値
- **WHEN** 4 つの agent 定義の `effort:` 行を読む
- **THEN** worker と gate-runner は `medium`、reviewer と decider は `high`

### Requirement: model-tiers.md が effort の対応表と上書き方法の正本になる
`plugins/dev-workflow/references/model-tiers.md` は、役ごとの effort の表、frontmatter の `effort` が既定であること、Agent ツールの `effort` 引数（Claude Code 2.1.292）で呼び出し単位に上書きできること、上書きの優先順位を書かなければならない（MUST）。公式文書（https://code.claude.com/docs/en/sub-agents ）が定める範囲は、frontmatter の `effort` がセッションの effort を上書きするが環境変数 `CLAUDE_CODE_EFFORT_LEVEL` は上書きしない（環境変数があれば環境変数が勝つ）こと。Agent の `effort` 引数と frontmatter・環境変数の優先関係は同文書に記載がないので、推測で書かず「文書に記載なし」と書かなければならない（MUST）。`codex-role-profiles.json` の effort は監査値のままで Agent の引数に変換しないことも書く（SHALL）。既存の「ティア → `opts.model`」表は書き換えてはならない（MUST NOT）。

#### Scenario: 節がある
- **WHEN** `grep -n 'effort' plugins/dev-workflow/references/model-tiers.md` を実行する
- **THEN** 1 件以上ヒットし、4 役の値と上書き方法が読める

#### Scenario: 既存の model 表は不変
- **WHEN** 変更前後の `model-tiers.md` の「ティア → `opts.model` に渡す値」の表を比べる
- **THEN** 差分が無い

#### Scenario: 環境変数の例外が書かれている
- **WHEN** `model-tiers.md` の effort の節を読む
- **THEN** 環境変数 `CLAUDE_CODE_EFFORT_LEVEL` があるときは frontmatter の値より環境変数が優先されること、Agent の `effort` 引数との関係は「文書に記載なし」であることが読める

### Requirement: effort の定義を bats が検査する
`plugins/dev-workflow/tests/` の bats は、4 つの agent 定義それぞれについて、frontmatter（先頭の `---` から次の `---` まで）内の `effort:` 行がちょうど 1 行であることと、役ごとの値（worker / gate-runner が `medium`、reviewer / decider が `high`）を検査しなければならない（MUST）。本文中の `effort:` を数えてはならない（MUST NOT）。

#### Scenario: effort 行が欠けると落ちる
- **WHEN** いずれかの agent 定義の frontmatter から `effort:` 行を消してテストを実行する
- **THEN** テストが失敗する

#### Scenario: 値が違うと落ちる
- **WHEN** worker の `effort:` を `high` に変えてテストを実行する
- **THEN** テストが失敗する

