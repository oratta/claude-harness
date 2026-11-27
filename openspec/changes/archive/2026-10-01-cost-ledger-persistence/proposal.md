# cost-ledger-persistence — 会話ログが消えてもコストが残る台帳

エピック #272 の子2（issue #274）。子1 #273（集計エンジンと `/cost`）と子3 #276（ゲート通過時の自動投稿）はマージ済み。

## Why

`/cost` は Claude Code の会話ログ（`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/**/*.jsonl`）を直接読んでいる。会話ログは既定 30 日で消えるので、消えたあとに `/cost <PR番号>` を叩くと過去の PR のコストが 0 に落ちる。消える前にコストを焼き付ける置き場が要る。

## What Changes

- **リポジトリ外の append-only JSONL 台帳**を足す。場所は環境変数 `COST_LEDGER_PATH`（台帳ファイルのパス）だけで決め、既定のパスを持たない。`LLM_LOG_DIR` と同じ扱いで、未設定なら `/cost` を動かしているエージェントが利用者に場所を聞く。台帳がこのプラグインのリポジトリ配下を指していたら書かずにエラーで終わる
- 台帳の 1 行は子1 が定めた**事実**（`build_fact` の出力）そのもの。区間の帰属は事実の列から読み取り時に導くので、台帳に帰属を書かない
- **`Stop` hook で差分追記**する。会話ログごとに読み終えたバイト位置を台帳の隣の控えファイルに持ち、増えた分だけを読む。`requestId` が台帳に既にある事実は書かない（控えファイルが壊れても消えても、重複排除で同じ台帳になる）
- **`/cost` の読み取り元を台帳に切り替える**。`COST_LEDGER_PATH` があるときは、読む前に同じ差分追記を 1 回行い、そのあと台帳だけを読む。未設定なら従来どおり会話ログを直接読む
- `cost_ledger.py` に `ledger-sync` サブコマンドを足す（hook と手動の取り込みの共通入口）

## Capabilities

### New Capabilities

- `cost-ledger-persistence`: 台帳の場所の解決・書式・差分追記・重複排除・同時実行・hook の登録と抜け方・`/cost` の読み取り元の切り替え

### Modified Capabilities

なし。`cost-ledger-cost-command` の入力解釈と出力の書式、`cost-ledger-gate-report` の hook は変えない（ゲートの hook は `cost_ledger.py cost` を呼ぶだけなので、読み取り元が台帳になっても変更なしで台帳の値を貼る）。

## #276 との役割分担

#276 の hook は `PostToolUse`（matcher `Bash`）で、合格ラベルの付与のときだけ PR にコメントを貼る。台帳には何も書かない。この change の hook は `Stop` で、台帳へ書くだけで PR には何もしない。重なる処理は無い。

## Impact

- **新規**: `plugins/cost-ledger/scripts/ledger-hook.sh`、`plugins/cost-ledger/tests/ledger.bats`、`plugins/cost-ledger/changes/274.md`
- **変更**: `plugins/cost-ledger/hooks/hooks.json`（`Stop` を足す）、`plugins/cost-ledger/scripts/cost_ledger.py`、`plugins/cost-ledger/commands/cost.md`、`plugins/cost-ledger/README.md`
- **マージ経路**: `plugins/*/hooks/` は聖域なので人間マージ
