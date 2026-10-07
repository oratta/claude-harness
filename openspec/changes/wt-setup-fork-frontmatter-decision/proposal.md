## Why

`plugins/worktree/skills/wt-setup/SKILL.md` の `context: fork` / `background: false`（#707）が、実際に呼ばれる経路で効くのか未確認だった（#732）。使い捨てリポジトリでの実機確認（Claude Code 2.1.292、`claude -p --plugin-dir`）で、`/wt-setup` も Skill ツール経由の `worktree:wt-setup` も、同名の `commands/wt-setup.md`（インライン実行のラッパー）に解決され、SKILL.md の frontmatter は読まれないと分かった。この事実をスキル本体に残さないと、効かない設定が理由なしに残り続ける。

## What Changes

- `context: fork` / `background: false` / `model: sonnet` は**残す**。frontmatter 内の YAML コメントで「いまの経路ではラッパーが勝つので効かない。ラッパーを外したときに効く保険であり、その場合 fork でも完了を待つ」と理由を書く
- `skill-execution-isolation` の「隔離されたコンテキストで実行する」要件に、ラッパーが同名で存在する間は frontmatter が効かないこと、効くのはスキル本体が直接実行される経路に限ることを明記する
- `commands/wt-setup.md` と bats（`skill-safety.bats`）は変えない

## Capabilities

### Modified Capabilities
- `skill-execution-isolation`: fork 指定の要件に、適用される経路（スキル本体が直接実行される場合）を限定する文言と、現行経路の観測結果を足す

## Impact

`plugins/worktree/skills/wt-setup/SKILL.md`（frontmatter のコメントのみ）、`openspec/specs/skill-execution-isolation/spec.md`（archive 時に反映）。振る舞いは変わらない。
