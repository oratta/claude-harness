## ADDED Requirements

### Requirement: wait は PR の CI が決着するまで黙って待ち、決着したら 1 行の JSON を出す
`plugins/dev-workflow/scripts/ci-watch.sh wait <owner/repo> <PR番号> [--until-merged]` は、最初に 1 間隔待ってから、`gh pr view <PR番号> --repo <owner/repo> --json state,mergeable,statusCheckRollup,headRefOid` を間隔を空けて繰り返し、次のどれかに当たった時点で 1 行の JSON を標準出力に出して exit 0 で終わらなければならない（MUST）。当たるまでは標準出力に何も出してはならない（MUST NOT）。

1. PR の `state` が `MERGED`: `{"result":"merged","obs":null}`
2. PR の `state` が `CLOSED`: `{"result":"closed","obs":null}`
3. `--until-merged` が無く、同じ JSON を `pr-state.sh annotations <owner/repo>` の出力を `--hints` にして `pr-state.sh observe` に通した結果の `state` が `wait` 以外: `{"result":"settled","obs":<observe の出力>}`
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
`ci-watch.sh next <owner/repo> <PR番号> [--unrelated <チェック名>]...` は、`gh pr view <PR番号> --repo <owner/repo> --json mergeable,statusCheckRollup,headRefOid` の JSON を `pr-state.sh annotations <owner/repo>` に通して手がかりを作り、同じ JSON を `pr-state.sh observe --hints <手がかり> [--unrelated <チェック名>]...` に、その出力を `pr-state.sh decide <前回の状態>` に通し、`decide` の出力をそのまま 1 行で標準出力に出さなければならない（MUST）。`--unrelated` は受け取った順にすべて `observe` に渡す（MUST）。

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

#### Scenario: gh が失敗したら状態を書き換えない
- **WHEN** 状態ファイルが `{"fixes":1}` で、偽物の `gh pr view` が非 0 で終わる
- **THEN** `next` は非 0 で終わり、状態ファイルの中身は `{"fixes":1}` のまま

#### Scenario: 一手を実行しない
- **WHEN** `.act` が `rerun` になる入力で `next` を実行する
- **THEN** 偽物の `gh` に `run rerun` の呼び出しが無い

### Requirement: CI の見張りの手順は共有 reference に 1 本置く
`plugins/dev-workflow/references/ci-watch.md` は、合格後（と #523 の入口から呼ばれたとき）の CI の見張りの手順の正本として、次を書かなければならない（MUST）。pr-review-gate と develop の SKILL.md はこの手順を言い換えて再掲せず、この reference を参照する（MUST）。

