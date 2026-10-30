# CI の見張り（dev-workflow の共有手順）

ゲートに合格した PR（と、`/ci-watch` の入口 `commands/ci-watch.md` で指定された PR）の CI が決着するまで待ち、落ちたらやり直すか直すかに進むための手順の正本。pr-review-gate と develop の SKILL.md はこの手順を言い換えずに、ここを参照する。

部品は `plugins/dev-workflow/scripts/ci-watch.sh` の 2 つのサブコマンドで、分類と一手の判断は同じディレクトリの `pr-state.sh` が持つ。

| コマンド | すること | 状態ファイル |
|---|---|---|
| `ci-watch.sh wait <owner/repo> <PR番号> [--until-merged]` | 決着するまで黙って待ち、1 行の JSON（`result` と `obs`）を出す | 読み書きしない |
| `ci-watch.sh next <owner/repo> <PR番号> [--unrelated <チェック名>]... [--after-fix]` | PR を取り直して一手（`act`）を決め、状態を保存する | 書き換える |

`next` の出力は `{act, next, obs}` で、`next.state` は保存する状態ファイルの `state` を表す。

`next` は一手の実行（`gh run rerun`・push・ラベル操作）をしない。一手の実行は下の手順が持つ。

この手順は「呼び出し側」と「PR の実装者」という言い方で書く。develop では、呼び出し側は本体、実装者は W にあたる。

## 1. 見張りを始めるのは本体（メインセッション）だけ

サブエージェントは見張りを始めない。サブエージェントは自分が起動した背景タスクの完了では起こされないため（`references/subagent-waiting.md`「禁止と許可」）、`run_in_background` で待つと完了しても止まったままになる。ゲートをサブエージェント（develop の G など）が回しているときは、そのサブエージェントは見張りを始めずに `passed` を return し、呼び出し側の本体が見張る。

## 2. 1 つの PR を見張るのは 1 セッションだけ

状態ファイルは読んで書き戻すので、同じ PR を 2 つのセッションが見張ると修正回数の数え落としや二重の修正が起きる。

- 見張りを始める前に PR のコメントを見る。1 行目が `CI 見張り開始:` のコメントのあとに、1 行目が `CI 見張り終了:` のコメントが無ければ、ほかのセッションが見張り中として始めず、PR の URL を添えてオーナーに伝える
- 始めるときは、1 行目が `CI 見張り開始:` のコメントを PR に投稿する。本文には何を待っているか（PR の CI の決着を本体が待っていること）を 1 行添える。見張りを終えるときは、1 行目が `CI 見張り終了:` のコメントを投稿する（終えた理由を 1 行添える）
- 前のセッションが閉じて終了のコメントが残らなかった見張りを、通知を受けていない別のセッションが引き継ぐには、下のオーナーの指示による再開の規則に従う。自分の会話で起動した待ちの `stopped` / `killed` の通知を受けた起動し直しのセッションは 9 に従う（オーナーの指示を待たない）。
- オーナーの指示で見張りを再開するとき（前のセッションが閉じて終了のコメントが残らなかった・オーナーに上げたあと続けるよう言われた）は、状態ファイルの `raised` を消すだけで済ませない。`decide` は前回と同じ状態・同じ HEAD の決着を `none` にするので、中断した一手を飛ばしたまま見張りが終わってしまう。先に状態ファイル（`state`・`head`・`fixes`・`reran_head`）と PR の記録（直しの依頼・push・`gh run rerun`・ラベル）から、中断した一手が済んでいるかを確かめる
  - 状態ファイルの `head` が PR の今の HEAD と同じで、`fix` の判定のあと直しの push が無いときは、`next` を呼ばずに、下の 7 の直し方の実装者への修正依頼から再開する（`fixes` は判定のときに数え済みなので書き換えない）
  - `rerun` の判定のあと、その HEAD で `gh run rerun` が実行されていなければ、6 の表の `rerun` の行の `gh run rerun` から再開する
  - `escalate` のあとに続けるよう言われたときは、オーナーの具体的な指示（直す・やり直す・関係ない失敗として扱うなど）を先に実行してから、`raised` を消して `wait` から見張りに戻る。指示が具体的でなければ、何をすればよいかをオーナーに聞き返す
  - `raised` の消し方: `f=<状態ファイル>; jq -c 'del(.raised)' "$f" > "$f.tmp" && mv -f "$f.tmp" "$f"`
