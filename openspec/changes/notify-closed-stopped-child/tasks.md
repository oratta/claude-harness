## 1. テスト（先に書いて落ちることを確かめる）

- [ ] 1.1 `notify-closed` の振る舞いのテストを足す: 止まった印（`epic-stopped-seen`・`epic-stopped`）のまま completed で閉じた子には `親エピック #400 の判断（主の承認ではない）: 記録先の issue #11 は completed で閉じた。` で始まる文が送られ、エピックに `親の判断: 子 #11 通した` で始まる 1 行が投稿され `notified 11` を出す／端末が無ければ起動し直して `notified 11`／`--relaunch` で起動し直す。偽の `gh` は子 issue の `.state`・`.state_reason`・コメント一覧（停止の記録の URL）とエピックへの投稿を返す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2549-2600（`set_terms`・`reply_ready` の使い方）、plugins/dev-workflow/tests/epic-dispatch.bats:2991 の後ろ（新規の @test 群）、plugins/dev-workflow/tests/epic-dispatch.bats:34-311（`setup`・`make_stub`・`gh_seq`・`wt_entry`・`set_list` の使い方）
- [ ] 1.2 送らない場合のテストを足す: コメント欄が空か `epic-resumed` → `skipped 11 not-stopped`、`workspaceStatus` が `completed` → `skipped 11 already-done`、`not_planned` → `skipped 11 not-completed`、`open` → `skipped 11 not-closed`、ワークツリー 0 件 → `skipped 11 no-worktree`。どれも `orca terminal send`・`orca terminal create`・`gh issue comment` が 0 回であることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2991 の後ろ（新規）
- [ ] 1.3 失敗の場合のテストを足す: エピックへの投稿の失敗 → `unrecorded 11` と stderr の投稿し直しのコマンド、送信の失敗 → `failed 11 send` で exit 1 とエピックに投稿しないこと、`gh` の失敗 → `failed 11 issue`、ワークツリー 2 件 → `failed 11 ambiguous-worktree`、引数の誤り（数字でない・数が違う・知らないフラグ）→ 使い方と exit 1 で `orca` を呼ばないこと。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2991 の後ろ（新規）
- [ ] 1.4 手順 4 の文面のテストを足す: `run_section` の手順 4 に `notify-closed` があり、`completed` の子に呼ぶこと・`unrecorded`・`failed` の扱い・`reply-after-idle.md` への参照があることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:329-331（`section`・`run_section`）、plugins/dev-workflow/tests/epic-dispatch.bats:2438-2548（既存の手順のテストの書き方）

## 2. スクリプト

- [ ] 2.1 `cmd_notify_closed` を足す（design.md「判定の条件と出力」の順）。送信は `deliver_reply 「relaunch」 parent <epic> <child> <文> <repoId>` を使い、停止の記録の URL は `gh api repos/{owner}/{repo}/issues/<child>/comments` から `author_association` が OWNER・MEMBER・COLLABORATOR で 1 行目が `子の停止: 主の返事待ち` の最新のものを取る。投稿の失敗は `repost_hint` で出す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:415-512（`deliver_reply`・`cmd_reply`。新しい関数は `cmd_reply` の後ろ）、plugins/dev-workflow/scripts/epic-dispatch.sh:561-563（`repost_hint`）、plugins/dev-workflow/scripts/epic-dispatch.sh:215-228（`agent_setup`）
- [ ] 2.2 使い方・先頭の説明・サブコマンドの振り分けに `notify-closed` を足し、先頭の「正本」の要件名の並びに新しい要件名を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-11（使い方の並び）、plugins/dev-workflow/scripts/epic-dispatch.sh:78-118（各サブコマンドの説明と正本の要件名）、plugins/dev-workflow/scripts/epic-dispatch.sh:122-132（`usage`）、plugins/dev-workflow/scripts/epic-dispatch.sh:899-910（`case "$sub"`）

## 3. 手順書

- [ ] 3.1 develop の `SKILL.md`「回し方」の Orca 経路の手順 4 に、`completed` の子ごとに `references/reply-after-idle.md` の表で起動し直すかを決めて `scripts/epic-dispatch.sh notify-closed [--relaunch] <エピック番号> <N>` を呼ぶこと、出力の扱い（`notified`・`skipped` は何もしない、`unrecorded` は stderr の投稿し直しのコマンドでエピックに 1 行、`failed` は主に報告）、completed 以外の子には呼ばないことを足す。親が主に出す発言の 1 行目の規定（`主がすること:` の段落）の列挙に `notify-closed` の `failed` の報告を足す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:432（手順 4）、plugins/dev-workflow/skills/develop/SKILL.md:427（`主がすること:` の段落）
- [ ] 3.2 `references/reply-after-idle.md` の「送り方と起動し直し方の手順本体はここに書かない」の段落の参照先に手順 4 の `notify-closed` を足す。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:5

## 4. 確かめる

- [ ] 4.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats` が全部通ることと、`openspec validate notify-closed-stopped-child --type change --strict` が通ることを確かめる。触る範囲: なし（実行だけ）
