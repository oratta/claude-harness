## MODIFIED Requirements

### Requirement: 入口分岐は5分岐で対象 issue を確定する
`/develop` コマンド定義（`commands/develop.md`。`/work-issue` はそのエイリアス）は、引数から記録先を確定するための分岐として以下の5つをすべて明記しなければならない（MUST）。既存 issue が特定できる分岐（①③）の挙動は従来から変更してはならない（MUST NOT）。issue を特定できない分岐（②④⑤）の既定は develop スキルの入口 0（issue を切らず Draft PR を記録先にする）であり、issueify フォールバックは「追跡・キュー・議論が要る」とユーザーが選んだときに限る（SHALL）。

- ① 番号・URL で既存 issue が特定できる → その issue を記録先にして develop パイプラインへ
- ② 番号指定だが issue が存在しない → typo 確認を先に行い、ユーザーが希望した場合のみ issueify フォールバックへ。希望しなければ入口 0（Draft PR）へ
- ③ 自然文が既存 issue にマッチする → その issue を記録先にして develop パイプラインへ
- ④ 自然文がどの既存 issue にもマッチしない → 入口 0（Draft PR を記録先）へ。追跡・キュー・議論が要る場合のみ issueify フォールバックへ
- ⑤ 引数なし → open issue 一覧に「新しいタスクを説明して着手する（issue は切らない）」と「新しいタスクを説明して issue 化する」の選択肢を加えて提示する

#### Scenario: 番号不存在は typo 確認が先行する
- **WHEN** `/develop 42` が渡され `gh issue view 42` が失敗する
- **THEN** コマンド定義は新規起票に直行せず、近い番号・タイトルの候補を提示して意図を確認する手順を指示し、ユーザーが新規作成を選んだ場合のみ issueify フォールバックに進み、それ以外は入口 0 に進む

#### Scenario: 自然文マッチなしは Draft PR が既定
- **WHEN** 自然文の依頼がどの open issue にもマッチしない
- **THEN** コマンド定義は issue を切らずに入口 0（Draft PR を記録先）へ進むことを既定とし、追跡・キュー・議論が要る場合に限り issueify フォールバック（起票 → 起票番号で develop パイプライン接続）を指示する

#### Scenario: 引数なしの一覧に着手と起票の両方の選択肢が載る
- **WHEN** `/develop` が引数なしで起動される
- **THEN** open issue 一覧とあわせて「新しいタスクを説明して着手する（issue は切らない）」と「新しいタスクを説明して issue 化する」の選択肢が提示される

### Requirement: issueify フォールバックは loops-issueify を path-discovery で解決する
issueify フォールバックは、`loops-issueify/SKILL.md` を develop と同一の path-discovery パターン（CLAUDE_PLUGIN_ROOT 起点 → marketplaces → installed の順）で探して Read し、その手順（原子化 → 測定可能な受け入れ条件 → 承認 → 起票）をインライン実行しなければならない（MUST）。Skill tool は使用してはならない（MUST NOT）。

#### Scenario: loops プラグイン導入済み環境での起票
- **WHEN** path-discovery で `loops-issueify/SKILL.md` が見つかる
- **THEN** その SKILL.md の手順に従って issue を起票し、起票された番号を develop パイプラインに渡す

#### Scenario: loops プラグイン未導入時は fail-soft で縮退する
- **WHEN** path-discovery で `loops-issueify/SKILL.md` が見つからない
- **THEN** コマンド定義に明記された最小手順（「これで何が変わるか」「やらないとどうなるか / 今のコスト」・概要・触るファイル・測定可能な受け入れ条件を含むドラフトを提示し、承認後 `gh issue create` で起票）にフォールバックし、エラーで停止しない

### Requirement: 複数 issue に割れた場合は着手1件を選択する
issueify の原子化により依頼が複数 issue に割れた場合、全件を起票した上で着手する1件をユーザーに選択させ、選択された1件のみを develop パイプラインに渡さなければならない（MUST）。残りは起票のみで実行しない（MUST NOT）。

#### Scenario: 依頼が2 issue に分割された
- **WHEN** issueify の原子化が依頼を2つの独立した issue に分割し、両方が起票された
- **THEN** どちらに着手するかをユーザーに確認し、選ばれた1件だけを develop パイプラインに渡し、もう1件は起票のみで終了する

## ADDED Requirements

### Requirement: /work-issue は /develop のエイリアスである
`commands/work-issue.md` は独自の手順を持たず、`$ARGUMENTS` をそのまま `/develop` の手順に渡すエイリアスでなければならない（MUST）。5 分岐・issueify フォールバック・承認ゲートの本文は `commands/develop.md` の 1 箇所にのみ存在する（SHALL）。

#### Scenario: エイリアスが本文を持たない
- **WHEN** `commands/work-issue.md` を読む
- **THEN** `/develop` のエイリアスである旨と `commands/develop.md` への参照だけがあり、5 分岐の本文は書かれていない
