## 0. 仕様レビュー（R1）の SHOULD_FIX を artifact に取り込む

- [x] 0.1 `specs/dev-workflow-develop/spec.md` の守備範囲の段落で、拾いたい誤りを 1 つの列挙にして「…、CI の見張りのやり直しの上限で止まった子の記録に HEAD が無くて親が過去の `親の判断:` と同じ件かを見分けられないこと、の 5 つである」と書く（「4 つと、…の 5 つ」と数が食い違って読めるため）。確かめ方: `の 4 つと` が spec に無く、`の 5 つである` が 1 回出る。触る範囲: specs/dev-workflow-develop/spec.md の守備範囲の段落
- [x] 0.2 `ci-watch.md` の `escalate` 行の規定を dev-workflow-ci-watch に置く: `specs/dev-workflow-ci-watch/spec.md` に要件「CI の見張りの手順は共有 reference に 1 本置く」の MODIFIED の delta を足し、6 の `escalate` に「エピックの子のセッションは止まる前に `skills/develop/references/epic-child-stop.md` の記録を残す（書き方はそこが正本で写さない）」を足し、シナリオ「エピックの子の escalate は停止の記録の規定を指す」を足す。dev-workflow-develop の delta からは `escalate` 行のシナリオを外し、規定の在りかを指す 1 文にする。proposal の Modified Capabilities に `dev-workflow-ci-watch` を足す。確かめ方: `openspec validate epic-child-stop-ci-head-sha --type change --strict` が通る。触る範囲: specs/dev-workflow-ci-watch/spec.md（新規）・specs/dev-workflow-develop/spec.md・proposal.md

## 1. 子の停止の記録の形に、CI の見張りで止まったときの書き方を足す

- [x] 1.1 `epic-child-stop.md` の「記録の形」の箇条書き（`主に聞く理由:` の行から `親は記録の項目を正本の段に置き直して` の行まで）に 1 項目足す: CI の見張り（`references/ci-watch.md`）の 6 の表の `escalate` か 7 の直し方の手順 7 で止まったときは、`再開に要る途中経過:` に PR の URL・落ちたチェック名・止まった時点の PR の HEAD の短い SHA を書く。短い SHA は PR の HEAD のコミット SHA の先頭 7 文字（`ci-watch.sh next` の出力の `obs.head`、手元に無ければ `gh pr view <PR番号> --json headRefOid --jq '.headRefOid[0:7]'`）。取れなければ作らずに `HEAD 不明` と書く。親が `parent-pass-criteria.md` の上限で止まった子の節で `理由:` に写し、過去の `親の判断:` と同じ件かを見分けるため、と目的を添える。項目は 7 つのまま（「7 つの項目」「ほかの 6 項目」の文は変えない）。確かめ方: 3.1 のテストの (a) が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:29-33（節「エピックの子が主の返事を待って止まるとき」の「記録の形」の箇条書き）

## 2. CI の見張りの escalate から記録の規定を指す

- [x] 2.1 `ci-watch.md` の 6 の表の `escalate` の行の末尾に 1 文足す: エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）は、止まる前に `skills/develop/references/epic-child-stop.md` の記録を残す（CI の見張りで止まったときの `再開に要る途中経過:` の書き方もそこが正本）。桁数・取り方は写さない。7 の手順 7 の文（「`escalate` と同じ手順で」）は変えない。確かめ方: 3.1 のテストの (b) が通る。触る範囲: plugins/dev-workflow/references/ci-watch.md:66（6 の表の `escalate` の行）

## 3. テストと変更の記録

- [x] 3.1 2 つのテストを足す。(a) は `tests/epic-dispatch.bats` の `# spec: dev-workflow-develop（エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く）` のテスト群の末尾に置く。(a) `section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP"` に、`再開に要る途中経過:` と `HEAD の短い SHA` と `落ちたチェック名` が同じ行に出ること、`先頭 7 文字`・`obs.head`・`headRefOid`・`HEAD 不明` が出ること、`ci-watch.md` の `escalate` と手順 7 の両方に触れていること、`7 つの項目` の文が残ること。(b) は dev-workflow-ci-watch の要件のテストなので `tests/ci-watch.bats` の `escalate` の行のテストの隣に置く: `ci-watch.md` の `| \`escalate\` |` の行に `エピックの子` と `epic-child-stop.md` が出て、`先頭 7 文字`・`obs.head`・`headRefOid` が出ないこと（シナリオ「エピックの子の escalate は停止の記録の規定を指す」と 1 対 1 にするため、R1 の NOTE を取り込む）。確かめ方: 足したテストを手元で `bats -f` で回して通る（全体のテストは CI に任せる）。既存の `skill: an epic child's stop record lists the seven items in order` が通ったままであること。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3487-3529（停止の記録の形のテスト群）・plugins/dev-workflow/tests/ci-watch.bats:412-420（`escalate` の行のテスト）
- [x] 3.2 変更の記録 `plugins/dev-workflow/changes/1298.md` を `changes/1271.md` と同じ形で書く（何を変えたか・項目を足さなかった理由・読む部品と `parent-pass-criteria.md` を変えていないこと・spec の change 名・テスト・戻し方）。確かめ方: ファイルがあり、`plugins/dev-workflow/scripts/forbidden-words-check.sh` に掛けて落ちない。触る範囲: plugins/dev-workflow/changes/1298.md（新規）

## Workflow follow-up

- archive（`openspec archive epic-child-stop-ci-head-sha`）で `openspec/specs/dev-workflow-develop/spec.md` と `openspec/specs/dev-workflow-ci-watch/spec.md` の該当要件に反映する
- PR 本文に `Closes #1298` を書く
