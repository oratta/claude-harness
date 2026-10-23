# dev-workflow-ci-watch Specification

## Purpose
pr-review-gate の合格後に、PR の CI が決着するまで本体が黙って待ち、落ちたら直す・やり直す・オーナーに伝えるのどれに進むかを決める見張りの振る舞い（`ci-watch.sh` の wait / next と共有 reference `references/ci-watch.md`）を定める。
## Requirements
### Requirement: wait は PR の CI が決着するまで黙って待ち、決着したら 1 行の JSON を出す
`plugins/dev-workflow/scripts/ci-watch.sh wait <owner/repo> <PR番号> [--until-merged]` は、最初に 1 間隔待ってから、`gh pr view <PR番号> --repo <owner/repo> --json state,mergeable,statusCheckRollup,headRefOid` を間隔を空けて繰り返し、次のどれかに当たった時点で 1 行の JSON を標準出力に出して exit 0 で終わらなければならない（MUST）。当たるまでは標準出力に何も出してはならない（MUST NOT）。

1. PR の `state` が `MERGED`: `{"result":"merged","obs":null}`
2. PR の `state` が `CLOSED`: `{"result":"closed","obs":null}`
3. 同じ JSON を `pr-state.sh annotations <owner/repo>` の出力を `--hints` にして `pr-state.sh observe` に通した結果の `state` が `wait` 以外（`--until-merged` があるときは `wait` と `ready` 以外。`--until-merged` は `ready` だけを待ち続け、`ci-fail`・`conflict` は決着として返す）: `{"result":"settled","obs":<observe の出力>}`
4. 起動からの経過が上限時間を超えた: `{"result":"timeout","obs":<最後の observe の出力。一度も取れていなければ null>}`
5. `gh pr view` が続けて 5 回失敗した: `{"result":"error","obs":null}`（1〜4 回の失敗は警告を標準エラーに出して待ちを続ける）

間隔は環境変数 `DEV_WORKFLOW_CI_WATCH_INTERVAL`（秒、既定 30）、上限時間は `DEV_WORKFLOW_CI_WATCH_TIMEOUT`（秒、既定 3600）で決めなければならない（MUST）。値が正の整数でなければ既定値を使う（MUST）。`annotations` は `observe` の `state` が `wait` 以外になった回だけ呼ぶ（MUST。待っている間の毎回には呼ばない）。`wait` は状態ファイルを読み書きしてはならない（MUST NOT）。引数が足りないときは標準出力に何も出さずに非 0 で終わる（MUST）。

守備範囲: `wait` が受け取る入力は `gh pr view` の JSON（GitHub が返す PR の状態）と `annotations` の出力に限る。拾いたい誤りは、CI の決着を待たずに一手に進むこと・決着したのに待ち続けること・ポーリングの途中経過が呼び出し側の会話に出ることの 3 つ。次の入力は誤ったまま通ることを許す: push や `gh run rerun` の直後に、GitHub がチェックを未確定に戻す前の古い失敗を 1 間隔の待ちのあとでも読んだときは、その古い観測で決着する／上限時間より長くかかる CI は `timeout` になる／`gh` が 5 回より少ない回数で断続的に失敗し続ける間は上限時間まで待ち続ける。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 実行中のあいだは何も出さず、落ちたら settled を出す
- **WHEN** PATH 先頭の `gh` の偽物が、1 回目は実行中のチェック、2 回目は失敗したチェック（`/actions/runs/11/job/77`）を含む JSON を返し、`DEV_WORKFLOW_CI_WATCH_INTERVAL=1` で `wait o/r 5` を実行する
- **THEN** 標準出力はちょうど 1 行で、`.result` が `settled`、`.obs.state` が `ci-fail`、`.obs.runs` が `["11"]`、終了コードは 0

#### Scenario: 決着した回だけ annotation を取る
- **WHEN** 上と同じ偽物で `wait` を実行する
- **THEN** `gh api .../check-runs/77/annotations` の呼び出しは 1 回だけで、実行中だった回には呼ばれない

#### Scenario: 通信切れの annotation は決着した観測に入る
- **WHEN** 失敗したジョブ 77 の annotation が `The self-hosted runner lost communication with the server` を含む
- **THEN** `.obs.checks[0].cause` が `runner-lost`、`.obs.retry` が `true`

#### Scenario: マージされたら merged
- **WHEN** `gh pr view` の `state` が `MERGED` を返す
- **THEN** 出力は `{"result":"merged","obs":null}`

#### Scenario: until-merged は ready でも待ち続ける
- **WHEN** `--until-merged` を付け、偽物が 1 回目は全チェック成功の `OPEN`、2 回目は `MERGED` を返す
- **THEN** 出力は `{"result":"merged","obs":null}` で、`gh pr view` は 2 回呼ばれる

#### Scenario: until-merged でも ready のあとの CI の失敗は settled を返す
- **WHEN** `--until-merged` を付け、`DEV_WORKFLOW_CI_WATCH_TIMEOUT=10` で、偽物が 1 回目は全チェック成功の `OPEN`、2 回目は失敗したチェック（ジョブ 78。annotation に `The self-hosted runner lost communication with the server` を含む）を返す
- **THEN** 上限時間を待たずに `.result` が `settled`、`.obs.state` が `ci-fail`、`.obs.checks[0].cause` が `runner-lost` で、`gh pr view` は 2 回、ジョブ 78 の annotation の呼び出しは 1 回

