## MODIFIED Requirements

### Requirement: observe は落ちたチェックごとにやり直しに当たるかを仕分ける
`observe` は失敗したチェックごとに `checks` の要素 `{name, run, job, cause}` を出さなければならない（MUST）。`job` は `detailsUrl` の `/job/<数字>` から取った ID（無ければ `null`）。`cause` は次の順で最初に当たったものとする（MUST）:

1. `runner-lost`: そのチェックの `job` があり、`--hints <file>` の JSON の `annotations_by_job.<job>`（文字列の配列）のいずれかが `The self-hosted runner lost communication with the server` を含む。鍵はジョブ ID で、チェック名では引かない（別ワークフローの同名ジョブの通信切れを、もう片方の本当の失敗に移さないため）
2. `job-timeout`: そのチェックの `job` があり、`--hints <file>` の JSON の `annotations_by_job.<job>` のいずれかが `maximum execution time` を含む（ジョブが上限時間で打ち切られたときに GitHub が付ける annotation。ランナー名と分数が入るので、変わらない部分だけを部分一致で見る）。鍵は `runner-lost` と同じくジョブ ID。`--unrelated` で同じチェック名が渡されていても `job-timeout` とする
3. `unrelated`: `--unrelated <チェック名>` で渡された名前（複数回指定できる）に一致する
4. `real`: それ以外

`retry` は、`state` が `ci-fail` で、失敗したチェックが 1 件以上あり、そのすべての `cause` が `real` でなく、すべてに run ID があるときだけ `true`、それ以外は `false` としなければならない（MUST）。`--hints` も `--unrelated` も無ければ、すべての失敗は `real` になる（MUST）。`--hints` のファイルが読めない・JSON でないときは非 0 で終わる（MUST）。

守備範囲: この仕分けが受け取る入力は、`gh pr view` の JSON（GitHub が返す PR の状態）、`annotations` の出力（GitHub のジョブの annotation）、呼び出し側が渡す `--unrelated` のチェック名の 3 つに限る。拾いたい誤りは、本当の失敗をやり直して CI 1 周分待つこと、やり直せば通る失敗（実行マシンの通信切れ・PR に関わらない失敗）を直しに回すこと、状態が読めない回（`UNKNOWN`）を挟むと修正回数が増えること（flatmate#899）、ジョブの上限時間での打ち切りを PR が原因の失敗として直しに回すこと（genetta-inc/flatmate#1563）の 4 つ。次の入力は誤った一手のまま通ることを許す: GitHub が通信切れや上限時間の文言を変えたときは `real` になり直しに回る／PR に関わる失敗を呼び出し側が `--unrelated` で渡すと、やり直しで CI 1 周分を失う（同じ HEAD では 1 回だけなので損失はそこで止まる）／Actions 以外の失敗は手がかりがあってもやり直さない／`annotations` が取れなかったジョブは `real` になり直しに回る／ジョブ ID を持たない失敗（`detailsUrl` に `/job/<数字>` が無い）は通信切れとも上限時間の打ち切りとも判定できない／PR 自身がテストを遅くして上限時間に達したジョブも `job-timeout` になり、やり直しで CI 1 周分を失う／ステップ単位の上限での打ち切り（annotation に `maximum execution time` を含まない）は `job-timeout` にならない／1 つのジョブに通信切れと上限時間の両方の annotation があれば `runner-lost` になる。これらの穴を塞ぎ切ることはこの要件の完了条件にしない。

#### Scenario: 通信切れの annotation はやり直しに当たる
- **WHEN** 落ちたチェック `build`（job 77）が 1 件で run ID があり、`--hints` の `annotations_by_job."77"` に `The self-hosted runner lost communication with the server.` を含む文字列を渡す
- **THEN** `build` の `cause` は `runner-lost`、`retry` は `true`

#### Scenario: 上限時間で打ち切られたジョブは job-timeout
- **WHEN** 落ちたチェック `test`（`conclusion: CANCELLED`、job 77）が 1 件で run ID があり、`--hints` の `annotations_by_job."77"` に `The job running on runner mac-1 has exceeded the maximum execution time of 40 minutes.` を渡す
- **THEN** `.checks[0].cause` は `job-timeout`、`retry` は `true`

