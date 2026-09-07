# 旧運用からの移行と、marketplace dir に残った worktree の扱い

現行の運用では、開発は marketplace dir（`~/.claude/plugins/marketplaces/oratta-claude-harness/`）の外に置いた clone とその worktree で行う（`CLAUDE.md` の「開発場所」を参照）。marketplace dir は常に main のまま Claude Code の自動更新に任せる。

以前は marketplace dir 自体で feature ブランチを checkout し、そこから worktree を生やしていた。この形の worktree は、管理情報が再 clone されうる `.git` の中にあるため、プラグイン自動更新で失われることがある。残っている場合も、失われた場合も、開発用 clone 側で作り直す:

```bash
# 1. 開発用 clone（marketplace dir の外に置いたもの）で branch を取得する
git -C <dev-clone> fetch origin <branch-name>

# 2. 開発用 clone から worktree を作り直す
git -C <dev-clone> worktree add <worktree-path> <branch-name>

# 3. wt-setup で開発環境を整える
cd <worktree-path>
# Claude Code を立ち上げて /wt-setup
```

marketplace dir 側に古い worktree の登録が残っている場合の掃除（`git worktree prune` や worktree dir の削除）は破壊的操作なので、主の承認を得てから行う。

commit して push 済みの内容は remote から復元できる。session.jsonl のような ephemeral ファイルは **復元対象外**。
