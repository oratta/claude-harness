## 1. spec の文言を直す

- [ ] 1.1 `specs/` の差分（5 capability）を archive で `openspec/specs/` に反映する（`openspec archive develop-spec-moved-section-refs`）。要件名 2 件は `## RENAMED Requirements` で変わる。反映後、差分に無い要件が変わっていないことを `git diff` で確かめる。触る範囲: openspec/specs/dev-workflow-develop/spec.md:1-3700、openspec/specs/dev-workflow-ci-watch/spec.md:253、openspec/specs/dev-workflow-pr-review-gate/spec.md:1641、openspec/specs/dev-workflow-pr-review-gate/spec.md:1681、openspec/specs/harness-public-private-split/spec.md:287、openspec/specs/owner-question-style/spec.md:73

## 2. 確かめる

- [ ] 2.1 移設先の節名を SKILL.md の節として名指す記述が 0 件であることを確かめる。`grep -rnE 'SKILL\.md[^。]{0,8}[「『](エピックの扱い|エピックの子が主の返事を待って止まるとき|保留で止まるときの引き継ぎ|レビューの周を主に聞かずに続ける|channel の聞き方|channel のリスク許容|channel の主への発言|新しいセッションでの再開)' openspec/specs; echo "exit=$?"` を実行し、`exit=1`（一致ゼロ）を合格とする。`exit=2` は検索エラーなので合格にせず、検索のしかたを直して取り直す。`exit=0` は一致があるので、1 件ずつ、その節の中身が今どのファイルにあるかを見て直すか（移設先に中身がある）、直さない理由を残す（SKILL.md に中身が残る節）。触る範囲: openspec/specs/（読むだけ）
- [ ] 2.2 受け入れ条件 2 つ目（移設先の節名を SKILL.md の節として名指す記述が無い）の照合として、2.1 の節名の一覧が、移設先の見出し（`plugins/dev-workflow/skills/develop/references/epic.md`・`epic-child-stop.md`・`handover.md`・`fix-check.md`・`channel.md` の `##`・`###` の見出し）と食い違っていないことを `grep -n '^##' <各ファイル>` で確かめる。移設先に見出しが増えていたら 2.1 の一覧に足して取り直す。触る範囲: plugins/dev-workflow/skills/develop/references/（読むだけ）
- [ ] 2.3 `openspec validate --specs --strict` が通ることと、`bats plugins/dev-workflow/tests/develop-channel-mode.bats tests/owner-question-style.bats` が通ることを確かめる。触る範囲: plugins/dev-workflow/tests/develop-channel-mode.bats（読むだけ）、tests/owner-question-style.bats（読むだけ）
- [ ] 2.4 退行テスト: `openspec/specs/` の現行 spec の形を守る既存の bats（`tests/openspec-specs-format.bats`）に、2.1 と同じ検査を `@test` として 1 件足す（テスト名は ASCII のみ）。新しいファイルや仕組みは作らない。同じ型の検査が他の既存 bats にあると分かったら、そちらに足す。足したら `bats tests/openspec-specs-format.bats` を通す。触る範囲: tests/openspec-specs-format.bats:17-60
