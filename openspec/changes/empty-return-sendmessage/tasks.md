## 1. SKILL.md と bats

- [ ] 1.1 先にテストを書く: `develop-skill.bats` に、`returned no output` を含む行を SKILL.md から取り出し、その段落に「SendMessage で 1 回だけ報告を求める」「`git -C <path> status --porcelain`」「同じ指示で起こし直さない」「主に上げる」が含まれることを確かめるテストを足す。段落が見つからなければ落ちる形にする。触る範囲: plugins/dev-workflow/tests/develop-skill.bats（末尾に足す。setup は 1-30 行付近）
- [ ] 1.2 SKILL.md の「1 ループ」の節、W の spawn・SendMessage 再開を説明する段落（`W は名前付きで spawn し`）の直後に、`(Subagent completed but returned no output.)` を受けたときの扱いの段落を足す（design.md の 4 つの Decisions）。frontmatter の `description` は変えない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:198-202（「W は名前付きで spawn し」の段落と「## ループの終わり」の見出しの間）
- [ ] 1.3 `bats plugins/dev-workflow/tests/develop-skill.bats` が exit 0。`scripts/test.sh` が exit 0（`tests/injection-budget.bats` を含む）。触る範囲: なし

## 2. 変更の記録と実機確認

- [ ] 2.1 `plugins/dev-workflow/changes/1117.md` に変更の記録を書く。触る範囲: plugins/dev-workflow/changes/1117.md（新規）
- [ ] 2.2 実機確認: `claude -p --setting-sources project,local --plugin-dir <この worktree>/plugins/dev-workflow` で親を起こし、バックグラウンドの子に scratchpad の使い捨て repo で `git checkout -- <file>` を別のファイルで 2 回打たせて hook に 2 回拒否させ打ち切る。親が SendMessage で報告を受け取れること（拒否の経緯を含む）を確かめ、結果を design.md の末尾に「実機確認の結果」として足す（PR 本文への記録は finish 段）。触る範囲: openspec/changes/empty-return-sendmessage/design.md（末尾に節を追加）
