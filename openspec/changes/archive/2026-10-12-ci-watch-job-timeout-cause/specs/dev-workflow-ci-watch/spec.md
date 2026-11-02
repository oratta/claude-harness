## ADDED Requirements

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
