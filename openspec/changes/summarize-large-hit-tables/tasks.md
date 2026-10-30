# Tasks

## 1. 共通照合スクリプトの全ヒット要約

- [ ] 1.1 先にテストを足す。全ヒット 2,100 行の語の要約が exit 0、シェルのパイプで作った行数とハッシュが書き込み不可の `.git` でも一致、検索範囲を狭めた要約の拒否、行数違い・ハッシュ違いの `summary:` 出力、ちょうど 50 行の語の要約の拒否と 51 行の受理、全ヒットに無い 4 列の行の `extra:`、`一致` の行の拒否、値の形式の不正の拒否、`--head` 付きの拒否、4 列の表を省いた要約、バイナリのヒットを含む語の要約、50 行を超える語の全行の表の受理。検証: `bats plugins/dev-workflow/tests/review-hit-set.bats` で新しいテストだけが落ちる。触る範囲: plugins/dev-workflow/tests/review-hit-set.bats:390-末尾
- [ ] 1.2 `review-hit-set.py` に、`全ヒット要約:` の行の検出、`SUMMARY_MIN_HITS = 50`、解析なしのバイト列での行数と `git hash-object --stdin` の計算、4 列の行の検査、`--head` との組み合わせの拒否を足す。検索コマンドは今の `parse_command` を通す。全行の表の経路は変えない。検証: `bats plugins/dev-workflow/tests/review-hit-set.bats` が全件 pass。触る範囲: plugins/dev-workflow/scripts/review-hit-set.py:17-27（定数）、plugins/dev-workflow/scripts/review-hit-set.py:282-338（actual_hits と main）

## 2. レビュアーとゲートの手順

- [ ] 2.1 reviewer-brief のレビュアー向け指示ブロックに `全ヒット要約` の段落を足す（`**共通一覧契約` の段落の直後に、`**` で始まる別の段落として置く）。行数とハッシュを作るコマンド、標準出力だけで完結すること、読み方、順 3 は全行のままであることを書く。`照合表` の項目と保証範囲の文も直す。検証: pr-review-gate-skill.bats に、指示ブロックが手順と下限 50 を含み、下限がスクリプトの定数と同じ値であることを確かめるテストを足して pass。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:29（照合表の項目）、plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:34-36（共通一覧契約の直後と保証範囲）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:987-1070
- [ ] 2.2 gate-runner の「一周目の三表を機械照合する」の 2 番に、`全ヒット要約:` の行を持つ表も同じコマンドに渡し、全行の本文が無いことを表の欠落として扱わないと書く。検証: develop-roles.bats の同じ節のテストにトークンを足して pass。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:43、plugins/dev-workflow/tests/develop-roles.bats:701-705

## 3. 記録と全体の確認

- [ ] 3.1 変更の記録 `plugins/dev-workflow/changes/1457.md` を書く。検証: ファイルがあり、既存の記録と同じ形である。触る範囲: plugins/dev-workflow/changes/1457.md（新規）
- [ ] 3.2 全体を確かめる。検証: `bats plugins/dev-workflow/tests/review-hit-set.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/develop-roles.bats` が全件 pass、`openspec validate summarize-large-hit-tables --type change --strict` が通る、`git diff origin/main --stat` に triage.md と SKILL.md が無い。触る範囲: なし（確認のみ）
