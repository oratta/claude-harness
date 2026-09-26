## Context

- `plugins/dev-workflow/scripts/pr-state.sh`（#521）は `gh pr view --json mergeable,statusCheckRollup,headRefOid` の JSON を `observe` で `conflict` / `ci-fail` / `ready` / `wait` に分け、`decide` で前回の状態から次の一手（`none` / `ready` / `rerun` / `fix` / `escalate`）と次の状態を返す。`gh` を呼ぶのは `annotations` だけで、状態の保存・一手の実行は呼び出し側が持つ（`openspec/specs/dev-workflow-pr-state/spec.md`）
- ゲートの合格処理（pr-review-gate 手順 5）は、Draft なら Ready にしてから `agent-review:passed` を付けて終わる。そのあと CI が落ちても誰も見ていない。harness の auto-merge workflow は passed と CI の結論を見てマージするが、CI が落ちればスキップして終わる
- develop では、ゲートを回すのは名前付きサブエージェントの G。`plugins/dev-workflow/references/subagent-waiting.md` のとおり、サブエージェントは背景タスクの完了通知では起こされず、メインセッション（本体）は起こされる
- 直し方の手順は flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の「修正依頼を受けたターンの手順」にある（PR ブランチの worktree・版番号だけのコンフリクトの解き方・ラベルの外し方・ゲートの取り直し）。住人の依頼の列（`pending-mirror.sh pr-watch tasks` / `done`）とあなた待ちの項目に依存する部分は持ち込まない
- 後続の #523 は、ゲートを通していない PR について同じ待ち方と仕分けを呼ぶ入口を作る

## Goals / Non-Goals

**Goals:**

- ゲートに合格した PR の CI が落ちたら、オーナーが何もしなくても本体が起こされ、`decide` の一手どおりにやり直すか直すかに進む
- 待っている間、ポーリングの途中経過を本体の会話に出さない
- 待ち方と仕分けを、ゲートにも develop にも #523 の入口にも依存しない部品（スクリプト 1 本と共有 reference 1 本）に置く

**Non-Goals:**

- `pr-state.sh` の判定規則の変更（#535〜#539 の小さな直しを含めて範囲外）
- #523 の入口そのもの（コマンドかスキル）と、「マージして」を承認として扱う範囲
- unmanned モードと住人（flatmate の pr-watch）への配線（住人は genetta-inc/flatmate#976）
- LLM が `gh pr merge` や merge API でマージすること（ゲートの既存の禁止のまま）

## Decisions

### 待つのは本体だけ。G は見張りを始めずに passed を返す

サブエージェントの G が `run_in_background` で待つと、完了しても G は起こされず、親が SendMessage を送るまで止まる（2026-09-08 に G が 5 回止まった実例が `subagent-waiting.md` にある）。前景の有限ループで待つ形（subagent-waiting.md の 27 分上限）も、CI の所要時間が読めないうえ、その間 G が親からの SendMessage を処理できない。そこで見張りはメインセッションだけが始める。pr-review-gate は「メインセッションで回していれば自分で始め、サブエージェントなら passed を return して呼び出し側に任せる」と書き分け、develop は (4) の passed を受けた本体が始める。

代替案: G に前景ループで待たせる → CI が 27 分を超えるリポで取りこぼし、G のコンテキストに待ちの往復が積もるので捨てた。

### 待つだけのスクリプト `ci-watch.sh wait` と、一手を取り出して状態を保存する `ci-watch.sh next` に分ける

`wait` は決着するまで何も出さず、決着したら 1 行の JSON を出して終わる。本体はこれを `run_in_background` で起動し、完了通知で起こされてから出力を 1 回読むだけなので、ポーリングが会話に出ない。`wait` は状態ファイルを書かない（何度起動し直しても副作用が無い）。

`next` はその時点の PR を取り直して `annotations` → `observe`（呼び出し側が渡した `--unrelated` 付き）→ `decide` に通し、状態ファイルを書き換える。状態を書くのを `next` 1 か所にしたのは、`--unrelated` を渡すかどうかの判断（次節）を `wait` の出力を見てから行い、その判断を入れた観測だけを状態に反映させるため。`wait` と `next` の間に HEAD が変わっていても、`next` が取り直した観測で `decide` するので状態は崩れない。

`rerun` の `gh run rerun` と `fix` の修正は `next` では行わず、reference の手順として本体が行う。`next` が副作用を持つのは状態ファイルだけにしておくと、#523 の入口が一手の実行のしかた（マージの扱いなど）を変えても `next` を変えずに済む。

代替案: 1 本のスクリプトで待ちから一手の実行まで行う → `--unrelated` の判断を挟めず、#523 で一手の扱いが変わるたびにスクリプトに分岐が増えるので捨てた。

### `wait` の決着の条件と上限

`wait` は、`gh pr view --json state,mergeable,statusCheckRollup,headRefOid` を `observe` に通し、`state` が `wait` 以外になったら `{"result":"settled","obs":<observe の出力>}` を出す。PR がマージされたら `merged`、閉じられたら `closed`、上限時間に達したら `timeout`、`gh` が続けて失敗したら `error` を出す。決着したときの `obs` には `annotations` の手がかりを入れる（通信切れの判定が済んだ観測を本体が読めるように）。`--until-merged` では `ready` でも決着させず、マージか閉じるか上限時間まで待つ。

