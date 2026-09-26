# CI の見張り（dev-workflow の共有手順）

ゲートに合格した PR（と、`/ci-watch` の入口 `commands/ci-watch.md` で指定された PR）の CI が決着するまで待ち、落ちたらやり直すか直すかに進むための手順の正本。pr-review-gate と develop の SKILL.md はこの手順を言い換えずに、ここを参照する。

部品は `plugins/dev-workflow/scripts/ci-watch.sh` の 2 つのサブコマンドで、分類と一手の判断は同じディレクトリの `pr-state.sh` が持つ。

| コマンド | すること | 状態ファイル |
|---|---|---|
| `ci-watch.sh wait <owner/repo> <PR番号> [--until-merged]` | 決着するまで黙って待ち、1 行の JSON（`result` と `obs`）を出す | 読み書きしない |
| `ci-watch.sh next <owner/repo> <PR番号> [--unrelated <チェック名>]... [--after-fix]` | PR を取り直して一手（`act`）を決め、状態を保存する | 書き換える |

`next` は一手の実行（`gh run rerun`・push・ラベル操作）をしない。一手の実行は下の手順が持つ。

この手順は「呼び出し側」と「PR の実装者」という言い方で書く。develop では、呼び出し側は本体、実装者は W にあたる。

## 1. 見張りを始めるのは本体（メインセッション）だけ

サブエージェントは見張りを始めない。サブエージェントは自分が起動した背景タスクの完了では起こされないため（`references/subagent-waiting.md`「禁止と許可」）、`run_in_background` で待つと完了しても止まったままになる。ゲートをサブエージェント（develop の G など）が回しているときは、そのサブエージェントは見張りを始めずに `passed` を return し、呼び出し側の本体が見張る。

## 2. 1 つの PR を見張るのは 1 セッションだけ

状態ファイルは読んで書き戻すので、同じ PR を 2 つのセッションが見張ると修正回数の数え落としや二重の修正が起きる。

- 見張りを始める前に PR のコメントを見る。1 行目が `CI 見張り開始:` のコメントのあとに、1 行目が `CI 見張り終了:` のコメントが無ければ、ほかのセッションが見張り中として始めず、PR の URL を添えてオーナーに伝える
- 始めるときは、1 行目が `CI 見張り開始:` のコメントを PR に投稿する。本文には何を待っているか（PR の CI の決着を本体が待っていること）を 1 行添える。見張りを終えるときは、1 行目が `CI 見張り終了:` のコメントを投稿する（終えた理由を 1 行添える）
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
| `timeout` | `--until-merged` を付けずに起動した `wait` なら、PR の URL を添えて、CI が上限時間内に決着しなかったことをオーナーに 1 アクションで伝える。`--until-merged` を付けて起動した `wait` なら、マージされなかったとして、PR の URL を添えてオーナーにマージを頼む |
| `error` | `gh` の認証・ネットワークを確かめて 1 回だけ起動し直す。もう一度 `error` ならオーナーに伝える |

## 5. `--unrelated` を渡す基準

`wait` の `obs.state` が `ci-fail` で `obs.retry` が `false` のとき、`cause` が `real` のチェックごとに、`gh run view <run> --log-failed` の末尾（`| tail -n 80` のように範囲を切って読む）と `gh pr diff <PR番号> --repo <owner/repo> --name-only` を見て、次の 2 条件を両方満たすチェックだけを `next --unrelated <チェック名>` に渡す。どちらかが判断できなければ渡さない（直しに回る）。

1. 落ちたテスト・手順が、PR が変えたファイルと、それを直接読み込むテストに当たらない
2. 失敗の内容が PR の差分と因果を持たない（タイムアウト・ネットワーク・外部サービス・実行マシンの資源不足など、同じコードで結果が変わりうるもの）

守備範囲: この判断が受け取る入力は、`wait` の観測（`gh pr view` と `annotations` から作ったもの）、落ちた run のログの末尾（`gh run view --log-failed`）、PR の変更ファイルの一覧（`gh pr diff --name-only`）の 3 つに限る。拾いたい誤りは、PR に関わらない一時的な失敗（たまに落ちるテスト・外部サービスの一時的な不調）を直しに回して実装者を空振りさせることと、PR が原因の失敗をやり直して CI 1 周分を待つことの 2 つ。次の入力は誤った一手のまま通ることを許す: PR の変えたファイルを間接的に読み込むテストの失敗を「当たらない」と読み違えてやり直しに回す（同じ HEAD で 1 回だけなので損失は CI 1 周分で止まる）／ログの末尾に原因が出ない失敗は判断できずに直しに回る／1 つのチェックに PR に関わる失敗と関わらない失敗が混ざっていれば直しに回る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

## 6. `next` の一手ごとの動き