#### Scenario: until-merged でも ready のあとの競合は settled を返す
- **WHEN** `--until-merged` を付け、`DEV_WORKFLOW_CI_WATCH_TIMEOUT=10` で、偽物が 1 回目は全チェック成功の `OPEN`・`MERGEABLE`、2 回目は `CONFLICTING` を返す
- **THEN** 上限時間を待たずに `.result` が `settled`、`.obs.state` が `conflict` で、`gh pr view` は 2 回

#### Scenario: 上限時間を超えたら timeout
- **WHEN** 偽物が常に実行中のチェックを返し、`DEV_WORKFLOW_CI_WATCH_INTERVAL=1`・`DEV_WORKFLOW_CI_WATCH_TIMEOUT=3` で実行する
- **THEN** `.result` が `timeout`、`.obs.state` が `wait`

#### Scenario: gh が続けて失敗したら error
- **WHEN** 偽物の `gh pr view` が常に非 0 で終わる
- **THEN** 5 回目の失敗で `{"result":"error","obs":null}` を出して終わり、標準エラーに警告がある

#### Scenario: 状態ファイルに触れない
- **WHEN** `DEV_WORKFLOW_PR_STATE_DIR` を空のディレクトリにして `wait` を実行する
- **THEN** 終了後もそのディレクトリは空

### Requirement: next は PR の一手を取り出し、PR ごとの状態ファイルを書き換える
`ci-watch.sh next <owner/repo> <PR番号> [--unrelated <チェック名>]... [--after-fix]` は、`gh pr view <PR番号> --repo <owner/repo> --json mergeable,statusCheckRollup,headRefOid` の JSON を `pr-state.sh annotations <owner/repo>` に通して手がかりを作り、同じ JSON を `pr-state.sh observe --hints <手がかり> [--unrelated <チェック名>]...` に、その出力を `pr-state.sh decide <前回の状態>` に通し、`decide` の出力をそのまま 1 行で標準出力に出さなければならない（MUST）。`--unrelated` は受け取った順にすべて `observe` に渡す（MUST）。`--after-fix` があるときは、前回の状態の `state` を `wait` に置き換えてから `decide` に渡さなければならない（MUST）。`--after-fix` は、`fix` を受けた実装者が「PR と関係ない失敗」と判断して直さずに返したときだけ使う引数で、直前の `fix` の判定で書かれた `{state: ci-fail, head: <同じ HEAD>}` によって `decide` の「前回と同じ状態・同じ HEAD なら none」がやり直しより先に効くのを避けるためのもの。`state` 以外のキー（`fixes` など）は変えない（MUST）。

前回の状態は状態ファイル `<状態ディレクトリ>/<owner>__<repo>__<PR番号>.json` から読み（無ければ `{}`）、`decide` の `.next` で上書きしなければならない（MUST）。状態ディレクトリは `DEV_WORKFLOW_PR_STATE_DIR`、無ければ `${XDG_STATE_HOME:-$HOME/.local/state}/dev-workflow/pr-state` とし、無ければ作る（MUST）。上書きは一時ファイルに書いてから置き換える（MUST。途中で止まって半端なファイルを残さないため）。`gh pr view` か `pr-state.sh` のどれかが非 0 で終わったら、状態ファイルを書き換えずに非 0 で終わらなければならない（MUST）。状態ファイルが JSON として読めないときも、書き換えずに非 0 で終わる（MUST）。

`next` は `gh run rerun`・push・ラベル操作などの一手の実行を行ってはならない（MUST NOT。一手の実行は呼び出し側の手順が持つ）。

#### Scenario: 初見は空の状態で decide して状態を書く
- **WHEN** 状態ファイルが無く、偽物が本当の失敗（run 11、HEAD `h1`）を返す
- **THEN** 出力の `.act` が `fix`、状態ファイルが作られ、その中身の `.fixes` が 1、`.head` が `h1`

#### Scenario: 前回の状態を読んで decide に渡す
- **WHEN** 状態ファイルが `{"state":"ci-fail","head":"h1","fixes":2}` で、偽物が HEAD `h2` の本当の失敗を返す
- **THEN** `.act` が `escalate`、状態ファイルの `.raised` が `true`

#### Scenario: unrelated を observe に渡す
- **WHEN** 偽物がチェック `flaky`（run 11）の失敗を返し、`next o/r 5 --unrelated flaky` を実行する
- **THEN** `.act` が `rerun`、`.obs.checks[0].cause` が `unrelated`、状態ファイルの `.reran_head` が観測の HEAD

#### Scenario: 直しの担い手が関係ないと返したあとは after-fix でやり直す
- **WHEN** 状態ファイルが `{"state":"ci-fail","head":"h1","fixes":1}` で、偽物がチェック `flaky`（run 11、HEAD `h1`）の失敗を返し、`next o/r 5 --unrelated flaky --after-fix` を実行する
- **THEN** `.act` が `rerun`、状態ファイルの `.fixes` が 1 のまま、`.reran_head` が `h1`

#### Scenario: gh が失敗したら状態を書き換えない
- **WHEN** 状態ファイルが `{"fixes":1}` で、偽物の `gh pr view` が非 0 で終わる
- **THEN** `next` は非 0 で終わり、状態ファイルの中身は `{"fixes":1}` のまま

#### Scenario: 一手を実行しない
- **WHEN** `.act` が `rerun` になる入力で `next` を実行する
- **THEN** 偽物の `gh` に `run rerun` の呼び出しが無い