- 同じセッションが `fix` の直しのあとに `wait` から始め直すときは、開始の判定も開始のコメントもしない。直しの担い手に渡すときも、終了のコメントは投稿しない。同じ見張りの続きで、新しい開始として扱うと、自分が投稿した `CI 見張り開始:` に対応する終了が無いので自分で自分を止めてしまう

## 3. 待ち方

`ci-watch.sh wait` を Bash ツールの `run_in_background` で起動し、完了通知で起こされてから出力を 1 回読む。前景のループで待たない。途中で出力を覗かない（ポーリングの途中経過を会話に出さないため）。

間隔と上限時間は `DEV_WORKFLOW_CI_WATCH_INTERVAL`（秒、既定 30）と `DEV_WORKFLOW_CI_WATCH_TIMEOUT`（秒、既定 3600）で変えられる。`wait` は最初の観測の前に 1 間隔待つ（push や `gh run rerun` の直後に古い失敗を読まないため）。

## 4. `wait` の結果ごとの動き

| `result` | 動き |
|---|---|
| `settled` | 下の 5 で `--unrelated` を渡すチェックを決めてから `ci-watch.sh next` を実行し、6 に進む。`--until-merged` の `wait` も `ci-fail`・`conflict` では `settled` を返す（`ready` だけを待ち続ける）ので、同じく `next` に進む |
| `merged` | 見張りを終えてマージを報告する |
| `closed` | 見張りを終える |
| `timeout` | `--until-merged` を付けずに起動した `wait` なら、PR の URL を添えて、CI が上限時間内に決着しなかったことをオーナーに 1 アクションで伝える。`--until-merged` を付けて起動した `wait` なら、マージされなかったとして、PR の URL を添えてオーナーにマージを頼む（エピックの子のセッションの頼む文面は、下の「`ready` を受けたあと」のエピックの子のマージ依頼の段落に従う） |
| `error` | `gh` の認証・ネットワークを確かめて 1 回だけ起動し直す。もう一度 `error` ならオーナーに伝える |

## 5. `--unrelated` を渡す基準

`wait` の `obs.state` が `ci-fail` で `obs.retry` が `false` のとき、`cause` が `real` のチェックごとに、`gh run view <run> --log-failed` の末尾（`| tail -n 80` のように範囲を切って読む）と `gh pr diff <PR番号> --repo <owner/repo> --name-only` を見て、次の 2 条件を両方満たすチェックだけを `next --unrelated <チェック名>` に渡す。どちらかが判断できなければ渡さない（直しに回る）。

1. 落ちたテスト・手順が、PR が変えたファイルと、それを直接読み込むテストに当たらない
2. 失敗の内容が PR の差分と因果を持たない（タイムアウト・ネットワーク・外部サービス・実行マシンの資源不足など、同じコードで結果が変わりうるもの）

`cause` が `job-timeout`（ジョブが上限時間で打ち切られた）のチェックはこの判断の対象でない。`real` でないので、`--unrelated` を渡さなくても同じ HEAD で 1 回やり直される（`runner-lost` と同じ）。

守備範囲: この判断が受け取る入力は、`wait` の観測（`gh pr view` と `annotations` から作ったもの）、落ちた run のログの末尾（`gh run view --log-failed`）、PR の変更ファイルの一覧（`gh pr diff --name-only`）の 3 つに限る。拾いたい誤りは、PR に関わらない一時的な失敗（たまに落ちるテスト・外部サービスの一時的な不調）を直しに回して実装者を空振りさせることと、PR が原因の失敗をやり直して CI 1 周分を待つことの 2 つ。次の入力は誤った一手のまま通ることを許す: PR の変えたファイルを間接的に読み込むテストの失敗を「当たらない」と読み違えてやり直しに回す（同じ HEAD で 1 回だけなので損失は CI 1 周分で止まる）／ログの末尾に原因が出ない失敗は判断できずに直しに回る／1 つのチェックに PR に関わる失敗と関わらない失敗が混ざっていれば直しに回る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