#### Scenario: 上限時間の annotation が無い取り消しは今までどおり
- **WHEN** 落ちたチェック `test`（`conclusion: CANCELLED`、job 77）が 1 件で、`--hints` の `annotations_by_job."77"` が `The operation was canceled.` だけを持つ
- **THEN** `test` の `cause` は `real`、`retry` は `false`

#### Scenario: 上限時間の打ち切りは --unrelated より先に決まる
- **WHEN** 落ちたチェック `test`（job 77）の annotation に `maximum execution time` を含む文字列があり、`--unrelated test` も渡す
- **THEN** `test` の `cause` は `job-timeout`

#### Scenario: 上限時間の打ち切りを別のジョブに移さない
- **WHEN** 別のワークフローの同名チェック `test` が job 77 と job 88 で落ち、`--hints` の `annotations_by_job` には job 77 の上限時間の annotation だけがある
- **THEN** job 77 の `cause` は `job-timeout`、job 88 の `cause` は `real`、`retry` は `false`

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
6. 観測が `ci-fail` で `retry` が `true` で、観測の `checks` に `cause` が `job-timeout` の要素が 1 件以上ある（5 に当たらなかったので、この HEAD のやり直しは使い切っている）: `act` は `escalate`、`next` は見た状態に `{raised: true}` を重ねたもの。`fixes` は変えない
7. 前回の `fixes`（無ければ 0）が 2 以上: `act` は `escalate`、`next` は見た状態に `{raised: true}` を重ねたもの
8. それ以外: `act` は `fix`、`next` は見た状態に `{fixes: <前回の fixes + 1>}` を重ねたもの

6 は、その HEAD のやり直しを使い切ったあとに打ち切りを見たときに、実装者の直しに回さずオーナーに上げるための規則である。前回の原因が `job-timeout` だったかは見ない（状態に `cause` を持たないため）。1 回はやり直すのは、`real` でない原因は同じ HEAD で 1 回だけやり直すという既存の規則（5）に揃えたもので、失うのは CI 1 周分で止まる。観測が `checks` を持たないとき、6 は当たらない（MUST）。

前回の状態の引数や標準入力が JSON として読めないときは、非 0 で終わらなければならない（MUST）。

#### Scenario: 同じ HEAD で 2 回落ちてもやり直しは 1 回
- **WHEN** HEAD `e1` で `retry: true` の `ci-fail` を初見で渡し、その `next` を前回の状態にして同じ観測をもう一度渡す
- **THEN** 1 回目は `rerun`（`next.state` は `wait`、`next.reran_head` は `e1`）、2 回目は `fix`（`next.fixes` は 1）

#### Scenario: 上限時間の打ち切りは 1 回やり直し、やり直しを使い切った HEAD で打ち切りを見たらオーナーに上げる
- **WHEN** HEAD `t1` で、`cause` が `job-timeout` のチェック 1 件を持つ `retry: true` の `ci-fail` を初見で渡し、その `next` を前回の状態にして同じ観測をもう一度渡す
- **THEN** 1 回目は `rerun`（`next.reran_head` は `t1`）、2 回目は `escalate`（`next.raised` は `true`）で、`next` に `fixes` は無い

#### Scenario: 打ち切りでオーナーに上げても修正回数は増えない
- **WHEN** `{state: "wait", head: "t1", reran_head: "t1", fixes: 1}` を前回の状態にして、HEAD `t1` の `cause` が `job-timeout` のチェックを持つ `retry: true` の `ci-fail` を渡す
- **THEN** `act` は `escalate`、`next.fixes` は 1 のまま

#### Scenario: 本当の失敗が混ざった打ち切りは直しに回す
- **WHEN** `{state: "wait", head: "t1", reran_head: "t1"}` を前回の状態にして、`cause` が `job-timeout` のチェックと `real` のチェックを持つ `retry: false` の `ci-fail`（HEAD `t1`）を渡す
- **THEN** `act` は `fix`

#### Scenario: 上げたあとの打ち切りは何もしない
- **WHEN** 打ち切りで `escalate` になった `next` を前回の状態にして、HEAD が変わった `job-timeout` の `retry: true` の `ci-fail` を渡す
- **THEN** `act` は `none`

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
