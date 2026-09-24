## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/test_codex_develop.py` の `test_builtin_codex_entries_name_families_not_model_ids` の期待値を、`codex-standard`・`codex-economy` で spec-review/impl-review/review が `sol`、decider が `astra` になるよう直す
- [ ] 1.2 同じファイルの `test_reverse_hybrid_profile_resolves_every_canonical_role` の期待値を、`claude-write-codex-review` の spec-review/impl-review/review が `('codex', 'current', 'sol', 'high')`、decider が `('codex', 'current', 'astra', 'high')` になるよう直す
- [ ] 1.3 `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` を実行し、直した 2 件が落ちることを確認する

## 2. 実装（Green）

- [ ] 2.1 `plugins/dev-workflow/references/codex-role-profiles.json` の `codex-standard`・`codex-economy`・`claude-write-codex-review` で、spec-review/impl-review/review の model を `astra` から `sol` に替える（effort は `high` のまま、decider は変えない、`hybrid-standard` は変えない）
- [ ] 2.2 `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` が通ることを確認する
- [ ] 2.3 `git grep -nE 'gpt-[0-9]' plugins/dev-workflow/references/codex-role-profiles.json` が 0 件であることを確認する

## 3. 記録

- [ ] 3.1 `plugins/dev-workflow/changes/474.md` に変更記録を書く（何を替えたか・decider と effort を据え置いた理由・受け入れたリスク）。版は上げない

## 4. 確認

- [ ] 4.1 `bash scripts/test.sh` を引数なしで全件実行し、exit code を記録する。`scripts/lint.sh` も通す
- [ ] 4.2 `openspec validate codex-review-roles-sol --strict` が通ることを確認する
