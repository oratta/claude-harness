# Tasks

## 1. スクリプトの判定 4 に「PR 自身の commit が触れたか」を足す

- [x] 1.1 bats に失敗するテストを先に足す（PR 自身の commit が根拠ファイルの中で PR の変えた行（make_multiline_evidence の `L5 pr`）を同じ本文のまま元の位置より後ろ（L7 の直後）へ動かした → 終了コード 4・`CARRYOVER=if-judged`・`EVIDENCE_PR_CHANGED=evidence.txt`・`EVIDENCE_MAIN_ONLY=` なし・`NG:` なし／PR 自身の commit が根拠ファイルを変えて戻し、main が同じファイルの離れた行を変えた → 終了コード 4／根拠ファイル以外だけを変える PR 自身の commit と main の根拠ファイルの離れた行の変更が重なった → 終了コード 0・`PR_COMMITS=1`・`EVIDENCE_MAIN_ONLY=evidence.txt`）。動かす向きは後ろに限る（PR の変更は `-L5` / `+L5 pr` の順なので、後ろへ動かしたときだけ `-U0` の並びが前後で一致し、今のスクリプトで終了コード 0 になる。前へ動かすと今のスクリプトでも終了コード 4 になり、修正を証明するテストにならない）。前の 2 つが今のスクリプトで落ちることを `bats plugins/dev-workflow/tests/risk-carryover-check.bats` で確かめる。触る範囲: plugins/dev-workflow/tests/risk-carryover-check.bats:342-364（「PR's own commit rewrote the PR's evidence line」と「changed it back」の近く。共通の用意は make_multiline_evidence 46-57）
- [x] 1.2 判定 2 のループで merge commit でない commit ごとに `git diff --no-renames --name-only <親> <commit>` の結果を集め、判定 4 で PR 自身の差分が同じだった根拠ファイルがその集合に入っていれば `EVIDENCE_PR_CHANGED=` に回す（`EVIDENCE_DIFF_LINES=` にも数える。前後の diff が空・バイナリ・merge-base の NG の扱いと順序は変えない。Bash 3.2 の空配列の書き方を守る）。1.1 のテストと既存のテストが通ることを `bats plugins/dev-workflow/tests/risk-carryover-check.bats` で確かめる。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:83-90（変数の用意）、143-150（判定 2 のループの merge commit でない commit の枝）、209-217（判定 4 の比較）
- [x] 1.3 スクリプトの頭のコメント（判定 4 の説明・`EVIDENCE_MAIN_ONLY=` / `EVIDENCE_PR_CHANGED=` の条件・終了コード 4 の意味）と bats の頭のコメントを新しい条件に合わせ、`#1303` を添える。`grep -n '1303' plugins/dev-workflow/scripts/risk-carryover-check.sh plugins/dev-workflow/tests/risk-carryover-check.bats` で両方に出ることを確かめる。触る範囲: plugins/dev-workflow/scripts/risk-carryover-check.sh:18-41、plugins/dev-workflow/tests/risk-carryover-check.bats:1-9

## 2. ゲートの 3-c の説明を合わせる

- [x] 2.1 `stages/hold.md` 3-c の呼び方のブロックの `EVIDENCE_MAIN_ONLY=` / `EVIDENCE_PR_CHANGED=` / 終了コード 4 の説明、条件 1 の終了コード 4 の括弧書き、引き継ぎの根拠の行の「PR 自身の差分が変わった」の欄、引き継げないときに添える `EVIDENCE_PR_CHANGED=` の説明、「終了コード 4 の判定役」の冒頭の文を「PR 自身の差分が前後で違うか、PR 自身の commit が根拠ファイルに触れた」に直す（4 行の構造・行頭・判定役の入力は変えない）。`bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` の 3-c まわりのテストが通ることを確かめる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:29-35、44、54、60、66

## 3. 変更の記録

- [x] 3.1 `plugins/dev-workflow/changes/1303.md` を書く（何を・なぜ・issue の 2 案から案 2 を選んだ理由・残る隙間と新たな誤検出・読み方の変更）。`printf '%s\n' plugins/dev-workflow/changes/1303.md | FORBIDDEN_WORDS_NO_GH=1 bash plugins/dev-workflow/scripts/forbidden-words-check.sh --root . $(for d in tests/public-names/dict/*.txt; do printf -- '--dict %s ' "$d"; done)` が違反 0 件で終わることを確かめる（公開版にオーナーの固有名・アカウント名・PC の絶対パスを書かない）。触る範囲: plugins/dev-workflow/changes/1303.md（新規）

## Workflow follow-up

- 仕様レビュー（R1）の APPROVE を記録先で確かめてから実装に入る
- 実装と verify のあと、change を archive して PR を作る（PR 本文に `Closes #1303`）
