## Context

Orca 経路のエピックでは、子は独立した Claude Code セッションで `/develop #<N>` を回し、主の返事を待って止まるときは子 issue に `子の停止: 主の返事待ち` の記録を投稿してから `epic-dispatch.sh mark stopped` で止まった印（Orca のワークツリーのコメント欄 `epic-stopped`）を付ける。親の `wait --watch-stopped` は印を見つけると `epic-stopped-seen` に書き換えて `stopped <N>` を返し、`--resolve` があれば判断して通す返事を送る。

子 issue が閉じたとき、`wait` は `closed <N>` を返し、親は手順 4 で `state_reason` を読んでエピックに `子 #N マージ → 残り k 件` を残し、後続を起動する。閉じた子は位置引数から外れるので、止まった印の検査（閉じていない子だけを見る）からも外れる。子のセッションは止まったままで、主が子のタブで返事をしない限り完了報告も `mark done` もしない。親の片付け（`reap`）は完了の印（`workspaceStatus == completed`）を要るので、`kept <N> not-done` が続く。

`epic-dispatch.sh` は Orca のコマンドを呼ぶ唯一のスクリプトで、手順書に `orca` のコマンドを書かない既存要件がある。返事の送信は `deliver_reply`（`reply` と `wait --resolve` が共用）が持ち、端末が無ければ起動し直す。

## Goals / Non-Goals

**Goals:**

- 止まった印のまま completed で閉じた子に、親が完了報告と `mark done` を促す返事を送り、主が子のタブを開かずに片付けまで進むようにする
- 送った判断をエピックに `親の判断: 子 #N 通した` の 1 行で残す（親を起動し直したときの復元元と、`stop-judge.sh` の繰り返しの判定の入力）
- 止まっていない子（動いている子・既に再開した子・既に完了の印を付けた子）と completed 以外で閉じた子には送らない
- 条件の判定と送信を bats で偽の `orca`・`gh` を使って確かめられる場所に置く

**Non-Goals:**

- `wait` の出力の形と終わり方を変えること（`closed` は今までどおり返す）
- `not_planned` などで閉じた止まった子への扱い（今までどおり主に報告する。作業されていない件に完了を促さない）
- 子が返事を受けたあとの完了報告の中身と、`mark done` の選び方（子の側の既存手順のまま）
- 同じ子へ 2 回送ることを機械で防ぐこと（下の Decisions の 3 つ目）

## Decisions

### 送る場所: 新しいサブコマンド `notify-closed` を足す

選んだもの: `epic-dispatch.sh notify-closed [--relaunch] <epic> <child>` を足し、親は手順 4 で completed の子ごとに 1 回呼ぶ。

比べた案:

- `wait` の中で送る（閉じた子を見つけたポーリングで、印と `state_reason` を見て送る）: 親の手順は増えないが、`wait` に閉じた子ごとの `gh` 呼び出しと送信の失敗の返し方が増え、`closed` の行の意味（閉じた子の一覧）に「送ったかどうか」が混ざる。`--resolve` の有無で振る舞いが分かれる組み合わせも増える。`wait` は背景で長く動くので、送信の失敗を親が知るには新しい出力の行が要る
- 手順書だけで、親が `reply --as parent` で送る: スクリプトは変えずに済むが、印の確認（Orca のコメント欄）は手順書から読めず（`orca` のコマンドを手順書に書かない既存要件）、条件の判定が bats で確かめられない。受け入れ条件の「止まっていない子には送らない」を機械で確かめられない

`notify-closed` なら、条件の判定（閉じた理由・印）と送信とエピックへの記録が 1 か所にまとまり、出力 1 行で親が扱いを決められる。手順 4 は既に `state_reason` を読んで子ごとに分岐しているので、呼ぶ場所が自然に決まる。

### 判定の条件と出力

`notify-closed` は次の順に確かめ、最初に当たったもので終わる。

1. 引数の誤り（`<epic>`・`<child>` が数字でない、引数の数、`--relaunch` 以外のフラグ）と返事の送り方の設定の誤り（`agent_setup`）→ 使い方を出して exit 1。`orca` を呼ばない
2. `gh api repos/{owner}/{repo}/issues/<child>` の `.state` が `closed` でない → `skipped <child> not-closed`。`.state_reason` が `completed` でない → `skipped <child> not-completed`。`gh` の失敗 → `failed <child> issue`
3. `orca worktree current --json` の repoId と同じ repoId・linkedIssue が `<child>`・archive されていないワークツリーが 0 件 → `skipped <child> no-worktree`（片付いた子に送るものはない）。2 件以上 → `failed <child> ambiguous-worktree`。一覧を読めない → `failed <child> list`
4. そのワークツリーの `workspaceStatus` が `completed` → `skipped <child> already-done`。コメント欄が `epic-stopped` でも `epic-stopped-seen` でもない → `skipped <child> not-stopped`
5. 子 issue のコメントから、1 行目が `子の停止: 主の返事待ち` で投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` の最新のものの URL を取る（取れなければ子 issue の URL を使う）
6. `deliver_reply`（`reply --as parent` と同じ処理）で、固定の文 `記録先の issue #<child> は completed で閉じた。完了報告を書き、mark done で終える（停止の記録: <URL>）` を送る。`failed <child> <段>` ならそのまま出して exit 1
7. 送れたら（`sent` か `relaunched`）、エピックに `親の判断: 子 #<child> 通した — 記録先が completed で閉じたので、完了報告と mark done を促した <URL>` を投稿する。投稿できたら `notified <child>`、失敗したら `unrecorded <child>` と stderr に投稿し直しのコマンド（`gh issue comment <epic> --body <その 1 行>`）。どちらも exit 0

`skipped` はすべて exit 0。エピックへの記録は送れたあとに投稿する（`wait --resolve` と同じ理由。送る前に残すと送れなかったときに送っていない判断が残る）。返事の文は親の判断として送る（頭は `親エピック #<epic> の判断（主の承認ではない）: `）。子は既存の手順どおり `mark resumed` を呼んで続きから進み、承認として扱わない。

### 2 回送ることは機械で防がない

`wait` が `closed <N>` を返すのは、その子が位置引数にある間の 1 回だけで、手順 4 はその子を動いている子から外す。手順 7（親を起動し直したとき）は `notify-closed` を呼ばない。親が同じ `closed` を 2 回処理したときだけ 2 通届くが、子は同じ促しを 2 回受けても完了報告を 1 回書いて印を付けるだけで、害は小さい。送ったあとに印を別の値に書き換える案は、子の `mark resumed`（止まった印のときだけ付く）を空振りさせ、既存の印の意味を変えるので採らない。

### 起動し直すかは親が決める

`reply` と同じく `--relaunch` を受け付け、`references/reply-after-idle.md` の表で決めるのは親（手順 4）とする。子の端末が無いときは `deliver_reply` が起動し直すので、親が表を当てはめるのは端末がある場合だけ。

## Risks / Trade-offs

- [子が止まった理由がマージ待ちではなく、別の質問で止まったまま主が PR をマージした] → 返事は「閉じたので完了報告を書いて終える」なので、子は残った質問を完了報告に書いて終える。閉じた記録先で作業を続ける理由は無い
- [`state_reason` が completed でも、主が手で閉じただけで PR がマージされていない] → 子の完了報告と `reap` の既存の確認（マージ済み PR の HEAD 一致など）が `kept` で止めるので、ワークツリーは消えない
- [親が手順 4 で `notify-closed` を呼び忘れる] → 今と同じ状態（子が止まったまま）に戻るだけ。bats は手順 4 の文面に `notify-closed` があることを確かめる
