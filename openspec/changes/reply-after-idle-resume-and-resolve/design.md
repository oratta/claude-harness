## 判断

1. **主の返事待ちの子の集め方（手順 7）**: 印（Orca のコメント欄）ではなく GitHub の記録から復元する。`launch` に渡したことのある開いた子ごとに、最新の `子の停止: 主の返事待ち` コメントと、2 行目の `停止の記録:` がその URL と一致する最新の `親の判断:` を読む（手順 8 と同じ照合・同じ author_association の条件）。`親の判断:` が「通した」以外（`主に上げる` / `判断できなかった` / 一致なし）で、その停止コメントより後に子の再開の記録（子 issue の新しいコメントまたは印 `epic-resumed`）が無い子を出し直す。`通すが送れなかった` は手順 8 と同じく送り直す。材料は GitHub にあるので、スクリプトは増やさず手順書だけで足りる。
   - 却下: `epic-stopped-seen` を `epic-stopped` に戻して `wait` に再度拾わせる。印の意味（親が一度受けた）が壊れ、主が答えるまで毎回起こされる。
2. **`--relaunch` の判定（resolve_stopped）**: `deliver_reply` を呼ぶ前に、同じスクリプト内の補助関数が表を当てる。端末の有無は `deliver_reply` が既に扱う（端末が無ければ起動し直す）ので、補助関数は端末ありの前提で「最後のリクエストから 60 分以上、かつ待ちの間のコンパクトなし、かつ会話量 N が 150,000 以上」のときだけ `relaunch=1` を返す。それ以外はすべて 0。
3. **判定の事実の読み方**:
   - トランスクリプト: 子のワークツリーのパス（`orca worktree list --json` の `path`）を `/` と `.` を `-` に置換した名前のディレクトリ `${CLAUDE_PROJECTS_DIR:-~/.claude/projects}/<名前>/*.jsonl`。ちょうど 1 本のときだけ使う。0 本・2 本以上は「読めない」。
   - 最後のリクエストの時刻: 最後の `type == "assistant"` の行の `timestamp`。
   - コンパクトの有無: 最後の assistant の行より後に `subtype == "compact_boundary"` の行がある。
   - 会話量 N: `subagent-context.sh --file <トランスクリプト>` の `context_tokens`。
   - どれか 1 つでも読めない・解釈できない・コマンドが失敗したときは `relaunch=0`（表の「扱いが揺れる子」と同じ）。
4. 閾値は表と同じ値を定数にし、`EPIC_DISPATCH_RELAUNCH_IDLE_SEC`（既定 3600）・`EPIC_DISPATCH_RELAUNCH_MIN_TOKENS`（既定 150000）で変えられる。
