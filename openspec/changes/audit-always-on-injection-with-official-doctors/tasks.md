行番号は仕様づくりの時点（HEAD 07c0be97）の値。前のタスクの編集でずれるので、編集前に該当範囲を読む。

## 1. テストを先に書く

- [x] 1.1 思考の深さを文で指示する句（`よく考え`・`think deeply`・`think hard`・`think carefully`・`think step by step`、英語は大文字小文字を区別しない）を検出する検査ヘルパを足し、合成ファイルで「対象の句を検出してファイル名と行を出す」「`必ず確認する` と `IMPORTANT: Do NOT guess` は違反にしない」の 2 件のテストを書く。触る範囲: tests/injection-budget.bats:368-478（frontmatter 書式ガードのヘルパ群の前後に足す）、tests/injection-budget.bats:1242-1256（末尾にテストを足す）
- [x] 1.2 実リポジトリの `rules/*.md`・`CLAUDE.md`・`output-styles/*.md`・`plugins/*/skills/*/SKILL.md`・`.claude/commands/`・`.claude/skills/` に対象の句が無いことを確かめるテストを書き、失敗時の出力に `docs/injection-budget-review.md` を含める。この時点では `.claude/` の 2 ファイルで落ちることを確かめる。触る範囲: tests/injection-budget.bats:1242-1256（末尾に足す）
- [x] 1.3 `docs/injection-budget-review.md` が存在し、`/doctor prompt-audit`・`/skill-doctor`・`claude plugin details` の 3 つと Claude Code の版（`[0-9]+\.[0-9]+\.[0-9]+` の形。値は直書きしない）を含むこと、`CLAUDE.md` と `rules/` に `prompt-audit`・`skill-doctor` が無いことを確かめるテストを書く。触る範囲: tests/injection-budget.bats:1242-1256（「CLAUDE.md documents how to move the budget file」「the budget convention is not placed under rules/」の並びに足す）
- [x] 1.4 失敗時の出力が超過側・下振れ側の両方で `docs/injection-budget-review.md` を含むことを確かめるテストを書く。触る範囲: tests/injection-budget.bats:852-876（`report over` と `report under` を使う既存テストの並び）

## 2. 実装

- [x] 2.1 `report` の「取るべき行動」に、超過側・下振れ側の両方で `docs/injection-budget-review.md` を指す 1 行を足す。触る範囲: tests/injection-budget.bats:342-367（関数 `report`）
- [x] 2.2 「Think deeply. 」の 1 文を削る（前後の文は残す）。触る範囲: .claude/commands/opsx/explore.md:8、.claude/skills/openspec-explore/SKILL.md:12
- [x] 2.3 予算値の見直し手順を書く。内容は design.md「手順の文書に書く内容」のとおり（確かめた版 2.1.294 と日付 2026-10-08、3 コマンドの実行方法、出力の読み方、指摘の扱い、記録先と public リポジトリでの注意、数値目標を置かず結果を記録すること）。書き方は `docs/plugin-evals.md` に合わせる。触る範囲: docs/injection-budget-review.md（新規）、docs/plugin-evals.md:1-25（体裁の参考に読むだけ）

## 3. 確認

- [x] 3.1 `grep -rn 'よく考え' rules/` が 0 件であることを確かめる。触る範囲: なし（確認のみ）
- [x] 3.2 `scripts/test.sh injection-budget` と `scripts/test.sh agents-md-sync` が exit 0 であることを確かめる。`tests/injection-budget.txt`・`CLAUDE.md`・`AGENTS.md` に差分が無いことを `git status` で確かめる。触る範囲: なし（確認のみ）
- [x] 3.3 `scripts/test.sh` を引数なしで実行して exit 0 を確かめる。statusline のテストが 1 件だけ落ちたときは単独で再実行して判定する。触る範囲: なし（確認のみ）
- [ ] 3.4 PR 本文に、予算値を動かしていないこと（測定対象のバイト数がこの change で変わらないため）と、診断の指摘のうち範囲外にした 3 件（`CLAUDE.md` の CI の記述、`CLAUDE.md` のマージ手順、issueify の質問の仕方）を書く。あわせて、診断が旧モデル向けの言い回しに分類した強調語（`IMPORTANT`・`MUST`・`NEVER`、18 ファイル 34 箇所）を残した理由（openspec CLI の生成物で、再生成のたびに 34 箇所を直し直すことになる）を PR 本文と issue #712 のコメントに書く。範囲外の 3 件も issue #712 のコメントに残す。触る範囲: なし（PR 本文と issue コメント）
