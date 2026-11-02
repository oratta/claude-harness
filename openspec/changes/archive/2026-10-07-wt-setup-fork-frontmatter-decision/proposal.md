## Why

`plugins/worktree/skills/wt-setup/SKILL.md` の `context: fork` / `background: false`（#707）が、実際に呼ばれる経路で効くのか未確認だった（#732）。使い捨てリポジトリでの実機確認（Claude Code 2.1.292、`claude -p --plugin-dir`）で、`/wt-setup` も Skill ツール経由の `worktree:wt-setup` も、同名の `commands/wt-setup.md`（インライン実行のラッパー）に解決され、SKILL.md の frontmatter は読まれないと分かった。この事実をスキル本体に残さないと、効かない設定が理由なしに残り続ける。

## What Changes

- `context: fork` / `background: false` / `model: sonnet` は**残す**。frontmatter 内に先頭 12 行へ収まる短い YAML コメント（効かない旨と、詳細は本文を見よという指示）を書き、SKILL.md 本文に節「frontmatter の fork 指定について」を足して、実機観測（同名 commands ラッパーが勝つこと・版・確かめ方）と残す理由を書く
- `skill-execution-isolation` の「隔離されたコンテキストで実行する」要件に、ラッパーが同名で存在する間は frontmatter が効かないこと、効くのはスキル本体が直接実行される経路に限ることを明記する
- `commands/wt-setup.md` は変えない。`skill-safety.bats` には先頭 12 行のコメントと本文の節を検査するテストを 2 件足す

## Capabilities

### Modified Capabilities
- `skill-execution-isolation`: fork 指定の要件に、適用される経路（スキル本体が直接実行される場合）を限定する文言と、現行経路の観測結果を足す

## Impact

`plugins/worktree/skills/wt-setup/SKILL.md`（frontmatter のコメントと本文の 1 節）、`openspec/specs/skill-execution-isolation/spec.md`（archive 時に反映）。振る舞いは変わらない。