### Requirement: CI の見張りの手順は共有 reference に 1 本置く
`plugins/dev-workflow/references/ci-watch.md` は、合格後（と #523 の入口から呼ばれたとき）の CI の見張りの手順の正本として、次を書かなければならない（MUST）。pr-review-gate と develop の SKILL.md はこの手順を言い換えて再掲せず、この reference を参照する（MUST）。reference の中でゲートを前提にする手順（直し方の ③ と ⑥）は、③ を「`agent-review:passed` が付いていた PR のとき」、⑥ を「`agent-review:passed` を外した PR（`agent-review:pending` が付いている PR）」に限って行うと書き、`ready` を受けたあとの扱いは呼び出し側が決める差し込み口として書く（MUST。#523 の入口がゲートを通していない PR についてそのまま呼べるようにするため）。

1. **待つのは本体（メインセッション）だけ**: サブエージェントは見張りを始めない。理由として `references/subagent-waiting.md` の「背景タスクの完了では起こされない」を参照する
2. **1 つの PR を見張るのは 1 セッションだけ**: 見張りを始めるとき、PR に 1 行目が `CI 見張り開始:` のコメント（何を待っているか＝PR の CI の決着を本体が待っていること、を添える）を投稿し、見張りを終えるときに 1 行目が `CI 見張り終了:` のコメントを投稿する。始める前に PR のコメントを見て、`CI 見張り開始:` のあとに `CI 見張り終了:` が無ければ、ほかのセッションが見張り中として始めず、PR の URL を添えてオーナーに伝える。オーナーの指示で見張りを再開するとき（前のセッションが閉じた・オーナーに上げたあと続けるよう言われた）は、状態ファイルの `raised` を消すだけで済ませず、状態ファイル（`state`・`head`・`fixes`・`reran_head`）と PR の記録（直しの依頼・push・`gh run rerun`・ラベル）から中断した一手が済んでいるかを確かめる。状態ファイルの `head` が PR の今の HEAD と同じで、`fix` の判定のあと直しの push が無いときは、`next` を呼ばずに（`decide` が同じ状態・同じ HEAD の決着を `none` にするため）直し方の実装者への修正依頼から再開する。`rerun` の判定のあとその HEAD で `gh run rerun` が実行されていなければ、`gh run rerun` から再開する。`escalate` のあとに続けるよう言われたときは、オーナーの具体的な指示（直す・やり直す・関係ない失敗として扱うなど）を先に実行してから、`raised` を消して `wait` から見張りに戻る。同じセッションが `fix` の直しのあとに `wait` から始め直すときは、開始の判定も開始のコメントもしない。直しの担い手に渡すときも、終了のコメントは投稿しない
3. **待ち方**: `ci-watch.sh wait` を Bash ツールの `run_in_background` で起動し、完了通知で起こされてから出力を 1 回読む。前景のループで待たない・途中で出力を覗かない
4. **`wait` の結果ごとの動き**: `settled` → 下の 5 で `--unrelated` を決めてから `next` を実行する（`--until-merged` の `wait` が `ci-fail`・`conflict` で返した `settled` も同じ）／`merged` → 見張りを終えてマージを報告する／`closed` → 見張りを終える／`timeout` → `--until-merged` を付けずに起動した `wait` なら、PR の URL を添えて CI が上限時間内に決着しなかったことをオーナーに 1 アクションで伝える。`--until-merged` を付けて起動した `wait` なら、マージされなかったとして PR の URL を添えてオーナーにマージを頼む／`error` → `gh` の認証・ネットワークを確かめて 1 回だけ起動し直し、もう一度 `error` ならオーナーに伝える
5. **`--unrelated` を渡す基準**: `wait` の `obs.state` が `ci-fail` で `obs.retry` が `false` のとき、`cause` が `real` のチェックごとに、`gh run view <run> --log-failed` の末尾（範囲を切って読む）と `gh pr diff --name-only` を見て、「落ちたテスト・手順が PR の変えたファイルとそれを直接読み込むテストに当たらない」と「失敗の内容が PR の差分と因果を持たない（タイムアウト・ネットワーク・外部サービス・実行マシンの資源不足など）」の両方を満たすものだけを渡す。どちらかが判断できなければ渡さない
6. **`next` の一手ごとの動き**: `rerun` → `obs.runs` の各 run に `gh run rerun <run> --failed` を実行してから `wait` を起動し直す（やり直しに失敗したら、その旨を PR にコメントして `wait` を起動し直す。次の観測で `decide` が直しに回す）／`fix` → 下の 7 の直し方で直す。push したら、`agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直し（同じ見張りの続きなので、上の 2 の開始の判定・開始と終了のコメントはしない）、そのあとの `rerun`・`fix` もこの一手どおりに処理する。ゲートの取り直しは `ready` になってから行う／`escalate` → `needs-approval` を付け、落ちたチェック名と PR の URL を添えてオーナーに 1 アクションで頼み、見張りを終える／`ready` → 扱いは呼び出し側が決める。ゲートの合格後に呼んだとき（pr-review-gate・develop）の扱いは次のとおり: 直しで `agent-review:passed` を外した PR（`agent-review:pending` が付いている）は、先にゲートを取り直し、取り直したゲートに合格するまでマージ待ち・マージ依頼に進まない（failed なら指摘を直して push し、`wait` から続けて `ready` になってから再び取り直す。保留になるか 2 周で合格が確定しなければオーナーに上げる。合格したら同じ見張りの続きとして次のラベルの確認に進む）。そのうえで PR のラベルを見て、`human-merge` / `needs-human-merge` / `human-only` / `needs-approval`（`.github/workflows/auto-merge.yml` がマージを止めるラベル）のどれかが付いていれば、待たずに PR の URL を添えてオーナーにマージを頼み、見張りを終える。どれも付いておらず、自動マージの workflow（`.github/workflows/auto-merge.yml`）が対象リポにあれば `wait --until-merged` を `run_in_background` で起動して見届け、無ければ PR の URL を添えてオーナーにマージを頼む。どの呼び出し側でも、LLM が `gh pr merge` や merge API を叩いてはならない／`none` → `obs.state` が `wait` のときだけ `wait` を起動し直す。それ以外の `none`（前回と同じ状態・同じ HEAD の決着、オーナーに上げ済み）は見張りを終え、PR の URL を添えてオーナーに状況（`obs.state` と、上げ済みならその旨）を伝える
7. **直し方**（flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の修正手順を移したもの）: 担い手は PR の実装者で、ゲートを回した側ではない（develop では W。develop を使わずメインセッションで pr-review-gate を回したときは、メインセッションが実装者のサブエージェント（model は sonnet）を起こして直させる）。① `git fetch origin` し、PR ブランチの worktree で作業する（残っていればそれを使い、無ければ対象リポの clone から切る。harness では開発用の clone から切り、marketplace dir では作業しない）② `conflict` は `git merge origin/main` で解く。版番号だけの競合は main の値に PR の上げ幅を積んだ値にする（main が 1.4.0・PR が 1.3.0 → 1.3.1 なら 1.4.1）。`ci-fail` は `gh run view <run> --log-failed` を読んで直す。実装者がログを読んで PR の差分と関係ない失敗だと判断したら、直さず push もせずに本体へ返し、本体は `next --unrelated <チェック名> --after-fix` を 1 回だけ実行してその一手に従う（同じ HEAD でのやり直しは 1 回までなので、失うのは CI 1 周分で止まる）③ `agent-review:passed` が付いていた PR のとき、push の前に `gh api -X DELETE repos/<owner/repo>/issues/<PR番号>/labels/agent-review:passed` で外し、`gh pr view <PR番号> --json labels` で外れたことを確かめ、PR が Draft でなければ `gh pr ready --undo` で Draft に戻し、`agent-review:pending` を付ける ④ オーナーにマージを頼んだ未解決の依頼があれば、差分が変わったので取り下げると PR にコメントする ⑤ commit して push する ⑥ `agent-review:passed` を外した PR（この直しで外したか、前の直しで外したまま `agent-review:pending` が付いている PR）は、push のあとすぐにはゲートを取り直さない。呼び出し側が `fix` の一手どおり `wait` → `next` を続けて CI のやり直し・再度の直しを済ませ、`ready` になってからゲートを取り直す。合格するまで `agent-review:passed` を付け直さない ⑦ push の前に直せないと判断したときは、push せずに `escalate` と同じ手順でオーナーに上げる
8. **状態ファイル**: 置き場所と、`fix` のあとも消さずに使い続けること（修正回数が PR ごとに累計され、3 回目の失敗で `escalate` になる）。状態ファイルは同じ PC のローカルにあり、1 つの PR を 1 セッションだけが見張る前提（上の 2）で読み書きする

#### Scenario: reference が見張りの手順を持つ
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` を読む
- **THEN** `run_in_background`・`ci-watch.sh wait`・`ci-watch.sh next`・`--unrelated`・`--after-fix`・`gh run rerun`・`--log-failed`・`agent-review:passed`・`gh pr ready --undo`・`--until-merged` の各語が現れる

