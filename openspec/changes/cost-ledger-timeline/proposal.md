# cost-ledger-timeline — PR と issue に、節目ごとのコストを 1 行ずつ積む

エピック #272 の子5（issue #303）。子1 #273（集計と `/cost`）・子2 #274（台帳）・子3 #276（ゲート通過時の自動投稿）はマージ済みで、子4 #688（台帳を動かし始める）も済んでいる。

## Why

いま PR にコストが載るのはゲート通過（合格ラベル `agent-review:passed` の付与）のときだけで、1 本のコメントを最新の合計で書き換えている。途中経過が残らないので、どのステップで急に高くなったかを後から見られない。issue 側には何も載らず、PR を作らない作業や議論だけの issue のコストは `/cost <issue番号>` を手で叩かないと分からない。

主の決定（#303 の 2026-10-06 のコメント）: 1 本のコメントに節目ごとに 1 行ずつ積む。1 行には時刻・きっかけと、金額・入出力トークン・キャッシュトークンの 3 項目を「累計 (+前の節目からの増分)」で載せる。トークン量を載せるのは、金額が下がった原因が使う量の減少なのか単価の変化なのかを後から切り分けるため。

## What Changes

- **きっかけを広げる。** いまの合格ラベルの付与に加えて、`gh pr comment`・`gh issue comment`・`gh pr ready`・`gh pr close`・`gh pr merge`・`gh issue close`・`gh issue reopen` を実行したときに、その PR / issue へ 1 行積む
- **issue にもコストが載る。** issue 側の累計は `/cost <issue番号>` と同じ値（その issue を触った区間の合計）
- **1 本のコメントに行を積む。** 目印 `<!-- cost-ledger:timeline ... -->` を持つコメントを PR / issue ごとに 1 本だけ保ち、節目のたびに表の行を 1 行足す。1 行目は `/cost` の 1 行目と同じ行（最新の累計）で、これだけは毎回差し替える
- **BREAKING（コメントの形）**: ゲート通過時に貼っていた 3 行のコメント（目印 `<!-- cost-ledger:gate-report -->`、合計の行と時点の行）は作らなくなる。ゲート通過は、同じ 1 本のコメントに「ゲート通過」の行として積まれる。既に貼られた古い形のコメントには触らない
- **hook はセッションを止めない。** hook 自身はコマンドの判定だけをして、GitHub への問い合わせ・集計・書き込みは切り離した裏のプロセスで行う。`gh` の呼び出しがあるので合計は 1 秒を超えるため（エピック #272 の「全体の制約」）
- `cost_ledger.py` に `timeline` サブコマンドを足す（既存のコメント本文を受け取り、行を足した新しい本文を返す。数字と書式はここだけが持つ）。issue の集計は、台帳をその issue を触ったセッションの行だけに絞って読む
- LLM のトークンは使わない。スキル本文には何も足さず、hook は何も出力しない

## やらないこと（他の子 issue の範囲）

| やらないこと | 受け持つ issue |
|---|---|
| issue を閉じたときに、その issue を閉じた PR の分も重複なしで合わせた合計を出す。この change の issue の累計は `/cost <issue番号>` と同じ値のままにする | #689 |
| エピックで子 issue ごとの内訳と合計を出す | #690 |
| auto-merge のマージと、PR の `Closes` による自動クローズへの後追いの行。手元でコマンドが走らないので、この change の hook からは見えない（`gh pr merge --auto` は実行した時点ではマージされていないので行を積まない） | #691 |
| 自前の単価表と Claude Code 本体のコスト値のずれの検出 | #692 |
| OpenTelemetry の検証 | #693 |
| 区間の境界（`gh pr comment` など 4 つ）と、issue 番号を拾うコマンドの集合（`cost-ledger-attribution`）の変更 | なし（この change では変えない） |

## Capabilities

### New Capabilities

- `cost-ledger-timeline`: きっかけの集合と呼び名、対象の解決、状態変更の実測、1 本のコメントの構成と行の書式、前の節目の値の持ち方、数字の出どころ、裏での実行、同時実行、`gh` の呼び出し回数

### Modified Capabilities

- `cost-ledger-gate-report`: hook の fast path の条件を広げる。「投稿するのはゲート通過のときだけ」「貼る形はマーカー付きのコメント 1 本」「貼る数字は `/cost` と同じ入口から取る」の 3 要件を外し、`cost-ledger-timeline` に置き換える。緊急停止の環境変数は同じ名前のまま、積む処理すべてを止める

## Impact

- `plugins/cost-ledger/scripts/gate-report.sh`（fast path を広げ、Python 本体を別ファイルに出す）
- `plugins/cost-ledger/scripts/gate_report.py`（新規。判定・対象の解決・裏のプロセス・`gh` の読み書き）
- `plugins/cost-ledger/scripts/cost_ledger.py`（`timeline` サブコマンド、トークンの合計、issue の絞り込み読み）
- `plugins/cost-ledger/tests/gate-report.bats`（コメントの形が変わる分を直す）、`plugins/cost-ledger/tests/timeline.bats`（新規）
- `plugins/cost-ledger/README.md`、`plugins/cost-ledger/changes/303.md`（新規）
- `plugins/cost-ledger/hooks/hooks.json` は変えない（PostToolUse・matcher `Bash`・`timeout: 60`・`async` なしのまま）
- 常時注入の合計（`tests/injection-budget.bats`）には影響しない（description・rules・CLAUDE.md を変えない）
- PR に書く実測: hook 1 回の所要時間（変更前後）、`gh` の呼び出し回数、コメントの編集で通知が飛ぶか、実機で 2 行以上積まれた PR
