## MODIFIED Requirements

### Requirement: 思考の深さを文で指示する言い回しを置かない

`rules/*.md`・`CLAUDE.md`・`output-styles/*.md`・`plugins/*/skills/*/SKILL.md`（本文を含む）・`.claude/commands/` 配下・`.claude/skills/` 配下・`.agents/skills/` 配下のファイルは、思考の深さを文で指示する言い回しを含んではならない（MUST NOT）。対象の句は `よく考え`・`think deeply`・`think hard`・`think carefully`・`think step by step` とし、英語の句は大文字小文字を区別しない。

`scripts/test.sh` の全件実行に、この条件を確かめるテストが含まれなければならない（MUST）。テストが落ちたときの出力は、該当したファイルと行、および `docs/injection-budget-review.md` を示さなければならない（MUST）。

`必ず`・`絶対`・`MUST`・`IMPORTANT` などの強調語は、この要件の対象にしてはならない（MUST NOT）。破壊的操作やデータ消失の防止に理由つきで使われているものが大半で、一律に禁じると必要な制約まで落ちる。

`plugins/` 配下のうち対象にするのは `plugins/*/skills/*/SKILL.md` だけとする。スキルの `references/` などそれ以外のファイルは対象にしない（必要なときだけ読まれる文書で、issue #712 が名指しした「rules とスキル」の外にある）。

**守備範囲**: 違反が入ってくる経路は 2 つで、openspec CLI が `.claude/`・`.agents/` 配下を再生成したときと、対象ファイルを手で編集したときである。拾うのは上の 5 つの句が 1 行の中にそのまま現れた場合だけとする。5 つの句に当たらない言い換え（`じっくり考えて`・`深く考えて`・`ultrathink`・`think thoroughly` など）と、改行をまたぐ形（`Think` の次の行に `deeply`）は通る。逆に `think hard-coded` のように思考の深さと無関係な英文にも当たりうる。見つかるたびに句を足したり例外を足したりして、取りこぼしと誤検出を塞ぎ切ることを完了条件にしない。言い換えを見つける役は診断コマンド `/doctor prompt-audit` が担う。

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
