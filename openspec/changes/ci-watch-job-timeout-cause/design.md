## Context

`pr-state.sh observe` は落ちたチェックの原因を 3 つに分ける。`runner-lost`（ジョブの annotation に `The self-hosted runner lost communication with the server`）、`unrelated`（呼び出し側が `--unrelated` で渡した名前）、`real`（それ以外）。落ちたチェックがすべて `real` でなく run ID を持てば `retry` が `true` になり、`decide` は HEAD ごとに 1 回だけ `rerun` を返す。同じ HEAD でまた落ちると、`retry` が `true` でも「前回の `fixes` が 2 以上なら `escalate`、そうでなければ `fix`」に進む。

ジョブが上限時間（`timeout-minutes`）で打ち切られたときの今の流れは次のとおり。

| 場面 | 今の動き | 失うもの |
|---|---|---|
| 1 回目の打ち切り | annotation に通信切れの文言が無いので `real`。呼び出し側がログを読んで `--unrelated` を渡せば `rerun`、渡さなければ `fix` | `fix` なら実装者が PR の差分を調べる 1 往復 |
| やり直しても同じ HEAD でまた打ち切り | `reran_head` が同じなので `rerun` にならず `fix` | CI 1 周分（flatmate では 40 分）と、実装者の 1 往復 |

実装者はランナーの状態（取り残しのプロセス・ディスク・負荷）を直せないので、この `fix` は成果が出ない。`fix` のたびに `fixes` が増え、PR の本当の失敗を直せる回数（2 回）も減る。

annotation は `pr-state.sh annotations` が落ちたジョブごとに既に取っており、`observe --hints` に渡る。新しく `gh` を呼ぶ箇所は要らない。

## Goals / Non-Goals

**Goals:**

- 上限時間で打ち切られたジョブを、PR が原因の失敗と別の原因として観測に出す
- 打ち切りが同じ HEAD で 2 回続いたら、実装者に直させず、原因が分かる形でオーナーに上げる
- 新しい push による取り消しなど、上限時間の annotation を持たない失敗の扱いを変えない

**Non-Goals:**

- `ci-watch.sh wait` の上限時間の既定値（3600 秒）の見直し（flatmate 側で CI が短くなったあとの実測で決める）
- `runner-lost`・`unrelated` が同じ HEAD で 2 回続いたときに `fix` になる既存の動きの見直し
- ランナーの状態そのものの検査や復旧（見張りは伝えるところまで）
- ステップ単位の上限（`steps[*].timeout-minutes`）での打ち切りの判定

## Decisions

### 1. 原因名は `job-timeout`、見分ける文言は `maximum execution time`

`observe` は、ジョブの annotation のいずれかが `maximum execution time` を含むとき `cause` を `job-timeout` にする。GitHub が打ち切ったジョブに付ける annotation は `The job running on runner <名前> has exceeded the maximum execution time of <N> minutes.` の形で、ランナー名と分数が入るので、変わらない部分だけを部分一致で見る（`runner-lost` の判定と同じやり方）。文言は `pr-state.sh` の定数 1 つに置き、GitHub が変えたらそこだけ直す。

名前を `timeout` にしなかったのは、`ci-watch.sh wait` の `result` に既に `timeout`（見張りの上限時間を超えた）があり、同じ語が 2 つの別の出来事を指すと reference の読み手が取り違えるため。

### 2. 判定の順は `runner-lost` → `job-timeout` → `unrelated` → `real`

annotation という GitHub 由来の事実で決まる 2 つを、呼び出し側の判断（`--unrelated`）より先に置く。呼び出し側が打ち切られたチェックを `--unrelated` で渡しても `job-timeout` のままにし、2 回目に `escalate` へ進めるようにする。

1 つのジョブに通信切れと上限時間の両方の annotation が付いたときは、既存の順を保って `runner-lost` にする。どちらでも 1 回目はやり直しになり、違いが出るのは同じ HEAD の 2 回目（`fix` か `escalate` か）だけで、両方が同時に付く場面は確かめていない。既存のテストと仕様の読みを変えないほうを選んだ。

### 3. 一手: 1 回はやり直し、同じ HEAD でまた打ち切られたらオーナーに上げる

issue はこの一手を、`dev-workflow-ci-watch` の既存の `runner-lost` の扱いと揃えて決めるよう指定している。既存の扱いは「`real` でない原因は同じ HEAD で 1 回だけやり直す。失うのは CI 1 周分で止まる」である（`dev-workflow-pr-state` の守備範囲と、`dev-workflow-ci-watch` の `--unrelated` の守備範囲に同じ文がある）。これに揃えて、1 回目の打ち切りはやり直す。

検討した 2 案の比較:

| 案 | 1 回目 | 同じ HEAD の 2 回目 | 受け入れること |
|---|---|---|---|
| 1 回はやり直す（採用） | `rerun` | `escalate` | ランナーが壊れたままのとき、やり直しの CI 1 周分（flatmate では 40 分）を待ってからオーナーに届く |
| 1 回もやり直さずに上げる | `escalate` | — | ランナーが一時的に混んでいただけの打ち切りでも、毎回オーナーの手が要る。見張りが止まるので、オーナーが動くまで PR は進まない |

