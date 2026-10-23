## 1. 検査を先に足す

- [x] 1.1 `tests/owner-question-style.bats` に受け入れ条件の検査（論点の定義と書き分けが 2 つの文書にある・実例の書き直しが 2 つで各 4 行以内・宣言の雛形の 2 つの形と外した文が無いこと・子の停止の記録の `主に聞く理由:` に論点の有無）を足し、「番号を主語にせず」と例が 1 つの検査を新しい決まりに合わせる。否定の検査は行末に `|| return 1` を付け、`tests/bats-assertion-guard.bats` の検査を通す。`bats tests/owner-question-style.bats` が文書の変更前に落ち、変更後に通ることで確かめる。触る範囲: tests/owner-question-style.bats:74-84、tests/owner-question-style.bats:148-224

## 2. 正本の型

- [x] 2.1 正本 `output-styles/readable.md` の節 3 に論点の定義と書き分け、1 行目の質問・番号は末尾の URL にだけ・困りごとが無ければ書かない・新たに生じるリスクだけ・論点なしは 3〜4 行を足し、例を論点ありの 1 つと実例 2 つの論点なしの書き直しにする。3〜4 行は区切りより上の行数と書き、例の語は特定の repo の用語を使わない（予算の中で直す）。`bats tests/owner-question-style.bats` で確かめる。触る範囲: output-styles/readable.md:39-89（節 3「判断を求めるときは、質問から書いて、推奨まで出す」）
- [x] 2.2 短い版 `rules/communication-style.md` の 3 番目に同じ要点を詰めて足す。`bats tests/owner-question-style.bats` と `bats tests/injection-budget.bats`（予算は動かさない）で確かめる。触る範囲: rules/communication-style.md:10

## 3. 返信前チェックの言い換え

- [x] 3.1 `rules/perspective-casting.md` の手順 2 を「判断に必要な観点を特定する」に言い換え、casting の SKILL.md と eval の prompt 2 つも揃える。`bats plugins/casting/tests/casting-structure.bats plugins/casting/tests/casting-consultation.bats plugins/casting/tests/casting-delegation.bats tests/always-on-injection-scope.bats` で確かめる。触る範囲: rules/perspective-casting.md:6、plugins/casting/skills/casting/SKILL.md:61、plugins/casting/evals/casting-escalate-sanctuary/prompt.md:8、plugins/casting/evals/casting-no-escalate-delegated/prompt.md:8

## 4. ゲートの宣言と保留の段

- [x] 4.1 pr-review-gate `declarations.md` の手順 3 の「主のリスク許容が必要」の雛形の 4 行目を論点なし／論点ありの 2 つの形にし、「この形式以外で主にリスク承認を求めない」と「これを許容するか」を外し、依頼文は正本の型で書くとする。行頭の 2 文言・`対象 HEAD:` 行・`主の回答: 許容` は変えない。`bats tests/owner-question-style.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats plugins/dev-workflow/tests/pr-review-gate-index.bats plugins/dev-workflow/tests/pr-review-gate-spec-declaration.bats` で確かめる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/declarations.md:18-69（手順 3「リスク宣言」）
- [x] 4.2 `stages/hold.md` に、宣言が論点なしのときは依頼も論点なしの 3〜4 行で書き、宣言を写さないことを書く。同じ bats で確かめる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:61
- [x] 4.3 `stages/hold.md` の論点なしの依頼の文に、返事の渡し方の案内は答え方の行に畳み、満たさなかった条件は区切りの下に置くことを足す（仕様の pr-review-gate の ADDED の文と揃える）。`bats tests/owner-question-style.bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` で確かめる。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:61

## 5. develop の子の停止の記録と親の手順

- [x] 5.1 `references/epic-child-stop.md` の記録の `主に聞く理由:` に論点の有無を添え、`受け入れるリスク:` を新たに生じるものだけにする（7 項目の名前と並びは変えない）。`bats tests/owner-question-style.bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/epic-dispatch.bats` で確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:21-30
- [x] 5.2 `references/epic.md` の手順 8 の「親経由のリスク許容の依頼」を、子の記録の推奨を主に OK してもらう報告として正本の型で書く形に置き換える（答えとして打つ語を親のタブで打つ点は残す）。`bats plugins/dev-workflow/tests/develop-skill.bats plugins/dev-workflow/tests/parent-merge.bats` で確かめる。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:55（手順 8）
- [x] 5.3 `references/ci-watch.md` のマージ待ちの子の記録の例を、`主に聞く理由:` に論点なし、`受け入れるリスク:` に新たに生じるものだけの形にする。`bats tests/owner-question-style.bats` で確かめる。触る範囲: plugins/dev-workflow/references/ci-watch.md:80-84

## 6. 変更の記録

- [x] 6.1 変更の記録 `plugins/dev-workflow/changes/1209.md` と `plugins/casting/changes/1209.md` を書く（何を変えたか・仕様化への切り替えと仕様レビューで直したこと・触らないもの・戻し方）。ファイルがあり内容が差分と食い違わないことで確かめる。触る範囲: plugins/dev-workflow/changes/1209.md（新規）、plugins/casting/changes/1209.md（新規）

## Workflow follow-up

- PR #1262 本文の実装メモにある「openspec/specs の 3 つに古い文言が残る」の行は、この change の archive で解消するので finish の段で直す
- 仕様レビュー（R1）の APPROVE のあと、archive して仕様宣言を出す