#### Scenario: サブエージェントに待たせない
- **WHEN** reference の待つ担い手の節を読む
- **THEN** 見張りを始めるのは本体（メインセッション）だけで、サブエージェントは始めないことと、`subagent-waiting.md` への参照が書かれている

#### Scenario: LLM はマージしない
- **WHEN** reference の `ready` の動きを読む
- **THEN** `gh pr merge` や merge API を叩かないことが書かれている

#### Scenario: マージを止めるラベルが付いた ready は待たずに頼む
- **WHEN** reference の `ready` の動きを読む
- **THEN** `human-merge`・`needs-human-merge`・`human-only`・`needs-approval` の 4 つのラベル名と、どれかが付いていれば `--until-merged` で待たずにオーナーへマージを頼むことが書かれ、`--until-merged` で起動した `wait` の `timeout` はマージを頼む扱いと書き分けられている

#### Scenario: none で起動し直すのは wait のときだけ
- **WHEN** reference の `none` の動きを読む
- **THEN** `wait` を起動し直すのは `obs.state` が `wait` のときだけで、それ以外の `none` は見張りを終えて PR の URL を添えてオーナーに伝えることが書かれている

#### Scenario: 1 つの PR を見張るのは 1 セッションだけ
- **WHEN** reference の見張りの開始の節を読む
- **THEN** `CI 見張り開始:` と `CI 見張り終了:` のコメントで見張り中かを判定し、見張り中なら始めないことと、同じセッションが直したあとに始め直すときは開始の判定もコメントもしないことが書かれている

#### Scenario: 再開では中断した一手を確かめる
- **WHEN** reference のオーナーの指示で再開するときの記述を読む
- **THEN** `raised` を消すだけで済ませず中断した一手が済んでいるかを確かめること、同じ HEAD の未実行の `fix` は `next` を呼ばずに実装者への修正依頼から再開すること、`escalate` のあとはオーナーの具体的な指示を先に実行してから見張りに戻ることが書かれている