1 回はやり直すほうを採った理由は 3 つある。1 つ目は、打ち切りには一時的なもの（ほかのジョブと重なってランナーが遅かった）が含まれ、それはやり直しで通ること。2 つ目は、やり直さない案では `job-timeout` だけ「`real` でないのに `retry` が `false`」になり、`retry` の定義（落ちたチェックがすべて `real` でなく run ID を持つ）に例外が入ること。`retry` は flatmate の pr-watch も読む出力なので、定義は変えないほうが安全である。3 つ目は、損失の上限が既存の規則と同じ CI 1 周分で、新しい種類の損失を足さないこと。

flatmate の PR #1516 のように 2 回とも打ち切られる場面では、この案でも CI 1 周分は失う。変わるのはそのあとで、実装者の直しに回らずにオーナーへ届く。

### 4. 2 回目は `fix` でなく `escalate`（`runner-lost` と揃えない部分）

`runner-lost` が同じ HEAD で 2 回続くと、既存の `decide` は `fix` を返す。`job-timeout` はここを揃えず `escalate` にする。issue の受け入れ条件（同じ原因が同じ HEAD で 2 回続いた入力で `act` が `fix` にならない）がこれを求めており、実装者が直せない原因を直しに回さないことがこの変更の目的だからである。`runner-lost` の 2 回目も同じ理由で `escalate` にする余地はあるが、issue の範囲に無く、既存のテスト（`Ne1-Ne2 (runner-lost hint)`）の期待値を変えることになるので、この変更では触らない。

`decide` の規則は、既存の「やり直し」の規則の直後に 1 つ足す。

- 条件: 観測が `ci-fail` で `retry` が `true`、かつ `checks` に `cause` が `job-timeout` の要素が 1 件以上ある
- 一手: `escalate`。`next` は見た状態に `{raised: true}` を重ねたもの

この規則は「やり直し」の規則のあとに評価されるので、ここに来るのはその HEAD のやり直しを使い切ったときだけである。`fixes` は増やさない（実装者に直しを頼んでいないため）。`raised` が立つので、そのあとは既存の規則どおり `none` になり、オーナーの指示で再開するときは reference の既存の手順（`raised` を消す前に中断した一手を確かめる）に従う。

`retry` が `true` であることを条件に入れたのは、`real` の失敗が混ざっているとき（`retry` が `false`）を外すためである。PR が原因の失敗が同時にあれば、実装者に直せるものがあるので既存どおり `fix` に進める。

`checks` を持たない観測（古い呼び出し側が自分で組み立てた観測）では、この規則は当たらず既存の順のまま進む。

### 5. 理由の伝え方は reference に書き、`decide` の出力の形は変えない

`escalate` の理由は `decide` の出力に既にある（`obs.checks[].cause`）。出力に `reason` のようなキーを足す案は、`{act, next, obs}` という契約を広げることになり、読み手は今のところ reference の手順だけなので採らなかった。`references/ci-watch.md` の `escalate` の行に、`obs.checks` に `job-timeout` があるときの伝え方（落ちたチェック名・run・PR の URL に加えて「ジョブが上限時間で打ち切られた。ランナーの状態を確かめてほしい」）を書く。

同じ reference の `--unrelated` を渡す基準は、対象を `cause` が `real` のチェックに限っているので、`job-timeout` はログを読む判断の対象にならない。これは既存の文のままで成り立つが、読み手が迷わないよう 1 文で明示する。

### 6. `dev-workflow-ci-watch` の仕様は要件を足す形にする

見張りの手順を定める既存の要件（「CI の見張りの手順は共有 reference に 1 本置く」）は 8 項目を 1 つの要件に持つ長い文で、`escalate` の動きを「落ちたチェック名と PR の URL を添えてオーナーに頼む」と定めている。今回の動きはこれに理由を 1 つ添えるだけで矛盾しないので、既存の要件を書き換えず、上限時間の打ち切りの扱いを 1 つの要件として足す。長い要件を丸ごと写して差し替えると、archive のときに写し損じで既存の文が欠ける危険があるため。

`dev-workflow-pr-state` の 2 つの要件（`observe` の仕分けと `decide` の一手の順）は、順序つきの一覧そのものが変わるので書き換える。

## Risks / Trade-offs

- PR 自身がテストを遅くして上限に達したときも `job-timeout` になる。1 回やり直したあと、実装者の直しではなくオーナーに届く。→ オーナーへの文面は「ランナーの状態を確かめてほしい」であり、ランナーに問題が無ければオーナーが実装者に直しを指示する（reference の既存の「`escalate` のあとに続けるよう言われたとき」の手順）。失うのは CI 1 周分とオーナーの 1 往復。flatmate の 2026-10-09〜12 の 9 件以上はランナー側が原因だったので、こちらの取り違えのほうが少ないと見ている
- GitHub が annotation の文言を変えると `job-timeout` にならず `real` に戻る。→ 今と同じ動き（直しに回る）に戻るだけで、今より悪くはならない。文言は定数 1 つ
- `annotations` の取得に失敗したジョブは `real` になる。→ 既存の `runner-lost` と同じ穴で、今と同じ動きに戻るだけ
- flatmate の pr-watch が `cause` の値を列挙して扱っていると、知らない値 `job-timeout` を受け取る。→ `retry` と `act` の意味は変えていないので、`retry` と `act` だけを読む呼び出し側は影響を受けない。`cause` を直接読んでいるかはこのリポジトリからは確かめていないので、変更の記録（`changes/991.md`）に新しい値を書く

## Migration Plan

状態ファイルの形は変えないので、移行は要らない。見張りの途中でこの変更が入った PR は、次の `next` から新しい規則で判定される。戻すときはこの PR の差分を戻す（状態ファイルに残った `raised: true` は、reference の既存の手順で消す）。
