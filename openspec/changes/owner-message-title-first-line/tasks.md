# Tasks

## 1. テスト

- [ ] 1.1 旧い書き分けの語を検査しているテストを、新しい書き分けの語（1 行目の題名・2 行目のアクションの行）に直し、文書を直す前に落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:3715-3735、plugins/dev-workflow/tests/epic-dispatch.bats:7680-7690、plugins/dev-workflow/tests/develop-channel-mode.bats:140-155、plugins/dev-workflow/tests/develop-handover.bats:160-170

## 2. 文書

- [ ] 2.1 `epic.md` の Orca 経路の導入部（1 行目と最後の行の規定・待ちに入る通知）、手順 8（OK をもらう報告の 1 行目・答え方の行・子のタブの連絡・`failed` の報告）、状態表の規定（区切りより上の最後の行）を新しい書き分けに直す。列名 `答え方` は変えない。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:46-66、plugins/dev-workflow/skills/develop/references/epic.md:88-94
- [ ] 2.2 `channel.md` の「channel の主への発言」の 1 行目と最後の行の規定と、答え方の行の禁止を、アクションの行に直す。触る範囲: plugins/dev-workflow/skills/develop/references/channel.md:42-47
- [ ] 2.3 `handover.md` の主への案内と channel の主への案内の「最後の答え方の行」を「アクションの行」に直す。触る範囲: plugins/dev-workflow/skills/develop/references/handover.md:35-37
- [ ] 2.4 `rg -n '1 行目を質問|最後の答え方|最後の行に答え方|問いの質問' plugins/dev-workflow/skills` が 0 件であることを確かめる。触る範囲: なし（確認のみ）

## 3. 確認

- [ ] 3.1 `bats plugins/dev-workflow/tests/epic-dispatch.bats plugins/dev-workflow/tests/develop-channel-mode.bats plugins/dev-workflow/tests/develop-handover.bats plugins/dev-workflow/tests/develop-skill.bats` を通す。触る範囲: なし（確認のみ）
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1671.md` にこの change の分を足す。触る範囲: plugins/dev-workflow/changes/1671.md
