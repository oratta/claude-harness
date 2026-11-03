## Context

Orca 1.4.226 では `orca worktree create`（`--agent` なし）が空のシェルの端末「Terminal 1」を 1 つ作る。launch は従来、そのあと `orca terminal create --command <起動コマンド>` で 2 つ目の端末を作っていたため、子のワークツリーの端末が 2 つになり、`reply` が `ambiguous-terminal` で止まった。

## Decisions

- **案 (a) を採る: worktree create が作った最初の端末へ起動コマンドを打ち込む。** 案 (b) の `worktree create --agent claude` は端末が 1 つで済むが、Orca の設定のコマンドで起動するため `EPIC_DISPATCH_CLAUDE_CMD`・`EPIC_DISPATCH_PARENT_EPIC`・`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`・`--model` を渡せない。子が `nested` を判定できず、モデルも指定できなくなる（既存の要件「worktree create に `--agent` と `--prompt` を渡してはならない」と同じ理由）。(a) は起動コマンドの文字列を変えないので、環境変数の意味がそのまま保たれる
- **最初の端末は `orca terminal list --worktree path:<子> --json` で取る。** 作った直後のワークツリーで、端末がちょうど 1 つならそれが空のシェルである。`reply` が端末を選ぶのと同じ一覧の形（`.result.terminals[].handle`）を読む
- **起動コマンドは `orca terminal send --terminal <handle> --text <cmd> --enter --json` で打ち込む。** 既存の送信手段をそのまま使う。`--wait-submit` は付けない（シェルへの入力であって、エージェントの指示の送信ではない）
- **Claude Code になるまで一覧を引き直して待つ。** シェルは起動コマンドを打つ前から idle なので、すぐ `terminal wait --for tui-idle` を呼ぶと、Claude Code が立ち上がる前に通ってしまい、最初の指示がシェルに入る。そこで、一覧の同じハンドルが `agentIdentity == claude`（無ければタイトルに `Claude Code`。既存の `pick_session_term` の判定）になるまで 1 秒ごとに引き直す。上限は `EPIC_DISPATCH_READY_TIMEOUT_MS`（ミリ秒を秒に切り下げ、最低 1 回）。そのあとは従来どおり `terminal wait --for tui-idle` → 指示の `terminal send`
- **端末が 0 個なら従来どおり `terminal create`。** worktree create が端末を作らない版でも動かす。**1 個でない（2 個以上・一覧が読めない）ときは作らず failed。** 作ると二重起動の原因を増やす。失敗の案内は、既存の「端末を作れなかった子」の案内（`recreate_hint`）ではなく専用の短い案内にする（その案内は端末が無いことを前提にしているため）
- 範囲外: `reply` / `reap` / `wait` / `mark` / `route`。他の子 issue が並行して触っている

## Risks

- シェルに起動コマンドを打ち込むため、Orca が開いたシェルが入力を受け付ける前に送ると取りこぼす可能性がある。worktree create が戻った時点で端末は存在しており、`terminal send` の失敗は failed として表に出る。実機での確認は受け入れ条件 2 で本体が行う
