# Tasks

## 1. G の周の終わりの条件の段

- [x] 1.1 `pr-review-gate-skill.bats` に、段落「周の終わりの止める指摘の条件」が 1 か所にあること・順 6 と直し方の判定と順 5 の振り分けより先に当てること・`成り立つ予定が無い` が段 B の表のほかにもあること・閉じるのがその行だけで `条件を書けない` を閉じないこと・3 つの歯止め（受け入れ条件またはこの PR が触れる openspec の spec（delta spec を含む）の文が求める場面、順 5 の「この PR で直す」、artifact の想定を根拠にしない）・決められないときに新しい質問も保留も足さないこと・`条件の確認待ち` と `needs-approval` をこの段で使わないこと・PR コメントと仕分け欄の記録・全件を閉じたときの扱い・1 周目と順 3・順 4 からの落とし込みに当てないこと・守備範囲の文を検査するテストを足し、落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1628-1640
- [x] 1.2 `triage.md` の周の終わりの段落の書き出しを「段落「周の終わりの止める指摘の条件」を通したあとに止める指摘が残っていれば」の形に直し、その直後に段落を足し、手順 3 の言い直しをそろえる。「直し方の判定の受領」は変えない。1.1 のテストと、順 2〜5 の判定の既存のテスト（`grep -F '2 周目以降の周の終わり'` で段落を取るテストを含む）が通ることで確かめる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:32、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:133

## 2. 合格処理の前提

- [x] 2.1 `pr-review-gate-skill.bats` の verdict (#354) のテストを、`pass.md` の除外に「G が周の終わりの止める指摘の条件で閉じたもの」が入る形に直す。spec の読み先を `openspec/changes/pr-review-end-of-round-condition/specs/dev-workflow-pr-review-gate/spec.md` にし（無ければ main spec）、MODIFIED の本文と Scenario の行数に合わせて数を直し、条件で閉じたものの行数の検査を足す。落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:864-875
- [x] 2.2 `pass.md` の手順 5 の前提の除外を直し、閉じる経路の括弧書きに段落「周の終わりの止める指摘の条件」を足す。2.1 のテストが通ることで確かめる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:57

## 3. develop の本体の手順

- [x] 3.1 `spec-decision-and-review.bats` の condition check (#1121) のテストに、本体の手順を当てないこと・G が `stages/triage.md` で確かめること・決める役に渡すのが `needs-fix-check` で渡された指摘に限ることの検査を足し、落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/spec-decision-and-review.bats:304-310
- [x] 3.2 `fix-check.md` の PR のレビューの文を直す。`needs-fix-check` には当てない、の語は残す。3.1 のテストが通ることで確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/fix-check.md:30

## 4. 記録と確認

- [x] 4.1 `plugins/dev-workflow/changes/1486.md` を書く。変えたこと・変えていないこと・戻し方と、#1436 との間で後から入る側に再適用が要ることを含める。触る範囲: plugins/dev-workflow/changes/1486.md（新規）
- [x] 4.2 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/spec-decision-and-review.bats plugins/dev-workflow/tests/develop-roles.bats` と、`grep -n '成り立つ予定が無い' plugins/dev-workflow/skills/pr-review-gate/stages/triage.md` が段 B の表のほかに 1 件以上あることを確かめ、`openspec validate pr-review-end-of-round-condition --type change --strict` を通す。バージョンは上げない。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats、plugins/dev-workflow/tests/spec-decision-and-review.bats、plugins/dev-workflow/tests/develop-roles.bats
