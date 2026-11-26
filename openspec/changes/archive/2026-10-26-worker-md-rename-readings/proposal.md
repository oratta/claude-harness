## Why

`references/roles/worker.md` は索引になり、W の手順は `worker/` の 4 本（`common.md`・`spec.md`・`implement.md`・`finish.md`）と `references/pre-classification.md` に移った。しかし spec 側は、dev-workflow-spec-review・dev-workflow-pr-review-gate・dev-workflow-subagent-waiting に「worker.md と書いた箇所は次のとおり読む」という読み替えの要件を置き、さらに dev-workflow-develop の要件「既存要件が worker.md に置いた内容は移し先のファイルを指す」が対応表を持って、その 3 つの読み替えの正本になっている。この対応表を求める要件のせいで、`worker.md` の節「旧節の移し先」も消せない（#1310 の調査で判明）。名指しを移し先のファイル名で直接書けば、読み替えも対応表も要らなくなる。

## What Changes

- 5 つの capability（dev-workflow-develop・dev-workflow-spec-review・dev-workflow-pr-review-gate・dev-workflow-subagent-waiting・loops-longrun-retirement）の要件・Scenario にある「worker.md」の名指しを、移し先のファイル名（`references/roles/worker/<段>.md`・`references/pre-classification.md`）に書き直す。`agents/worker.md`（エージェント定義）と、索引そのものを指す名指しは変えない
- 読み替えの要件 3 つ（spec-review・pr-review-gate・subagent-waiting）と、対応表を持つ要件 1 つ（dev-workflow-develop）を REMOVED にする。読み替えの要件が持っていた固有の Scenario（事前分類の参照先・対の検査の差し込み先・待ちの規約の所在）は、同じ capability の該当する要件に移す
- dev-workflow-develop の要件「W の指示書は索引・共通・段のファイルに分かれている」から、索引が旧節の移し先の対応表を持つ記述を外し、持ってはならないものに加える
- 実装の段で `plugins/dev-workflow/skills/develop/references/roles/worker.md` の節「旧節の移し先」の表を消し、冒頭の文言を合わせる

この change では spec 本体と worker.md はまだ書き換えない（仕様の差分だけ）。

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: 名指しの書き直し、読み替えの要件の削除、索引の要件から対応表の記述を外す
- `dev-workflow-spec-review`: 名指しの書き直し、読み替えの要件の削除
- `dev-workflow-pr-review-gate`: 名指しの書き直し、読み替えの要件の削除
- `dev-workflow-subagent-waiting`: 名指しの書き直し、読み替えの要件の削除
- `loops-longrun-retirement`: `roles/worker.md` の PR 本文の型の名指しを `roles/worker/finish.md` に直す

## Impact

- `openspec/specs/` の上の 5 spec と、`plugins/dev-workflow/skills/develop/references/roles/worker.md`（表の削除）。tests/ に旧節の表や読み替えを検査するものは無く、テストの変更は見込まない
- 本体と W のすること・手順書の中身は変えない