#### Scenario: 直しの push のあとは ready まで見張ってからゲートを取り直す
- **WHEN** reference の `fix` の動きと `ready` を受けたあとの動きを読む
- **THEN** push のあと `agent-review:passed` を外したまま同じ状態ファイルで `wait` から始め直すこと、ゲートの取り直しは `ready` になってから行うこと、取り直したゲートに合格するまでマージ待ち・マージ依頼に進まないことが書かれている

#### Scenario: ゲート前提の手順は passed が付いていた PR に限る
- **WHEN** reference の直し方を読む
- **THEN** passed を外して Draft に戻す手順は `agent-review:passed` が付いていた PR に、ゲートの取り直しは passed を外した PR に限ると書かれ、`ready` のあとの扱いは呼び出し側が決めると書かれている

### Requirement: --unrelated の判断の守備範囲
reference の `--unrelated` を渡す基準は、次の守備範囲の段落を伴わなければならない（MUST）。

守備範囲: この判断が受け取る入力は、`wait` の観測（`gh pr view` と `annotations` から作ったもの）、落ちた run のログの末尾（`gh run view --log-failed`）、PR の変更ファイルの一覧（`gh pr diff --name-only`）の 3 つに限る。拾いたい誤りは、PR に関わらない一時的な失敗（たまに落ちるテスト・外部サービスの一時的な不調）を直しに回して実装者を空振りさせることと、PR が原因の失敗をやり直して CI 1 周分を待つことの 2 つ。次の入力は誤った一手のまま通ることを許す: PR の変えたファイルを間接的に読み込むテストの失敗を「当たらない」と読み違えてやり直しに回す（同じ HEAD で 1 回だけなので損失は CI 1 周分で止まる）／ログの末尾に原因が出ない失敗は判断できずに直しに回る／1 つのチェックに PR に関わる失敗と関わらない失敗が混ざっていれば直しに回る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 守備範囲が書かれている
- **WHEN** reference の `--unrelated` を渡す基準の節を読む
- **THEN** 入力の出どころ 3 つ・拾いたい誤り 2 つ・誤ったまま通ることを許す入力の例・塞ぎ切ることを完了条件にしない旨が書かれている

### Requirement: ゲート未通過 PR の CI を見張る入口がある

dev-workflow は `/ci-watch <PR> [--merge]` の入口を持ち、対象 PR の URL または番号と、マージ依頼を表す任意の `--merge` 引数を受け取らなければならない（MUST）。番号は現在のリポジトリの PR、URL は URL が示すリポジトリの PR として扱い、対象を解決できなければ見張りを始めてはならない（MUST NOT）。メインセッションは `plugins/dev-workflow/references/ci-watch.md` の開始判定と開始・終了コメント、`scripts/ci-watch.sh wait` / `next`、各 `act` の手順を再利用しなければならない（MUST）。独立した待機・仕分け規則を入口に持ってはならない（MUST NOT）。

