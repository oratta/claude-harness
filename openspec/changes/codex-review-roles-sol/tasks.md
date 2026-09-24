## 1. テストを先に書く（Red）

- [x] 1.1 `plugins/dev-workflow/tests/test_codex_develop.py` の `test_builtin_codex_entries_name_families_not_model_ids` の期待値を、`codex-standard`・`codex-economy` で spec-review/impl-review/review が `sol`、decider が `astra` になるよう直す
- [x] 1.2 同じファイルの `test_reverse_hybrid_profile_resolves_every_canonical_role` の期待値を、`claude-write-codex-review` の spec-review/impl-review/review が `('codex', 'current', 'sol', 'high')`、decider が `('codex', 'current', 'astra', 'high')` になるよう直す
- [x] 1.3 `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` を実行し、直した 2 件が落ちることを確認する

## 2. 実装（Green）

- [x] 2.1 `plugins/dev-workflow/references/codex-role-profiles.json` の `codex-standard`・`codex-economy`・`claude-write-codex-review` で、spec-review/impl-review/review の model を `astra` から `sol` に替える（effort は `high` のまま、decider は変えない、`hybrid-standard` は変えない）
- [x] 2.2 `python3 -m unittest plugins/dev-workflow/tests/test_codex_develop.py` が通ることを確認する
- [x] 2.3 `git grep -nE 'gpt-[0-9]' plugins/dev-workflow/references/codex-role-profiles.json` が 0 件であることを確認する

## 3. 記録

- [x] 3.1 `plugins/dev-workflow/changes/474.md` に変更記録を書く（何を替えたか・decider と effort を据え置いた理由・受け入れたリスク）。版は上げない

## 4. 確認

- [x] 4.1 `bash scripts/test.sh` を引数なしで全件実行し、exit code を記録する。`scripts/lint.sh` も通す
- [x] 4.2 `openspec validate codex-review-roles-sol --strict` が通ることを確認する

## 5. archive（(3b) で行う）

- [ ] 5.1 change を archive し、`git diff` で `openspec/specs/codex-role-profiles/spec.md` の 3 シナリオ（「二つの Codex 組み込みセットを解決する」「Claude が書き Codex が検査する組み込みセットを解決する」「両 provider に余裕がある」）が delta と同じ文面になったことを確認する
