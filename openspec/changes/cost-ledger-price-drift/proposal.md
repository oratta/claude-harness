## Why

cost-ledger の単価は `plugins/cost-ledger/pricing.json` に手で書いている。新しいモデルが出てから追記するまで、そのモデルの分は 0 円として落ち、値上げや値下げがあっても古い単価で計算し続ける。今はこのずれに気づく仕組みが無く、ずれた額を PR や issue に貼り続けてしまう（エピック #272 の「主が飲んだリスク」の「料金表のずれ」）。

Claude Code 本体は、セッションごとのコストを自分の単価で計算して statusline の入力（`cost.total_cost_usd`）に渡している。これを手元に書き残して自前の計算と比べれば、LLM のトークンを使わずにずれを検出できる。

## What Changes

- statusline のスクリプトが、描画のたびに受け取る本体のコスト値を、セッション ID ごとの小さな記録ファイルに書き残す。値が前回と同じ描画では何も書かない。statusline の表示は変えない
- cost-ledger の `/cost`（`cost_ledger.py` の `cost`・`branch`・`issue`）が、答えに含まれるセッションのうち記録があるものについて、本体の値の増分と自前の計算を比べる。差が閾値（差額 $0.50 超 かつ 大きい方の額の 10% 超）を超えたセッション、または単価の無いモデルの行を含むセッションがあれば、出力の 2 行目以降に警告行を出す。該当が無ければ何も出さない
- 出力の 1 行目（`headline()` が作る行）は変えない。pr-review-gate 通過時に PR へ貼る hook は 1 行目しか使わないので、突き合わせを省く引数 `--no-drift-check` を付けて呼ぶ（hook の所要時間を増やさない）
- 突き合わせは `/clear` などで本体の値が 0 に戻る区間ごとに行う（記録が「値が下がったら区間を始め直す」形を持つ）

## Capabilities

### New Capabilities

- `session-cost-record`: statusline が Claude Code 本体のセッションコストを書き残す記録の、置き場所・形式・書く条件。statusline プラグイン（書き手）と cost-ledger プラグイン（読み手）の間の受け渡しの取り決め

### Modified Capabilities

- `cost-ledger-pricing`: 本体のコスト値と自前の計算を突き合わせ、ずれを警告する要件を足す（閾値、突き合わせる範囲、警告の出し方、単価の無いモデルを含むときの扱い）

## Impact

- `plugins/statusline/scripts/statusline.sh`: 記録を書く処理を足す（表示は不変）
- `plugins/cost-ledger/scripts/cost_ledger.py`: 記録の読み取り、突き合わせ、警告行、`cost` サブコマンドの `--no-drift-check`
- `plugins/cost-ledger/scripts/gate-report.sh`: `cost` の呼び出しに `--no-drift-check` を付ける（1 か所）
- テスト: `plugins/cost-ledger/tests/drift.bats`（新規）、`plugins/statusline/tests/statusline-session-cost-record.bats`（新規）、`plugins/cost-ledger/tests/gate-report.bats`（引数の確認を 1 件追加）
- 文書: `plugins/cost-ledger/README.md`、`plugins/statusline/README.md`、`plugins/cost-ledger/changes/692.md`、`plugins/statusline/changes/692.md`
- 常時注入される文面（`rules/`・`CLAUDE.md`・各種 `description`）は変えない。`commands/cost.md` も変えない（警告はスクリプトの出力に出るだけで、LLM に実行させる手順は足さない）
- hook は増やさない。`gh` の呼び出しも増やさない
- 利用者の環境に `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.session-cost/` というディレクトリが新しくできる