1. **待つのは本体（メインセッション）だけ**: サブエージェントは見張りを始めない。理由として `references/subagent-waiting.md` の「背景タスクの完了では起こされない」を参照する
2. **待ち方**: `ci-watch.sh wait` を Bash ツールの `run_in_background` で起動し、完了通知で起こされてから出力を 1 回読む。前景のループで待たない・途中で出力を覗かない。最初に見張りを始めたとき、何を待っているか（PR の CI の決着を本体が待っていること）を PR に 1 行コメントする
3. **`wait` の結果ごとの動き**: `settled` → 下の 4 で `--unrelated` を決めてから `next` を実行する／`merged` → 見張りを終えてマージを報告する／`closed` → 見張りを終える／`timeout` → PR の URL を添えて、CI が上限時間内に決着しなかったことをオーナーに 1 アクションで伝える／`error` → `gh` の認証・ネットワークを確かめて 1 回だけ起動し直し、もう一度 `error` ならオーナーに伝える
4. **`--unrelated` を渡す基準**: `wait` の `obs.state` が `ci-fail` で `obs.retry` が `false` のとき、`cause` が `real` のチェックごとに、`gh run view <run> --log-failed` の末尾（範囲を切って読む）と `gh pr diff --name-only` を見て、「落ちたテスト・手順が PR の変えたファイルとそれを直接読み込むテストに当たらない」と「失敗の内容が PR の差分と因果を持たない（タイムアウト・ネットワーク・外部サービス・実行マシンの資源不足など）」の両方を満たすものだけを渡す。どちらかが判断できなければ渡さない
5. **`next` の一手ごとの動き**: `rerun` → `obs.runs` の各 run に `gh run rerun <run> --failed` を実行してから `wait` を起動し直す（やり直しに失敗したら、その旨を PR にコメントして `wait` を起動し直す。次の観測で `decide` が直しに回す）／`fix` → 下の 6 の直し方で直し、ゲートを取り直して合格したら `wait` から始め直す／`escalate` → `needs-approval` を付け、落ちたチェック名と PR の URL を添えてオーナーに 1 アクションで頼み、見張りを終える／`ready` → 自動マージの workflow（`.github/workflows/auto-merge.yml`）が対象リポにあれば `wait --until-merged` を `run_in_background` で起動して見届け、無ければ PR の URL を添えてオーナーにマージを頼む。LLM が `gh pr merge` や merge API を叩いてはならない／`none` → 状態の `raised` が `true` なら見張りを終え、そうでなければ `wait` を起動し直す
6. **直し方**（flatmate の `docs/project-modes.md`「止まった人間マージ待ち PR の見張り」の修正手順を移したもの）: 担い手は PR の実装者で、ゲートを回した側ではない。① `git fetch origin` し、PR ブランチの worktree で作業する（残っていればそれを使い、無ければ対象リポの clone から切る。harness では `CLAUDE_HARNESS_DEV_DIR` の開発用 clone から切り、marketplace dir では作業しない）② `conflict` は `git merge origin/main` で解く。版番号だけの競合は main の値に PR の上げ幅を積んだ値にする（main が 1.4.0・PR が 1.3.0 → 1.3.1 なら 1.4.1）。`ci-fail` は `gh run view <run> --log-failed` を読んで直す ③ push の前に `agent-review:passed` を `gh api -X DELETE repos/<owner/repo>/issues/<PR番号>/labels/agent-review:passed` で外し、PR が Draft でなければ `gh pr ready --undo` で Draft に戻し、`agent-review:pending` を付ける ④ オーナーにマージを頼んだ未解決の依頼があれば、差分が変わったので取り下げると PR にコメントする ⑤ commit して push する ⑥ ゲートを取り直す。合格するまで `agent-review:passed` を付け直さない ⑦ 直せなかったとき（ゲートに合格しない場合を含む）は push せずに `escalate` と同じ手順でオーナーに上げる
7. **状態ファイル**: 置き場所と、`fix` のあとも消さずに使い続けること（修正回数が PR ごとに累計され、3 回目の失敗で `escalate` になる）

#### Scenario: reference が見張りの手順を持つ
- **WHEN** `plugins/dev-workflow/references/ci-watch.md` を読む
- **THEN** `run_in_background`・`ci-watch.sh wait`・`ci-watch.sh next`・`--unrelated`・`gh run rerun`・`--log-failed`・`agent-review:passed`・`gh pr ready --undo`・`--until-merged`・`CLAUDE_HARNESS_DEV_DIR` の各語が現れる

#### Scenario: サブエージェントに待たせない
- **WHEN** reference の待つ担い手の節を読む
- **THEN** 見張りを始めるのは本体（メインセッション）だけで、サブエージェントは始めないことと、`subagent-waiting.md` への参照が書かれている

#### Scenario: LLM はマージしない
- **WHEN** reference の `ready` の動きを読む
- **THEN** `gh pr merge` や merge API を叩かないことが書かれている

### Requirement: --unrelated の判断の守備範囲
reference の `--unrelated` を渡す基準は、次の守備範囲の段落を伴わなければならない（MUST）。

守備範囲: この判断が受け取る入力は、`wait` の観測（`gh pr view` と `annotations` から作ったもの）、落ちた run のログの末尾（`gh run view --log-failed`）、PR の変更ファイルの一覧（`gh pr diff --name-only`）の 3 つに限る。拾いたい誤りは、PR に関わらない一時的な失敗（たまに落ちるテスト・外部サービスの一時的な不調）を直しに回して実装者を空振りさせることと、PR が原因の失敗をやり直して CI 1 周分を待つことの 2 つ。次の入力は誤った一手のまま通ることを許す: PR の変えたファイルを間接的に読み込むテストの失敗を「当たらない」と読み違えてやり直しに回す（同じ HEAD で 1 回だけなので損失は CI 1 周分で止まる）／ログの末尾に原因が出ない失敗は判断できずに直しに回る／1 つのチェックに PR に関わる失敗と関わらない失敗が混ざっていれば直しに回る。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 守備範囲が書かれている
- **WHEN** reference の `--unrelated` を渡す基準の節を読む
- **THEN** 入力の出どころ 3 つ・拾いたい誤り 2 つ・誤ったまま通ることを許す入力の例・塞ぎ切ることを完了条件にしない旨が書かれている
