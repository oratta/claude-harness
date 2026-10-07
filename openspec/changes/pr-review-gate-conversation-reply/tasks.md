## 1. 確認スクリプト（テストから）

- [x] 1.1 `owner-reply-check.bats` を新設し、テスト用の会話ログ（`OWNER_REPLY_PROJECTS_DIR` の下に `<プロジェクト>/<UUID>.jsonl` を一時作成）で次を 1 件ずつ固定する。通す: 通常の発言（`origin.kind: "human"`）・`<command-args>721 許容する</command-args>` の行・`origin` の無い `<bash-input> gh pr comment ...` の行。通さない（exit 1）: `type: "assistant"`・`isSidechain: true`・`tool_result` を含む配列・`Another Claude session sent a message` で始まる行（`origin` も `isMeta` も無い形）・`<teammate-message` を含む行・`isMeta: true`・`origin.kind` が `"peer"` / `"task-notification"` / `"channel"` の行（`isMeta` 無し）・本文が `<bash-stdout>` / `<bash-stderr>` / `<local-command-stdout>` / `<local-command-stderr>` で始まる行。通す側にもう 1 件: `type: "text"` の要素だけからなる配列の本文。exit 2: 引数 1 個・UUID でない ID・空白だけの原文・会話ログ無し。ほかに改行の違いを無視する一致、`MATCH: <timestamp> <全文>` と `MATCHES=<件数>` の出力、`<ID>/subagents/` の下の会話ログを読まないこと。触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats（新規）、書き方の手本は plugins/dev-workflow/tests/risk-carryover-check.bats:1-40
- [x] 1.2 `owner-reply-check.sh` を実装する（bash の入口で引数と UUID を検査し、埋め込みの `python3` で JSONL を読む。主の発言の 7 条件は design.md の Decisions 2 のとおり。壊れた行は読み飛ばす）。`scripts/test.sh owner-reply-check` が exit 0 になるまで。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh（新規）、ヘッダの書き方の手本は plugins/dev-workflow/scripts/risk-carryover-check.sh:1-30、埋め込み python の手本は plugins/dev-workflow/scripts/context-tripwire.sh:150-190

## 2. pr-review-gate の文書

- [x] 2.1 手順 5 の合格条件の表に「会話で受領」の行を足し、真正性確認の段落に記録の書式（`主の回答: 許容 — 会話で受領（セッション <セッション ID> / <日時>）原文: <原文>`）・`owner-reply-check.sh` の呼び方と終了コードの扱い・記録の日時と同じ timestamp の `MATCH:` の全文で許容の意思を読むこと・確認記録の書式・exit 2 のときの受け直し先を書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:46-68（手順 5 の表と「許容リンク経由の合格では」の段落）
- [x] 2.2 手順 3-c の条件 3 に、元の回答が会話で受けたものでもよいこと・引き継いだ宣言には元の記録を書き写すこと・やり直しはスクリプトの再実行で、終了コード 0 かつ記録の日時と同じ timestamp の `MATCH:` があり、その全文から許容の意思が読めるときだけ引き継ぐこと（終了コード 0 でも日時が一致しない、`許容しない` への部分一致などは不可）、どれかが欠ければ手順 6 へ進むことを足す。追記の書式ブロックは 4 行の構造を維持し、1 行目の回答の書式を「回答リンク」と「会話で受領（セッション … / …）原文: …」の 2 形に拡張する。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:29-45（3-c の条件と追記の書式）
- [x] 2.3 手順 6 の依頼（項目 3）と復帰表の「リスク許容待ち」の行に、会話で返事をすればよく PR へのコメントは要らないこと、会話で受けたら主に PR へのコメントを求めず「会話で受領」の形で追記して手順 5 の確認をすることを書く。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:49-65（手順 6）
- [x] 2.4 `pr-review-gate-skill.bats` に、pass.md の手順 5 に「会話で受領」と `owner-reply-check.sh` があること、hold.md に「会話で返事を受けたときは主に PR へのコメントを求めない」旨の文があること、3-c の条件 3 が会話の回答を扱うこと、3-c の追記の書式ブロックが 4 行のまま 1 行目に会話の記録の形を持つこと、手順 5 と 3-c に「終了コード 0 でも日時が一致しなければ不可」と「`許容しない` への部分一致では不可」に当たる文があることを固定するテストを足す（既存の「4 行」のテストが会話の形の追加で落ちないように書式ブロックの書き方を合わせる）。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1-30（setup の変数）、plugins/dev-workflow/tests/pr-review-gate-skill.bats:960-996（末尾の carryover のテストの後ろに足す）
- [x] 2.5 自動セキュリティレビューの指摘（同じセッションで別の PR へ返した許容を流用できる）を受け、手順 5 と 3-c の条件 3 に、同じ timestamp が記録を追記する宣言（3-c では `引き継ぎ元:` をたどった最初の宣言）の作成日時より後であることと、全文が別の PR・別のリスクを名指ししていないことを足す。delta spec の dev-workflow-pr-review-gate にも同じ条件と Scenario を足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md・hold.md、plugins/dev-workflow/tests/pr-review-gate-skill.bats（末尾に 2 件）、openspec/changes/pr-review-gate-conversation-reply/specs/dev-workflow-pr-review-gate/spec.md

## 3. develop の文書

- [x] 3.1 「保留で止まるときの引き継ぎ」の主への案内に、許容は会話で返すか `/develop <記録先> 許容する` と打てばよく PR へのコメントは要らないことを足す。再開手順 2 に、`/develop` の引数の残りを会話で受けた回答として扱い、セッション ID（`$CLAUDE_CODE_SESSION_ID`）・日時・原文を保留の解除の G に渡すことを足す。保留の行（`保留 → needs-approval のまま`）にも、同じセッションで会話の返事を受けたら同じ値を G に渡すことを足す。守備範囲の段落の「主の返事」の出どころに `/develop` の引数が既にあることを確かめ、矛盾があれば直す。書式は再掲しない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:157（保留の行）、plugins/dev-workflow/skills/develop/SKILL.md:229（主への案内）、plugins/dev-workflow/skills/develop/SKILL.md:236（再開手順 2）、plugins/dev-workflow/skills/develop/SKILL.md:242（守備範囲）
- [x] 3.2 案内の文言を固定している既存のテストが 3.1 の変更で落ちないか確かめ、案内に「PR へのコメントは要らない」があることを固定するテストを足す。触る範囲: plugins/dev-workflow/tests/develop-handover.bats:45-100

## 4. 仕上げ

- [x] 4.1 変更の記録を書く（何を変えたか・なぜ・会話ログを読めない PC では従来の経路に戻ること・この PR 自体が安全ゲートの弱体化に当たること）。触る範囲: plugins/dev-workflow/changes/721.md（新規）
- [x] 4.2 `scripts/test.sh owner-reply-check`・`scripts/test.sh pr-review-gate-skill`・`scripts/test.sh dev-workflow` がそれぞれ exit 0、`grep -n "会話で受領" plugins/dev-workflow/skills/pr-review-gate/stages/pass.md` が 1 行以上であることを確かめる。常時注入の予算（`tests/injection-budget.bats`）に触れていないことも確かめる。触る範囲: なし（確認だけ）
