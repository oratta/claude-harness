# dev-workflow-pr-state Specification

## Purpose
`plugins/dev-workflow/scripts/pr-state.sh` が、`gh pr view` の JSON から PR の状態（conflict / ci-fail / ready / wait）を分類し、前回の状態から次の一手（none / ready / rerun / fix / escalate）を決める規約。落ちたチェックをやり直しに当たるか（実行マシンの通信切れ・PR に関わらない失敗）で仕分けること、やり直しは HEAD ごとに 1 回・修正は PR ごとに 2 回までとすること、状態の保存と一手の実行は呼び出し側が持つことを含む。
## Requirements
### Requirement: observe は gh pr view の JSON を PR の状態に分類する
`plugins/dev-workflow/scripts/pr-state.sh observe` は、標準入力の `gh pr view --json mergeable,statusCheckRollup,headRefOid` の JSON を読み、1 行の JSON `{head, state, failed, runs, checks, retry}` を標準出力に出さなければならない（MUST）。`gh` を呼んではならない（MUST NOT）。

チェック 1 件の結論は、`conclusion` が空でなければそれを、空なら `state`、それも無ければ `status` を大文字にして決める。`SUCCESS` / `NEUTRAL` / `SKIPPED` は成功、`PENDING` / `EXPECTED` / `QUEUED` / `IN_PROGRESS` / `WAITING` / `REQUESTED` と空は未確定、それ以外（知らない値を含む）は失敗とする（MUST）。

`state` は、`mergeable` が `CONFLICTING` なら `conflict`、失敗したチェックが 1 件以上あれば `ci-fail`、`mergeable` が `MERGEABLE` で全チェックが成功なら `ready`、それ以外（`UNKNOWN`・未確定のチェックがある等）は `wait` とする（MUST）。`head` は `headRefOid`（無ければ空文字）。`failed` は失敗したチェックの名前（`name`、無ければ `context`、どちらも無ければ `?`。タブ・改行・カンマは空白に置き換える）の重複なし一覧、`runs` は失敗したチェックの `detailsUrl`（無ければ `targetUrl`）の `/actions/runs/<数字>` から取った run ID の重複なし一覧とする（MUST）。標準入力が JSON のオブジェクトとして読めないときは、標準出力に何も出さずに非 0 で終わらなければならない（MUST）。

#### Scenario: コンフリクトはチェックより先に conflict
- **WHEN** `mergeable` が `CONFLICTING` で、失敗したチェックもある入力を渡す
- **THEN** `state` は `conflict`

#### Scenario: 実行中・URL の無い未確定のチェックがあれば wait
- **WHEN** `status: IN_PROGRESS` のチェック、または `state: PENDING` の外部チェックと成功したチェックが並ぶ `MERGEABLE` の入力を渡す
- **THEN** `state` は `wait`

#### Scenario: 成功・中立だけならマージ可能
- **WHEN** `conclusion` が `SUCCESS` と `NEUTRAL` のチェックだけの `MERGEABLE` の入力を渡す
- **THEN** `state` は `ready`

#### Scenario: 失敗は落ちたチェック名と run ID を返す
- **WHEN** `name: test`・`conclusion: FAILURE`・`detailsUrl` が `https://github.com/o/r/actions/runs/555/job/9` のチェックを含む入力を渡す
- **THEN** `state` は `ci-fail`、`failed` は `["test"]`、`runs` は `["555"]`

#### Scenario: Actions 以外の失敗は run ID を持たない
- **WHEN** `context: ext/ci`・`state: FAILURE`・`targetUrl` が Actions 以外の URL のチェックだけが落ちた入力を渡す
- **THEN** `state` は `ci-fail`、`runs` は空

#### Scenario: 知らない結論は失敗
- **WHEN** `conclusion` が `STARTUP_FAILURE` や未知の値のチェックを含む入力を渡す
- **THEN** そのチェックは失敗として `failed` に入る

#### Scenario: 読めない入力は非 0
- **WHEN** JSON でない文字列を標準入力に渡す
- **THEN** 標準出力は空で、終了コードは 0 以外

### Requirement: observe は落ちたチェックごとにやり直しに当たるかを仕分ける
`observe` は失敗したチェックごとに `checks` の要素 `{name, run, job, cause}` を出さなければならない（MUST）。`job` は `detailsUrl` の `/job/<数字>` から取った ID（無ければ `null`）。`cause` は次の順で最初に当たったものとする（MUST）:

1. `runner-lost`: そのチェックの `job` があり、`--hints <file>` の JSON の `annotations_by_job.<job>`（文字列の配列）のいずれかが `The self-hosted runner lost communication with the server` を含む。鍵はジョブ ID で、チェック名では引かない（別ワークフローの同名ジョブの通信切れを、もう片方の本当の失敗に移さないため）
2. `unrelated`: `--unrelated <チェック名>` で渡された名前（複数回指定できる）に一致する
3. `real`: それ以外

`retry` は、`state` が `ci-fail` で、失敗したチェックが 1 件以上あり、そのすべての `cause` が `real` でなく、すべてに run ID があるときだけ `true`、それ以外は `false` としなければならない（MUST）。`--hints` も `--unrelated` も無ければ、すべての失敗は `real` になる（MUST）。`--hints` のファイルが読めない・JSON でないときは非 0 で終わる（MUST）。

