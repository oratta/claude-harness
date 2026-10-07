## Why

コストの行を積む hook（PostToolUse）は、手元の Bash で `gh` コマンドが走ったときにしか動かない。auto-merge によるマージと、PR の `Closes` による issue の自動クローズは GitHub の側で起きるので、手元からは見えず、最後の行（`マージ`・`issue クローズ` と issue の合計の行）が付かない。このリポジトリでいちばん多い終わり方（ゲート合格 → auto-merge）で、履歴の最後が欠けている（issue #691、エピック #272 の子）。

GitHub Actions では作れない。コストの元データ（会話ログと台帳）が手元にしか無いため。

## What Changes

- `plugins/cost-ledger/hooks/hooks.json` に `SessionStart`（matcher `startup|resume`）の hook を足し、新しい `scripts/backfill.sh` を呼ぶ。hook の同期部分は標準入力を読んで裏のプロセスを切り離すだけで、`gh` も台帳も会話ログも読まない。stdout・stderr には何も出さない（会話の文脈に何も入れない）
- 裏のプロセス（新しい `scripts/backfill.py`）が、セッションの `cwd` のリポジトリについて、前回見た時刻以降にクローズされた issue とマージされた PR を `gh api` の一覧 1 回で探し、最後の行が無いものに `マージ` / `issue クローズ` の行を後追いで積む。行の時刻と累計を切る時刻は、GitHub が記録したマージ・クローズの時刻
- どこまで見たかを、台帳の隣の控えファイル（`<COST_LEDGER_PATH>.backfill.json`）にリポジトリごとに記録する。`COST_LEDGER_PATH` が未設定なら後追いは動かない
- `cost_ledger.py timeline` に `--backfill` を足す。付けると、同じきっかけの行が既にある（手で `gh pr merge` / `gh issue close` を実行して積まれた）ときは本文を変えず、手元にコストが 1 つも無いときは既存のコメントがあっても積まない
- 行を積む処理（対象ごとのロック・既存コメントの取得・`timeline`・書き込み・issue を閉じた PR の問い合わせ）は `gate_report.py` の既存の関数をそのまま使う。`gate_report.py` の変更は、`timeline` に追加の引数を渡せるようにすることだけ
- 緊急停止は、既存の `COST_LEDGER_GATE_REPORT=off`（GitHub へ書く処理すべて）と、後追いだけを止める `COST_LEDGER_BACKFILL=off`
- README に後追いの節を足し、`plugins/cost-ledger/changes/691.md` に変更の記録と実測（セッション開始の遅れ・`gh` の呼び出し回数）を書く

## やらないこと（他の子 issue の範囲、または今回は見送るもの）

- マージされずに閉じられた PR への `PR クローズ` の後追い、GitHub の画面から付けたコメント・`Ready`・再オープン・ゲート通過の後追い（issue #691 の範囲はマージ済みの PR とクローズ済みの issue）
- `gh api` の直叩きと `gh pr create` / `gh pr reopen` で行を積むこと（#697）、`gh issue reopen` を帰属先の拾い先に足すこと（#698）、リポジトリ名の検証（#703）、#705、`/cost <issue番号>` の合計（#736）、閉じた PR の問い合わせ失敗の見分け（#737）
- エピックでの子ごとの内訳と合計（#690）、複数行に分かれた応答の拾い漏れ（#695）、`changes/701.md` の記載（#726）
- 既存の行の書式・並び順・増分の計算・合計の行の中身（`cost-ledger-timeline` の既存の要件のまま使う）
- 前回のセッションから十分に時間が空いていないときに一覧の問い合わせを省くこと（決定 9 で見送り）

## Capabilities

### New Capabilities

- `cost-ledger-backfill`: セッション開始時に、手元から見えなかったマージとクローズを探し、最後の行を後追いで積む。hook の登録、候補の探し方、どこまで見たかの記録、2 回追記しないこと、`gh` の呼び出し回数を定める

### Modified Capabilities

- `cost-ledger-timeline`: `timeline --backfill` の振る舞いを足す（ADDED）。「行を積むきっかけ」の守備範囲の記述を、auto-merge などで積まれない分のうちマージと issue のクローズは後追いが積む、という形に改める（MODIFIED。PostToolUse の hook の振る舞いは変えない）。「1 本のコメントに行を積む」の「行を足さない場合」に、`--backfill` の判定が加わることを 1 文で書く（MODIFIED。`--backfill` を付けない呼び出しの振る舞いは変えない）

## Impact

- コード: `plugins/cost-ledger/hooks/hooks.json`、`plugins/cost-ledger/scripts/backfill.sh`（新規）、`plugins/cost-ledger/scripts/backfill.py`（新規）、`plugins/cost-ledger/scripts/gate_report.py`、`plugins/cost-ledger/scripts/cost_ledger.py`
- テスト: `plugins/cost-ledger/tests/backfill.bats`（新規）
- 文書: `plugins/cost-ledger/README.md`、`plugins/cost-ledger/changes/691.md`（新規）
- `hooks.json` を変えるので、反映には `/reload-plugins` が要る。`plugins/*/hooks/` は聖域なので、この PR は機械マージに乗らず人間のマージになる
- 手元に増えるファイル: `<COST_LEDGER_PATH>.backfill.json` と `<COST_LEDGER_PATH>.backfill.lock`
- 入れた直後の最初のセッション開始では、過去 24 時間にマージ・クローズされた分（1 回の実行で 20 件まで）にまとめて行が付く
