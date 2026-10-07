## Why

cost-ledger を入れると、いまは全部のリポジトリで GitHub へのコストの行の書き込みが有効になり、止める手段は全体を止める `COST_LEDGER_GATE_REPORT=off` だけである。2026-10-06 にプラグインをユーザー全体へ入れたあと、意図していない別のリポジトリの PR と issue 18 件に金額とトークン量の行が付いた。コメントは消せるが、通知メールで届いた分と消すまでに読まれた分は取り消せない。書き込みを「利用者が書いてよいと登録したリポジトリだけ」に絞り、既定を「書き込まない」に変える（issue #775、エピック #272 の子）。

## What Changes

- **BREAKING**: 既定を「書き込まない」にする。GitHub にコストの行を書くのは、許可の一覧に載っているリポジトリ（`owner/repo`。ホストは github.com）だけになる。更新した直後は、一覧を作るまでどのリポジトリにも行が付かない
- 許可の一覧は、リポジトリの外に置くテキストファイル（既定 `$HOME/.config/cost-ledger/write-repos`、1 行に `owner/repo` を 1 つ）にする。環境変数やプラグインの userConfig の値そのものを一覧にはしない（作業中のリポジトリの `.claude/settings.json` の `env` から設定できてしまうため）。一覧のファイルが作業中のリポジトリの中にあるときは、一覧を空として扱う
- 一覧が空（ファイルが無い・空）のとき、hook は標準入力を読まず、`python3` も `gh` も起動せずに抜ける
- 一覧があっても、作業中のリポジトリ（hook の `cwd` の origin）か、コマンドが名指ししたリポジトリが一覧に無ければ、`gh` を 1 回も呼ばずに抜ける。書き込みの直前にも、GitHub が返したリポジトリ名で同じ判定をもう一度通す
- 判定は 1 つの関数にまとめ、GitHub に書き込む経路（ゲート通過の投稿、節目ごとの行、issue を閉じたときの合計、後から入る後追い #691）はすべてそこを通す
- 全体停止の `COST_LEDGER_GATE_REPORT=off` は残し、一覧より先に効く（off なら一覧に載っていても書かない）
- README に、一覧の作り方と、既に付いた行を一覧して消す手順を書く
- `/cost` の表示と台帳への追記は GitHub に何も書かないので変えない。行の書式も変えない

## Capabilities

### New Capabilities

- `cost-ledger-write-allowlist`: GitHub への書き込みを許可するリポジトリの一覧（置き場所・書式・リポジトリの中のファイルでは有効にならないこと）、判定を 1 つの関数にまとめること、一覧に無いリポジトリでは `gh` を呼ばないこと、全体停止との関係

### Modified Capabilities

- `cost-ledger-gate-report`: 「有効・無効の設定を持たず、緊急停止だけを持つ」を、「有効にする手段は許可の一覧だけで、緊急停止は一覧より先に効く」に変える
- `cost-ledger-timeline`: 「`gh` の呼び出し回数」に、一覧に無いリポジトリでは 0 回であることを足す

## Impact

- コード: `plugins/cost-ledger/scripts/write_allow.py`（新規。判定の関数）、`plugins/cost-ledger/scripts/gate-report.sh`（一覧が空なら抜ける 1 段）、`plugins/cost-ledger/scripts/gate_report.py`（裏の処理 `work()` で判定を呼ぶ。きっかけの検出部分は変えない）
- テスト: `plugins/cost-ledger/tests/write-allow.bats`（新規）、`plugins/cost-ledger/tests/gate-report.bats`（setup で一覧と `cwd` の origin を用意する）
- 文書: `plugins/cost-ledger/README.md`、`plugins/cost-ledger/.claude-plugin/plugin.json` の `description`、`plugins/cost-ledger/changes/775.md`
- 利用者: 更新後、一覧を作るまで行が付かなくなる。作り方は README に書く
- 同時に動いている変更: #691（後追い `backfill.py`）は main に入った時点で同じ判定を通す。#697（`gate_report.py` の検出）とは触る場所を分ける
- エピック #272 の「全体の制約」: LLM のトークンは使わない（hook とスクリプトだけ、hook は無出力）。hook 1 回の所要時間と `gh` の呼び出し回数を変更の前後で実測して PR に書く