間隔と上限は環境変数で変えられるようにし（`DEV_WORKFLOW_CI_WATCH_INTERVAL` 既定 30 秒、`DEV_WORKFLOW_CI_WATCH_TIMEOUT` 既定 3600 秒）、リポごとの CI の所要時間を要件に直書きしない。最初の観測の前に 1 間隔待つ。`gh run rerun` の直後や push の直後に起動したとき、GitHub がチェックを未確定に戻す前の古い失敗を読んで決着してしまうのを避けるため。

### 前回の状態は PR ごとのローカルファイルに置く

置き場所は `${DEV_WORKFLOW_PR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dev-workflow/pr-state}/<owner>__<repo>__<PR番号>.json`。見張るのは同じ PC の本体なので、ローカルファイルで足りる。worktree の中に置かないのは、`fix` で worktree を切り直したり撤去したりしても修正回数（`fixes`）と上げ済みの印（`raised`）が消えないようにするため。ファイルが無ければ初見として `decide` に渡す。

代替案: PR コメントに状態を書く → PC をまたいで引き継げるが、見張るたびに PR にコメントが積もり、照合の手間も増える。PC をまたいだ見張りはこの issue の要件に無いので捨てた。

### `--unrelated` は、本体がログを読んで 2 条件を満たすチェックだけに渡す

`wait` の観測が `ci-fail` で `retry` が `false` のとき、本体は `cause` が `real` の落ちたチェックごとに `gh run view <run> --log-failed` の末尾（範囲を切って読む）と `gh pr diff --name-only` を見て、次の 2 条件を両方満たすチェックだけを `next --unrelated <チェック名>` に渡す。

1. 落ちたテスト・手順が、PR が変えたファイル（とそれを直接読み込むテスト）に当たらない
2. 失敗の内容が PR の差分と因果を持たない（タイムアウト・ネットワーク・外部サービス・実行マシンの資源不足など、同じコードで結果が変わりうるもの）

どちらかが判断できなければ渡さない（直しに回る）。読み違えて PR に関わる失敗を渡しても、`decide` のやり直しは同じ HEAD で 1 回だけなので、失うのは CI 1 周分で止まる（#521 の守備範囲に書かれたとおり）。

代替案: 既知の不安定なチェック名をリポごとの設定に並べる → `--unrelated` はチェック単位なので、1 つのチェックにテストが全部入っているリポでは本当の失敗までやり直しに回るうえ、設定の手入れが要るので捨てた。main の直近の結果と比べる → main でも落ちているなら壊れているのは main でやり直しでは通らず、「たまに落ちる」を見分けられないので捨てた。

### 直し方の手順は共有 reference に置き、担い手は実装者

直し方は `references/ci-watch.md` に置き、pr-review-gate から参照する。担い手は PR の実装者（develop では W。再開か手渡しかは develop のコンテキスト上限の規則に従う）。ゲートを回している側（G）には直させない（実装とレビューを別コンテキストに保つゲートの前提のため）。flatmate からの変更点は、住人の依頼の列とあなた待ちの操作を外したことと、ラベルを外すときにゲートの手順 1 に合わせて Draft に戻し `agent-review:pending` を付けること（取り直しのゲートが「passed が付いていなかった」扱いになって Draft に戻さない食い違いを避けるため）。版番号だけのコンフリクトの解き方は、版を上げない harness では起きないが、他のリポで使う手順なので残す。

### 取り直したゲートに合格したら、同じ状態ファイルのまま見張りを続ける

`fix` のあとゲートに合格したら、本体はもう一度 `wait` から始める。状態ファイルは消さないので、`fixes` は PR ごとに累計され、3 回目の失敗で `decide` が `escalate` を返す。直せなかったとき（ゲートに合格しなかった・実装者が直せなかった）は push せずに `escalate` と同じ手順でオーナーに上げる。

## Risks / Trade-offs

- [本体のセッションが閉じると見張りも止まる] → 背景タスクは本体のセッションの中で動く。閉じたら止まったことをオーナーが見て分かるよう、見張りを始めたときに PR に 1 行（何を待っているか）をコメントする。住人の常時見張り（flatmate#976）とは担う範囲が違う
- [完了通知で本体が起こされる前提が崩れる] → Claude Code の背景タスクの挙動に依存する。崩れたら reference の待ち方だけを差し替える（`wait` の出力と `next` は変わらない）
- [`--unrelated` の判断が本体の読み取りに依存する] → 判断を誤ったときの損失は同じ HEAD で CI 1 周分。ログは末尾だけを読み、本体のコンテキストを食い過ぎないようにする
- [push 直後の古い失敗を読む] → 最初の観測の前に 1 間隔待つ。それでも読んだ場合は `decide` の「同じ状態・同じ HEAD は none」で二重の一手にはならないが、`rerun` 直後の古い失敗を読むと `fix` に進みうる。実機確認でこの間隔が足りるかを見る
- [実機確認のやり直しの経路は判断の入力を人が与える] → ubuntu のランナーでは実行マシンの通信切れを起こせず、捨て PR で足したテストは必ず PR の差分に入るので、本体の 2 条件の判断では `--unrelated` にならない。実機確認では、1 回目だけ落ちるテストに対して本体が `--unrelated` を明示して渡し、`rerun` → 通る、の配線を確かめる（2 条件の判断そのものは reference の記述とレビューで担保する）