`wait` が `ci-fail` を返し `obs.retry=false` なら、入口の呼び出し側は共有 reference のログと PR 差分の 2 条件を確認し、両方を満たすチェック名だけを `ci-watch.sh next --unrelated <チェック名>` に渡さなければならない（MUST）。一時的に落ちるテストもこの経路で扱い、手がかりが足りなければ `--unrelated` を渡さず `fix` に回す（MUST）。やり直しの回数は `pr-state.sh` の同一 HEAD で 1 回という既存の判定に従う（MUST）。`next` が `fix` を返したら、メインセッションは自分で直さず、実装者のサブエージェント（model は sonnet）を起こして共有 reference「7. 直し方」で直させなければならない（MUST）。実装者が PR の差分と関係ない失敗だと返したら、メインセッションは `ci-watch.sh next --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従わなければならない（MUST）。実行の一手と結果は対象 PR にコメントとして記録しなければならない（MUST）。

守備範囲: 入口が受け取る対象はオーナーの依頼に含まれる PR URL または番号、対象 PR と CI の観測は GitHub CLI、関係ない失敗の判断材料は共有 reference が定める落ちた run のログ末尾と PR の変更ファイル一覧に限る。拾いたい誤りは、別 PR を見張ること、ゲート未通過 PR の失敗を放置すること、理由のない CI 失敗を一時的な失敗として再実行することである。ログ末尾に原因が出ない失敗や、変更ファイルを間接的に読むテストの失敗を取り違える入力は、そのまま `fix` または同一 HEAD で 1 回の誤った再実行へ進むことを許す。GitHub の観測遅延やログから因果関係を完全に判定する穴を塞ぎ切ることは、この要件の完了条件にしない。

#### Scenario: URL または番号を受け取る
- **WHEN** オーナーが `/ci-watch <PR URL>` または `/ci-watch <PR番号>` で対象 PR を指定する
- **THEN** 入口は対象 PR を解決し、共有 reference の開始判定と `ci-watch.sh wait` に接続する

#### Scenario: ゲート未通過 PR の CI 失敗から一手へ進む
- **WHEN** ゲート未通過 PR の CI が落ち、`wait` が `ci-fail` を返す
- **THEN** 呼び出し側は共有 reference の基準で `--unrelated` の有無を決めて `next` を呼び、`rerun` または `fix` の一手と結果を PR に記録する

#### Scenario: PR の対象を解決できない
- **WHEN** URL または番号から対象 PR を解決できない
- **THEN** 入口は `ci-watch.sh wait` を開始せず、対象を確認するよう呼び出し元に伝える

#### Scenario: 実装者が関係ない失敗と返す
- **WHEN** `fix` の直しを頼んだ実装者が、ログを読んで PR の差分と関係ない失敗だと返す
- **THEN** メインセッションは push せずに `ci-watch.sh next --unrelated <チェック名> --after-fix` を 1 回だけ実行し、その一手に従う

### Requirement: マージ依頼の無い見張りは `ready` で終える

入口は、マージ依頼の有無を `--merge` 引数の有無だけで決めなければならない（MUST）。依頼文の自由文からマージ依頼を推定してはならない（MUST NOT）。`--merge` が無い見張りで `ready` を受けたら、`pr-review-gate` を実施してはならず、ラベルを付け外ししてはならない（MUST NOT）。1 行目が `CI 見張り終了:` のコメントを PR に投稿し、CI が通ったことを PR の URL を添えてオーナーに伝えて見張りを終えなければならない（MUST）。

守備範囲: 判定の入力は `/ci-watch` の呼び出しに `--merge` が含まれるかどうかだけである。拾いたい誤りは、見張りだけを頼まれた PR でゲートを回し、`agent-review:passed` を付けて auto-merge.yml による承認の無いマージを起こすことである。オーナーが自由文でマージを頼みながら `--merge` を付け忘れた入力は、見張りが `ready` で終わってマージが 1 往復遅れることを許す。PR に既に `agent-review:passed` が付いていて、見張りと無関係に自動マージが進むことを止めることは、この要件の完了条件にしない。

#### Scenario: マージ依頼なしで CI が通る
- **WHEN** オーナーが `--merge` を付けずに `/ci-watch <PR>` で見張りを始め、`next` が `ready` を返す
- **THEN** 入口はゲートを実施せず、ラベルを付け外しせずに `CI 見張り終了:` を PR に投稿し、PR の URL を添えて CI が通ったことをオーナーに伝える

#### Scenario: 自由文のマージ依頼は `--merge` として扱わない
- **WHEN** オーナーの依頼文に「マージして」とあるが、`/ci-watch` の呼び出しに `--merge` が無い
- **THEN** 入口はマージ依頼が無いものとして見張り、`ready` でゲートとマージに進まずに見張りを終える

### Requirement: 条件付きのマージ依頼は既存のゲートと権限の範囲で扱う

オーナー本人が当該 PR について `/ci-watch <PR> --merge` で「CI が通ったらマージして」と直接依頼した場合、その依頼は当該 PR が CI 成功と既存ゲート・リポジトリ運用の条件を満たした後にマージへ進める意思として扱わなければならない（MUST）。入口からの `ready` はゲート合格と同一視せず、`pr-review-gate` の合格が確定するまで、マージ待ち・マージ依頼へ進んではならない（MUST NOT）。合格後の扱いは `references/ci-watch.md` の「`ready` を受けたあと」に従う（MUST）。

この依頼を、ゲート省略、別 PR のマージ、別 HEAD のリスク許容、main への直接 push、rebase・force-push、LLM による `gh pr merge` または merge API の承認として扱ってはならない（MUST NOT）。自動マージが使えないか、マージを止めるラベルがあるときは、PR URL を添えて人間にマージを依頼しなければならない（MUST）。

守備範囲: 承認判断の入力は、オーナー本人が当該 PR を指定して付けた `--merge` と、共有 reference が取得する CI・ラベル・ゲート結果である。拾いたい誤りは、CI green だけでゲートを飛ばすことと、依頼の対象や権限を広げて直接マージすることである。オーナーが曖昧な表現で別の PR を意図していた場合や、GitHub が直後に古い CI 状態を返す場合は、依頼の再確認または共有 reference の観測結果に従うことで進行が遅れることを許す。自然言語の意図や GitHub の状態遅延を完全に解消することは、この要件の完了条件にしない。

#### Scenario: CI は通ったがゲート未通過
- **WHEN** オーナーが `/ci-watch <PR> --merge` で当該 PR のマージを依頼しており、見張った PR が `ready` になり、ゲートの合格記録がまだない
- **THEN** 入口はゲートを実施し、合格が確定するまでマージ待ち・依頼に進まない

#### Scenario: 自動マージできない
- **WHEN** オーナーが `/ci-watch <PR> --merge` で当該 PR のマージを依頼しており、ゲート合格後の PR にマージを止めるラベルがある、または自動マージ workflow がない
- **THEN** 入口は直接 merge API を呼ばず、PR URL を添えて人間にマージを依頼する

### Requirement: 上限時間で打ち切られたジョブは 1 回だけやり直し、やり直しを使い切った HEAD で打ち切りを見たら理由を添えてオーナーに上げる
`ci-watch.sh wait` と `ci-watch.sh next` は、落ちたジョブの annotation に `maximum execution time` が含まれ、同じジョブに通信切れの annotation が無いとき、`pr-state.sh` の判定をそのまま通して、観測の `checks[].cause` に `job-timeout` を出さなければならない（MUST）。`next` は、`real` が混ざらず `job-timeout` を 1 件以上含む `ci-fail` を見たとき、その HEAD でまだやり直していなければ `rerun` を、やり直しを使い切っていれば `escalate` を返し、状態ファイルに `raised: true` を書き、`fixes` を増やしてはならない（MUST NOT）。`ci-watch.sh` はこの判定のための独自の分岐を持たず、判定は `pr-state.sh` に置く（MUST）。

一手を「1 回もやり直さずに上げる」ではなく「1 回はやり直す」にしたのは、通信切れ（`runner-lost`）と同じく、`real` でない原因は同じ HEAD で 1 回だけやり直すという既存の規則に揃えるためである。打ち切りにはランナーが一時的に遅かっただけのものが含まれ、失うのは CI 1 周分で止まる。やり直しを使い切ったあとの打ち切りを `fix` にしないのは、ランナーの状態は PR の実装者には直せず、直しに回すと実装者が PR の差分を調べ直す空振りになるためである。

`plugins/dev-workflow/references/ci-watch.md` は次を書かなければならない（MUST）。

1. `next` の一手ごとの動きの `escalate` に、`obs.checks` に `cause` が `job-timeout` のチェックがあるときは、落ちたチェック名と PR の URL に加えて、ジョブが上限時間で打ち切られたことと、ランナーの状態を確かめてほしいことをオーナーに伝えること。このとき実装者に直しを頼まないこと
2. `--unrelated` を渡す基準に、`cause` が `job-timeout` のチェックはログを読む判断の対象でないこと（`real` でないので、渡さなくても 1 回やり直される）
3. `job-timeout`（CI のジョブが自分の上限時間で打ち切られた）と、`wait` の `result` の `timeout`（見張りが上限時間内に決着を見られなかった）は別の出来事であること

`ci-watch.sh wait` の上限時間の既定値（`DEV_WORKFLOW_CI_WATCH_TIMEOUT`、既定 3600 秒）は、この要件では変えない（MUST NOT）。

守備範囲: この扱いが受け取る入力は、`gh pr view` の JSON と `annotations` の出力（GitHub のジョブの annotation）に限る。拾いたい誤りは、上限時間での打ち切りを PR が原因の失敗として実装者の直しに回すことと、やり直しを使い切った HEAD で打ち切りを見たのにやり直しを繰り返して CI を何周も待つことの 2 つ（genetta-inc/flatmate#1563）。次の入力は誤った一手のまま通ることを許す: PR 自身がテストを遅くして上限時間に達したときも、1 回やり直したあと実装者ではなくオーナーに届く（オーナーがランナーに問題が無いと確かめたら、reference の「`escalate` のあとに続けるよう言われたとき」の手順で実装者に直させる）／ランナーが壊れたままのときも 1 回はやり直すので、CI 1 周分を待ってからオーナーに届く／CI がランナーの空きを長く待ったために `wait` の上限時間のほうが先に来たときは、`job-timeout` を見る前に `timeout` でオーナーに届く／判定は前回の原因を見ない（状態ファイルに `cause` を持たない）ので、1 回目が `unrelated` や `runner-lost` でやり直しになり、同じ HEAD の 2 回目が初めての `job-timeout` のときも、`job-timeout` と `runner-lost` が混ざった失敗のときも、やり直さずに `escalate` になる／GitHub が annotation の文言を変えたとき・annotation の取得に失敗したときは `real` になり直しに回る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 打ち切りの annotation は決着した観測に入る
- **WHEN** PATH 先頭の `gh` の偽物が、失敗したチェック（`conclusion: CANCELLED`、`/actions/runs/11/job/77`）を返し、ジョブ 77 の annotation が `The job running on runner mac-1 has exceeded the maximum execution time of 40 minutes.` を含む状態で `wait o/r 5` を実行する
- **THEN** `.result` が `settled`、`.obs.checks[0].cause` が `job-timeout`、`.obs.retry` が `true`

#### Scenario: 1 回目の打ち切りはやり直す
- **WHEN** 状態ファイルが無く、偽物が HEAD `h1` の上と同じ打ち切られたチェックを返し、`next o/r 5` を実行する
- **THEN** `.act` が `rerun`、状態ファイルの `.reran_head` が `h1` で、`.fixes` は書かれない

#### Scenario: やり直しを使い切った HEAD の打ち切りはオーナーに上げる
- **WHEN** 状態ファイルが `{"state":"wait","head":"h1","reran_head":"h1"}` で、偽物が HEAD `h1` の上と同じ打ち切られたチェックを返し、`next o/r 5` を実行する
- **THEN** `.act` が `escalate`、`.obs.checks[0].cause` が `job-timeout`、状態ファイルの `.raised` が `true` で、`.fixes` は書かれない

#### Scenario: 上限時間の annotation が無い取り消しは直しに回る
- **WHEN** 状態ファイルが無く、偽物が `conclusion: CANCELLED` のチェック（ジョブ 77）を返し、ジョブ 77 の annotation が `The operation was canceled.` だけのとき `next o/r 5` を実行する
- **THEN** `.act` が `fix`、`.obs.checks[0].cause` が `real`

#### Scenario: reference が打ち切りの伝え方を持つ
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` の `escalate` の動きを読む
- **THEN** `job-timeout` の語と、ジョブが上限時間で打ち切られたこと・ランナーの状態を確かめてほしいことをオーナーに伝えること・実装者に直しを頼まないことが書かれている

