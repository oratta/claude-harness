## Why

サブエージェント（子）が破壊的 git 操作を 2 回拒否されると、hook が `continue: false` を返して子を打ち切る（#1108）。実機（Claude Code 2.1.303）で確かめると、子だけが終わって親は続くが、親に届くのは `(Subagent completed but returned no output.)` だけで、拒否された理由も `stopReason` も届かない。親は作業の途中で子が消えた理由が分からず、同じ指示で子を起こし直して同じ操作に当たることがある（issue #1117）。

#1108 の実機確認では、バックグラウンドで起こした子に SendMessage で報告を求めると、子は拒否された経緯を含めて報告を書き直せた。これを develop の本体（親）の手順にする。

## What Changes

- `skills/develop/SKILL.md` の「1 ループ」の節に、子の return が空（`returned no output`）だったときの本体の扱いを足す。名前付きで起こした子（W）には SendMessage で 1 回だけ報告を求め、作業ツリーの未コミット差分を `git -C <path> status --porcelain` で確かめる。報告に破壊的 git 操作で打ち切られたとあれば、同じ指示では起こし直さず、主に上げる
- develop の文面の bats に、この 2 つの文言（1 回だけ報告を求める・同じ指示で起こし直さない）の検査を足す
- `dev-workflow-develop` に要件を 1 つ足す。`description` と常時注入の文面は変えない

## Capabilities

### Modified Capabilities

- `dev-workflow-develop`: 空の return を受けた本体の扱いの要件を足す

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（本文のみ。frontmatter は変えない）
- `plugins/dev-workflow/tests/develop-skill.bats`
- `plugins/dev-workflow/changes/1117.md`（変更の記録）
