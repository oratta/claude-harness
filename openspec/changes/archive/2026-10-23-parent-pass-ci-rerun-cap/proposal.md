## Why

CI の見張り（`plugins/dev-workflow/references/ci-watch.md`）は、同じ HEAD でのやり直しを 1 回までとする。使い切った HEAD でなお落ちると、見張りはもう一度やり直せない。`job-timeout` を含む失敗は `escalate` で止まり、`real`・`unrelated`・`runner-lost` の失敗は `fix` に回って、実装者が直すものが無いと判断すれば ci-watch.md 7 の手順 7 で `escalate` と同じ手順で上げる。親が子の止まりを通すか主に上げるかを決める基準 `parent-pass-criteria.md` は、どちらの止まりの扱いも書いていない。ほかのリポジトリのエピックでは、同じ種類の止まりを親が通したり主に上げたりと揺れて判断した（#1244 の調べた結果）。理由が「見張りがやり直せない」だけの止まりが夜に主へ上がるのは、主の手間になる。

## What Changes

- `parent-pass-criteria.md` に、表でなく文章の節「CI の見張りのやり直しの上限で止まった子」を足す。対象の止まりを子の停止の記録から見分けられる形で定義し、通すか主に上げるかが一通りに決まるようにする。
- 条件表の 9 条件は増やさない。「繰り返していない」との関係を節の中で決める（見張りの上限は見張りの歯止め、「繰り返していない」は親の判断の歯止めで別物。親が追加のやり直しを許すのは、同じ PR の同じチェックにつき 1 回まで）。
- 通る例に、上限で止まった子への追加のやり直し 1 回を足す（既存要件の MODIFIED）。
- `ci-watch.md` は変えない。親の許可は返事で指示し、子は 1 回やり直したあと ci-watch.md 2 の `escalate` のあとの再開手順で見張りに戻る。

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: 要件「親が通してよい範囲の基準を 1 つのファイルに置く」の通る例に 1 件足し、上限で止まった子の扱いの要件を足す。

## Impact

- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`（`stop-judge.sh` が判断のモデルに渡す文書の一部なので、判断の挙動が変わる）
- テスト: 該当の記述があることを確かめる bats（`plugins/dev-workflow/tests/epic-dispatch.bats`）
