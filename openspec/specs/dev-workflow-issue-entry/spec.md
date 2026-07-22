# dev-workflow-issue-entry Specification

## Purpose
TBD - created by archiving change dev-workflow-work-issue-issueify-fallback. Update Purpose after archive.
## Requirements
### Requirement: 入口分岐は5分岐で対象 issue を確定する
`/work-issue` コマンド定義は、引数から対象 issue を確定するための分岐として以下の5つをすべて明記しなければならない（MUST）。既存 issue が特定できる分岐（①③）の挙動は従来から変更してはならない（MUST NOT）。

- ① 番号・URL で既存 issue が特定できる → 従来どおり github-issue パイプラインへ
- ② 番号指定だが issue が存在しない → typo 確認を先に行い、ユーザーが希望した場合のみ issueify フォールバックへ
- ③ 自然文が既存 issue にマッチする → 従来どおり github-issue パイプラインへ
- ④ 自然文がどの既存 issue にもマッチしない → issueify フォールバックへ
- ⑤ 引数なし → open issue 一覧に「新しいタスクを説明して issue 化する」選択肢を加えて提示する

#### Scenario: 番号不存在は typo 確認が先行する
- **WHEN** `/work-issue 42` が渡され `gh issue view 42` が失敗する
- **THEN** コマンド定義は新規起票に直行せず、近い番号・タイトルの候補を提示して意図を確認する手順を指示し、ユーザーが新規作成を選んだ場合のみ issueify フォールバックに進む

#### Scenario: 自然文マッチなしで issueify フォールバックが発動する
- **WHEN** 自然文の依頼がどの open issue にもマッチしない
- **THEN** コマンド定義は「新規 issue 化して進めるか」の確認を経て issueify フォールバック（起票 → 起票番号で github-issue パイプライン接続）を指示する

#### Scenario: 引数なしの一覧に新規作成の選択肢が載る
- **WHEN** `/work-issue` が引数なしで起動される
- **THEN** open issue 一覧とあわせて「新しいタスクを説明して issue 化する」選択肢が提示される

### Requirement: issueify フォールバックは loops-issueify を path-discovery で解決する
issueify フォールバックは、`loops-issueify/SKILL.md` を github-issue と同一の path-discovery パターン（CLAUDE_PLUGIN_ROOT 起点 → marketplaces → installed の順）で探して Read し、その手順（原子化 → 測定可能な受け入れ条件 → 承認 → 起票）をインライン実行しなければならない（MUST）。Skill tool は使用してはならない（MUST NOT）。

#### Scenario: loops プラグイン導入済み環境での起票
- **WHEN** path-discovery で `loops-issueify/SKILL.md` が見つかる
- **THEN** その SKILL.md の手順に従って issue を起票し、起票された番号を github-issue パイプラインに渡す

#### Scenario: loops プラグイン未導入時は fail-soft で縮退する
- **WHEN** path-discovery で `loops-issueify/SKILL.md` が見つからない
- **THEN** コマンド定義に明記された最小手順（概要・触るファイル・測定可能な受け入れ条件を含むドラフトを提示し、承認後 `gh issue create` で起票）にフォールバックし、エラーで停止しない

### Requirement: 複数 issue に割れた場合は着手1件を選択する
issueify の原子化により依頼が複数 issue に割れた場合、全件を起票した上で着手する1件をユーザーに選択させ、選択された1件のみを github-issue パイプラインに渡さなければならない（MUST）。残りは起票のみで実行しない（MUST NOT）。

#### Scenario: 依頼が2 issue に分割された
- **WHEN** issueify の原子化が依頼を2つの独立した issue に分割し、両方が起票された
- **THEN** どちらに着手するかをユーザーに確認し、選ばれた1件だけを github-issue パイプラインに渡し、もう1件は起票のみで終了する

### Requirement: 起票前のユーザー承認ゲートを維持する
issueify フォールバック経由の起票は、loops-issueify の承認ゲート（ドラフト提示 → ユーザー承認 → `gh issue create`）を維持しなければならない（MUST）。fail-soft の縮退手順でも承認なしに起票してはならない（MUST NOT）。

#### Scenario: 承認前に起票されない
- **WHEN** issueify フォールバックが issue ドラフトを生成した
- **THEN** ドラフトの提示とユーザーの承認を経てから `gh issue create` が実行される