## 6. `next` の一手ごとの動き

| `act` | 動き |
|---|---|
| `rerun` | `obs.runs` の各 run に `gh run rerun <run> --repo <owner/repo> --failed` を実行してから `wait` を起動し直す。やり直しに失敗したら、`wait` を起動し直さず、その旨を PR にコメントして `needs-approval` を付け、オーナーに上げて見張りを終える（エピックの子の止まり方も `escalate` と同じ） |
| `fix` | 下の 7 の直し方で直す。push したら、`agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直し（同じ見張りの続きなので、上の 2 の開始の判定・開始と終了のコメントはしない）、そのあとの `rerun`・`fix` もこの表どおりに処理する。ゲートの取り直しは `ready` になってから行う（下の「`ready` を受けたあと」） |
| `escalate` | PR に `needs-approval` を付け、落ちたチェック名と PR の URL を添えてオーナーに 1 アクションで頼み、見張りを終える。`obs.checks` に `cause` が `job-timeout` のチェックがあるときは、そのチェック名と run に加えて「ジョブが上限時間で打ち切られた。ランナーの状態を確かめてほしい」と伝え、実装者に直しを頼まない（ランナーの状態は PR の差分では直せないため）。エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）は、止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まる（CI の見張りで止まったときの `再開に要る途中経過:` の書き方もそこが正本） |
| `ready` | 扱いは呼び出し側が決める（下の「`ready` を受けたあと」） |
| `none` | `obs.state` が `wait` のときは `wait` を起動し直す。`obs.state` が `ci-fail` でも `next.state`（状態ファイルの `state`）が `wait` の `none` は、やり直し直後の古い失敗なので `wait` を起動し直す。呼び出し側はこの古い失敗による起動し直しを数え、続けて 3 回この `none` で `wait` を起動し直しても決着しなければ、見張りを終えてオーナーに通知する。この回数は呼び出し側だけで管理し、別の結果になったらリセットする（状態ファイルや `pr-state.sh` の判定は増やさない）。それ以外の `none`（前回と同じ状態・同じ HEAD の決着、オーナーに上げ済み）は見張りを終え、PR の URL を添えてオーナーに状況（`obs.state` と、上げ済みならその旨）を伝える。エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）は、この `none` で見張りを終えるとき、止まる前に `skills/develop/references/epic-child-stop.md` の手順どおり記録を残して `mark stopped` で止まる（`escalate` と同じ。親が追加のやり直しを許したあと同じ HEAD でまた落ちたときはこの `none` になる） |

`job-timeout` は CI のジョブが自分の上限時間で打ち切られたことで、4 の表の `timeout`（見張りの上限時間内に決着を見られなかった）とは別の出来事。`job-timeout` の失敗は 1 回目が `rerun` になり、その HEAD のやり直しを使い切ったあとにもう一度見ると、`fix` ではなく `escalate` になる（修正回数は増えない）。前回の原因は見ないので、`--unrelated` や `runner-lost` でやり直したあとの初めての `job-timeout` も `escalate` になる。

守備範囲: この判断（`next.state` が `wait` の `none` を数える待ちと、`rerun` の失敗の扱い）の入力は、`next` の出力（`act`・`obs.state`・`next.state`）と、`gh run rerun` の終了コードの 2 つ。拾いたい誤りは、やり直し直後の古い失敗を決着と読んで直しに回すことと、やり直せないまま見張りが止まって赤の PR が残ること。GitHub の反映遅れで実際は進行中なのに連続 3 回 `none` が続いて通知する場合、`rerun` の失敗が一時的な通信の不調だったのに上げる場合は、誤った一手のまま通ることを許す（オーナーに余計に 1 通届くだけで止まる）。これらの穴を塞ぎ切ることはこの手順の完了条件にしない。

### `ready` を受けたあと

`ready` を受けたあとの扱いは呼び出し側が決める。`/ci-watch` の入口（見張る PR とマージ依頼の有無は `ci-watch.sh target` が決める）では `commands/ci-watch.md` の「3. `ready` を受けたら」に従い、`--merge` が無ければゲートに進まずに見張りを終え、`--merge` 付きならゲートの合格後に下の 1 から進む。ゲートの合格後に呼んだとき（pr-review-gate・develop）の扱いは次のとおり。

直しで `agent-review:passed` を外した PR（`agent-review:pending` が付いている）は、先にゲートを取り直す。取り直したゲートに合格するまで、下の 1〜3 のマージ待ち・マージ依頼に進まない。取り直したゲートが failed なら、ゲートの通常の周回で指摘を直し、push したら 6 の表の `fix` の行と同じく `wait` から続けて、`ready` になってから再び取り直す。保留になるか 2 周で合格が確定しなければオーナーに上げる。合格したら、同じ見張りの続きとして下の 1 から進む（上の 2 の開始の判定・開始のコメントはしない）。

1. まず PR のラベルを見る（`gh api repos/<owner/repo>/issues/<PR番号> --jq '.labels[].name'`）。`human-merge` / `needs-human-merge` / `human-only` / `needs-approval`（`.github/workflows/auto-merge.yml` の `BLOCKING_LABELS`。一覧が変わったらここも直す）のどれかが付いていれば、`--until-merged` で待たずに PR の URL を添えてオーナーにマージを頼み、見張りを終える（頼む文面は `~/.claude/output-styles/readable.md` の節 3 の型で書く。主に聞く理由は、人が押すと決まっているマージ。エピックの子のセッションの頼む文面は、1〜3 のあとの段落に従う）
   - ただし、エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）で、付いている見送りラベルが `human-merge` だけで、PR の base ブランチの `auto-merge.yml` に `parent-merge-approved` の語があるとき（`gh api "repos/<owner>/<repo>/contents/.github/workflows/auto-merge.yml?ref=<PR の base ブランチ>" --jq .content | base64 -d | grep -qF parent-merge-approved` が成功する）は、オーナーに直接頼まず、親の判断を待つ。develop の `skills/develop/references/epic-child-stop.md`（エピックの子が主の返事を待って止まるとき）の記録を `止まった理由: PR のマージ待ち（human-merge）: <PR の URL>` で残し、その手順どおり `mark stopped` で止まる（見張りの終了のコメントは投稿して終える）。どれかを満たさなければ上のとおりオーナーに頼む。残りの 6 項目は、たとえば次のように書く（記録の形の正本は `skills/develop/references/epic-child-stop.md` の側）:
     - `主に聞く理由:` 決まりで主の承認が要る（聖域のファイルに触れた PR は、人の判断を通してからマージすると決まっている。聖域の変更が人の目を通らずに入るのを防ぐため）。論点なし（決まりで聞いている。リスク宣言が「リスクなし」か、論点なしのとき）。論点ありのリスク宣言なら、その論点を書く。親の判断で回せる仕組みがあるので、まず親に判断を求める
     - `前提:` 聖域のどのパスに触れて `human-merge` が付いたか（自動マージの処理の投稿の URL）、ゲートの合格の HEAD と CI の状態
     - `推奨:` 親の判断で自動マージの処理に回す
     - `推奨の根拠:` 見送りが聖域接触だけで、ゲートが今の HEAD で済んでいる
     - `受け入れるリスク:` PR のリスク宣言のうち、マージすることで新たに生じるもの（宣言が「リスクなし」か論点なしなら `なし`）。書くときは何が起きるか・どれくらい起きるか・確かめたのか見込みかを添える
     - `再開に要る途中経過:` PR の URL と今の HEAD の SHA、ゲートの合格のコメントの URL
   - 親から `親エピック #<E> の判断（主の承認ではない）:` で始まる返事（エピックが別のリポジトリにあるときは、番号のあとに `（<owner>/<repo>）` が付く `親エピック #<E>（<owner>/<repo>）の判断（主の承認ではない）:` の形。先頭の `親エピック #` で照合する）が届いたら、新しい見張りとして上の 2 の重複の確認（1 行目が `CI 見張り開始:` のコメントのあとに `CI 見張り終了:` のコメントが無ければ始めない）と `CI 見張り開始:` のコメントの投稿をしてから、`ci-watch.sh wait <owner/repo> <PR番号> --until-merged` を `run_in_background` で起動して見届ける（結果の扱いは上の 4 のまま。止まるときに `CI 見張り終了:` を投稿しているので、開始の記録なしに始めると、別のセッションが同じ PR の見張りを重ねて始められてしまう）。`--until-merged` の `timeout` で改めて止まるときは、`止まった理由:` を `PR のマージ待ち（human-merge、親の返事のあともマージされない）: <PR の URL>` にする。子は `parent-merge-approved` ラベルも `親のマージ判断:` のコメントも付けない。親の返事は聖域の変更や破壊的な操作の承認ではなく、その返事で聖域のファイルを変えたりマージしたりしない
