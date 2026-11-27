## Why

PR #1513（#1011）の独立レビューで、段 C の親の取得の手順に止めない指摘が 8 件出た（issue #1519）。G が手順どおりに走らせると、親が見えない 404 を「親が無い」と読む、`HTTP 404` に当たらない取り方になる、親の取得が段 B の後に回って段 B が親を知らないまま当てられる、といった誤りが起きる。手順書と main の spec の文を直す。

## What Changes

- `dev-workflow-pr-review-gate` の 3 つの要件の文を変える（文言だけ。新しい要件は足さない）
  - 段 C の要件: 親の取得コマンドの末尾に ` 2>&1`、取得を「段 B の前に済ませる」、やり直しの出力も同じ判定にかける、親の取得が失敗し続けたときの答えは記録先の本文に足す、親の `sub_issues` に足す要求の形（`-X POST ... -F sub_issue_id=<id>`）、守備範囲の許す誤りに 2 件
  - 条件を主に聞くときの要件と、指摘を条件と結果の形で書かせる要件: `## 条件の答え` を読み書きする文に「親が別リポジトリなら親のリポジトリの本文（`stages/triage.md` の段 C の段落）」を足す
- 同じ語句を `stages/triage.md` の段 C の段落、`skills/develop/references/roles/gate-runner.md`、`stages/reviewer-brief.md` に反映する
- `tests/pr-review-gate-skill.bats` に、反映した語句ごとの検査を足す

## Capabilities

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 段 C の親の取得と `## 条件の答え` の読み書きの文を直す

## Impact

- 手順書 3 ファイルと main の spec、bats の検査。ゲートの判定の骨格・Gate Result の形式は変わらない
