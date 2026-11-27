# cost-ledger-gate-report — ゲート通過時に PR のコストを hook で 1 行貼る

エピック #272 の子3（issue #276）。子1 #273（集計エンジンと `/cost`）はマージ済み。子2 #274（台帳への焼き付け）とは独立で、この change を先に進める。

## Why

`/cost <PR番号>` で PR ごとのコストは出せるようになったが、誰かが叩かない限り PR には何も残らない。エピック #272 の完了条件の 1 つは「ゲート通過時に PR へ自動で 1 行載る」ことである。

当初はこれを pr-review-gate のスキル本文に手順として足し、ゲートを回すエージェントに貼らせる設計だった。その形では手順の文を読む・`/cost` の出力を文脈に取り込む・コメントを組み立てる、の 3 つがモデルの仕事になり、足した数百トークンがゲートのターン数ぶん繰り返し読み込まれる。コストを測る道具が自分でコストを生む。ゲート通過は合格ラベル `agent-review:passed` を付けるコマンドとして機械から見えるので、「いつ貼るか」は変えずに「誰が貼るか」だけを hook に置き換えれば、LLM のトークンを 1 つも使わずに貼れる。

## What Changes

- **`plugins/cost-ledger/hooks/hooks.json` を新設し、`PostToolUse`（matcher `Bash`、`timeout: 60`、同期実行）で `plugins/cost-ledger/scripts/gate-report.sh` を呼ぶ**
- **`gate-report.sh` は、実行された Bash が合格ラベルの付与コマンドだったときだけ、その PR にコストのコメントを 1 本貼る**。本文の 1 行目は `/cost <PR番号>` の 1 行目（`headline()`）そのもので、2 行目に「YYYY-MM-DD HH:MM 時点・ゲート通過時に自動投稿」、末尾に隠しマーカー `<!-- cost-ledger:gate-report -->` を置く。マーカー付きのコメントが既にあれば書き換え、無ければ新規作成する。数字は `cost_ledger.py cost <PR番号>` を呼んで得る（`/cost` と同じ入口。hook は集計も書式も持たない）
- **ラベル付与コマンドからの対象 PR の取り出し**を定める。実ログの調査で、ラベル付与の多くは `R=oratta/x; N=189` のようなシェル変数、`for N in 96 97; do ... done`、`gh pr edit <N> --add-label` の形で書かれていた。リテラルの形に加えてこれらを解決し、解決できない形は何もせずに抜ける（詳細は design）
- **fast path**: stdin に文字列 `agent-review:passed` が含まれなければ、JSON のパースも python3 の起動もせずに即 `exit 0` する。対象外コマンドでの実行時間は 50 ms 未満
- **抜け方**: コマンドが対象外・`gh` か `python3` が無い・cost スクリプトが失敗・GitHub に届かない、のどれでも無出力で `exit 0`。`exit 2` は返さない（hook の失敗でゲートを止めない）
- **緊急停止**: 環境変数 `COST_LEDGER_GATE_REPORT=off` で hook を何もせず抜けさせる。有効・無効の設定項目は作らない（発火条件がラベル付与コマンドそのものなので、pr-review-gate を使うリポジトリでしか動かない）
- **`plugins/cost-ledger/prototypes/` を削除する**。回収率の測り直し（#286、65%）が完了し、本番実装との突き合わせが済んだため。プロトタイプを名指ししている既存 spec 2 本・README・実装のコメントを、実在するものを指すように直す
- pr-review-gate のスキル本文には手を入れない

## Capabilities

### New Capabilities

- `cost-ledger-gate-report`: ゲート通過（`agent-review:passed` の付与）を hook が捕まえ、その PR のコストを 1 本のコメントとして貼る・書き換える規則。発火条件・対象 PR の取り出し・貼る形・頻度・停止方法・失敗時の抜け方・子2 との関係・数字の遅れの扱い

### Modified Capabilities

- `cost-ledger-pricing`: Requirement「トークン内訳からのコスト算出」のシナリオ「プロトタイプと同じ値になる」が削除される `prototypes/branch-cost.py` を実行する形なので、手計算との一致を見るシナリオに置き換える
- `cost-ledger-attribution`: Requirement「issue による帰属（第 2 の鍵）」と「セッションごとの区間分割」が、拾うコマンド 5 つ・区間の境界 4 つの根拠として `prototypes/issue-rescue.py`・`prototypes/per-post-cost.py` を名指ししているので、根拠の参照先を archive 済みの change `cost-ledger-aggregation` の design に移す（コマンドと境界の集合そのものは変えない）

`cost-ledger-cost-command` は変えない。1 行目の固定書式の要件は「後続のゲート連携が 1 行目だけを取って貼る」前提で書かれており、この change はその前提どおりに 1 行目を使う。

## Impact

- **新規**: `plugins/cost-ledger/hooks/hooks.json`、`plugins/cost-ledger/scripts/gate-report.sh`、bats テスト（stub の `gh` を PATH に置き、stdin に hook の JSON を流す）
- **削除**: `plugins/cost-ledger/prototypes/`（スクリプト 5 本と README）
- **変更**: `plugins/cost-ledger/README.md`（prototypes の節を消し、hook の節を足す）、`plugins/cost-ledger/scripts/cost_ledger.py`（プロトタイプを名指ししているコメント 2 か所）、`plugins/cost-ledger/.claude-plugin/plugin.json`（バージョンと description）、`openspec/specs/cost-ledger-pricing/spec.md`・`openspec/specs/cost-ledger-attribution/spec.md`（archive 時に同期）
- **マージ経路**: `^plugins/[^/]+/hooks/` は auto-merge の聖域なので、この PR は機械マージに乗らず人間マージになる（主は承知済み）
- **install 先への影響**: cost-ledger を入れた全セッションの全 Bash 呼び出しで hook が起動する。fast path で python3 を起動しないので、対象外の呼び出しに乗る費用は bash の起動 1 回ぶん
- **外部との関係**: エピック #272 の「prototypes の扱い」の記述と、完了条件「ゲート通過時に PR へ自動で 1 行載る」の達成報告を、エピックに書く