2. どれも付いておらず、自動マージの workflow（`.github/workflows/auto-merge.yml`）が対象リポにあれば、`ci-watch.sh wait <owner/repo> <PR番号> --until-merged` を `run_in_background` で起動して見届ける（結果の扱いは上の 4）
3. 自動マージの workflow が無ければ、PR の URL を添えてオーナーにマージを頼み、見張りを終える（頼む文面は `~/.claude/output-styles/readable.md` の節 3 の型で書く。主に聞く理由は、人が押すと決まっているマージ。エピックの子のセッションの頼む文面は、1〜3 のあとの段落に従う）

エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）がオーナーにマージを頼んで見張りを終えるとき（1 の見送りラベルで親の判断を待たずに頼むとき・3・4 の表の `--until-merged` で起動した `wait` の `timeout`）は、頼む文面に「マージしたら教えてください」のような、マージ後にオーナーがこのタブへ戻って知らせる依頼を書かず、「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書く。親の `epic-dispatch.sh wait --watch-done` が、記録先が completed で閉じて子のセッションが止まった子を完了と推定するため。エピックの子でないセッションの文面は変えない。

どの呼び出し側でも、LLM が `gh pr merge` や merge API を叩いてはならない。

## 7. 直し方

genetta-inc/flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の修正手順を移したもの（住人の依頼の列とあなた待ちの操作は持ち込んでいない）。担い手は PR の実装者で、ゲートを回した側ではない（実装とレビューを別のコンテキストに保つため）。develop では W が直す。develop を使わずメインセッションで pr-review-gate を回したときは、メインセッションが実装者のサブエージェント（model は sonnet）を起こして直させる。

