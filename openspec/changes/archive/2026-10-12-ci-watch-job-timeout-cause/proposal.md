## Why

CI のジョブが上限時間（`timeout-minutes`）で打ち切られたとき、`pr-state.sh` はそれを見分ける分類を持たないので、打ち切りは `real`（PR が原因の失敗）として実装者の直しに回るか、呼び出し側が `--unrelated` を付けてやり直したあと、同じ HEAD でまた打ち切られて直しに回る。セルフホストのランナーでは、上限での打ち切りは PR のテストが遅いことよりランナーの調子が悪いことのほうが多く、実装者が PR の差分を調べ直しても原因は見つからない。

genetta-inc/flatmate の PR #1516（2026-10-12）では、CI が 40 分の上限で 2 回続けて打ち切られ、原因（ランナーのある Mac に残った取り残しのプロセス）が分かるまでに CI 2 周分かかった。同じリポジトリで 2026-10-09〜12 に上限での打ち切りが 9 件以上あった（genetta-inc/flatmate#1563）。親のエピックは genetta-inc/flatmate#1566。

## What Changes

- `pr-state.sh observe` が、落ちたチェックの原因に `job-timeout` を足す。見分け方は、そのジョブの annotation に `maximum execution time` が含まれること（`runner-lost` と同じく `annotations` の出力をジョブ ID で引く）。順は `runner-lost` → `job-timeout` → `unrelated` → `real`
- `job-timeout` は `real` でないので、既存の規則どおり `retry` が `true` になり、同じ HEAD で 1 回だけやり直す（`runner-lost` と同じ扱い）
- `pr-state.sh decide` が、その HEAD のやり直しを使い切ったあとに、`real` が混ざらず `job-timeout` を 1 件以上含む `ci-fail`（`retry: true`）を見たとき、`fix` ではなく `escalate` を返す（修正回数 `fixes` は増やさない）。`runner-lost` と `unrelated` の 2 回目が `fix` になる既存の動きは変えない
- `references/ci-watch.md` に、`escalate` の観測に `job-timeout` があるときはオーナーへ「ジョブが上限時間で打ち切られた。ランナーの状態を確かめてほしい」と伝えること、`job-timeout` は `--unrelated` の判断の対象でないこと、`wait` の `timeout`（見張りの上限時間）とは別のものであることを書く
- annotation に `maximum execution time` を含まない取り消し（新しい push による打ち切りなど）の扱いは変えない
- `decide` の出力の形（`{act, next, obs}`）と状態のキーは変えない。`ci-watch.sh` のコードと `wait` の上限時間の既定値（3600 秒）も変えない

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-state`: `observe` の `cause` に `job-timeout` を足し、`decide` の一手の順に「その HEAD のやり直しを使い切ったあと、`real` が混ざらず `job-timeout` を 1 件以上含む `ci-fail` を見たらオーナーに上げる」を足す
- `dev-workflow-ci-watch`: 上限時間で打ち切られたジョブを見張りがどう扱うか（1 回やり直し、やり直しを使い切った HEAD で打ち切りを見たら理由を添えてオーナーに上げる）の要件を足す

## Impact

- コード: `plugins/dev-workflow/scripts/pr-state.sh`（`observe` の `cause` と `decide` の一手、冒頭の契約コメント）
- テスト: `plugins/dev-workflow/tests/pr-state.bats`、`plugins/dev-workflow/tests/ci-watch.bats`
- 文書: `plugins/dev-workflow/references/ci-watch.md`、変更の記録 `plugins/dev-workflow/changes/991.md`
- 仕様: `openspec/specs/dev-workflow-pr-state/spec.md`、`openspec/specs/dev-workflow-ci-watch/spec.md`
- 呼び出し側: `observe` の `cause` に新しい値が増える。`decide` は `cause` の値を見て一手を変えるので、`observe` の出力をそのまま `decide` に渡す呼び出し側（`ci-watch.sh next`、flatmate の pr-watch）は、やり直しを使い切った HEAD で打ち切りを見た PR で `fix` の代わりに `escalate` を受け取るようになる。`act` の値の種類は増えない。flatmate の pr-watch が `cause` の値を直接読んでいるかは、このリポジトリからは確かめていない