#### Scenario: reference が見張りの timeout と書き分ける
- **WHEN** reference の `--unrelated` を渡す基準と `job-timeout` の説明を読む
- **THEN** `job-timeout` のチェックは `--unrelated` の判断の対象でないことと、`job-timeout` が `wait` の `timeout` とは別の出来事であることが書かれている

### Requirement: エピックの子は聖域接触だけの human-merge で親の判断を待つ
`plugins/dev-workflow/references/ci-watch.md` の「`ready` を受けたあと」の見送りラベルの分岐は、エピックの子のセッション（`epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッション）について次を書かなければならない（MUST）。この要件は、要件「CI の見張りの手順は共有 reference に 1 本置く」の、見送りラベルのどれかが付いていれば `--until-merged` で待たずにオーナーへマージを頼む規定に、次の 3 つをすべて満たすときに限って優先する: エピックの子のセッションである／付いている見送りラベルが `human-merge` だけ／対象リポの PR の base ブランチの `.github/workflows/auto-merge.yml`（`gh api "repos/<owner>/<repo>/contents/.github/workflows/auto-merge.yml?ref=<PR の base ブランチ>" --jq .content | base64 -d`） に `parent-merge-approved` の語がある。どれかを満たさなければ従来どおりオーナーにマージを頼む。

- オーナーに直接頼む代わりに、develop の SKILL.md「エピックの子が主の返事を待って止まるとき」の記録を `止まった理由: PR のマージ待ち（human-merge）: <PR の URL>` で残し、その手順どおり印（`mark stopped`）を付けて止まる（MUST）。記録の形と印の手順は SKILL.md の側の規定のまま。残りの 6 項目（主に聞く理由・前提・推奨・推奨の根拠・受け入れるリスク・再開に要る途中経過）に何を書くかの例を添える（MUST）。`主に聞く理由:` の例は「決まりで主の承認が要る」で始め、その決まりが何を守るためか（聖域のファイルに触れた PR は人の判断を通してからマージする）まで書く
- 親から返事（`親エピック #<E> の判断（主の承認ではない）:` で始まる入力）が届いたら、新しい見張りとして `ci-watch.md` の 2 の重複の確認と `CI 見張り開始:` のコメントの投稿をしてから、`ci-watch.sh wait <owner/repo> <PR番号> --until-merged` を `run_in_background` で起動して見届ける（MUST。止まるときに `CI 見張り終了:` を投稿しているので、開始の記録なしに始めると、別のセッションが同じ PR の見張りを重ねて始められてしまう）。結果の扱いは既存の 4 の表のまま。`--until-merged` の `timeout` で改めて止まるときは、`止まった理由:` を `PR のマージ待ち（human-merge、親の返事のあともマージされない）: <PR の URL>` とする（MUST）
- 子は `parent-merge-approved` ラベルも `親のマージ判断:` のコメントも付けてはならない（MUST NOT）。親の返事を聖域の変更や破壊的な操作の承認として扱わず、その返事で聖域のファイルを変えたりマージしたりしない（MUST NOT）。`gh pr merge` や merge API を叩かない規定は変えない

