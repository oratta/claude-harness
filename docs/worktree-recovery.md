# 復元手順（worktree dir がプラグイン更新で消えた場合）

```bash
# 1. branch を取得
git fetch origin <branch-name>

# 2. 新しい worktree を作る（marketplace dir の外がおすすめ）
git worktree add ~/.superset/worktrees/<uuid>/<branch-name> <branch-name>

# 3. wt-setup で開発環境を整える
cd ~/.superset/worktrees/<uuid>/<branch-name>
# Claude Code を立ち上げて /wt-setup
```

session.jsonl のような ephemeral ファイルは **復元対象外**。Draft PR にバックアップされるのは git tracked なファイルと commit 履歴のみ。
