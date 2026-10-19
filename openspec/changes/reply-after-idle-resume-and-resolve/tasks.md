## 1. 手順書

- [ ] 1.1 SKILL.md 手順 7 に主の返事待ちの子の出し直しを足す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:435-436
- [ ] 1.2 reply-after-idle.md の復元元の表に行を足す 触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md:42-54

## 2. スクリプト

- [ ] 2.0 読み取り専用の `pending-owner <子>...` を足す（使い方・冒頭コメントも） 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:1-20、plugins/dev-workflow/scripts/epic-dispatch.sh（cmd_wait の前に新規関数）
- [ ] 2.1 `resolve_stopped` の前に起動し直しの判定関数を足し、`deliver_reply` の第 1 引数に使う。冒頭コメントの `--resolve` の説明も直す 触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:64-80、plugins/dev-workflow/scripts/epic-dispatch.sh:672-695

## 3. テスト

- [ ] 3.1 手順 7 と表の行を確かめる 触る範囲: plugins/dev-workflow/tests/develop-skill.bats（末尾付近）
- [ ] 3.2 偽の orca・gh・トランスクリプトで relaunched / sent / sent（読めない）を確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:2840-2910
- [ ] 3.3 `pending-owner` が `epic-stopped-seen` の子だけを返すことを確かめる 触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（末尾付近）