1. `git fetch origin` し、PR ブランチの worktree で作業する。残っていればそれを使い、無ければ対象リポの clone から切る。harness では開発用の clone から切り、marketplace dir では作業しない
2. `conflict` は `git merge origin/main` で解く。版番号だけの競合は、main の値に PR の上げ幅を積んだ値にする（main が 1.4.0・PR が 1.3.0 → 1.3.1 なら 1.4.1）。`ci-fail` は `gh run view <run> --log-failed` を読んで直す。実装者がログを読んで PR の差分と関係ない失敗だと判断したら、直さず push もせずに呼び出し側へ返し、呼び出し側は `next --unrelated <チェック名> --after-fix` を 1 回だけ実行してその一手に従う（`--after-fix` は、直前の `fix` の判定で書かれた同じ状態・同じ HEAD の記録を外してやり直しを効かせる。同じ HEAD でのやり直しは 1 回までなので、失うのは CI 1 周分で止まる）
3. `agent-review:passed` が付いていた PR のとき、push の前に `gh api -X DELETE repos/<owner/repo>/issues/<PR番号>/labels/agent-review:passed` で外し、`gh pr view <PR番号> --repo <owner/repo> --json labels` で外れたことを確かめ、PR が Draft でなければ `gh pr ready --undo`（`gh pr ready <PR番号> --repo <owner/repo> --undo`）で Draft に戻し、`agent-review:pending` を付ける
4. オーナーにマージを頼んだ未解決の依頼があれば、差分が変わったので取り下げると PR にコメントする
5. commit して push する
6. `agent-review:passed` を外した PR（この直しで外したか、前の直しで外したまま `agent-review:pending` が付いている PR）は、push のあとすぐにはゲートを取り直さない。呼び出し側が 6 の表の `fix` の行どおり `wait` → `next` を続けて CI のやり直し・再度の直しを済ませ、`ready` になってからゲートを取り直す（「`ready` を受けたあと」）。合格するまで `agent-review:passed` を付け直さない
7. push の前に直せないと判断したときは、push せずに `escalate` と同じ手順でオーナーに上げる

