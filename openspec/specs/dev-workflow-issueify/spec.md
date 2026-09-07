# dev-workflow-issueify Specification

## Purpose
TBD - created by archiving change loops-longrun-retirement. Update Purpose after archive.
## Requirements
### Requirement: issueify スキルは dev-workflow に属し 4 つの入力モードを持つ
dev-workflow プラグインは `plugins/dev-workflow/skills/issueify/SKILL.md`（frontmatter `name: issueify`）を配布し、`plugin.json` の `skills[]` に登録しなければならない（MUST）。スキルは、タスクメモ・バックログ md・TODO・受け入れ条件の無い issue を、測定可能な受け入れ条件付きの GitHub issue に変換する。入力は (1) インラインテキスト、(2) ファイルパス、(3) 引数なし（`docs/` とルート直下 md の未チェック項目・コード中の `TODO`/`FIXME`・受け入れ条件やラベルの無い open issue を自動発見して一括処理）、(4) `--existing`（既存 open issue の補筆のみ）の 4 モードを持たなければならない（MUST）。description は「これを issue にして」「タスクを issue 化」「バックログを issue に移行」の起動語を含む。

#### Scenario: スキルが登録されている
- **WHEN** `plugins/dev-workflow/.claude-plugin/plugin.json` の `skills[]` と `plugins/dev-workflow/skills/issueify/SKILL.md` の frontmatter を読む
- **THEN** `./skills/issueify` が登録され、frontmatter の `name` は `issueify` である

#### Scenario: 4 入力モードが定義されている
- **WHEN** SKILL.md の入力の節を読む
- **THEN** インラインテキスト・ファイルパス・引数なし（自動発見）・`--existing` の 4 モードが定義されている

### Requirement: 原子化・測定可能な受け入れ条件・不足だけヒアリング・承認ゲート
スキルは、入力を 1 issue = 1 論理タスクに原子化し（MUST）、タスクごとに「これで何が変わるか（最大 3 行・技術用語禁止）」「やらないとどうなるか / 今のコスト（最大 3 行）」「概要」「触るファイル・関数（Grep / Glob で実在確認）」「受け入れ条件（実行コマンド + 期待値。テスト / API / UI / 成果物の 4 型）」「備考」の 6 節でドラフトを作り（MUST）、機械検証に変換できない項目を受け入れ条件に書いてはならない（MUST NOT）。ドラフトで埋められなかった箇所だけを AskUserQuestion でまとめて質問し（MUST）、導出できた項目は質問してはならない（MUST NOT）。起票・編集はユーザーの承認を得てから `gh issue create` / `gh issue edit` で行い（MUST）、承認なしに実行してはならない（MUST NOT）。リポジトリに issue テンプレートがあればその構造に合わせ、無ければ上の 6 節を使う。

#### Scenario: 承認前に起票しない
- **WHEN** ドラフトの一覧が提示された段階
- **THEN** SKILL.md は「ユーザーの承認を得てから `gh issue create`」を要求し、承認なしの起票を禁じている

#### Scenario: 受け入れ条件が機械検証可能な形に限られる
- **WHEN** SKILL.md の受け入れ条件の作り方を読む
- **THEN** テスト（exit 0）・API（curl とレスポンス期待値）・UI（再現可能な操作手順）・成果物（実在・grep）の 4 型が示され、主観基準を受け入れ条件に書かない旨がある

### Requirement: ラベル提案と issue 依存関係の張り方
スキルは起票時に、無人ループ単独で完結できるなら `agent-ready`、人間の承認や不可逆操作が絡むなら `needs-approval`、秘密情報・外部アカウント・ダッシュボード操作なら `human-only`、1 サイクルに収まらないなら `size:large` を提案しなければならない（MUST）。ユーザーがその場で承認した分は `agent-ready` を直接付けてよく、「あとで見る」分は `agent-proposed` で起票する。issue 間に実行順の依存があるときは GitHub ネイティブの issue dependencies（`gh api -X POST repos/<owner>/<repo>/issues/<後続>/dependencies/blocked_by -F issue_id=<前提の id>`）を張らなければならない（MUST）。元ファイルから移行した項目には「issue へ移行済み（#番号）」を追記し、削除はしない。

#### Scenario: 依存関係のコマンドが示されている
- **WHEN** SKILL.md の起票手順を読む
- **THEN** `dependencies/blocked_by` を使う `gh api` コマンドと、`issue_id` の取り方が記載されている

#### Scenario: ラベル 5 種の提案基準がある
- **WHEN** SKILL.md のラベル提案の節を読む
- **THEN** `agent-ready`・`needs-approval`・`human-only`・`size:large`・`agent-proposed` の基準が定義されている

### Requirement: 解散プラグインへの依存を持たない
`plugins/dev-workflow/skills/issueify/SKILL.md` は `loops`・`goalify`・`recipes/loop-dev-agent.md`・`agent-loop-template`・`/loops:` の文字列を含んではならない（MUST NOT）。無人ループへの言及は「loop-dev-agent（憲法は各リポの `docs/agent-loop.md`）」の形で行い、翻訳の規律は `plugins/dev-workflow/references/pr-body-format.md` を参照する。

#### Scenario: 旧プラグインの参照が 0 件
- **WHEN** SKILL.md で `loops`・`goalify`・`agent-loop-template` を grep する
- **THEN** ヒットは 0 件である

#### Scenario: 翻訳の規律の参照先が新パス
- **WHEN** SKILL.md のドラフト生成手順を読む
- **THEN** `plugins/dev-workflow/references/pr-body-format.md` への参照がある

