## 1. 見張りテスト（先に Red で書く）

- [ ] 1.1 `tests/bats-assertion-guard.bats` を新規作成し、途中に偽の `[[ ... ]]` を置いた fixture テストを子プロセスの bats として起動し、そのテストが `not ok` になることを確認するテストを書く（`tests/test-sh-residual-guard.bats` の bats 子プロセス起動パターンを踏襲）
- [ ] 1.2 見張りテストを実行し、ガードを付ける前の bats の挙動（途中の偽アサーションを素通りする）を確かめてから次に進む（Red の確認）

## 2. 対象ファイルへのガード適用

- [ ] 2.1 `plugins/capability-registry/tests/fmtoken.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.2 `plugins/casting/tests/casting-check.bats` / `casting-resolve.bats` / `casting-set.bats` / `casting-structure.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.3 `plugins/dev-workflow/tests/memory-refresh-skill.bats` / `memory-tripwire.bats` / `push-guard-setup.bats` / `review-hit-set.bats` / `usage-probe-multi-account.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.4 `plugins/experience-to-skill/tests/jsonl-finder.bats` / `sanitize.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.5 `plugins/infra/tests/infra-fixes.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.6 `plugins/statusline/tests/statusline-multi-account.bats` / `statusline.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.7 `plugins/worktree/tests/active-session-guard.bats` / `devserver-kill.bats` / `hooks.bats` / `orphan-proc-guard.bats` / `setup-script.bats` / `unattended-mode.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける
- [ ] 2.8 `tests/injection-budget.bats` / `tests/python-suites.bats` / `tests/test-sh-residual-guard.bats` の途中の `[[ ... ]]` に `|| return 1` を付ける

## 3. 検証

- [ ] 3.1 見張りテストが green になったことを確認する（ガードを付けたことで、意図的に偽アサーションを含む fixture テストが実際に fail すると見張りテストが検証する）
- [ ] 3.2 `git ls-files '*.bats' ':(exclude)_longruns/' ':(exclude)plugins/cost-ledger/'` を対象に、各 `@test` 本文で最後の文以外に位置するガード無しの `[[ ... ]]` が 0 件であることを確認する（grep で件数を示す）
- [ ] 3.3 `bash scripts/test.sh` を実行し、全件 green（exit 0）であることを確認する。ガードを付けた結果として落ちるテストが出たら、その内容を記録して別途 issue を切る（本 change の受け入れ条件は変えない）