| `act` | 動き |
|---|---|
| `rerun` | `obs.runs` の各 run に `gh run rerun <run> --repo <owner/repo> --failed` を実行してから `wait` を起動し直す。やり直しに失敗したら、その旨を PR にコメントして `wait` を起動し直す（次の観測で `decide` が直しに回す） |
| `fix` | 下の 7 の直し方で直す。push したら、`agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直し（同じ見張りの続きなので、上の 2 の開始の判定・開始と終了のコメントはしない）、そのあとの `rerun`・`fix` もこの表どおりに処理する。ゲートの取り直しは `ready` になってから行う（下の「`ready` を受けたあと」） |
| `escalate` | PR に `needs-approval` を付け、落ちたチェック名と PR の URL を添えてオーナーに 1 アクションで頼み、見張りを終える |
| `ready` | 扱いは呼び出し側が決める（下の「`ready` を受けたあと」） |
| `none` | `obs.state` が `wait` のときだけ `wait` を起動し直す。それ以外の `none`（前回と同じ状態・同じ HEAD の決着、オーナーに上げ済み）は見張りを終え、PR の URL を添えてオーナーに状況（`obs.state` と、上げ済みならその旨）を伝える |

### `ready` を受けたあと

`ready` を受けたあとの扱いは呼び出し側が決める。`/ci-watch` の入口（見張る PR とマージ依頼の有無は `ci-watch.sh target` が決める）では `commands/ci-watch.md` の「3. `ready` を受けたら」に従い、`--merge` が無ければゲートに進まずに見張りを終え、`--merge` 付きならゲートの合格後に下の 1 から進む。ゲートの合格後に呼んだとき（pr-review-gate・develop）の扱いは次のとおり。

直しで `agent-review:passed` を外した PR（`agent-review:pending` が付いている）は、先にゲートを取り直す。取り直したゲートに合格するまで、下の 1〜3 のマージ待ち・マージ依頼に進まない。取り直したゲートが failed なら、ゲートの通常の周回で指摘を直し、push したら 6 の表の `fix` の行と同じく `wait` から続けて、`ready` になってから再び取り直す。保留になるか 2 周で合格が確定しなければオーナーに上げる。合格したら、同じ見張りの続きとして下の 1 から進む（上の 2 の開始の判定・開始のコメントはしない）。

1. まず PR のラベルを見る（`gh api repos/<owner/repo>/issues/<PR番号> --jq '.labels[].name'`）。`human-merge` / `needs-human-merge` / `human-only` / `needs-approval`（`.github/workflows/auto-merge.yml` の `BLOCKING_LABELS`。一覧が変わったらここも直す）のどれかが付いていれば、`--until-merged` で待たずに PR の URL を添えてオーナーにマージを頼み、見張りを終える
2. どれも付いておらず、自動マージの workflow（`.github/workflows/auto-merge.yml`）が対象リポにあれば、`ci-watch.sh wait <owner/repo> <PR番号> --until-merged` を `run_in_background` で起動して見届ける（結果の扱いは上の 4）
3. 自動マージの workflow が無ければ、PR の URL を添えてオーナーにマージを頼み、見張りを終える

どの呼び出し側でも、LLM が `gh pr merge` や merge API を叩いてはならない。

## 7. 直し方

genetta-inc/flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の修正手順を移したもの（住人の依頼の列とあなた待ちの操作は持ち込んでいない）。担い手は PR の実装者で、ゲートを回した側ではない（実装とレビューを別のコンテキストに保つため）。develop では W が直す。develop を使わずメインセッションで pr-review-gate を回したときは、メインセッションが実装者のサブエージェント（model は sonnet）を起こして直させる。

1. `git fetch origin` し、PR ブランチの worktree で作業する。残っていればそれを使い、無ければ対象リポの clone から切る。harness では `CLAUDE_HARNESS_DEV_DIR` の開発用 clone から切り、marketplace dir では作業しない
2. `conflict` は `git merge origin/main` で解く。版番号だけの競合は、main の値に PR の上げ幅を積んだ値にする（main が 1.4.0・PR が 1.3.0 → 1.3.1 なら 1.4.1）。`ci-fail` は `gh run view <run> --log-failed` を読んで直す。実装者がログを読んで PR の差分と関係ない失敗だと判断したら、直さず push もせずに呼び出し側へ返し、呼び出し側は `next --unrelated <チェック名> --after-fix` を 1 回だけ実行してその一手に従う（`--after-fix` は、直前の `fix` の判定で書かれた同じ状態・同じ HEAD の記録を外してやり直しを効かせる。同じ HEAD でのやり直しは 1 回までなので、失うのは CI 1 周分で止まる）
3. `agent-review:passed` が付いていた PR のとき、push の前に `gh api -X DELETE repos/<owner/repo>/issues/<PR番号>/labels/agent-review:passed` で外し、`gh pr view <PR番号> --repo <owner/repo> --json labels` で外れたことを確かめ、PR が Draft でなければ `gh pr ready --undo`（`gh pr ready <PR番号> --repo <owner/repo> --undo`）で Draft に戻し、`agent-review:pending` を付ける
4. オーナーにマージを頼んだ未解決の依頼があれば、差分が変わったので取り下げると PR にコメントする
5. commit して push する
6. `agent-review:passed` を外した PR（この直しで外したか、前の直しで外したまま `agent-review:pending` が付いている PR）は、push のあとすぐにはゲートを取り直さない。呼び出し側が 6 の表の `fix` の行どおり `wait` → `next` を続けて CI のやり直し・再度の直しを済ませ、`ready` になってからゲートを取り直す（「`ready` を受けたあと」）。合格するまで `agent-review:passed` を付け直さない
7. push の前に直せないと判断したときは、push せずに `escalate` と同じ手順でオーナーに上げる

## 8. 状態ファイル

置き場所は `${DEV_WORKFLOW_PR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dev-workflow/pr-state}/<owner>__<repo>__<PR番号>.json`。worktree の外に置くのは、直しで worktree を切り直したり撤去したりしても修正回数（`fixes`）と上げ済みの印（`raised`）が消えないようにするため。

`fix` のあとも消さずに使い続ける。修正回数は PR ごとに累計され、3 回目の失敗で `decide` が `escalate` を返す。状態ファイルは同じ PC のローカルにあり、1 つの PR を 1 セッションだけが見張る前提（上の 2）で読み書きする。
