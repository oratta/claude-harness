## Why

エピックの親は、回している途中で足された子（子が見つけた範囲外の問題・ゲートの仕分け・子の停止から起票されたもの）を、主に聞かずにほかの子とファイルがぶつからないという理由だけで起動した（flatmate のエピックで実害。主は「やってはいけない細かい話」と指摘し、一度出した「全部やっていい」も後から足された子に使われた）。主に頼まれていない子に、主の知らないうちにトークンが使われる。

## What Changes

- `references/epic.md` の「別セッション方式とサブエージェント方式に共通」に、回している途中で足された子は起票と紐付けまでで止め、起動する前に主へ 1 問で聞く手順と、主の承認が効く範囲（その時点で挙がっていた子だけ）を足す
- `references/epic-loop.md` の状態表の書き方に、起動待ちの子のステータス `未起動（主の判断待ち）` を足す
- 新しい部品・サブコマンド・状態の値は作らない。reviewer-brief.md は触らない

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: エピックの親が子を起動してよい条件（要件を 2 つ足す。既存の要件の文は変えない）

## Impact

- `plugins/dev-workflow/skills/develop/references/epic.md`、`epic-loop.md`（文書のみ）
- `plugins/dev-workflow/tests/develop-skill.bats`、`epic-dispatch.bats`（文書の検査を足す）
- `plugins/dev-workflow/changes/1647.md`（変更の記録）。常時注入の予算には触れない
