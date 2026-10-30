## Why

コマンド本文の探索ループは、`CLAUDE_PLUGIN_ROOT`（slash command の本文では空になる）の次に `~/.claude/plugins/marketplaces/*/plugins/<部品>` を名前順に見る。旧運用の worktree の残り（例 `aaa-stale` や `claude-harness-burn-63`）が `oratta-claude-harness` より先に並ぶと、古い版の手順やスクリプトが黙って使われる。#1152 で `/statusline:setup` だけ直したので、同型の残りを揃える（親エピック #1479）。

## What Changes

探索順を `CLAUDE_PLUGIN_ROOT` → `~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/<部品>`（固定）→ marketplaces の glob → installed の glob に揃える。glob は固定候補が無い環境の最後の手段として残す。#955 の nullglob 退避は触らない。

対象（`marketplaces/*` を `for dir in` で探す全 10 か所。数え直した結果）:
- `plugins/dev-workflow/commands/develop.md`（2 か所）・`ci-watch.md`・`memory-refresh.md`・`synced-skills-slim.md`（issue の一覧に無かったが同型なので足す）
- `plugins/cost-ledger/commands/cost.md`
- `plugins/worktree/commands/wt-clean.md`・`wt-setup.md`
- `plugins/casting/commands/init.md`
- `plugins/infra/agents/infra-phase-4-github-actions.md`（`CLAUDE_PLUGIN_ROOT` を候補に持たない代替ループ。固定候補を glob の前に足す）
- 要件文: `openspec/specs/dev-workflow-issue-entry/spec.md` の issueify 探索順
- 予算: `tests/develop-startup-budget.txt` の `commands/develop.md`（探索 2 行ぶん増える）
- 検査: 各プラグインの探索テストに、`aaa-stale` と `oratta-claude-harness` を並べた HOME で順を確かめるケースを足す
- 記録: 各プラグインの `changes/1480.md`

casting の `templates/*.md` などにある `marketplaces/*/plugins/casting/…` は説明文中の表記で探索ブロックではないので触らない。

## Capabilities

### Modified Capabilities
- `dev-workflow-issue-entry`: issueify フォールバックの探索順に固定パスを加える

## Impact

- コマンド本文のみ。実行時の挙動は、旧 worktree が残る環境で正しい版が選ばれるようになる以外変わらない
- `tests/injection-budget.txt` は動かない（commands の本文・agent の本文は常時注入の対象外）
