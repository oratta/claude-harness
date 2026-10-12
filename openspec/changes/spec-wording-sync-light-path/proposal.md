## Why

仕様化判断は「する」「しない」の二択で、「する」になると直す量に関係なく artifact 一式（proposal / design / tasks / specs）と別担当（R1）の仕様レビューが付く。既存の仕様が文言の細部まで書いてあると、数行の直しでも「既存 capability の要件を変える」に当たって「する」になる。genetta-inc/flatmate#1513 はコード 6 行に対し openspec 305 行と仕様レビュー 1 周、flatmate#1515 はコード 15 行に対し openspec 258 行と仕様レビュー 2 周だった（issue #973 の 2026-10-12 のコメント「2 点目の調査結果」）。

主の決定（issue #973、2026-10-12 のコメント「2 点目の前半『仕様の文言合わせの軽い通し方』を作る」）: 既存の仕様の文言を実装に合わせて直すだけの変更は、仕様の差分 1 ファイルだけにして R1 の仕様レビューを省く。実装後レビュー（pr-review-gate）は変えない（同日のコメント「2 点目の後半」）。

## What Changes

- 仕様化判断「する」の中に「文言合わせの通し方」を足す。対象は、既存の要件の文を実装に合わせて直すだけで、新しい要件を足さず、設計の選択が無く、1 つの capability の spec に収まる変更
- 当てる条件は、記録先の受け入れ条件に「どの仕様のどの文をどう直すか」が書けていること。書けていない変更と迷う変更は、これまでどおり artifact 一式と R1
- 成果物は `openspec/changes/<name>/specs/<capability>/spec.md` の 1 ファイルだけ（`## MODIFIED Requirements` だけ）。proposal・design・tasks は作らない。作業項目と触る範囲は W の return に書く
- 仕様化判断のコメントの 1 行目は変えず、2 行目以降に `通し方: 文言合わせ` の行と、直す要件ごとの `直す文:` の行を書く。本体はこの行を記録先で確かめて R1 を起こさず実装へ進める
- pr-review-gate の合格処理の整合表に行を 1 つ足す。`通し方: 文言合わせ` の行がある PR では `仕様レビュー: APPROVE` を求めず、代わりに archive 済みの差分が 1 ファイルで、MODIFIED だけで、要件名がすべて `直す文:` の行にあることを実測する
- 仕様宣言に 3 つ目の形（`仕様レビュー: 省いた（文言合わせ。<URL>）`）を足す
- proposal.md の無い change は `openspec validate <name> --strict` が `Unknown item` で落ちるので、この通し方の検証コマンドを `--type change` 付きにする（実測は design.md）

変えないもの: 仕様化判断の 1 行目の正規表現、`仕様レビュー:` の 1 行目の正規表現、通し方の行が無い「する」と「しない」の扱い、実装後レビューの重さ（light / full の判定・三表の照合・宣言・動作確認）、テスト作成が全経路で必須であること。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-spec-review`: 文言合わせの通し方の Requirement を足す（対象・当てる条件・記録の書式・成果物・途中で対象から外れたときの戻し方・守備範囲）。「書いた仕様は実装前に別コンテキストがレビューする」に、この通し方だけを例外とする文を足す
- `dev-workflow-develop`: 「1 ループは W→R1→W→G の順で回る」に、この通し方では (2) を飛ばす分岐を足す。「実行モードと unmanned の責務分割」に、unmanned でも同じ条件で当てることを足す。「W の仕様化経路は openspec CLI だけで進める」に、この通し方の検証コマンドと archive の確認を足す
- `dev-workflow-pr-review-gate`: 「仕様宣言を通過の必須点に加える」の本文の形を 2 つから 3 つにする。「合格処理は仕様宣言の実在と issue 記録との整合を実測する」に、通し方の行がある場合の照合と守備範囲を足す

## Impact

- 指示書: `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（Step B）、`references/roles/worker/spec.md`・`worker/common.md`・`worker/implement.md`・`worker/finish.md`、`references/roles/spec-reviewer.md`（判断記録の契約）、`skills/develop/SKILL.md`（1 ループの (1)(2)・実行モード）、`skills/pr-review-gate/stages/pass.md`（整合表）、`skills/pr-review-gate/declarations.md`（仕様宣言の形）
- テスト: `plugins/dev-workflow/tests/` に bats を 1 本足す。既存の `spec-decision-and-review.bats`・`pr-review-gate-spec-declaration.bats`・`develop-roles.bats`・`develop-skill.bats` は通ったままにする
- 触らないもの: `plugins/dev-workflow/scripts/`、`stages/triage.md`・`stages/hold.md`・`stages/reviewer-brief.md`（issue #973 の別の change が触る）
- 常時注入の予算（`tests/injection-budget.txt`）: 触るファイルはどれも常時注入の対象外なので動かない見込み。動いたら PR 本文に理由を書く
- 受け入れたリスク（主の決定）: 仕様の書き換えの誤り（直す範囲より広く書き換える・要件の文を落とす）を見るのが実装後レビューだけになる
- 記録先: issue #973。PR は `Refs #973`（この change は #973 の 3 つの change の 1 つで、issue を閉じない）
