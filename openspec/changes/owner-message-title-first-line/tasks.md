# Tasks

## 1. テスト

- [x] 1.1 旧い書き分けの語を検査しているテストを、新しい書き分けの語（1 行目の題名・2 行目のアクションの行）に直し、文書を直す前に落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3715-3735、plugins/dev-workflow/tests/epic-dispatch.bats:7680-7690、plugins/dev-workflow/tests/develop-channel-mode.bats:140-155、plugins/dev-workflow/tests/develop-handover.bats:160-170

- [x] 1.2 手順 8 の記録の項目の対応を検査するテスト（`止まった理由:` を質問に…）を、新しい対応（題名と詳細・論点・詳細・推奨と根拠・リスク、アクションは親が書く、使う場所の表に従う）と、`を質問に`・`をいま困っていることに`・`3〜4 行` が無いことの検査に直し、文書を直す前に落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3958-3975（「skill: step 8 of the Orca route restates the stop record in the readable steps」）
- [x] 1.3 状態表の規定のテストに、依頼が無い報告ではアクションの行を書かないことの検査を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（状態表の規定を検査するテスト。`rg -n '区切りより下' plugins/dev-workflow/tests/epic-dispatch.bats` で探す）

## 2. 文書

- [x] 2.1 `epic.md` の Orca 経路の導入部（1 行目と最後の行の規定・待ちに入る通知）、手順 8（OK をもらう報告の 1 行目・答え方の行・子のタブの連絡・`failed` の報告）、状態表の規定（区切りより上の最後の行）を新しい書き分けに直す。列名 `答え方` は変えない。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:46-66、plugins/dev-workflow/skills/develop/references/epic.md:88-94
- [x] 2.1b `epic.md` 手順 8 の「子の停止の記録の項目は正本の段に置き直す: `止まった理由:` を質問に…受け入れるリスクにする」を新しい対応に直し、アクションの行は親が書くこと・使う項目と長さは正本の使う場所の表（親のタブは対話のセッション、チャンネルはチャットで 1 件ずつ出す依頼。ブロックには止まっている子）に従うことを書く。同じ手順の「論点なしなら区切りより上を 3〜4 行に収め」を、正本の論点の無い依頼の決まりを指す文に直す。状態表の規定の 1 行目と 2 行目の文を、依頼の有無で分ける。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:88（手順 8 の「主に上げる」の文と「子の記録の推奨を主に OK してもらう報告」の文）、plugins/dev-workflow/skills/develop/references/epic.md:46-66（状態表の規定）
- [x] 2.2 `channel.md` の「channel の主への発言」の 1 行目と最後の行の規定と、答え方の行の禁止を、アクションの行に直す。触る範囲: plugins/dev-workflow/skills/develop/references/channel.md:42-47
- [x] 2.3 `handover.md` の主への案内と channel の主への案内の「最後の答え方の行」を「アクションの行」に直す。触る範囲: plugins/dev-workflow/skills/develop/references/handover.md:35-37
- [x] 2.4 `rg -n '1 行目を質問|最後の答え方|最後の行に答え方|問いの質問' plugins/dev-workflow/skills` が 0 件であることを確かめる。触る範囲: なし（確認のみ）

## 3. 確認

- [x] 3.0 spec の Scenario「実機で親の報告が正本の型になり、理由の無い止まりは上がらない」を `claude -p --plugin-dir` で取り直し、主に上げた報告の 1 行目が題名・2 行目が `アクション:` の行であることを確かめる（結果は変更の記録に書く）。触る範囲: なし（確認のみ）

- [ ] 3.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/develop-channel-mode.bats plugins/dev-workflow/tests/develop-handover.bats plugins/dev-workflow/tests/develop-skill.bats` を通す。触る範囲: なし（確認のみ）
- [x] 3.2 変更の記録 `plugins/dev-workflow/changes/1671.md` にこの change の分を足す。触る範囲: plugins/dev-workflow/changes/1671.md
