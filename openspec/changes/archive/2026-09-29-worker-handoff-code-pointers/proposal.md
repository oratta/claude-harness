## Why

develop の作業者 W が交代すると（コンテキスト上限での手渡し、トリップワイヤーでの乗り換え）、後任は前任が読んだコードを探し直す。直近 10 日の W 420 体では、コンテキストの 38%（1 体あたり約 2.9 万字）がコードを読んだ結果で、読んだ量の最大 50% が同じ issue の前任 W が既に読んだファイルの読み直しだった（ファイル名一致で数えた上限値で、書き換えたファイルの必要な読み直しも含む）。今の引き継ぎの成果一覧（編集済みファイル・通ったテスト・判明した事実・埋めた決定・残作業）にはコードの場所が入っていない。

## What Changes

- W の return（`工程完了:` / `工程中断:` のどちらでも、トリップワイヤーで止まったときも）の成果一覧に「読んだコードの要点」欄を足す。1 行 1 件で `ファイル:行の範囲 — そこから分かったこと`、上限 20 行
- 後任 W への指示として、要点は読む場所の案内であり、編集する前には該当範囲を自分で読んで確かめる、と worker.md の手渡しの節に書く
- (1) 仕様化の段で、`tasks.md` の各タスクに `触る範囲: ファイル:行` を書く。仕様化しない経路（コード直行）では、同じ内容を (1) の return に書く
- 手渡しの入力の定義（`decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の成果一覧）に同じ欄の名前を足し、書式は worker.md を指す
- 上の内容を bats で確かめる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-develop`: W の return の成果一覧に「読んだコードの要点」を加える要件と、(1) で作業項目ごとに触る範囲を書く要件を足す

## Impact

- `plugins/dev-workflow/skills/develop/references/roles/worker.md`（(1) の仕様化する場合／しない場合、昇格トリップワイヤー、(3a) の return、コンテキスト上限と手渡しの節）
- `plugins/dev-workflow/skills/develop/references/decision-criteria.md`（コンテキスト上限の節の成果一覧 2 箇所）
- `plugins/dev-workflow/tests/develop-roles.bats`、`plugins/dev-workflow/tests/handoff-declaration.bats`
- `plugins/dev-workflow/changes/555.md`（変更の記録）
- 途中計測 hook の通知文（`scripts/context-tripwire.sh`）とトリップワイヤーのテンプレート（`templates/escalation-tripwires.md`）は変えない（design の決定 5）
- 振る舞いが変わるのは W の return の中身と `tasks.md` の書き方だけで、本体・R1・G の判定規則と手渡しの条件は変わらない