この要件の守備範囲で入力として扱うのは、PR のラベル、PR の base ブランチの `auto-merge.yml`、`epic-dispatch.sh route` の出力、子のセッションに届いた入力の頭の文字列である。拾いたい誤りは、エピックの子が `human-merge` だけの PR で主に直接頼んで親の判断を通らないこと、子が自分で印を付けること、親の返事を承認として扱って子が何かを変えることの 3 つである。次は通ってよく、この要件では止めない: 親の判断を待つ間に主が子のタブで直接マージを押すこと（子は `closed`／`merged` で見届けを終える）／親が誤って印を付けずに返事だけを送ったとき、`--until-merged` の上限時間まで待つこと。すり抜ける形が見つかるたびに塞ぎ切ることは、この要件の完了条件としない。

#### Scenario: 見送りラベルの分岐にエピックの子の扱いが書かれている
- **WHEN** `ci-watch.md` の「`ready` を受けたあと」の 1 を読む
- **THEN** エピックの子のセッションで見送りラベルが `human-merge` だけ、かつ PR の base ブランチの `auto-merge.yml` に `parent-merge-approved` があるとき（確かめるコマンドを添える）、子の停止の記録を `PR のマージ待ち（human-merge）` で残し、残りの 6 項目（`主に聞く理由:` を含む）の例に沿って書いて止まること、親の返事が届いたら 2 の重複の確認と `CI 見張り開始:` の投稿をしてから `--until-merged` で見届けること、子は印を付けず親の返事を承認として扱わないことが書かれ、それ以外は従来どおりオーナーにマージを頼むことが書かれている

### Requirement: エピックの子はオーナーにマージを頼むとき、マージ後の連絡を頼まない

`plugins/dev-workflow/references/ci-watch.md` は、エピックの子のセッション（`epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッション）がオーナーにマージを頼んで見張りを終えるすべての箇所（「`ready` を受けたあと」の 1 の見送りラベルの分岐で親の判断を待たずにオーナーに頼むとき・3 の自動マージの workflow が無いとき・4 の表の `--until-merged` で起動した `wait` の `timeout`）について、次を 1 か所にまとめて書かなければならない（MUST）。

- 頼む文面に「マージしたら教えてください」のような、マージ後にオーナーが子のタブへ戻って知らせる依頼を書いてはならない（MUST NOT）
- 代わりに「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書く（MUST）。理由として、親の `epic-dispatch.sh wait --watch-done` が、記録先が completed で閉じて子のセッションが止まった子を完了と推定することを添える（SHALL）

エピックの子でないセッションがオーナーにマージを頼む文面は変えない。

#### Scenario: ci-watch.md にエピックの子のマージ依頼の文面の規定がある
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` の「`ready` を受けたあと」を読む
- **THEN** エピックの子のセッションがオーナーにマージを頼んで見張りを終えるとき（1・3・`--until-merged` の `timeout`）に、マージ後の連絡を頼まず「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書くことと、親の `wait --watch-done` が完了を推定するという理由が書かれている

