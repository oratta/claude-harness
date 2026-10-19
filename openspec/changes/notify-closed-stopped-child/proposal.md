## Why

Orca 経路のエピックで、子が「PR のマージ待ち」などで主の返事を待って止まった（止まった印 `epic-stopped` を付けた）あと、主が子のタブの外で PR をマージして子 issue が閉じても、子のセッションには何も届かない。子は止まったまま「用が済んだ」の印（`mark done`）を付けないので、親の `reap` は `kept <N> not-done` を返し続け、ワークツリーが残る。2026-10-19、子 #1059 で実際に起き、親が手で `reply --as parent` を送るまで片付かなかった（https://github.com/oratta/claude-harness/issues/1093 ）。親の `wait` は閉じた子を `closed <N>` で返すだけで、止まったまま閉じた子に知らせる手順が無い。

## What Changes

- `scripts/epic-dispatch.sh` に `notify-closed [--relaunch] <epic> <child>` を足す。子 issue が `completed` で閉じていて、子のワークツリーの印が止まった印（`epic-stopped` か `epic-stopped-seen`）のままのときだけ、`reply --as parent` と同じ処理で「記録先は completed で閉じた。完了報告を書き、mark done で終える」旨の返事を子に送り、送れたらエピックに `親の判断: 子 #<child> 通した — <理由> <停止の記録の URL>` の 1 行を残す。条件を満たさない子には何も送らず `skipped <child> <理由>` を返す
- develop の `SKILL.md`「回し方」の Orca 経路の手順 4 で、`closed <N>` を受けて `state_reason` が `completed` の子ごとに、`references/reply-after-idle.md` の表で `--relaunch` の要否を決めてから `notify-closed` を呼び、出力ごとの扱い（`unrecorded` は投稿し直し、`failed` は主に報告）を書く
- `tests/epic-dispatch.bats` に、偽の `orca`・`gh` で、止まった印のまま completed で閉じた子には返事が送られエピックに 1 行が残ること、止まっていない子・completed でない子・閉じていない子には何も送らないこと、手順 4 の文面が `notify-closed` を呼ぶことを確かめるテストを足す

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: Orca 経路の親が、止まった印のまま completed で閉じた子に完了を促す返事を送る要件を足す（`epic-dispatch.sh notify-closed` の振る舞いと、手順 4 での呼び方）

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（新しいサブコマンド・使い方・先頭の説明）
- `plugins/dev-workflow/skills/develop/SKILL.md`（「回し方」の Orca 経路の手順 4）
- `plugins/dev-workflow/tests/epic-dispatch.bats`
- 既存の `wait`・`reply`・`mark`・`reap` の振る舞いは変えない