守備範囲: この仕分けが受け取る入力は、`gh pr view` の JSON（GitHub が返す PR の状態）、`annotations` の出力（GitHub のジョブの annotation）、呼び出し側が渡す `--unrelated` のチェック名の 3 つに限る。拾いたい誤りは、本当の失敗をやり直して CI 1 周分待つこと、やり直せば通る失敗（実行マシンの通信切れ・PR に関わらない失敗）を直しに回すこと、状態が読めない回（`UNKNOWN`）を挟むと修正回数が増えること（flatmate#899）の 3 つ。次の入力は誤った一手のまま通ることを許す: GitHub が通信切れの文言を変えたときは `real` になり直しに回る／PR に関わる失敗を呼び出し側が `--unrelated` で渡すと、やり直しで CI 1 周分を失う（同じ HEAD では 1 回だけなので損失はそこで止まる）／Actions 以外の失敗は手がかりがあってもやり直さない／`annotations` が取れなかったジョブは `real` になり直しに回る／ジョブ ID を持たない失敗（`detailsUrl` に `/job/<数字>` が無い）は通信切れと判定できない。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 通信切れの annotation はやり直しに当たる
- **WHEN** 落ちたチェック `build`（job 77）が 1 件で run ID があり、`--hints` の `annotations_by_job."77"` に `The self-hosted runner lost communication with the server.` を含む文字列を渡す
- **THEN** `build` の `cause` は `runner-lost`、`retry` は `true`

#### Scenario: 変更に関わらないと渡した失敗はやり直しに当たる
- **WHEN** 落ちたチェック `e2e` が 1 件で run ID があり、`--unrelated e2e` を渡す
- **THEN** `e2e` の `cause` は `unrelated`、`retry` は `true`

#### Scenario: 本当の失敗が 1 件でも混ざれば直しに回す
- **WHEN** 落ちたチェックが `build`（通信切れの annotation あり）と `lint`（手がかりなし）の 2 件
- **THEN** `lint` の `cause` は `real`、`retry` は `false`

#### Scenario: 同名チェックの通信切れを別のジョブに移さない
- **WHEN** 別のワークフローの同名チェック `test` が job 77 と job 88 で落ち、`--hints` の `annotations_by_job` には job 77 の通信切れだけがある
- **THEN** job 77 の `cause` は `runner-lost`、job 88 の `cause` は `real`、`retry` は `false`

#### Scenario: 手がかりが無ければやり直さない
- **WHEN** run ID のある失敗を `--hints` も `--unrelated` も無しで渡す
- **THEN** すべての `cause` が `real`、`retry` は `false`

#### Scenario: run ID が無ければやり直さない
- **WHEN** Actions 以外の落ちたチェックを `--unrelated` で渡す
- **THEN** `cause` は `unrelated` だが `retry` は `false`

### Requirement: decide は観測と前回の状態から次の一手と次の状態を決める
`pr-state.sh decide [<前回の状態の JSON>]` は、標準入力の `observe` の出力と引数の前回の状態から、1 行の JSON `{act, next, obs}` を標準出力に出さなければならない（MUST）。`gh` を呼んではならない（MUST NOT）。前回の状態が省略・`null`・`{}` のときは初見として扱う（MUST）。状態は `{state, head, reran_head, fixes, raised}` を持ち、`next` は前回の状態の知らないキーを消さずに引き継がなければならない（MUST）。`obs` は標準入力の観測をそのまま返す。

`act` と `next` は次の順で最初に当たったもので決める（MUST）。以下「見た状態」は前回の状態に `{state: <観測の state>, head: <観測の head>}` を重ねたもの。

1. 観測が `wait`: `act` は `none`。`next` は、前回の `head` が観測の `head` と同じなら前回の状態そのまま、違えば見た状態
2. 観測が `ready`: `act` は `ready`、`next` は見た状態
3. 前回の `state` と `head` が観測と同じ: `act` は `none`、`next` は見た状態
4. 前回の `raised` が `true`: `act` は `none`、`next` は見た状態
5. 観測が `ci-fail` で `retry` が `true` で、前回の `reran_head` が観測の `head` と違う: `act` は `rerun`、`next` は見た状態に `{state: "wait", reran_head: <観測の head>}` を重ねたもの
6. 前回の `fixes`（無ければ 0）が 2 以上: `act` は `escalate`、`next` は見た状態に `{raised: true}` を重ねたもの
7. それ以外: `act` は `fix`、`next` は見た状態に `{fixes: <前回の fixes + 1>}` を重ねたもの

前回の状態の引数や標準入力が JSON として読めないときは、非 0 で終わらなければならない（MUST）。

#### Scenario: 同じ HEAD で 2 回落ちてもやり直しは 1 回
- **WHEN** HEAD `e1` で `retry: true` の `ci-fail` を初見で渡し、その `next` を前回の状態にして同じ観測をもう一度渡す
- **THEN** 1 回目は `rerun`（`next.state` は `wait`、`next.reran_head` は `e1`）、2 回目は `fix`（`next.fixes` は 1）

