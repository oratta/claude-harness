## change-4: worktree-command-dedup

### S1: [worktree-command-wrapper] wt-clean コマンドが SKILL.md を Read してインライン実行する
- WHEN: ユーザーが `plugins/worktree/commands/wt-clean.md` を開く
- THEN: `skills/wt-clean/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/wt-clean/SKILL.md` を含むパス）を Read tool で読み込みインライン実行する旨の指示が本文に含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S2: [worktree-command-wrapper] wt-clean コマンドに診断分類表の重複コピーが無い
- WHEN: `plugins/worktree/commands/wt-clean.md` 内で診断分類表（`🟢 Safe` / `🟡 Recoverable` / `🔴 Active` の Markdown 表・分類条件本文）を grep する
- THEN: 分類表・分類条件本文が 1 件も存在しない（分類の正は SKILL.md 側のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S3: [worktree-command-wrapper] wt-clean コマンドに squash 検出ロジックの重複コピーが無い
- WHEN: `plugins/worktree/commands/wt-clean.md` 内で squash 検出手順本文（`検証A`/`検証B`/`検証C`・`git cherry`・`TREE_DIFF`・`SQUASHED`）を grep する
- THEN: これらの手順本文が command に存在しない（squash 検出の正は SKILL.md 側のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S4: [worktree-command-wrapper] wt-setup コマンドが SKILL.md を Read してインライン実行する
- WHEN: ユーザーが `plugins/worktree/commands/wt-setup.md` を開く
- THEN: `skills/wt-setup/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/wt-setup/SKILL.md` を含むパス）を Read tool で読み込みインライン実行する旨の指示が本文に含まれている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S5: [worktree-command-wrapper] wt-setup コマンドにセットアップ手順本文の重複コピーが無い
- WHEN: `plugins/worktree/commands/wt-setup.md` 内でセットアップ手順本文（`wt-setup.sh` 呼び出しブロック・`.worktreeinclude` 生成の分類ルール本文・`gh pr create --draft` の Draft PR 手順）を grep する
- THEN: これらの手順本文が command に存在しない（Step 1-6 の正は SKILL.md 側のみ）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S6: [worktree-command-wrapper] wt-clean の frontmatter が allowed-tools を維持する
- WHEN: `plugins/worktree/commands/wt-clean.md` の frontmatter を読む
- THEN: `allowed-tools` に `AskUserQuestion`・`Read`・`Bash` を含む（診断フロー実行に必要なツールが欠落していない）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S7: [worktree-command-wrapper] wt-setup の frontmatter が allowed-tools と argument-hint を維持する
- WHEN: `plugins/worktree/commands/wt-setup.md` の frontmatter を読む
- THEN: `allowed-tools` が保持され、かつ `argument-hint`（`[--with-pr] ...` 相当）が存在する
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S8: [worktree-command-wrapper] 引数が SKILL.md の実行に透過される
- WHEN: ユーザーが `/wt-clean ~/wt/foo --no-sync` や `/wt-setup --with-pr ログイン画面のバグ修正` のように引数付きで起動する
- THEN: ラッパーは `$ARGUMENTS` を SKILL.md の実行にそのまま渡す旨を明記しており、位置引数・フラグ・後続作業指示が SKILL.md 側フローに欠落なく届く
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S9: [worktree-command-wrapper] squash 検出 A/B/C が SKILL.md に一言一句残っている
- WHEN: `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- THEN: 検証 A（実ツリー差分空）・検証 B（`git cherry`）・検証 C（`gh pr` MERGED）の 3 検証、「実ツリー差分を優先」、`SQUASHED` 非空を 🟢/🟡 とし `AHEAD_COUNT>0` でも 🔴 にしない旨がすべて残っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S10: [worktree-command-wrapper] AskUserQuestion 別ターン実行の絶対禁則が SKILL.md に残っている
- WHEN: `plugins/worktree/skills/wt-clean/SKILL.md` を読む
- THEN: 「AskUserQuestion ツール呼び出しと削除 Bash を同一ターンの並列ツール呼び出しに含めてはならない」「回答を受け取った後の別のアシスタントターンで実行する」旨の絶対禁則（最重要）が残っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S11: [worktree-command-wrapper] command 経由と skill 経由で同一の診断フローになる
- WHEN: `/wt-clean` を command として起動した場合と、wt-clean skill を起動した場合を比較する
- THEN: command は独立フロー定義を持たず SKILL.md を Read して実行するため、両経路とも `skills/wt-clean/SKILL.md` の同一手順（Step 0→A→B→C, squash 検出込み）を実行し、command 側に旧分類表など別フローが存在しない
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S12: [worktree-setup-script-integrity] find -path グロブの挙動が検証され意図がコメント化されている
- WHEN: `plugins/worktree/scripts/wt-setup.sh` の `.worktreeinclude` 展開ループ（`find -path "./$pattern"` を含む箇所）を読む
- THEN: `find -path` のグロブ展開挙動（1 階層パターンとサブディレクトリ一致の差異）についての確認結果コメントが存在する、または挙動を是正する修正が入っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S13: [worktree-setup-script-integrity] settings.local.json の symlink 是非が判断・文書化されている
- WHEN: `plugins/worktree/scripts/wt-setup.sh` の `.claude/` 配下ファイルを symlink するループ（`settings.json` / `settings.local.json` 対象箇所）を読む
- THEN: `settings.local.json` を worktree に symlink する／しないの判断理由コメントが存在する、または是正する修正が入っている
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了

### S14: [worktree-setup-script-integrity] スクリプトの構文検証が通る
- WHEN: `bash -n plugins/worktree/scripts/wt-setup.sh` を実行する
- THEN: 構文エラーなく終了する（exit 0）
- [x] テスト実装完了
- [x] ロジック実装完了
- [x] 動作確認完了
- [ ] ユーザー確認完了
