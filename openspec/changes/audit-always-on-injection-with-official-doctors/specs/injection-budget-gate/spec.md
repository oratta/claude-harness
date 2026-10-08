## ADDED Requirements

### Requirement: 予算値を見直すときの診断手順を docs に置き、失敗時の出力から辿れる

予算値 `tests/injection-budget.txt` を見直すときに使う診断手順を、リポジトリの `docs/injection-budget-review.md` に置かなければならない（MUST）。この文書は次を含まなければならない（MUST）。

1. 3 つの診断コマンド `/doctor prompt-audit`・`/skill-doctor`・`claude plugin details <name>` の名前と、print モード（`claude -p`）での実行方法
2. 手順を確かめた Claude Code の版と日付
3. 診断結果の記録先（見直しの issue または PR へのコメント）と、個人の `~/.claude/skills/` にあるスキルの名前と中身を public な記録に載せないこと
4. 削減量の数値目標を置かず、削った結果（前後のバイト数）を記録すること

`tests/injection-budget.bats` の失敗時の出力は、超過側と下振れ側のどちらでも、この文書のパス `docs/injection-budget-review.md` を含まなければならない（MUST）。

この手順を `CLAUDE.md` と `rules/*.md` に書いてはならない（MUST NOT）。どちらも測定対象で、書いた分だけ固定分が増える。「予算ファイルの変更手続きを CLAUDE.md に定める」が求める `CLAUDE.md` の記述は、この要件で増やさない。

診断コマンドをテストや CI から実行してはならない（MUST NOT）。モデルを呼ぶため費用がかかり、結果が実行ごとに変わる。

#### Scenario: 手順の文書が 3 コマンドを挙げている

- **WHEN** `docs/injection-budget-review.md` を読む
- **THEN** `/doctor prompt-audit`・`/skill-doctor`・`claude plugin details` の 3 つの文字列がすべて現れる

#### Scenario: 手順の文書に確かめた版がある

- **WHEN** `grep -nE '[0-9]+\.[0-9]+\.[0-9]+' docs/injection-budget-review.md` を実行する
- **THEN** 1 件以上一致する

#### Scenario: 超過側の失敗時の出力から手順に辿れる

- **WHEN** 実測が予算を超える合成値で失敗時の出力を作る
- **THEN** 出力に `docs/injection-budget-review.md` が含まれる

#### Scenario: 下振れ側の失敗時の出力から手順に辿れる

- **WHEN** 予算が実測の 1.1 倍を超える合成値で失敗時の出力を作る
- **THEN** 出力に `docs/injection-budget-review.md` が含まれる

#### Scenario: 手順は CLAUDE.md と rules に書かれていない

- **WHEN** `grep -rn 'prompt-audit\|skill-doctor' CLAUDE.md rules/` を実行する
- **THEN** 一致件数が 0 件である

### Requirement: 思考の深さを文で指示する言い回しを置かない

`rules/*.md`・`CLAUDE.md`・`output-styles/*.md`・`plugins/*/skills/*/SKILL.md`（本文を含む）・`.claude/commands/` 配下・`.claude/skills/` 配下のファイルは、思考の深さを文で指示する言い回しを含んではならない（MUST NOT）。対象の句は `よく考え`・`think deeply`・`think hard`・`think carefully`・`think step by step` とし、英語の句は大文字小文字を区別しない。

`scripts/test.sh` の全件実行に、この条件を確かめるテストが含まれなければならない（MUST）。テストが落ちたときの出力は、該当したファイルと行、および `docs/injection-budget-review.md` を示さなければならない（MUST）。

`必ず`・`絶対`・`MUST`・`IMPORTANT` などの強調語は、この要件の対象にしてはならない（MUST NOT）。破壊的操作やデータ消失の防止に理由つきで使われているものが大半で、一律に禁じると必要な制約まで落ちる。

`plugins/` 配下のうち対象にするのは `plugins/*/skills/*/SKILL.md` だけとする。スキルの `references/` などそれ以外のファイルは対象にしない（必要なときだけ読まれる文書で、issue #712 が名指しした「rules とスキル」の外にある）。

**守備範囲**: 違反が入ってくる経路は 2 つで、openspec CLI が `.claude/` 配下を再生成したときと、対象ファイルを手で編集したときである。拾うのは上の 5 つの句が 1 行の中にそのまま現れた場合だけとする。5 つの句に当たらない言い換え（`じっくり考えて`・`深く考えて`・`ultrathink`・`think thoroughly` など）と、改行をまたぐ形（`Think` の次の行に `deeply`）は通る。逆に `think hard-coded` のように思考の深さと無関係な英文にも当たりうる。見つかるたびに句を足したり例外を足したりして、取りこぼしと誤検出を塞ぎ切ることを完了条件にしない。言い換えを見つける役は診断コマンド `/doctor prompt-audit` が担う。

#### Scenario: rules に「よく考え」が無い

- **WHEN** `grep -rn 'よく考え' rules/` を実行する
- **THEN** 一致件数が 0 件である

#### Scenario: 現状のリポジトリが条件を満たす

- **WHEN** リポジトリのルートで `scripts/test.sh injection-budget` を実行する
- **THEN** exit code が 0 で、対象の句を確かめるテストが `ok` になっている

#### Scenario: 対象の句が戻ってきたら検出する

- **WHEN** 一時ディレクトリに `Enter explore mode. Think deeply.` を含むファイルを置き、検査ヘルパに渡す
- **THEN** 違反として検出され、該当ファイル名と行が出力される

#### Scenario: 強調語は違反にならない

- **WHEN** 一時ディレクトリに `必ず確認する` と `IMPORTANT: Do NOT guess` を含み、対象の句を含まないファイルを置き、検査ヘルパに渡す
- **THEN** 違反は検出されない
