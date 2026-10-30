## 1. コマンド・agent の探索順

- [x] 1.1 `plugins/dev-workflow/commands/develop.md` の 2 つの探索ループ（develop 本体・issueify）に、`oratta-claude-harness` の固定候補を `CLAUDE_PLUGIN_ROOT` の次・glob の前に足す。#955 の nullglob 退避は変えない 触る範囲: plugins/dev-workflow/commands/develop.md:22-34、plugins/dev-workflow/commands/develop.md:57-69
- [x] 1.2 `ci-watch.md`・`memory-refresh.md`・`synced-skills-slim.md` も同じ 触る範囲: plugins/dev-workflow/commands/ci-watch.md:14-26、plugins/dev-workflow/commands/memory-refresh.md:13-25、plugins/dev-workflow/commands/synced-skills-slim.md:13-25
- [x] 1.3 `plugins/cost-ledger/commands/cost.md`・`plugins/worktree/commands/wt-clean.md`・`wt-setup.md`・`plugins/casting/commands/init.md` も同じ 触る範囲: plugins/cost-ledger/commands/cost.md:15-27、plugins/worktree/commands/wt-clean.md:15-27、plugins/worktree/commands/wt-setup.md:16-28、plugins/casting/commands/init.md:17-29
- [x] 1.4 `plugins/infra/agents/infra-phase-4-github-actions.md` の代替ループ（`CLAUDE_PLUGIN_ROOT` 候補なし）の先頭に固定候補を足す 触る範囲: plugins/infra/agents/infra-phase-4-github-actions.md:46-58

## 2. 予算・仕様

- [x] 2.1 `tests/develop-startup-budget.txt` の `commands/develop.md` を実測に合わせて上げる（上限 1.1 倍以内）。`tests/injection-budget.txt` は動かさない 触る範囲: tests/develop-startup-budget.txt:2
- [x] 2.2 仕様の差分を本体の `openspec/specs/dev-workflow-issue-entry/spec.md` に反映する（archive 時） 触る範囲: openspec/specs/dev-workflow-issue-entry/spec.md:48-50

## 3. 検査と記録

- [x] 3.1 各プラグインの探索テストに、`aaa-stale` と `oratta-claude-harness` を並べた HOME で順（ルート → 固定 → glob → installed）を bash 常に・zsh 有るときに確かめるケースを足す。固定パスの無い HOME で glob → installed になることも 触る範囲: plugins/dev-workflow/tests/command-search-zsh.bats（末尾に追加）、plugins/cost-ledger/tests/cost-command-zsh.bats（末尾に追加）、plugins/worktree/tests/commands-search-zsh.bats（末尾に追加）、plugins/casting/tests/init-command-zsh.bats（末尾に追加）、plugins/infra/tests/phase4-search-zsh.bats（末尾に追加）
- [x] 3.2 `plugins/{dev-workflow,cost-ledger,worktree,casting,infra}/changes/1480.md` を書く（#1152 の statusline の記録に倣う） 触る範囲: plugins/dev-workflow/changes/1480.md（新規）、plugins/cost-ledger/changes/1480.md（新規）、plugins/worktree/changes/1480.md（新規）、plugins/casting/changes/1480.md（新規）、plugins/infra/changes/1480.md（新規）
- [x] 3.3 `grep -rn 'marketplaces/\*' plugins/*/commands plugins/*/agents` で、固定パスより先に glob が来る箇所が無いこと、`bats tests/command-plugin-root.bats tests/develop-startup-budget.bats` と各探索テストが通ることを確かめる
