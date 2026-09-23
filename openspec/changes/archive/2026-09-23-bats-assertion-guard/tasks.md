## 1. 常設の静的スコープ検査（TDD の Red をここで立てる）

- [x] 1.1 `tests/bats-assertion-guard.bats` を新規作成し、spec の grep コマンド（`git ls-files '*.bats' ':(exclude)_longruns/' ':(exclude)plugins/cost-ledger/' | xargs grep -nE '^[[:space:]]*\[\[ .*\]\][[:space:]]*(#.*)?$'`）を実行し出力が空であることを確認するテストを書く
- [x] 1.2 このテストを実行し、ガード適用前は Red（378 件前後ヒットする）であることを確認する

## 2. 実行時の実演テスト（bash バージョン依存）

- [x] 2.1 同じファイルに、途中に偽の `[[ ... ]]` を `|| return 1` 付きで置いた fixture テストを子プロセスの bats で起動し、実行した bash のバージョンに関わらず `not ok` になることを確認するテストを書く（`tests/test-sh-residual-guard.bats` の bats 子プロセス起動パターンを踏襲）
- [x] 2.2 同様に、ガード無しの fixture テストを子プロセスの bats で起動し、`${BASH_VERSINFO[0]}` が 4 未満、または 4 かつ `${BASH_VERSINFO[1]}` が 1 未満のときだけ `ok`（素通り）になることを確認し、それ以外のバージョンでは `skip` するテストを書く

## 3. 対象ファイルへのガード適用（単独文の `[[ ]]` は最後の文も含め全部）

- [x] 3.1 `plugins/capability-registry/tests/fmtoken.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.2 `plugins/casting/tests/casting-check.bats` / `casting-resolve.bats` / `casting-set.bats` / `casting-structure.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.3 `plugins/dev-workflow/tests/memory-refresh-skill.bats` / `memory-tripwire.bats` / `push-guard-setup.bats` / `review-hit-set.bats` / `usage-probe-multi-account.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.4 `plugins/experience-to-skill/tests/jsonl-finder.bats` / `sanitize.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.5 `plugins/infra/tests/infra-fixes.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.6 `plugins/statusline/tests/statusline-multi-account.bats` / `statusline.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.7 `plugins/worktree/tests/active-session-guard.bats` / `devserver-kill.bats` / `hooks.bats` / `orphan-proc-guard.bats` / `setup-script.bats` / `unattended-mode.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける
- [x] 3.8 `tests/injection-budget.bats` / `tests/python-suites.bats` / `tests/test-sh-residual-guard.bats` の単独文 `[[ ... ]]` に `|| return 1` を付ける

## 4. 検証

- [x] 4.1 タスク 1.1 のスコープ検査テストが Green（出力 0 行）になったことを確認する
- [x] 4.2 タスク 2.1 / 2.2 の実演テストが green（該当する bash バージョンでの検証、または skip）で終わることを確認する
- [x] 4.3 `bash scripts/test.sh` を実行し、全件 green（exit 0）であることを確認する。ガードを付けた結果として落ちるテストが出たら、その内容を記録して別途 issue を切る（本 change の受け入れ条件は変えない）