## 8. 状態ファイル

置き場所は `${DEV_WORKFLOW_PR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dev-workflow/pr-state}/<owner>__<repo>__<PR番号>.json`。worktree の外に置くのは、直しで worktree を切り直したり撤去したりしても修正回数（`fixes`）と上げ済みの印（`raised`）が消えないようにするため。

`fix` のあとも消さずに使い続ける。修正回数は PR ごとに累計され、3 回目の失敗で `decide` が `escalate` を返す。状態ファイルは同じ PC のローカルにあり、1 つの PR を 1 セッションだけが見張る前提（上の 2）で読み書きする。

## 9. 起動し直したセッションが見張りの待ちの `stopped` / `killed` の通知を受けたとき

対象は、自分の会話で `run_in_background` で起動した `ci-watch.sh wait <owner/repo> <PR番号>`（`--until-merged` 付きも含む）の待ちが切れ、起動し直したセッションに `stopped` / `killed` の通知が届いた場合。このセッションが自分で TaskStop で止めた待ちの `killed` は対象外とする。

通知を受けたあとの最初のターンで、次の手順を実行する。ターンを起こしたのが通知そのものでも、親の返事や主の入力でも同じに扱う。入力なしでセッションを起こす部分は #1084 が受け持つ。

1. 通知の task id / tool-use id から、自分の会話でその背景タスクを起動したコマンドを確かめ、`<owner/repo>` と PR 番号を取る。状態ファイルの一覧から PR を推測しない。
2. `gh pr view <PR番号> --repo <owner/repo> --json state` で PR の状態を確かめ、`gh api --paginate repos/<owner/repo>/issues/<PR番号>/comments` でコメントを全ページ読む。1 行目が `CI 見張り開始:` の最新のコメントと、そのあとに 1 行目が `CI 見張り終了:` のコメントがあるかを確かめる。
   - 終了のコメントがあれば何もしない。
   - 終了のコメントが無く、PR が merged / closed なら再開せず、1 行目が `CI 見張り終了:` のコメントを投稿する（終えた理由を 1 行添える）。merged ならマージを報告し、closed なら見張りを終える。
   - PR が open で、最新の開始のコメントがあり、そのあとに終了のコメントが無いときだけ再開する。
3. 再開すると決まったら、主やオーナーに再開してよいかを聞き返さずに `ci-watch.sh next <owner/repo> <PR番号>` を `--unrelated` なしで実行し、その出力を 6 の表どおりに処理する。`obs.state` が `wait` の `none` なら待ちに戻り、`ready` なら「`ready` を受けたあと」に進む（切れた待ちが `--until-merged` 付きでも同じ）。

同じ見張りの続きなので、2 の開始の判定も開始のコメントもしない。通知が届くのは `wait` の実行中に落ちた場合で、待ちの前の一手は済んでいるため、2 の中断した一手の確認も要らない。通知を受けていない別のセッションが始める・引き継ぐ場合は、2 のオーナーの指示による再開の規則に従う。

守備範囲: この判断の入力は、自分の待ちの `stopped` / `killed` の通知、`gh pr view` の PR の状態、開始・終了の PR コメント（全ページ）の 3 つ。拾いたい誤りは、決着済みの見張りを再開して二重の修正や修正回数の数え落としを起こすことと、決着していない見張りを放置して赤の PR が残ること。落ちている間に別のセッションが 2 の規則で再開していて見張りが重なる入力、開始・終了のコメントを人が消したり書き換えたりした入力、通知が届かない起動のしかた（`/clear` からの起動し直しなど）で何も起きない入力は通ることを許す。これらの穴を塞ぎ切ることは、この要件の完了条件にしない。
