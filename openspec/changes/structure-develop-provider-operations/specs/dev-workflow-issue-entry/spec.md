## MODIFIED Requirements
### Requirement: 入口分岐は5分岐で対象 issue を確定する
`/develop`（`commands/develop.md`）、そのエイリアス `/work-issue`、Codex の `$develop` は同じ `skills/develop/references/entry.md` を読み、引数から記録先を確定するための分岐として以下の5つをすべて明記しなければならない（MUST）。既存 issue が特定できる分岐（①③）の挙動は従来から変更してはならない（MUST NOT）。issue を特定できない分岐（②④⑤）の既定は develop スキルの入口 0（issue を切らず Draft PR を記録先にする）であり、issueify フォールバックは「追跡・キュー・議論が要る」とユーザーが選んだときに限る（SHALL）。

- ① 番号・URL で既存 issue が特定できる → その issue を記録先にして develop パイプラインへ
- ② 番号指定だが issue が存在しない → typo 確認を先に行い、ユーザーが希望した場合のみ issueify フォールバックへ。希望しなければ入口 0（Draft PR）へ
- ③ 自然文が既存 issue にマッチする → その issue を記録先にして develop パイプラインへ
- ④ 自然文がどの既存 issue にもマッチしない → 入口 0（Draft PR を記録先）へ。追跡・キュー・議論が要る場合のみ issueify フォールバックへ
- ⑤ 引数なし → open issue 一覧に「新しいタスクを説明して着手する（issue は切らない）」と「新しいタスクを説明して issue 化する」の選択肢を加えて提示する

#### Scenario: 番号不存在は typo 確認が先行する
- **WHEN** `/develop 42` が渡され `gh issue view 42` が失敗する
- **THEN** 共通入口は新規起票に直行せず、近い番号・タイトルの候補を提示して意図を確認する手順を指示し、ユーザーが新規作成を選んだ場合のみ issueify フォールバックに進み、それ以外は入口 0 に進む

#### Scenario: 自然文マッチなしは Draft PR が既定
- **WHEN** 自然文の依頼がどの open issue にもマッチしない
- **THEN** 共通入口は issue を切らずに入口 0（Draft PR を記録先）へ進むことを既定とし、追跡・キュー・議論が要る場合に限り issueify フォールバック（起票 → 起票番号で develop パイプライン接続）を指示する

#### Scenario: 引数なしの一覧に着手と起票の両方の選択肢が載る
- **WHEN** `/develop` が引数なしで起動される
- **THEN** open issue 一覧とあわせて「新しいタスクを説明して着手する（issue は切らない）」と「新しいタスクを説明して issue 化する」の選択肢が提示される
#### Scenario: 二つの本体の入口で同じ選択になる
- **WHEN** issue 番号/URL、番号不存在、自然文一致/不一致、引数なしの同じ fixture を `/develop` と `$develop` の入口へ渡す
- **THEN** 同じ共通入口と 5 分岐を使い、同じ記録先または同じ問いを返す。承認を要する起票を飛ばさない

### Requirement: /work-issue は /develop のエイリアスである
`commands/work-issue.md` は独自の手順を持たず、`$ARGUMENTS` をそのまま `/develop` の手順に渡すエイリアスでなければならない（MUST）。5 分岐・issueify フォールバック・承認ゲートの本文は 両本体から読む `skills/develop/references/entry.md` の 1 箇所にのみ存在する（SHALL）。

#### Scenario: エイリアスが本文を持たない
- **WHEN** `commands/work-issue.md` を読む
- **THEN** `/develop` のエイリアスである旨と `commands/develop.md` 経由の共通入口への参照だけがあり、5 分岐の本文は書かれていない

### Requirement: issueify フォールバックは同プラグイン内の issueify スキルを Read で解決する
issueify フォールバックは、同じ dev-workflow プラグイン内の `skills/issueify/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md`。`CLAUDE_PLUGIN_ROOT` が無い環境では `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/skills/issueify` → `~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/issueify` → `~/.claude/plugins/installed/*/dev-workflow/skills/issueify` の順で探す）を、台帳の plugin-root と本文読取に対応する本体別操作で解決して読み、その手順（原子化 → 測定可能な受け入れ条件 → 不足だけヒアリング → 承認 → 起票）をインライン実行しなければならない（MUST）。上記の root 探索順は Claude 用対応に置き、Codex 用対応はインストールした skill 実体から同じプラグインの root を解決しなければならない（MUST）。解決した本文を直接読み、別のスキル起動へ置き換えてはならない（MUST NOT）。他プラグイン（旧 loops）への path-discovery を行ってはならない（MUST NOT）。

#### Scenario: 同プラグイン内の issueify で起票する
- **WHEN** `${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md` が読める
- **THEN** その SKILL.md の手順に従って issue を起票し、起票された番号を develop パイプラインに渡す

#### Scenario: 名前順で先の古い marketplace dir があっても固定パスの版を使う
- **WHEN** `CLAUDE_PLUGIN_ROOT` が空で、`~/.claude/plugins/marketplaces/aaa-stale/plugins/dev-workflow/skills/issueify/SKILL.md` と `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/skills/issueify/SKILL.md` の両方がある
- **THEN** `oratta-claude-harness` 側の SKILL.md を読む

#### Scenario: SKILL.md が読めないときは fail-soft で縮退する
- **WHEN** 上の探索で `skills/issueify/SKILL.md` が見つからない
- **THEN** コマンド定義に明記された最小手順（「これで何が変わるか」「やらないとどうなるか / 今のコスト」・概要・触るファイル・測定可能な受け入れ条件を含むドラフトを提示し、承認後 `gh issue create` で起票）にフォールバックし、エラーで停止しない

## ADDED Requirements
### Requirement: PR の指定は共通入口で型を確かめる
共通入口は PR URL または PR 番号を与えられたとき PR を明示照会し、既存 develop の記録先・引継ぎ規則で続けなければならない（MUST）。番号だけの issue 照会が失敗しても、PR の存在を確かめる前に番号不存在と扱ってはならない（MUST NOT）。ネットワーク失敗を不存在へ読み替えてはならない（MUST NOT）。
#### Scenario: 既存の PR を指定する
- **WHEN** `/develop` と `$develop` に同じ既存 PR 番号または URL を渡す
- **THEN** 同じ PR/関連 issue と既存の引継ぎを照会し、同じ再開位置へ進み、新しい Draft PR を重複作成しない
### Requirement: Codex のエピック入口は未提供の実行を始めない
`$develop <エピック番号>` は、#1855 による Codex 本体のエピック実行が未導入なら、範囲外の理由と #1855 を示して停止しなければならない（MUST）。子の起動・分割や単発 issue への偽装をしてはならない（MUST NOT）。
#### Scenario: エピックと単発または子 issue を見分ける
- **WHEN** Codex で実際に発見した `$develop` へエピック番号、通常の issue 番号、親を持つ子 issue 番号をそれぞれ渡す
- **THEN** エピックだけは子を起動する前に理由付き停止し、通常と子 issue は共通の入口へ進む。Claude の既存エピック経路は変わらない
