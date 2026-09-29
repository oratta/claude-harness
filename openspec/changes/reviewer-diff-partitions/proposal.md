## Why

PR レビュアー（一周目の full レビュー）は、差分の行数が大きいほどコンテキスト上限（150,000 トークン）に当たって交代する。直近 10 日の 1 周目レビュアー 69 体では、差分（追加＋削除）が 600 行未満の PR では上限超えが 41 体中 4 体だったのに対し、600 行以上では 28 体中 20 体（71%）だった（測り直しの記録: https://github.com/oratta/claude-harness/issues/514#issuecomment-5882781960 ）。三表（変更点の一覧・照合表・ハンク被覆）は差分全体の通読とリポジトリ全体の grep を要するので、1 人に渡す仕事の大きさを最初から上限に届かない大きさにする必要がある。G（ゲート実行者）は #553・#554・#330 のあと上限に届いていないので、G 側の手当ては要らない。

## What Changes

- pr-review-gate の手順 2-0 に「区画の判定」を足す。PR の差分（ファイルごとの追加＋削除の合計）が 600 行を超えたら、ファイル単位の区画（1 区画 400 行以下を目安に、ファイルの並び順で詰める。1 ファイルで 400 行を超えるものはそれだけで 1 区画）に分ける。区画の計算は新しいスクリプト `plugins/dev-workflow/scripts/review-partitions.sh` が行い、結果を `レビュー重量:` の PR コメントと `needs-reviewer` の payload に載せる
- 区画に分けるのは Claude のレビュアー（Task サブエージェント・`dev-workflow:decider`・adapter 経路で executor が claude のレビュアー）だけにする。Codex のレビュアーは区画に分けず、差分全体を 1 体に渡す（理由は design の決定 2）
- レビュアー向け指示ブロックに、区画を渡されたときの書き方を足す: 区画のファイルだけを読む範囲にする、変更点 ID と finding ID に区画の接頭辞（`P<k>-`）を付ける、受け入れ条件はその区画に関わるものだけを被覆する、ハンク被覆は区画のファイルの全ハンクを被覆する、照合表の検索コマンドは SHA を書かず文字どおり `<rev>` と書く、テスト・lint の再実行は区画 1 のレビュアーだけが行う
- develop の本体は adapter 経路の `needs-reviewer`（(4) の ③）で、executor が claude で payload に区画があれば、区画ごとにレビュアーを並列に起こし、全区画の要約をまとめて 1 体の照合と振り分けの G に渡す。補足要求は残差のある区画だけに起こす
- G の「一周目の三表を機械照合する」を、区画ごとの三表の和集合で照合する形にする（全区画の三表が揃っていること、受け入れ条件の被覆・ハンク被覆は和集合で見る、照合表は区画ごとに `review-hit-set.py` に渡す）
- 上の内容を bats で確かめる

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `dev-workflow-pr-review-gate`: 差分を区画に分ける条件と決め方、区画を渡されたレビュアーの書き方、G が区画ごとの三表を和集合で照合する要件を足す
- `dev-workflow-develop`: adapter 経路の本体が、executor が claude のとき区画ごとにレビュアーを起こす要件を足す

## Impact

- `plugins/dev-workflow/skills/pr-review-gate/stages/prepare.md`（2-0 の区画の判定、`needs-reviewer` の payload）
- `plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md`（レビュアー向け指示ブロックと起こす側の手順）
- `plugins/dev-workflow/skills/pr-review-gate/stages/review-run.md`（従来モードの Task サブエージェントを区画に分ける）
- `plugins/dev-workflow/skills/develop/SKILL.md`（(4) の needs-reviewer ③④）
- `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md`（一周目の三表の機械照合・補足レビュー結果の受領）
- `plugins/dev-workflow/scripts/review-partitions.sh`（新規）と `plugins/dev-workflow/tests/review-partitions.bats`（新規）
- `plugins/dev-workflow/tests/pr-review-gate-skill.bats`、`plugins/dev-workflow/tests/develop-roles.bats`、`plugins/dev-workflow/tests/develop-adapter-review-routing.bats`
- `plugins/dev-workflow/changes/514.md`（変更の記録）
- `plugins/dev-workflow/scripts/review-hit-set.py` は変えない（照合表は区画ごとでもリポジトリ全体の grep で完結しているので、表ごとに今のまま渡せる）
- 変わるのはレビュアーの起こし方と G の照合の単位だけで、light / full の判定、止める判定、仕分け表、合格処理、Codex の呼び出し規約は変わらない