#### Scenario: HEAD が変わればやり直しの権利が戻る
- **WHEN** `reran_head: e1`・`fixes: 1` の状態に、HEAD `e2` で `retry: true` の `ci-fail` を渡す
- **THEN** `act` は `rerun`、`next.fixes` は 1 のまま（HEAD が変わっても修正回数は数え直さない）

#### Scenario: CI 失敗を直すのは 2 回まで、3 回目はオーナーに上げる
- **WHEN** HEAD `d1` → `d2` → `d3` と変わりながら `retry: false` の `ci-fail` を 1 回ずつ渡し、毎回前の `next` を前回の状態にする
- **THEN** `fix`（`fixes` 1）→ `fix`（`fixes` 2）→ `escalate`（`raised: true`）の順になる

#### Scenario: 直すのは 2 回まで、3 回目はオーナーに上げる
- **WHEN** HEAD `d1` → `d2` → `d3` と変わりながら `conflict` を 1 回ずつ渡し、毎回前の `next` を前回の状態にする
- **THEN** `fix`（`fixes` 1）→ `fix`（`fixes` 2）→ `escalate`（`raised: true`）の順になり、そのあと HEAD `d4` の `conflict` は `none`

#### Scenario: 同じ状態・同じ HEAD の再観測は何もしない
- **WHEN** `conflict` で `fix` になった `next` を前回の状態にして、同じ HEAD の `conflict` を渡す
- **THEN** `act` は `none`、`fixes` は 1 のまま

#### Scenario: UNKNOWN を挟んでも修正回数が戻らない（flatmate#899）
- **WHEN** 同じ HEAD で `conflict` → `wait` → `conflict` → `wait` → `conflict` の観測を、毎回前の `next` を前回の状態にして渡す
- **THEN** 一手は `fix` → `none` → `none` → `none` → `none` で、最後の `next.fixes` は 1

#### Scenario: HEAD が変わったあとの wait は状態名を wait にする
- **WHEN** `state: conflict`・`head: h1`・`fixes: 1` の状態に、HEAD `h2` の `wait` を渡し、その `next` に HEAD `h2` の `conflict` を渡す
- **THEN** 1 回目の `next` は `state: wait`・`head: h2`、2 回目は `fix`（`fixes` 2）

#### Scenario: 状態名と HEAD を消した状態は再依頼の条件になる
- **WHEN** `fixes: 1` だけを持つ（`state` と `head` の無い）状態に、HEAD `j1` の `conflict` を渡す
- **THEN** `act` は `fix`、`fixes` は 2

#### Scenario: 知らないキーを引き継ぐ
- **WHEN** `last_done: "failed"` を含む前回の状態を渡す
- **THEN** `next.last_done` は `"failed"`

#### Scenario: マージ可能は毎回 ready
- **WHEN** `ready` の観測を渡す
- **THEN** `act` は `ready`

### Requirement: annotations は落ちた Actions のジョブの annotation を observe の手がかりの形で返す
`pr-state.sh annotations <owner/repo>` は、標準入力の `gh pr view --json mergeable,statusCheckRollup,headRefOid` の JSON から、失敗したチェックのうち `detailsUrl` に `/actions/runs/<数字>/job/<数字>` を持つものについて `gh api repos/<owner/repo>/check-runs/<job>/annotations` を呼び、`{"annotations_by_job": {"<job>": [<message>, ...]}}` を 1 行の JSON で標準出力に出さなければならない（MUST）。鍵は `observe` の `checks[].job` と同じジョブ ID の文字列とする（MUST）。呼び出しには `gh` の認証と、対象リポジトリの checks を読む権限が要る。1 件の `gh api` が失敗したら、そのジョブを結果に含めず標準エラーに警告を出して残りを続け、exit 0 で終わらなければならない（MUST）。失敗したチェックが無ければ `gh` を呼ばずに `{"annotations_by_job":{}}` を出す（MUST）。

#### Scenario: 落ちたジョブの annotation を取る
- **WHEN** `build`（job 77 で失敗）と `lint`（成功）を含む入力を渡し、`gh api .../check-runs/77/annotations` が通信切れの message を返す
- **THEN** 出力の `annotations_by_job."77"` にその message が入り、`gh api` の呼び出しは job 77 の 1 回だけ

#### Scenario: 取得に失敗しても止まらない
- **WHEN** 落ちたジョブが 2 件あり、片方の `gh api` が非 0 で終わる
- **THEN** もう片方の annotation を出し、標準エラーに警告があり、終了コードは 0

#### Scenario: 落ちたチェックが無ければ gh を呼ばない
- **WHEN** 全チェックが成功の入力を渡す
- **THEN** 出力は `{"annotations_by_job":{}}` で、`gh` は呼ばれない

#### Scenario: annotations の出力をそのまま observe の手がかりに使える
- **WHEN** `annotations` の出力をファイルに書き、同じ入力を `observe --hints <そのファイル>` に渡す
- **THEN** 通信切れの message を持つチェックの `cause` は `runner-lost`

