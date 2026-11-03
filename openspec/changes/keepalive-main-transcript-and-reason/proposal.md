## Why

止まった子へのキャッシュの声かけ（#1383）は、子の会話ログの置き場に `.jsonl` がちょうど 1 本のときしか送らない。セキュリティレビューが SDK で起こす短いセッションや過去のセッションがあると必ず外れ、実例（flatmate #1818）では約 30 時間一度も送られなかった。送らなかったときは `skipped` で黙って終わるので、動いていないことに気づけない。返事を通すときの起動し直しの判定（`decide_relaunch`）も同じ「1 本だけ」で、ログが複数あると常に「起動し直さない」になる。

## What Changes

- 本体の会話のログを「`entrypoint` が `cli` の assistant 行を持つファイルのうち、最終活動が最も新しい 1 本」で選ぶ共有の選び方を作り、声かけの判定と起動し直しの判定の両方に使う。候補が無ければ送らない
- 声かけの判定結果（送った・送らなかった理由）を子の記録に任意の文字列 1 項目 `keepalive` として残す。同じ結果は書き直さない
- `wait` の stdout の行と exit code は変えない

issue #1554 の案は記録の `session` を会話ログのファイル名に使うとしていたが、`session` は端末のハンドル（Orca）かペイン ID（tmux）で Claude Code のセッション ID ではない。そのため上の選び方に置き換える（理由は design.md）。

## Capabilities

### Modified Capabilities
- `dev-workflow-epic-state`: 子の記録に `keepalive` 項目を足す。声かけと起動し直しが本体の会話ログを選ぶ規則と、結果の語彙を足す

## Impact

- `plugins/dev-workflow/scripts/epic-dispatch.sh`（`keepalive_candidate`・`keepalive_child`・`decide_relaunch`・共有の選び方）、`plugins/dev-workflow/scripts/epic-state.sh`（`keepalive` の検査）、`plugins/dev-workflow/tests/epic-dispatch.bats`
- 範囲外: #1556（親が LLM を起こさず待つ）。#1545 は未着手のため今の main に合わせ、先に入ったほうに合わせて競合を直す
