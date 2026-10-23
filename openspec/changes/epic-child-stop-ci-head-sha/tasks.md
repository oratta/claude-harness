## 1. 子の停止の記録の形に、CI の見張りで止まったときの書き方を足す

- [ ] 1.1 `epic-child-stop.md` の「記録の形」の箇条書き（`主に聞く理由:` の行から `親は記録の項目を正本の段に置き直して` の行まで）に 1 項目足す: CI の見張り（`references/ci-watch.md`）の 6 の表の `escalate` か 7 の直し方の手順 7 で止まったときは、`再開に要る途中経過:` に PR の URL・落ちたチェック名・止まった時点の PR の HEAD の短い SHA を書く。短い SHA は PR の HEAD のコミット SHA の先頭 7 文字（`ci-watch.sh next` の出力の `obs.head`、手元に無ければ `gh pr view <PR番号> --json headRefOid --jq '.headRefOid[0:7]'`）。取れなければ作らずに `HEAD 不明` と書く。親が `parent-pass-criteria.md` の上限で止まった子の節で `理由:` に写し、過去の `親の判断:` と同じ件かを見分けるため、と目的を添える。項目は 7 つのまま（「7 つの項目」「ほかの 6 項目」の文は変えない）。確かめ方: 3.1 のテストの (a) が通る。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:29-33（節「エピックの子が主の返事を待って止まるとき」の「記録の形」の箇条書き）

## 2. CI の見張りの escalate から記録の規定を指す

- [ ] 2.1 `ci-watch.md` の 6 の表の `escalate` の行の末尾に 1 文足す: エピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す）は、止まる前に `skills/develop/references/epic-child-stop.md` の記録を残す（CI の見張りで止まったときの `再開に要る途中経過:` の書き方もそこが正本）。桁数・取り方は写さない。7 の手順 7 の文（「`escalate` と同じ手順で」）は変えない。確かめ方: 3.1 のテストの (b) が通る。触る範囲: plugins/dev-workflow/references/ci-watch.md:66（6 の表の `escalate` の行）

## 3. テストと変更の記録

- [ ] 3.1 `tests/epic-dispatch.bats` の `# spec: dev-workflow-develop（エピックの子の停止の記録は、子の会話を読んでいない読み手が 1 通で読める形で書く）` のテスト群の末尾に、2 つのテストを足す。(a) `section 'エピックの子が主の返事を待って止まるとき' "$EPIC_CHILD_STOP"` に、`再開に要る途中経過:` と `HEAD の短い SHA` と `落ちたチェック名` が同じ行に出ること、`先頭 7 文字`・`obs.head`・`headRefOid`・`HEAD 不明` が出ること、`ci-watch.md` の `escalate` と手順 7 の両方に触れていること、`7 つの項目` の文が残ること。(b) `ci-watch.md` の `| \`escalate\` |` の行に `エピックの子` と `epic-child-stop.md` が出て、`先頭 7 文字` が出ないこと。確かめ方: 足したテストを手元で `bats -f` で回して通る（全体のテストは CI に任せる）。既存の `skill: an epic child's stop record lists the seven items in order` が通ったままであること。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3487-3529（停止の記録の形のテスト群）
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1298.md` を `changes/1271.md` と同じ形で書く（何を変えたか・項目を足さなかった理由・読む部品と `parent-pass-criteria.md` を変えていないこと・spec の change 名・テスト・戻し方）。確かめ方: ファイルがあり、`plugins/dev-workflow/scripts/forbidden-words-check.sh` に掛けて落ちない。触る範囲: plugins/dev-workflow/changes/1298.md（新規）

## Workflow follow-up

- archive（`openspec archive epic-child-stop-ci-head-sha`）で `openspec/specs/dev-workflow-develop/spec.md` の該当要件に反映する
- PR 本文に `Closes #1298` を書く
