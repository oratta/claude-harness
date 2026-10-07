## Why

単価表のずれを突き合わせる読み直し（issue #692）は、一定の行数ごと（5,000 行）とファイルを開く前にだけ上限の時間（既定 1 秒）を確かめる。最後に確かめてから読み終えるまでの間に上限を超えると、その後に確かめる箇所が無いので、最後のファイルが確認間隔より短いときは、上限を超えて読み終えても `未確認` にならず通常の比較結果が出る（issue #701。PR #700 のレビューで、時計を 0 秒から 2 秒に進め予算 1 秒の入力で `cut_off=False, drifted=1` を再現）。

issue は「ループ終了後に期限超過を確かめて `未確認` にする」案を挙げたうえで、読み終えた完全な結果を捨てる挙動が仕様として望ましいかを先に決めるよう求めている。この change はその決定を仕様に書き、テストで固定する。

## What Changes

- `cost-ledger-pricing` の要件「突き合わせのための読み直しは上限の時間で打ち切り…」に、「最後まで読み終えたら、その時点で上限を超えていても読んだ結果を使う」を明記する（決定: 読み終えた結果は捨てない）
- 現状の挙動がこの決定どおりなので、`cost_ledger.py` の処理は変えない。読んで分かる形にするためのコメントだけ足す
- 最後のファイルの読み込み中に時計を上限の先へ進めるテストを `plugins/cost-ledger/tests/drift.bats` に足し、決定を固定する

## Capabilities

### Modified Capabilities
- `cost-ledger-pricing`: 読み直しの打ち切りの規定に、読み終えた結果の扱いを足す

## Impact

- `openspec/specs/cost-ledger-pricing/spec.md`（archive で反映）、`plugins/cost-ledger/tests/drift.bats`、`plugins/cost-ledger/scripts/cost_ledger.py`（コメントのみ）、`plugins/cost-ledger/changes/701.md`
- LLM のトークンは使わず、`gh` の呼び出しは増えない。処理は変えないので突き合わせ 1 回の所要時間も変わらない（PR に実測を書く）
