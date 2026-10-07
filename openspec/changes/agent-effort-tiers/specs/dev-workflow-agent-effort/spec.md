## ADDED Requirements

### Requirement: agent 定義は役ごとの effort を frontmatter に持つ
`plugins/dev-workflow/agents/` の `worker.md`・`gate-runner.md`・`reviewer.md`・`decider.md` は、frontmatter に `effort:` をちょうど 1 行持たなければならない（MUST）。初期値は `worker` と `gate-runner` が `medium`、`reviewer` と `decider` が `high` とする（SHALL）。

#### Scenario: 4 ファイルとも effort が 1 行
- **WHEN** `grep -c '^effort:' plugins/dev-workflow/agents/*.md` を実行する
- **THEN** 4 ファイルとも 1 を返す

#### Scenario: 役ごとの値
- **WHEN** 4 つの agent 定義の `effort:` 行を読む
- **THEN** worker と gate-runner は `medium`、reviewer と decider は `high`

### Requirement: model-tiers.md が effort の対応表と上書き方法の正本になる
`plugins/dev-workflow/references/model-tiers.md` は、役ごとの effort の表、frontmatter の `effort` が既定であること、Agent ツールの `effort` 引数（Claude Code 2.1.292）で呼び出し単位に上書きできること、上書きの優先順位（呼び出し引数、frontmatter、親セッションの順）を書かなければならない（MUST）。`codex-role-profiles.json` の effort は監査値のままで Agent の引数に変換しないことも書く（SHALL）。既存の「ティア → `opts.model`」表は書き換えてはならない（MUST NOT）。

#### Scenario: 節がある
- **WHEN** `grep -n 'effort' plugins/dev-workflow/references/model-tiers.md` を実行する
- **THEN** 1 件以上ヒットし、4 役の値と上書き方法が読める

#### Scenario: 既存の model 表は不変
- **WHEN** 変更前後の `model-tiers.md` の「ティア → `opts.model` に渡す値」の表を比べる
- **THEN** 差分が無い
