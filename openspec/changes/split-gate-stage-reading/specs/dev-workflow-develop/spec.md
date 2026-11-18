# Spec Delta

## MODIFIED Requirements

### Requirement: G は段ごとに要るファイルだけを読む

`plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` は、`skills/pr-review-gate/SKILL.md` を Read する指示を持ってはならない（MUST NOT）。pr-review-gate の手順 1〜5 を実行する義務の文は gate-runner.md に残さなければならない（MUST。既存要件「役割の指示書は references/roles/ に分かれている」と `develop-roles.bats` がその文を見る）。代わりに、G がどの時点でどのファイルを読むかを表で示さなければならない（MUST）。表は少なくとも次を含む: 起動したら `stages/prepare.md`、従来経路でレビューを自分で起動するときだけ `stages/review-run.md`、レビュー結果に指摘が残っていたら `stages/triage.md`、宣言を書く前に `declarations.md`、合格処理で `stages/pass.md`、主のリスク許容が要る・保留に入る・保留から再開するときは `stages/hold.md`。各入口の条件付き詳細は dev-workflow-pr-review-gate の「既存要件が SKILL.md に置いた内容は段のファイルを指す」の場面別の所在に従って読む（MUST）。条件が成り立たない詳細は読ませない（MUST NOT）。

gate-runner.md に残すのは、役割と入力、レビュー経路の判別、上の表、return の共通部分（宣言の正本への参照と Gate Result の共通欄）、段ごとの起動と入力の共通契約、モデルとコンテキスト上限の正本への参照とする（MUST）。三表の機械照合・補足受領・要約受領の分岐は stages/gate-triage.md を条件付きで読み、区画固有部分はそこから stages/gate-triage-partitions.md を読む（MUST）。特定の段でしか使わない G の規則（needs-reviewer の payload、従来経路のレビュー実行者の表と Codex の起動、Status ごとの return 書式、再開のうち段に固有のもの）は、その段の入口または条件付き詳細の「G として動くとき（develop）」節に置かなければならない（MUST）。

#### Scenario: SKILL.md 全体を読む指示が無い

- **WHEN** gate-runner.md を読む
- **THEN** `pr-review-gate/SKILL.md` を Read する指示が無く、pr-review-gate の手順 1〜5 を実行する義務の文と、段ごとに読むファイルの表がある

#### Scenario: return の書式が段のファイルにある

- **WHEN** `stages/pass.md`・`stages/triage.md`・`stages/hold.md`・`stages/prepare.md` とそれらが条件付きで指す詳細の「G として動くとき」節を読む
- **THEN** それぞれに passed・failed / needs-decider / review-incomplete・保留・needs-reviewer の return 書式がある

#### Scenario: 読み込み量の実測

- **WHEN** この変更の PR の prepare・review・triage・pass・hold の読むファイルを、固定した変更前 main と実装後の HEAD で測る
- **THEN** UTF-8 ロケールの wc -m の字数とファイルごとの内訳が PR 本文に記録されている。条件付き詳細も数え、減少量や 15K トークンの目標を合否に使わない

### Requirement: 既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す

既存要件が `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` に置く・含む・書くと定めた内容のうち、段の入口または条件付き詳細の「G として動くとき（develop）」節へ移すものは、移した先のその節を指すものとして読まなければならない（MUST）。移すものと移し先は次のとおりとする（MUST）。

| 内容 | 移し先 |
|---|---|
| needs-reviewer の payload（判定 `full（adapter 経路）` と、証拠欄 5 つの `未実行（adapter 経路）` を含む）と、その前に済ませること | `stages/prepare-reviewer.md` |
| レビュー要約を受け取った G が投稿する「レビュー実行者:」PR コメントの段落 | `stages/triage.md` |
| 従来経路のレビュー実行者の表と Codex の起動・完了確認（Codex の起動の事実 (a)(b)・companion の path-discovery・slash command 不可を含む） | `stages/review-run.md` |
| Status ごとの return 書式のうち failed 節・仕分け欄・needs-decider 節・review-incomplete | `stages/triage.md` |
| Status ごとの return 書式のうち保留欄 | `stages/hold.md` |
| Status ごとの return 書式のうち passed | `stages/pass.md` |
| 再開節のうち W の修正後の再レビュー | `stages/triage-convergence.md` |
| 再開節のうち決める役の裁定受領 | `stages/triage.md` |
| 一周目の三表・補足受領・要約受領の分岐 | `stages/gate-triage.md`（区画の詳細は `stages/gate-triage-partitions.md`） |
| 再開節のうち保留の解除 | `stages/hold-resume.md` |
| 許容済み PR で HEAD が動いたとき | `stages/carryover.md`（判定役の詳細は `stages/carryover-judge.md`） |

`周回:` 欄は Gate Result の共通欄として gate-runner.md に残す（MUST）。

この読み替えは、少なくとも次の 5 つの既存要件に掛かる: `dev-workflow-develop` の「役割の指示書は references/roles/ に分かれている」（Scenario「gate-runner.md は pr-review-gate を手順書として参照する」が見る needs-reviewer の項目と failed の原因分類を含む）・「adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す」・「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」（参照先の「`gate-runner.md`『needs-reviewer の return』節」は `stages/prepare-reviewer.md` の「G として動くとき（develop）」節を指す）、`dev-workflow-pr-review-gate` の「G の指示書の failed 節と周回欄が収束ルールに揃っている」・「Codex 経路と Task サブエージェント経路で同じ書式を渡す」（gate-runner.md の payload がブロックを指す行は、`stages/prepare-reviewer.md` の payload の行が `stages/reviewer-brief.md` を指すことで満たす）。gate-runner.md に残す内容（上の要件「G は段ごとに要るファイルだけを読む」が列挙したもの）を定めた既存要件は読み替えない。段の入口からさらに移す本文の所在は dev-workflow-pr-review-gate の場面別の移動先を参照する（MUST）。Status ごとの return を詳細へ移す場合も書式は逐語保存する。

#### Scenario: needs-reviewer の証拠欄の所在

- **WHEN** 既存要件「adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す」が gate-runner.md に求める payload を探す
- **THEN** `stages/prepare-reviewer.md` の「G として動くとき（develop）」節に、判定 `full（adapter 経路）` と証拠欄 5 つの `未実行（adapter 経路）` がある

#### Scenario: failed 節の所在

- **WHEN** 既存要件「G の指示書の failed 節と周回欄が収束ルールに揃っている」が gate-runner.md に求める failed 節・仕分け欄・needs-decider 節を探す
- **THEN** `stages/triage.md` の「G として動くとき（develop）」節にそれらがあり、保留欄は `stages/hold.md` の同じ節にある
