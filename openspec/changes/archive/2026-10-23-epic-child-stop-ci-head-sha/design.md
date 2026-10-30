# Design

## Context

理由は proposal.md の Why。いまの形は次のとおり。

- 子の停止の記録の形の正本は `skills/develop/references/epic-child-stop.md`「記録の形」で、7 つの項目（`止まった理由:`〜`再開に要る途中経過:`）をこの並びで書き、省かない
- この形を読む部品: `scripts/stop-judge.sh`（本文を項目名を解釈せずに判断のモデルへ渡す。`tests/stop-judge.bats` が 7 項目のまま渡すことを確かめる）、`scripts/epic-dispatch.sh`、`references/epic.md` 手順 8（項目を正本の段に置き直す。`再開に要る途中経過:` は主には書かず URL で足りる）、`parent-merge-criteria.md`（`止まった理由:` の値の頭を読む）、`parent-pass-criteria.md`（上限で止まった子の節。`理由:` の PR 番号・チェック名・HEAD を記録から取り、無ければ `不明`）
- 「7 つの項目」「ほかの 6 項目」の語は `epic-child-stop.md`・`openspec/specs/dev-workflow-develop/spec.md`・`tests/epic-dispatch.bats`・`tests/parent-merge.bats`・`tests/stop-judge.bats` に出る
- CI の見張りの `escalate` の行（`references/ci-watch.md` 6 の表）は「落ちたチェック名と PR の URL を添えてオーナーに 1 アクションで頼む」だけで、エピックの子のときに停止の記録をどう書くかに触れていない。`ci-watch.sh next` の出力の `obs.head` に PR の HEAD のコミット SHA（全桁）がある

## Goals / Non-Goals

**Goals:**
- 上限で止まった子の停止の記録を読めば、止まった時点の PR の HEAD の短い SHA が分かる
- 親が `理由:` に書く短い SHA と、子が記録に書く短い SHA が同じ桁数でそろう

**Non-Goals:**
- 記録を読む部品（`stop-judge.sh` など）を変えること
- CI の見張り以外の止まり（マージ待ち・リスク許容の保留など）で HEAD を書かせること。`ci-watch.md` の `ready` のあとのマージ待ちの例は既に `再開に要る途中経過:` に「今の HEAD の SHA」を挙げており、そこは変えない
- `parent-pass-criteria.md` を変えること（兄弟の子 #1253・#1270・#1280 が同時に触っており、`子の停止の記録から取って` の文はこの変更のあとも正しい）

## Decisions

### HEAD は既存の `再開に要る途中経過:` に書く（8 つ目の項目を足さない）

- 案 A（採用）: `再開に要る途中経過:` に PR の URL・落ちたチェック名・HEAD の短い SHA を書く。項目の数と並びは変わらないので、読む部品・「7 つの項目」の記述・既存テストはそのまま。`再開に要る途中経過:` はもともと「コミット・PR など」を書く項目で、意味が合う。`stop-judge.sh` は本文をそのまま判断のモデルに渡すので、親の判断のモデルにも届く
- 案 B（不採用）: 8 つ目の項目 `止まった時点の HEAD:` を足す。どの止まりでも書くことになり、CI に関係しない止まりでは常に `なし` になる。「7 つ」の記述・spec のシナリオ・3 つの bats を直すことになり、変更が今回の目的より広い
- 案 C（不採用）: CI の見張りの `escalate` の出力（オーナーへの頼み）にだけ書く。親が読むのは子 issue の停止の記録で、端末に出たオーナーへの頼みは読めないので、受け入れ条件（停止の記録を読んで分かる）を満たさない

### 規定の正本は `epic-child-stop.md`、`ci-watch.md` は指すだけ

記録の形の正本は `epic-child-stop.md`（`ci-watch.md` の `ready` のあとのマージ待ちの段落も「記録の形の正本は `epic-child-stop.md` の側」と書いている）。同じ規定を 2 か所に書くと片方だけ直す事故が起きるので、`ci-watch.md` の `escalate` の行には「エピックの子のセッションは止まる前に `epic-child-stop.md` の記録を残す（CI の見張りで止まったときの `再開に要る途中経過:` の書き方もそこ）」とだけ書き、止まり方として `mark stopped` で止まることまで書く（記録だけ残して印を付けないと親が気づかないため）。手順 7 は「`escalate` と同じ手順でオーナーに上げる」なので、行を足さずに同じ規定が及ぶ。`obs.state` が `wait` でない `none`（前回と同じ状態・同じ HEAD の決着）にも同じ 1 文を足す。親が追加のやり直しを許して子が `raised` を消して見張りに戻ったあと、同じ HEAD でまた落ちると、`pr-state.sh decide` は前回と同じ状態・同じ HEAD として `escalate` ではなく `none` を返し、子はそこで止まる。これがちょうど親が過去の `親の判断:` と見比べたい止まりなので、対象から外せない（PR ゲートの 1 周目の指摘）。仕様の側も同じ分け方にする。記録の書き方は dev-workflow-develop の要件「エピックの子の停止の記録は…」が持ち、`escalate` の行がその記録を指すことは dev-workflow-ci-watch の要件「CI の見張りの手順は共有 reference に 1 本置く」の 6 が持つ（`escalate` の行の中身はもともとその要件が規定しているため。仕様レビューの 1 周目の指摘）。

### 短い SHA は PR の HEAD のコミット SHA の先頭 7 文字

- 子の手元の `git rev-parse --short HEAD` は、作業ツリーが PR の HEAD とずれていることがあり、桁数も repo の大きさで変わる。親が過去の `親の判断:` と見比べるには、どの HEAD か・何桁かが毎回同じである必要がある
- 取り方: `ci-watch.sh next` の出力の `obs.head` の先頭 7 文字（手元に無ければ `gh pr view <PR番号> --repo <owner/repo> --json headRefOid --jq '.headRefOid[0:7]'`）。GitHub の画面の短い SHA と同じ 7 文字
- 取れなかったときは作らずに `HEAD 不明` と書く。親は `parent-pass-criteria.md` のとおり `不明` として扱う

## Risks / Trade-offs

- [子が `再開に要る途中経過:` に HEAD を書き忘れる] → 親は `不明` と書き、同じ件かを見分けられないものとして扱う（`parent-pass-criteria.md` の既存の扱い）。損失は親が見分けを諦めて主に上げる側に倒れることで、誤って通す側には倒れない
- [項目の中に埋めるので、機械では取り出しにくい] → 今の読み手（親のセッションと判断のモデル）は本文を読むので足りる。機械で取り出す部品が要るようになったら、そのときに項目を分ける
- [この変更の前に起動された子は HEAD を書かない] → 上と同じく `不明` で扱われる

## Migration Plan

文書とテストの変更だけ。マージ後に起動された子から効く。戻すときは PR を revert する。
