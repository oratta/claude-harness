# Proposal

## Why

エピックの親の見張り（`epic-dispatch.sh` の `wait`・`notify-closed`・`wait --resolve`）には、子の終わり方や止まり方によって親が気づけない、または誤って動く穴が 4 つ残っている。エピック #1826 の子 #1827 が、元の issue #1084・#1182・#1598・#1620・#1815 の作業をまとめて塞ぐ（記録先: https://github.com/oratta/claude-harness/issues/1827 ）。

- 止まった印を付けずに主にマージを頼んで見張りを終えた子は、記録先が completed で閉じても `notify-closed` が `skipped <N> not-stopped` を返して何も送らない（#1182）
- 親が受けた止まり（`stopped-seen`）のまま記録先が閉じ、`notify-closed` が届かなかった子は、`wait --watch-done` の完了推定の対象から外れていて、ワークツリーが残り続ける（#1598）
- `wait --resolve` の判断が「親が #N を起動する」のような親の操作を含む推奨を通すと、子に返事だけが送られて親が起こされず、操作が行われないまま子が待ち続ける（#1620。flatmate のエピックで約 50 分起動されなかった実例がある）
- 子を新しいセッションで再開したあとも、古いセッションの `主の返事待ち` が残っていると `owner-away` を出し、主に済んだ問いを知らせる（#1815）

#1084 の 2 つの条件と、#1182 の 2 つ目・#1815 の 2 つ目の条件は main で既に満たしている（証拠は design.md の Context）。

## What Changes

- `notify-closed` は、記録の `stop` の値と `status` が `running` か `waiting` かによらず、完了の印（`status` が `done`）の無い子に促しを送る。送る直前の止まりの確かめ（`stop`・`stop_turn`・会話ログの進み）も掛けない。`skipped <N> not-stopped` は出なくなる
- `wait --watch-done` の完了推定は、`stop` が `stopped-seen` の子を対象に含める（`stopped` は外したまま）。推定しても `stop` 系の項目は変えない
- `stop-judge.sh` は判断の 1 行目に `判断: 親が動く` を受け付け、基準のファイルが「推奨が親の操作を含むときに出す」と定める。`wait --resolve` はこの判断の止まりを子に送らず、子 issue に `親の判断: 親の操作が要る` を残して `stopped <N>` で返す。親は `epic-stop.md` の手順 8 で操作を行ってから返事を送る
- `wait --watch-stopped` の `owner-away` の判定は、子の最新の会話ログのセッションが `turn_state` のセッションと違い、そちらに `turn_state.recorded_at` より新しい入力があるときは知らせない
- `epic-dispatch.sh` の冒頭のコメントと `--help`、`references/epic-loop.md` の手順 2・4 と親だけの片付けの段落を、上の振る舞いに合わせて直す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 要件「Orca 経路の親は、止まった印のまま completed で閉じた子に完了を促す返事を送る」「epic-dispatch.sh wait は完了の印の無いまま記録先が閉じて動きの止まった子を完了と推定する」「回し方の手順は推定した done も子の付けた done と同じに片付ける」「完了を伝えるだけの子を起こす必要は既存の片付け条件で分ける」を変え、要件「wait --resolve は親の操作が要る止まりを通さず stopped で返す」を足す
- `dev-workflow-epic-state`: 要件「親の見張りは記録だけで子の状態を判定する」「wait --watch-done は推定した完了を記録に書き、Orca の印へ写す」「主が打った返事待ちは時間がたったら親が主に知らせる」「owner-away の守備範囲を限る」を変える

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`deliver_reply`・`cmd_notify_closed`・`infer_done`・`resolve_stopped`・`detect_owner_away`、冒頭のコメント、`--help`）
- `plugins/dev-workflow/scripts/stop-judge.sh`（1 行目の値の検査）
- `plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md`・`epic-loop.md`・`epic-stop.md`
- `plugins/dev-workflow/tests/epic-dispatch.bats`・`stop-judge.bats`
- 変更の記録 `plugins/dev-workflow/changes/<PR番号>.md`
- エピックの後続の子 2 本が同じ範囲（`wait`・`resolve_stopped`・owner-away）を触るので、この子を先にマージする
