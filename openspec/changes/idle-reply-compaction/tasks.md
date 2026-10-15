## 1. epic-dispatch.sh の起動コマンドに閾値を前置きする

- [ ] 1.1 `cmd_launch` で `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS`（既定 `120000`）を読み、空文字か数字だけでない値なら stderr に変数名を出して `usage`（exit 1、`orca` も `git` も呼ばない位置。`EPIC_DISPATCH_MODEL` の検査の隣）。`agent_cmd` を `EPIC_DISPATCH_PARENT_EPIC=$epic CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=<値> $claude_cmd --model ...` にする。`recreate_hint` は `agent_cmd` をそのまま出すので直さない。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:178-191（`cmd_launch` の環境変数の検査と `agent_cmd` の組み立て）
- [ ] 1.2 ヘッダコメントの `launch` の説明に、起動コマンドの形の前置きと `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS`（既定 120000、空か数字でなければ exit 1）を足す。触る範囲: plugins/dev-workflow/scripts/epic-dispatch.sh:20-29

## 2. 規則のファイルと SKILL.md

- [ ] 2.1 `reply-after-idle.md` を新設し、子 120,000・親 100,000 の値、親の値は主の起動コマンドの先頭に付けて `~/.claude/settings.json` の `env` に置かないこと、「そのまま送る」か「起動し直す」かを分ける条件（端末が無い／60 分未満／コンパクトが走った／N が 150,000 以上か未満）、判定に使う事実（`orca terminal list --worktree path:<子> --json`、トランスクリプトの最後のリクエストの時刻と `compact_boundary`、`plugins/dev-workflow/scripts/subagent-context.sh --file`）、親への適用と親の状態の復元、根拠（#1039 の集計コメントの URL と要点）と限り、1〜2 週間後の再集計を書く。送り方・起動し直し方の手順本体は書かない（#1034 が書く）。触る範囲: plugins/dev-workflow/skills/develop/references/reply-after-idle.md（新規）
- [ ] 2.2 SKILL.md「回し方」の「子セッションは `launch` が `cld --model '<model>'` で起動する」の段落に、起動コマンドの先頭に `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`（既定 120000、`EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS` で変える）が付くことを 1 文足す。「`--dangerously-skip-permissions` で動き」の段落のあとに、時間がたった子・親に返事を送る前に `references/reply-after-idle.md` の規則で「そのまま送る」か「起動し直す」かを決めることを短い段落で足す。「`nested` を受けたセッション」の段落と「`epic-dispatch.sh` が足すのは `--model` だけ」の文、他の節は触らない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:389-391

## 3. テスト

- [ ] 3.1 `--command` の完全一致の期待値 3 か所に `CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS=120000 ` を足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:441、plugins/dev-workflow/tests/epic-dispatch.bats:458、plugins/dev-workflow/tests/epic-dispatch.bats:466
- [ ] 3.2 `launch` のテストを足す: `EPIC_DISPATCH_IDLE_COMPACT_MIN_TOKENS=150000` で前置きの値が変わる、空と `120k` で exit 1・stderr に変数名・`orca` と `git` を呼ばない（既存の「an empty EPIC_DISPATCH_MODEL creates nothing」の隣）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:469-481
- [ ] 3.3 規則のファイルの記述（120,000・100,000、`settings.json` に置かない、150,000、60 分、`compact_boundary`、再集計）と、SKILL.md「エピックの扱い」の記述（`CLAUDE_CODE_IDLE_COMPACT_MIN_TOKENS`、`reply-after-idle.md`）を確かめるテストを足す（`section()` と SKILL を確かめる節を使う）。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:243（`section()`）、plugins/dev-workflow/tests/epic-dispatch.bats:1491-1501（近い既存テスト。新しいテストはこの節の末尾 1608 行付近に足す）

## 4. 変更の記録と検証

- [ ] 4.1 変更の記録を書く（何を変えたか、子・親の値と根拠の issue コメント、マージ前に起動された子は既定のまま動くこと、親の値は主の起動コマンドで付けること）。触る範囲: plugins/dev-workflow/changes/1039.md（新規）
- [ ] 4.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats`、`scripts/lint.sh`、`openspec validate --specs --strict`、`openspec validate idle-reply-compaction --type change --strict` を通す。触る範囲: なし（実行だけ）
